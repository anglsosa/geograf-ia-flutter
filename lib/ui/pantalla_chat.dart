import 'package:flutter/material.dart';

import '../controllers/controlador_tutor.dart';
import '../core/reglas.dart';
import '../core/tema.dart';
import '../models/modelos.dart';
import '../services/servicios.dart';
import 'mascota.dart';
import 'menu_lateral.dart';
import 'pantalla_configuracion.dart';
import 'vista_llamada_voz.dart';

/// ActividadChat (9_UML.pdf) - Pantalla principal responsiva nino-tutor.
/// Se adapta automaticamente a telefonos pequenos y tablets, manteniendo
/// siempre visible el ultimo mensaje de la conversacion.
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
	void iniciar() {}

	/// Metodo oficial del UML: +enviarPreguntaTexto(texto: String) : void
	Future<void> enviarPreguntaTexto(String texto) async {
		final String limpio = texto.trim();
		if (limpio.isEmpty) {
			return;
		}
		_campoTexto.clear();
		FocusScope.of(context).unfocus();
		_irAlUltimoMensaje();
		await widget.controlador.enviarPregunta(limpio);
		_irAlUltimoMensaje();
	}

	/// Metodo oficial del UML: +alPresionarMicrofono() : void
	/// Primer toque: escucha. Segundo toque mientras escucha: termina y envia.
	Future<void> alPresionarMicrofono() async {
		final ControladorTutor c = widget.controlador;
		if (c.estado == EstadoMascota.escuchando) {
			await c.detenerEscucha();
			return;
		}
		_irAlUltimoMensaje();
		await c.preguntarPorVoz();
		_irAlUltimoMensaje();
		if (mounted && c.errorVoz.isNotEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(c.errorVoz),
					behavior: SnackBarBehavior.floating,
					duration: const Duration(seconds: 6),
				),
			);
			c.limpiarErrorVoz();
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

	/// Con reverse: true en el ListView, la posicion 0.0 es siempre el ultimo mensaje.
	void _irAlUltimoMensaje() {
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (_scroll.hasClients) {
				_scroll.animateTo(
					0.0,
					duration: const Duration(milliseconds: 250),
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
						? <Color>[Colors.white, const Color(0xFFF4F6F5)]
						: <Color>[
							Paleta.cremaFondo,
							Paleta.cremaTarjeta,
							Paleta.salviaSuave,
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
						_construirAvisoModelo(context, c),
						if (c.estado == EstadoMascota.escuchando)
							_construirIndicadorEscucha(c),
						if (c.estado == EstadoMascota.pensando)
							_construirIndicadorPensando(),
						_construirBarraInferiorEntrada(context, c),
					],
				),
			),
		);
	}

	/// Botones "me quedo clara" / "no entendi" de una respuesta ya guardada.
	List<Widget> _botonesValoracion(ControladorTutor c, MensajeChat m) {
		Widget boton(bool valor, IconData icono, String ayuda) {
			final bool elegido = m.quedoClara == valor;
			return Tooltip(
				message: ayuda,
				child: InkWell(
					borderRadius: BorderRadius.circular(10),
					onTap: () => c.valorarRespuesta(m.id, valor),
					child: Padding(
						padding: const EdgeInsets.all(4),
						child: Icon(
							icono,
							size: 18,
							color: elegido ? Paleta.verdeBosque : Paleta.textoSecundario,
						),
					),
				),
			);
		}

		return <Widget>[
			boton(
				true,
				m.quedoClara == true
					? Icons.thumb_up_alt_rounded
					: Icons.thumb_up_off_alt_rounded,
				'Me quedó clara',
			),
			boton(
				false,
				m.quedoClara == false
					? Icons.thumb_down_alt_rounded
					: Icons.thumb_down_off_alt_rounded,
				'No entendí',
			),
		];
	}

	/// Muestra en vivo lo que el microfono va entendiendo.
	Widget _construirIndicadorEscucha(ControladorTutor c) {
		final String parcial = c.textoVozParcial;
		return Container(
			width: double.infinity,
			margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
			decoration: BoxDecoration(
				color: const Color(0xFFFCEDEA),
				borderRadius: BorderRadius.circular(12),
				border: Border.all(color: const Color(0xFFE8B4AC)),
			),
			child: Row(
				children: <Widget>[
					const Icon(
						Icons.mic_rounded,
						size: 18,
						color: Color(0xFFC0392B),
					),
					const SizedBox(width: 8),
					Expanded(
						child: Text(
							parcial.isEmpty
								? 'Te escucho… habla y toca "Listo" al terminar'
								: '“$parcial”',
							maxLines: 2,
							overflow: TextOverflow.ellipsis,
							style: const TextStyle(
								fontSize: 13,
								fontWeight: FontWeight.w600,
								color: Paleta.textoPrimario,
							),
						),
					),
				],
			),
		);
	}

	/// Aviso discreto sobre el estado del modelo de IA (solo si no esta listo).
	Widget _construirAvisoModelo(BuildContext context, ControladorTutor c) {
		final MotorLLMLocal motor = c.pipelineRAG.motorLLM;
		String texto = '';
		IconData icono = Icons.info_outline_rounded;
		switch (motor.estado) {
			case EstadoModelo.listo:
				return const SizedBox.shrink();
			case EstadoModelo.cargando:
			case EstadoModelo.instalado:
				texto = 'Despertando al tutor de IA… mientras tanto respondo con el libro.';
				icono = Icons.hourglass_top_rounded;
			case EstadoModelo.descargando:
				texto =
					'Descargando el modelo de IA: ${(motor.progresoDescarga * 100).round()}%';
				icono = Icons.downloading_rounded;
			case EstadoModelo.noInstalado:
			case EstadoModelo.error:
				if (!MotorLLMLocal.plataformaSoportada) {
					return const SizedBox.shrink();
				}
				texto =
					'Modo básico: respondo con el texto del libro. Instala el modelo de IA en Configuración.';
		}
		return Container(
			width: double.infinity,
			margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
			decoration: BoxDecoration(
				color: Paleta.cremaTarjeta,
				borderRadius: BorderRadius.circular(12),
				border: Border.all(color: Paleta.bordeSuave),
			),
			child: Row(
				children: <Widget>[
					Icon(icono, size: 16, color: Paleta.verdeBosque),
					const SizedBox(width: 8),
					Expanded(
						child: Text(
							texto,
							style: const TextStyle(
								fontSize: 11.5,
								fontWeight: FontWeight.w600,
								color: Paleta.textoSecundario,
							),
						),
					),
				],
			),
		);
	}

	/// Barra superior responsiva: nunca parte el titulo en varias lineas.
	Widget _construirBarraSuperior(BuildContext context, ControladorTutor c) {
		return Padding(
			padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
			child: Row(
				children: <Widget>[
					Builder(
						builder: (BuildContext ctx) => IconButton(
							tooltip: 'Temas y menú',
							visualDensity: VisualDensity.compact,
							icon: const Icon(
								Icons.menu_rounded,
								size: 24,
								color: Paleta.textoPrimario,
							),
							onPressed: () => Scaffold.of(ctx).openDrawer(),
						),
					),
					GestureDetector(
						onTap: () => setState(() {
							_modoLlamadaVoz = true;
						}),
						child: const Mascota(
							estado: EstadoMascota.reposo,
							tamano: 32,
							mostrarEtiqueta: false,
							mostrarOrejas: false,
						),
					),
					const SizedBox(width: 8),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							mainAxisSize: MainAxisSize.min,
							children: <Widget>[
								const Text(
									'Geograf-IA',
									maxLines: 1,
									overflow: TextOverflow.ellipsis,
									style: TextStyle(
										fontSize: 15.5,
										fontWeight: FontWeight.w800,
										color: Paleta.textoPrimario,
										letterSpacing: -0.3,
									),
								),
								Text(
									'Offline · SEP ${c.configuracion.gradoActual}° primaria',
									maxLines: 1,
									overflow: TextOverflow.ellipsis,
									style: const TextStyle(
										fontSize: 11,
										fontWeight: FontWeight.w600,
										color: Paleta.textoSecundario,
									),
								),
							],
						),
					),
					// Selector compacto de grado escolar (RF-08: 4°, 5°, 6°)
					Container(
						padding: const EdgeInsets.all(2),
						decoration: BoxDecoration(
							color: Colors.white,
							borderRadius: BorderRadius.circular(16),
							border: Border.all(color: Paleta.bordeSuave),
						),
						child: Row(
							mainAxisSize: MainAxisSize.min,
							children: Reglas.gradosSoportados.map((int g) {
								final bool activo =
									c.configuracion.gradoActual == g;
								return InkWell(
									borderRadius: BorderRadius.circular(12),
									onTap: () => c.establecerGradoEscolar(g),
									child: Container(
										padding: const EdgeInsets.symmetric(
											horizontal: 7,
											vertical: 4,
										),
										decoration: BoxDecoration(
											color: activo
												? Paleta.verdeBosque
												: Colors.transparent,
											borderRadius:
												BorderRadius.circular(12),
										),
										child: Text(
											'$g°',
											style: TextStyle(
												fontSize: 12,
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
					const SizedBox(width: 4),
					IconButton(
						tooltip: 'Modo llamada de voz',
						visualDensity: VisualDensity.compact,
						style: IconButton.styleFrom(
							backgroundColor: Paleta.esferaCeleste,
							foregroundColor: Paleta.verdeBosque,
						),
						onPressed: () => setState(() {
							_modoLlamadaVoz = true;
						}),
						icon: const Icon(
							Icons.record_voice_over_rounded,
							size: 18,
						),
					),
					IconButton(
						tooltip: 'Configuración y USB',
						visualDensity: VisualDensity.compact,
						icon: const Icon(
							Icons.settings_outlined,
							size: 21,
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

	/// Vista hero inicial responsiva para telefonos pequenos y tablets.
	Widget _construirBienvenidaHero(BuildContext context, ControladorTutor c) {
		return LayoutBuilder(
			builder: (BuildContext context, BoxConstraints bc) {
				final bool esCompacto = bc.maxWidth < 390 || bc.maxHeight < 620;
				final double tamMascota = esCompacto ? 96.0 : 120.0;

				return SingleChildScrollView(
					padding: const EdgeInsets.symmetric(
						horizontal: 16,
						vertical: 8,
					),
					child: Center(
						child: ConstrainedBox(
							constraints: const BoxConstraints(maxWidth: 600),
							child: Column(
								children: <Widget>[
									GestureDetector(
										onTap: () => setState(() {
											_modoLlamadaVoz = true;
										}),
										child: Mascota(
											estado: c.estado,
											tamano: tamMascota,
										),
									),
									const SizedBox(height: 10),
									Text(
										'¡Hola! ¿Qué descubrimos hoy?',
										textAlign: TextAlign.center,
										style: TextStyle(
											fontSize: esCompacto ? 20 : 23,
											fontWeight: FontWeight.w800,
											color: Paleta.textoPrimario,
											letterSpacing: -0.4,
										),
									),
									const SizedBox(height: 4),
									Text(
										'Pregúntame con tu voz o toca una idea. Todo sale de tu libro SEP de ${c.configuracion.gradoActual}° grado.',
										textAlign: TextAlign.center,
										style: const TextStyle(
											fontSize: 13.5,
											color: Paleta.textoSecundario,
											height: 1.3,
										),
									),
									const SizedBox(height: 12),
									// Boton compacto para abrir el Modo Llamada de Voz
									OutlinedButton.icon(
										style: OutlinedButton.styleFrom(
											backgroundColor: Colors.white,
											foregroundColor: Paleta.verdeBosque,
											side: const BorderSide(
												color: Paleta.bordeSuave,
											),
											padding: const EdgeInsets.symmetric(
												horizontal: 14,
												vertical: 9,
											),
											shape: RoundedRectangleBorder(
												borderRadius:
													BorderRadius.circular(20),
											),
										),
										onPressed: () => setState(() {
											_modoLlamadaVoz = true;
										}),
										icon: const Icon(
											Icons.phone_in_talk_rounded,
											size: 17,
										),
										label: const Text(
											'Modo Llamada de Voz con Mascota',
											style: TextStyle(
												fontSize: 13,
												fontWeight: FontWeight.w700,
											),
										),
									),
									const SizedBox(height: 16),
									Row(
										children: <Widget>[
											const Text(
												'Ideas para explorar',
												style: TextStyle(
													fontSize: 13.5,
													fontWeight: FontWeight.w800,
													color: Paleta.verdeBosque,
												),
											),
											const SizedBox(width: 8),
											const Expanded(
												child: Divider(
													color: Paleta.bordeSuave,
												),
											),
										],
									),
									const SizedBox(height: 8),
									...Reglas.ideasParaExplorar.map(
										(Map<String, String> idea) => Padding(
											padding: const EdgeInsets.only(
												bottom: 8,
											),
											child: InkWell(
												borderRadius:
													BorderRadius.circular(16),
												onTap: c.ocupado
													? null
													: () => enviarPreguntaTexto(
														idea['pregunta'] ?? '',
													),
												child: Container(
													padding:
														const EdgeInsets
															.symmetric(
																horizontal: 12,
																vertical: 10,
															),
													decoration: BoxDecoration(
														color: Colors.white,
														borderRadius:
															BorderRadius
																.circular(16),
														border: Border.all(
															color: Paleta
																.bordeSuave,
														),
													),
													child: Row(
														children: <Widget>[
															Container(
																width: 36,
																height: 36,
																decoration:
																	BoxDecoration(
																		color: Paleta
																			.esferaCeleste,
																		borderRadius:
																			BorderRadius
																				.circular(
																					10,
																				),
																	),
																child: Icon(
																	_iconoIdea(
																		idea['icono'] ??
																			'',
																	),
																	size: 19,
																	color: Paleta
																		.verdeBosque,
																),
															),
															const SizedBox(
																width: 10,
															),
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
																				fontSize:
																					14,
																				fontWeight:
																					FontWeight
																						.w700,
																				color: Paleta
																					.textoPrimario,
																			),
																		),
																		Text(
																			idea['subtitulo'] ??
																				'',
																			style: const TextStyle(
																				fontSize:
																					12,
																				color: Paleta
																					.textoSecundario,
																			),
																		),
																	],
																),
															),
															const Icon(
																Icons
																	.arrow_forward_ios_rounded,
																size: 14,
																color: Paleta
																	.textoSecundario,
															),
														],
													),
												),
											),
										),
									),
								],
							),
						),
					),
				);
			},
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

	/// Lista de conversacion con reverse: true para que SIEMPRE muestre el
	/// ultimo mensaje abajo sin necesidad de hacer scroll manual.
	Widget _construirListaConversacion(
		BuildContext context,
		ControladorTutor c,
	) {
		final int total = c.mensajes.length;
		return ListView.builder(
			controller: _scroll,
			reverse: true,
			padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
			itemCount: total,
			itemBuilder: (BuildContext context, int reversoIndex) {
				final MensajeChat m = c.mensajes[total - 1 - reversoIndex];
				if (m.rol == RolMensaje.retoPedagogico) {
					return _construirTarjetaReto(c, m);
				}
				final bool esAlumno = m.rol == RolMensaje.alumno;
				return Align(
					alignment: esAlumno
						? Alignment.centerRight
						: Alignment.centerLeft,
					child: Container(
						margin: const EdgeInsets.symmetric(vertical: 5),
						padding: const EdgeInsets.symmetric(
							horizontal: 14,
							vertical: 11,
						),
						constraints: BoxConstraints(
							maxWidth:
								MediaQuery.sizeOf(context).width * 0.86,
						),
						decoration: BoxDecoration(
							color: esAlumno
								? Paleta.burbujaAlumno
								: (m.esRemisionMaestro
									? Paleta.alertaMaestro
									: Paleta.burbujaTutor),
							borderRadius: BorderRadius.only(
								topLeft: const Radius.circular(18),
								topRight: const Radius.circular(18),
								bottomLeft: Radius.circular(esAlumno ? 18 : 5),
								bottomRight: Radius.circular(esAlumno ? 5 : 18),
							),
							border: m.esRemisionMaestro
								? Border.all(
									color: Paleta.bordeAlerta,
									width: 1.2,
								)
								: Border.all(
									color: esAlumno
										? Colors.transparent
										: Paleta.bordeSuave,
								),
						),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: <Widget>[
								Text(
									m.texto,
									style: TextStyle(
										fontSize: c.configuracion.tamanoFuente
											.toDouble(),
										height: 1.38,
										color: esAlumno
											? Colors.white
											: Paleta.textoPrimario,
									),
								),
								if (!esAlumno && m.tipoIlustracion.isNotEmpty)
									TarjetaIlustracionDidactica(
										tipoIlustracion: m.tipoIlustracion,
										notaIlustracion: m.notaIlustracion,
									),
								if (!esAlumno && !m.enProgreso) ...<Widget>[
									const SizedBox(height: 8),
									Wrap(
										spacing: 6,
										runSpacing: 4,
										crossAxisAlignment:
											WrapCrossAlignment.center,
										children: <Widget>[
											if (m.citaFuente.isNotEmpty)
												Container(
													padding:
														const EdgeInsets
															.symmetric(
																horizontal: 8,
																vertical: 3,
															),
													decoration: BoxDecoration(
														color: Paleta
															.esferaCeleste
															.withValues(
																alpha: 0.65,
															),
														borderRadius:
															BorderRadius
																.circular(10),
													),
													child: Text(
														'📖 ${m.citaFuente}',
														style: const TextStyle(
															fontSize: 11.5,
															fontWeight:
																FontWeight.w700,
															color: Paleta
																.verdeBosque,
														),
													),
												),
											if (!m.esRemisionMaestro && m.citaFuente.isNotEmpty)
												Text(
													m.generadoPorIA
														? '🤖 IA local'
														: '📚 Modo básico',
													style: const TextStyle(
														fontSize: 11,
														fontWeight: FontWeight.w700,
														color: Paleta
															.textoSecundario,
													),
												),
											if (m.tiempoMs > 0)
												Text(
													'⚡ ${(m.tiempoMs / 1000).toStringAsFixed(1)} s',
													style: const TextStyle(
														fontSize: 11,
														color: Paleta
															.textoSecundario,
													),
												),
											// El nino indica si le quedo clara la respuesta (se guarda en la base de datos)
											if (m.idConsulta != null) ..._botonesValoracion(c, m),
											InkWell(
												borderRadius:
													BorderRadius.circular(10),
												onTap: () =>
													reproducirRespuestaVoz(
														m.texto,
													),
												child: const Padding(
													padding:
														EdgeInsets.symmetric(
															horizontal: 6,
															vertical: 2,
														),
													child: Row(
														mainAxisSize:
															MainAxisSize.min,
														children: <Widget>[
															Icon(
																Icons
																	.volume_up_rounded,
																size: 16,
																color: Paleta
																	.verdeBosque,
															),
															SizedBox(width: 4),
															Text(
																'Escuchar',
																style:
																	TextStyle(
																		fontSize:
																			12,
																		fontWeight:
																			FontWeight
																				.w700,
																		color: Paleta
																			.verdeBosque,
																	),
															),
														],
													),
												),
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

	/// Tarjeta de comprobacion pedagogica compacta y amigable.
	Widget _construirTarjetaReto(ControladorTutor c, MensajeChat m) {
		final bool respondido = m.opcionSeleccionadaReto != null;
		final bool acerto =
			respondido && m.opcionSeleccionadaReto == m.indiceCorrectoReto;

		return Container(
			margin: const EdgeInsets.symmetric(vertical: 6),
			padding: const EdgeInsets.all(14),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(18),
				border: Border.all(color: Paleta.bordeSuave),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: <Widget>[
					Row(
						children: <Widget>[
							const Icon(
								Icons.stars_rounded,
								size: 18,
								color: Paleta.verdeBosque,
							),
							const SizedBox(width: 6),
							Expanded(
								child: Text(
									m.texto,
									style: const TextStyle(
										fontWeight: FontWeight.w800,
										color: Paleta.verdeBosque,
										fontSize: 13.5,
									),
								),
							),
						],
					),
					const SizedBox(height: 6),
					Text(
						m.preguntaReto,
						style: const TextStyle(
							fontSize: 14.5,
							fontWeight: FontWeight.w700,
							color: Paleta.textoPrimario,
						),
					),
					const SizedBox(height: 8),
					Wrap(
						spacing: 6,
						runSpacing: 6,
						children: List<Widget>.generate(
							m.opcionesReto.length,
							(int idx) {
								final bool elegida =
									m.opcionSeleccionadaReto == idx;
								final bool esCorrecta =
									idx == m.indiceCorrectoReto;
								Color colorFondo = Paleta.cremaTarjeta;
								if (respondido && esCorrecta) {
									colorFondo = Paleta.verdeLima;
								} else if (respondido &&
									elegida &&
									!esCorrecta) {
									colorFondo = const Color(0xFFFADBD8);
								}
								return ChoiceChip(
									label: Text(
										m.opcionesReto[idx],
										style: const TextStyle(fontSize: 13),
									),
									selected: elegida,
									selectedColor: colorFondo,
									backgroundColor: colorFondo,
									onSelected: respondido
										? null
										: (_) {
											c.responderRetoPedagogico(
												m.id,
												idx,
											);
											_irAlUltimoMensaje();
										},
								);
							},
						),
					),
					if (respondido) ...<Widget>[
						const SizedBox(height: 6),
						Text(
							acerto
								? '¡Muy bien! Comprendiste el tema del libro SEP.'
								: '¡Casi! Revisa la explicación de arriba.',
							style: TextStyle(
								fontSize: 12.5,
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

	Widget _construirIndicadorPensando() {
		return Align(
			alignment: Alignment.centerLeft,
			child: Container(
				margin: const EdgeInsets.only(left: 16, bottom: 6),
				padding: const EdgeInsets.symmetric(
					horizontal: 14,
					vertical: 8,
				),
				decoration: BoxDecoration(
					color: Colors.white,
					borderRadius: BorderRadius.circular(18),
					border: Border.all(color: Paleta.bordeSuave),
				),
				child: const Text(
					'• • •  Buscando en tu libro SEP…',
					style: TextStyle(
						fontSize: 13,
						fontWeight: FontWeight.w700,
						color: Paleta.textoSecundario,
					),
				),
			),
		);
	}

	/// Barra inferior responsiva: nunca corta el placeholder en pantallas chicas.
	Widget _construirBarraInferiorEntrada(
		BuildContext context,
		ControladorTutor c,
	) {
		final bool pantallaAngosta = MediaQuery.sizeOf(context).width < 360;

		return Padding(
			padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
			child: Row(
				children: <Widget>[
					// Boton Hablar compacto y amigable
					FilledButton.icon(
						style: FilledButton.styleFrom(
							backgroundColor: c.estado == EstadoMascota.escuchando
								? const Color(0xFFC0392B)
								: Paleta.verdeBoton,
							foregroundColor: Colors.white,
							padding: EdgeInsets.symmetric(
								horizontal: pantallaAngosta ? 10 : 14,
								vertical: 12,
							),
							minimumSize: Size.zero,
							shape: RoundedRectangleBorder(
								borderRadius: BorderRadius.circular(22),
							),
						),
						onPressed: c.ocupado ? null : alPresionarMicrofono,
						icon: Icon(
							c.estado == EstadoMascota.escuchando
								? Icons.graphic_eq_rounded
								: Icons.mic_rounded,
							size: 19,
						),
						label: Text(
							c.estado == EstadoMascota.escuchando ? 'Listo' : 'Hablar',
							style: const TextStyle(
								fontSize: 13.5,
								fontWeight: FontWeight.w700,
							),
						),
					),
					const SizedBox(width: 8),
					// Capsula blanca de texto con boton circular de envio
					Expanded(
						child: Container(
							padding: const EdgeInsets.only(left: 14, right: 4),
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(24),
								border: Border.all(color: Paleta.bordeSuave),
							),
							child: Row(
								children: <Widget>[
									Expanded(
										child: TextField(
											controller: _campoTexto,
											enabled: !c.ocupado,
											maxLength:
												Reglas.maxCaracteresPregunta,
											style: const TextStyle(
												fontSize: 14,
											),
											onSubmitted: enviarPreguntaTexto,
											decoration: const InputDecoration(
												isDense: true,
												contentPadding:
													EdgeInsets.symmetric(
														vertical: 10,
													),
												counterText: '',
												hintText:
													'¿Qué quieres descubrir?',
												hintStyle: TextStyle(
													fontSize: 13.5,
													color:
														Paleta.textoSecundario,
												),
												border: InputBorder.none,
											),
										),
									),
									IconButton(
										tooltip: 'Enviar pregunta',
										visualDensity: VisualDensity.compact,
										style: IconButton.styleFrom(
											backgroundColor: Paleta.verdeBoton,
											foregroundColor: Colors.white,
										),
										onPressed: c.ocupado
											? null
											: () => enviarPreguntaTexto(
												_campoTexto.text,
											),
										icon: const Icon(
											Icons.arrow_upward_rounded,
											size: 18,
										),
									),
								],
							),
						),
					),
				],
			),
		);
	}
}
