import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/reglas.dart';
import '../data/persistencia.dart';
import '../data/repositorio_corpus.dart';
import '../models/entidades_db.dart';
import '../models/modelos.dart';
import '../services/corpus_sep_oficial.dart';
import '../services/servicios.dart';

/// Controlador principal de la sesion tutor-alumno (9_UML.pdf).
/// Orquesta ServicioRAG, ServicioAudio y ConfiguracionAula bajo reglas
/// estrictas para impedir fallos por uso infantil.
class ControladorTutor extends ChangeNotifier {
	ControladorTutor({
		ServicioRAG? pipelineRAG,
		ServicioAudio? servicioAudio,
		ConfiguracionAula? configuracionAula,
		GestorActualizacionUSB? gestorUSB,
		Persistencia? persistencia,
	})  : _pipelineRAG = pipelineRAG ?? ServicioRAG(),
		_servicioAudio = servicioAudio ?? ServicioAudio(),
		_configuracionAula = configuracionAula ?? ConfiguracionAula(),
		_persistencia = persistencia,
		_persistenciaInyectada = persistencia != null {
		_gestorUSB = gestorUSB ??
			GestorActualizacionUSB(
				almacenVectores: _pipelineRAG.baseVectores,
			);
		// Cada cambio del motor de IA (descarga, carga, listo, error) refresca la UI.
		_pipelineRAG.motorLLM.addListener(notifyListeners);
	}

	bool _liberado = false;

	// ------------------------------------------------------------ Persistencia

	Persistencia? _persistencia;
	final bool _persistenciaInyectada;
	Grupo? _grupo;
	Alumno? _alumno;
	int? _idConversacion;
	List<Grupo> _grupos = <Grupo>[];
	List<Alumno> _alumnos = <Alumno>[];
	List<ConversacionResumen> _conversaciones = <ConversacionResumen>[];

	/// Acceso a la base de datos local. Sin base disponible (pruebas, navegador)
	/// devuelve una persistencia vacia y la app funciona sin guardar historial.
	Persistencia get persistencia => _persistencia ??= Persistencia.sinBaseDatos();

	bool get hayBaseDatos => persistencia.disponible;
	Grupo? get grupoActivo => _grupo;
	Alumno? get alumnoActivo => _alumno;
	List<Grupo> get grupos => List<Grupo>.unmodifiable(_grupos);
	List<Alumno> get alumnos => List<Alumno>.unmodifiable(_alumnos);
	List<ConversacionResumen> get conversacionesRecientes =>
		List<ConversacionResumen>.unmodifiable(_conversaciones);

	/// Arranque de la app: abre la base de datos, carga el corpus y los ajustes
	/// guardados, y detecta si el modelo de IA ya esta instalado para cargarlo
	/// en segundo plano (no bloquea la interfaz).
	Future<void> iniciar() async {
		await _iniciarPersistencia();
		await _pipelineRAG.motorLLM.inicializar();
	}

	Future<void> _iniciarPersistencia() async {
		try {
			if (!_persistenciaInyectada) {
				_persistencia = await Persistencia.abrir();
			}
			final Persistencia p = persistencia;
			if (!p.disponible) {
				return;
			}
			// El corpus vive en la base: solo se agregan los temas que falten.
			await p.corpus.completarCorpusPrecargado(
				CorpusSepOficial.versionInicial,
				CorpusSepOficial.fragmentosIniciales,
			);
			final CorpusPersistido? corpus = await p.corpus.cargarCorpusActivo();
			if (corpus != null) {
				_pipelineRAG.baseVectores.reemplazarCorpus(
					corpus.fragmentos,
					corpus.version,
				);
			}
			await _recargarGrupos();
			if (_grupos.isEmpty) {
				await p.aula.crearGrupo('Grupo 1');
				await _recargarGrupos();
			}
			if (_grupos.isNotEmpty) {
				_grupo = _grupos.first;
				await _aplicarConfiguracionDelGrupo();
				await _recargarAlumnos();
				await _refrescarConversaciones();
			}
			notifyListeners();
		} catch (e) {
			debugPrint('[ControladorTutor] No se pudo iniciar la base de datos: $e');
		}
	}

