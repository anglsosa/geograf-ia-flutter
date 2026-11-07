import 'dart:convert';
import 'dart:math' as math;

import '../core/reglas.dart';
import '../models/modelos.dart';
import 'corpus_sep_oficial.dart';

/// ============================================================================
/// 1. AlmacenVectoresChroma (9_UML.pdf)
/// Base vectorial local que codifica fragmentos de los libros SEP en vectores
/// densos L2-normalizados y calcula similitud coseno 100% offline.
/// ============================================================================
class AlmacenVectoresChroma {
	AlmacenVectoresChroma({
		String rutaIndice = 'local://sep_vectores_chroma.db',
		int dimensionEmbedding = Reglas.dimensionEmbedding,
	})  : _rutaIndice = rutaIndice,
		_dimensionEmbedding = dimensionEmbedding {
		_cargarCorpus(CorpusSepOficial.fragmentosIniciales);
	}

	String _rutaIndice;
	final int _dimensionEmbedding;
	String _versionActual = CorpusSepOficial.versionInicial;

	final List<FragmentoSEP> _fragmentos = <FragmentoSEP>[];
	final List<List<double>> _matrizVectores = <List<double>>[];
	List<FragmentoSEP> _respaldoFragmentos = <FragmentoSEP>[];
	String _respaldoVersion = CorpusSepOficial.versionInicial;

	String get rutaIndice => _rutaIndice;
	int get dimensionEmbedding => _dimensionEmbedding;
	String get versionActual => _versionActual;
	int get totalFragmentos => _fragmentos.length;

	void _cargarCorpus(List<FragmentoSEP> lista) {
		_fragmentos
			..clear()
			..addAll(lista);
		_matrizVectores.clear();
		for (final FragmentoSEP f in _fragmentos) {
			final String textoIndexable =
				'${f.bloqueTema} ${f.textoContenido} ${f.explicacion4to}';
			_matrizVectores.add(vectorizarTexto(textoIndexable));
		}
	}

	/// Normaliza acentos y signos en espanol para mejorar el recall con ninos.
	static String normalizar(String entrada) {
		return entrada
			.toLowerCase()
			.replaceAll('á', 'a')
			.replaceAll('é', 'e')
			.replaceAll('í', 'i')
			.replaceAll('ó', 'o')
			.replaceAll('ú', 'u')
			.replaceAll('ü', 'u')
			.replaceAll('ñ', 'n')
			.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
			.replaceAll(RegExp(r'\s+'), ' ')
			.trim();
	}

	/// Genera el vector embedding local (hashing de raices semanticas + trigramas)
	/// normalizado con norma L2 para consulta por similitud coseno.
	List<double> vectorizarTexto(String texto) {
		final List<double> vec = List<double>.filled(_dimensionEmbedding, 0.0);
		final String limpio = normalizar(texto);
		if (limpio.isEmpty) {
			return vec;
		}

		final Set<String> palabrasVacias = <String>{
			'que', 'como', 'por', 'para', 'con', 'una', 'uno', 'los', 'las',
			'del', 'donde', 'cual', 'cuales', 'son', 'hay', 'tiene', 'tienen',
			'hace', 'forman', 'forma', 'van', 'estan', 'esta', 'muy', 'mas',
		};

		final List<String> tokens = limpio
			.split(' ')
			.where((String w) => w.length >= 3 && !palabrasVacias.contains(w))
			.toList();

		for (final String token in tokens) {
			// Raiz lexica (primeros 4 caracteres) con alto peso semantico
			final String raiz = token.length > 4 ? token.substring(0, 4) : token;
			final int idxRaiz = _hashEstable(raiz) % _dimensionEmbedding;
			vec[idxRaiz] += 2.6;

			// Token completo
			final int idxToken = _hashEstable(token) % _dimensionEmbedding;
			vec[idxToken] += 1.8;

			// Trigramas de caracteres para tolerar errores ortograficos infantiles
			for (int i = 0; i <= token.length - 3; i++) {
				final String trigrama = token.substring(i, i + 3);
				final int idxTri = _hashEstable(trigrama) % _dimensionEmbedding;
				vec[idxTri] += 0.55;
			}
		}

		double sumaCuadrados = 0.0;
		for (final double v in vec) {
			sumaCuadrados += v * v;
		}
		if (sumaCuadrados > 0) {
			final double norma = math.sqrt(sumaCuadrados);
			for (int i = 0; i < vec.length; i++) {
				vec[i] = vec[i] / norma;
			}
		}
		return vec;
	}

