import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../models/modelos.dart';

/// Mascota digital interactiva inspirada en la esfera 3D amigable de la
/// referencia de UI ("Coach Voice Call") y la mascota de 6_DisenoUI.pdf.
/// Muestra retroalimentacion clara cuando escucha, piensa, habla o descansa.
class Mascota extends StatefulWidget {
	const Mascota({
		super.key,
		required this.estado,
		this.tamano = 150,
		this.mostrarEtiqueta = true,
		this.mostrarOrejas = true,
	});

	final EstadoMascota estado;
	final double tamano;
	final bool mostrarEtiqueta;
	final bool mostrarOrejas;

	@override
	State<Mascota> createState() => _MascotaState();
}

class _MascotaState extends State<Mascota> with SingleTickerProviderStateMixin {
	late final AnimationController _animador = AnimationController(
		vsync: this,
		duration: const Duration(milliseconds: 1400),
	)..repeat(reverse: true);

	@override
	void dispose() {
		_animador.dispose();
		super.dispose();
	}

	String get _textoEstado {
		switch (widget.estado) {
			case EstadoMascota.escuchando:
				return 'El tutor te está escuchando…';
			case EstadoMascota.pensando:
				return 'Buscando en tu libro de la SEP…';
			case EstadoMascota.hablando:
				return 'Explicando paso a paso…';
			case EstadoMascota.reposo:
				return 'Listo para ayudarte sin internet';
		}
	}

	Color get _colorHalo {
		switch (widget.estado) {
			case EstadoMascota.escuchando:
				return const Color(0xFFB8F2E6);
			case EstadoMascota.pensando:
				return const Color(0xFFFFE5A3);
			case EstadoMascota.hablando:
				return const Color(0xFFD8F3DC);
			case EstadoMascota.reposo:
				return Paleta.haloCalido;
		}
	}

	@override
	Widget build(BuildContext context) {
		return Semantics(
			label: 'Mascota Geograf-IA: $_textoEstado',
			child: AnimatedBuilder(
				animation: _animador,
				builder: (BuildContext context, Widget? _) {
					final double pulso = _animador.value;
					final bool activo = widget.estado != EstadoMascota.reposo;
					final double escala = activo
						? 1.0 + (pulso * 0.08)
						: 1.0 + (pulso * 0.025);

					return Column(
						mainAxisSize: MainAxisSize.min,
						children: <Widget>[
							Transform.scale(
								scale: escala,
								child: SizedBox(
									width: widget.tamano * 1.25,
									height: widget.tamano * 1.25,
									child: Stack(
										alignment: Alignment.center,
										children: <Widget>[
											// Halo suave luminoso estilo Coach Voice Call
											Container(
												width: widget.tamano * 1.22,
												height: widget.tamano * 1.22,
												decoration: BoxDecoration(
													shape: BoxShape.circle,
													boxShadow: <BoxShadow>[
														BoxShadow(
															color: _colorHalo.withValues(alpha: 0.75),
															blurRadius: widget.tamano * 0.35,
															spreadRadius: widget.tamano * 0.08,
														),
													],
												),
											),
											// Orejitas suaves opcionales (fusion conejo 6_DisenoUI + esfera 3D)
											if (widget.mostrarOrejas)
												Positioned(
													top: 0,
													child: Row(
														mainAxisSize: MainAxisSize.min,
														children: <Widget>[
															_construirOreja(-0.18),
															SizedBox(width: widget.tamano * 0.22),
															_construirOreja(0.18),
														],
													),
												),
											// Esfera 3D principal con sombreado radial suave
											Container(
												width: widget.tamano,
												height: widget.tamano,
												decoration: BoxDecoration(
													shape: BoxShape.circle,
													gradient: const RadialGradient(
														center: Alignment(-0.3, -0.35),
														radius: 0.95,
														colors: <Color>[
															Color(0xFFF7FCFD),
															Paleta.esferaCeleste,
															Paleta.esferaSombra,
														],
														stops: <double>[0.0, 0.62, 1.0],
													),
													boxShadow: <BoxShadow>[
														BoxShadow(
															color: Colors.black.withValues(alpha: 0.08),
															blurRadius: 22,
															offset: const Offset(0, 10),
														),
													],
												),
												child: CustomPaint(
													painter: _CaritaMascotaPainter(
														estado: widget.estado,
														progreso: pulso,
													),
												),
											),
										],
									),
								),
							),
							if (widget.mostrarEtiqueta) ...<Widget>[
								const SizedBox(height: 8),
								Container(
									padding: const EdgeInsets.symmetric(
										horizontal: 14,
										vertical: 6,
									),
									decoration: BoxDecoration(
										color: Colors.white.withValues(alpha: 0.9),
										borderRadius: BorderRadius.circular(20),
										border: Border.all(
											color: Paleta.verdeBosque.withValues(alpha: 0.15),
										),
									),
									child: Row(
										mainAxisSize: MainAxisSize.min,
										children: <Widget>[
											Icon(
												_iconoEstado,
												size: 16,
												color: Paleta.verdeBosque,
											),
											const SizedBox(width: 6),
											Text(
												_textoEstado,
												style: const TextStyle(
													fontSize: 13.5,
													fontWeight: FontWeight.w600,
													color: Paleta.textoPrimario,
												),
											),
										],
									),
								),
							],
						],
					);
				},
			),
		);
	}

