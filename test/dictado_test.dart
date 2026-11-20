import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geograf_ia/services/servicios.dart';
import 'package:geograf_ia/controllers/controlador_tutor.dart';
import 'package:geograf_ia/models/modelos.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class ReconocedorPrueba extends SpeechToText {
	ReconocedorPrueba() : super.withMethodChannel();
	void Function(String)? estado;
	void Function(SpeechRecognitionResult)? resultado;
	Completer<void> inicio = Completer<void>();
	bool disponible = true;
	@override
	Future<bool> initialize({onError, onStatus, debugLogging = false,
		Duration finalTimeout = const Duration(seconds: 2), options}) async {
		estado = onStatus;
		return disponible;
	}
	@override
	Future<List<LocaleName>> locales() async => [LocaleName('es_MX', 'Español')];
	@override
	Future listen({onResult, listenFor, pauseFor, localeId, onSoundLevelChange,
		cancelOnError = false, partialResults = true, onDevice = false,
		listenMode = ListenMode.confirmation, sampleRate = 0, listenOptions}) async {
		resultado = onResult;
		if (!inicio.isCompleted) inicio.complete();
	}
	@override
	Future<void> stop() async {}
	@override
	Future<void> cancel() async {}
	void emitir(String texto, {bool finalizado = false}) => resultado?.call(
		SpeechRecognitionResult([SpeechRecognitionWords(texto, null, 1)], finalizado ? 2 : 0));
}

void main() {
	test('dictado final llega al chat como pregunta y obtiene respuesta', () async {
		final reconocedor = ReconocedorPrueba();
		final audio = ServicioAudio(estaListoTTS: false, reconocedor: reconocedor);
		final tutor = ControladorTutor(servicioAudio: audio,
			configuracionAula: ConfiguracionAula(vozAutomatica: false));
		final captura = tutor.preguntarPorVoz();
		await reconocedor.inicio.future;
		reconocedor.emitir('¿Por qué llueve?', finalizado: true);
		await captura;
		expect(tutor.mensajes.first.texto, '¿Por qué llueve?');
		expect(tutor.mensajes.last.rol, RolMensaje.tutor);
		expect(tutor.errorVoz, isEmpty);
	});
	test('Listo devuelve el parcial aunque Android no envíe done', () async {
		final reconocedor = ReconocedorPrueba();
		final audio = ServicioAudio(estaListoTTS: false, reconocedor: reconocedor);
		final captura = audio.escucharPregunta();
		await reconocedor.inicio.future;
		reconocedor.emitir('¿Cómo se forma un volcán?');
		await audio.detenerEscucha();
		expect(await captura.timeout(const Duration(seconds: 1)), '¿Cómo se forma un volcán?');
		expect(audio.escuchando, isFalse);
	});

	test('done retrasado de una captura no termina la siguiente', () async {
		final reconocedor = ReconocedorPrueba();
		final audio = ServicioAudio(estaListoTTS: false, reconocedor: reconocedor);
		final primera = audio.escucharPregunta();
		await reconocedor.inicio.future;
		reconocedor.estado?.call('done');
		reconocedor.emitir('ríos', finalizado: true);
		expect(await primera, 'ríos');
		reconocedor.inicio = Completer<void>();
		var terminada = false;
		final segunda = audio.escucharPregunta().then((texto) { terminada = true; return texto; });
		await reconocedor.inicio.future;
		await Future<void>.delayed(const Duration(milliseconds: 450));
		expect(terminada, isFalse);
		reconocedor.emitir('volcanes', finalizado: true);
		expect(await segunda, 'volcanes');
	});

	test('permiso o reconocedor no disponible comunica el problema', () async {
		final reconocedor = ReconocedorPrueba()..disponible = false;
		final audio = ServicioAudio(estaListoTTS: false, reconocedor: reconocedor);
		expect(await audio.escucharPregunta(), isEmpty);
		expect(audio.ultimoErrorVoz, contains('permiso'));
	});
}