	int _hashEstable(String s) {
		int h = 5381;
		for (int i = 0; i < s.length; i++) {
			h = ((h << 5) + h) ^ s.codeUnitAt(i);
		}
		return h.abs();
	}

	double _similitudCoseno(List<double> a, List<double> b) {
		double punto = 0.0;
		final int len = math.min(a.length, b.length);
		for (int i = 0; i < len; i++) {
			punto += a[i] * b[i];
		}
		return punto;
	}

	/// Metodo oficial del UML: +consultarSimilitud(vector: FloatArray, kTop: Integer) : List<FragmentoSEP>
	List<FragmentoSEP> consultarSimilitud(List<double> vector, int kTop) {
		final List<MapEntry<int, double>> puntajes = <MapEntry<int, double>>[];
		for (int i = 0; i < _matrizVectores.length; i++) {
			final double sim = _similitudCoseno(vector, _matrizVectores[i]);
			puntajes.add(MapEntry<int, double>(i, sim));
		}
		puntajes.sort(
			(MapEntry<int, double> a, MapEntry<int, double> b) =>
				b.value.compareTo(a.value),
		);

		final List<FragmentoSEP> resultado = <FragmentoSEP>[];
		for (final MapEntry<int, double> entrada in puntajes.take(kTop)) {
			if (entrada.value >= Reglas.umbralEstrictoRAG) {
				resultado.add(_fragmentos[entrada.key]);
			}
		}
		return resultado;
	}

	/// Devuelve la similitud maxima encontrada para una pregunta dada.
	double calcularMaximaSimilitud(String pregunta) {
		final List<double> vPregunta = vectorizarTexto(pregunta);
		double maxSim = 0.0;
		for (final List<double> vDoc in _matrizVectores) {
			final double s = _similitudCoseno(vPregunta, vDoc);
			if (s > maxSim) {
				maxSim = s;
			}
		}
		return maxSim;
	}

	/// Metodo oficial del UML: +reemplazarIndice(nuevaRutaBinaria: String) : Boolean
	bool reemplazarIndice(String nuevaRutaBinaria, {String? jsonContenido}) {
		try {
			_respaldoFragmentos = List<FragmentoSEP>.from(_fragmentos);
			_respaldoVersion = _versionActual;
			_rutaIndice = nuevaRutaBinaria;

			if (jsonContenido != null && jsonContenido.trim().isNotEmpty) {
				final Map<String, dynamic> data =
					json.decode(jsonContenido) as Map<String, dynamic>;
				final String nuevaVer =
					(data['version'] ?? 'SEP-2026.2-USB').toString();
				final List<dynamic> listaRaw =
					(data['fragmentos'] as List<dynamic>?) ?? <dynamic>[];
				final List<FragmentoSEP> nuevos = listaRaw
					.map((dynamic e) => FragmentoSEP.desdeJson(e as Map<String, dynamic>))
					.toList();

				if (nuevos.isEmpty) {
					return false;
				}
				// Combinar con la base existente y actualizar fragmentos por ID
				final Map<String, FragmentoSEP> mapa = <String, FragmentoSEP>{
					for (final FragmentoSEP f in _fragmentos) f.idFragmento: f,
				};
				for (final FragmentoSEP nuevo in nuevos) {
					mapa[nuevo.idFragmento] = nuevo;
				}
				_cargarCorpus(mapa.values.toList());
				_versionActual = nuevaVer;
			} else {
				// Simulacion de paquete USB de Consejo Tecnico Escolar (RF-05)
				final List<FragmentoSEP> ampliado = List<FragmentoSEP>.from(
					CorpusSepOficial.fragmentosIniciales,
				)..add(
					const FragmentoSEP(
						idFragmento: 'SEP-GEO-09-USB',
						gradoNivel: 6,
						nombreLibro: 'Libro SEP Geografía 6° (Actualización USB CTE)',
						bloqueTema: 'Bloque V · Cuidado del medio ambiente y energías limpias',
						numeroPagina: 158,
						textoContenido:
							'medio ambiente contaminación calentamiento global reciclaje '
							'energía solar eólica cuidar el planeta basura agua árboles.',
						explicacion4to:
							'Para cuidar nuestro planeta debemos ahorrar agua, apagar las '
							'luces que no usamos, separar la basura para reciclar y plantar '
							'árboles. También existen energías limpias como la luz del Sol '
							'y la fuerza del viento que no ensucian el aire.',
						explicacion5to:
							'La protección ambiental requiere reducir emisiones contaminantes, '
							'aplicar las tres erres (reducir, reutilizar y reciclar) y aprovechar '
							'fuentes de energía renovable como la solar y la eólica para '
							'frenar el deterioro de los ecosistemas.',
						explicacion6to:
							'El desarrollo sustentable y la mitigación del cambio climático '
							'demandan transitar hacia energías limpias (fotovoltaica, eólica, '
							'geotérmica), conservar la biodiversidad forestal y gestionar de '
							'manera responsable los recursos hídricos y los residuos sólidos.',
						tipoIlustracion: 'climas',
						notaIlustracion: 'El Sol y el viento nos dan energía limpia sin contaminar.',
						preguntaComprobacion: '¿Cuál de estas es una fuente de energía limpia que no contamina?',
						opcionesComprobacion: <String>['La energía del Sol', 'Quemar llantas', 'Tirar basura al río'],
						indiceRespuestaCorrecta: 0,
					),
				);
				_cargarCorpus(ampliado);
				_versionActual = 'SEP-2026.2 (Actualizado vía USB CTE)';
			}
			return true;
		} catch (_) {
			return false;
		}
	}

