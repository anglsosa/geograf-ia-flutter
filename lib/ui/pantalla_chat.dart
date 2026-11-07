import 'package:flutter/material.dart';

import '../controllers/controlador_tutor.dart';
import '../core/reglas.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import 'mascota.dart';
import 'menu_lateral.dart';
import 'pantalla_configuracion.dart';
import 'vista_llamada_voz.dart';

/// ActividadChat (9_UML.pdf) - Pantalla principal de interaccion nino-tutor.
/// Integra el Modo Chat (derecha de la imagen de referencia + 6_DisenoUI.pdf)
/// y el Modo Llamada de Voz con Mascota 3D (izquierda de la imagen de referencia).
class PantallaChat extends StatefulWidget {
	const PantallaChat({
		super.key,
		required this.controlador,
	});

	final ControladorTutor controlador;

	@override
	State<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends State<PantallaChat> {
	final TextEditingController _campoTexto = TextEditingController();
	final ScrollController _scroll = ScrollController();
	bool _modoLlamadaVoz = false;
	bool _estaGrabando = false;

	@override
	void initState() {
		super.initState();
		iniciar();
	}

	@override
	void dispose() {
		_campoTexto.dispose();
		_scroll.dispose();
		super.dispose();
	}

	/// Metodo oficial del UML: +iniciar() : void
	void iniciar() {
		_estaGrabando = false;
	}

	/// Metodo oficial del UML: +enviarPreguntaTexto(texto: String) : void
	Future<void> enviarPreguntaTexto(String texto) async {
		final String limpio = texto.trim();
		if (limpio.isEmpty) {
			return;
		}
		_campoTexto.clear();
		FocusScope.of(context).unfocus();
		await widget.controlador.enviarPregunta(limpio);
		_desplazarAlFinal();
	}

	/// Metodo oficial del UML: +alPresionarMicrofono() : void
	Future<void> alPresionarMicrofono() async {
		setState(() {
			_estaGrabando = true;
		});
		await widget.controlador.preguntarPorVoz();
		if (mounted) {
			setState(() {
				_estaGrabando = false;
			});
			_desplazarAlFinal();
		}
	}

	/// Metodo oficial del UML: +reproducirRespuestaVoz(texto: String) : void
	Future<void> reproducirRespuestaVoz(String texto) async {
		await widget.controlador.reproducirRespuestaVoz(texto);
	}

	/// Metodo oficial del UML: +actualizarVistaRespuesta(respuesta: String, fuente: String) : void
	void actualizarVistaRespuesta(String respuesta, String fuente) {
		if (mounted) {
			setState(() {});
		}
	}

	/// Metodo oficial del UML: +mostrarAvisoConsultarMaestro() : void (RF-03)
	void mostrarAvisoConsultarMaestro() {
		if (!mounted) {
			return;
		}
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(
				content: Text(Reglas.mensajeConsultaAlMaestro),
				backgroundColor: Paleta.verdeBosque,
			),
		);
	}

