import 'package:flutter_test/flutter_test.dart';
import 'package:geograf_ia/controllers/controlador_configuracion.dart';
import 'package:geograf_ia/controllers/controlador_tutor.dart';
import 'package:geograf_ia/core/reglas.dart';
import 'package:geograf_ia/models/modelos.dart';
import 'package:geograf_ia/services/servicios.dart';

void main() {
	test('Sanear rechaza texto muy corto y recorta el largo excesivo', () {
		expect(ControladorTutor.sanear('  a '), isNull);
		expect(
			ControladorTutor.sanear('x' * 400)!.length,
			Reglas.maxCaracteresPregunta,
		);
	});

	test('RF-08: Grado fuera de escala (4, 5, 6) se ignora y adapta respuesta', () async {
		final ControladorTutor c = ControladorTutor();
		c.establecerGradoEscolar(99);
		expect(c.configuracion.obtenerGrado(), 4);

		final ResultadoConsulta r4 =
			await c.procesarConsulta('¿Cómo se forma un volcán?');
		c.establecerGradoEscolar(6);
		final ResultadoConsulta r6 =
			await c.procesarConsulta('¿Cómo se forma un volcán?');

		expect(r4.fuenteEncontrada, isTrue);
		expect(r6.fuenteEncontrada, isTrue);
		expect(r4.textoRespuesta, isNot(equals(r6.textoRespuesta)));
		expect(r6.obtenerCitaOficial(), contains('Libro SEP Geografía'));
	});

	test('RF-03: Pregunta fuera de la base SEP remite al maestro', () async {
		final ControladorTutor c = ControladorTutor();
		final ResultadoConsulta r =
			await c.procesarConsulta('¿Cuánto cuesta un videojuego en línea?');
		expect(r.esRemisionAlMaestro(), isTrue);
		expect(r.textoRespuesta, Reglas.mensajeConsultaAlMaestro);
	});

	test('RF-05 y RF-11: Actualizacion USB agrega contenidos y confirma exito', () async {
		final ControladorTutor c = ControladorTutor();
		final ControladorConfiguracion cfg = ControladorConfiguracion(
			gestorUSB: c.gestorUSB,
			configuracionAula: c.configuracion,
		);
		final int antes = c.pipelineRAG.baseVectores.totalFragmentos;
		final ReporteActualizacion rep = await cfg.iniciarActualizacionUSB(
			almacen: c.pipelineRAG.baseVectores,
		);
		expect(rep.exitoso, isTrue);
		expect(c.pipelineRAG.baseVectores.totalFragmentos, greaterThan(antes));
	});

	group('Recuperacion de contexto (BM25 por raices)', () {
		final AlmacenVectoresChroma almacen = AlmacenVectoresChroma();

		test('El corpus ampliado tiene al menos 70 temas con ids unicos', () {
			expect(almacen.totalFragmentos, greaterThanOrEqualTo(70));
		});

		// pregunta -> ids aceptados como primer resultado (algunos temas se
		// solapan a proposito, por ejemplo "estados de Mexico").
		const Map<String, List<String>> esperadas = <String, List<String>>{
			'¿Cómo se forma un volcán?': <String>['SEP-GEO-01'],
			'como nacen los volcanes': <String>['SEP-GEO-01'],
			'¿Por qué llueve?': <String>['SEP-GEO-02'],
			'¿A dónde van los ríos?': <String>['SEP-GEO-03', 'SEP-GEO-28'],
			'¿Por qué hay día y noche?': <String>['SEP-GEO-04'],
			'¿Cuántos estados tiene México?': <String>['SEP-GEO-05', 'SEP-GEO-66'],
			'¿Cuáles son los continentes del mundo?': <String>['SEP-GEO-06'],
			'¿Por qué tiembla en México?': <String>['SEP-GEO-07', 'SEP-GEO-46'],
			'¿Qué es la agricultura?': <String>['SEP-GEO-10', 'SEP-GEO-54'],
			'cuales son las capas de la tierra': <String>['SEP-GEO-12'],
			'cuantos planetas hay en el sistema solar': <String>['SEP-GEO-13'],
			'para que sirve una brujula': <String>['SEP-GEO-14'],
			'que es la latitud': <String>['SEP-GEO-17'],
			'que es el ecuador': <String>['SEP-GEO-18'],
			'cual es la montana mas alta del mundo': <String>['SEP-GEO-26'],
			'como puedo ahorrar agua': <String>['SEP-GEO-30'],
			'que es un huracan': <String>['SEP-GEO-36'],
			'que es el calentamiento global': <String>['SEP-GEO-43'],
			'que significa reciclar': <String>['SEP-GEO-44'],
			'que lleva una mochila de emergencia': <String>['SEP-GEO-47'],
			'cuantos habitantes tiene mexico': <String>['SEP-GEO-50'],
			'cual es el continente mas grande': <String>['SEP-GEO-61'],
			'donde esta la antartida': <String>['SEP-GEO-64'],
			'cual es la capital de Nuevo León': <String>['SEP-GEO-67'],
			'cual es la capital de Jalisco': <String>['SEP-GEO-68'],
			'cual es la capital de Yucatán': <String>['SEP-GEO-69'],
			'cual es la capital de Argentina': <String>['SEP-GEO-70'],
			'cual es la capital de Japón': <String>['SEP-GEO-71'],
		};

		esperadas.forEach((String pregunta, List<String> ids) {
			test('"$pregunta" recupera ${ids.join(' o ')}', () {
				final List<ResultadoBusqueda> r = almacen.buscar(pregunta, 3);
				expect(r, isNotEmpty);
				expect(ids, contains(r.first.fragmento.idFragmento));
			});
		});

		for (final String fuera in <String>[
			'¿Cuánto cuesta un videojuego en línea?',
			'cuentame un chiste',
			'como se hace un pastel de chocolate',
			'quien gano el mundial de futbol',
			'cual es la receta de los tacos',
		]) {
			test('"$fuera" no tiene sustento en los libros SEP', () {
				expect(almacen.buscar(fuera, 3), isEmpty);
			});
		}
	});

	group('Motor de IA local sin modelo instalado (modo basico)', () {
		test('Estado inicial honesto: no hay modelo cargado ni instalado', () {
			final MotorLLMLocal motor = MotorLLMLocal();
			expect(motor.estado, EstadoModelo.noInstalado);
			expect(motor.modeloCargado, isFalse);
			expect(motor.paqueteOfflineInstalado, isFalse);
			expect(motor.nombreModeloActivo, contains('Modo básico'));
		});

		test('Responde con la explicacion del libro y lo declara (no es IA)', () async {
			final ControladorTutor c = ControladorTutor();
			c.establecerGradoEscolar(5);
			final ResultadoConsulta r =
				await c.procesarConsulta('¿Cómo se forma un volcán?');
			expect(r.fuenteEncontrada, isTrue);
			expect(r.generadoPorIA, isFalse);
			expect(r.textoRespuesta, contains('magma'));
		});

		test('El streaming no se activa sin modelo (solo respuesta final)', () async {
			final ControladorTutor c = ControladorTutor();
			final List<String> parciales = <String>[];
			await c.procesarConsulta(
				'¿Por qué llueve?',
				alTextoParcial: parciales.add,
			);
			expect(parciales, isEmpty);
		});

		test('enviarPregunta agrega pregunta y respuesta al chat', () async {
			final ControladorTutor c = ControladorTutor();
			c.configuracion.vozAutomatica = false;
			await c.enviarPregunta('¿A dónde van los ríos?');
			expect(c.mensajes.length, 2);
			expect(c.mensajes.last.rol, RolMensaje.tutor);
			expect(c.mensajes.last.enProgreso, isFalse);
			expect(c.mensajes.last.citaFuente, isNotEmpty);
			expect(c.ocupado, isFalse);
		});
	});
}
