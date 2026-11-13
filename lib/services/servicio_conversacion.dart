import '../core/reglas.dart';
import '../models/modelos.dart';
import 'servicios.dart';

/// Interpreta mensajes sobre la conversación antes de consultar el corpus.
///
/// Esta capa no inventa contenido académico: responde saludos y ayuda con datos
/// locales, y conserva únicamente el último tema respaldado para resolver
/// seguimientos breves.
class ServicioConversacion {
	ServicioConversacion(this._almacen);

	final AlmacenVectoresChroma _almacen;
	FragmentoSEP? _ultimoFragmento;
	String _ultimaPregunta = '';

	FragmentoSEP? get ultimoFragmento => _ultimoFragmento;

	void reiniciar() {
		_ultimoFragmento = null;
		_ultimaPregunta = '';
	}

	void restaurarTema(String claveFragmento, {String ultimaPregunta = ''}) {
		for (final FragmentoSEP fragmento in _almacen.fragmentos) {
			if (fragmento.idFragmento == claveFragmento) {
				_ultimoFragmento = fragmento;
				_ultimaPregunta = ultimaPregunta;
				return;
			}
		}
	}

	void recordarResultado(String pregunta, ResultadoConsulta resultado) {
		final FragmentoSEP? fragmento = resultado.fragmentoAsociado;
		if (fragmento != null) {
			_ultimoFragmento = fragmento;
			_ultimaPregunta = pregunta;
		}
	}

	/// Responde intenciones que no requieren recuperar una explicación escolar.
	ResultadoConsulta? responderSiAplica(String pregunta, int grado) {
		final String normalizada = AlmacenVectoresChroma.normalizar(pregunta);

		if (_solicitaTemas(normalizada)) {
			return _respuestaConversacional(_catalogoDisponible());
		}
		if (_esAgradecimiento(normalizada)) {
			return _respuestaConversacional(
				'¡Con gusto! Podemos seguir con este tema o explorar otro de Geografía.',
			);
		}
		if (_esDespedida(normalizada)) {
			return _respuestaConversacional(
				'¡Hasta luego! Cuando quieras, seguimos explorando Geografía.',
			);
		}
		if (_esSaludoSimple(normalizada)) {
			return _respuestaConversacional(
				'¡Hola! Soy Geograf-IA. Puedes preguntarme sobre volcanes, clima, mapas, '
				'ríos y otros temas del material disponible.',
			);
		}
		if (_pideExplicacionMasSimple(normalizada)) {
			final FragmentoSEP? fragmento = _ultimoFragmento;
			if (fragmento == null) {
				return _respuestaConversacional(
					'Claro. ¿Qué tema quieres que explique de una manera más sencilla?',
				);
			}
			final int gradoMasSimple = grado > 4 ? grado - 1 : 4;
			return ResultadoConsulta(
				textoRespuesta:
						'Claro. ${fragmento.explicacionParaGrado(gradoMasSimple)}',
				fuenteEncontrada: true,
				libroOrigen: fragmento.nombreLibro,
				unidadTematica: fragmento.bloqueTema,
				numeroPagina: fragmento.numeroPagina,
				fragmentoAsociado: fragmento,
				tipoIlustracion: fragmento.tipoIlustracion,
				notaIlustracion: fragmento.notaIlustracion,
				esConversacional: true,
			);
		}
		if (_esSeguimiento(normalizada) && _ultimoFragmento == null) {
			return _respuestaConversacional(
				'Quiero entenderte bien. ¿De qué tema estás hablando?',
			);
		}
		return null;
	}

	/// Convierte un seguimiento corto en una consulta recuperable sin cambiar la
	/// pregunta que se muestra ni se guarda en el historial.
	String prepararConsulta(String pregunta) {
		final String normalizada = AlmacenVectoresChroma.normalizar(pregunta);
		final FragmentoSEP? fragmento = _ultimoFragmento;
		if (fragmento == null || !_esSeguimiento(normalizada)) {
			return pregunta;
		}
		return '$pregunta. Tema anterior: ${fragmento.bloqueTema}. '
				'Pregunta anterior: $_ultimaPregunta. Palabras del tema: '
				'${fragmento.textoContenido}';
	}

	ResultadoConsulta _respuestaConversacional(String texto) {
		return ResultadoConsulta(
			textoRespuesta: texto,
			fuenteEncontrada: false,
			esConversacional: true,
		);
	}

	String _catalogoDisponible() {
		final List<String> temas = <String>[];
		for (final Map<String, String> categoria in Reglas.categoriasTemas) {
			final String pregunta = categoria['pregunta'] ?? '';
			if (pregunta.isNotEmpty &&
					_almacen.calcularMaximaSimilitud(pregunta) >=
							Reglas.umbralEstrictoRAG) {
				temas.add(categoria['titulo'] ?? 'Geografía');
			}
		}
		if (temas.isEmpty) {
			for (final FragmentoSEP fragmento in _almacen.fragmentos) {
				final String tema = fragmento.bloqueTema.split('·').last.trim();
				if (tema.isNotEmpty && !temas.contains(tema)) {
					temas.add(tema);
				}
				if (temas.length == 5) {
					break;
				}
			}
		}
		final String lista = temas.map((String tema) => '• $tema').join('\n');
		return 'Puedes preguntarme sobre estos temas disponibles:\n$lista\n'
				'Por ejemplo: “¿Cómo se forma un volcán?”';
	}

	bool _solicitaTemas(String texto) {
		return texto.contains('temas disponibles') ||
				texto.contains('que temas') ||
				texto.contains('puedo preguntar') ||
				texto.contains('puedo preguntarte') ||
				texto.contains('que sabes') ||
				texto.contains('ayuda para empezar') ||
				texto == 'ayuda';
	}

	bool _esAgradecimiento(String texto) {
		return RegExp(r'^(muchas )?gracias[ a-z]*$').hasMatch(texto);
	}

	bool _esDespedida(String texto) {
		return texto == 'adios' || texto == 'hasta luego' || texto == 'nos vemos';
	}

	bool _esSaludoSimple(String texto) {
		return RegExp(
			r'^(hola|buenos dias|buenas tardes|buenas noches|hola como estas)$',
		).hasMatch(texto);
	}

	bool _pideExplicacionMasSimple(String texto) {
		return texto.contains('mas facil') ||
				texto.contains('mas sencillo') ||
				texto.contains('no entendi') ||
				texto.contains('explicamelo otra vez');
	}

	bool _esSeguimiento(String texto) {
		if (texto.isEmpty) {
			return false;
		}
		return texto.startsWith('y ') ||
				texto.contains('eso') ||
				texto.contains('ese tema') ||
				texto.contains('lo anterior') ||
				texto == 'por que' ||
				texto == 'dame un ejemplo' ||
				texto == 'otro ejemplo';
	}
}
