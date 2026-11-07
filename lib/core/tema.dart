import 'package:flutter/material.dart';

/// Paleta cromatica que fusiona:
/// 1) El diseno limpio, calido y amigable de "Coach Voice Call" (fondo crema suave,
///    esfera celeste/menta con halo luminoso, burbujas blancas redondeadas).
/// 2) La identidad visual de Geograf-IA en 6_DisenoUI.pdf (verde bosque, acento lima).
class Paleta {
	Paleta._();

	// Tonos base suaves estilo Coach Voice Call
	static const Color cremaFondo = Color(0xFFF3EFEA);
	static const Color cremaTarjeta = Color(0xFFFAF8F5);
	static const Color lavandaSuave = Color(0xFFE6DFEC);
	static const Color esferaCeleste = Color(0xFFD6ECEF);
	static const Color esferaSombra = Color(0xFFA8CFD6);
	static const Color haloCalido = Color(0xFFFFF3D6);

	// Tonos naturaleza Geograf-IA (6_DisenoUI.pdf)
	static const Color verdeBosque = Color(0xFF1E4D3B);
	static const Color verdePino = Color(0xFF2B6CB0);
	static const Color verdeBoton = Color(0xFF215A46);
	static const Color verdeLima = Color(0xFFC5D93D);
	static const Color cieloMontana = Color(0xFF8FB9AA);

	// Texto y burbujas
	static const Color textoPrimario = Color(0xFF1E242B);
	static const Color textoSecundario = Color(0xFF687078);
	static const Color burbujaAlumno = Color(0xFF23272F);
	static const Color burbujaTutor = Color(0xFFFFFFFF);
	static const Color alertaMaestro = Color(0xFFFFF4E5);
	static const Color bordeAlerta = Color(0xFFE6A23C);
}

ThemeData construirTema({bool altoContraste = false, int tamanoBase = 19}) {
	final double escala = tamanoBase / 19.0;
	final Color fondo = altoContraste ? const Color(0xFFFFFFFF) : Paleta.cremaFondo;
	final Color primario = altoContraste ? const Color(0xFF0D2E22) : Paleta.verdeBosque;

	return ThemeData(
		useMaterial3: true,
		scaffoldBackgroundColor: fondo,
		colorScheme: ColorScheme.fromSeed(
			seedColor: primario,
			primary: primario,
			surface: fondo,
		),
		textTheme: TextTheme(
			headlineMedium: TextStyle(
				fontSize: 26 * escala,
				fontWeight: FontWeight.w800,
				color: Paleta.textoPrimario,
				letterSpacing: -0.5,
			),
			titleLarge: TextStyle(
				fontSize: 20 * escala,
				fontWeight: FontWeight.w700,
				color: Paleta.textoPrimario,
			),
			bodyLarge: TextStyle(
				fontSize: 18 * escala,
				height: 1.4,
				color: Paleta.textoPrimario,
			),
			bodyMedium: TextStyle(
				fontSize: 16 * escala,
				height: 1.35,
				color: Paleta.textoPrimario,
			),
		),
	);
}

