import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/controlador_tutor.dart';
import '../core/reglas.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/servicio_autenticacion.dart';
import 'mascota.dart';
import 'pantalla_configuracion.dart';

/// Abre el panel de Configuracion. Si el docente no tiene una sesion activa,
/// primero muestra la pantalla de acceso con contrasena.
Future<void> abrirPanelDocente(BuildContext context, ControladorTutor c) async {
	final NavigatorState navegador = Navigator.of(context);
	final ServicioAutenticacion auth = c.autenticacion;
	final bool conSesion = auth.sesionActiva;
	if (conSesion) {
		auth.renovarSesion();
	}
	await navegador.push(
		MaterialPageRoute<void>(
			builder: (_) => conSesion
				? PantallaConfiguracion(controlador: c)
				: PantallaAccesoDocente(controlador: c),
		),
	);
}

/// Campo de contrasena con el estilo de la app (tarjeta crema y borde suave).
class CampoContrasena extends StatefulWidget {
	const CampoContrasena({
		super.key,
		required this.controlador,
		required this.etiqueta,
		this.autofocus = false,
		this.habilitado = true,
		this.onSubmitted,
		this.icono = Icons.key_rounded,
	});

	final TextEditingController controlador;
	final String etiqueta;
	final bool autofocus;
	final bool habilitado;
	final ValueChanged<String>? onSubmitted;
	final IconData icono;

	@override
	State<CampoContrasena> createState() => _CampoContrasenaState();
}

class _CampoContrasenaState extends State<CampoContrasena> {
	bool _visible = false;

	@override
	Widget build(BuildContext context) {
		OutlineInputBorder borde(Color color, double ancho) => OutlineInputBorder(
			borderRadius: BorderRadius.circular(14),
			borderSide: BorderSide(color: color, width: ancho),
		);
		return TextField(
			controller: widget.controlador,
			autofocus: widget.autofocus,
			enabled: widget.habilitado,
			obscureText: !_visible,
			autocorrect: false,
			enableSuggestions: false,
			maxLength: Reglas.maxCaracteresContrasena,
			textInputAction: TextInputAction.done,
			onSubmitted: widget.onSubmitted,
			style: const TextStyle(
				fontSize: 15,
				fontWeight: FontWeight.w600,
				color: Paleta.textoPrimario,
			),
			decoration: InputDecoration(
				isDense: true,
				counterText: '',
				filled: true,
				fillColor: Paleta.cremaTarjeta,
				labelText: widget.etiqueta,
				labelStyle: const TextStyle(
					fontSize: 13,
					color: Paleta.textoSecundario,
				),
				floatingLabelStyle: const TextStyle(
					fontSize: 13,
					fontWeight: FontWeight.w700,
					color: Paleta.verdeBosque,
				),
				prefixIcon: Icon(widget.icono, size: 19, color: Paleta.verdeBosque),
				suffixIcon: IconButton(
					tooltip: _visible ? 'Ocultar' : 'Mostrar',
					visualDensity: VisualDensity.compact,
					icon: Icon(
						_visible
							? Icons.visibility_off_rounded
							: Icons.visibility_rounded,
						size: 19,
						color: Paleta.textoSecundario,
					),
					onPressed: () => setState(() => _visible = !_visible),
				),
				contentPadding: const EdgeInsets.symmetric(
					horizontal: 12,
					vertical: 13,
				),
				border: borde(Paleta.bordeSuave, 1),
				enabledBorder: borde(Paleta.bordeSuave, 1),
				disabledBorder: borde(Paleta.bordeSuave, 1),
				focusedBorder: borde(Paleta.verdeBosque, 1.5),
			),
		);
	}
}

/// Pantalla "Acceso docente": pide la contrasena que la direccion entrego al
/// maestro antes de abrir el panel de Configuracion (sin internet, sobre SQLite).
class PantallaAccesoDocente extends StatefulWidget {
	const PantallaAccesoDocente({super.key, required this.controlador});

	final ControladorTutor controlador;

	@override
	State<PantallaAccesoDocente> createState() => _PantallaAccesoDocenteState();
}

