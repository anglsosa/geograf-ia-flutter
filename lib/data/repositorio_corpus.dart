import 'package:sqflite/sqflite.dart';

import '../models/entidades_db.dart';
import '../models/modelos.dart';
import 'base_datos.dart';

/// Corpus activo cargado desde la base de datos.
class CorpusPersistido {
	const CorpusPersistido({required this.version, required this.fragmentos});

	final String version;
	final List<FragmentoSEP> fragmentos;
}

/// Corpus de los libros SEP, retos, versiones de la base y actualizaciones USB.
/// Sin base de datos disponible, todos los metodos devuelven valores vacios.
class RepositorioCorpus {
	RepositorioCorpus(this._base);

	final BaseDatos _base;

	Database? get _db => _base.db;

	// ----------------------------------------------------------------- Carga

	/// Garantiza que exista una version activa y que todos los fragmentos del
	/// corpus precargado esten en la base. Solo agrega los que faltan: nunca pisa
	/// lo que ya existe, asi una actualizacion por USB no se pierde al abrir la app.
	Future<void> completarCorpusPrecargado(
		String codigoVersion,
		List<FragmentoSEP> precargados,
	) async {
		final Database? db = _db;
		if (db == null) {
			return;
		}
		await db.transaction((Transaction txn) async {
			final List<Map<String, Object?>> activas = await txn.query(
				'version_base',
				where: 'activa = 1',
				limit: 1,
			);
			final int idVersion = activas.isEmpty
				? await txn.insert('version_base', <String, Object?>{
					'codigo': codigoVersion,
					'origen': 'precargada',
					'fecha_instalacion': ahoraIso(),
					'activa': 1,
					'total_fragmentos': 0,
				})
				: aEntero(activas.first['id_version']);

			final List<Map<String, Object?>> existentes = await txn.query(
				'fragmento_sep',
				columns: <String>['clave'],
			);
			final Set<String> claves = <String>{
				for (final Map<String, Object?> f in existentes)
					(f['clave'] ?? '').toString(),
			};
			for (final FragmentoSEP f in precargados) {
				if (!claves.contains(f.idFragmento)) {
					await _insertarFragmento(txn, f, idVersion);
				}
			}
			await _actualizarTotal(txn, idVersion);
		});
	}

	/// Lee el corpus de la version activa, con su reto mas reciente por fragmento.
	/// Devuelve null si la base no esta disponible o aun no tiene corpus.
	Future<CorpusPersistido?> cargarCorpusActivo() async {
		final Database? db = _db;
		if (db == null) {
			return null;
		}
		final List<Map<String, Object?>> versiones = await db.query(
			'version_base',
			where: 'activa = 1',
			limit: 1,
		);
		if (versiones.isEmpty) {
			return null;
		}
		final List<Map<String, Object?>> filas = await db.query(
			'fragmento_sep',
			orderBy: 'id_fragmento',
		);
		if (filas.isEmpty) {
			return null;
		}

		// Reto mas reciente de cada fragmento y sus opciones en orden.
		final List<Map<String, Object?>> retos = await db.rawQuery(
			'SELECT r.id_reto, r.id_fragmento, r.pregunta FROM reto r '
			'WHERE r.id_reto = (SELECT MAX(r2.id_reto) FROM reto r2 '
			'WHERE r2.id_fragmento = r.id_fragmento)',
		);
		final List<Map<String, Object?>> opciones = await db.query(
			'opcion_reto',
			orderBy: 'id_reto, orden',
		);
		final Map<int, List<Map<String, Object?>>> opcionesPorReto =
			<int, List<Map<String, Object?>>>{};
		for (final Map<String, Object?> o in opciones) {
			opcionesPorReto
				.putIfAbsent(aEntero(o['id_reto']), () => <Map<String, Object?>>[])
				.add(o);
		}
		final Map<int, Map<String, Object?>> retoPorFragmento =
			<int, Map<String, Object?>>{
				for (final Map<String, Object?> r in retos)
					aEntero(r['id_fragmento']): r,
			};

		final List<FragmentoSEP> fragmentos = <FragmentoSEP>[];
		for (final Map<String, Object?> f in filas) {
			final Map<String, Object?>? reto =
				retoPorFragmento[aEntero(f['id_fragmento'])];
			final List<Map<String, Object?>> ops = reto == null
				? const <Map<String, Object?>>[]
				: (opcionesPorReto[aEntero(reto['id_reto'])] ??
					const <Map<String, Object?>>[]);
			int correcta = 0;
			for (int i = 0; i < ops.length; i++) {
				if (aEntero(ops[i]['es_correcta']) == 1) {
					correcta = i;
				}
			}
			fragmentos.add(
				FragmentoSEP(
					idFragmento: (f['clave'] ?? '').toString(),
					gradoNivel: aEntero(f['grado_nivel']),
					nombreLibro: (f['nombre_libro'] ?? '').toString(),
					bloqueTema: (f['bloque_tema'] ?? '').toString(),
					numeroPagina: aEntero(f['numero_pagina']),
					textoContenido: (f['palabras_clave'] ?? '').toString(),
					explicacion4to: (f['explicacion_4to'] ?? '').toString(),
					explicacion5to: (f['explicacion_5to'] ?? '').toString(),
					explicacion6to: (f['explicacion_6to'] ?? '').toString(),
					tipoIlustracion: (f['tipo_ilustracion'] ?? '').toString(),
					notaIlustracion: (f['nota_ilustracion'] ?? '').toString(),
					preguntaComprobacion: (reto?['pregunta'] ?? '').toString(),
					opcionesComprobacion: ops
						.map((Map<String, Object?> o) => (o['texto'] ?? '').toString())
						.toList(),
					indiceRespuestaCorrecta: correcta,
				),
			);
		}
		return CorpusPersistido(
			version: (versiones.first['codigo'] ?? '').toString(),
			fragmentos: fragmentos,
		);
	}