	Future<void> _recargarGrupos() async {
		_grupos = await persistencia.aula.listarGrupos();
	}

	Future<void> _recargarAlumnos() async {
		final Grupo? g = _grupo;
		_alumnos = g == null
			? <Alumno>[]
			: await persistencia.aula.listarAlumnos(g.id);
	}

	Future<void> _refrescarConversaciones() async {
		final Grupo? g = _grupo;
		if (g == null || !persistencia.disponible) {
			return;
		}
		try {
			_conversaciones = await persistencia.conversaciones.recientes(g.id);
			notifyListeners();
		} catch (e) {
			debugPrint('[ControladorTutor] No se pudo leer el historial: $e');
		}
	}

	Future<void> _aplicarConfiguracionDelGrupo() async {
		final Grupo? g = _grupo;
		if (g == null) {
			return;
		}
		final ConfiguracionAula? guardada =
			await persistencia.aula.cargarConfiguracion(g.id);
		if (guardada != null) {
			_configuracionAula.aplicarDesde(guardada);
		}
	}

	void _guardarConfiguracion() {
		final Grupo? g = _grupo;
		if (g == null || !persistencia.disponible) {
			return;
		}
		unawaited(
			persistencia.aula
				.guardarConfiguracion(g.id, _configuracionAula)
				.catchError((Object e) {
					debugPrint('[ControladorTutor] No se guardo la configuracion: $e');
				}),
		);
	}

	@override
	void notifyListeners() {
		if (!_liberado) {
			super.notifyListeners();
		}
	}

	@override
	void dispose() {
		_liberado = true;
		_pipelineRAG.motorLLM.removeListener(notifyListeners);
		_pipelineRAG.motorLLM.dispose();
		unawaited(_persistencia?.cerrar() ?? Future<void>.value());
		super.dispose();
	}

	final ServicioRAG _pipelineRAG;
	final ServicioAudio _servicioAudio;
	final ConfiguracionAula _configuracionAula;
	late final GestorActualizacionUSB _gestorUSB;

	EstadoMascota _estadoMascota = EstadoMascota.reposo;
	final List<MensajeChat> _mensajes = <MensajeChat>[];
	final List<String> _consultasRecientes = <String>[
		'¿Cómo se forma un volcán?',
		'Estados de México',
		'Continentes del mundo',
	];

	DateTime? _ultimaConsulta;
	bool _ocupado = false;
	String _textoVozParcial = '';
	String _errorVoz = '';
	int _consultasExitosasEnSesion = 0;
	int _retosCorrectos = 0;
	int _retosTotales = 0;

	ServicioRAG get pipelineRAG => _pipelineRAG;
	ServicioAudio get servicioAudio => _servicioAudio;
	ConfiguracionAula get configuracion => _configuracionAula;
	GestorActualizacionUSB get gestorUSB => _gestorUSB;
	EstadoMascota get estado => _estadoMascota;

	/// Lo que el reconocedor de voz va entendiendo mientras el nino habla.
	String get textoVozParcial => _textoVozParcial;

	/// Ultimo problema de voz (permiso, sin espanol, no se entendio...).
	String get errorVoz => _errorVoz;

	/// Marca el error de voz como ya mostrado.
	void limpiarErrorVoz() {
		_errorVoz = '';
	}
	List<MensajeChat> get mensajes => List<MensajeChat>.unmodifiable(_mensajes);
	List<String> get consultasRecientes =>
		List<String>.unmodifiable(_consultasRecientes);
	bool get ocupado => _ocupado;
	int get consultasExitosasEnSesion => _consultasExitosasEnSesion;
	int get retosCorrectos => _retosCorrectos;
	int get retosTotales => _retosTotales;