class _PantallaAccesoDocenteState extends State<PantallaAccesoDocente>
	with SingleTickerProviderStateMixin {
	final TextEditingController _campo = TextEditingController();

	/// Sacudida de la tarjeta cuando la contrasena es incorrecta.
	late final AnimationController _sacudida = AnimationController(
		vsync: this,
		duration: const Duration(milliseconds: 420),
	);

	bool _verificando = false;
	String _error = '';
	Duration _espera = Duration.zero;
	Timer? _cuentaRegresiva;

	ServicioAutenticacion get _auth => widget.controlador.autenticacion;

	bool get _bloqueado => _espera > Duration.zero;

	@override
	void initState() {
		super.initState();
		_revisarBloqueoGuardado();
	}

	@override
	void dispose() {
		_cuentaRegresiva?.cancel();
		_sacudida.dispose();
		_campo.dispose();
		super.dispose();
	}

	/// Si la app se cerro durante un bloqueo, este sigue vigente al volver.
	Future<void> _revisarBloqueoGuardado() async {
		final Duration espera = await _auth.bloqueoRestante();
		if (mounted && espera > Duration.zero) {
			_iniciarCuentaRegresiva(espera);
		}
	}

	void _iniciarCuentaRegresiva(Duration espera) {
		_cuentaRegresiva?.cancel();
		setState(() => _espera = espera);
		_cuentaRegresiva = Timer.periodic(const Duration(seconds: 1), (Timer t) {
			if (!mounted) {
				t.cancel();
				return;
			}
			final Duration resto = _espera - const Duration(seconds: 1);
			setState(() {
				_espera = resto.isNegative ? Duration.zero : resto;
				if (_espera == Duration.zero) {
					_error = '';
				}
			});
			if (_espera == Duration.zero) {
				t.cancel();
			}
		});
	}

	Future<void> _entrar() async {
		if (_verificando || _bloqueado) {
			return;
		}
		setState(() {
			_verificando = true;
			_error = '';
		});
		// Deja que se pinte el indicador antes de calcular la huella.
		await Future<void>.delayed(const Duration(milliseconds: 60));
		final RespuestaAcceso r = await _auth.iniciarSesion(_campo.text);
		if (!mounted) {
			return;
		}
		if (r.exitoso) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Row(
						children: <Widget>[
							const Icon(Icons.lock_open_rounded, color: Colors.white),
							const SizedBox(width: 10),
							Expanded(child: Text(r.mensaje)),
						],
					),
					backgroundColor: Paleta.verdeBosque,
					behavior: SnackBarBehavior.floating,
				),
			);
			Navigator.of(context).pushReplacement(
				MaterialPageRoute<void>(
					builder: (_) => PantallaConfiguracion(
						controlador: widget.controlador,
					),
				),
			);
			return;
		}
		_campo.clear();
		setState(() {
			_verificando = false;
			_error = r.mensaje;
		});
		if (r.resultado != ResultadoAcceso.vacio) {
			_sacudida.forward(from: 0);
		}
		if (r.resultado == ResultadoAcceso.bloqueado) {
			_iniciarCuentaRegresiva(r.esperar);
		}
	}

	Future<void> _recuperarAcceso() async {
		final String? mensaje = await showDialog<String>(
			context: context,
			builder: (_) => _DialogoRecuperacion(auth: _auth),
		);
		if (!mounted || mensaje == null) {
			return;
		}
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(mensaje),
				backgroundColor: Paleta.verdeBosque,
				behavior: SnackBarBehavior.floating,
			),
		);
		// Un restablecimiento correcto tambien quita el bloqueo.
		_cuentaRegresiva?.cancel();
		setState(() {
			_espera = Duration.zero;
			_error = '';
		});
	}

	@override
	Widget build(BuildContext context) {
		final EstadoMascota estado =
			_verificando ? EstadoMascota.pensando : EstadoMascota.reposo;
		return Scaffold(
			body: Container(
				decoration: const BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: <Color>[
							Paleta.cremaFondo,
							Paleta.cremaTarjeta,
							Paleta.salviaSuave,
						],
					),
				),
				child: SafeArea(
					child: Column(
						children: <Widget>[
							_construirEncabezado(context),
							Expanded(
								child: SingleChildScrollView(
									padding: const EdgeInsets.symmetric(
										horizontal: 16,
										vertical: 8,
									),
									child: Center(
										child: ConstrainedBox(
											constraints: const BoxConstraints(maxWidth: 420),
											child: Column(
												children: <Widget>[
													const SizedBox(height: 8),
													Mascota(
														estado: estado,
														tamano: 92,
														mostrarEtiqueta: false,
													),
													const SizedBox(height: 14),
													const Text(
														'Solo para el maestro',
														textAlign: TextAlign.center,
														style: TextStyle(
															fontSize: 21,
															fontWeight: FontWeight.w800,
															color: Paleta.textoPrimario,
															letterSpacing: -0.4,
														),
													),
													const SizedBox(height: 4),
													const Text(
														'Escribe la contraseña que te entregó la dirección '
														'para cambiar el grado, la voz o actualizar por USB.',
														textAlign: TextAlign.center,
														style: TextStyle(
															fontSize: 12.5,
															height: 1.35,
															color: Paleta.textoSecundario,
														),
													),
													const SizedBox(height: 16),
													AnimatedBuilder(
														animation: _sacudida,
														builder: (BuildContext context, Widget? hijo) {
															final double t = _sacudida.value;
															final double dx =
																math.sin(t * math.pi * 6) * 9 * (1 - t);
															return Transform.translate(
																offset: Offset(dx, 0),
																child: hijo,
															);
														},
														child: _tarjetaAcceso(),
													),
													const SizedBox(height: 12),
													_avisoPrivacidad(),
													const SizedBox(height: 12),
												],
											),
										),
									),
								),
							),
						],
					),
				),
			),
		);
	}

	Widget _construirEncabezado(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
			child: Row(
				children: <Widget>[
					OutlinedButton.icon(
						style: OutlinedButton.styleFrom(
							backgroundColor: Colors.white,
							foregroundColor: Paleta.textoPrimario,
							side: const BorderSide(color: Paleta.bordeSuave),
							padding: const EdgeInsets.symmetric(
								horizontal: 10,
								vertical: 6,
							),
							minimumSize: Size.zero,
							tapTargetSize: MaterialTapTargetSize.shrinkWrap,
							shape: RoundedRectangleBorder(
								borderRadius: BorderRadius.circular(18),
							),
						),
						onPressed: () => Navigator.of(context).pop(),
						icon: const Icon(Icons.arrow_back_rounded, size: 17),
						label: const Text(
							'Inicio',
							style: TextStyle(
								fontSize: 13,
								fontWeight: FontWeight.w700,
							),
						),
					),
					const SizedBox(width: 10),
					const Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							mainAxisSize: MainAxisSize.min,
							children: <Widget>[
								Text(
									'Acceso docente',
									maxLines: 1,
									overflow: TextOverflow.ellipsis,
									style: TextStyle(
										fontSize: 18,
										fontWeight: FontWeight.w800,
										color: Paleta.textoPrimario,
										letterSpacing: -0.3,
									),
								),
								Text(
									'Configuración protegida con contraseña',
									maxLines: 1,
									overflow: TextOverflow.ellipsis,
									style: TextStyle(
										fontSize: 11.5,
										color: Paleta.textoSecundario,
									),
								),
							],
						),
					),
					Container(
						width: 34,
						height: 34,
						decoration: BoxDecoration(
							color: Paleta.esferaCeleste,
							borderRadius: BorderRadius.circular(17),
						),
						child: const Icon(
							Icons.lock_rounded,
							size: 18,
							color: Paleta.verdeBosque,
						),
					),
				],
			),
		);
	}

	Widget _tarjetaAcceso() {
		final bool habilitado = !_verificando && !_bloqueado;
		return Container(
			padding: const EdgeInsets.all(14),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(20),
				border: Border.all(color: Paleta.bordeSuave),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: <Widget>[
					Row(
						children: <Widget>[
							Container(
								width: 32,
								height: 32,
								decoration: BoxDecoration(
									color: Paleta.esferaCeleste,
									borderRadius: BorderRadius.circular(9),
								),
								child: const Icon(
									Icons.admin_panel_settings_rounded,
									size: 18,
									color: Paleta.verdeBosque,
								),
							),
							const SizedBox(width: 10),
							const Expanded(
								child: Text(
									'Contraseña del docente',
									style: TextStyle(
										fontSize: 15.5,
										fontWeight: FontWeight.w800,
										color: Paleta.textoPrimario,
									),
								),
							),
						],
					),
					const SizedBox(height: 12),
					CampoContrasena(
						controlador: _campo,
						etiqueta: 'Contraseña',
						autofocus: true,
						habilitado: habilitado,
						onSubmitted: (_) => _entrar(),
					),
					if (_bloqueado) ...<Widget>[
						const SizedBox(height: 10),
						_avisoBloqueo(),
					] else if (_error.isNotEmpty) ...<Widget>[
						const SizedBox(height: 8),
						Row(
							children: <Widget>[
								Icon(
									Icons.error_outline_rounded,
									size: 16,
									color: Colors.red.shade700,
								),
								const SizedBox(width: 6),
								Expanded(
									child: Text(
										_error,
										style: TextStyle(
											fontSize: 12,
											fontWeight: FontWeight.w600,
											color: Colors.red.shade700,
										),
									),
								),
							],
						),
					],
					const SizedBox(height: 12),
					SizedBox(
						width: double.infinity,
						child: FilledButton.icon(
							style: FilledButton.styleFrom(
								backgroundColor: Paleta.verdeBoton,
								foregroundColor: Colors.white,
								disabledBackgroundColor: Paleta.salviaSuave,
								disabledForegroundColor: Paleta.verdeBosque,
								padding: const EdgeInsets.symmetric(vertical: 12),
								shape: RoundedRectangleBorder(
									borderRadius: BorderRadius.circular(14),
								),
							),
							onPressed: habilitado ? _entrar : null,
							icon: _verificando
								? const SizedBox(
									width: 16,
									height: 16,
									child: CircularProgressIndicator(
										strokeWidth: 2,
										color: Paleta.verdeBosque,
									),
								)
								: const Icon(Icons.lock_open_rounded, size: 18),
							label: Text(
								_verificando ? 'Verificando…' : 'Entrar al panel',
								style: const TextStyle(
									fontSize: 13.5,
									fontWeight: FontWeight.w700,
								),
							),
						),
					),
					const SizedBox(height: 4),
					Align(
						alignment: Alignment.center,
						child: TextButton.icon(
							style: TextButton.styleFrom(
								foregroundColor: Paleta.verdeBosque,
							),
							onPressed: _verificando ? null : _recuperarAcceso,
							icon: const Icon(Icons.help_outline_rounded, size: 16),
							label: const Text(
								'¿Olvidaste la contraseña?',
								style: TextStyle(
									fontSize: 12.5,
									fontWeight: FontWeight.w700,
								),
							),
						),
					),
				],
			),
		);
	}

	Widget _avisoBloqueo() {
		final int segundos = _espera.inSeconds < 1 ? 1 : _espera.inSeconds;
		final double fraccion = (_espera.inMilliseconds /
				Reglas.bloqueoAccesoDocente.inMilliseconds)
			.clamp(0.0, 1.0)
			.toDouble();
		return Container(
			width: double.infinity,
			padding: const EdgeInsets.all(10),
			decoration: BoxDecoration(
				color: Paleta.alertaMaestro,
				borderRadius: BorderRadius.circular(12),
				border: Border.all(color: Paleta.bordeAlerta),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: <Widget>[
					Row(
						children: <Widget>[
							const Icon(
								Icons.hourglass_top_rounded,
								size: 16,
								color: Paleta.bordeAlerta,
							),
							const SizedBox(width: 6),
							Expanded(
								child: Text(
									'Demasiados intentos. Espera $segundos s.',
									style: const TextStyle(
										fontSize: 12,
										fontWeight: FontWeight.w700,
										color: Paleta.textoPrimario,
									),
								),
							),
						],
					),
					const SizedBox(height: 8),
					ClipRRect(
						borderRadius: BorderRadius.circular(8),
						child: LinearProgressIndicator(
							value: fraccion,
							minHeight: 6,
							backgroundColor: Colors.white,
							valueColor: const AlwaysStoppedAnimation<Color>(
								Paleta.bordeAlerta,
							),
						),
					),
				],
			),
		);
	}

	Widget _avisoPrivacidad() {
		return Container(
			width: double.infinity,
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(16),
				border: Border.all(color: Paleta.bordeSuave),
			),
			child: const Row(
				children: <Widget>[
					Icon(
						Icons.shield_outlined,
						size: 17,
						color: Paleta.verdeBosque,
					),
					SizedBox(width: 8),
					Expanded(
						child: Text(
							'Funciona sin internet. La contraseña nunca se guarda tal cual: '
							'en este teléfono solo vive su huella protegida (SHA-256).',
							style: TextStyle(
								fontSize: 11.5,
								fontWeight: FontWeight.w600,
								color: Paleta.textoSecundario,
							),
						),
					),
				],
			),
		);
	}
}