	// ------------------------------------------------------ Actualizacion USB

	/// Guarda una actualizacion por USB COMPLETA en una sola transaccion: crea la
	/// version nueva, agrega o modifica los fragmentos que cambiaron y registra la
	/// actualizacion en el historial. Si algo falla, SQLite deshace todo y se
	/// relanza el error para que quien llama restaure la version anterior.
	Future<void> registrarActualizacionUsb({
		required String rutaPaquete,
		required String versionNueva,
		required List<FragmentoSEP> fragmentos,
		required double duracionSeg,
	}) async {
		final Database? db = _db;
		if (db == null) {
			return;
		}
		await db.transaction((Transaction txn) async {
			final List<Map<String, Object?>> previas = await txn.query(
				'version_base',
				where: 'activa = 1',
				limit: 1,
			);
			final int? idAnterior =
				previas.isEmpty ? null : aEntero(previas.first['id_version']);

			await txn.update('version_base', <String, Object?>{'activa': 0});

			final List<Map<String, Object?>> mismas = await txn.query(
				'version_base',
				where: 'codigo = ?',
				whereArgs: <Object?>[versionNueva],
				limit: 1,
			);
			final int idNueva;
			if (mismas.isEmpty) {
				idNueva = await txn.insert('version_base', <String, Object?>{
					'codigo': versionNueva,
					'origen': 'usb',
					'fecha_instalacion': ahoraIso(),
					'activa': 1,
					'total_fragmentos': 0,
				});
			} else {
				idNueva = aEntero(mismas.first['id_version']);
				await txn.update(
					'version_base',
					<String, Object?>{
						'activa': 1,
						'origen': 'usb',
						'fecha_instalacion': ahoraIso(),
					},
					where: 'id_version = ?',
					whereArgs: <Object?>[idNueva],
				);
			}

			int cambios = 0;
			for (final FragmentoSEP f in fragmentos) {
				if (await _insertarOActualizarFragmento(txn, f, idNueva)) {
					cambios++;
				}
			}
			await _actualizarTotal(txn, idNueva);

			await txn.insert('actualizacion_usb', <String, Object?>{
				'id_version_anterior': idAnterior,
				'id_version_nueva': idNueva,
				'fecha': ahoraIso(),
				'ruta_paquete': rutaPaquete,
				'exitosa': 1,
				'mensaje': 'Actualización completada: $cambios fragmento(s) nuevo(s) o modificado(s).',
				'fragmentos_cargados': cambios,
				'duracion_seg': duracionSeg,
			});
		});
	}

	/// Deja constancia en el historial de un intento de actualizacion que fallo.
	Future<void> registrarActualizacionFallida({
		required String rutaPaquete,
		required String mensaje,
		required double duracionSeg,
	}) async {
		final Database? db = _db;
		if (db == null) {
			return;
		}
		final List<Map<String, Object?>> activas = await db.query(
			'version_base',
			where: 'activa = 1',
			limit: 1,
		);
		await db.insert('actualizacion_usb', <String, Object?>{
			'id_version_anterior':
				activas.isEmpty ? null : aEntero(activas.first['id_version']),
			'id_version_nueva': null,
			'fecha': ahoraIso(),
			'ruta_paquete': rutaPaquete,
			'exitosa': 0,
			'mensaje': mensaje,
			'fragmentos_cargados': 0,
			'duracion_seg': duracionSeg,
		});
	}

