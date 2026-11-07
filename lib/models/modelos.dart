/// Modelos de datos oficiales conforme al Diagrama de Clases UML (9_UML.pdf)
/// y los requerimientos RF-01..RF-12 / RNF-01..RNF-12.

/// Representa un fragmento verificado de los libros de texto gratuitos de la SEP.
class FragmentoSEP {
	const FragmentoSEP({
		required this.idFragmento,
		required this.gradoNivel,
		required this.nombreLibro,
		required this.bloqueTema,
		required this.numeroPagina,
		required this.textoContenido,
		this.explicacion4to = '',
		this.explicacion5to = '',
		this.explicacion6to = '',
		this.tipoIlustracion = '',
		this.notaIlustracion = '',
		this.preguntaComprobacion = '',
		this.opcionesComprobacion = const <String>[],
		this.indiceRespuestaCorrecta = 0,
	});

	final String idFragmento;
	final int gradoNivel;
	final String nombreLibro;
	final String bloqueTema;
	final int numeroPagina;
	final String textoContenido;

	// Explicaciones pre-adaptadas o enriquecidas por nivel para el motor local
	final String explicacion4to;
	final String explicacion5to;
	final String explicacion6to;

	// Apoyo visual didactico (6_DisenoUI.pdf - Pantalla de conversacion)
	final String tipoIlustracion;
	final String notaIlustracion;

	// Pregunta pedagogica de comprobacion (Equipo6_App_Greograf-ia.pdf - Objetivo General)
	final String preguntaComprobacion;
	final List<String> opcionesComprobacion;
	final int indiceRespuestaCorrecta;

	/// Metodo oficial del UML: +obtenerMetadatos() : String
	String obtenerMetadatos() {
		return '$nombreLibro · $bloqueTema · Pág. $numeroPagina';
	}

	factory FragmentoSEP.desdeJson(Map<String, dynamic> json) {
		return FragmentoSEP(
			idFragmento: (json['idFragmento'] ?? '').toString(),
			gradoNivel: (json['gradoNivel'] is int) ? json['gradoNivel'] as int : 4,
			nombreLibro: (json['nombreLibro'] ?? 'Libro SEP Geografía').toString(),
			bloqueTema: (json['bloqueTema'] ?? 'Bloque 1').toString(),
			numeroPagina: (json['numeroPagina'] is int) ? json['numeroPagina'] as int : 10,
			textoContenido: (json['textoContenido'] ?? '').toString(),
			explicacion4to: (json['explicacion4to'] ?? '').toString(),
			explicacion5to: (json['explicacion5to'] ?? '').toString(),
			explicacion6to: (json['explicacion6to'] ?? '').toString(),
			tipoIlustracion: (json['tipoIlustracion'] ?? '').toString(),
			notaIlustracion: (json['notaIlustracion'] ?? '').toString(),
			preguntaComprobacion: (json['preguntaComprobacion'] ?? '').toString(),
			opcionesComprobacion: (json['opcionesComprobacion'] is List)
				? (json['opcionesComprobacion'] as List<dynamic>)
					.map((dynamic e) => e.toString())
					.toList()
				: const <String>[],
			indiceRespuestaCorrecta: (json['indiceRespuestaCorrecta'] is int)
				? json['indiceRespuestaCorrecta'] as int
				: 0,
		);
	}
}

/// Resultado tipado de una consulta al ServicioRAG (9_UML.pdf).
class ResultadoConsulta {
	const ResultadoConsulta({
		required this.textoRespuesta,
		required this.fuenteEncontrada,
		this.libroOrigen = '',
		this.unidadTematica = '',
		this.numeroPagina = 0,
		this.similitudAlcanzada = 0.0,
		this.tiempoInferenciaMs = 0,
		this.tipoIlustracion = '',
		this.notaIlustracion = '',
		this.fragmentoAsociado,
	});

	final String textoRespuesta;
	final bool fuenteEncontrada;
	final String libroOrigen;
	final String unidadTematica;
	final int numeroPagina;
	final double similitudAlcanzada;
	final int tiempoInferenciaMs;
	final String tipoIlustracion;
	final String notaIlustracion;
	final FragmentoSEP? fragmentoAsociado;

