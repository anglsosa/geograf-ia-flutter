import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/controlador_tutor.dart';
import 'core/tema.dart';
import 'ui/pantalla_chat.dart';

void main() {
	WidgetsFlutterBinding.ensureInitialized();
	runApp(const GeografIaApp());
}

/// Aplicacion principal Geograf-IA (100% Offline, RF-12: Sin login ni registro).
class GeografIaApp extends StatefulWidget {
	const GeografIaApp({super.key});

	@override
	State<GeografIaApp> createState() => _GeografIaAppState();
}

class _GeografIaAppState extends State<GeografIaApp> {
	late final ControladorTutor _controlador = ControladorTutor();

	@override
	void initState() {
		super.initState();
		// Detecta el modelo de IA instalado y lo carga en segundo plano.
		_controlador.iniciar();
	}

	@override
	void dispose() {
		_controlador.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return ChangeNotifierProvider<ControladorTutor>.value(
			value: _controlador,
			child: Consumer<ControladorTutor>(
				builder: (BuildContext context, ControladorTutor c, Widget? _) {
					return MaterialApp(
						title: 'Geograf-IA · Tutor SEP Offline',
						debugShowCheckedModeBanner: false,
						theme: construirTema(
							altoContraste: c.configuracion.altoContraste,
							tamanoBase: c.configuracion.tamanoFuente,
						),
						home: PantallaChat(controlador: c),
					);
				},
			),
		);
	}
}