	/// Historial de actualizaciones, de la mas reciente a la mas antigua.
	Future<List<RegistroActualizacionUsb>> historialActualizaciones({
		int limite = 5,
	}) async {
		final Database? db = _db;
		if (db == null) {
			return const <RegistroActualizacionUsb>[];
		}
		final List<Map<String, Object?>> filas = await db.rawQuery(
			'SELECT a.fecha, a.exitosa, a.mensaje, a.fragmentos_cargados, '
			'a.duracion_seg, v.codigo AS version_nueva '
			'FROM actualizacion_usb a '
			'LEFT JOIN version_base v ON v.id_version = a.id_version_nueva '
			'ORDER BY a.id_actualizacion DESC LIMIT ?',
			<Object?>[limite],
		);
		return filas
			.map(
				(Map<String, Object?> f) => RegistroActualizacionUsb(
					fecha: DateTime.tryParse((f['fecha'] ?? '').toString()) ??
						DateTime.now(),
					exitosa: aEntero(f['exitosa']) == 1,
					mensaje: (f['mensaje'] ?? '').toString(),
					versionNueva: (f['version_nueva'] ?? '—').toString(),
					fragmentosCargados: aEntero(f['fragmentos_cargados']),
					duracionSeg: aDecimal(f['duracion_seg']),
				),
			)
			.toList();
	}

	// -------------------------------------------------------------- Internos

	Map<String, Object?> _valoresFragmento(FragmentoSEP f, int idVersion) {
		return <String, Object?>{
			'id_version': idVersion,
			'grado_nivel': f.gradoNivel.clamp(4, 6),
			'nombre_libro': f.nombreLibro,
			'bloque_tema': f.bloqueTema,
			'numero_pagina': f.numeroPagina,
			'palabras_clave': f.textoContenido,
			'explicacion_4to': f.explicacion4to,
			'explicacion_5to': f.explicacion5to,
			'explicacion_6to': f.explicacion6to,
			'tipo_ilustracion': f.tipoIlustracion,
			'nota_ilustracion': f.notaIlustracion,
		};
	}

	Future<int> _insertarFragmento(
		DatabaseExecutor ejecutor,
		FragmentoSEP f,
		int idVersion,
	) async {
		final int id = await ejecutor.insert('fragmento_sep', <String, Object?>{
			'clave': f.idFragmento,
			..._valoresFragmento(f, idVersion),
		});
		await _asegurarReto(ejecutor, id, f);
		return id;
	}

	/// Inserta el fragmento si no existe, o lo actualiza si su contenido cambio.
	/// Devuelve true si hubo algun cambio.
	Future<bool> _insertarOActualizarFragmento(
		DatabaseExecutor ejecutor,
		FragmentoSEP f,
		int idVersion,
	) async {
		final List<Map<String, Object?>> filas = await ejecutor.query(
			'fragmento_sep',
			where: 'clave = ?',
			whereArgs: <Object?>[f.idFragmento],
			limit: 1,
		);
		if (filas.isEmpty) {
			await _insertarFragmento(ejecutor, f, idVersion);
			return true;
		}
		final Map<String, Object?> actual = filas.first;
		final int id = aEntero(actual['id_fragmento']);
		final Map<String, Object?> nuevos = _valoresFragmento(f, idVersion);
		bool cambio = false;
		nuevos.forEach((String columna, Object? valor) {
			if (columna != 'id_version' && actual[columna] != valor) {
				cambio = true;
			}
		});
		if (cambio) {
			await ejecutor.update(
				'fragmento_sep',
				nuevos,
				where: 'id_fragmento = ?',
				whereArgs: <Object?>[id],
			);
		}
		final bool retoNuevo = await _asegurarReto(ejecutor, id, f);
		return cambio || retoNuevo;
	}

	/// Crea el reto del fragmento si todavia no existe uno con esa misma pregunta.
	/// Los retos anteriores se conservan para no perder las respuestas ya dadas.
	Future<bool> _asegurarReto(
		DatabaseExecutor ejecutor,
		int idFragmento,
		FragmentoSEP f,
	) async {
		if (f.preguntaComprobacion.trim().isEmpty ||
			f.opcionesComprobacion.isEmpty) {
			return false;
		}
		final List<Map<String, Object?>> existente = await ejecutor.query(
			'reto',
			columns: <String>['id_reto'],
			where: 'id_fragmento = ? AND pregunta = ?',
			whereArgs: <Object?>[idFragmento, f.preguntaComprobacion],
			limit: 1,
		);
		if (existente.isNotEmpty) {
			return false;
		}
		final int idReto = await ejecutor.insert('reto', <String, Object?>{
			'id_fragmento': idFragmento,
			'pregunta': f.preguntaComprobacion,
		});
		for (int i = 0; i < f.opcionesComprobacion.length; i++) {
			await ejecutor.insert('opcion_reto', <String, Object?>{
				'id_reto': idReto,
				'orden': i,
				'texto': f.opcionesComprobacion[i],
				'es_correcta': i == f.indiceRespuestaCorrecta ? 1 : 0,
			});
		}
		return true;
	}

	Future<void> _actualizarTotal(DatabaseExecutor ejecutor, int idVersion) async {
		final int total = aEntero(
			Sqflite.firstIntValue(
				await ejecutor.rawQuery('SELECT COUNT(*) FROM fragmento_sep'),
			),
		);
		await ejecutor.update(
			'version_base',
			<String, Object?>{'total_fragmentos': total},
			where: 'id_version = ?',
			whereArgs: <Object?>[idVersion],
		);
	}
}
