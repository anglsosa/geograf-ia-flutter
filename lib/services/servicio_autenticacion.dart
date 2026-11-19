import 'package:flutter/foundation.dart';

import '../core/hash_seguro.dart';
import '../core/reglas.dart';
import '../data/persistencia.dart';
import '../data/repositorio_docente.dart';

/// Resultado de un intento de acceso al panel docente.
enum ResultadoAcceso { exitoso, contrasenaIncorrecta, bloqueado, vacio }

/// Respuesta del servicio de autenticacion, lista para mostrarse en pantalla.
class RespuestaAcceso {
	const RespuestaAcceso._(
		this.resultado,
		this.mensaje, {
		this.intentosRestantes = 0,
		this.esperar = Duration.zero,
	});

	final ResultadoAcceso resultado;
	final String mensaje;

	/// Intentos que quedan antes del bloqueo (solo si la contrasena fue incorrecta).
	final int intentosRestantes;

	/// Tiempo que falta para poder intentarlo de nuevo (solo si esta bloqueado).
	final Duration esperar;

	bool get exitoso => resultado == ResultadoAcceso.exitoso;

	factory RespuestaAcceso.exitoso([
		String mensaje = '¡Listo! Panel docente abierto.',
	]) =>
		RespuestaAcceso._(ResultadoAcceso.exitoso, mensaje);

	factory RespuestaAcceso.vacio() => const RespuestaAcceso._(
		ResultadoAcceso.vacio,
		'Escribe la contraseña del docente.',
	);

	factory RespuestaAcceso.incorrecta(
		int restantes, {
		String que = 'Contraseña incorrecta',
	}) =>
		RespuestaAcceso._(
			ResultadoAcceso.contrasenaIncorrecta,
			'$que. Te ${restantes == 1 ? 'queda 1 intento' : 'quedan $restantes intentos'}.',
			intentosRestantes: restantes,
		);

	factory RespuestaAcceso.bloqueado(Duration esperar) => RespuestaAcceso._(
		ResultadoAcceso.bloqueado,
		'Demasiados intentos. Espera ${esperar.inSeconds < 1 ? 1 : esperar.inSeconds} s para volver a intentar.',
		esperar: esperar,
	);
}

/// Proveedor de autenticacion local que protege el panel de Configuracion.
///
/// Simula lo que haria un servicio de cuentas real, pero 100% offline sobre la
/// misma base SQLite (tabla `credencial_docente`):
///  - La contrasena inicial la entrega la direccion al docente y solo se guarda
///    su huella SHA-256 iterada con sal ([HashSeguro]).
///  - Tras [Reglas.maxIntentosAccesoDocente] fallos se bloquea un momento; el
///    bloqueo vive en la base, asi que cerrar la app no lo evita.
///  - La sesion se cierra tras [Reglas.duracionSesionDocente] sin actividad, o
///    a mano con [cerrarSesion].
///  - El docente puede cambiar su contrasena, y con el codigo de recuperacion
///    de la direccion se regresa a la inicial si la olvida.
///
/// Si no hay base de datos (navegador o pruebas) funciona igual, solo en memoria.
class ServicioAutenticacion {
	ServicioAutenticacion(
		this._persistencia, {
		DateTime Function()? reloj,
	}) : _reloj = reloj ?? DateTime.now;

	final Persistencia Function() _persistencia;
	final DateTime Function() _reloj;

	CredencialDocente? _credencial;
	DateTime? _sesionHasta;
	DateTime? _accesoAnterior;

	// ---------------------------------------------------------------- Sesion

	/// true si el docente ya entro y la sesion no ha caducado.
	bool get sesionActiva {
		final DateTime? hasta = _sesionHasta;
		return hasta != null && _reloj().isBefore(hasta);
	}

	/// Tiempo que le queda a la sesion (cero si no hay sesion).
	Duration get tiempoRestanteSesion {
		final DateTime? hasta = _sesionHasta;
		if (hasta == null) {
			return Duration.zero;
		}
		final Duration resto = hasta.difference(_reloj());
		return resto.isNegative ? Duration.zero : resto;
	}