	IconData get _iconoEstado {
		switch (widget.estado) {
			case EstadoMascota.escuchando:
				return Icons.mic_rounded;
			case EstadoMascota.pensando:
				return Icons.menu_book_rounded;
			case EstadoMascota.hablando:
				return Icons.volume_up_rounded;
			case EstadoMascota.reposo:
				return Icons.check_circle_outline_rounded;
		}
	}

	Widget _construirOreja(double angulo) {
		return Transform.rotate(
			angle: angulo,
			child: Container(
				width: widget.tamano * 0.22,
				height: widget.tamano * 0.42,
				decoration: BoxDecoration(
					borderRadius: BorderRadius.circular(widget.tamano * 0.15),
					gradient: const LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: <Color>[
							Color(0xFFF5FAFB),
							Paleta.esferaCeleste,
						],
					),
					boxShadow: <BoxShadow>[
						BoxShadow(
							color: Colors.black.withValues(alpha: 0.05),
							blurRadius: 6,
						),
					],
				),
				alignment: Alignment.center,
				child: Container(
					width: widget.tamano * 0.1,
					height: widget.tamano * 0.25,
					decoration: BoxDecoration(
						color: const Color(0xFFF4C6C6).withValues(alpha: 0.55),
						borderRadius: BorderRadius.circular(20),
					),
				),
			),
		);
	}
}

class _CaritaMascotaPainter extends CustomPainter {
	_CaritaMascotaPainter({
		required this.estado,
		required this.progreso,
	});

	final EstadoMascota estado;
	final double progreso;