	/// Sanea y valida estrictamente la entrada de texto del alumno.
	static String? sanear(String entrada) {
		final String limpio = entrada.replaceAll(RegExp(r'\s+'), ' ').trim();
		if (limpio.length < Reglas.minCaracteresPregunta) {
			return null;
		}
		if (limpio.length > Reglas.maxCaracteresPregunta) {
			return limpio.substring(0, Reglas.maxCaracteresPregunta);
		}
		return limpio;
	}

	bool _pasaFiltroAntiSpam() {
		final DateTime ahora = DateTime.now();
		final DateTime? previa = _ultimaConsulta;
		if (previa != null &&
			ahora.difference(previa) < Reglas.pausaEntreConsultas) {
			return false;
		}
		_ultimaConsulta = ahora;
		return true;
	}

	/// Metodo oficial del UML: +establecerGradoEscolar(grado: Integer) : void (RF-08)
	void establecerGradoEscolar(int grado) {
		if (!Reglas.gradosSoportados.contains(grado)) {
			return;
		}
		_configuracionAula.fijarGrado(grado);
		_guardarConfiguracion();
		notifyListeners();
	}

	/// Alias compatible con pruebas unitarias previas.
	void establecerGrado(int grado) => establecerGradoEscolar(grado);

	void actualizarPreferencias({
		int? grado,
		double? velocidadVoz,
		int? tamanoTexto,
		bool? altoContraste,
		bool? vozAutomatica,
	}) {
		if (grado != null && Reglas.gradosSoportados.contains(grado)) {
			_configuracionAula.fijarGrado(grado);
		}
		if (velocidadVoz != null) {
			_configuracionAula.fijarVelocidadLectura(velocidadVoz);
		}
		if (tamanoTexto != null) {
			_configuracionAula.fijarTamanoFuente(tamanoTexto);
		}
		if (altoContraste != null) {
			_configuracionAula.altoContraste = altoContraste;
		}
		if (vozAutomatica != null) {
			_configuracionAula.vozAutomatica = vozAutomatica;
		}
		_guardarConfiguracion();
		notifyListeners();
	}

	/// Metodo oficial del UML: +reiniciarContextoSesion() : void (RF-09)
	void reiniciarContextoSesion() {
		_pipelineRAG.motorLLM.cancelarGeneracion();
		_servicioAudio.cancelarEscucha();
		_servicioAudio.detenerAudio();
		_cerrarConversacionActual();
		_mensajes.clear();
		_estadoMascota = EstadoMascota.reposo;
		_ocupado = false;
		notifyListeners();
	}

	/// Cierra la conversacion en curso; la siguiente pregunta abrira una nueva.
	void _cerrarConversacionActual() {
		final int? id = _idConversacion;
		_idConversacion = null;
		if (id == null || !persistencia.disponible) {
			return;
		}
		unawaited(
			persistencia.conversaciones
				.cerrarConversacion(id)
				.catchError((Object e) {
					debugPrint('[ControladorTutor] No se cerro la conversacion: $e');
				})
				.then((_) => _refrescarConversaciones()),
		);
	}

	/// Metodo oficial del UML: +procesarConsulta(preguntaEntrada: String) : ResultadoConsulta
	Future<ResultadoConsulta> procesarConsulta(
		String preguntaEntrada, {
		void Function(String parcial)? alTextoParcial,
	}) async {
		final String? pregunta = sanear(preguntaEntrada);
		if (pregunta == null) {
			return const ResultadoConsulta(
				textoRespuesta: Reglas.mensajeConsultaAlMaestro,
				fuenteEncontrada: false,
			);
		}
		return _pipelineRAG
			.generarRespuestaFundamentada(
				pregunta,
				_configuracionAula.obtenerGrado(),
				alTextoParcial: alTextoParcial,
			)
			.timeout(Reglas.tiempoMaximoRespuesta);
	}