	/// true mientras se siga usando la contrasena que entrego la direccion.
	bool get usaContrasenaInicial => _credencial?.esInicial ?? true;

	/// Fecha del acceso anterior al actual (para que el docente note accesos raros).
	DateTime? get accesoAnterior => _accesoAnterior;

	void cerrarSesion() {
		_sesionHasta = null;
	}

	/// Extiende la sesion mientras el docente sigue usando el panel: caduca
	/// tras [Reglas.duracionSesionDocente] SIN actividad, no desde que entro.
	void renovarSesion() {
		if (sesionActiva) {
			_sesionHasta = _reloj().add(Reglas.duracionSesionDocente);
		}
	}

	/// Tiempo de bloqueo pendiente, o [Duration.zero] si se puede intentar ya.
	Future<Duration> bloqueoRestante() async {
		final CredencialDocente c = await _obtener();
		return _restanteBloqueo(c);
	}

	/// Valida la contrasena del docente y, si es correcta, abre la sesion.
	Future<RespuestaAcceso> iniciarSesion(String contrasena) async {
		if (contrasena.trim().isEmpty) {
			return RespuestaAcceso.vacio();
		}
		final CredencialDocente c = await _obtener();
		final Duration espera = _restanteBloqueo(c);
		if (espera > Duration.zero) {
			return RespuestaAcceso.bloqueado(espera);
		}
		if (!_coincide(c, contrasena)) {
			return _registrarFallo(c);
		}
		final DateTime ahora = _reloj();
		_accesoAnterior = c.ultimoAcceso;
		c
			..intentosFallidos = 0
			..bloqueadoHasta = null
			..ultimoAcceso = ahora;
		await _guardar(c);
		_sesionHasta = ahora.add(Reglas.duracionSesionDocente);
		return RespuestaAcceso.exitoso();
	}

	// ------------------------------------------------------------ Contrasena

	/// Revisa que una contrasena nueva cumpla las reglas. Devuelve el problema
	/// en texto, o null si es valida.
	static String? validarNueva(String nueva, String confirmacion) {
		if (nueva.length < Reglas.minCaracteresContrasena) {
			return 'Usa al menos ${Reglas.minCaracteresContrasena} caracteres.';
		}
		if (nueva.length > Reglas.maxCaracteresContrasena) {
			return 'Usa como máximo ${Reglas.maxCaracteresContrasena} caracteres.';
		}
		if (nueva.trim() != nueva) {
			return 'No empieces ni termines la contraseña con espacios.';
		}
		if (nueva == Reglas.contrasenaDocenteInicial) {
			return 'Elige una contraseña distinta a la inicial.';
		}
		if (nueva != confirmacion) {
			return 'Las dos contraseñas nuevas no coinciden.';
		}
		return null;
	}

	/// Cambia la contrasena del docente. Devuelve null si todo salio bien o el
	/// motivo por el que no se pudo cambiar.
	Future<String?> cambiarContrasena({
		required String actual,
		required String nueva,
		required String confirmacion,
	}) async {
		final CredencialDocente c = await _obtener();
		if (!_coincide(c, actual)) {
			return 'La contraseña actual no es correcta.';
		}
		final String? problema = validarNueva(nueva, confirmacion);
		if (problema != null) {
			return problema;
		}
		_asignarContrasena(c, nueva, esInicial: false);
		await _guardar(c);
		return null;
	}

