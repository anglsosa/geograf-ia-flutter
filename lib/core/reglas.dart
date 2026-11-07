/// Reglas estrictas del sistema Geograf-IA (RF-01 a RF-12 y RNF-01 a RNF-12).
/// Ninguna pantalla ni controlador debe usar valores magicos fuera de esta clase.
class Reglas {
	Reglas._();

	// RF-08: Escala fija de grados escolares soportados (Primaria Alta SEP).
	static const List<int> gradosSoportados = <int>[4, 5, 6];
	static const int gradoPorDefecto = 4;

	// Limites estrictos de entrada para evitar desbordamiento de contexto o mal uso.
	static const int maxCaracteresPregunta = 180;
	static const int minCaracteresPregunta = 3;

	// RNF-01: Objetivo de respuesta en procesador ARM de bajo consumo (8 segundos).
	// Con el LLM real el primer token puede tardar mas en telefonos modestos, por
	// eso el texto se muestra en streaming y estos son solo limites duros:
	//  - tiempoMaximoRespuesta: tope absoluto de una consulta completa.
	//  - tiempoMaximoGeneracionLLM: tope de generacion; si se agota se conserva
	//    el texto ya generado (o se usa la explicacion del libro si no hay nada).
	//  - silencioMaximoLLM: tiempo maximo sin recibir ningun token nuevo.
	static const Duration tiempoMaximoRespuesta = Duration(minutes: 3);
	static const Duration tiempoMaximoGeneracionLLM = Duration(seconds: 100);
	static const Duration silencioMaximoLLM = Duration(seconds: 60);

	// Modelo LLM local (GGUF cuantizado a 4 bits). Fuente publica en Hugging Face.
	static const String modeloRepoHuggingFace = 'Qwen/Qwen2.5-1.5B-Instruct-GGUF';
	static const String modeloArchivoGguf = 'qwen2.5-1.5b-instruct-q4_k_m.gguf';
	static const String modeloNombre = 'Qwen2.5-1.5B-Instruct (GGUF 4-bit)';
	static const int modeloBytesEsperados = 1117320736;
	static const String modeloSha256 =
		'6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e';
	static const int ventanaContextoLLM = 2048;
	static const int maxTokensRespuesta = 220;
	static const double temperaturaLLM = 0.2;

	// Marcador que el LLM debe devolver cuando el contexto SEP no responde (RF-03).
	static const String marcadorSinInformacion = 'SIN_INFORMACION';

	// RNF-07: Tiempo maximo permitido para actualizacion por USB (10 minutos).
	static const Duration tiempoMaximoActualizacionUSB = Duration(minutes: 10);

	// RNF-09: Presupuesto maximo de almacenamiento local (4 GB = 4096 MB).
	static const double maxAlmacenamientoMB = 4096.0;

	// RAG (RF-02 y RF-03): Umbral estricto de similitud coseno y top-K fragmentos.
	// El puntaje es BM25 normalizado (0 a 1) sobre raices de palabras. Se calibro
	// con bancos de preguntas de ninos y de preguntas fuera de tema:
	//  - umbralEstrictoRAG: con LLM instalado. Es mas bajo porque el modelo vuelve
	//    a filtrar (marcador SIN_INFORMACION) lo que no corresponda.
	//  - umbralModoBasico: sin LLM no hay segundo filtro, por eso es mas alto.
	//  - fraccionContextoRAG: un fragmento extra solo entra al contexto si alcanza
	//    esta fraccion del puntaje del mejor.
	static const double umbralEstrictoRAG = 0.25;
	static const double umbralModoBasico = 0.35;
	static const double fraccionContextoRAG = 0.5;
	static const int kTopFragmentos = 3;
	// Conservado por compatibilidad con el UML; el indice ahora es disperso (sin hash).
	static const int dimensionEmbedding = 0;

	// Anti-spam / antirrebote para evitar que los ninos rompan el flujo tocando repetidamente.
	static const Duration pausaEntreConsultas = Duration(milliseconds: 700);

	// Accesibilidad (RNF-08 y 6_DisenoUI.pdf): Rangos de voz y tamano de fuente.
	static const double velocidadVozMin = 0.6;
	static const double velocidadVozMax = 1.4;
	static const double velocidadVozPorDefecto = 1.0;

	static const int tamanoTextoMin = 14;
	static const int tamanoTextoMax = 22;
	static const int tamanoTextoPorDefecto = 16;

	// Pregunta pedagogica de comprobacion (Objetivo General - Equipo6_App_Greograf-ia.pdf):
	// Cada N consultas resueltas, el tutor lanza un reto breve para verificar comprension.
	static const int consultasParaRetoPedagogico = 2;

	// RF-03: Mensaje normativo cuando la consulta no existe en los libros de la SEP.
	static const String mensajeConsultaAlMaestro =
		'No encontré suficiente información sobre eso en tus libros de texto de la SEP. '
		'¡Te recomiendo preguntarle a tu maestra o maestro en el salón!';

	// Categorias del menu lateral (6_DisenoUI.pdf - Pantalla de side bar).
	static const List<Map<String, String>> categoriasTemas = <Map<String, String>>[
		<String, String>{
			'id': 'climas',
			'titulo': 'Climas y naturaleza',
			'icono': 'wb_sunny',
			'pregunta': '¿Por qué llueve y qué tipos de clima hay en México?',
		},
		<String, String>{
			'id': 'relieves',
			'titulo': 'Relieves y volcanes',
			'icono': 'terrain',
			'pregunta': '¿Cómo se forma un volcán y qué es el relieve?',
		},
		<String, String>{
			'id': 'mapas',
			'titulo': 'Mapas y continentes',
			'icono': 'map',
			'pregunta': '¿Cuáles son los continentes y para qué sirven los mapas?',
		},
		<String, String>{
			'id': 'agua',
			'titulo': 'Ríos y océanos',
			'icono': 'water',
			'pregunta': '¿A dónde van los ríos y por qué son importantes?',
		},
		<String, String>{
			'id': 'mexico',
			'titulo': 'Estados de México',
			'icono': 'flag',
			'pregunta': '¿Cuántos estados tiene México y cuál es su capital?',
		},
	];

	// Tarjetas de "Ideas para explorar" para evitar que el nino se congele (6_DisenoUI.pdf).
	static const List<Map<String, String>> ideasParaExplorar = <Map<String, String>>[
		<String, String>{
			'pregunta': '¿Cómo se forma un volcán?',
			'subtitulo': 'El interior de la Tierra',
			'icono': 'volcano',
		},
		<String, String>{
			'pregunta': '¿Por qué llueve?',
			'subtitulo': 'El agua y el clima',
			'icono': 'cloud',
		},
		<String, String>{
			'pregunta': '¿A dónde van los ríos?',
			'subtitulo': 'Un viaje hacia el mar',
			'icono': 'waves',
		},
		<String, String>{
			'pregunta': '¿Por qué hay día y noche?',
			'subtitulo': 'Los movimientos de la Tierra',
			'icono': 'public',
		},
	];

	// Preguntas sugeridas (chips de la llamada de voz). Ya NO se usan como voz simulada.
	static const List<String> preguntasVozDemo = <String>[
		'¿Cómo se forma un volcán?',
		'¿Por qué llueve?',
		'¿A dónde van los ríos?',
		'¿Cuántos estados tiene México?',
		'¿Cuáles son los continentes del mundo?',
		'¿Por qué tiembla en México?',
	];
}