	/// Envia una pregunta desde la UI, actualiza burbujas, mascota y TTS.
	Future<void> enviarPregunta(String texto, {bool porVoz = false}) async {
		if (_ocupado || !_pasaFiltroAntiSpam()) {
			return;
		}
		final String? pregunta = sanear(texto);
		if (pregunta == null) {
			return;
		}

		_ocupado = true;
		_registrarReciente(pregunta);
		_mensajes.add(
			MensajeChat(
				id: 'msg-${DateTime.now().microsecondsSinceEpoch}-usr',
				rol: RolMensaje.alumno,
				texto: pregunta,
			),
		);
		_estadoMascota = EstadoMascota.pensando;
		notifyListeners();

		// Respuesta que se va escribiendo en pantalla mientras el LLM genera.
		final String idRespuesta =
			'msg-${DateTime.now().microsecondsSinceEpoch}-bot';
		MensajeChat? burbujaParcial;

		try {
			final ResultadoConsulta resultado = await procesarConsulta(
				pregunta,
				alTextoParcial: (String parcial) {
					if (_liberado || parcial.trim().isEmpty) {
						return;
					}
					final MensajeChat? actual = burbujaParcial;
					if (actual == null) {
						final MensajeChat nueva = MensajeChat(
							id: idRespuesta,
							rol: RolMensaje.tutor,
							texto: parcial,
							generadoPorIA: true,
							enProgreso: true,
						);
						burbujaParcial = nueva;
						_mensajes.add(nueva);
					} else {
						actual.texto = parcial;
					}
					notifyListeners();
				},
			);

			// Reemplaza la burbuja en progreso por la respuesta final con su cita.
			final MensajeChat? parcialPrevio = burbujaParcial;
			if (parcialPrevio != null) {
				_mensajes.remove(parcialPrevio);
			}
			final MensajeChat mensajeFinal = MensajeChat(
				id: idRespuesta,
				rol: RolMensaje.tutor,
				texto: resultado.textoRespuesta,
				citaFuente: resultado.obtenerCitaOficial(),
				esRemisionMaestro: resultado.esRemisionAlMaestro(),
				tiempoMs: resultado.tiempoInferenciaMs,
				tipoIlustracion: resultado.tipoIlustracion,
				notaIlustracion: resultado.notaIlustracion,
				generadoPorIA: resultado.generadoPorIA,
				claveFragmento: resultado.fragmentoAsociado?.idFragmento ?? '',
			);
			_mensajes.add(mensajeFinal);
			await _guardarConsulta(pregunta, resultado, mensajeFinal, porVoz);

			// Si hubo fuente SEP valida, verificar si toca lanzar reto pedagogico
			if (resultado.fuenteEncontrada &&
				resultado.fragmentoAsociado != null) {
				_consultasExitosasEnSesion++;
				final FragmentoSEP frag = resultado.fragmentoAsociado!;
				if (frag.preguntaComprobacion.isNotEmpty &&
					_consultasExitosasEnSesion %
							Reglas.consultasParaRetoPedagogico ==
						0) {
					_mensajes.add(
						MensajeChat(
							id: 'msg-${DateTime.now().microsecondsSinceEpoch}-quiz',
							rol: RolMensaje.retoPedagogico,
							texto: '¡Reto rápido para comprobar lo aprendido!',
							preguntaReto: frag.preguntaComprobacion,
							opcionesReto: frag.opcionesComprobacion,
							indiceCorrectoReto: frag.indiceRespuestaCorrecta,
							citaFuente: frag.obtenerMetadatos(),
							claveFragmento: frag.idFragmento,
						),
					);
				}
			}

			if (_configuracionAula.vozAutomatica) {
				_estadoMascota = EstadoMascota.hablando;
				notifyListeners();
				await _servicioAudio.textoAVoz(
					resultado.textoRespuesta,
					_configuracionAula.velocidadLecturaVoz,
				);
			}
		} catch (e) {
			// Un fallo tecnico NO es lo mismo que "no esta en los libros": se le
			// dice al nino que reintente en lugar de mandarlo al maestro sin motivo.
			debugPrint('[ControladorTutor] Error al procesar la consulta: $e');
			final MensajeChat? parcialPrevio = burbujaParcial;
			if (parcialPrevio != null) {
				_mensajes.remove(parcialPrevio);
			}
			_mensajes.add(
				MensajeChat(
					id: 'msg-${DateTime.now().microsecondsSinceEpoch}-err',
					rol: RolMensaje.tutor,
					texto: e is TimeoutException
						? 'Me tardé demasiado en pensar la respuesta. '
							'¿Puedes intentar de nuevo con una pregunta más corta?'
						: 'Uy, tuve un problema para responder. '
							'¿Puedes intentar de nuevo en un momento?',
				),
			);
		} finally {
			_estadoMascota = EstadoMascota.reposo;
			_ocupado = false;
			notifyListeners();
		}
	}