	void _desplazarAlFinal() {
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (_scroll.hasClients) {
				_scroll.animateTo(
					_scroll.position.maxScrollExtent,
					duration: const Duration(milliseconds: 300),
					curve: Curves.easeOut,
				);
			}
		});
	}

	@override
	Widget build(BuildContext context) {
		return ListenableBuilder(
			listenable: widget.controlador,
			builder: (BuildContext context, Widget? _) {
				final ControladorTutor c = widget.controlador;

				return Scaffold(
					drawer: MenuLateralGeografIA(controlador: c),
					body: _modoLlamadaVoz
						? VistaLlamadaVoz(
							controlador: c,
							alCerrar: () => setState(() {
								_modoLlamadaVoz = false;
							}),
						)
						: _construirModoChat(context, c),
				);
			},
		);
	}

	Widget _construirModoChat(BuildContext context, ControladorTutor c) {
		return Container(
			decoration: BoxDecoration(
				gradient: LinearGradient(
					begin: Alignment.topCenter,
					end: Alignment.bottomCenter,
					colors: c.configuracion.altoContraste
						? <Color>[Colors.white, const Color(0xFFF2F4F3)]
						: <Color>[
							Paleta.cremaFondo,
							Paleta.cremaTarjeta,
							const Color(0xFFE7EFEA),
						],
				),
			),
			child: SafeArea(
				child: Column(
					children: <Widget>[
						_construirBarraSuperior(context, c),
						Expanded(
							child: c.mensajes.isEmpty
								? _construirBienvenidaHero(context, c)
								: _construirListaConversacion(context, c),
						),
						if (c.estado == EstadoMascota.pensando)
							_construirIndicadorPensando(),
						_construirBarraInferiorEntrada(c),
					],
				),
			),
		);
	}

	/// Barra superior estilo imagen de referencia (avatar de esfera + grado + controles).
	Widget _construirBarraSuperior(BuildContext context, ControladorTutor c) {
		return Padding(
			padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
			child: Row(
				children: <Widget>[
					Builder(
						builder: (BuildContext ctx) => IconButton(
							tooltip: 'Temas y menú lateral',
							icon: const Icon(
								Icons.menu_rounded,
								size: 28,
								color: Paleta.verdeBosque,
							),
							onPressed: () => Scaffold.of(ctx).openDrawer(),
						),
					),
					const SizedBox(width: 4),
					// Mini avatar de la mascota (como en la esquina superior de la imagen)
					GestureDetector(
						onTap: () => setState(() {
							_modoLlamadaVoz = true;
						}),
						child: const Mascota(
							estado: EstadoMascota.reposo,
							tamano: 40,
							mostrarEtiqueta: false,
							mostrarOrejas: false,
						),
					),
					const SizedBox(width: 10),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: <Widget>[
								const Text(
									'Geograf-IA · SEP Offline',
									style: TextStyle(
										fontSize: 16,
										fontWeight: FontWeight.w800,
										color: Paleta.textoPrimario,
									),
								),
								Text(
									'100% sin internet · ${c.configuracion.gradoActual}° de primaria',
									style: const TextStyle(
										fontSize: 12,
										fontWeight: FontWeight.w600,
										color: Paleta.textoSecundario,
									),
								),
							],
						),
					),
					// Selector rapido de grado escolar (RF-08: 4°, 5°, 6°)
					Container(
						padding: const EdgeInsets.symmetric(
							horizontal: 6,
							vertical: 2,
						),
						decoration: BoxDecoration(
							color: Colors.white,
							borderRadius: BorderRadius.circular(20),
							border: Border.all(
								color: Paleta.verdeBosque.withValues(alpha: 0.2),
							),
						),
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: Reglas.gradosSoportados.map((int g) {
								final bool activo =
									c.configuracion.gradoActual == g;
								return InkWell(
									borderRadius: BorderRadius.circular(14),
									onTap: () => c.establecerGradoEscolar(g),
									child: Container(
										padding: const EdgeInsets.symmetric(
											horizontal: 9,
											vertical: 5,
										),
										decoration: BoxDecoration(
											color: activo
												? Paleta.verdeBosque
												: Colors.transparent,
											borderRadius: BorderRadius.circular(14),
										),
										child: Text(
											'$g°',
											style: TextStyle(
												fontSize: 13,
												fontWeight: FontWeight.w800,
												color: activo
													? Colors.white
													: Paleta.textoPrimario,
											),
										),
									),
								);
							}).toList(),
						),
					),
					const SizedBox(width: 6),
					// Boton para abrir el Modo Llamada de Voz (pantalla izquierda de la imagen)
					IconButton.filledTonal(
						tooltip: 'Modo llamada de voz',
						style: IconButton.styleFrom(
							backgroundColor: Paleta.esferaCeleste,
							foregroundColor: Paleta.verdeBosque,
						),
						onPressed: () => setState(() {
							_modoLlamadaVoz = true;
						}),
						icon: const Icon(Icons.record_voice_over_rounded),
					),
					IconButton(
						tooltip: 'Configuración y USB',
						icon: const Icon(
							Icons.settings_outlined,
							color: Paleta.textoPrimario,
						),
						onPressed: () => Navigator.of(context).push(
							MaterialPageRoute<void>(
								builder: (_) => PantallaConfiguracion(
									controlador: c,
								),
							),
						),
					),
				],
			),
		);
	}

	/// Vista hero inicial (6_DisenoUI.pdf pagina 5: "¡Hola! ¿Qué descubrimos hoy?" + Ideas).
	Widget _construirBienvenidaHero(BuildContext context, ControladorTutor c) {
		return SingleChildScrollView(
			padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
			child: Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 680),
					child: Column(
						children: <Widget>[
							const SizedBox(height: 8),
							GestureDetector(
								onTap: () => setState(() {
									_modoLlamadaVoz = true;
								}),
								child: Mascota(
									estado: c.estado,
									tamano: 135,
								),
							),
							const SizedBox(height: 16),
							Text(
								'¡Hola! ¿Qué descubrimos hoy?',
								textAlign: TextAlign.center,
								style: Theme.of(context).textTheme.headlineMedium,
							),
							const SizedBox(height: 6),
							Text(
								'Pregúntame con tu voz o toca una tarjeta. Todo sale de tu libro SEP de ${c.configuracion.gradoActual}° grado.',
								textAlign: TextAlign.center,
								style: const TextStyle(
									fontSize: 15,
									color: Paleta.textoSecundario,
								),
							),
							const SizedBox(height: 22),
							// Boton destacado para modo llamada de voz a pantalla completa
							FilledButton.tonalIcon(
								style: FilledButton.styleFrom(
									backgroundColor: Colors.white,
									foregroundColor: Paleta.verdeBosque,
									padding: const EdgeInsets.symmetric(
										horizontal: 20,
										vertical: 12,
									),
									shape: RoundedRectangleBorder(
										borderRadius: BorderRadius.circular(24),
										side: BorderSide(
											color: Paleta.verdeBosque
												.withValues(alpha: 0.25),
										),
									),
								),
								onPressed: () => setState(() {
									_modoLlamadaVoz = true;
								}),
								icon: const Icon(Icons.phone_in_talk_rounded),
								label: const Text(
									'Abrir Modo Llamada de Voz con la Mascota',
									style: TextStyle(fontWeight: FontWeight.w700),
								),
							),
							const SizedBox(height: 24),
							Row(
								children: <Widget>[
									const Text(
										'Ideas para explorar',
										style: TextStyle(
											fontSize: 16,
											fontWeight: FontWeight.w800,
											color: Paleta.verdeBosque,
										),
									),
									const SizedBox(width: 10),
									Expanded(
										child: Divider(
											color: Paleta.verdeBosque
												.withValues(alpha: 0.2),
										),
									),
								],
							),
							const SizedBox(height: 12),
							Wrap(
								spacing: 12,
								runSpacing: 12,
								children: Reglas.ideasParaExplorar.map(
									(Map<String, String> idea) {
										return SizedBox(
											width: 310,
											child: InkWell(
												borderRadius: BorderRadius.circular(18),
												onTap: c.ocupado
													? null
													: () => enviarPreguntaTexto(
														idea['pregunta'] ?? '',
													),
												child: Container(
													padding: const EdgeInsets.all(14),
													decoration: BoxDecoration(
														color: Colors.white,
														borderRadius:
															BorderRadius.circular(18),
														boxShadow: <BoxShadow>[
															BoxShadow(
																color: Colors.black
																	.withValues(alpha: 0.04),
																blurRadius: 10,
																offset: const Offset(0, 4),
															),
														],
													),
													child: Row(
														children: <Widget>[
															Container(
																width: 42,
																height: 42,
																decoration: BoxDecoration(
																	color: Paleta
																		.esferaCeleste,
																	borderRadius:
																		BorderRadius.circular(
																			12,
																		),
																),
																child: Icon(
																	_iconoIdea(
																		idea['icono'] ?? '',
																	),
																	color: Paleta.verdeBosque,
																),
															),
															const SizedBox(width: 12),
															Expanded(
																child: Column(
																	crossAxisAlignment:
																		CrossAxisAlignment
																			.start,
																	children: <Widget>[
																		Text(
																			idea['pregunta'] ??
																				'',
																			style: const TextStyle(
																				fontSize: 15,
																				fontWeight:
																					FontWeight
																						.w800,
																				color: Paleta
																					.textoPrimario,
																			),
																		),
																		const SizedBox(
																			height: 2,
																		),
																		Text(
																			idea['subtitulo'] ??
																				'',
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
									},
								).toList(),
							),
						],
					),
				),
			),
		);
	}

	IconData _iconoIdea(String clave) {
		switch (clave) {
			case 'volcano':
				return Icons.landscape_rounded;
			case 'cloud':
				return Icons.wb_cloudy_rounded;
			case 'waves':
				return Icons.waves_rounded;
			default:
				return Icons.public_rounded;
		}
	}

	/// Lista de mensajes estilo "Coach Voice Call" (derecha de la imagen) + citas SEP.
	Widget _construirListaConversacion(
		BuildContext context,
		ControladorTutor c,
	) {
		return ListView.builder(
			controller: _scroll,
			padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
			itemCount: c.mensajes.length,
			itemBuilder: (BuildContext context, int index) {
				final MensajeChat m = c.mensajes[index];
				if (m.rol == RolMensaje.retoPedagogico) {
					return _construirTarjetaReto(c, m);
				}
				final bool esAlumno = m.rol == RolMensaje.alumno;
				return Align(
					alignment: esAlumno
						? Alignment.centerRight
						: Alignment.centerLeft,
					child: Container(
						margin: const EdgeInsets.symmetric(vertical: 6),
						padding: const EdgeInsets.symmetric(
							horizontal: 18,
							vertical: 14,
						),
						constraints: const BoxConstraints(maxWidth: 540),
						decoration: BoxDecoration(
							color: esAlumno
								? Paleta.burbujaAlumno
								: (m.esRemisionMaestro
									? Paleta.alertaMaestro
									: Paleta.burbujaTutor),
							borderRadius: BorderRadius.only(
								topLeft: const Radius.circular(22),
								topRight: const Radius.circular(22),
								bottomLeft: Radius.circular(esAlumno ? 22 : 6),
								bottomRight: Radius.circular(esAlumno ? 6 : 22),
							),
							border: m.esRemisionMaestro
								? Border.all(color: Paleta.bordeAlerta, width: 1.5)
								: null,
							boxShadow: <BoxShadow>[
								BoxShadow(
									color: Colors.black.withValues(alpha: 0.04),
									blurRadius: 10,
									offset: const Offset(0, 3),
								),
							],
						),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: <Widget>[
								Text(
									m.texto,
									style: TextStyle(
										fontSize: c.configuracion.tamanoFuente
											.toDouble(),
										height: 1.4,
										color: esAlumno
											? Colors.white
											: Paleta.textoPrimario,
									),
								),
								// Ilustracion didactica del tema (6_DisenoUI.pdf pagina 5)
								if (!esAlumno && m.tipoIlustracion.isNotEmpty)
									TarjetaIlustracionDidactica(
										tipoIlustracion: m.tipoIlustracion,
										notaIlustracion: m.notaIlustracion,
									),
								// Pie de burbuja del tutor: cita oficial SEP (RF-10) + boton de voz (RF-04)
								if (!esAlumno) ...<Widget>[
									const SizedBox(height: 10),
									Wrap(
										spacing: 8,
										runSpacing: 6,
										crossAxisAlignment:
											WrapCrossAlignment.center,
										children: <Widget>[
											if (m.citaFuente.isNotEmpty)
												Container(
													padding:
														const EdgeInsets.symmetric(
															horizontal: 10,
															vertical: 4,
														),
													decoration: BoxDecoration(
														color: Paleta.esferaCeleste
															.withValues(alpha: 0.6),
														borderRadius:
															BorderRadius.circular(12),
													),
													child: Text(
														'📖 ${m.citaFuente}',
														style: const TextStyle(
															fontSize: 12.5,
															fontWeight:
																FontWeight.w700,
															color: Paleta.verdeBosque,
														),
													),
												),
											if (m.tiempoMs > 0)
												Text(
													'⚡ ${(m.tiempoMs / 1000).toStringAsFixed(1)} s',
													style: const TextStyle(
														fontSize: 12,
														color: Paleta.textoSecundario,
													),
												),
											TextButton.icon(
												style: TextButton.styleFrom(
													padding:
														const EdgeInsets.symmetric(
															horizontal: 10,
															vertical: 4,
														),
													minimumSize: Size.zero,
													tapTargetSize:
														MaterialTapTargetSize
															.shrinkWrap,
												),
												onPressed: () =>
													reproducirRespuestaVoz(m.texto),
												icon: const Icon(
													Icons.volume_up_rounded,
													size: 18,
												),
												label: const Text('Escuchar'),
											),
										],
									),
								],
							],
						),
					),
				);
			},
		);
	}

	/// Tarjeta de comprobacion pedagogica (Objetivo General - Equipo6_App_Greograf-ia.pdf).
	Widget _construirTarjetaReto(ControladorTutor c, MensajeChat m) {
		final bool respondido = m.opcionSeleccionadaReto != null;
		final bool acerto =
			respondido && m.opcionSeleccionadaReto == m.indiceCorrectoReto;

		return Container(
			margin: const EdgeInsets.symmetric(vertical: 8),
			padding: const EdgeInsets.all(16),
			decoration: BoxDecoration(
				color: const Color(0xFFF3F8E8),
				borderRadius: BorderRadius.circular(20),
				border: Border.all(
					color: Paleta.verdeBosque.withValues(alpha: 0.3),
				),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: <Widget>[
					Row(
						children: <Widget>[
							const Icon(
								Icons.stars_rounded,
								color: Paleta.verdeBosque,
							),
							const SizedBox(width: 8),
							Expanded(
								child: Text(
									m.texto,
									style: const TextStyle(
										fontWeight: FontWeight.w800,
										color: Paleta.verdeBosque,
										fontSize: 15,
									),
								),
							),
						],
					),
					const SizedBox(height: 8),
					Text(
						m.preguntaReto,
						style: const TextStyle(
							fontSize: 16.5,
							fontWeight: FontWeight.w700,
							color: Paleta.textoPrimario,
						),
					),
					const SizedBox(height: 10),
					Wrap(
						spacing: 8,
						runSpacing: 8,
						children: List<Widget>.generate(
							m.opcionesReto.length,
							(int idx) {
								final bool elegida =
									m.opcionSeleccionadaReto == idx;
								final bool esCorrecta =
									idx == m.indiceCorrectoReto;
								Color colorFondo = Colors.white;
								if (respondido && esCorrecta) {
									colorFondo = Paleta.verdeLima;
								} else if (respondido && elegida && !esCorrecta) {
									colorFondo = const Color(0xFFFADBD8);
								}
								return ChoiceChip(
									label: Text(m.opcionesReto[idx]),
									selected: elegida,
									selectedColor: colorFondo,
									backgroundColor: colorFondo,
									onSelected: respondido
										? null
										: (_) => c.responderRetoPedagogico(
											m.id,
											idx,
										),
								);
							},
						),
					),
					if (respondido) ...<Widget>[
						const SizedBox(height: 8),
						Text(
							acerto
								? '¡Muy bien! Comprendiste el tema del libro SEP.'
								: '¡Casi! Revisa la explicación de arriba y vuelve a intentarlo.',
							style: TextStyle(
								fontWeight: FontWeight.w700,
								color: acerto
									? Paleta.verdeBosque
									: const Color(0xFFB03A2E),
							),
						),
					],
				],
			),
		);
	}

	/// Burbuja "..." de pensamiento identica a la parte inferior de la imagen subida.
	Widget _construirIndicadorPensando() {
		return Align(
			alignment: Alignment.centerLeft,
			child: Container(
				margin: const EdgeInsets.only(left: 18, bottom: 6),
				padding: const EdgeInsets.symmetric(
					horizontal: 16,
					vertical: 10,
				),
				decoration: BoxDecoration(
					color: Colors.white,
					borderRadius: BorderRadius.circular(20),
				),
				child: const Text(
					'• • •   Buscando en tu libro SEP…',
					style: TextStyle(
						fontWeight: FontWeight.w700,
						color: Paleta.textoSecundario,
					),
				),
			),
		);
	}

	/// Barra inferior que une el boton verde "Hablar" (6_DisenoUI.pdf) y la
	/// capsula limpia de texto ("+ Escribe tu pregunta" de la imagen de referencia).
	Widget _construirBarraInferiorEntrada(ControladorTutor c) {
		return Container(
			padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
			child: Container(
				padding: const EdgeInsets.all(8),
				decoration: BoxDecoration(
					color: const Color(0xFFEAE6DC),
					borderRadius: BorderRadius.circular(28),
				),
				child: Row(
					children: <Widget>[
						// Boton Hablar (6_DisenoUI.pdf)
						FilledButton.icon(
							style: FilledButton.styleFrom(
								backgroundColor: _estaGrabando
									? const Color(0xFFC0392B)
									: Paleta.verdeBoton,
								foregroundColor: Colors.white,
								minimumSize: const Size(112, 48),
								shape: RoundedRectangleBorder(
									borderRadius: BorderRadius.circular(20),
								),
							),
							onPressed: c.ocupado ? null : alPresionarMicrofono,
							icon: Icon(
								_estaGrabando
									? Icons.graphic_eq_rounded
									: Icons.mic_rounded,
							),
							label: Text(
								_estaGrabando ? 'Oído…' : 'Hablar',
								style: const TextStyle(
									fontSize: 15.5,
									fontWeight: FontWeight.w800,
								),
							),
						),
						const SizedBox(width: 8),
						// Campo de texto redondeado blanco
						Expanded(
							child: Container(
								padding: const EdgeInsets.symmetric(
									horizontal: 14,
								),
								decoration: BoxDecoration(
									color: Colors.white,
									borderRadius: BorderRadius.circular(24),
								),
								child: Row(
									children: <Widget>[
										Expanded(
											child: TextField(
												controller: _campoTexto,
												enabled: !c.ocupado,
												maxLength:
													Reglas.maxCaracteresPregunta,
												onSubmitted: enviarPreguntaTexto,
												decoration: const InputDecoration(
													counterText: '',
													hintText:
														'¿Qué quieres descubrir?',
													border: InputBorder.none,
												),
											),
										),
										FilledButton(
											style: FilledButton.styleFrom(
												backgroundColor:
													Paleta.verdeBoton,
												foregroundColor: Colors.white,
												padding:
													const EdgeInsets.symmetric(
														horizontal: 16,
														vertical: 10,
													),
												minimumSize: Size.zero,
												shape: RoundedRectangleBorder(
													borderRadius:
														BorderRadius.circular(18),
												),
											),
											onPressed: c.ocupado
												? null
												: () => enviarPreguntaTexto(
													_campoTexto.text,
												),
											child: const Text(
												'enviar',
												style: TextStyle(
													fontWeight: FontWeight.w800,
												),
											),
										),
									],
								),
							),
						),
					],
				),
			),
		);
	}
}
