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
	int _consultasExitosasEnSesion = 0;
	int _retosCorrectos = 0;
	int _retosTotales = 0;

	ServicioRAG get pipelineRAG => _pipelineRAG;
	ServicioAudio get servicioAudio => _servicioAudio;
	ConfiguracionAula get configuracion => _configuracionAula;
	GestorActualizacionUSB get gestorUSB => _gestorUSB;
	EstadoMascota get estado => _estadoMascota;
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
		_servicioAudio.detenerAudio();
		_mensajes.clear();
		_estadoMascota = EstadoMascota.reposo;
		_ocupado = false;
		notifyListeners();
	}

	/// Metodo oficial del UML: +procesarConsulta(preguntaEntrada: String) : ResultadoConsulta
	Future<ResultadoConsulta> procesarConsulta(String preguntaEntrada) async {
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

		try {
			final ResultadoConsulta resultado = await procesarConsulta(pregunta);

			_mensajes.add(
				MensajeChat(
					id: 'msg-${DateTime.now().microsecondsSinceEpoch}-bot',
					rol: RolMensaje.tutor,
					texto: resultado.textoRespuesta,
					citaFuente: resultado.obtenerCitaOficial(),
					esRemisionMaestro: resultado.esRemisionAlMaestro(),
					tiempoMs: resultado.tiempoInferenciaMs,
					tipoIlustracion: resultado.tipoIlustracion,
					notaIlustracion: resultado.notaIlustracion,
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
		} catch (_) {
			_mensajes.add(
				MensajeChat(
					id: 'msg-${DateTime.now().microsecondsSinceEpoch}-err',
					rol: RolMensaje.tutor,
					texto: Reglas.mensajeConsultaAlMaestro,
					esRemisionMaestro: true,
				),
			);
		} finally {
			_estadoMascota = EstadoMascota.reposo;
			_ocupado = false;
			notifyListeners();
		}
	}

	/// RF-01 y RNF-08: Consulta por voz sin conexion.
	Future<void> preguntarPorVoz({String? fraseSimulada}) async {
		if (_ocupado) {
			return;
		}
		_estadoMascota = EstadoMascota.escuchando;
		notifyListeners();

		final String reconocida = await _servicioAudio.vozATexto(
			const <int>[],
			fraseForzada: fraseSimulada,
		);
		_estadoMascota = EstadoMascota.reposo;
		notifyListeners();

		if (reconocida.isNotEmpty) {
			await enviarPregunta(reconocida);
		}
	}

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

