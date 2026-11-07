import 'package:flutter/material.dart';

import '../controllers/controlador_configuracion.dart';
import '../controllers/controlador_tutor.dart';
import '../core/reglas.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/servicios.dart';
import 'mascota.dart';

/// ActividadConfiguracion (9_UML.pdf y 6_DisenoUI.pdf pagina 6).
/// Incluye el boton de 1 clic para descargar e instalar el modelo GGUF
/// cuantizado + base vectorial SEP + prueba directa del narrador de voz TTS.
class PantallaConfiguracion extends StatefulWidget {
	const PantallaConfiguracion({
		super.key,
		required this.controlador,
	});

	final ControladorTutor controlador;

	@override
	State<PantallaConfiguracion> createState() => _PantallaConfiguracionState();
}

class _PantallaConfiguracionState extends State<PantallaConfiguracion> {
	late final ControladorConfiguracion _controladorConfig;
	late final GestorActualizacionUSB _gestorUSB;

	bool _actualizandoUSB = false;
	String _estadoUSB = 'USB sin comprobar';
	ReporteActualizacion? _ultimoReporte;

	@override
	void initState() {
		super.initState();
		iniciar();
	}

	/// Metodo oficial del UML: +iniciar() : void
	void iniciar() {
		_gestorUSB = widget.controlador.gestorUSB;
		_controladorConfig = ControladorConfiguracion(
			gestorUSB: _gestorUSB,
			configuracionAula: widget.controlador.configuracion,
		);
	}

	/// Metodo oficial del UML: +seleccionarGrado(grado: Integer) : void (RF-08)
	void seleccionarGrado(int grado) {
		_controladorConfig.guardarAjustesAula(
			grado,
			widget.controlador.configuracion.velocidadLecturaVoz,
			widget.controlador.configuracion.tamanoFuente,
		);
		widget.controlador.establecerGradoEscolar(grado);
	}

	/// Metodo oficial del UML: +ajustarVelocidadVoz(velocidad: Float) : void
	void ajustarVelocidadVoz(double velocidad) {
		_controladorConfig.guardarAjustesAula(
			widget.controlador.configuracion.gradoActual,
			velocidad,
			widget.controlador.configuracion.tamanoFuente,
		);
		widget.controlador.actualizarPreferencias(velocidadVoz: velocidad);
	}

	/// Metodo oficial del UML: +ajustarTamanoTexto(tamano: Integer) : void
	void ajustarTamanoTexto(int tamano) {
		_controladorConfig.guardarAjustesAula(
			widget.controlador.configuracion.gradoActual,
			widget.controlador.configuracion.velocidadLecturaVoz,
			tamano,
		);
		widget.controlador.actualizarPreferencias(tamanoTexto: tamano);
	}

	/// Descarga e instala en 1 clic el modelo GGUF (una sola vez) y lo carga en
	/// memoria. El progreso lo publica el propio motor (sobrevive a cambiar de pantalla).
	Future<void> _instalarModeloOfflineClick() async {
		final MotorLLMLocal motor = widget.controlador.pipelineRAG.motorLLM;
		if (motor.descargando || motor.cargando || motor.modeloCargado) {
			return;
		}
		final bool ok = await motor.instalarModeloConUnClick();
		if (!mounted) {
			return;
		}
		if (ok) {
			mostrarNotificacionExito(
				'¡Modelo de IA instalado! Ya puedes preguntar sin conexión.',
			);
			await widget.controlador.reproducirRespuestaVoz(
				'¡Hola! El modelo de inteligencia artificial ya está instalado en este teléfono para funcionar sin internet.',
			);
		} else if (motor.ultimoError.isNotEmpty) {
			_mostrarError(motor.ultimoError);
		}
	}

	/// Carga en memoria un modelo que ya esta descargado.
	Future<void> _cargarModeloClick() async {
		final MotorLLMLocal motor = widget.controlador.pipelineRAG.motorLLM;
		if (motor.descargando || motor.cargando || motor.modeloCargado) {
			return;
		}
		final bool ok = await motor.cargarModeloCuantizado(motor.rutaModelo);
		if (!mounted) {
			return;
		}
		if (ok) {
			mostrarNotificacionExito('¡Modelo de IA cargado y listo!');
		} else if (motor.ultimoError.isNotEmpty) {
			_mostrarError(motor.ultimoError);
		}
	}

