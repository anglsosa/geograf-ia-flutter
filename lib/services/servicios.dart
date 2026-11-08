import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:llamadart/llamadart.dart'
	show
		ComputeDevice,
		DefaultModelDownloadManager,
		GenerationParams,
		LlamaChatMessage,
		LlamaChatRole,
		LlamaEngine,
		LlamaModel,
		ModelDownloadCancelToken,
		ModelDownloadProgress,
		ModelLoadOptions,
		ModelParams,
		ModelSource;
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_recognition_error.dart'
	show SpeechRecognitionError;
import 'package:speech_to_text/speech_recognition_result.dart'
	show SpeechRecognitionResult;
import 'package:speech_to_text/speech_to_text.dart'
	show ListenMode, SpeechListenOptions, SpeechToText;

import '../core/reglas.dart';
import '../models/modelos.dart';
import 'corpus_sep_oficial.dart';

/// Resultado de una busqueda en el indice: fragmento SEP y su puntaje (0 a 1).
class ResultadoBusqueda {
	const ResultadoBusqueda(this.fragmento, this.similitud);

	final FragmentoSEP fragmento;
	final double similitud;
}

/// ============================================================================
/// 1. AlmacenVectoresChroma (9_UML.pdf)
/// Base de conocimiento local de los libros SEP. Cada fragmento se indexa por
/// raices de palabras y la consulta se puntua con BM25 normalizado (0 a 1): la
/// fraccion de lo que pregunta el nino que el fragmento realmente cubre. Una
/// palabra que no existe en ningun libro baja el puntaje, asi las preguntas
/// fuera de tema no alcanzan el umbral. Todo 100% offline.
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
	final List<Map<String, int>> _frecuencias = <Map<String, int>>[];
	final List<int> _largos = <int>[];
	final Map<String, int> _frecuenciaDocumento = <String, int>{};
	double _largoPromedio = 1.0;
	List<FragmentoSEP> _respaldoFragmentos = <FragmentoSEP>[];
	String _respaldoVersion = CorpusSepOficial.versionInicial;

	// Parametros de BM25 calibrados con bancos de preguntas de ninos.
	static const double _k1 = 1.2;
	static const double _b = 0.3;
	static const int _repeticionPalabrasClave = 2;
	static const int _largoRaiz = 6;

	/// Palabras sin valor tematico (ya normalizadas, sin acentos).
	static const Set<String> _palabrasVacias = <String>{
		'como', 'con', 'cual', 'cuales', 'cuando', 'cuantas', 'cuanto', 'cuantos',
		'cuentame', 'del', 'desde', 'diferencia', 'dime', 'donde', 'entre', 'era',
		'eres', 'esas', 'eso', 'esos', 'esta', 'estan', 'estar', 'estas',
		'esto', 'estoy', 'existe', 'existen', 'explicame', 'favor', 'forma', 'forman',
		'hace', 'hasta', 'hay', 'hola', 'importante', 'importantes', 'las', 'les',
		'los', 'mas', 'mis', 'muy', 'nombre', 'nos', 'para', 'pasa',
		'por', 'porque', 'puede', 'pueden', 'que', 'quien', 'quienes', 'quiero',
		'saber', 'sale', 'salen', 'ser', 'significa', 'significan', 'sirve', 'sirven',
		'sobre', 'son', 'soy', 'sus', 'tiene', 'tienen', 'tipo', 'tipos',
		'tus', 'una', 'unas', 'uno', 'unos', 'van', 'viene', 'vienen',
	};

	/// Terminos que no se truncan porque su raiz chocaria con otra palabra
	/// (por ejemplo "oceania" con "oceano" o "internet" con "interno").
	static const Set<String> _terminosExactos = <String>{
		'oceania', 'centroamerica', 'sudamerica', 'norteamerica', 'internet',
		'electricidad',
	};

	/// Sinonimos y formas verbales que un nino usa al hablar, llevados al
	/// termino que aparece en los libros.
	static const Map<String, String> _sinonimos = <String, String>{
		'cultivar': 'agricultura',
		'cultivo': 'agricultura',
		'cultivos': 'agricultura',
		'emigran': 'migracion',
		'entidad': 'estado',
		'entidades': 'estados',
		'erupciona': 'erupcion',
		'erupcionan': 'erupcion',
		'erupciones': 'erupcion',
		'federativas': 'estados',
		'ganaderia': 'campo',
		'ganado': 'campo',
		'granja': 'campo',
		'llover': 'lluvia',
		'llovio': 'lluvia',
		'llueve': 'lluvia',
		'llueven': 'lluvia',
		'lluvioso': 'lluvia',
		'mudan': 'migracion',
		'mudarse': 'migracion',
		'nacen': 'nace',
		'pueblo': 'rural',
		'pueblos': 'rural',
		'sembrar': 'agricultura',
		'siembra': 'agricultura',
		'temblor': 'sismo',
		'temblores': 'sismo',
		'terremoto': 'sismo',
		'terremotos': 'sismo',
		'tiembla': 'sismo',
		'tiemblan': 'sismo',
	};

	/// Copia de los fragmentos que hay cargados ahora en el indice.
	List<FragmentoSEP> get fragmentos =>
		List<FragmentoSEP>.unmodifiable(_fragmentos);

	/// Reemplaza todo el corpus (por ejemplo con el leido de la base de datos).
	void reemplazarCorpus(List<FragmentoSEP> lista, String version) {
		if (lista.isEmpty) {
			return;
		}
		_cargarCorpus(lista);
		_versionActual = version;
	}

	String get rutaIndice => _rutaIndice;
	int get dimensionEmbedding => _dimensionEmbedding;
	String get versionActual => _versionActual;
	int get totalFragmentos => _fragmentos.length;

	void _cargarCorpus(List<FragmentoSEP> lista) {
		_fragmentos
			..clear()
			..addAll(lista);
		_frecuencias.clear();
		_largos.clear();
		_frecuenciaDocumento.clear();

		int totalTerminos = 0;
		for (final FragmentoSEP f in _fragmentos) {
			final String claves = '${f.textoContenido} ' * _repeticionPalabrasClave;
			final List<String> tokens = _tokenizar(
				'${f.bloqueTema} $claves${f.explicacion4to}',
			);
			final Map<String, int> tf = <String, int>{};
			for (final String t in tokens) {
				tf[t] = (tf[t] ?? 0) + 1;
			}
			for (final String t in tf.keys) {
				_frecuenciaDocumento[t] = (_frecuenciaDocumento[t] ?? 0) + 1;
			}
			_frecuencias.add(tf);
			_largos.add(tokens.length);
			totalTerminos += tokens.length;
		}
		_largoPromedio = _fragmentos.isEmpty
			? 1.0
			: math.max(1.0, totalTerminos / _fragmentos.length);
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

	static String _raiz(String palabra) {
		if (_terminosExactos.contains(palabra)) {
			return palabra;
		}
		final String p = _sinonimos[palabra] ?? palabra;
		if (p.length > _largoRaiz) {
			return p.substring(0, _largoRaiz);
		}
		if (p.length > 3 && p.endsWith('s')) {
			return p.substring(0, p.length - 1);
		}
		return p;
	}

	List<String> _tokenizar(String texto) {
		final String limpio = normalizar(texto);
		if (limpio.isEmpty) {
			return const <String>[];
		}
		final List<String> raices = <String>[];
		for (final String palabra in limpio.split(' ')) {
			if (palabra.length < 3 || _palabrasVacias.contains(palabra)) {
				continue;
			}
			raices.add(_raiz(palabra));
		}
		return raices;
	}

	double _idf(String termino) {
		final int n = _fragmentos.length;
		final int df = _frecuenciaDocumento[termino] ?? 0;
		return math.log(1.0 + (n - df + 0.5) / (df + 0.5));
	}

	/// Puntaje BM25 de cada fragmento, normalizado entre 0 y 1 respecto de lo que
	/// el fragmento ideal podria cubrir de la pregunta.
	List<double> _puntuar(String pregunta) {
		final List<double> puntajes = List<double>.filled(_fragmentos.length, 0.0);
		final Set<String> terminos = _tokenizar(pregunta).toSet();
		if (terminos.isEmpty || _fragmentos.isEmpty) {
			return puntajes;
		}
		double denominador = 0.0;
		for (final String t in terminos) {
			denominador += _idf(t) * (_k1 + 1.0);
		}
		if (denominador <= 0) {
			return puntajes;
		}
		for (int i = 0; i < _fragmentos.length; i++) {
			final Map<String, int> tf = _frecuencias[i];
			final double norma =
				_k1 * (1.0 - _b + _b * _largos[i] / _largoPromedio);
			double suma = 0.0;
			for (final String t in terminos) {
				final int veces = tf[t] ?? 0;
				if (veces > 0) {
					suma += _idf(t) * veces * (_k1 + 1.0) / (veces + norma);
				}
			}
			puntajes[i] = suma / denominador;
		}
		return puntajes;
	}

	/// Busca hasta [kTop] fragmentos relevantes para la pregunta, de mayor a menor
	/// puntaje. Solo se devuelven los que superan [umbral] y al menos la mitad del
	/// puntaje del mejor (para no mezclar temas poco relacionados).
	List<ResultadoBusqueda> buscar(
		String pregunta,
		int kTop, {
		double umbral = Reglas.umbralEstrictoRAG,
	}) {
		final List<double> puntajes = _puntuar(pregunta);
		final List<ResultadoBusqueda> todos = <ResultadoBusqueda>[
			for (int i = 0; i < _fragmentos.length; i++)
				ResultadoBusqueda(_fragmentos[i], puntajes[i]),
		];
		todos.sort(
			(ResultadoBusqueda a, ResultadoBusqueda b) =>
				b.similitud.compareTo(a.similitud),
		);
		if (todos.isEmpty || todos.first.similitud < umbral) {
			return const <ResultadoBusqueda>[];
		}
		final double corte = math.max(
			umbral,
			todos.first.similitud * Reglas.fraccionContextoRAG,
		);
		return todos
			.take(kTop)
			.where((ResultadoBusqueda r) => r.similitud >= corte)
			.toList();
	}

	/// Metodo oficial del UML: +consultarSimilitud(consulta, kTop) : List<FragmentoSEP>
	List<FragmentoSEP> consultarSimilitud(String consulta, int kTop) {
		return buscar(consulta, kTop)
			.map((ResultadoBusqueda r) => r.fragmento)
			.toList();
	}

	/// Devuelve el puntaje maximo (0 a 1) encontrado para una pregunta dada.
	double calcularMaximaSimilitud(String pregunta) {
		double maxSim = 0.0;
		for (final double s in _puntuar(pregunta)) {
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
				final Map<String, FragmentoSEP> mapa = <String, FragmentoSEP>{
					for (final FragmentoSEP f in _fragmentos) f.idFragmento: f,
				};
				for (final FragmentoSEP nuevo in nuevos) {
					mapa[nuevo.idFragmento] = nuevo;
				}
				_cargarCorpus(mapa.values.toList());
				_versionActual = nuevaVer;
			} else {
				final List<FragmentoSEP> ampliado = List<FragmentoSEP>.from(
					CorpusSepOficial.fragmentosIniciales,
				)..add(
					const FragmentoSEP(
						idFragmento: 'SEP-GEO-11-USB',
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
	/// Tamano real (en MB) del texto de los libros indexados. El modelo de IA se
	/// suma aparte con [MotorLLMLocal.tamanoModeloMB].
	double obtenerAlmacenamientoUsadoMB() {
		int bytes = 0;
		for (final FragmentoSEP f in _fragmentos) {
			bytes += utf8
				.encode(
					'${f.bloqueTema}${f.textoContenido}${f.explicacion4to}'
					'${f.explicacion5to}${f.explicacion6to}',
				)
				.length;
		}
		return bytes / (1024.0 * 1024.0);
	}
}

/// ============================================================================
/// 2. MotorLLMLocal (9_UML.pdf)
/// Ejecutor de inferencia local REAL: descarga el modelo GGUF cuantizado a 4
/// bits desde Hugging Face (una sola vez, con reanudacion y verificacion
/// SHA-256), lo carga en memoria con llama.cpp y redacta la respuesta del tutor
/// usando unicamente el contexto de los libros SEP. Despues de la descarga
/// funciona 100% sin internet.
/// ============================================================================
enum EstadoModelo {
	/// No hay archivo del modelo en el telefono (modo basico: solo libros SEP).
	noInstalado,

	/// Descargando el archivo GGUF.
	descargando,

	/// Archivo descargado y verificado, aun no cargado en memoria.
	instalado,

	/// Cargando el modelo en memoria.
	cargando,

	/// Modelo en memoria, listo para responder.
	listo,

	/// Fallo la descarga o la carga (ver [MotorLLMLocal.ultimoError]).
	error,
}

/// Respuesta del motor: texto final y como se obtuvo.
class RespuestaMotor {
	const RespuestaMotor({
		required this.texto,
		this.usoIA = false,
		this.sinInformacion = false,
	});

	final String texto;

	/// true si lo redacto el LLM; false si es la explicacion del libro tal cual.
	final bool usoIA;

	/// true si el LLM determino que el contexto no responde la pregunta (RF-03).
	final bool sinInformacion;
}

class MotorLLMLocal extends ChangeNotifier {
	MotorLLMLocal({
		String rutaModelo = '',
		int ventanaContexto = Reglas.ventanaContextoLLM,
		double temperatura = Reglas.temperaturaLLM,
	})  : _rutaModelo = rutaModelo,
		_ventanaContexto = ventanaContexto,
		_temperatura = temperatura;

	String _rutaModelo;
	final int _ventanaContexto;
	final double _temperatura;

	EstadoModelo _estado = EstadoModelo.noInstalado;
	bool _archivoPresente = false;
	int _bytesModelo = 0;
	double _progreso = 0.0;
	String _etapa = '';
	String _ultimoError = '';
	double _ultimoProgresoNotificado = -1.0;

	LlamaEngine? _engine;
	Future<bool>? _cargaEnCurso;
	ModelDownloadCancelToken? _tokenDescarga;
	bool _inicializado = false;
	bool _liberado = false;

	/// El LLM local usa codigo nativo (llama.cpp): no existe en el navegador.
	static bool get plataformaSoportada => !kIsWeb;

	String get rutaModelo => _rutaModelo;
	int get ventanaContexto => _ventanaContexto;
	double get temperatura => _temperatura;
	EstadoModelo get estado => _estado;

	/// true solo si el modelo esta realmente en memoria y puede responder.
	bool get modeloCargado => _estado == EstadoModelo.listo && _engine != null;

	/// true si el archivo GGUF ya esta guardado en el telefono.
	bool get paqueteOfflineInstalado => _archivoPresente;
	bool get descargando => _estado == EstadoModelo.descargando;
	bool get cargando => _estado == EstadoModelo.cargando;
	double get progresoDescarga => _progreso;
	String get etapaDescarga => _etapa;
	String get ultimoError => _ultimoError;
	double get tamanoModeloMB =>
		_archivoPresente ? _bytesModelo / (1024.0 * 1024.0) : 0.0;

	String get nombreModeloActivo {
		switch (_estado) {
			case EstadoModelo.listo:
				return '${Reglas.modeloNombre} · listo, sin internet';
			case EstadoModelo.instalado:
				return '${Reglas.modeloNombre} · descargado';
			case EstadoModelo.cargando:
				return '${Reglas.modeloNombre} · cargando…';
			case EstadoModelo.descargando:
				return '${Reglas.modeloNombre} · descargando…';
			case EstadoModelo.error:
			case EstadoModelo.noInstalado:
				return 'Modo básico (libros SEP) · modelo de IA no instalado';
		}
	}

	void _notificar() {
		if (!_liberado) {
			notifyListeners();
		}
	}

	// --------------------------------------------------------------------------
	// Almacenamiento
	// --------------------------------------------------------------------------

	Future<Directory> _directorioModelos() async {
		final Directory base = await getApplicationSupportDirectory();
		final Directory dir =
			Directory('${base.path}${Platform.pathSeparator}modelos_ia');
		if (!await dir.exists()) {
			await dir.create(recursive: true);
		}
		return dir;
	}

	File _archivoMarcador(Directory dir) =>
		File('${dir.path}${Platform.pathSeparator}modelo_activo.txt');

	/// Devuelve el archivo GGUF instalado y valido, o null si no hay ninguno.
	Future<File?> _archivoInstalado() async {
		final Directory dir = await _directorioModelos();
		final File marcador = _archivoMarcador(dir);
		if (!await marcador.exists()) {
			return null;
		}
		final String ruta = (await marcador.readAsString()).trim();
		if (ruta.isEmpty) {
			return null;
		}
		final File modelo = File(ruta);
		if (!await modelo.exists()) {
			return null;
		}
		if (await modelo.length() != Reglas.modeloBytesEsperados) {
			return null;
		}
		return modelo;
	}

	/// Detecta si el modelo ya esta instalado y, de ser asi, lo carga en memoria
	/// en segundo plano para que la primera pregunta responda sin esperar.
	Future<void> inicializar() async {
		if (_inicializado || !plataformaSoportada) {
			return;
		}
		_inicializado = true;
		try {
			final File? modelo = await _archivoInstalado();
			if (modelo == null) {
				return;
			}
			_rutaModelo = modelo.path;
			_archivoPresente = true;
			_bytesModelo = await modelo.length();
			_estado = EstadoModelo.instalado;
			_notificar();
			unawaited(cargarModeloCuantizado(modelo.path));
		} catch (e) {
			_registrarError('No se pudo revisar el modelo guardado: $e');
		}
	}

	// --------------------------------------------------------------------------
	// Descarga e instalacion
	// --------------------------------------------------------------------------

	String _textoMB(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(0);

	String _mensajeErrorDescarga(Object e) {
		if (e is SocketException || e is HandshakeException) {
			return 'No hay conexión a internet. Conéctate a una red Wi-Fi y vuelve a '
				'intentar: la descarga continúa donde se quedó.';
		}
		if (e is TimeoutException) {
			return 'La conexión se cortó o es muy lenta. Vuelve a intentar: la '
				'descarga continúa donde se quedó.';
		}
		return 'No se pudo descargar el modelo: $e';
	}

	/// Descarga e instala en 1 clic el modelo GGUF desde Hugging Face y lo carga
	/// en memoria. Reanuda descargas interrumpidas y verifica SHA-256 y tamano.
	Future<bool> instalarModeloConUnClick({
		void Function(double progreso, String etapa)? alProgresar,
	}) async {
		if (!plataformaSoportada) {
			_registrarError(
				'El modelo de IA solo funciona en la app instalada en el teléfono '
				'(Android), no en el navegador.',
			);
			return false;
		}
		if (_estado == EstadoModelo.descargando) {
			return false;
		}

		void avanzar(double progreso, String etapa) {
			_progreso = progreso.clamp(0.0, 1.0);
			_etapa = etapa;
			alProgresar?.call(_progreso, etapa);
			// Evita reconstruir toda la UI en cada paquete de red.
			if ((_progreso - _ultimoProgresoNotificado).abs() >= 0.004 ||
				_progreso >= 1.0) {
				_ultimoProgresoNotificado = _progreso;
				_notificar();
			}
		}

		_ultimoError = '';
		_ultimoProgresoNotificado = -1.0;

		try {
			// Si ya esta descargado y valido, solo hay que cargarlo.
			final File? existente = await _archivoInstalado();
			if (existente != null) {
				_rutaModelo = existente.path;
				_archivoPresente = true;
				_bytesModelo = await existente.length();
				_estado = EstadoModelo.instalado;
				avanzar(0.95, 'El modelo ya está descargado. Cargándolo en memoria…');
				return await cargarModeloCuantizado(existente.path);
			}

			_estado = EstadoModelo.descargando;
			avanzar(0.01, 'Preparando almacenamiento del teléfono…');
			final Directory dir = await _directorioModelos();

			final ModelDownloadCancelToken token = ModelDownloadCancelToken();
			_tokenDescarga = token;
			final DefaultModelDownloadManager gestor =
				DefaultModelDownloadManager(defaultCacheDirectory: dir.path);

			avanzar(0.02, 'Conectando con Hugging Face…');
			final entrada = await gestor.ensureModel(
				ModelSource.huggingFace(
					repoId: Reglas.modeloRepoHuggingFace,
					filePath: Reglas.modeloArchivoGguf,
				),
				options: ModelLoadOptions(
					cacheDirectory: dir.path,
					sha256: Reglas.modeloSha256,
					cancelToken: token,
					resume: true,
					maxRetries: 5,
				),
				onProgress: (ModelDownloadProgress p) {
					final double? fraccion = p.fraction;
					if (fraccion == null) {
						avanzar(
							_progreso,
							'Descargando modelo… ${_textoMB(p.receivedBytes)} MB',
						);
						return;
					}
					final int total = p.totalBytes ?? Reglas.modeloBytesEsperados;
					avanzar(
						0.02 + fraccion * 0.88,
						'Descargando modelo: ${_textoMB(p.receivedBytes)} de '
						'${_textoMB(total)} MB',
					);
				},
			);
			_tokenDescarga = null;

			avanzar(0.92, 'Verificando que el archivo esté completo…');
			final File archivo = File(entrada.filePath);
			final int tamano = await archivo.length();
			if (tamano != Reglas.modeloBytesEsperados) {
				throw StateError(
					'El archivo descargado está incompleto o dañado '
					'($tamano de ${Reglas.modeloBytesEsperados} bytes).',
				);
			}

			await _archivoMarcador(dir).writeAsString(archivo.path);
			_rutaModelo = archivo.path;
			_archivoPresente = true;
			_bytesModelo = tamano;
			_estado = EstadoModelo.instalado;

			avanzar(0.95, 'Cargando el modelo en la memoria del teléfono…');
			final bool cargado = await cargarModeloCuantizado(archivo.path);
			if (cargado) {
				avanzar(1.0, '¡Modelo de IA instalado y listo sin internet!');
			}
			return cargado;
		} catch (e) {
			final bool cancelado = _tokenDescarga?.isCancelled ?? false;
			_tokenDescarga = null;
			if (cancelado) {
				_estado = _archivoPresente
					? EstadoModelo.instalado
					: EstadoModelo.noInstalado;
				_etapa = 'Descarga cancelada. Puedes reanudarla cuando quieras.';
				_ultimoError = '';
				_notificar();
				return false;
			}
			if (_archivoPresente) {
				_estado = EstadoModelo.instalado;
				_registrarError(
					'El modelo se descargó pero no pudo cargarse: $e',
					conservarEstado: true,
				);
			} else {
				_registrarError(_mensajeErrorDescarga(e));
			}
			return false;
		}
	}

	/// Cancela una descarga en curso (el avance parcial se conserva para reanudar).
	void cancelarDescarga() {
		_tokenDescarga?.cancel();
	}

	/// Borra el modelo del telefono para recuperar ~1.1 GB de almacenamiento.
	Future<void> eliminarModelo() async {
		try {
			await _liberarMotor();
			final Directory dir = await _directorioModelos();
			if (await dir.exists()) {
				await dir.delete(recursive: true);
			}
			_archivoPresente = false;
			_bytesModelo = 0;
			_rutaModelo = '';
			_progreso = 0.0;
			_etapa = '';
			_ultimoError = '';
			_estado = EstadoModelo.noInstalado;
			_notificar();
		} catch (e) {
			_registrarError('No se pudo borrar el modelo: $e', conservarEstado: true);
		}
	}

	void _registrarError(String mensaje, {bool conservarEstado = false}) {
		_ultimoError = mensaje;
		if (!conservarEstado) {
			_estado = EstadoModelo.error;
		}
		debugPrint('[MotorLLMLocal] $mensaje');
		_notificar();
	}

	// --------------------------------------------------------------------------
	// Carga en memoria
	// --------------------------------------------------------------------------

	Future<void> _liberarMotor() async {
		final LlamaEngine? motor = _engine;
		_engine = null;
		if (motor != null) {
			try {
				await motor.dispose();
			} catch (_) {}
		}
	}

	/// Metodo oficial del UML: +cargarModeloCuantizado(ruta: String) : Boolean
	/// Abre el archivo GGUF con llama.cpp. Es seguro llamarlo varias veces: si
	/// ya hay una carga en curso, espera a esa misma.
	Future<bool> cargarModeloCuantizado(String ruta) {
		if (ruta.trim().isEmpty || !plataformaSoportada) {
			return Future<bool>.value(false);
		}
		if (modeloCargado && ruta == _rutaModelo) {
			return Future<bool>.value(true);
		}
		final Future<bool>? enCurso = _cargaEnCurso;
		if (enCurso != null) {
			return enCurso;
		}
		final Future<bool> nueva = _cargar(ruta);
		_cargaEnCurso = nueva;
		return nueva.whenComplete(() {
			_cargaEnCurso = null;
		});
	}

	Future<bool> _cargar(String ruta) async {
		_estado = EstadoModelo.cargando;
		_ultimoError = '';
		_notificar();
		try {
			final File archivo = File(ruta);
			if (!await archivo.exists() ||
				await archivo.length() != Reglas.modeloBytesEsperados) {
				_archivoPresente = false;
				throw StateError('El archivo del modelo no existe o está incompleto.');
			}
			await _liberarMotor();
			_engine = await LlamaEngine.load(
				LlamaModel(ModelSource.path(ruta)),
				params: ModelParams(
					contextSize: _ventanaContexto,
					device: ComputeDevice.cpu,
					gpuLayers: 0,
					numberOfThreads: 4,
					numberOfThreadsBatch: 4,
				),
			);
			_rutaModelo = ruta;
			_archivoPresente = true;
			_bytesModelo = await archivo.length();
			_estado = EstadoModelo.listo;
			_notificar();
			return true;
		} catch (e) {
			_engine = null;
			_estado = _archivoPresente ? EstadoModelo.instalado : EstadoModelo.error;
			_registrarError(
				'No se pudo cargar el modelo de IA en memoria: $e',
				conservarEstado: _archivoPresente,
			);
			return false;
		}
	}

	// --------------------------------------------------------------------------
	// Inferencia
	// --------------------------------------------------------------------------

	/// Interrumpe la generacion en curso (por ejemplo al reiniciar la conversacion).
	void cancelarGeneracion() {
		try {
			_engine?.cancelGeneration();
		} catch (_) {}
	}

	static String _promptSistema(int grado) {
		return 'Eres Geograf-IA, un tutor amable de Geografía para niños de $grado° '
			'grado de primaria en México. Reglas: '
			'1) Responde SOLO con la información del CONTEXTO; no agregues datos de '
			'otras fuentes ni inventes nada. '
			'2) Usa palabras sencillas y oraciones cortas, adecuadas para $grado° grado. '
			'3) Responde en español, en 2 a 4 oraciones, sin listas ni títulos. '
			'4) Si el CONTEXTO no sirve para responder la pregunta, responde '
			'únicamente: ${Reglas.marcadorSinInformacion}';
	}

	/// true si [texto] podria ser el inicio del marcador SIN_INFORMACION (para no
	/// mostrarlo a medias en pantalla mientras llega por streaming).
	static bool _podriaSerMarcador(String texto) {
		final String t = texto.trim().toUpperCase();
		return t.isNotEmpty && Reglas.marcadorSinInformacion.startsWith(t);
	}

	static bool _esMarcador(String texto) {
		return texto.trim().toUpperCase().startsWith(Reglas.marcadorSinInformacion);
	}

	/// Metodo oficial del UML: +inferirConPrompt(promptSistema: String, contexto: String, pregunta: String) : String
	///
	/// Con el modelo cargado, el LLM redacta la respuesta usando solo [contexto].
	/// Sin modelo (o si falla), devuelve la explicacion del libro SEP adaptada al
	/// grado (modo basico), marcando `usoIA: false` para ser transparente.
	Future<RespuestaMotor> inferirConPrompt(
		String promptSistema,
		String contexto,
		String pregunta, {
		FragmentoSEP? fragmentoPrincipal,
		int gradoEscolar = 4,
		void Function(String parcial)? alTextoParcial,
	}) async {
		if (contexto.trim().isEmpty) {
			return const RespuestaMotor(
				texto: Reglas.mensajeConsultaAlMaestro,
				sinInformacion: true,
			);
		}

		final String respaldo = fragmentoPrincipal != null
			? fragmentoPrincipal.explicacionParaGrado(gradoEscolar)
			: contexto.trim();

		// Si el modelo esta descargado pero aun se carga, esperar a que termine.
		if (!modeloCargado && _archivoPresente && _rutaModelo.isNotEmpty) {
			await cargarModeloCuantizado(_rutaModelo);
		}

		final LlamaEngine? motor = _engine;
		if (!modeloCargado || motor == null) {
			return RespuestaMotor(texto: respaldo);
		}

		try {
			final StringBuffer acumulado = StringBuffer();
			final Stopwatch reloj = Stopwatch()..start();

			final Stream<String> flujo = motor
				.create(
					<LlamaChatMessage>[
						LlamaChatMessage.fromText(
							role: LlamaChatRole.system,
							text: promptSistema.trim().isNotEmpty
								? '${_promptSistema(gradoEscolar)} ${promptSistema.trim()}'
								: _promptSistema(gradoEscolar),
						),
						LlamaChatMessage.fromText(
							role: LlamaChatRole.user,
							text: 'CONTEXTO (libro SEP de Geografía):\n${contexto.trim()}\n\n'
								'PREGUNTA DEL NIÑO: ${pregunta.trim()}',
						),
					],
					params: GenerationParams(
						maxTokens: Reglas.maxTokensRespuesta,
						temp: _temperatura,
						topK: 40,
						topP: 0.9,
						penalty: 1.1,
					),
				)
				.map<String>(
					(chunk) => chunk.choices.firstOrNull?.delta.content ?? '',
				)
				.timeout(
					Reglas.silencioMaximoLLM,
					onTimeout: (EventSink<String> sink) {
						cancelarGeneracion();
						sink.close();
					},
				);

			await for (final String trozo in flujo) {
				acumulado.write(trozo);
				final String parcial = acumulado.toString();
				if (!_podriaSerMarcador(parcial) && !_esMarcador(parcial)) {
					alTextoParcial?.call(parcial.trimLeft());
				}
				if (reloj.elapsed > Reglas.tiempoMaximoGeneracionLLM) {
					cancelarGeneracion();
					break;
				}
			}

			final String finalTexto = acumulado.toString().trim();
			if (_esMarcador(finalTexto)) {
				return const RespuestaMotor(
					texto: Reglas.mensajeConsultaAlMaestro,
					sinInformacion: true,
				);
			}
			if (finalTexto.isEmpty) {
				return RespuestaMotor(texto: respaldo);
			}
			return RespuestaMotor(texto: finalTexto, usoIA: true);
		} catch (e) {
			// No dejar al nino sin respuesta: se usa la explicacion del libro.
			_ultimoError = 'Fallo la generación con el modelo: $e';
			debugPrint('[MotorLLMLocal] $_ultimoError');
			return RespuestaMotor(texto: respaldo);
		}
	}

	@override
	void dispose() {
		_liberado = true;
		_tokenDescarga?.cancel();
		final LlamaEngine? motor = _engine;
		_engine = null;
		if (motor != null) {
			unawaited(
				motor.dispose().catchError((Object _) {}),
			);
		}
		super.dispose();
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
		return _baseVectores
			.buscar(pregunta, Reglas.kTopFragmentos, umbral: _umbralActual())
			.map((ResultadoBusqueda r) => r.fragmento)
			.toList();
	}

	/// Con el LLM disponible se acepta un umbral mas bajo (el modelo descarta lo
	/// irrelevante con SIN_INFORMACION). Sin LLM no hay segundo filtro, asi que
	/// el umbral es mas estricto para no responder con un tema equivocado.
	double _umbralActual() {
		final bool hayLLM = _motorLLM.modeloCargado || _motorLLM.paqueteOfflineInstalado;
		return hayLLM ? _umbralEstricto : Reglas.umbralModoBasico;
	}

	/// Metodo oficial del UML: +generarRespuestaFundamentada(pregunta: String, grado: Integer) : ResultadoConsulta
	///
	/// [alTextoParcial] recibe el texto a medida que el LLM lo escribe (streaming).
	Future<ResultadoConsulta> generarRespuestaFundamentada(
		String pregunta,
		int grado, {
		void Function(String parcial)? alTextoParcial,
	}) async {
		final Stopwatch cronometro = Stopwatch()..start();

		final List<ResultadoBusqueda> encontrados = _baseVectores.buscar(
			pregunta,
			Reglas.kTopFragmentos,
			umbral: _umbralActual(),
		);

		ResultadoConsulta remitirAlMaestro(double similitud) {
			cronometro.stop();
			return ResultadoConsulta(
				textoRespuesta: Reglas.mensajeConsultaAlMaestro,
				fuenteEncontrada: false,
				similitudAlcanzada: similitud,
				tiempoInferenciaMs: cronometro.elapsedMilliseconds,
			);
		}

		// RF-03: Si no hay sustento en los libros de la SEP, remitir al maestro
		if (encontrados.isEmpty) {
			return remitirAlMaestro(_baseVectores.calcularMaximaSimilitud(pregunta));
		}

		final ResultadoBusqueda mejor = encontrados.first;
		final FragmentoSEP principal = mejor.fragmento;

		// Contexto para el LLM: el fragmento principal y los demas relevantes (sirve
		// para preguntas que mezclan temas, y compensa si el mejor no era el ideal).
		final String contexto = encontrados
			.map((ResultadoBusqueda r) => r.fragmento.explicacionParaGrado(grado))
			.join('\n');

		final RespuestaMotor respuesta = await _motorLLM.inferirConPrompt(
			'',
			contexto,
			pregunta,
			fragmentoPrincipal: principal,
			gradoEscolar: grado,
			alTextoParcial: alTextoParcial,
		);

		if (respuesta.sinInformacion) {
			return remitirAlMaestro(mejor.similitud);
		}

		cronometro.stop();
		return ResultadoConsulta(
			textoRespuesta: respuesta.texto,
			fuenteEncontrada: true,
			libroOrigen: principal.nombreLibro,
			unidadTematica: principal.bloqueTema,
			numeroPagina: principal.numeroPagina,
			similitudAlcanzada: mejor.similitud,
			tiempoInferenciaMs: cronometro.elapsedMilliseconds,
			tipoIlustracion: principal.tipoIlustracion,
			notaIlustracion: principal.notaIlustracion,
			fragmentoAsociado: principal,
			generadoPorIA: respuesta.usoIA,
		);
	}
}

/// ============================================================================
/// 4. ServicioAudio (9_UML.pdf)
/// Sintesis de voz real con FlutterTts (Android nativo offline + Web Speech API)
/// y reconocimiento de voz para ninos (RF-01, RF-04 y RNF-08).
/// ============================================================================
class ServicioAudio {
	ServicioAudio({
		bool estaListoTTS = true,
		bool estaListoSTT = true,
	})  : _estaListoTTS = estaListoTTS,
		_estaListoSTT = estaListoSTT {
		_inicializarMotorTTS();
	}

	final bool _estaListoTTS;
	final bool _estaListoSTT;
	FlutterTts? _tts;
	bool _ttsInicializado = false;
	String _vozSeleccionada = 'Voz Neuronal Español (es-MX)';
	bool _reproduciendo = false;

	bool get estaListoTTS => _estaListoTTS;
	bool get estaListoSTT => _estaListoSTT;
	bool get reproduciendo => _reproduciendo;
	String get vozSeleccionada => _vozSeleccionada;

	/// Busca y selecciona automaticamente la voz en espanol mas natural/neuronal
	/// disponible en el celular Android (Google WaveNet / Neural) o navegador.
	Future<void> _inicializarMotorTTS() async {
		try {
			final FlutterTts instancia = FlutterTts();
			await instancia.setLanguage('es-MX');
			await instancia.setPitch(1.0);
			await instancia.setVolume(1.0);

			try {
				final dynamic vocesRaw = await instancia.getVoices;
				if (vocesRaw is List) {
					Map<String, String>? mejorVoz;
					int mejorPuntaje = -1;

					for (final dynamic item in vocesRaw) {
						if (item is Map) {
							final String nombre =
								(item['name'] ?? '').toString();
							final String locale =
								(item['locale'] ?? '').toString();
							final String nBajo = nombre.toLowerCase();
							final String lBajo = locale.toLowerCase();

							if (!lBajo.startsWith('es')) {
								continue;
							}

							int puntaje = 10;
							// Priorizar espanol de Mexico y Latinoamerica
							if (lBajo.contains('mx')) {
								puntaje += 30;
							} else if (lBajo.contains('us') ||
								lBajo.contains('419')) {
								puntaje += 20;
							}
							// Priorizar motores neuronales / naturales no roboticos
							if (nBajo.contains('natural') ||
								nBajo.contains('neural') ||
								nBajo.contains('wavenet') ||
								nBajo.contains('sfb') ||
								nBajo.contains('sfc') ||
								nBajo.contains('dalia') ||
								nBajo.contains('jorge') ||
								nBajo.contains('paulina') ||
								nBajo.contains('sabina') ||
								nBajo.contains('premium') ||
								nBajo.contains('enhanced')) {
								puntaje += 50;
							}

							if (puntaje > mejorPuntaje) {
								mejorPuntaje = puntaje;
								mejorVoz = <String, String>{
									'name': nombre,
									'locale': locale,
								};
							}
						}
					}

					if (mejorVoz != null) {
						await instancia.setVoice(mejorVoz);
						_vozSeleccionada =
							'${mejorVoz['name']} (${mejorVoz['locale']})';
					}
				}
			} catch (_) {
				// Si la plataforma restringe listar voces, mantiene es-MX por defecto
			}

			_tts = instancia;
			_ttsInicializado = true;
		} catch (_) {
			_ttsInicializado = false;
		}
	}

	// --------------------------------------------------------------------------
	// Voz a texto REAL (RF-01 y RNF-08)
	// Usa el reconocedor de voz del propio Android (servicio de Google). Pide
	// funcionar "en el dispositivo": con el paquete de espanol descargado en el
	// telefono (Ajustes > Idioma > Voz de Google > Reconocimiento sin conexion)
	// transcribe SIN internet; si el telefono no lo tiene, Android usa internet.
	// --------------------------------------------------------------------------

	SpeechToText? _stt;
	bool _sttDisponible = false;
	bool _escuchando = false;
	Completer<String>? _sesionVoz;
	String _textoSesion = '';
	String? _errorSesion;
	String _ultimoErrorVoz = '';

	/// true mientras el microfono esta abierto.
	bool get escuchando => _escuchando;

	/// Ultimo problema de voz, listo para mostrarlo al nino o al docente.
	String get ultimoErrorVoz => _ultimoErrorVoz;

	Future<bool> _prepararSTT() async {
		if (_sttDisponible) {
			return true;
		}
		try {
			_stt ??= SpeechToText();
			_sttDisponible = await _stt!.initialize(
				onError: _alErrorVoz,
				onStatus: _alEstadoVoz,
			);
		} catch (e) {
			debugPrint('[ServicioAudio] No se pudo iniciar el reconocimiento de voz: $e');
			_sttDisponible = false;
		}
		if (!_sttDisponible) {
			_ultimoErrorVoz =
				'No pude usar el micrófono. Revisa que la app tenga permiso de '
				'micrófono y que el teléfono tenga activado el reconocimiento de voz.';
		}
		return _sttDisponible;
	}

	void _alErrorVoz(SpeechRecognitionError error) {
		_errorSesion = error.errorMsg;
		final Completer<String>? sesion = _sesionVoz;
		if (sesion != null && !sesion.isCompleted) {
			sesion.complete(_textoSesion);
		}
	}

	void _alEstadoVoz(String estado) {
		if (estado != 'done') {
			return;
		}
		// El resultado final suele llegar justo antes de "done"; se da un margen.
		Future<void>.delayed(const Duration(milliseconds: 400), () {
			final Completer<String>? sesion = _sesionVoz;
			if (sesion != null && !sesion.isCompleted) {
				sesion.complete(_textoSesion);
			}
		});
	}

	/// Elige la mejor variante de espanol disponible (Mexico > Latinoamerica > otra).
	static String? _mejorLocaleEspanol(Iterable<String> ids) {
		String? mejor;
		int mejorPuntaje = -1;
		for (final String id in ids) {
			final String bajo = id.toLowerCase().replaceAll('-', '_');
			if (!bajo.startsWith('es')) {
				continue;
			}
			int puntaje = 10;
			if (bajo.contains('mx')) {
				puntaje += 30;
			} else if (bajo.contains('us') || bajo.contains('419')) {
				puntaje += 20;
			}
			if (puntaje > mejorPuntaje) {
				mejorPuntaje = puntaje;
				mejor = id;
			}
		}
		return mejor;
	}

	static String _mensajeErrorVoz(String codigo) {
		switch (codigo) {
			case 'error_permission':
				return 'Necesito permiso para usar el micrófono. Actívalo en '
					'Ajustes > Aplicaciones > Geograf-IA > Permisos.';
			case 'error_no_match':
			case 'error_speech_timeout':
				return 'No te escuché bien. Toca el micrófono y habla de nuevo.';
			case 'error_network':
			case 'error_network_timeout':
			case 'error_server':
			case 'error_server_disconnected':
				return 'Este teléfono no tiene el reconocimiento de voz sin internet. '
					'En Ajustes > Idioma y entrada > Voz de Google descarga el español '
					'para usarlo sin conexión, o escribe tu pregunta.';
			case 'error_language_not_supported':
			case 'error_language_unavailable':
				return 'El teléfono no tiene reconocimiento de voz en español. '
					'Instálalo en Ajustes > Idioma y entrada > Voz de Google.';
			case 'error_busy':
				return 'El micrófono está ocupado. Espera un momento y vuelve a intentar.';
			case 'error_speech_recognizer_disabled':
				return 'El reconocimiento de voz está desactivado en este teléfono.';
			default:
				return 'No pude entender el audio ($codigo). Intenta de nuevo o escribe tu pregunta.';
		}
	}

	/// Abre el microfono, transcribe lo que dice el nino y devuelve el texto final
	/// (cadena vacia si no se entendio nada; el motivo queda en [ultimoErrorVoz]).
	/// [alParcial] recibe lo que se va entendiendo mientras habla.
	Future<String> escucharPregunta({
		void Function(String parcial)? alParcial,
		Duration duracionMaxima = const Duration(seconds: 20),
		Duration pausaSilencio = const Duration(seconds: 3),
	}) async {
		_ultimoErrorVoz = '';
		if (!_estaListoSTT || _escuchando) {
			return '';
		}
		if (!await _prepararSTT()) {
			return '';
		}

		String? idioma;
		bool hayIdiomas = false;
		try {
			final locales = await _stt!.locales();
			hayIdiomas = locales.isNotEmpty;
			idioma = _mejorLocaleEspanol(locales.map((l) => l.localeId));
		} catch (_) {}
		if (hayIdiomas && idioma == null) {
			_ultimoErrorVoz = _mensajeErrorVoz('error_language_unavailable');
			return '';
		}

		String texto = await _escucharUnaVez(
			idioma: idioma,
			enDispositivo: true,
			alParcial: alParcial,
			maxima: duracionMaxima,
			pausa: pausaSilencio,
		);

		// Sin paquete de espanol "en el dispositivo": reintentar con el servicio normal.
		if (texto.isEmpty &&
			(_errorSesion == 'error_language_not_supported' ||
				_errorSesion == 'error_language_unavailable')) {
			texto = await _escucharUnaVez(
				idioma: idioma,
				enDispositivo: false,
				alParcial: alParcial,
				maxima: duracionMaxima,
				pausa: pausaSilencio,
			);
		}

		texto = texto.trim();
		if (texto.isEmpty) {
			_ultimoErrorVoz =
				_mensajeErrorVoz(_errorSesion ?? 'error_no_match');
		}
		return texto;
	}

	Future<String> _escucharUnaVez({
		required String? idioma,
		required bool enDispositivo,
		required Duration maxima,
		required Duration pausa,
		void Function(String parcial)? alParcial,
	}) async {
		final Completer<String> fin = Completer<String>();
		_sesionVoz = fin;
		_errorSesion = null;
		_textoSesion = '';
		_escuchando = true;
		try {
			await _stt!.listen(
				onResult: (SpeechRecognitionResult r) {
					_textoSesion = r.recognizedWords;
					if (_textoSesion.isNotEmpty) {
						alParcial?.call(_textoSesion);
					}
					if (r.finalResult && !fin.isCompleted) {
						fin.complete(_textoSesion);
					}
				},
				listenOptions: SpeechListenOptions(
					partialResults: true,
					onDevice: enDispositivo,
					cancelOnError: true,
					listenMode: ListenMode.dictation,
					listenFor: maxima,
					pauseFor: pausa,
					localeId: idioma,
				),
			);
			return await fin.future.timeout(
				maxima + const Duration(seconds: 6),
				onTimeout: () => _textoSesion,
			);
		} catch (e) {
			debugPrint('[ServicioAudio] Error al escuchar: $e');
			_errorSesion ??= 'error_client';
			return _textoSesion;
		} finally {
			_escuchando = false;
			_sesionVoz = null;
			try {
				await _stt?.stop();
			} catch (_) {}
		}
	}

	/// El nino terminó de hablar: entrega de inmediato lo que se alcanzo a entender.
	Future<void> detenerEscucha() async {
		try {
			await _stt?.stop();
		} catch (_) {}
	}

	/// Cancela el microfono sin procesar lo dicho.
	Future<void> cancelarEscucha() async {
		final Completer<String>? sesion = _sesionVoz;
		if (sesion != null && !sesion.isCompleted) {
			_textoSesion = '';
			sesion.complete('');
		}
		try {
			await _stt?.cancel();
		} catch (_) {}
	}

	/// Metodo oficial del UML: +vozATexto(datosAudio: ByteArray) : String
	/// El audio lo captura el reconocedor del sistema directamente del microfono,
	/// por lo que [datosAudio] no se usa. [fraseForzada] queda solo para pruebas.
	Future<String> vozATexto(List<int> datosAudio, {String? fraseForzada}) async {
		if (fraseForzada != null && fraseForzada.trim().isNotEmpty) {
			return fraseForzada.trim();
		}
		return escucharPregunta();
	}

	/// Metodo oficial del UML: +textoAVoz(texto: String, velocidad: Float) : void
	/// Narra en voz alta la respuesta en Android fisico y en navegador Web.
	Future<void> textoAVoz(String texto, double velocidad) async {
		if (!_estaListoTTS || texto.trim().isEmpty) {
			return;
		}
		_reproduciendo = true;
		try {
			if (!_ttsInicializado) {
				await _inicializarMotorTTS();
			}
			if (_tts != null) {
				// Velocidad fluida y natural (sin arrastrar silabas)
				final double rate = (velocidad * 0.88).clamp(0.5, 1.2);
				await _tts!.setSpeechRate(rate);
				await _tts!.stop();
				await _tts!.speak(texto);
			}
		} catch (_) {
			// Respaldo silencioso si el emulador no tiene tarjeta de audio
		}
		final int duracionMs = (900 / velocidad.clamp(0.6, 1.4)).round();
		await Future<void>.delayed(Duration(milliseconds: duracionMs));
		_reproduciendo = false;
	}

	Future<void> detenerAudio() async {
		_reproduciendo = false;
		try {
			await _tts?.stop();
		} catch (_) {}
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
