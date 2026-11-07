import 'package:flutter/material.dart';

import '../controllers/controlador_tutor.dart';
import '../core/reglas.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import 'mascota.dart';
import 'pantalla_configuracion.dart';

/// Menu lateral (Sidebar) fiel a la Fase 3 de 6_DisenoUI.pdf (pagina 6):
/// Muestra las categorias de Temas, las consultas Recientes, el boton de
/// "nueva conversacion" (RF-09) y acceso directo a Configuracion.
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
		return Drawer(
			backgroundColor: Paleta.verdeBosque,
			width: 320,
			child: SafeArea(
				child: Padding(
					padding: const EdgeInsets.symmetric(
						horizontal: 20,
						vertical: 14,
					),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: <Widget>[
							// Encabezado CERRAR | GEOGRAF-IA
							Row(
								mainAxisAlignment: MainAxisAlignment.spaceBetween,
								children: <Widget>[
									TextButton(
										onPressed: () => Navigator.of(context).pop(),
										child: const Text(
											'CERRAR',
											style: TextStyle(
												color: Colors.white70,
												fontWeight: FontWeight.w700,
												letterSpacing: 1.1,
											),
										),
									),
									const Text(
										'GEOGRAF-IA',
										style: TextStyle(
											color: Colors.white,
											fontWeight: FontWeight.w800,
											letterSpacing: 1.2,
										),
									),
								],
							),
							const SizedBox(height: 12),
							const Text(
								'Temas',
								style: TextStyle(
									color: Colors.white,
									fontSize: 22,
									fontWeight: FontWeight.w800,
								),
							),
							const SizedBox(height: 10),
							...Reglas.categoriasTemas.map(
								(Map<String, String> tema) => Padding(
									padding: const EdgeInsets.only(bottom: 8),
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
												horizontal: 14,
												vertical: 11,
											),
											decoration: BoxDecoration(
												color: Paleta.cremaFondo,
												borderRadius: BorderRadius.circular(14),
											),
											child: Row(
												children: <Widget>[
													Icon(
														_iconoPorNombre(tema['icono'] ?? ''),
														color: Paleta.verdeBosque,
														size: 20,
													),
													const SizedBox(width: 10),
													Expanded(
														child: Text(
															tema['titulo'] ?? '',
															style: const TextStyle(
																color: Paleta.verdeBosque,
																fontSize: 16,
																fontWeight: FontWeight.w700,
															),
														),
													),
												],
											),
										),
									),
								),
							),
							const SizedBox(height: 14),
							const Text(
								'Recientes',
								style: TextStyle(
									color: Colors.white,
									fontSize: 20,
									fontWeight: FontWeight.w800,
								),
							),
							const SizedBox(height: 8),
							Expanded(
								child: ListView.builder(
									itemCount: controlador.consultasRecientes.length,
									itemBuilder: (BuildContext context, int i) {
										final String pregunta =
											controlador.consultasRecientes[i];
										return Padding(
											padding: const EdgeInsets.only(bottom: 8),
											child: InkWell(
												borderRadius: BorderRadius.circular(14),
												onTap: () {
													Navigator.of(context).pop();
													controlador.enviarPregunta(pregunta);
												},
												child: Container(
													padding: const EdgeInsets.symmetric(
														horizontal: 14,
														vertical: 10,
													),
													decoration: BoxDecoration(
														color: Paleta.cremaFondo
															.withValues(alpha: 0.92),
														borderRadius: BorderRadius.circular(14),
													),
													child: Text(
														pregunta,
														maxLines: 1,
														overflow: TextOverflow.ellipsis,
														style: const TextStyle(
															color: Paleta.textoPrimario,
															fontSize: 14.5,
															fontWeight: FontWeight.w600,
														),
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
										foregroundColor: Colors.white,
										side: const BorderSide(color: Colors.white54),
										padding: const EdgeInsets.symmetric(vertical: 12),
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(24),
										),
									),
									onPressed: () {
										Navigator.of(context).pop();
										Navigator.of(context).push(
											MaterialPageRoute<void>(
												builder: (_) => PantallaConfiguracion(
													controlador: controlador,
												),
											),
										);
									},
									icon: const Icon(Icons.settings_rounded),
									label: const Text(
										'Configuración y USB',
										style: TextStyle(
											fontSize: 15,
											fontWeight: FontWeight.w700,
										),
									),
								),
							),
							const SizedBox(height: 10),
							// Pie con boton "nueva conversacion" (RF-09) y mascota
							Row(
								children: <Widget>[
									Expanded(
										child: FilledButton.icon(
											style: FilledButton.styleFrom(
												backgroundColor: Paleta.verdeLima,
												foregroundColor: Paleta.verdeBosque,
												padding: const EdgeInsets.symmetric(
													vertical: 14,
												),
												shape: RoundedRectangleBorder(
													borderRadius: BorderRadius.circular(28),
												),
											),
											onPressed: () {
												controlador.reiniciarContextoSesion();
												Navigator.of(context).pop();
											},
											icon: const Icon(Icons.arrow_forward_rounded),
											label: const Text(
												'nueva conversación',
												style: TextStyle(
													fontSize: 15.5,
													fontWeight: FontWeight.w800,
												),
											),
										),
									),
									const SizedBox(width: 8),
									const Mascota(
										estado: EstadoMascota.reposo,
										tamano: 46,
										mostrarEtiqueta: false,
									),
								],
							),
						],
					),
				),
			),
		);
	}
}