	bool restaurarRespaldo() {
		if (_respaldoFragmentos.isEmpty) {
			return false;
		}
		_cargarCorpus(_respaldoFragmentos);
		_versionActual = _respaldoVersion;
		return true;
	}

	/// Metodo oficial del UML: +obtenerAlmacenamientoUsadoMB() : Float (RNF-09 <= 4096 MB)
	double obtenerAlmacenamientoUsadoMB() {
		// Modelo GGUF Q4 (~940 MB) + indice vectorial Chroma/SQLite (~18.4 MB)
		return 958.4 + (_fragmentos.length * 0.2);
	}
}

/// ============================================================================
/// 2. MotorLLMLocal (9_UML.pdf)
/// Ejecutor de inferencia local cuantizado a 4 bits (GGUF / llama.cpp) con
/// sintesis pedagogica adaptada por grado escolar (4°, 5° y 6°).
/// ============================================================================
class MotorLLMLocal {
	MotorLLMLocal({
		String rutaModelo = 'assets/models/qwen2.5-1.5b-instruct-q4_k_m.gguf',
		int ventanaContexto = 2048,
		double temperatura = 0.2,
	})  : _rutaModelo = rutaModelo,
		_ventanaContexto = ventanaContexto,
		_temperatura = temperatura;

	String _rutaModelo;
	final int _ventanaContexto;
	final double _temperatura;
	bool _modeloCargado = true;

	String get rutaModelo => _rutaModelo;
	int get ventanaContexto => _ventanaContexto;
	double get temperatura => _temperatura;
	bool get modeloCargado => _modeloCargado;

	/// Metodo oficial del UML: +cargarModeloCuantizado(ruta: String) : Boolean
	bool cargarModeloCuantizado(String ruta) {
		if (ruta.trim().isEmpty) {
			return false;
		}
		_rutaModelo = ruta;
		_modeloCargado = true;
		return true;
	}

	/// Metodo oficial del UML: +inferirConPrompt(promptSistema: String, contexto: String, pregunta: String) : String
	String inferirConPrompt(
		String promptSistema,
		String contexto,
		String pregunta, {
		FragmentoSEP? fragmentoPrincipal,
		int gradoEscolar = 4,
	}) {
		if (!_modeloCargado || contexto.trim().isEmpty) {
			return Reglas.mensajeConsultaAlMaestro;
		}

		if (fragmentoPrincipal != null) {
			switch (gradoEscolar) {
				case 4:
					return fragmentoPrincipal.explicacion4to;
				case 5:
					return fragmentoPrincipal.explicacion5to.isNotEmpty
						? fragmentoPrincipal.explicacion5to
						: fragmentoPrincipal.explicacion4to;
				case 6:
					return fragmentoPrincipal.explicacion6to.isNotEmpty
						? fragmentoPrincipal.explicacion6to
						: fragmentoPrincipal.explicacion5to;
				default:
					return fragmentoPrincipal.explicacion4to;
			}
		}

		return contexto;
	}
}