	@override
	void paint(Canvas canvas, Size size) {
		final double cx = size.width / 2;
		final double cy = size.height / 2;
		final double r = size.width * 0.5;

		final Paint pinturaOjo = Paint()
			..color = const Color(0xFF232B2B)
			..style = PaintingStyle.fill;

		final Paint pinturaBrillo = Paint()
			..color = Colors.white
			..style = PaintingStyle.fill;

		final Paint pinturaMejilla = Paint()
			..color = const Color(0xFFF4A8A8).withValues(alpha: 0.35)
			..style = PaintingStyle.fill;

		// Posicion de los ojos (estilo tierno centrado como en la imagen subida)
		final double sepX = r * 0.34;
		final double ojoY = cy - (r * 0.04);
		final double radioOjo = r * 0.095;

		// Mejillas rosadas suaves
		canvas.drawOval(
			Rect.fromCenter(
				center: Offset(cx - sepX * 1.35, ojoY + r * 0.14),
				width: r * 0.18,
				height: r * 0.1,
			),
			pinturaMejilla,
		);
		canvas.drawOval(
			Rect.fromCenter(
				center: Offset(cx + sepX * 1.35, ojoY + r * 0.14),
				width: r * 0.18,
				height: r * 0.1,
			),
			pinturaMejilla,
		);

		// Ojo izquierdo y derecho
		final Offset izq = Offset(cx - sepX, ojoY);
		final Offset der = Offset(cx + sepX, ojoY);
		canvas.drawCircle(izq, radioOjo, pinturaOjo);
		canvas.drawCircle(der, radioOjo, pinturaOjo);

		// Brillo blanco en cada ojo
		canvas.drawCircle(
			Offset(izq.dx - radioOjo * 0.28, izq.dy - radioOjo * 0.28),
			radioOjo * 0.32,
			pinturaBrillo,
		);
		canvas.drawCircle(
			Offset(der.dx - radioOjo * 0.28, der.dy - radioOjo * 0.28),
			radioOjo * 0.32,
			pinturaBrillo,
		);

		// Boca segun el estado de la mascota
		final Paint pinturaBoca = Paint()
			..color = const Color(0xFF232B2B)
			..style = PaintingStyle.stroke
			..strokeWidth = math.max(2.2, r * 0.045)
			..strokeCap = StrokeCap.round;

		final double bocaY = ojoY + (r * 0.12);
		if (estado == EstadoMascota.hablando) {
			// Boca abierta animada al hablar
			final double altoBoca = (r * 0.08) + (progreso * r * 0.07);
			canvas.drawOval(
				Rect.fromCenter(
					center: Offset(cx, bocaY + r * 0.02),
					width: r * 0.16,
					height: altoBoca,
				),
				Paint()..color = const Color(0xFF232B2B),
			);
		} else if (estado == EstadoMascota.pensando) {
			// Boquita curiosa de pensamiento ("o")
			canvas.drawCircle(
				Offset(cx + (progreso - 0.5) * 4, bocaY + r * 0.02),
				r * 0.045,
				pinturaBoca,
			);
		} else {
			// Sonrisa tierna entre los ojos (identica a la esfera de la imagen)
			final Rect rectSonrisa = Rect.fromCenter(
				center: Offset(cx, bocaY - r * 0.02),
				width: r * 0.18,
				height: r * 0.14,
			);
			canvas.drawArc(rectSonrisa, 0.2, math.pi - 0.4, false, pinturaBoca);
		}
	}

	@override
	bool shouldRepaint(covariant _CaritaMascotaPainter oldDelegate) {
		return oldDelegate.estado != estado || oldDelegate.progreso != progreso;
	}
}

/// Tarjeta de apoyo visual didactico que acompana las explicaciones del tutor,
/// tal como muestra 6_DisenoUI.pdf en la pagina 5 (diagrama del volcan con flecha).
class TarjetaIlustracionDidactica extends StatelessWidget {
	const TarjetaIlustracionDidactica({
		super.key,
		required this.tipoIlustracion,
		required this.notaIlustracion,
	});

	final String tipoIlustracion;
	final String notaIlustracion;

	@override
	Widget build(BuildContext context) {
		if (tipoIlustracion.isEmpty) {
			return const SizedBox.shrink();
		}
		return Container(
			margin: const EdgeInsets.only(top: 10),
			padding: const EdgeInsets.all(10),
			decoration: BoxDecoration(
				color: Paleta.salviaSuave,
				borderRadius: BorderRadius.circular(14),
				border: Border.all(color: Paleta.bordeSuave),
			),
			child: Row(
				children: <Widget>[
					Container(
						width: 78,
						height: 62,
						decoration: BoxDecoration(
							color: const Color(0xFFFBE9D7),
							borderRadius: BorderRadius.circular(10),
						),
						child: ClipRRect(
							borderRadius: BorderRadius.circular(10),
							child: CustomPaint(
								painter: _DiagramaGeografiaPainter(tipoIlustracion),
							),
						),
					),
					const SizedBox(width: 10),
					Expanded(
						child: Text(
							notaIlustracion,
							style: const TextStyle(
								color: Paleta.textoPrimario,
								fontSize: 12.5,
								height: 1.3,
								fontWeight: FontWeight.w600,
							),
						),
					),
				],
			),
		);
	}
}