	/// Metodo oficial del UML: +obtenerCitaOficial() : String (RF-10)
	String obtenerCitaOficial() {
		if (!fuenteEncontrada || libroOrigen.isEmpty) {
			return '';
		}
		if (numeroPagina > 0) {
			return '$libroOrigen · $unidadTematica (Pág. $numeroPagina)';
		}
		return '$libroOrigen · $unidadTematica';
	}

	/// Metodo oficial del UML: +esRemisionAlMaestro() : Boolean (RF-03)
	bool esRemisionAlMaestro() {
		return !fuenteEncontrada;
	}
}

/// Configuracion del aula administrada por el docente o alumno (9_UML.pdf).
class ConfiguracionAula {
	ConfiguracionAula({
		int gradoActual = 4,
		double velocidadLecturaVoz = 1.0,
		int tamanoFuente = 19,
		this.altoContraste = false,
		this.vozAutomatica = true,
	})  : _gradoActual = gradoActual,
		_velocidadLecturaVoz = velocidadLecturaVoz,
		_tamanoFuente = tamanoFuente;

	int _gradoActual;
	double _velocidadLecturaVoz;
	int _tamanoFuente;
	bool altoContraste;
	bool vozAutomatica;

	int get gradoActual => _gradoActual;
	double get velocidadLecturaVoz => _velocidadLecturaVoz;
	int get tamanoFuente => _tamanoFuente;

	/// Metodo oficial del UML: +obtenerGrado() : Integer
	int obtenerGrado() => _gradoActual;

	/// Metodo oficial del UML: +fijarGrado(grado: Integer) : void
	void fijarGrado(int grado) {
		if (grado >= 4 && grado <= 6) {
			_gradoActual = grado;
		}
	}

	void fijarVelocidadLectura(double velocidad) {
		_velocidadLecturaVoz = velocidad.clamp(0.6, 1.4);
	}

	void fijarTamanoFuente(int tamano) {
		_tamanoFuente = tamano.clamp(16, 26);
	}

	ConfiguracionAula copiarCon({
		int? gradoActual,
		double? velocidadLecturaVoz,
		int? tamanoFuente,
		bool? altoContraste,
		bool? vozAutomatica,
	}) {
		return ConfiguracionAula(
			gradoActual: gradoActual ?? _gradoActual,
			velocidadLecturaVoz: velocidadLecturaVoz ?? _velocidadLecturaVoz,
			tamanoFuente: tamanoFuente ?? _tamanoFuente,
			altoContraste: altoContraste ?? this.altoContraste,
			vozAutomatica: vozAutomatica ?? this.vozAutomatica,
		);
	}
}

/// Reporte devuelto tras el proceso de actualizacion por USB (9_UML.pdf, RF-05 y RF-11).
class ReporteActualizacion {
	const ReporteActualizacion({
		required this.exitoso,
		required this.mensaje,
		required this.versionAnterior,
		required this.versionNueva,
		required this.fragmentosCargados,
		required this.duracionSegundos,
	});

	final bool exitoso;
	final String mensaje;
	final String versionAnterior;
	final String versionNueva;
	final int fragmentosCargados;
	final double duracionSegundos;
}

/// Estados de retroalimentacion visual de la mascota digital (6_DisenoUI.pdf).
enum EstadoMascota {
	reposo,
	escuchando,
	pensando,
	hablando,
}

enum RolMensaje {
	alumno,
	tutor,
	retoPedagogico,
}

/// Mensaje individual dentro de la conversacion tutor-alumno.
class MensajeChat {
	MensajeChat({
		required this.id,
		required this.rol,
		required this.texto,
		this.citaFuente = '',
		this.esRemisionMaestro = false,
		this.tiempoMs = 0,
		this.tipoIlustracion = '',
		this.notaIlustracion = '',
		this.preguntaReto = '',
		this.opcionesReto = const <String>[],
		this.indiceCorrectoReto = 0,
		this.opcionSeleccionadaReto,
	});

	final String id;
	final RolMensaje rol;
	final String texto;
	final String citaFuente;
	final bool esRemisionMaestro;
	final int tiempoMs;
	final String tipoIlustracion;
	final String notaIlustracion;

	// Campos para el componente pedagogico de comprobacion de aprendizaje
	final String preguntaReto;
	final List<String> opcionesReto;
	final int indiceCorrectoReto;
	int? opcionSeleccionadaReto;
}

