import '../core/reglas.dart';
import '../models/modelos.dart';
import '../services/servicios.dart';

/// Controlador de configuracion del aula y actualizacion por USB (9_UML.pdf).
class ControladorConfiguracion {
	ControladorConfiguracion({
		required GestorActualizacionUSB gestorUSB,
		required ConfiguracionAula configuracionAula,
	})  : _gestorUSB = gestorUSB,
		_configuracionAula = configuracionAula;

	final GestorActualizacionUSB _gestorUSB;
	final ConfiguracionAula _configuracionAula;

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
		sw.stop();

		if (!exito) {
			_gestorUSB.revertirCambios();
			return ReporteActualizacion(
				exitoso: false,
				mensaje: 'Error al desempaquetar la base vectorial. Se restauró la versión anterior.',
				versionAnterior: versionPrevia,
				versionNueva: almacen.versionActual,
				fragmentosCargados: almacen.totalFragmentos,
				duracionSegundos: sw.elapsedMilliseconds / 1000.0,
			);
		}

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
}

