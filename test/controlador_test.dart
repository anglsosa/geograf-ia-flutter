import 'package:flutter_test/flutter_test.dart';
import 'package:geograf_ia/controllers/controlador_configuracion.dart';
import 'package:geograf_ia/controllers/controlador_tutor.dart';
import 'package:geograf_ia/core/hash_seguro.dart';
import 'package:geograf_ia/core/reglas.dart';
import 'package:geograf_ia/data/esquema_sql.dart';
import 'package:geograf_ia/data/persistencia.dart';
import 'package:geograf_ia/models/entidades_db.dart';
import 'package:geograf_ia/models/modelos.dart';
import 'package:geograf_ia/services/servicio_autenticacion.dart';
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

	group('Conversacion contextual', () {
		test('lista temas disponibles sin remitir al maestro', () async {
			final ControladorTutor c = ControladorTutor();
			final ResultadoConsulta r =
				await c.procesarConsulta('Hola, ¿qué temas tenemos disponibles?');
			expect(r.esConversacional, isTrue);
			expect(r.esRemisionAlMaestro(), isFalse);
			expect(r.textoRespuesta, contains('Relieves y volcanes'));
		});

		test('agradecimiento no recupera el tema de lluvia', () async {
			final ControladorTutor c = ControladorTutor();
			final ResultadoConsulta r = await c.procesarConsulta('gracias');
			expect(r.esConversacional, isTrue);
			expect(r.fragmentoAsociado, isNull);
			expect(r.textoRespuesta, isNot(contains('lluvia')));
		});

		test('seguimiento conserva el ultimo tema respaldado', () async {
			final ControladorTutor c = ControladorTutor();
			final ResultadoConsulta inicial =
				await c.procesarConsulta('¿Cómo se forma un volcán?');
			final ResultadoConsulta seguimiento =
				await c.procesarConsulta('¿Y por qué pasa eso?');
			expect(inicial.fragmentoAsociado?.idFragmento, 'SEP-GEO-01');
			expect(seguimiento.fuenteEncontrada, isTrue);
			expect(seguimiento.fragmentoAsociado?.idFragmento, 'SEP-GEO-01');
		});

		test('explicacion mas facil reutiliza fuente y evita remision', () async {
			final ControladorTutor c = ControladorTutor();
			c.establecerGradoEscolar(6);
			await c.procesarConsulta('¿Cómo se forma un volcán?');
			final ResultadoConsulta r =
				await c.procesarConsulta('Explícamelo más fácil');
			expect(r.esConversacional, isTrue);
			expect(r.fuenteEncontrada, isTrue);
			expect(r.obtenerCitaOficial(), isNotEmpty);
		});
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

	group('Base de datos local (modo seguro y reglas de negocio)', () {
		test('El esquema define las 12 tablas y ninguna guarda nombres de personas', () {
			expect(EsquemaSql.tablas.length, 12);
			final String todo = EsquemaSql.tablas.join('\n').toLowerCase();
			expect(todo.contains('nombre_alumno'), isFalse);
			expect(todo.contains('apellido'), isFalse);
			expect(todo.contains('curp'), isFalse);
		});

		test('Sin base de datos los repositorios devuelven vacio y no fallan', () async {
			final Persistencia p = Persistencia.sinBaseDatos();
			expect(p.disponible, isFalse);
			expect(await p.aula.listarGrupos(), isEmpty);
			expect(await p.aula.crearGrupo('5° A'), isNull);
			expect(await p.aula.agregarAlumno(1), isNull);
			expect(await p.aula.cargarConfiguracion(1), isNull);
			expect(await p.conversaciones.recientes(1), isEmpty);
			expect(await p.conversaciones.consultasDe(1), isEmpty);
			expect(await p.corpus.cargarCorpusActivo(), isNull);
			expect(await p.corpus.historialActualizaciones(), isEmpty);
			final ResumenEstadisticas r = await p.conversaciones.estadisticas(1);
			expect(r.consultas, 0);
			expect(r.porcentajeResueltas, isNull);
		});

		test('El controlador sigue respondiendo con una persistencia vacia', () async {
			final ControladorTutor c = ControladorTutor(
				persistencia: Persistencia.sinBaseDatos(),
			);
			c.configuracion.vozAutomatica = false;
			await c.iniciar();
			expect(c.hayBaseDatos, isFalse);
			await c.enviarPregunta('¿Por qué llueve?');
			expect(c.mensajes.length, 2);
			expect(c.mensajes.last.idConsulta, isNull);
			expect(c.conversacionesRecientes, isEmpty);
		});

		test('Los indicadores calculan bien los porcentajes de las metas', () {
			const ResumenEstadisticas r = ResumenEstadisticas(
				consultas: 10,
				remitidas: 2,
				valoradas: 5,
				claras: 4,
				retosRespondidos: 4,
				retosAcertados: 3,
			);
			expect(r.porcentajeRemitidas, 20.0);
			expect(r.porcentajeResueltas, 80.0);
			expect(r.porcentajeAciertosRetos, 75.0);
			expect(const ResumenEstadisticas().porcentajeResueltas, isNull);
		});

		test('Aplicar una configuracion guardada respeta los rangos permitidos', () {
			final ConfiguracionAula cfg = ConfiguracionAula();
			cfg.aplicarDesde(
				ConfiguracionAula(
					gradoActual: 6,
					velocidadLecturaVoz: 9.0,
					tamanoFuente: 99,
					altoContraste: true,
					vozAutomatica: false,
				),
			);
			expect(cfg.gradoActual, 6);
			expect(cfg.velocidadLecturaVoz, 1.4);
			expect(cfg.tamanoFuente, 22);
			expect(cfg.altoContraste, isTrue);
			expect(cfg.vozAutomatica, isFalse);
		});
	});

	group('Acceso docente al panel de Configuracion (SQLite, sin internet)', () {
		DateTime ahora = DateTime(2026, 11, 18, 10);
		ServicioAutenticacion nuevoServicio() {
			final Persistencia p = Persistencia.sinBaseDatos();
			return ServicioAutenticacion(() => p, reloj: () => ahora);
		}

		setUp(() => ahora = DateTime(2026, 11, 18, 10));

		test('SHA-256 en Dart puro coincide con los vectores oficiales', () {
			expect(
				HashSeguro.sha256Hex(''),
				'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
			);
			expect(
				HashSeguro.sha256Hex('abc'),
				'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
			);
			final String sal = HashSeguro.generarSal();
			expect(sal.length, 32);
			expect(
				HashSeguro.huellaContrasena('x', sal, 10),
				isNot(HashSeguro.huellaContrasena('x', HashSeguro.generarSal(), 10)),
			);
		});

		test('Solo la contrasena entregada al docente abre la sesion', () async {
			final ServicioAutenticacion auth = nuevoServicio();
			expect(auth.sesionActiva, isFalse);
			expect((await auth.iniciarSesion('   ')).resultado, ResultadoAcceso.vacio);

			final RespuestaAcceso mala = await auth.iniciarSesion('1234');
			expect(mala.resultado, ResultadoAcceso.contrasenaIncorrecta);
			expect(mala.intentosRestantes, Reglas.maxIntentosAccesoDocente - 1);
			expect(auth.sesionActiva, isFalse);

			final RespuestaAcceso buena =
				await auth.iniciarSesion(Reglas.contrasenaDocenteInicial);
			expect(buena.exitoso, isTrue);
			expect(auth.sesionActiva, isTrue);
			expect(auth.usaContrasenaInicial, isTrue);

			auth.cerrarSesion();
			expect(auth.sesionActiva, isFalse);
		});

		test('Tras varios intentos fallidos el acceso se bloquea un momento', () async {
			final ServicioAutenticacion auth = nuevoServicio();
			RespuestaAcceso r = RespuestaAcceso.vacio();
			for (int i = 0; i < Reglas.maxIntentosAccesoDocente; i++) {
				r = await auth.iniciarSesion('adivinanza$i');
			}
			expect(r.resultado, ResultadoAcceso.bloqueado);
			// Ni la contrasena correcta entra mientras dura el bloqueo.
			final RespuestaAcceso durante =
				await auth.iniciarSesion(Reglas.contrasenaDocenteInicial);
			expect(durante.resultado, ResultadoAcceso.bloqueado);
			expect(auth.sesionActiva, isFalse);

			ahora = ahora.add(Reglas.bloqueoAccesoDocente + const Duration(seconds: 1));
			expect(await auth.bloqueoRestante(), Duration.zero);
			expect(
				(await auth.iniciarSesion(Reglas.contrasenaDocenteInicial)).exitoso,
				isTrue,
			);
		});

		test('La sesion se cierra sola tras unos minutos sin actividad', () async {
			final ServicioAutenticacion auth = nuevoServicio();
			await auth.iniciarSesion(Reglas.contrasenaDocenteInicial);

			ahora = ahora.add(Reglas.duracionSesionDocente - const Duration(seconds: 5));
			auth.renovarSesion();
			ahora = ahora.add(const Duration(minutes: 1));
			expect(auth.sesionActiva, isTrue);

			ahora = ahora.add(Reglas.duracionSesionDocente);
			expect(auth.sesionActiva, isFalse);
			auth.renovarSesion();
			expect(auth.sesionActiva, isFalse);
		});

		test('El docente cambia su contrasena y la anterior deja de servir', () async {
			final ServicioAutenticacion auth = nuevoServicio();
			expect(
				await auth.cambiarContrasena(
					actual: 'equivocada',
					nueva: 'Volcan#45',
					confirmacion: 'Volcan#45',
				),
				isNotNull,
			);
			expect(
				ServicioAutenticacion.validarNueva('abc', 'abc'),
				isNotNull,
			);
			expect(
				ServicioAutenticacion.validarNueva('Volcan#45', 'Volcan#46'),
				isNotNull,
			);
			expect(
				await auth.cambiarContrasena(
					actual: Reglas.contrasenaDocenteInicial,
					nueva: 'Volcan#45',
					confirmacion: 'Volcan#45',
				),
				isNull,
			);
			expect(auth.usaContrasenaInicial, isFalse);
			expect(
				(await auth.iniciarSesion(Reglas.contrasenaDocenteInicial)).exitoso,
				isFalse,
			);
			expect((await auth.iniciarSesion('Volcan#45')).exitoso, isTrue);
		});

		test('El codigo de recuperacion regresa a la contrasena inicial', () async {
			final ServicioAutenticacion auth = nuevoServicio();
			await auth.cambiarContrasena(
				actual: Reglas.contrasenaDocenteInicial,
				nueva: 'Montana77',
				confirmacion: 'Montana77',
			);
			final RespuestaAcceso mal = await auth.restablecerConCodigo('NO-ES');
			expect(mal.resultado, ResultadoAcceso.contrasenaIncorrecta);

			final RespuestaAcceso ok = await auth.restablecerConCodigo(
				Reglas.codigoRecuperacionDocente.toLowerCase(),
			);
			expect(ok.exitoso, isTrue);
			expect(auth.usaContrasenaInicial, isTrue);
			expect(
				(await auth.iniciarSesion(Reglas.contrasenaDocenteInicial)).exitoso,
				isTrue,
			);
		});
	});
}
