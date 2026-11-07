import '../models/modelos.dart';

/// Construye un fragmento del temario de Geografia de primaria con formato compacto.
///
/// IMPORTANTE (RF-10): estos fragmentos siguen los temas del programa de Geografia
/// de 4o a 6o de primaria de la SEP, pero estan redactados para este proyecto; no
/// son transcripciones de un libro. Por eso NO llevan numero de pagina
/// (numeroPagina = 0 y la cita solo muestra el tema). Si se cargan paginas reales
/// desde los libros, actualiza `numeroPagina` y `nombreLibro`.
///
/// [claves] es una lista de palabras clave y formas en que un nino pregunta;
/// alimenta la busqueda semantica. [correcta] es el indice de la opcion correcta.
FragmentoSEP frag(
	String id,
	int grado,
	String tema,
	String claves,
	String explicacion4to,
	String explicacion5to,
	String explicacion6to,
	String ilustracion,
	String nota,
	String pregunta,
	List<String> opciones,
	int correcta,
) {
	return FragmentoSEP(
		idFragmento: id,
		gradoNivel: grado,
		nombreLibro: 'Geografía de primaria · temario SEP $grado°',
		bloqueTema: tema,
		numeroPagina: 0,
		textoContenido: claves,
		explicacion4to: explicacion4to,
		explicacion5to: explicacion5to,
		explicacion6to: explicacion6to,
		tipoIlustracion: ilustracion,
		notaIlustracion: nota,
		preguntaComprobacion: pregunta,
		opcionesComprobacion: opciones,
		indiceRespuestaCorrecta: correcta,
	);
}
