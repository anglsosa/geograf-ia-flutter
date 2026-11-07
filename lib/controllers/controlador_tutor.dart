import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/reglas.dart';
import '../models/modelos.dart';
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
	})  : _pipelineRAG = pipelineRAG ?? ServicioRAG(),
		_servicioAudio = servicioAudio ?? ServicioAudio(),
		_configuracionAula = configuracionAula ?? ConfiguracionAula() {
		_gestorUSB = gestorUSB ??
			GestorActualizacionUSB(
				almacenVectores: _pipelineRAG.baseVectores,
			);
		// Cada cambio del motor de IA (descarga, carga, listo, error) refresca la UI.
		_pipelineRAG.motorLLM.addListener(notifyListeners);
	}

	bool _liberado = false;

	/// Arranque de la app: detecta si el modelo de IA ya esta instalado y lo
	/// carga en memoria en segundo plano (no bloquea la interfaz).
	Future<void> iniciar() async {
		await _pipelineRAG.motorLLM.inicializar();
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
		notifyListeners();
	}

	/// Metodo oficial del UML: +reiniciarContextoSesion() : void (RF-09)
	void reiniciarContextoSesion() {
		_pipelineRAG.motorLLM.cancelarGeneracion();
		_servicioAudio.cancelarEscucha();
		_servicioAudio.detenerAudio();
		_mensajes.clear();
		_estadoMascota = EstadoMascota.reposo;
		_ocupado = false;
		notifyListeners();
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
	Future<void> enviarPregunta(String texto) async {
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
			_mensajes.add(
				MensajeChat(
					id: idRespuesta,
					rol: RolMensaje.tutor,
					texto: resultado.textoRespuesta,
					citaFuente: resultado.obtenerCitaOficial(),
					esRemisionMaestro: resultado.esRemisionAlMaestro(),
					tiempoMs: resultado.tiempoInferenciaMs,
					tipoIlustracion: resultado.tipoIlustracion,
					notaIlustracion: resultado.notaIlustracion,
					generadoPorIA: resultado.generadoPorIA,
				),
			);

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
		await enviarPregunta(reconocida);
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
				notifyListeners();
				break;
			}
		}
	}

	void _registrarReciente(String pregunta) {
		_consultasRecientes.remove(pregunta);
		_consultasRecientes.insert(0, pregunta);
		if (_consultasRecientes.length > 6) {
			_consultasRecientes.removeLast();
		}
	}
}