class _DiagramaGeografiaPainter extends CustomPainter {
	_DiagramaGeografiaPainter(this.tipo);

	final String tipo;

	@override
	void paint(Canvas canvas, Size size) {
		final double w = size.width;
		final double h = size.height;

		if (tipo == 'volcan') {
			// Cono volcanico y camara magmatica como en 6_DisenoUI.pdf pagina 5
			final Path cono = Path()
				..moveTo(w * 0.1, h * 0.85)
				..lineTo(w * 0.42, h * 0.25)
				..lineTo(w * 0.58, h * 0.25)
				..lineTo(w * 0.9, h * 0.85)
				..close();
			canvas.drawPath(cono, Paint()..color = const Color(0xFFB56B45));

			// Chimenea y magma rojo-naranja
			final Paint magma = Paint()
				..color = const Color(0xFFE04F33)
				..style = PaintingStyle.fill;
			canvas.drawOval(
				Rect.fromCenter(
					center: Offset(w * 0.5, h * 0.85),
					width: w * 0.36,
					height: h * 0.16,
				),
				magma,
			);
			canvas.drawRect(
				Rect.fromCenter(
					center: Offset(w * 0.5, h * 0.52),
					width: w * 0.08,
					height: h * 0.55,
				),
				magma,
			);
		} else if (tipo == 'ciclo_agua' || tipo == 'rios') {
			// Sol, nube y rio bajando al mar
			canvas.drawCircle(
				Offset(w * 0.22, h * 0.24),
				10,
				Paint()..color = const Color(0xFFF5B041),
			);
			canvas.drawOval(
				Rect.fromCenter(
					center: Offset(w * 0.68, h * 0.24),
					width: 34,
					height: 18,
				),
				Paint()..color = const Color(0xFF5DADE2),
			);
			final Path rio = Path()
				..moveTo(0, h * 0.78)
				..quadraticBezierTo(w * 0.5, h * 0.6, w, h * 0.82)
				..lineTo(w, h)
				..lineTo(0, h)
				..close();
			canvas.drawPath(rio, Paint()..color = const Color(0xFF2E86C1));
		} else if (tipo == 'montana') {
			canvas.drawCircle(
				Offset(w * 0.8, h * 0.2),
				8,
				Paint()..color = const Color(0xFFF5B041),
			);
			final Path atras = Path()
				..moveTo(w * 0.28, h * 0.9)
				..lineTo(w * 0.62, h * 0.3)
				..lineTo(w * 0.98, h * 0.9)
				..close();
			canvas.drawPath(atras, Paint()..color = const Color(0xFF7F8C8D));
			final Path frente = Path()
				..moveTo(w * 0.02, h * 0.9)
				..lineTo(w * 0.36, h * 0.38)
				..lineTo(w * 0.7, h * 0.9)
				..close();
			canvas.drawPath(frente, Paint()..color = const Color(0xFF5D6D7E));
			final Path nieve = Path()
				..moveTo(w * 0.36, h * 0.38)
				..lineTo(w * 0.28, h * 0.52)
				..lineTo(w * 0.36, h * 0.48)
				..lineTo(w * 0.44, h * 0.52)
				..close();
			canvas.drawPath(nieve, Paint()..color = Colors.white);
		} else if (tipo == 'brujula') {
			final Offset centro = Offset(w * 0.5, h * 0.5);
			final double r = h * 0.38;
			canvas.drawCircle(centro, r, Paint()..color = Colors.white);
			canvas.drawCircle(
				centro,
				r,
				Paint()
					..color = const Color(0xFF2F5D50)
					..style = PaintingStyle.stroke
					..strokeWidth = 3,
			);
			final Path norte = Path()
				..moveTo(centro.dx, centro.dy - r * 0.8)
				..lineTo(centro.dx - r * 0.22, centro.dy)
				..lineTo(centro.dx + r * 0.22, centro.dy)
				..close();
			canvas.drawPath(norte, Paint()..color = const Color(0xFFC0392B));
			final Path sur = Path()
				..moveTo(centro.dx, centro.dy + r * 0.8)
				..lineTo(centro.dx - r * 0.22, centro.dy)
				..lineTo(centro.dx + r * 0.22, centro.dy)
				..close();
			canvas.drawPath(sur, Paint()..color = const Color(0xFF5D6D7E));
		} else if (tipo == 'bosque') {
			canvas.drawRect(
				Rect.fromLTWH(0, h * 0.82, w, h * 0.18),
				Paint()..color = const Color(0xFF8D6E63),
			);
			for (final double fx in <double>[0.2, 0.5, 0.8]) {
				canvas.drawRect(
					Rect.fromLTWH(w * fx - 3, h * 0.6, 6, h * 0.24),
					Paint()..color = const Color(0xFF6D4C41),
				);
				final Path copa = Path()
					..moveTo(w * fx, h * 0.16)
					..lineTo(w * fx - w * 0.14, h * 0.66)
					..lineTo(w * fx + w * 0.14, h * 0.66)
					..close();
				canvas.drawPath(copa, Paint()..color = const Color(0xFF2E8B57));
			}
		} else if (tipo == 'ciudad') {
			canvas.drawRect(
				Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
				Paint()..color = const Color(0xFF7F8C8D),
			);
			final List<List<double>> edificios = <List<double>>[
				<double>[0.08, 0.45, 0.2],
				<double>[0.32, 0.25, 0.22],
				<double>[0.58, 0.5, 0.18],
				<double>[0.78, 0.35, 0.18],
			];
			for (final List<double> e in edificios) {
				canvas.drawRect(
					Rect.fromLTWH(w * e[0], h * e[1], w * e[2], h * (0.86 - e[1])),
					Paint()..color = const Color(0xFF5D6D7E),
				);
				canvas.drawRect(
					Rect.fromLTWH(
						w * e[0] + w * e[2] * 0.3,
						h * e[1] + 6,
						w * e[2] * 0.3,
						6,
					),
					Paint()..color = const Color(0xFFF7DC6F),
				);
			}
		} else if (tipo == 'oceano') {
			canvas.drawRect(
				Rect.fromLTWH(0, 0, w, h),
				Paint()..color = const Color(0xFFD6EAF8),
			);
			for (int i = 0; i < 3; i++) {
				final double y = h * (0.45 + i * 0.18);
				final Path ola = Path()..moveTo(0, y);
				for (int k = 0; k < 4; k++) {
					ola.quadraticBezierTo(
						w * (k * 0.25 + 0.125),
						y - 8,
						w * (k + 1) * 0.25,
						y,
					);
				}
				ola
					..lineTo(w, h)
					..lineTo(0, h)
					..close();
				canvas.drawPath(
					ola,
					Paint()
						..color = Color.lerp(
							const Color(0xFF5DADE2),
							const Color(0xFF1B4F72),
							i / 2,
						)!,
				);
			}
		} else if (tipo == 'sol') {
			final Offset c = Offset(w * 0.5, h * 0.5);
			final Paint rayo = Paint()
				..color = const Color(0xFFF5B041)
				..strokeWidth = 3
				..strokeCap = StrokeCap.round;
			for (int i = 0; i < 8; i++) {
				final double ang = i * math.pi / 4;
				canvas.drawLine(
					Offset(c.dx + math.cos(ang) * h * 0.30, c.dy + math.sin(ang) * h * 0.30),
					Offset(c.dx + math.cos(ang) * h * 0.44, c.dy + math.sin(ang) * h * 0.44),
					rayo,
				);
			}
			canvas.drawCircle(c, h * 0.24, Paint()..color = const Color(0xFFF39C12));
		} else {
			// Planeta Tierra / Geografia general
			canvas.drawCircle(
				Offset(w * 0.5, h * 0.5),
				h * 0.34,
				Paint()..color = const Color(0xFF2E86C1),
			);
			canvas.drawCircle(
				Offset(w * 0.45, h * 0.46),
				h * 0.16,
				Paint()..color = const Color(0xFF58D68D),
			);
		}
	}

	@override
	bool shouldRepaint(covariant _DiagramaGeografiaPainter oldDelegate) =>
		oldDelegate.tipo != tipo;
}