	/// RF-01 y RNF-08: Consulta por voz. Escucha por el microfono, muestra lo que
	/// va entendiendo ([textoVozParcial]) y al terminar envia la pregunta.
	/// [fraseSimulada] solo se usa en pruebas; en la app real siempre se escucha.
	Future<void> preguntarPorVoz({String? fraseSimulada}) async {
		if (_ocupado || _estadoMascota == EstadoMascota.escuchando) {
			return;
		}
		_errorVoz = '';
		_textoVozParcial = '';
		// Callar al tutor antes de abrir el microfono, para que no se escuche a si mismo.
		await _servicioAudio.detenerAudio();
		_estadoMascota = EstadoMascota.escuchando;
		notifyListeners();

		String reconocida;
		try {
			reconocida = fraseSimulada != null
				? fraseSimulada.trim()
				: await _servicioAudio.escucharPregunta(
					alParcial: (String parcial) {
						_textoVozParcial = parcial;
						notifyListeners();
					},
				);
		} catch (e) {
			debugPrint('[ControladorTutor] Error de voz: $e');
			reconocida = '';
		}

		_estadoMascota = EstadoMascota.reposo;
		_textoVozParcial = '';
		if (reconocida.isEmpty) {
			_errorVoz = _servicioAudio.ultimoErrorVoz.isNotEmpty
				? _servicioAudio.ultimoErrorVoz
				: 'No te escuché. Toca el micrófono y habla de nuevo.';
			notifyListeners();
			return;
		}
		notifyListeners();
		await enviarPregunta(reconocida, porVoz: fraseSimulada == null);
	}

	/// El nino termino de hablar: procesa de inmediato lo que se alcanzo a entender.
	Future<void> detenerEscucha() => _servicioAudio.detenerEscucha();

	/// RF-04: Reproducir en voz alta cualquier respuesta mostrada.
	Future<void> reproducirRespuestaVoz(String texto) async {
		if (_ocupado) {
			return;
		}
		_estadoMascota = EstadoMascota.hablando;
		notifyListeners();
		await _servicioAudio.textoAVoz(
			texto,
			_configuracionAula.velocidadLecturaVoz,
		);
		_estadoMascota = EstadoMascota.reposo;
		notifyListeners();
	}

	/// Registra la respuesta del alumno al reto pedagogico de comprobacion.
	void responderRetoPedagogico(String idMensaje, int indiceOpcion) {
		for (final MensajeChat m in _mensajes) {
			if (m.id == idMensaje && m.opcionSeleccionadaReto == null) {
				m.opcionSeleccionadaReto = indiceOpcion;
				_retosTotales++;
				if (indiceOpcion == m.indiceCorrectoReto) {
					_retosCorrectos++;
				}
				if (persistencia.disponible && m.claveFragmento.isNotEmpty) {
					unawaited(
						persistencia.conversaciones
							.registrarRespuestaReto(
								claveFragmento: m.claveFragmento,
								indiceOpcion: indiceOpcion,
								idAlumno: _alumno?.id,
								idConversacion: _idConversacion,
							)
							.catchError((Object e) {
								debugPrint('[ControladorTutor] No se guardo el reto: $e');
							}),
					);
				}
				notifyListeners();
				break;
			}
		}
	}