	void _mostrarError(String mensaje) {
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(mensaje),
				backgroundColor: Colors.red.shade700,
				behavior: SnackBarBehavior.floating,
				duration: const Duration(seconds: 6),
			),
		);
	}

	Future<void> _confirmarEliminarModelo() async {
		final MotorLLMLocal motor = widget.controlador.pipelineRAG.motorLLM;
		final bool? confirmado = await showDialog<bool>(
			context: context,
			builder: (BuildContext ctx) => AlertDialog(
				title: const Text('¿Borrar el modelo de IA?'),
				content: const Text(
					'Se liberarán ~1.1 GB. La app seguirá respondiendo con el texto '
					'de los libros SEP y podrás volver a descargarlo cuando quieras.',
				),
				actions: <Widget>[
					TextButton(
						onPressed: () => Navigator.of(ctx).pop(false),
						child: const Text('Cancelar'),
					),
					FilledButton(
						onPressed: () => Navigator.of(ctx).pop(true),
						child: const Text('Borrar'),
					),
				],
			),
		);
		if (confirmado == true) {
			await motor.eliminarModelo();
		}
	}

	/// Metodo oficial del UML: +verificarUSBClick() : void (RF-05 y RF-11)
	Future<void> verificarUSBClick() async {
		if (_actualizandoUSB) {
			return;
		}
		setState(() {
			_actualizandoUSB = true;
			_estadoUSB = 'Leyendo memoria USB del Consejo Técnico…';
		});

		final ReporteActualizacion reporte =
			await _controladorConfig.iniciarActualizacionUSB(
				almacen: widget.controlador.pipelineRAG.baseVectores,
			);

		if (!mounted) {
			return;
		}
		setState(() {
			_actualizandoUSB = false;
			_ultimoReporte = reporte;
			_estadoUSB = reporte.exitoso
				? 'Actualizado: ${reporte.versionNueva}'
				: 'Error al verificar USB';
		});

		mostrarNotificacionExito(reporte.mensaje);
	}

	/// Metodo oficial del UML: +mostrarNotificacionExito(mensaje: String) : void (RF-11)
	void mostrarNotificacionExito(String mensaje) {
		if (!mounted) {
			return;
		}
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Row(
					children: <Widget>[
						const Icon(
							Icons.check_circle_rounded,
							color: Colors.white,
						),
						const SizedBox(width: 10),
						Expanded(child: Text(mensaje)),
					],
				),
				backgroundColor: Paleta.verdeBosque,
				behavior: SnackBarBehavior.floating,
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		return ListenableBuilder(
			listenable: widget.controlador,
			builder: (BuildContext context, Widget? _) {
				final ConfiguracionAula cfg = widget.controlador.configuracion;
				final AlmacenVectoresChroma almacen =
					widget.controlador.pipelineRAG.baseVectores;
				final MotorLLMLocal motor =
					widget.controlador.pipelineRAG.motorLLM;

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
												horizontal: 14,
												vertical: 6,
											),
											child: Center(
												child: ConstrainedBox(
													constraints:
														const BoxConstraints(
															maxWidth: 840,
														),
													child: LayoutBuilder(
														builder: (
															BuildContext context,
															BoxConstraints bc,
														) {
															final bool ancho =
																bc.maxWidth > 660;
															if (ancho) {
																return Row(
																	crossAxisAlignment:
																		CrossAxisAlignment
																			.start,
																	children: <Widget>[
																		Expanded(
																			flex: 11,
																			child: _tarjetaBaseConocimiento(
																				cfg,
																				almacen,
																				motor,
																			),
																		),
																		const SizedBox(
																			width: 14,
																		),
																		Expanded(
																			flex: 10,
																			child: Column(
																				children: <Widget>[
																					_tarjetaActualizarUSB(
																						almacen,
																					),
																					const SizedBox(
																						height: 14,
																					),
																					_tarjetaAccesibilidad(
																						cfg,
																					),
																				],
																			),
																		),
																	],
																);
															}
															return Column(
																children: <Widget>[
																	_tarjetaBaseConocimiento(
																		cfg,
																		almacen,
																		motor,
																	),
																	const SizedBox(
																		height: 12,
																	),
																	_tarjetaActualizarUSB(
																		almacen,
																	),
																	const SizedBox(
																		height: 12,
																	),
																	_tarjetaAccesibilidad(
																		cfg,
																	),
																	const SizedBox(
																		height: 8,
																	),
																],
															);
														},
													),
												),
											),
										),
									),
									_barraEstadoInferior(cfg),
								],
							),
						),
					),
				);
			},
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
									'Configuración',
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
									'Modelo IA Offline, libros SEP y voz',
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
					const Mascota(
						estado: EstadoMascota.reposo,
						tamano: 34,
						mostrarEtiqueta: false,
						mostrarOrejas: false,
					),
				],
			),
		);
	}

	/// Tarjeta "Base de conocimiento SEP" + Boton de 1 clic para descargar el
	/// modelo LLM GGUF y dejar el telefono 100% autonomo (6_DisenoUI.pdf pag. 6).
	Widget _tarjetaBaseConocimiento(
		ConfiguracionAula cfg,
		AlmacenVectoresChroma almacen,
		MotorLLMLocal motor,
	) {
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
									Icons.menu_book_rounded,
									size: 18,
									color: Paleta.verdeBosque,
								),
							),
							const SizedBox(width: 10),
							const Expanded(
								child: Text(
									'Base de conocimiento SEP y Motor IA',
									style: TextStyle(
										fontSize: 15.5,
										fontWeight: FontWeight.w800,
										color: Paleta.textoPrimario,
									),
								),
							),
						],
					),
					const SizedBox(height: 6),
					const Text(
						'Libros de Geografía de la SEP para acompañar tus preguntas (RF-02, RF-07). Selecciona el grado:',
						style: TextStyle(
							fontSize: 12.5,
							color: Paleta.textoSecundario,
						),
					),
					const SizedBox(height: 10),
					...Reglas.gradosSoportados.map((int grado) {
						final bool seleccionado = cfg.gradoActual == grado;
						return Padding(
							padding: const EdgeInsets.only(bottom: 8),
							child: InkWell(
								borderRadius: BorderRadius.circular(14),
								onTap: () => seleccionarGrado(grado),
								child: Container(
									padding: const EdgeInsets.symmetric(
										horizontal: 12,
										vertical: 10,
									),
									decoration: BoxDecoration(
										color: seleccionado
											? Paleta.salviaSuave
											: Paleta.cremaTarjeta,
										borderRadius: BorderRadius.circular(14),
										border: Border.all(
											color: seleccionado
												? Paleta.verdeBosque
												: Paleta.bordeSuave,
											width: seleccionado ? 1.5 : 1.0,
										),
									),
									child: Row(
										children: <Widget>[
											Icon(
												seleccionado
													? Icons.check_circle_rounded
													: Icons.book_outlined,
												size: 20,
												color: Paleta.verdeBosque,
											),
											const SizedBox(width: 10),
											Expanded(
												child: Column(
													crossAxisAlignment:
														CrossAxisAlignment.start,
													children: <Widget>[
														Text(
															'Libros SEP Geografía $grado°',
															style: const TextStyle(
																fontWeight:
																	FontWeight.w700,
																fontSize: 14,
																color: Paleta
																	.textoPrimario,
															),
														),
														Text(
															seleccionado
																? 'Activo · Explicación adaptada a $grado°'
																: 'Disponible sin conexión · Toca para usar',
															style: const TextStyle(
																fontSize: 11.5,
																color: Paleta
																	.textoSecundario,
															),
														),
													],
												),
											),
										],
									),
								),
							),
						);
					}),
					const SizedBox(height: 4),
					..._bloqueModeloIA(motor, almacen),
				],
			),
		);
	}

	/// Boton de 1 clic, progreso, errores y estado real del modelo de IA local.
	List<Widget> _bloqueModeloIA(
		MotorLLMLocal motor,
		AlmacenVectoresChroma almacen,
	) {
		final EstadoModelo estado = motor.estado;
		final bool soportado = MotorLLMLocal.plataformaSoportada;
		final bool listo = estado == EstadoModelo.listo;
		final bool descargando = estado == EstadoModelo.descargando;
		final bool cargando = estado == EstadoModelo.cargando;
		final int porcentaje = (motor.progresoDescarga * 100).round();

		String etiqueta;
		IconData icono;
		VoidCallback? accion;
		if (!soportado) {
			etiqueta = 'El modelo de IA solo funciona en la app del teléfono';
			icono = Icons.phone_android_rounded;
			accion = null;
		} else if (listo) {
			etiqueta = 'Modelo de IA listo (funciona sin internet) ✅';
			icono = Icons.offline_pin_rounded;
			accion = null;
		} else if (cargando) {
			etiqueta = 'Cargando el modelo en memoria…';
			icono = Icons.hourglass_top_rounded;
			accion = null;
		} else if (descargando) {
			etiqueta = 'Descargando modelo de IA… $porcentaje%';
			icono = Icons.downloading_rounded;
			accion = null;
		} else if (estado == EstadoModelo.instalado) {
			etiqueta = 'Modelo descargado · Toca para cargarlo';
			icono = Icons.play_circle_outline_rounded;
			accion = _cargarModeloClick;
		} else if (estado == EstadoModelo.error) {
			etiqueta = 'Reintentar descarga del modelo de IA';
			icono = Icons.refresh_rounded;
			accion = _instalarModeloOfflineClick;
		} else {
			etiqueta = 'Descargar modelo de IA (≈1.1 GB)';
			icono = Icons.download_for_offline_rounded;
			accion = _instalarModeloOfflineClick;
		}

		final bool mostrarProgreso =
			descargando || (!listo && motor.etapaDescarga.isNotEmpty);
		final double totalMB =
			motor.tamanoModeloMB + almacen.obtenerAlmacenamientoUsadoMB();

		return <Widget>[
			if (soportado && !listo && !motor.paqueteOfflineInstalado)
				const Padding(
					padding: EdgeInsets.only(bottom: 8),
					child: Text(
						'Necesitas internet solo para esta descarga (≈1.1 GB: usa Wi-Fi). '
						'Después el tutor funciona sin conexión.',
						style: TextStyle(
							fontSize: 11.5,
							color: Paleta.textoSecundario,
						),
					),
				),
			SizedBox(
				width: double.infinity,
				child: FilledButton.icon(
					style: FilledButton.styleFrom(
						backgroundColor:
							listo ? Paleta.verdePino : Paleta.verdeBoton,
						disabledBackgroundColor:
							listo ? Paleta.verdePino : Paleta.salviaSuave,
						foregroundColor: Colors.white,
						disabledForegroundColor:
							listo ? Colors.white : Paleta.verdeBosque,
						padding: const EdgeInsets.symmetric(
							vertical: 11,
							horizontal: 12,
						),
						shape: RoundedRectangleBorder(
							borderRadius: BorderRadius.circular(14),
						),
					),
					onPressed: accion,
					icon: Icon(icono, size: 19),
					label: Text(
						etiqueta,
						textAlign: TextAlign.center,
						style: const TextStyle(
							fontSize: 13,
							fontWeight: FontWeight.w700,
						),
					),
				),
			),
			if (mostrarProgreso) ...<Widget>[
				const SizedBox(height: 8),
				ClipRRect(
					borderRadius: BorderRadius.circular(8),
					child: LinearProgressIndicator(
						value: cargando ? null : motor.progresoDescarga,
						minHeight: 7,
						backgroundColor: Paleta.salviaSuave,
						valueColor: const AlwaysStoppedAnimation<Color>(
							Paleta.verdeBosque,
						),
					),
				),
				const SizedBox(height: 4),
				Text(
					motor.etapaDescarga,
					style: const TextStyle(
						fontSize: 11.5,
						fontWeight: FontWeight.w600,
						color: Paleta.verdeBosque,
					),
				),
			],
			if (descargando)
				Align(
					alignment: Alignment.centerRight,
					child: TextButton.icon(
						onPressed: motor.cancelarDescarga,
						icon: const Icon(Icons.close_rounded, size: 16),
						label: const Text('Cancelar descarga'),
					),
				),
			if (motor.ultimoError.isNotEmpty) ...<Widget>[
				const SizedBox(height: 6),
				Text(
					motor.ultimoError,
					style: TextStyle(
						fontSize: 11.5,
						fontWeight: FontWeight.w600,
						color: Colors.red.shade700,
					),
				),
			],
			const SizedBox(height: 8),
			Container(
				width: double.infinity,
				padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
				decoration: BoxDecoration(
					color: Paleta.cremaTarjeta,
					borderRadius: BorderRadius.circular(12),
					border: Border.all(color: Paleta.bordeSuave),
				),
				child: Row(
					children: <Widget>[
						const Icon(
							Icons.memory_rounded,
							color: Paleta.verdeBosque,
							size: 17,
						),
						const SizedBox(width: 8),
						Expanded(
							child: Text(
								'${motor.nombreModeloActivo} · ${almacen.totalFragmentos} bloques SEP · ${totalMB.toStringAsFixed(0)} MB / 4096 MB (RNF-09)',
								style: const TextStyle(
									color: Paleta.textoSecundario,
									fontSize: 11,
									fontWeight: FontWeight.w600,
								),
							),
						),
					],
				),
			),
			if (motor.paqueteOfflineInstalado && !descargando && !cargando)
				Align(
					alignment: Alignment.centerRight,
					child: TextButton.icon(
						onPressed: _confirmarEliminarModelo,
						icon: const Icon(Icons.delete_outline_rounded, size: 16),
						label: const Text('Borrar modelo (liberar 1.1 GB)'),
					),
				),
		];
	}

	/// Tarjeta "Actualizar sistema (USB)" (RF-05 y RF-11).
	Widget _tarjetaActualizarUSB(AlmacenVectoresChroma almacen) {
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
									Icons.usb_rounded,
									size: 18,
									color: Paleta.verdeBosque,
								),
							),
							const SizedBox(width: 10),
							const Expanded(
								child: Text(
									'Actualizar sistema (USB)',
									style: TextStyle(
										fontSize: 15.5,
										fontWeight: FontWeight.w800,
										color: Paleta.textoPrimario,
									),
								),
							),
						],
					),
					const SizedBox(height: 6),
					const Text(
						'Conecta la memoria USB del Consejo Técnico Escolar para actualizar sin internet (RF-05):',
						style: TextStyle(
							fontSize: 12.5,
							color: Paleta.textoSecundario,
						),
					),
					const SizedBox(height: 10),
					Container(
						width: double.infinity,
						padding: const EdgeInsets.symmetric(
							horizontal: 12,
							vertical: 9,
						),
						decoration: BoxDecoration(
							color: Paleta.cremaTarjeta,
							borderRadius: BorderRadius.circular(12),
							border: Border.all(color: Paleta.bordeSuave),
						),
						child: Row(
							children: <Widget>[
								Icon(
									_ultimoReporte?.exitoso == true
										? Icons.check_circle_rounded
										: Icons.info_outline_rounded,
									size: 16,
									color: Paleta.verdeBosque,
								),
								const SizedBox(width: 8),
								Expanded(
									child: Text(
										'$_estadoUSB · ${almacen.versionActual}',
										style: const TextStyle(
											fontSize: 12,
											fontWeight: FontWeight.w600,
											color: Paleta.textoPrimario,
										),
									),
								),
							],
						),
					),
					const SizedBox(height: 10),
					SizedBox(
						width: double.infinity,
						child: FilledButton.icon(
							style: FilledButton.styleFrom(
								backgroundColor: Paleta.verdeBoton,
								foregroundColor: Colors.white,
								padding: const EdgeInsets.symmetric(
									vertical: 11,
								),
								shape: RoundedRectangleBorder(
									borderRadius: BorderRadius.circular(14),
								),
							),
							onPressed: _actualizandoUSB ? null : verificarUSBClick,
							icon: _actualizandoUSB
								? const SizedBox(
									width: 16,
									height: 16,
									child: CircularProgressIndicator(
										strokeWidth: 2,
										color: Colors.white,
									),
								)
								: const Icon(Icons.sync_rounded, size: 18),
							label: Text(
								_actualizandoUSB
									? 'Actualizando base SEP…'
									: 'Verificar actualizaciones en USB',
								style: const TextStyle(
									fontSize: 13.5,
									fontWeight: FontWeight.w700,
								),
							),
						),
					),
					if (_ultimoReporte != null && _ultimoReporte!.exitoso) ...<Widget>[
						const SizedBox(height: 6),
						Text(
							'✅ Confirmado (RF-11): ${_ultimoReporte!.fragmentosCargados} temas listos en ${_ultimoReporte!.duracionSegundos.toStringAsFixed(1)} s.',
							style: const TextStyle(
								fontSize: 12,
								fontWeight: FontWeight.w700,
								color: Paleta.verdeBosque,
							),
						),
					],
				],
			),
		);
	}

	/// Tarjeta "Accesibilidad y voz" con boton para probar la narracion TTS en vivo.
	Widget _tarjetaAccesibilidad(ConfiguracionAula cfg) {
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
									Icons.accessibility_new_rounded,
									size: 18,
									color: Paleta.verdeBosque,
								),
							),
							const SizedBox(width: 10),
							const Expanded(
								child: Text(
									'Accesibilidad y narrador de voz',
									style: TextStyle(
										fontSize: 15.5,
										fontWeight: FontWeight.w800,
										color: Paleta.textoPrimario,
									),
								),
							),
						],
					),
					const SizedBox(height: 6),
					const Text(
						'Ajusta el tamaño de letra, contraste y velocidad de lectura en español (RNF-08):',
						style: TextStyle(
							fontSize: 12.5,
							color: Paleta.textoSecundario,
						),
					),
					const SizedBox(height: 10),
					Text(
						'Tamaño del texto: ${cfg.tamanoFuente} pt',
						style: const TextStyle(
							fontSize: 13,
							color: Paleta.textoPrimario,
							fontWeight: FontWeight.w700,
						),
					),
					Slider(
						value: cfg.tamanoFuente.toDouble(),
						min: Reglas.tamanoTextoMin.toDouble(),
						max: Reglas.tamanoTextoMax.toDouble(),
						divisions: Reglas.tamanoTextoMax - Reglas.tamanoTextoMin,
						activeColor: Paleta.verdeBosque,
						onChanged: (double v) => ajustarTamanoTexto(v.round()),
					),
					Text(
						'Velocidad de voz: ${cfg.velocidadLecturaVoz.toStringAsFixed(1)}x',
						style: const TextStyle(
							fontSize: 13,
							color: Paleta.textoPrimario,
							fontWeight: FontWeight.w700,
						),
					),
					Slider(
						value: cfg.velocidadLecturaVoz,
						min: Reglas.velocidadVozMin,
						max: Reglas.velocidadVozMax,
						divisions: 8,
						activeColor: Paleta.verdeBosque,
						onChanged: ajustarVelocidadVoz,
					),
					SwitchListTile(
						contentPadding: EdgeInsets.zero,
						dense: true,
						activeColor: Paleta.verdeBosque,
						title: const Text(
							'Narrar respuestas en voz alta automáticamente',
							style: TextStyle(
								color: Paleta.textoPrimario,
								fontSize: 13,
								fontWeight: FontWeight.w600,
							),
						),
						value: cfg.vozAutomatica,
						onChanged: (bool val) => widget.controlador
							.actualizarPreferencias(vozAutomatica: val),
					),
					SwitchListTile(
						contentPadding: EdgeInsets.zero,
						dense: true,
						activeColor: Paleta.verdeBosque,
						title: const Text(
							'Modo de alto contraste visual',
							style: TextStyle(
								color: Paleta.textoPrimario,
								fontSize: 13,
								fontWeight: FontWeight.w600,
							),
						),
						value: cfg.altoContraste,
						onChanged: (bool val) => widget.controlador
							.actualizarPreferencias(altoContraste: val),
					),
					const SizedBox(height: 6),
					SizedBox(
						width: double.infinity,
						child: OutlinedButton.icon(
							style: OutlinedButton.styleFrom(
								foregroundColor: Paleta.verdeBosque,
								side: const BorderSide(
									color: Paleta.bordeSuave,
								),
								padding: const EdgeInsets.symmetric(
									vertical: 10,
								),
								shape: RoundedRectangleBorder(
									borderRadius: BorderRadius.circular(14),
								),
							),
							onPressed: () => widget.controlador
								.reproducirRespuestaVoz(
									'Hola, soy Geograf-IA, tu tutor de geografía para ${cfg.gradoActual}° grado de primaria.',
								),
							icon: const Icon(
								Icons.volume_up_rounded,
								size: 18,
							),
							label: const Text(
								'Probar narración de voz ahora',
								style: TextStyle(
									fontSize: 13,
									fontWeight: FontWeight.w700,
								),
							),
						),
					),
				],
			),
		);
	}

	Widget _barraEstadoInferior(ConfiguracionAula cfg) {
		final String textoTam =
			cfg.tamanoFuente > 17 ? 'Texto grande' : 'Texto normal';
		final String contraste =
			cfg.altoContraste ? 'Alto contraste' : 'Contraste estándar';
		final String voz = cfg.vozAutomatica ? 'Voz activa' : 'Voz manual';

		return Padding(
			padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
			child: Container(
				padding: const EdgeInsets.symmetric(
					horizontal: 12,
					vertical: 6,
				),
				decoration: BoxDecoration(
					color: Colors.white,
					borderRadius: BorderRadius.circular(16),
					border: Border.all(color: Paleta.bordeSuave),
				),
				child: Text(
					'🔊 $textoTam · $contraste · $voz · ${cfg.velocidadLecturaVoz.toStringAsFixed(1)}x',
					maxLines: 1,
					overflow: TextOverflow.ellipsis,
					style: const TextStyle(
						color: Paleta.textoSecundario,
						fontSize: 11.5,
						fontWeight: FontWeight.w600,
					),
				),
			),
		);
	}
}
