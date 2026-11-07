import 'dart:async';
import 'package:flutter/material.dart';

import '../controllers/controlador_tutor.dart';
import '../core/reglas.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import 'mascota.dart';

/// Vista de Llamada de Voz inspirada en "Coach Voice Call":
/// Totalmente responsiva para pantallas pequenas y grandes.
class VistaLlamadaVoz extends StatefulWidget {
	const VistaLlamadaVoz({
		super.key,
		required this.controlador,
		required this.alCerrar,
	});

	final ControladorTutor controlador;
	final VoidCallback alCerrar;

	@override
	State<VistaLlamadaVoz> createState() => _VistaLlamadaVozState();
}

class _VistaLlamadaVozState extends State<VistaLlamadaVoz> {
	Timer? _reloj;
	int _segundos = 0;

	@override
	void initState() {
		super.initState();
		_reloj = Timer.periodic(const Duration(seconds: 1), (_) {
			if (mounted) {
				setState(() {
					_segundos++;
				});
			}
		});
	}

	@override
	void dispose() {
		_reloj?.cancel();
		super.dispose();
	}

	String get _tiempoFormateado {
		final int min = _segundos ~/ 60;
		final int seg = _segundos % 60;
		final String m = min.toString().padLeft(2, '0');
		final String s = seg.toString().padLeft(2, '0');
		return '$m:$s';
	}

	String _subtituloEstado(EstadoMascota estado) {
		switch (estado) {
			case EstadoMascota.escuchando:
				return 'Geograf-IA te está escuchando…';
			case EstadoMascota.pensando:
				return 'Consultando libro SEP de ${widget.controlador.configuracion.gradoActual}° grado…';
			case EstadoMascota.hablando:
				return 'Geograf-IA está hablando contigo';
			case EstadoMascota.reposo:
				return 'Toca el micrófono o elige una pregunta abajo';
		}
	}