	// ---------------------------------------------- Guardado en base de datos

	/// Abre la conversacion si todavia no existe y devuelve su id.
	Future<int?> _asegurarConversacion(String primeraPregunta) async {
		final Grupo? g = _grupo;
		if (g == null || !persistencia.disponible) {
			return null;
		}
		final int? existente = _idConversacion;
		if (existente != null) {
			return existente;
		}
		final String titulo = primeraPregunta.length > 40
			? '${primeraPregunta.substring(0, 40)}…'
			: primeraPregunta;
		final int? nueva = await persistencia.conversaciones.crearConversacion(
			idGrupo: g.id,
			idAlumno: _alumno?.id,
			titulo: titulo,
		);
		_idConversacion = nueva;
		return nueva;
	}

	/// Guarda la consulta y su respuesta. Un fallo de la base NUNCA debe afectar
	/// lo que ve el nino: solo se registra en consola.
	Future<void> _guardarConsulta(
		String pregunta,
		ResultadoConsulta resultado,
		MensajeChat mensaje,
		bool porVoz,
	) async {
		try {
			final int? idConversacion = await _asegurarConversacion(pregunta);
			if (idConversacion == null) {
				return;
			}
			mensaje.idConsulta = await persistencia.conversaciones.guardarConsulta(
				idConversacion: idConversacion,
				pregunta: pregunta,
				respuesta: resultado.textoRespuesta,
				grado: _configuracionAula.obtenerGrado(),
				porVoz: porVoz,
				remitidaMaestro: resultado.esRemisionAlMaestro(),
				generadaPorIA: resultado.generadoPorIA,
				similitud: resultado.similitudAlcanzada,
				tiempoMs: resultado.tiempoInferenciaMs,
				claveFragmento: resultado.fragmentoAsociado?.idFragmento,
			);
			unawaited(_refrescarConversaciones());
		} catch (e) {
			debugPrint('[ControladorTutor] No se guardo la consulta: $e');
		}
	}

	/// El nino indica si le quedo clara la respuesta (meta: 80 % de dudas resueltas).
	Future<void> valorarRespuesta(String idMensaje, bool clara) async {
		for (final MensajeChat m in _mensajes) {
			if (m.id == idMensaje) {
				m.quedoClara = clara;
				notifyListeners();
				final int? idConsulta = m.idConsulta;
				if (idConsulta != null && persistencia.disponible) {
					try {
						await persistencia.conversaciones.marcarQuedoClara(idConsulta, clara);
					} catch (e) {
						debugPrint('[ControladorTutor] No se guardo la valoracion: $e');
					}
				}
				break;
			}
		}
	}

	/// Vuelve a mostrar una conversacion guardada para retomarla (RF-09).
	Future<void> abrirConversacion(int idConversacion) async {
		if (_ocupado || !persistencia.disponible) {
			return;
		}
		try {
			final List<ConsultaGuardada> consultas =
				await persistencia.conversaciones.consultasDe(idConversacion);
			if (consultas.isEmpty) {
				return;
			}
			_pipelineRAG.motorLLM.cancelarGeneracion();
			_servicioAudio.cancelarEscucha();
			_servicioAudio.detenerAudio();
			if (_idConversacion != idConversacion) {
				_cerrarConversacionActual();
			}
			_mensajes.clear();
			for (final ConsultaGuardada c in consultas) {
				_mensajes.add(
					MensajeChat(
						id: 'db-${c.id}-usr',
						rol: RolMensaje.alumno,
						texto: c.pregunta,
					),
				);
				_mensajes.add(
					MensajeChat(
						id: 'db-${c.id}-bot',
						rol: RolMensaje.tutor,
						texto: c.respuesta,
						citaFuente: c.cita,
						esRemisionMaestro: c.remitidaMaestro,
						tiempoMs: c.tiempoMs,
						tipoIlustracion: c.tipoIlustracion,
						notaIlustracion: c.notaIlustracion,
						generadoPorIA: c.generadaPorIA,
						idConsulta: c.id,
						quedoClara: c.quedoClara,
						claveFragmento: c.claveFragmento,
					),
				);
			}
			_idConversacion = idConversacion;
			_estadoMascota = EstadoMascota.reposo;
			notifyListeners();
		} catch (e) {
			debugPrint('[ControladorTutor] No se pudo abrir la conversacion: $e');
		}
	}

