import 'package:sqflite/sqflite.dart';

import '../models/entidades_db.dart';
import 'base_datos.dart';

/// Conversaciones, consultas, respuestas a retos y estadisticas del grupo.
/// Sin base de datos disponible, todos los metodos devuelven valores vacios.
class RepositorioConversaciones {
	RepositorioConversaciones(this._base);

	final BaseDatos _base;

	Database? get _db => _base.db;

	// ---------------------------------------------------------- Conversacion

	/// Abre una conversacion nueva (RF-09) y devuelve su id.
	Future<int?> crearConversacion({
		required int idGrupo,
		int? idAlumno,
		required String titulo,
	}) async {
		final Database? db = _db;
		if (db == null) {
			return null;
		}
		return db.insert('conversacion', <String, Object?>{
			'id_grupo': idGrupo,
			'id_alumno': idAlumno,
			'titulo': titulo,
			'inicio': ahoraIso(),
		});
	}

	/// Marca el fin de una conversacion.
	Future<void> cerrarConversacion(int idConversacion) async {
		await _db?.update(
			'conversacion',
			<String, Object?>{'fin': ahoraIso()},
			where: 'id_conversacion = ?',
			whereArgs: <Object?>[idConversacion],
		);
	}

	/// Conversaciones recientes del grupo que tengan al menos una consulta.
	Future<List<ConversacionResumen>> recientes(
		int idGrupo, {
		int limite = 8,
	}) async {
		final Database? db = _db;
		if (db == null) {
			return const <ConversacionResumen>[];
		}
		final List<Map<String, Object?>> filas = await db.rawQuery(
			'SELECT v.id_conversacion, v.titulo, v.inicio, '
			'COUNT(c.id_consulta) AS total '
			'FROM conversacion v '
			'JOIN consulta c ON c.id_conversacion = v.id_conversacion '
			'WHERE v.id_grupo = ? '
			'GROUP BY v.id_conversacion, v.titulo, v.inicio '
			'ORDER BY v.id_conversacion DESC LIMIT ?',
			<Object?>[idGrupo, limite],
		);
		return filas
			.map(
				(Map<String, Object?> f) => ConversacionResumen(
					id: aEntero(f['id_conversacion']),
					titulo: (f['titulo'] ?? '').toString(),
					inicio: DateTime.tryParse((f['inicio'] ?? '').toString()) ??
						DateTime.now(),
					totalConsultas: aEntero(f['total']),
				),
			)
			.toList();
	}

	// -------------------------------------------------------------- Consulta

	/// Guarda una consulta y devuelve su id. [claveFragmento] es la clave del tema
	/// de los libros SEP usado (por ejemplo "SEP-GEO-01"); null si se remitio al
	/// maestro.
	Future<int?> guardarConsulta({
		required int idConversacion,
		required String pregunta,
		required String respuesta,
		required int grado,
		required bool porVoz,
		required bool remitidaMaestro,
		required bool generadaPorIA,
		required double similitud,
		required int tiempoMs,
		String? claveFragmento,
	}) async {
		final Database? db = _db;
		if (db == null) {
			return null;
		}
		int? idFragmento;
		if (claveFragmento != null && claveFragmento.isNotEmpty) {
			final List<Map<String, Object?>> f = await db.query(
				'fragmento_sep',
				columns: <String>['id_fragmento'],
				where: 'clave = ?',
				whereArgs: <Object?>[claveFragmento],
				limit: 1,
			);
			if (f.isNotEmpty) {
				idFragmento = aEntero(f.first['id_fragmento']);
			}
		}
		return db.insert('consulta', <String, Object?>{
			'id_conversacion': idConversacion,
			'id_fragmento': idFragmento,
			'fecha': ahoraIso(),
			'pregunta': pregunta,
			'respuesta': respuesta,
			'grado': grado.clamp(4, 6),
			'por_voz': porVoz ? 1 : 0,
			'remitida_maestro': remitidaMaestro ? 1 : 0,
			'generada_por_ia': generadaPorIA ? 1 : 0,
			'similitud': similitud,
			'tiempo_ms': tiempoMs,
		});
	}

	/// Guarda si al nino le quedo clara la respuesta (meta: 80 % de dudas resueltas).
	Future<void> marcarQuedoClara(int idConsulta, bool clara) async {
		await _db?.update(
			'consulta',
			<String, Object?>{'quedo_clara': clara ? 1 : 0},
			where: 'id_consulta = ?',
			whereArgs: <Object?>[idConsulta],
		);
	}

