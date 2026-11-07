import 'package:flutter/material.dart';

/// Paleta cromatica suave, armonica y amigable para ninos ("Coach Voice Call"):
/// Fondo crema calido, tarjetas blancas limpias, acentos salvia/menta suaves
/// sin bloques verdes saturados.
class Paleta {
	Paleta._();

	// Tonos base suaves estilo Coach Voice Call
	static const Color cremaFondo = Color(0xFFF4F0EA);
	static const Color cremaTarjeta = Color(0xFFFAF8F5);
	static const Color lavandaSuave = Color(0xFFEBE5F0);
	static const Color esferaCeleste = Color(0xFFD8EEF1);
	static const Color esferaSombra = Color(0xFFAECFD6);
	static const Color haloCalido = Color(0xFFFFF4DC);

	// Acentos suaves y amigables (salvia / menta / pizarra suave)
	static const Color verdeBosque = Color(0xFF2F5D50);
	static const Color verdePino = Color(0xFF3E7364);
	static const Color verdeBoton = Color(0xFF2F5D50);
	static const Color verdeLima = Color(0xFFDCEAB2);
	static const Color salviaSuave = Color(0xFFE6EFEA);
	static const Color bordeSuave = Color(0xFFE2DDD5);

	// Texto y burbujas
	static const Color textoPrimario = Color(0xFF22262B);
	static const Color textoSecundario = Color(0xFF6C737A);
	static const Color burbujaAlumno = Color(0xFF262A32);
	static const Color burbujaTutor = Color(0xFFFFFFFF);
	static const Color alertaMaestro = Color(0xFFFFF6E8);
	static const Color bordeAlerta = Color(0xFFE6A23C);
}

ThemeData construirTema({bool altoContraste = false, int tamanoBase = 16}) {
	final double escala = tamanoBase / 16.0;
	final Color fondo =
		altoContraste ? const Color(0xFFFFFFFF) : Paleta.cremaFondo;
	final Color primario =
		altoContraste ? const Color(0xFF1A3A30) : Paleta.verdeBosque;

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
				fontSize: 21 * escala,
				fontWeight: FontWeight.w800,
				color: Paleta.textoPrimario,
				letterSpacing: -0.4,
				height: 1.2,
			),
			titleLarge: TextStyle(
				fontSize: 17 * escala,
				fontWeight: FontWeight.w700,
				color: Paleta.textoPrimario,
			),
			bodyLarge: TextStyle(
				fontSize: 15.5 * escala,
				height: 1.38,
				color: Paleta.textoPrimario,
			),
			bodyMedium: TextStyle(
				fontSize: 14 * escala,
				height: 1.35,
				color: Paleta.textoPrimario,
			),
		),
	);
}
