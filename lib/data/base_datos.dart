import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'esquema_sql.dart';

/// Apertura y creacion de la base de datos SQLite local.
///
/// Si la base no puede abrirse (por ejemplo en el navegador, o si falla el
/// almacenamiento) la app NO se detiene: [disponible] queda en false y los
/// repositorios devuelven valores vacios, de modo que Geograf-IA sigue
/// respondiendo como antes, solo que sin guardar historial.
class BaseDatos {
	BaseDatos._(this._db);

	final Database? _db;

	/// Base de datos abierta, o null si no esta disponible.
	Database? get db => _db;
	bool get disponible => _db != null;

	/// Instancia sin base de datos (pruebas, navegador o falla de almacenamiento).
	factory BaseDatos.sinBaseDatos() => BaseDatos._(null);

	/// Abre (y crea si hace falta) la base `geograf_ia.db`. Nunca lanza errores.
	static Future<BaseDatos> abrir() async {
		if (kIsWeb) {
			return BaseDatos.sinBaseDatos();
		}
		try {
			final String carpeta = await getDatabasesPath();
			final Database db = await openDatabase(
				'$carpeta/${EsquemaSql.nombreArchivo}',
				version: EsquemaSql.version,
				onConfigure: (Database d) async {
					// Hace que SQLite haga cumplir las llaves foraneas.
					await d.execute('PRAGMA foreign_keys = ON');
				},
				onCreate: _crearEsquema,
			);
			return BaseDatos._(db);
		} catch (e) {
			debugPrint('[BaseDatos] No se pudo abrir la base de datos: $e');
			return BaseDatos.sinBaseDatos();
		}
	}

	/// Crea las 11 tablas, los indices y el grupo inicial con su configuracion.
	static Future<void> _crearEsquema(Database db, int version) async {
		final Batch lote = db.batch();
		for (final String tabla in EsquemaSql.tablas) {
			lote.execute(tabla);
		}
		for (final String indice in EsquemaSql.indices) {
			lote.execute(indice);
		}
		await lote.commit(noResult: true);

		// Grupo inicial para que la app sirva desde el primer uso (RF-12: sin registro).
		final String ahora = DateTime.now().toIso8601String();
		final int idGrupo = await db.insert('grupo', <String, Object?>{
			'nombre': 'Grupo 1',
			'fecha_creacion': ahora,
			'ultimo_uso': ahora,
			'activo': 1,
		});
		await db.insert('configuracion_aula', <String, Object?>{
			'id_grupo': idGrupo,
			'actualizado_en': ahora,
		});
	}

	Future<void> cerrar() async {
		try {
			await _db?.close();
		} catch (_) {}
	}
}

/// Convierte un valor numerico de SQLite (puede venir null) en entero.
int aEntero(Object? valor) => (valor as num?)?.toInt() ?? 0;

/// Convierte un valor numerico de SQLite (puede venir null) en decimal.
double aDecimal(Object? valor) => (valor as num?)?.toDouble() ?? 0.0;

/// Marca de tiempo actual en formato ISO-8601 para guardar en la base.
String ahoraIso() => DateTime.now().toIso8601String();