	/// Consultas de una conversacion, en orden, listas para volver a mostrarse.
	Future<List<ConsultaGuardada>> consultasDe(int idConversacion) async {
		final Database? db = _db;
		if (db == null) {
			return const <ConsultaGuardada>[];
		}
		final List<Map<String, Object?>> filas = await db.rawQuery(
			'SELECT c.id_consulta, c.pregunta, c.respuesta, c.remitida_maestro, '
			'c.generada_por_ia, c.tiempo_ms, c.quedo_clara, '
			'f.clave, f.nombre_libro, f.bloque_tema, f.numero_pagina, '
			'f.tipo_ilustracion, f.nota_ilustracion '
			'FROM consulta c '
			'LEFT JOIN fragmento_sep f ON f.id_fragmento = c.id_fragmento '
			'WHERE c.id_conversacion = ? '
			'ORDER BY c.id_consulta',
			<Object?>[idConversacion],
		);
		return filas.map((Map<String, Object?> f) {
			final String libro = (f['nombre_libro'] ?? '').toString();
			final int pagina = aEntero(f['numero_pagina']);
			final String tema = (f['bloque_tema'] ?? '').toString();
			final String cita = libro.isEmpty
				? ''
				: (pagina > 0 ? '$libro · $tema (Pág. $pagina)' : '$libro · $tema');
			final Object? clara = f['quedo_clara'];
			return ConsultaGuardada(
				id: aEntero(f['id_consulta']),
				pregunta: (f['pregunta'] ?? '').toString(),
				respuesta: (f['respuesta'] ?? '').toString(),
				remitidaMaestro: aEntero(f['remitida_maestro']) == 1,
				generadaPorIA: aEntero(f['generada_por_ia']) == 1,
				tiempoMs: aEntero(f['tiempo_ms']),
				cita: cita,
				tipoIlustracion: (f['tipo_ilustracion'] ?? '').toString(),
				notaIlustracion: (f['nota_ilustracion'] ?? '').toString(),
				quedoClara: clara == null ? null : aEntero(clara) == 1,
				claveFragmento: (f['clave'] ?? '').toString(),
			);
		}).toList();
	}

	// ------------------------------------------------------- Respuesta a reto

	/// Guarda la opcion que eligio el alumno en el reto de un tema.
	/// [indiceOpcion] es la posicion (0, 1, 2...) de la opcion elegida.
	Future<void> registrarRespuestaReto({
		required String claveFragmento,
		required int indiceOpcion,
		int? idAlumno,
		int? idConversacion,
	}) async {
		final Database? db = _db;
		if (db == null) {
			return;
		}
		final List<Map<String, Object?>> retos = await db.rawQuery(
			'SELECT r.id_reto FROM reto r '
			'JOIN fragmento_sep f ON f.id_fragmento = r.id_fragmento '
			'WHERE f.clave = ? ORDER BY r.id_reto DESC LIMIT 1',
			<Object?>[claveFragmento],
		);
		if (retos.isEmpty) {
			return;
		}
		final int idReto = aEntero(retos.first['id_reto']);
		final List<Map<String, Object?>> opciones = await db.query(
			'opcion_reto',
			columns: <String>['id_opcion'],
			where: 'id_reto = ? AND orden = ?',
			whereArgs: <Object?>[idReto, indiceOpcion],
			limit: 1,
		);
		if (opciones.isEmpty) {
			return;
		}
		await db.insert('respuesta_reto', <String, Object?>{
			'id_reto': idReto,
			'id_opcion': aEntero(opciones.first['id_opcion']),
			'id_alumno': idAlumno,
			'id_conversacion': idConversacion,
			'fecha': ahoraIso(),
		});
	}

	// ---------------------------------------------------------- Estadisticas

	/// Indicadores del grupo o, si se indica [idAlumno], de ese alumno.
	Future<ResumenEstadisticas> estadisticas(
		int idGrupo, {
		int? idAlumno,
	}) async {
		final Database? db = _db;
		if (db == null) {
			return const ResumenEstadisticas();
		}
		final String filtroAlumno = idAlumno == null ? '' : ' AND v.id_alumno = ?';
		final List<Object?> args = <Object?>[
			idGrupo,
			if (idAlumno != null) idAlumno,
		];

		final List<Map<String, Object?>> c = await db.rawQuery(
			'SELECT COUNT(c.id_consulta) AS total, '
			'COALESCE(SUM(c.remitida_maestro), 0) AS remitidas, '
			'COALESCE(AVG(c.tiempo_ms), 0) AS promedio, '
			'COALESCE(SUM(CASE WHEN c.quedo_clara IS NOT NULL THEN 1 ELSE 0 END), 0) AS valoradas, '
			'COALESCE(SUM(CASE WHEN c.quedo_clara = 1 THEN 1 ELSE 0 END), 0) AS claras, '
			'COUNT(DISTINCT v.id_conversacion) AS conversaciones '
			'FROM consulta c '
			'JOIN conversacion v ON v.id_conversacion = c.id_conversacion '
			'WHERE v.id_grupo = ?$filtroAlumno',
			args,
		);

		final List<Map<String, Object?>> r = await db.rawQuery(
			'SELECT COUNT(r.id_respuesta) AS total, '
			'COALESCE(SUM(o.es_correcta), 0) AS aciertos '
			'FROM respuesta_reto r '
			'JOIN opcion_reto o ON o.id_opcion = r.id_opcion '
			'JOIN conversacion v ON v.id_conversacion = r.id_conversacion '
			'WHERE v.id_grupo = ?$filtroAlumno',
			args,
		);

		final Map<String, Object?> fc = c.first;
		final Map<String, Object?> fr = r.first;
		return ResumenEstadisticas(
			conversaciones: aEntero(fc['conversaciones']),
			consultas: aEntero(fc['total']),
			remitidas: aEntero(fc['remitidas']),
			tiempoPromedioMs: aDecimal(fc['promedio']),
			valoradas: aEntero(fc['valoradas']),
			claras: aEntero(fc['claras']),
			retosRespondidos: aEntero(fr['total']),
			retosAcertados: aEntero(fr['aciertos']),
		);
	}
}
