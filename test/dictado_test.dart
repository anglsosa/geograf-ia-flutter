import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geograf_ia/services/servicios.dart';
import 'package:geograf_ia/controllers/controlador_tutor.dart';
import 'package:geograf_ia/models/modelos.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

class ReconocedorPrueba extends SpeechToText {
	ReconocedorPrueba() : super.withMethodChannel();
	void Function(String)? estado;
	void Function(SpeechRecognitionResult)? resultado;
	Completer<void> inicio = Completer<void>();
	bool disponible = true;
	bool sinPaqueteOffline = false;
	void Function(SpeechRecognitionError)? error;
	final opciones = <SpeechListenOptions>[];
	final pausas = <Duration>[];
	Completer<void> inicioNormal = Completer<void>();
	int cancelaciones = 0;
	@override
	Future<bool> initialize({onError, onStatus, debugLogging = false,
		Duration finalTimeout = const Duration(seconds: 2), options}) async {
		estado = onStatus;
		error = onError;
		return disponible;
	}
	@override
	Future<List<LocaleName>> locales() async => [LocaleName('es_MX', 'Español')];
	@override
	Future listen({onResult, listenFor, pauseFor, localeId, onSoundLevelChange,
		cancelOnError = false, partialResults = true, onDevice = false,
		listenMode = ListenMode.confirmation, sampleRate = 0, listenOptions}) async {
		resultado = onResult;
		if (listenOptions != null) opciones.add(listenOptions);
		if (!inicio.isCompleted) inicio.complete();
		if (sinPaqueteOffline && listenOptions?.onDevice == true) {
			scheduleMicrotask(() => error?.call(SpeechRecognitionError('error_language_unavailable', true)));
		} else if (listenOptions?.onDevice == false && !inicioNormal.isCompleted) {
			inicioNormal.complete();
		}
	}
	@override
	Future<void> stop() async {}
	@override
	Future<void> cancel() async { cancelaciones++; }
	@override
	void changePauseFor(Duration pausa) { pausas.add(pausa); }
	void emitir(String texto, {bool finalizado = false}) => resultado?.call(
		SpeechRecognitionResult([SpeechRecognitionWords(texto, null, 1)], finalizado ? 2 : 0));
}

void main() {
	test('espera primer texto y libera el reconocedor en cuatro capturas seguidas', () async {
		final r = ReconocedorPrueba();
		final audio = ServicioAudio(estaListoTTS: false, reconocedor: r);
		for (int i = 0; i < 4; i++) {
			r.inicio = Completer<void>();
			final captura = audio.escucharPregunta();
			await r.inicio.future;
			expect(r.opciones.last.pauseFor, const Duration(seconds: 20));
			r.emitir('pregunta $i');
			expect(r.pausas.last, const Duration(seconds: 3));
			r.emitir('pregunta $i completa', finalizado: true);
			expect(await captura, 'pregunta $i completa');
			expect(audio.escuchando, isFalse);
		}
		expect(r.cancelaciones, 4);
	});

	test('no repite el motor offline si ya informó que falta el idioma', () async {
		final r = ReconocedorPrueba()..sinPaqueteOffline = true;
		final audio = ServicioAudio(estaListoTTS: false, reconocedor: r);
		for (int i = 0; i < 2; i++) {
			r.inicioNormal = Completer<void>();
			final captura = audio.escucharPregunta();
			await r.inicioNormal.future;
			r.emitir('ríos', finalizado: true);
			expect(await captura, 'ríos');
		}
		expect(r.opciones.map((o) => o.onDevice).toList(), [true, false, false]);
	});
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
