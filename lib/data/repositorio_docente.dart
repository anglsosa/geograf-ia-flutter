import 'package:sqflite/sqflite.dart';

import 'base_datos.dart';

/// Fila de la tabla `credencial_docente` (nunca contiene la contrasena real).
class CredencialDocente {
	CredencialDocente({
		required this.usuario,
		required this.huellaContrasena,
		required this.sal,
		required this.iteraciones,
		required this.esInicial,
		this.intentosFallidos = 0,
		this.bloqueadoHasta,
		this.ultimoAcceso,
	});

	final String usuario;
	String huellaContrasena;
	String sal;
	int iteraciones;

	/// true mientras el docente siga usando la contrasena que le entregaron.
	bool esInicial;
	int intentosFallidos;
	DateTime? bloqueadoHasta;
	DateTime? ultimoAcceso;
}

/// Credencial del docente guardada en SQLite (acceso al panel de Configuracion).
/// Sin base de datos disponible, [cargar] devuelve null y [guardar] no hace nada:
/// el servicio de autenticacion trabaja entonces solo en memoria.
class RepositorioDocente {
	RepositorioDocente(this._base);

	final BaseDatos _base;

	Database? get _db => _base.db;

	Future<CredencialDocente?> cargar(String usuario) async {
		final Database? db = _db;
		if (db == null) {
			return null;
		}
		final List<Map<String, Object?>> filas = await db.query(
			'credencial_docente',
			where: 'usuario = ?',
			whereArgs: <Object?>[usuario],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		final Map<String, Object?> f = filas.first;
		return CredencialDocente(
			usuario: (f['usuario'] ?? '').toString(),
			huellaContrasena: (f['huella_contrasena'] ?? '').toString(),
			sal: (f['sal'] ?? '').toString(),
			iteraciones: aEntero(f['iteraciones']),
			esInicial: aEntero(f['es_inicial']) == 1,
			intentosFallidos: aEntero(f['intentos_fallidos']),
			bloqueadoHasta: DateTime.tryParse((f['bloqueado_hasta'] ?? '').toString()),
			ultimoAcceso: DateTime.tryParse((f['ultimo_acceso'] ?? '').toString()),
		);
	}

	/// Guarda la credencial completa (la crea si todavia no existe).
	Future<void> guardar(CredencialDocente c) async {
		final Database? db = _db;
		if (db == null) {
			return;
		}
		final String ahora = ahoraIso();
		final Map<String, Object?> valores = <String, Object?>{
			'huella_contrasena': c.huellaContrasena,
			'sal': c.sal,
			'iteraciones': c.iteraciones,
			'es_inicial': c.esInicial ? 1 : 0,
			'intentos_fallidos': c.intentosFallidos,
			'bloqueado_hasta': c.bloqueadoHasta?.toIso8601String(),
			'ultimo_acceso': c.ultimoAcceso?.toIso8601String(),
			'actualizado_en': ahora,
		};
		final int filas = await db.update(
			'credencial_docente',
			valores,
			where: 'usuario = ?',
			whereArgs: <Object?>[c.usuario],
		);
		if (filas == 0) {
			await db.insert('credencial_docente', <String, Object?>{
				'usuario': c.usuario,
				'creado_en': ahora,
				...valores,
			});
		}
	}
}