/// Dialogo para volver a la contrasena inicial con el codigo de la direccion.
/// Devuelve el mensaje de exito, o null si se cancelo.
class _DialogoRecuperacion extends StatefulWidget {
	const _DialogoRecuperacion({required this.auth});

	final ServicioAutenticacion auth;

	@override
	State<_DialogoRecuperacion> createState() => _DialogoRecuperacionState();
}

class _DialogoRecuperacionState extends State<_DialogoRecuperacion> {
	final TextEditingController _codigo = TextEditingController();
	bool _enviando = false;
	String _error = '';

	@override
	void dispose() {
		_codigo.dispose();
		super.dispose();
	}

	Future<void> _restablecer() async {
		if (_enviando) {
			return;
		}
		setState(() {
			_enviando = true;
			_error = '';
		});
		await Future<void>.delayed(const Duration(milliseconds: 60));
		final RespuestaAcceso r =
			await widget.auth.restablecerConCodigo(_codigo.text);
		if (!mounted) {
			return;
		}
		if (r.exitoso) {
			Navigator.of(context).pop(r.mensaje);
			return;
		}
		setState(() {
			_enviando = false;
			_error = r.mensaje;
		});
	}

	@override
	Widget build(BuildContext context) {
		return AlertDialog(
			backgroundColor: Colors.white,
			surfaceTintColor: Colors.transparent,
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
			title: const Row(
				children: <Widget>[
					Icon(Icons.vpn_key_rounded, color: Paleta.verdeBosque, size: 20),
					SizedBox(width: 8),
					Expanded(
						child: Text(
							'Recuperar acceso',
							style: TextStyle(
								fontSize: 17,
								fontWeight: FontWeight.w800,
								color: Paleta.textoPrimario,
							),
						),
					),
				],
			),
			content: Column(
				mainAxisSize: MainAxisSize.min,
				crossAxisAlignment: CrossAxisAlignment.start,
				children: <Widget>[
					const Text(
						'Pide a la dirección el código de recuperación del Consejo '
						'Técnico. Con él, la contraseña vuelve a ser la inicial.',
						style: TextStyle(
							fontSize: 12.5,
							height: 1.35,
							color: Paleta.textoSecundario,
						),
					),
					const SizedBox(height: 12),
					CampoContrasena(
						controlador: _codigo,
						etiqueta: 'Código de recuperación',
						icono: Icons.vpn_key_outlined,
						autofocus: true,
						habilitado: !_enviando,
						onSubmitted: (_) => _restablecer(),
					),
					if (_error.isNotEmpty) ...<Widget>[
						const SizedBox(height: 8),
						Text(
							_error,
							style: TextStyle(
								fontSize: 12,
								fontWeight: FontWeight.w600,
								color: Colors.red.shade700,
							),
						),
					],
				],
			),
			actions: <Widget>[
				TextButton(
					onPressed: _enviando ? null : () => Navigator.of(context).pop(),
					child: const Text('Cancelar'),
				),
				FilledButton(
					style: FilledButton.styleFrom(
						backgroundColor: Paleta.verdeBoton,
						foregroundColor: Colors.white,
					),
					onPressed: _enviando ? null : _restablecer,
					child: const Text('Restablecer'),
				),
			],
		);
	}
}
