import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../controllers/controlador_tutor.dart';
import '../core/reglas.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import 'mascota.dart';
import 'pantalla_configuracion.dart';

/// Menu lateral (Sidebar) armonizado con la paleta suave crema/pastel de la app.
/// Muestra Temas, consultas Recientes, el boton "Nueva conversacion" (RF-09)
/// y acceso directo a Configuracion.
class MenuLateralGeografIA extends StatelessWidget {
	const MenuLateralGeografIA({
		super.key,
		required this.controlador,
	});

	final ControladorTutor controlador;

	IconData _iconoPorNombre(String nombre) {
		switch (nombre) {
			case 'wb_sunny':
				return Icons.wb_sunny_rounded;
			case 'terrain':
				return Icons.terrain_rounded;
			case 'map':
				return Icons.map_rounded;
			case 'water':
				return Icons.water_drop_rounded;
			case 'flag':
				return Icons.flag_rounded;
			default:
				return Icons.explore_rounded;
		}
	}

	@override
	Widget build(BuildContext context) {
		final double anchoPantalla = MediaQuery.sizeOf(context).width;
		final double anchoDrawer = math.min(300.0, anchoPantalla * 0.85);

		return Drawer(
			backgroundColor: Paleta.cremaFondo,
			width: anchoDrawer,
			child: SafeArea(
				child: Padding(
					padding: const EdgeInsets.symmetric(
						horizontal: 16,
						vertical: 12,
					),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: <Widget>[
							// Encabezado limpio estilo Coach Voice Call
							Row(
								children: <Widget>[
									const Mascota(
										estado: EstadoMascota.reposo,
										tamano: 36,
										mostrarEtiqueta: false,
										mostrarOrejas: false,
									),
									const SizedBox(width: 10),
									const Expanded(
										child: Column(
											crossAxisAlignment:
												CrossAxisAlignment.start,
											children: <Widget>[
												Text(
													'Geograf-IA',
													maxLines: 1,
													overflow:
														TextOverflow.ellipsis,
													style: TextStyle(
														color: Paleta
															.textoPrimario,
														fontSize: 16,
														fontWeight:
															FontWeight.w800,
													),
												),
												Text(
													'Libros SEP sin internet',
													maxLines: 1,
													overflow:
														TextOverflow.ellipsis,
													style: TextStyle(
														color: Paleta
															.textoSecundario,
														fontSize: 11.5,
														fontWeight:
															FontWeight.w600,
													),
												),
											],
										),
									),
									IconButton(
										tooltip: 'Cerrar menú',
										visualDensity: VisualDensity.compact,
										onPressed: () =>
											Navigator.of(context).pop(),
										icon: const Icon(
											Icons.close_rounded,
											color: Paleta.textoPrimario,
										),
									),
								],
							),
							const SizedBox(height: 12),
							const Text(
								'Temas para explorar',
								style: TextStyle(
									color: Paleta.textoSecundario,
									fontSize: 12.5,
									fontWeight: FontWeight.w800,
									letterSpacing: 0.3,
								),
							),
							const SizedBox(height: 8),
							...Reglas.categoriasTemas.map(
								(Map<String, String> tema) => Padding(
									padding: const EdgeInsets.only(bottom: 6),
									child: InkWell(
										borderRadius: BorderRadius.circular(14),
										onTap: () {
											Navigator.of(context).pop();
											controlador.enviarPregunta(
												tema['pregunta'] ?? '',
											);
										},
										child: Container(
											padding: const EdgeInsets.symmetric(
												horizontal: 12,
												vertical: 9,
											),
											decoration: BoxDecoration(
												color: Colors.white,
												borderRadius:
													BorderRadius.circular(14),
												border: Border.all(
													color: Paleta.bordeSuave,
												),
											),
											child: Row(
												children: <Widget>[
													Container(
														width: 30,
														height: 30,
														decoration:
															BoxDecoration(
																color: Paleta
																	.esferaCeleste,
																borderRadius:
																	BorderRadius
																		.circular(
																			8,
																		),
															),
														child: Icon(
															_iconoPorNombre(
																tema['icono'] ??
																	'',
															),
															color: Paleta
																.verdeBosque,
															size: 17,
														),
													),
													const SizedBox(width: 10),
													Expanded(
														child: Text(
															tema['titulo'] ?? '',
															maxLines: 1,
															overflow:
																TextOverflow
																	.ellipsis,
															style:
																const TextStyle(
																	color: Paleta
																		.textoPrimario,
																	fontSize: 14,
																	fontWeight:
																		FontWeight
																			.w700,
																),
														),
													),
													const Icon(
														Icons
															.chevron_right_rounded,
														size: 18,
														color: Paleta
															.textoSecundario,
													),
												],
											),
										),
									),
								),
							),
							const SizedBox(height: 10),
							const Text(
								'Consultas recientes',
								style: TextStyle(
									color: Paleta.textoSecundario,
									fontSize: 12.5,
									fontWeight: FontWeight.w800,
									letterSpacing: 0.3,
								),
							),
							const SizedBox(height: 6),
							Expanded(
								child: ListView.builder(
									padding: EdgeInsets.zero,
									itemCount:
										controlador.consultasRecientes.length,
									itemBuilder:
										(BuildContext context, int i) {
											final String pregunta = controlador
												.consultasRecientes[i];
											return Padding(
												padding: const EdgeInsets.only(
													bottom: 6,
												),
												child: InkWell(
													borderRadius:
														BorderRadius.circular(
															12,
														),
													onTap: () {
														Navigator.of(context)
															.pop();
														controlador
															.enviarPregunta(
																pregunta,
															);
													},
													child: Container(
														padding:
															const EdgeInsets
																.symmetric(
																	horizontal:
																		12,
																	vertical: 8,
																),
														decoration:
															BoxDecoration(
																color: Paleta
																	.cremaTarjeta,
																borderRadius:
																	BorderRadius
																		.circular(
																			12,
																		),
																border: Border.all(
																	color: Paleta
																		.bordeSuave,
																),
															),
														child: Row(
															children: <Widget>[
																const Icon(
																	Icons
																		.history_rounded,
																	size: 15,
																	color: Paleta
																		.textoSecundario,
																),
																const SizedBox(
																	width: 8,
																),
																Expanded(
																	child: Text(
																		pregunta,
																		maxLines:
																			1,
																		overflow:
																			TextOverflow
																				.ellipsis,
																		style: const TextStyle(
																			color: Paleta
																				.textoPrimario,
																			fontSize:
																				13,
																			fontWeight:
																				FontWeight
																					.w600,
																		),
																	),
																),
															],
														),
													),
												),
											);
										},
								),
							),
							const SizedBox(height: 8),
							// Boton Configurar Aula / USB
							SizedBox(
								width: double.infinity,
								child: OutlinedButton.icon(
									style: OutlinedButton.styleFrom(
										backgroundColor: Colors.white,
										foregroundColor: Paleta.textoPrimario,
										side: const BorderSide(
											color: Paleta.bordeSuave,
										),
										padding: const EdgeInsets.symmetric(
											vertical: 10,
										),
										shape: RoundedRectangleBorder(
											borderRadius:
												BorderRadius.circular(20),
										),
									),
									onPressed: () {
										Navigator.of(context).pop();
										Navigator.of(context).push(
											MaterialPageRoute<void>(
												builder: (_) =>
													PantallaConfiguracion(
														controlador: controlador,
													),
											),
										);
									},
									icon: const Icon(
										Icons.settings_outlined,
										size: 18,
									),
									label: const Text(
										'Configuración y USB',
										style: TextStyle(
											fontSize: 13.5,
											fontWeight: FontWeight.w700,
										),
									),
								),
							),
							const SizedBox(height: 8),
							// Boton "Nueva conversacion" (RF-09)
							SizedBox(
								width: double.infinity,
								child: FilledButton.icon(
									style: FilledButton.styleFrom(
										backgroundColor: Paleta.burbujaAlumno,
										foregroundColor: Colors.white,
										padding: const EdgeInsets.symmetric(
											vertical: 11,
										),
										shape: RoundedRectangleBorder(
											borderRadius:
												BorderRadius.circular(20),
										),
									),
									onPressed: () {
										controlador.reiniciarContextoSesion();
										Navigator.of(context).pop();
									},
									icon: const Icon(
										Icons.add_comment_outlined,
										size: 18,
									),
									label: const Text(
										'Nueva conversación',
										style: TextStyle(
											fontSize: 13.5,
											fontWeight: FontWeight.w700,
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
}
