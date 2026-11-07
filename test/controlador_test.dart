import 'package:flutter_test/flutter_test.dart';
import 'package:geograf_ia/controllers/controlador_configuracion.dart';
import 'package:geograf_ia/controllers/controlador_tutor.dart';
import 'package:geograf_ia/core/reglas.dart';
import 'package:geograf_ia/models/modelos.dart';

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
}

