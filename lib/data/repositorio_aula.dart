import 'package:sqflite/sqflite.dart';

import '../models/entidades_db.dart';
import '../models/modelos.dart';
import 'base_datos.dart';

/// Grupos, alumnos anonimos y configuracion del aula.
/// Sin base de datos disponible, todos los metodos devuelven valores vacios.
class RepositorioAula {
	RepositorioAula(this._base);

	final BaseDatos _base;

	Database? get _db => _base.db;

	// ---------------------------------------------------------------- Grupos

	/// Grupos activos; el primero es el de uso mas reciente.
	Future<List<Grupo>> listarGrupos() async {
		final Database? db = _db;
		if (db == null) {
			return const <Grupo>[];
		}
		final List<Map<String, Object?>> filas = await db.query(
			'grupo',
			where: 'activo = 1',
			orderBy: 'ultimo_uso DESC, id_grupo DESC',
		);
		return filas
			.map(
				(Map<String, Object?> f) => Grupo(
					id: aEntero(f['id_grupo']),
					nombre: (f['nombre'] ?? '').toString(),
				),
			)
			.toList();
	}

	/// Crea un grupo nuevo con su configuracion por defecto y lo deja en uso.
	Future<Grupo?> crearGrupo(String nombre) async {
		final Database? db = _db;
		final String limpio = nombre.trim();
		if (db == null || limpio.isEmpty) {
			return null;
		}
		final String ahora = ahoraIso();
		final String nombreFinal =
			limpio.length > 30 ? limpio.substring(0, 30) : limpio;
		final int id = await db.transaction<int>((Transaction txn) async {
			final int nuevo = await txn.insert('grupo', <String, Object?>{
				'nombre': nombreFinal,
				'fecha_creacion': ahora,
				'ultimo_uso': ahora,
				'activo': 1,
			});
			await txn.insert('configuracion_aula', <String, Object?>{
				'id_grupo': nuevo,
				'actualizado_en': ahora,
			});
			return nuevo;
		});
		return Grupo(id: id, nombre: nombreFinal);
	}

	/// Marca un grupo como el que esta usando el dispositivo ahora.
	Future<void> marcarGrupoEnUso(int idGrupo) async {
		await _db?.update(
			'grupo',
			<String, Object?>{'ultimo_uso': ahoraIso()},
			where: 'id_grupo = ?',
			whereArgs: <Object?>[idGrupo],
		);
	}

	// --------------------------------------------------------------- Alumnos

	Future<List<Alumno>> listarAlumnos(int idGrupo) async {
		final Database? db = _db;
		if (db == null) {
			return const <Alumno>[];
		}
		final List<Map<String, Object?>> filas = await db.query(
			'alumno',
			where: 'id_grupo = ? AND activo = 1',
			whereArgs: <Object?>[idGrupo],
			orderBy: 'codigo',
		);
		return filas
			.map(
				(Map<String, Object?> f) => Alumno(
					id: aEntero(f['id_alumno']),
					idGrupo: aEntero(f['id_grupo']),
					codigo: (f['codigo'] ?? '').toString(),
				),
			)
			.toList();
	}

	/// Agrega un alumno con el siguiente codigo libre ("A-01", "A-02"...).
	/// No se piden nombres: la app protege la privacidad de los ninos (RNF-10).
	Future<Alumno?> agregarAlumno(int idGrupo) async {
		final Database? db = _db;
		if (db == null) {
			return null;
		}
		final List<Map<String, Object?>> existentes = await db.query(
			'alumno',
			columns: <String>['codigo'],
			where: 'id_grupo = ?',
			whereArgs: <Object?>[idGrupo],
		);
		int mayor = 0;
		for (final Map<String, Object?> f in existentes) {
			final String codigo = (f['codigo'] ?? '').toString();
			final int? numero = int.tryParse(codigo.replaceAll(RegExp(r'[^0-9]'), ''));
			if (numero != null && numero > mayor) {
				mayor = numero;
			}
		}
		final String nuevo = 'A-${(mayor + 1).toString().padLeft(2, '0')}';
		final int id = await db.insert('alumno', <String, Object?>{
			'id_grupo': idGrupo,
			'codigo': nuevo,
			'fecha_alta': ahoraIso(),
			'activo': 1,
		});
		return Alumno(id: id, idGrupo: idGrupo, codigo: nuevo);
	}

	/// Da de baja a un alumno (conserva su historial para las estadisticas).
	Future<void> darDeBajaAlumno(int idAlumno) async {
		await _db?.update(
			'alumno',
			<String, Object?>{'activo': 0},
			where: 'id_alumno = ?',
			whereArgs: <Object?>[idAlumno],
		);
	}

	// --------------------------------------------------------- Configuracion

	/// Configuracion guardada del grupo, o null si no existe.
	Future<ConfiguracionAula?> cargarConfiguracion(int idGrupo) async {
		final Database? db = _db;
		if (db == null) {
			return null;
		}
		final List<Map<String, Object?>> filas = await db.query(
			'configuracion_aula',
			where: 'id_grupo = ?',
			whereArgs: <Object?>[idGrupo],
			limit: 1,
		);
		if (filas.isEmpty) {
			return null;
		}
		final Map<String, Object?> f = filas.first;
		return ConfiguracionAula(
			gradoActual: aEntero(f['grado_actual']),
			velocidadLecturaVoz: aDecimal(f['velocidad_voz']),
			tamanoFuente: aEntero(f['tamano_texto']),
			altoContraste: aEntero(f['alto_contraste']) == 1,
			vozAutomatica: aEntero(f['voz_automatica']) == 1,
		);
	}

	/// Guarda la configuracion del grupo (crea la fila si todavia no existe).
	Future<void> guardarConfiguracion(
		int idGrupo,
		ConfiguracionAula config,
	) async {
		final Database? db = _db;
		if (db == null) {
			return;
		}
		final Map<String, Object?> valores = <String, Object?>{
			'grado_actual': config.gradoActual,
			'velocidad_voz': config.velocidadLecturaVoz,
			'tamano_texto': config.tamanoFuente,
			'alto_contraste': config.altoContraste ? 1 : 0,
			'voz_automatica': config.vozAutomatica ? 1 : 0,
			'actualizado_en': ahoraIso(),
		};
		final int filas = await db.update(
			'configuracion_aula',
			valores,
			where: 'id_grupo = ?',
			whereArgs: <Object?>[idGrupo],
		);
		if (filas == 0) {
			await db.insert('configuracion_aula', <String, Object?>{
				'id_grupo': idGrupo,
				...valores,
			});
		}
	}
}