	@override
	Widget build(BuildContext context) {
		final ControladorTutor c = widget.controlador;
		final MensajeChat? ultimaRespuesta = c.mensajes
			.where((MensajeChat m) => m.rol == RolMensaje.tutor)
			.lastOrNull;

		return Container(
			decoration: const BoxDecoration(
				gradient: RadialGradient(
					center: Alignment(0.0, -0.1),
					radius: 0.95,
					colors: <Color>[
						Paleta.haloCalido,
						Paleta.cremaFondo,
						Paleta.lavandaSuave,
					],
					stops: <double>[0.0, 0.65, 1.0],
				),
			),
			child: SafeArea(
				child: LayoutBuilder(
					builder: (BuildContext context, BoxConstraints bc) {
						final bool pantallaBaja = bc.maxHeight < 640;
						final double tamEsfera = pantallaBaja ? 135.0 : 175.0;

						return Padding(
							padding: const EdgeInsets.symmetric(
								horizontal: 18,
								vertical: 12,
							),
							child: Column(
								children: <Widget>[
									Text(
										'Sin internet · Libro SEP ${c.configuracion.gradoActual}° Primaria',
										maxLines: 1,
										overflow: TextOverflow.ellipsis,
										style: const TextStyle(
											fontSize: 12.5,
											fontWeight: FontWeight.w600,
											color: Paleta.textoSecundario,
										),
									),
									const SizedBox(height: 2),
									const Text(
										'Tutor de Voz Geograf-IA',
										maxLines: 1,
										overflow: TextOverflow.ellipsis,
										style: TextStyle(
											fontSize: 20,
											fontWeight: FontWeight.w800,
											color: Paleta.textoPrimario,
											letterSpacing: -0.4,
										),
									),
									const Spacer(),
									Mascota(
										estado: c.estado,
										tamano: tamEsfera,
										mostrarEtiqueta: false,
										mostrarOrejas: false,
									),
									SizedBox(height: pantallaBaja ? 12 : 20),
									Text(
										_tiempoFormateado,
										style: const TextStyle(
											fontSize: 24,
											fontWeight: FontWeight.w800,
											color: Paleta.textoPrimario,
										),
									),
									const SizedBox(height: 2),
									Text(
										_subtituloEstado(c.estado),
										textAlign: TextAlign.center,
										maxLines: 2,
										overflow: TextOverflow.ellipsis,
										style: const TextStyle(
											fontSize: 13.5,
											fontWeight: FontWeight.w500,
											color: Paleta.textoSecundario,
										),
									),
									if (ultimaRespuesta != null) ...<Widget>[
										const SizedBox(height: 10),
										Container(
											padding: const EdgeInsets.all(12),
											constraints: const BoxConstraints(
												maxWidth: 440,
											),
											decoration: BoxDecoration(
												color: Colors.white.withValues(
													alpha: 0.92,
												),
												borderRadius:
													BorderRadius.circular(16),
												border: Border.all(
													color: Paleta.bordeSuave,
												),
											),
											child: Column(
												children: <Widget>[
													Text(
														ultimaRespuesta.texto,
														maxLines:
															pantallaBaja ? 2 : 3,
														overflow: TextOverflow
															.ellipsis,
														textAlign:
															TextAlign.center,
														style: const TextStyle(
															fontSize: 13,
															color: Paleta
																.textoPrimario,
															height: 1.3,
														),
													),
													if (ultimaRespuesta
														.citaFuente
														.isNotEmpty) ...<Widget>[
														const SizedBox(
															height: 4,
														),
														Text(
															'📖 ${ultimaRespuesta.citaFuente}',
															maxLines: 1,
															overflow:
																TextOverflow
																	.ellipsis,
															style:
																const TextStyle(
																	fontSize:
																		11,
																	fontWeight:
																		FontWeight
																			.w700,
																	color: Paleta
																		.verdeBosque,
																),
														),
													],
												],
											),
										),
									],
									const Spacer(),
									SizedBox(
										height: 34,
										child: ListView.separated(
											scrollDirection: Axis.horizontal,
											itemCount:
												Reglas.preguntasVozDemo.length,
											separatorBuilder: (_, __) =>
												const SizedBox(width: 6),
											itemBuilder: (
												BuildContext context,
												int i,
											) {
												final String frase = Reglas
													.preguntasVozDemo[i];
												return ActionChip(
													visualDensity:
														VisualDensity.compact,
													backgroundColor:
														Colors.white,
													side: const BorderSide(
														color:
															Paleta.bordeSuave,
													),
													avatar: const Icon(
														Icons
															.record_voice_over_rounded,
														size: 14,
														color:
															Paleta.verdeBosque,
													),
													label: Text(
														frase,
														style: const TextStyle(
															fontSize: 12,
														),
													),
													onPressed: c.ocupado
														? null
														: () =>
															c.preguntarPorVoz(
																fraseSimulada:
																	frase,
															),
												);
											},
										),
									),
									const SizedBox(height: 14),
									Row(
										mainAxisAlignment:
											MainAxisAlignment.spaceBetween,
										children: <Widget>[
											_BotonCircularLlamada(
												icono: c.estado ==
														EstadoMascota.escuchando
													? Icons.graphic_eq_rounded
													: Icons.mic_none_rounded,
												etiqueta: 'Hablar por voz',
												activo: c.estado ==
													EstadoMascota.escuchando,
												alPresionar: c.ocupado
													? null
													: () => c.preguntarPorVoz(),
											),
											_BotonCircularLlamada(
												icono: Icons.close_rounded,
												etiqueta: 'Volver al chat',
												activo: false,
												alPresionar: widget.alCerrar,
											),
										],
									),
								],
							),
						);
					},
				),
			),
		);
	}
}

class _BotonCircularLlamada extends StatelessWidget {
	const _BotonCircularLlamada({
		required this.icono,
		required this.etiqueta,
		required this.activo,
		required this.alPresionar,
	});

	final IconData icono;
	final String etiqueta;
	final bool activo;
	final VoidCallback? alPresionar;

	@override
	Widget build(BuildContext context) {
		return Tooltip(
			message: etiqueta,
			child: InkWell(
				onTap: alPresionar,
				customBorder: const CircleBorder(),
				child: AnimatedContainer(
					duration: const Duration(milliseconds: 220),
					width: 58,
					height: 58,
					decoration: BoxDecoration(
						shape: BoxShape.circle,
						color: activo ? Paleta.verdeBosque : Colors.white,
						border: Border.all(color: Paleta.bordeSuave),
						boxShadow: <BoxShadow>[
							BoxShadow(
								color: Colors.black.withValues(alpha: 0.06),
								blurRadius: 12,
								offset: const Offset(0, 4),
							),
						],
					),
					child: Icon(
						icono,
						size: 24,
						color: activo ? Colors.white : Paleta.textoPrimario,
					),
				),
			),
		);
	}
}
