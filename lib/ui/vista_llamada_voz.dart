import 'dart:async';
import 'package:flutter/material.dart';

import '../controllers/controlador_tutor.dart';
import '../core/reglas.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import 'mascota.dart';

/// Vista de Llamada de Voz inspirada directamente en la pantalla izquierda de
/// la referencia visual ("Coach Voice Call"):
/// Ideal para ninos con baja alfabetizacion digital o dificultades de lectura
/// (RF-01, RF-04 y RNF-08).
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
				return 'Consultando tu libro SEP de ${widget.controlador.configuracion.gradoActual}° grado…';
			case EstadoMascota.hablando:
				return 'Geograf-IA está hablando contigo';
			case EstadoMascota.reposo:
				return 'Toca el micrófono o elige una pregunta para hablar';
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
				child: Padding(
					padding: const EdgeInsets.symmetric(
						horizontal: 24,
						vertical: 16,
					),
					child: Column(
						children: <Widget>[
							const SizedBox(height: 8),
							// Indicador superior estilo "Connected / Coach Voice Call"
							Text(
								'Sin internet · Libro SEP ${c.configuracion.gradoActual}° Primaria',
								style: const TextStyle(
									fontSize: 13.5,
									fontWeight: FontWeight.w600,
									color: Paleta.textoSecundario,
								),
							),
							const SizedBox(height: 4),
							const Text(
								'Tutor de Voz Geograf-IA',
								style: TextStyle(
									fontSize: 24,
									fontWeight: FontWeight.w800,
									color: Paleta.textoPrimario,
									letterSpacing: -0.4,
								),
							),
							const Spacer(),
							// Esfera 3D gigante en el centro
							Mascota(
								estado: c.estado,
								tamano: 195,
								mostrarEtiqueta: false,
								mostrarOrejas: false,
							),
							const SizedBox(height: 24),
							// Contador de tiempo 01:24 + estado
							Text(
								_tiempoFormateado,
								style: const TextStyle(
									fontSize: 28,
									fontWeight: FontWeight.w800,
									color: Paleta.textoPrimario,
								),
							),
							const SizedBox(height: 4),
							Text(
								_subtituloEstado(c.estado),
								textAlign: TextAlign.center,
								style: const TextStyle(
									fontSize: 15,
									fontWeight: FontWeight.w500,
									color: Paleta.textoSecundario,
								),
							),
							const SizedBox(height: 16),
							// Subtitulos accesibles de la ultima explicacion + cita SEP
							if (ultimaRespuesta != null)
								Container(
									padding: const EdgeInsets.all(14),
									constraints: const BoxConstraints(maxWidth: 460),
									decoration: BoxDecoration(
										color: Colors.white.withValues(alpha: 0.9),
										borderRadius: BorderRadius.circular(20),
										boxShadow: <BoxShadow>[
											BoxShadow(
												color: Colors.black.withValues(alpha: 0.04),
												blurRadius: 12,
											),
										],
									),
									child: Column(
										children: <Widget>[
											Text(
												ultimaRespuesta.texto,
												maxLines: 3,
												overflow: TextOverflow.ellipsis,
												textAlign: TextAlign.center,
												style: const TextStyle(
													fontSize: 14.5,
													color: Paleta.textoPrimario,
													height: 1.35,
												),
											),
											if (ultimaRespuesta.citaFuente.isNotEmpty) ...<Widget>[
												const SizedBox(height: 6),
												Text(
													'📖 ${ultimaRespuesta.citaFuente}',
													style: const TextStyle(
														fontSize: 12,
														fontWeight: FontWeight.w700,
														color: Paleta.verdeBosque,
													),
												),
											],
										],
									),
								),
							const Spacer(),
							// Frases de voz rapidas para probar STT en FlutLab sin microfono fisico
							SizedBox(
								height: 38,
								child: ListView.separated(
									scrollDirection: Axis.horizontal,
									itemCount: Reglas.preguntasVozDemo.length,
									separatorBuilder: (_, __) => const SizedBox(width: 8),
									itemBuilder: (BuildContext context, int i) {
										final String frase = Reglas.preguntasVozDemo[i];
										return ActionChip(
											backgroundColor: Colors.white.withValues(alpha: 0.85),
											avatar: const Icon(
												Icons.record_voice_over_rounded,
												size: 16,
												color: Paleta.verdeBosque,
											),
											label: Text(
												frase,
												style: const TextStyle(fontSize: 13),
											),
											onPressed: c.ocupado
												? null
												: () => c.preguntarPorVoz(fraseSimulada: frase),
										);
									},
								),
							),
							const SizedBox(height: 22),
							// Dos botones circulares inferiores identicos a la imagen ("Coach Voice Call")
							Row(
								mainAxisAlignment: MainAxisAlignment.spaceBetween,
								children: <Widget>[
									_BotonCircularLlamada(
										icono: c.estado == EstadoMascota.escuchando
											? Icons.graphic_eq_rounded
											: Icons.mic_none_rounded,
										etiqueta: 'Hablar por voz',
										activo: c.estado == EstadoMascota.escuchando,
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
					width: 68,
					height: 68,
					decoration: BoxDecoration(
						shape: BoxShape.circle,
						color: activo ? Paleta.verdeBosque : Colors.white,
						boxShadow: <BoxShadow>[
							BoxShadow(
								color: Colors.black.withValues(alpha: 0.08),
								blurRadius: 16,
								offset: const Offset(0, 6),
							),
						],
					),
					child: Icon(
						icono,
						size: 28,
						color: activo ? Colors.white : Paleta.textoPrimario,
					),
				),
			),
		);
	}
}