	// ---------------------------------------------------- Grupos y alumnos

	/// Cambia de grupo: carga sus ajustes y empieza una conversacion nueva.
	Future<void> seleccionarGrupo(Grupo grupo) async {
		if (!persistencia.disponible) {
			return;
		}
		try {
			await persistencia.aula.marcarGrupoEnUso(grupo.id);
			_grupo = grupo;
			_alumno = null;
			_cerrarConversacionActual();
			_mensajes.clear();
			await _aplicarConfiguracionDelGrupo();
			await _recargarGrupos();
			await _recargarAlumnos();
			_conversaciones = <ConversacionResumen>[];
			await _refrescarConversaciones();
			notifyListeners();
		} catch (e) {
			debugPrint('[ControladorTutor] No se pudo cambiar de grupo: $e');
		}
	}

	Future<void> crearGrupo(String nombre) async {
		if (!persistencia.disponible) {
			return;
		}
		try {
			final Grupo? nuevo = await persistencia.aula.crearGrupo(nombre);
			if (nuevo != null) {
				await seleccionarGrupo(nuevo);
			}
		} catch (e) {
			debugPrint('[ControladorTutor] No se pudo crear el grupo: $e');
		}
	}

	/// Selecciona el alumno que usa el dispositivo ahora (null = invitado).
	void seleccionarAlumno(Alumno? alumno) {
		if (_alumno?.id == alumno?.id) {
			return;
		}
		_alumno = alumno;
		_cerrarConversacionActual();
		_mensajes.clear();
		notifyListeners();
	}

	Future<void> agregarAlumno() async {
		final Grupo? g = _grupo;
		if (g == null || !persistencia.disponible) {
			return;
		}
		try {
			await persistencia.aula.agregarAlumno(g.id);
			await _recargarAlumnos();
			notifyListeners();
		} catch (e) {
			debugPrint('[ControladorTutor] No se pudo agregar el alumno: $e');
		}
	}

	Future<void> darDeBajaAlumno(Alumno alumno) async {
		if (!persistencia.disponible) {
			return;
		}
		try {
			await persistencia.aula.darDeBajaAlumno(alumno.id);
			if (_alumno?.id == alumno.id) {
				seleccionarAlumno(null);
			}
			await _recargarAlumnos();
			notifyListeners();
		} catch (e) {
			debugPrint('[ControladorTutor] No se pudo dar de baja al alumno: $e');
		}
	}

	/// Indicadores del grupo activo o, con [soloAlumno], del alumno seleccionado.
	Future<ResumenEstadisticas> cargarEstadisticas({bool soloAlumno = false}) async {
		final Grupo? g = _grupo;
		if (g == null || !persistencia.disponible) {
			return const ResumenEstadisticas();
		}
		return persistencia.conversaciones.estadisticas(
			g.id,
			idAlumno: soloAlumno ? _alumno?.id : null,
		);
	}

	/// Ultimas actualizaciones de la base de conocimiento por USB.
	Future<List<RegistroActualizacionUsb>> historialActualizacionesUsb() async {
		if (!persistencia.disponible) {
			return const <RegistroActualizacionUsb>[];
		}
		return persistencia.corpus.historialActualizaciones(limite: 3);
	}

	void _registrarReciente(String pregunta) {
		_consultasRecientes.remove(pregunta);
		_consultasRecientes.insert(0, pregunta);
		if (_consultasRecientes.length > 6) {
			_consultasRecientes.removeLast();
		}
	}
}

