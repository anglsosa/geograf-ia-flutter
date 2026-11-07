import 'package:flutter/material.dart';

import '../controllers/controlador_configuracion.dart';
import '../controllers/controlador_tutor.dart';
import '../core/reglas.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/servicios.dart';
import 'mascota.dart';

/// ActividadConfiguracion (9_UML.pdf y 6_DisenoUI.pdf pagina 6).
/// Permite seleccionar el grado escolar (4°, 5°, 6°), actualizar la base
/// vectorial mediante memoria USB OTG (RF-05, RF-11) y ajustar accesibilidad.
/// Cumple con RNF-02: NO permite que el alumno modifique libremente el contenido SEP.
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
							color: Paleta.verdeLima,
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

				return Scaffold(
					body: Container(
						decoration: const BoxDecoration(
							gradient: LinearGradient(
								begin: Alignment.topCenter,
								end: Alignment.bottomCenter,
								colors: <Color>[
									Color(0xFFF3EAD8),
									Paleta.cremaFondo,
									Color(0xFFDCE8DF),
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
												horizontal: 20,
												vertical: 8,
											),
											child: Center(
												child: ConstrainedBox(
													constraints:
														const BoxConstraints(
															maxWidth: 880,
														),
													child: LayoutBuilder(
														builder: (
															BuildContext context,
															BoxConstraints bc,
														) {
															final bool ancho =
																bc.maxWidth > 680;
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
																			),
																		),
																		const SizedBox(
																			width: 16,
																		),
																		Expanded(
																			flex: 10,
																			child: Column(
																				children: <Widget>[
																					_tarjetaActualizarUSB(
																						almacen,
																					),
																					const SizedBox(
																						height: 16,
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
																	),
																	const SizedBox(
																		height: 16,
																	),
																	_tarjetaActualizarUSB(
																		almacen,
																	),
																	const SizedBox(
																		height: 16,
																	),
																	_tarjetaAccesibilidad(
																		cfg,
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
			padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
			child: Row(
				children: <Widget>[
					FilledButton.tonalIcon(
						style: FilledButton.styleFrom(
							backgroundColor: Paleta.cremaTarjeta,
							foregroundColor: Paleta.verdeBosque,
						),
						onPressed: () => Navigator.of(context).pop(),
						icon: const Icon(Icons.arrow_back_rounded),
						label: const Text(
							'Inicio',
							style: TextStyle(fontWeight: FontWeight.w800),
						),
					),
					const SizedBox(width: 14),
					const Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: <Widget>[
								Text(
									'CONFIGURACIÓN',
									style: TextStyle(
										fontSize: 22,
										fontWeight: FontWeight.w900,
										color: Paleta.verdeBosque,
										letterSpacing: 0.5,
									),
								),
								Text(
									'Prepara tus libros SEP y elige cómo quieres aprender.',
									style: TextStyle(
										fontSize: 13.5,
										color: Paleta.textoSecundario,
									),
								),
							],
						),
					),
					const Mascota(
						estado: EstadoMascota.reposo,
						tamano: 44,
						mostrarEtiqueta: false,
					),
				],
			),
		);
	}

	/// Tarjeta izquierda de 6_DisenoUI.pdf pagina 6: "Base de conocimiento" (4°, 5°, 6°).
	Widget _tarjetaBaseConocimiento(
		ConfiguracionAula cfg,
		AlmacenVectoresChroma almacen,
	) {
		return Container(
			padding: const EdgeInsets.all(18),
			decoration: BoxDecoration(
				color: const Color(0xFFEDF2E6),
				borderRadius: BorderRadius.circular(22),
				border: Border.all(
					color: Paleta.verdeBosque.withValues(alpha: 0.15),
				),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: <Widget>[
					const Row(
						children: <Widget>[
							Icon(
								Icons.menu_book_rounded,
								color: Paleta.verdeBosque,
							),
							SizedBox(width: 8),
							Text(
								'Base de conocimiento SEP',
								style: TextStyle(
									fontSize: 18,
									fontWeight: FontWeight.w800,
									color: Paleta.verdeBosque,
								),
							),
						],
					),
					const SizedBox(height: 6),
					const Text(
						'Libros oficiales de Geografía de la SEP preinstalados (RF-02, RF-07). Selecciona el grado escolar:',
						style: TextStyle(
							fontSize: 13.5,
							color: Paleta.textoSecundario,
						),
					),
					const SizedBox(height: 14),
					...Reglas.gradosSoportados.map((int grado) {
						final bool seleccionado = cfg.gradoActual == grado;
						return Padding(
							padding: const EdgeInsets.only(bottom: 10),
							child: InkWell(
								borderRadius: BorderRadius.circular(16),
								onTap: () => seleccionarGrado(grado),
								child: Container(
									padding: const EdgeInsets.all(14),
									decoration: BoxDecoration(
										color: Colors.white,
										borderRadius: BorderRadius.circular(16),
										border: Border.all(
											color: seleccionado
												? Paleta.verdeBosque
												: Colors.transparent,
											width: 2,
										),
									),
									child: Row(
										children: <Widget>[
											Icon(
												seleccionado
													? Icons.check_circle_rounded
													: Icons.book_outlined,
												color: Paleta.verdeBosque,
											),
											const SizedBox(width: 12),
											Expanded(
												child: Column(
													crossAxisAlignment:
														CrossAxisAlignment.start,
													children: <Widget>[
														Text(
															'Libros SEP Geografía $grado°',
															style: const TextStyle(
																fontWeight:
																	FontWeight.w800,
																fontSize: 15,
															),
														),
														Text(
															seleccionado
																? 'Activo · Nivel adaptado a $grado° de primaria'
																: 'Disponible sin conexión · Toca para activar',
															style: const TextStyle(
																fontSize: 12.5,
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
					const SizedBox(height: 6),
					Container(
						width: double.infinity,
						padding: const EdgeInsets.symmetric(
							horizontal: 14,
							vertical: 12,
						),
						decoration: BoxDecoration(
							color: Paleta.verdeBosque,
							borderRadius: BorderRadius.circular(14),
						),
						child: Row(
							children: <Widget>[
								const Icon(
									Icons.verified_user_rounded,
									color: Paleta.verdeLima,
									size: 20,
								),
								const SizedBox(width: 10),
								Expanded(
									child: Text(
										'Solo lectura protegida (RNF-02) · ${almacen.totalFragmentos} bloques · ${almacen.obtenerAlmacenamientoUsadoMB().toStringAsFixed(1)} MB / 4096 MB (RNF-09)',
										style: const TextStyle(
											color: Colors.white,
											fontSize: 12.5,
											fontWeight: FontWeight.w600,
										),
									),
								),
							],
						),
					),
				],
			),
		);
	}

	/// Tarjeta superior derecha de 6_DisenoUI.pdf pagina 6: "Actualizar sistema" (RF-05 y RF-11).
	Widget _tarjetaActualizarUSB(AlmacenVectoresChroma almacen) {
		return Container(
			padding: const EdgeInsets.all(18),
			decoration: BoxDecoration(
				color: const Color(0xFFEDF2E6),
				borderRadius: BorderRadius.circular(22),
				border: Border.all(
					color: Paleta.verdeBosque.withValues(alpha: 0.15),
				),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: <Widget>[
					const Row(
						children: <Widget>[
							Icon(
								Icons.usb_rounded,
								color: Paleta.verdeBosque,
							),
							SizedBox(width: 8),
							Text(
								'Actualizar sistema (USB)',
								style: TextStyle(
									fontSize: 18,
									fontWeight: FontWeight.w800,
									color: Paleta.verdeBosque,
								),
							),
						],
					),
					const SizedBox(height: 6),
					const Text(
						'Conecta una memoria USB entregada en el Consejo Técnico Escolar para actualizar sin internet (RF-05):',
						style: TextStyle(
							fontSize: 13.5,
							color: Paleta.textoSecundario,
						),
					),
					const SizedBox(height: 12),
					Container(
						width: double.infinity,
						padding: const EdgeInsets.symmetric(
							horizontal: 14,
							vertical: 11,
						),
						decoration: BoxDecoration(
							color: Colors.white,
							borderRadius: BorderRadius.circular(14),
						),
						child: Row(
							children: <Widget>[
								Icon(
									_ultimoReporte?.exitoso == true
										? Icons.check_circle_rounded
										: Icons.info_outline_rounded,
									size: 18,
									color: Paleta.verdeBosque,
								),
								const SizedBox(width: 8),
								Expanded(
									child: Text(
										'$_estadoUSB · Versión: ${almacen.versionActual}',
										style: const TextStyle(
											fontSize: 13,
											fontWeight: FontWeight.w600,
										),
									),
								),
							],
						),
					),
					const SizedBox(height: 12),
					SizedBox(
						width: double.infinity,
						child: FilledButton.icon(
							style: FilledButton.styleFrom(
								backgroundColor: Paleta.verdeBoton,
								foregroundColor: Colors.white,
								padding: const EdgeInsets.symmetric(
									vertical: 13,
								),
								shape: RoundedRectangleBorder(
									borderRadius: BorderRadius.circular(14),
								),
							),
							onPressed: _actualizandoUSB ? null : verificarUSBClick,
							icon: _actualizandoUSB
								? const SizedBox(
									width: 18,
									height: 18,
									child: CircularProgressIndicator(
										strokeWidth: 2,
										color: Colors.white,
									),
								)
								: const Icon(Icons.sync_rounded),
							label: Text(
								_actualizandoUSB
									? 'Actualizando base SEP…'
									: 'Verificar actualizaciones en USB',
								style: const TextStyle(
									fontWeight: FontWeight.w800,
								),
							),
						),
					),
					if (_ultimoReporte != null && _ultimoReporte!.exitoso) ...<Widget>[
						const SizedBox(height: 8),
						Text(
							'✅ Confirmación (RF-11): ${_ultimoReporte!.fragmentosCargados} temas oficiales listos en ${_ultimoReporte!.duracionSegundos.toStringAsFixed(1)} s.',
							style: const TextStyle(
								fontSize: 12.5,
								fontWeight: FontWeight.w700,
								color: Paleta.verdeBosque,
							),
						),
					],
				],
			),
		);
	}

	/// Tarjeta inferior derecha de 6_DisenoUI.pdf pagina 6: "Configuración de accesibilidad".
	Widget _tarjetaAccesibilidad(ConfiguracionAula cfg) {
		return Container(
			padding: const EdgeInsets.all(18),
			decoration: BoxDecoration(
				color: Paleta.verdeBosque,
				borderRadius: BorderRadius.circular(22),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: <Widget>[
					const Row(
						children: <Widget>[
							Icon(
								Icons.accessibility_new_rounded,
								color: Paleta.verdeLima,
							),
							SizedBox(width: 8),
							Expanded(
								child: Text(
									'Configuración de accesibilidad',
									style: TextStyle(
										fontSize: 18,
										fontWeight: FontWeight.w800,
										color: Colors.white,
									),
								),
							),
						],
					),
					const SizedBox(height: 6),
					const Text(
						'Ajusta el tamaño del texto, el contraste y la velocidad de la voz a tu medida (RNF-08).',
						style: TextStyle(
							fontSize: 13,
							color: Colors.white70,
						),
					),
					const SizedBox(height: 12),
					Text(
						'Tamaño de letra: ${cfg.tamanoFuente} pt',
						style: const TextStyle(
							color: Colors.white,
							fontWeight: FontWeight.w700,
						),
					),
					Slider(
						value: cfg.tamanoFuente.toDouble(),
						min: Reglas.tamanoTextoMin.toDouble(),
						max: Reglas.tamanoTextoMax.toDouble(),
						divisions: Reglas.tamanoTextoMax - Reglas.tamanoTextoMin,
						activeColor: Paleta.verdeLima,
						onChanged: (double v) => ajustarTamanoTexto(v.round()),
					),
					Text(
						'Velocidad de lectura por voz: ${cfg.velocidadLecturaVoz.toStringAsFixed(1)}x',
						style: const TextStyle(
							color: Colors.white,
							fontWeight: FontWeight.w700,
						),
					),
					Slider(
						value: cfg.velocidadLecturaVoz,
						min: Reglas.velocidadVozMin,
						max: Reglas.velocidadVozMax,
						divisions: 8,
						activeColor: Paleta.verdeLima,
						onChanged: ajustarVelocidadVoz,
					),
					SwitchListTile(
						contentPadding: EdgeInsets.zero,
						activeColor: Paleta.verdeLima,
						title: const Text(
							'Leer respuestas en voz alta automáticamente',
							style: TextStyle(color: Colors.white, fontSize: 14),
						),
						value: cfg.vozAutomatica,
						onChanged: (bool val) => widget.controlador
							.actualizarPreferencias(vozAutomatica: val),
					),
					SwitchListTile(
						contentPadding: EdgeInsets.zero,
						activeColor: Paleta.verdeLima,
						title: const Text(
							'Modo de alto contraste visual',
							style: TextStyle(color: Colors.white, fontSize: 14),
						),
						value: cfg.altoContraste,
						onChanged: (bool val) => widget.controlador
							.actualizarPreferencias(altoContraste: val),
					),
				],
			),
		);
	}

	/// Barra resumen inferior identica al pie de pagina 6 de 6_DisenoUI.pdf.
	Widget _barraEstadoInferior(ConfiguracionAula cfg) {
		final String textoTam = cfg.tamanoFuente > 20 ? 'Texto grande' : 'Texto normal';
		final String contraste =
			cfg.altoContraste ? 'Alto contraste' : 'Contraste estándar';
		final String voz = cfg.vozAutomatica ? 'Voz activada' : 'Voz manual';

		return Padding(
			padding: const EdgeInsets.only(bottom: 10, top: 4),
			child: Container(
				padding: const EdgeInsets.symmetric(
					horizontal: 16,
					vertical: 7,
				),
				decoration: BoxDecoration(
					color: Paleta.verdeBosque,
					borderRadius: BorderRadius.circular(20),
				),
				child: Text(
					'🔊 $textoTam · $contraste · $voz · Lectura ${cfg.velocidadLecturaVoz.toStringAsFixed(1)}x',
					style: const TextStyle(
						color: Colors.white,
						fontSize: 12.5,
						fontWeight: FontWeight.w600,
					),
				),
			),
		);
	}
}