	/// Restablece la contrasena inicial con el codigo que resguarda la direccion.
	/// Los codigos equivocados cuentan como intentos fallidos.
	Future<RespuestaAcceso> restablecerConCodigo(String codigo) async {
		if (codigo.trim().isEmpty) {
			return const RespuestaAcceso._(
				ResultadoAcceso.vacio,
				'Escribe el código de recuperación.',
			);
		}
		final CredencialDocente c = await _obtener();
		final Duration espera = _restanteBloqueo(c);
		if (espera > Duration.zero) {
			return RespuestaAcceso.bloqueado(espera);
		}
		final bool valido = HashSeguro.sonIguales(
			HashSeguro.sha256Hex(codigo.trim().toUpperCase()),
			HashSeguro.sha256Hex(Reglas.codigoRecuperacionDocente),
		);
		if (!valido) {
			return _registrarFallo(c, que: 'Código incorrecto');
		}
		_asignarContrasena(c, Reglas.contrasenaDocenteInicial, esInicial: true);
		c
			..intentosFallidos = 0
			..bloqueadoHasta = null;
		await _guardar(c);
		return RespuestaAcceso.exitoso(
			'Listo: la contraseña volvió a ser la inicial que entregó la dirección.',
		);
	}

	// ------------------------------------------------------------- Internos

	bool _coincide(CredencialDocente c, String contrasena) {
		final String huella = HashSeguro.huellaContrasena(
			contrasena,
			c.sal,
			c.iteraciones,
		);
		return HashSeguro.sonIguales(huella, c.huellaContrasena);
	}

	Duration _restanteBloqueo(CredencialDocente c) {
		final DateTime? hasta = c.bloqueadoHasta;
		if (hasta == null) {
			return Duration.zero;
		}
		final Duration resto = hasta.difference(_reloj());
		return resto.isNegative ? Duration.zero : resto;
	}

	Future<RespuestaAcceso> _registrarFallo(
		CredencialDocente c, {
		String que = 'Contraseña incorrecta',
	}) async {
		c.intentosFallidos++;
		if (c.intentosFallidos >= Reglas.maxIntentosAccesoDocente) {
			c
				..intentosFallidos = 0
				..bloqueadoHasta = _reloj().add(Reglas.bloqueoAccesoDocente);
			await _guardar(c);
			return RespuestaAcceso.bloqueado(Reglas.bloqueoAccesoDocente);
		}
		await _guardar(c);
		return RespuestaAcceso.incorrecta(
			Reglas.maxIntentosAccesoDocente - c.intentosFallidos,
			que: que,
		);
	}

	void _asignarContrasena(
		CredencialDocente c,
		String contrasena, {
		required bool esInicial,
	}) {
		final String sal = HashSeguro.generarSal();
		c
			..sal = sal
			..iteraciones = Reglas.iteracionesHashContrasena
			..huellaContrasena = HashSeguro.huellaContrasena(
				contrasena,
				sal,
				Reglas.iteracionesHashContrasena,
			)
			..esInicial = esInicial;
	}

	CredencialDocente _crearInicial() {
		final CredencialDocente c = CredencialDocente(
			usuario: Reglas.usuarioDocente,
			huellaContrasena: '',
			sal: '',
			iteraciones: Reglas.iteracionesHashContrasena,
			esInicial: true,
		);
		_asignarContrasena(c, Reglas.contrasenaDocenteInicial, esInicial: true);
		return c;
	}

	/// Lee la credencial de SQLite (y la crea la primera vez). Sin base de datos
	/// usa una credencial en memoria con la contrasena inicial.
	Future<CredencialDocente> _obtener() async {
		final Persistencia p = _persistencia();
		if (p.disponible) {
			try {
				CredencialDocente? c = await p.docente.cargar(Reglas.usuarioDocente);
				if (c == null) {
					c = _crearInicial();
					await p.docente.guardar(c);
				}
				return _credencial = c;
			} catch (e) {
				debugPrint('[ServicioAutenticacion] No se pudo leer la credencial: $e');
			}
		}
		return _credencial ??= _crearInicial();
	}

	Future<void> _guardar(CredencialDocente c) async {
		_credencial = c;
		final Persistencia p = _persistencia();
		if (!p.disponible) {
			return;
		}
		try {
			await p.docente.guardar(c);
		} catch (e) {
			debugPrint('[ServicioAutenticacion] No se pudo guardar la credencial: $e');
		}
	}
}
