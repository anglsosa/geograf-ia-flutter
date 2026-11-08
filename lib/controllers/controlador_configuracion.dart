import '../core/reglas.dart';
import '../data/persistencia.dart';
import '../models/modelos.dart';
import '../services/servicios.dart';

/// Controlador de configuracion del aula y actualizacion por USB (9_UML.pdf).
class ControladorConfiguracion {
	ControladorConfiguracion({
		required GestorActualizacionUSB gestorUSB,
		required ConfiguracionAula configuracionAula,
		Persistencia? persistencia,
	})  : _gestorUSB = gestorUSB,
		_configuracionAula = configuracionAula,
		_persistencia = persistencia;

	final GestorActualizacionUSB _gestorUSB;
	final ConfiguracionAula _configuracionAula;

	/// Base de datos donde se guardan la version nueva y el historial (RF-05, RF-11).
	final Persistencia? _persistencia;

	GestorActualizacionUSB get gestorUSB => _gestorUSB;
	ConfiguracionAula get configuracionAula => _configuracionAula;

	/// Metodo oficial del UML:
	/// +guardarAjustesAula(grado: Integer, velocidadVoz: Float, tamTexto: Integer) : Boolean
	bool guardarAjustesAula(int grado, double velocidadVoz, int tamTexto) {
		if (!Reglas.gradosSoportados.contains(grado)) {
			return false;
		}
		if (velocidadVoz < Reglas.velocidadVozMin ||
			velocidadVoz > Reglas.velocidadVozMax) {
			return false;
		}
		if (tamTexto < Reglas.tamanoTextoMin ||
			tamTexto > Reglas.tamanoTextoMax) {
			return false;
		}
		_configuracionAula
			..fijarGrado(grado)
			..fijarVelocidadLectura(velocidadVoz)
			..fijarTamanoFuente(tamTexto);
		return true;
	}

	/// Metodo oficial del UML:
	/// +iniciarActualizacionUSB() : ReporteActualizacion (RF-05, RF-11 y RNF-07)
	Future<ReporteActualizacion> iniciarActualizacionUSB({
		String rutaPaquete = '/storage/usb_otg/SEP_CTE_2026/sep_vectores_v2.db',
		String? jsonContenido,
		required AlmacenVectoresChroma almacen,
	}) async {
		final Stopwatch sw = Stopwatch()..start();
		final String versionPrevia = almacen.versionActual;

		// Simula conexion y verificacion rapida de paquete USB (< 10 min, RNF-07)
		_gestorUSB.simularConexionUSB(true, ruta: rutaPaquete);
		await Future<void>.delayed(const Duration(milliseconds: 800));

		if (!_gestorUSB.detectarUnidadUSB() ||
			!_gestorUSB.verificarPaqueteActualizacion(rutaPaquete)) {
			sw.stop();
			await _registrarFallo(
				rutaPaquete,
				'No se detectó un paquete oficial SEP válido en la memoria USB.',
				sw,
			);
			return ReporteActualizacion(
				exitoso: false,
				mensaje: 'No se detectó un paquete oficial SEP válido en la memoria USB.',
				versionAnterior: versionPrevia,
				versionNueva: versionPrevia,
				fragmentosCargados: almacen.totalFragmentos,
				duracionSegundos: sw.elapsedMilliseconds / 1000.0,
			);
		}

		final bool exito = _gestorUSB.desempaquetarBaseVectorial(
			rutaPaquete,
			jsonContenido: jsonContenido,
		);

		if (!exito) {
			_gestorUSB.revertirCambios();
			sw.stop();
			await _registrarFallo(
				rutaPaquete,
				'Error al desempaquetar la base vectorial. Se restauró la versión anterior.',
				sw,
			);
			return ReporteActualizacion(
				exitoso: false,
				mensaje: 'Error al desempaquetar la base vectorial. Se restauró la versión anterior.',
				versionAnterior: versionPrevia,
				versionNueva: almacen.versionActual,
				fragmentosCargados: almacen.totalFragmentos,
				duracionSegundos: sw.elapsedMilliseconds / 1000.0,
			);
		}

		// Guardado en la base de datos: todo o nada. Si SQLite falla, se deshace y se
		// restaura la version anterior en memoria para no quedar a medias.
		final Persistencia? p = _persistencia;
		if (p != null && p.disponible) {
			try {
				await p.corpus.registrarActualizacionUsb(
					rutaPaquete: rutaPaquete,
					versionNueva: almacen.versionActual,
					fragmentos: almacen.fragmentos,
					duracionSeg: sw.elapsedMilliseconds / 1000.0,
				);
			} catch (e) {
				_gestorUSB.revertirCambios();
				sw.stop();
				await _registrarFallo(
					rutaPaquete,
					'No se pudo guardar la actualización en la base de datos. Se restauró la versión anterior.',
					sw,
				);
				return ReporteActualizacion(
					exitoso: false,
					mensaje:
						'No se pudo guardar la actualización en la base de datos. Se restauró la versión anterior.',
					versionAnterior: versionPrevia,
					versionNueva: almacen.versionActual,
					fragmentosCargados: almacen.totalFragmentos,
					duracionSegundos: sw.elapsedMilliseconds / 1000.0,
				);
			}
		}
		sw.stop();

		return ReporteActualizacion(
			exitoso: true,
			mensaje:
				'¡Actualización USB completada con éxito! Base oficial SEP actualizada a ${almacen.versionActual}.',
			versionAnterior: versionPrevia,
			versionNueva: almacen.versionActual,
			fragmentosCargados: almacen.totalFragmentos,
			duracionSegundos: sw.elapsedMilliseconds / 1000.0,
		);
	}

	/// Deja constancia en el historial de un intento de actualizacion que fallo.
	Future<void> _registrarFallo(
		String rutaPaquete,
		String mensaje,
		Stopwatch cronometro,
	) async {
		final Persistencia? p = _persistencia;
		if (p == null || !p.disponible) {
			return;
		}
		try {
			await p.corpus.registrarActualizacionFallida(
				rutaPaquete: rutaPaquete,
				mensaje: mensaje,
				duracionSeg: cronometro.elapsedMilliseconds / 1000.0,
			);
		} catch (_) {}
	}
}