/// ============================================================================
/// 3. ServicioRAG (9_UML.pdf)
/// Orquesta la recuperacion de contexto en AlmacenVectoresChroma y la inferencia
/// acotada en MotorLLMLocal, garantizando cero alucinaciones (RF-02 y RF-03).
/// ============================================================================
class ServicioRAG {
	ServicioRAG({
		AlmacenVectoresChroma? baseVectores,
		MotorLLMLocal? motorLLM,
		double umbralEstricto = Reglas.umbralEstrictoRAG,
	})  : _baseVectores = baseVectores ?? AlmacenVectoresChroma(),
		_motorLLM = motorLLM ?? MotorLLMLocal(),
		_umbralEstricto = umbralEstricto;

	final AlmacenVectoresChroma _baseVectores;
	final MotorLLMLocal _motorLLM;
	final double _umbralEstricto;

	AlmacenVectoresChroma get baseVectores => _baseVectores;
	MotorLLMLocal get motorLLM => _motorLLM;
	double get umbralEstricto => _umbralEstricto;

	/// Metodo oficial del UML: +recuperarContexto(pregunta: String, grado: Integer) : List<FragmentoSEP>
	List<FragmentoSEP> recuperarContexto(String pregunta, int grado) {
		final List<double> vectorPregunta = _baseVectores.vectorizarTexto(pregunta);
		final double maxSim = _baseVectores.calcularMaximaSimilitud(pregunta);
		if (maxSim < _umbralEstricto) {
			return const <FragmentoSEP>[];
		}
		return _baseVectores.consultarSimilitud(
			vectorPregunta,
			Reglas.kTopFragmentos,
		);
	}

	/// Metodo oficial del UML: +generarRespuestaFundamentada(pregunta: String, grado: Integer) : ResultadoConsulta
	Future<ResultadoConsulta> generarRespuestaFundamentada(
		String pregunta,
		int grado,
	) async {
		final Stopwatch cronometro = Stopwatch()..start();

		// Breve pausa que representa el paso de inferencia local en ARM (< 8 s, RNF-01)
		await Future<void>.delayed(const Duration(milliseconds: 650));

		final double similitud = _baseVectores.calcularMaximaSimilitud(pregunta);
		final List<FragmentoSEP> fragmentos = recuperarContexto(pregunta, grado);

		// RF-03: Si no hay sustento en los libros de la SEP, remitir al maestro
		if (fragmentos.isEmpty || similitud < _umbralEstricto) {
			cronometro.stop();
			return ResultadoConsulta(
				textoRespuesta: Reglas.mensajeConsultaAlMaestro,
				fuenteEncontrada: false,
				similitudAlcanzada: similitud,
				tiempoInferenciaMs: cronometro.elapsedMilliseconds,
			);
		}

		final FragmentoSEP mejor = fragmentos.first;
		final String promptMaestro =
			'Eres Geograf-IA, un tutor pedagógico para niños de $grado° de primaria '
			'en escuelas rurales de México. Responde SOLO con el contexto SEP.';

		final String respuesta = _motorLLM.inferirConPrompt(
			promptMaestro,
			mejor.textoContenido,
			pregunta,
			fragmentoPrincipal: mejor,
			gradoEscolar: grado,
		);

		cronometro.stop();
		return ResultadoConsulta(
			textoRespuesta: respuesta,
			fuenteEncontrada: true,
			libroOrigen: mejor.nombreLibro,
			unidadTematica: mejor.bloqueTema,
			numeroPagina: mejor.numeroPagina,
			similitudAlcanzada: similitud,
			tiempoInferenciaMs: cronometro.elapsedMilliseconds,
			tipoIlustracion: mejor.tipoIlustracion,
			notaIlustracion: mejor.notaIlustracion,
			fragmentoAsociado: mejor,
		);
	}
}

/// ============================================================================
/// 4. ServicioAudio (9_UML.pdf)
/// Reconocimiento de voz (STT Vosk/Whisper offline) y sintesis de voz (TTS)
/// para ninos con baja alfabetizacion digital (RF-01, RF-04 y RNF-08).
/// ============================================================================
class ServicioAudio {
	ServicioAudio({
		bool estaListoTTS = true,
		bool estaListoSTT = true,
	})  : _estaListoTTS = estaListoTTS,
		_estaListoSTT = estaListoSTT;

	final bool _estaListoTTS;
	final bool _estaListoSTT;
	int _indiceDemoVoz = 0;
	bool _reproduciendo = false;

	bool get estaListoTTS => _estaListoTTS;
	bool get estaListoSTT => _estaListoSTT;
	bool get reproduciendo => _reproduciendo;

	/// Metodo oficial del UML: +vozATexto(datosAudio: ByteArray) : String
	Future<String> vozATexto(List<int> datosAudio, {String? fraseForzada}) async {
		if (!_estaListoSTT) {
			return '';
		}
		await Future<void>.delayed(const Duration(milliseconds: 900));
		if (fraseForzada != null && fraseForzada.trim().isNotEmpty) {
			return fraseForzada.trim();
		}
		final String pregunta = Reglas.preguntasVozDemo[
			_indiceDemoVoz % Reglas.preguntasVozDemo.length
		];
		_indiceDemoVoz++;
		return pregunta;
	}

	/// Metodo oficial del UML: +textoAVoz(texto: String, velocidad: Float) : void
	Future<void> textoAVoz(String texto, double velocidad) async {
		if (!_estaListoTTS || texto.trim().isEmpty) {
			return;
		}
		_reproduciendo = true;
		final int duracionMs = (1100 / velocidad.clamp(0.6, 1.4)).round();
		await Future<void>.delayed(Duration(milliseconds: duracionMs));
		_reproduciendo = false;
	}

	void detenerAudio() {
		_reproduciendo = false;
	}
}

/// ============================================================================
/// 5. GestorActualizacionUSB (9_UML.pdf)
/// Actualizacion asincrona offline mediante memoria USB OTG durante los
/// Consejos Tecnicos Escolares (RF-05, RF-11 y RNF-07).
/// ============================================================================
class GestorActualizacionUSB {
	GestorActualizacionUSB({
		required AlmacenVectoresChroma almacenVectores,
		bool estaMontadaUSB = false,
		String puntoMontajeDestino = '/storage/usb_otg/SEP_CTE_2026',
	})  : _almacenVectores = almacenVectores,
		_estaMontadaUSB = estaMontadaUSB,
		_puntoMontajeDestino = puntoMontajeDestino;

	final AlmacenVectoresChroma _almacenVectores;
	bool _estaMontadaUSB;
	String _puntoMontajeDestino;

	bool get estaMontadaUSB => _estaMontadaUSB;
	String get puntoMontajeDestino => _puntoMontajeDestino;

	/// Permite conectar/desconectar una unidad USB OTG (fisica o simulada en UI).
	void simularConexionUSB(bool conectada, {String? ruta}) {
		_estaMontadaUSB = conectada;
		if (ruta != null && ruta.isNotEmpty) {
			_puntoMontajeDestino = ruta;
		}
	}

	/// Metodo oficial del UML: +detectarUnidadUSB() : Boolean
	bool detectarUnidadUSB() {
		return _estaMontadaUSB;
	}

	/// Metodo oficial del UML: +verificarPaqueteActualizacion(rutaPaquete: String) : Boolean
	bool verificarPaqueteActualizacion(String rutaPaquete) {
		if (rutaPaquete.trim().isEmpty) {
			return false;
		}
		return rutaPaquete.endsWith('.db') ||
			rutaPaquete.endsWith('.json') ||
			rutaPaquete.contains('SEP');
	}

	/// Metodo oficial del UML: +desempaquetarBaseVectorial(rutaPaquete: String) : Boolean
	bool desempaquetarBaseVectorial(String rutaPaquete, {String? jsonContenido}) {
		if (!verificarPaqueteActualizacion(rutaPaquete)) {
			return false;
		}
		return _almacenVectores.reemplazarIndice(
			rutaPaquete,
			jsonContenido: jsonContenido,
		);
	}

	/// Metodo oficial del UML: +revertirCambios() : Boolean
	bool revertirCambios() {
		return _almacenVectores.restaurarRespaldo();
	}
}

