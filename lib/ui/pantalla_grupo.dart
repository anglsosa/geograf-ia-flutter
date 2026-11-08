import 'package:flutter/material.dart';

import '../controllers/controlador_tutor.dart';
import '../core/tema.dart';
import '../models/entidades_db.dart';

/// Pantalla "Grupo y avance": caso de uso para gestionar el grupo y sus alumnos
/// (RF-06, RF-09) y consultar los indicadores guardados en la base de datos.
///
/// Los alumnos NO tienen nombre: solo un codigo anonimo (RNF-10).
class PantallaGrupo extends StatefulWidget {
	const PantallaGrupo({super.key, required this.controlador});

	final ControladorTutor controlador;

	@override
	State<PantallaGrupo> createState() => _PantallaGrupoState();
}

class _PantallaGrupoState extends State<PantallaGrupo> {
	late Future<ResumenEstadisticas> _futuroEstadisticas;
	late Future<List<RegistroActualizacionUsb>> _futuroUsb;
	bool _soloAlumno = false;

	@override
	void initState() {
		super.initState();
		_futuroEstadisticas = widget.controlador.cargarEstadisticas();
		_futuroUsb = widget.controlador.historialActualizacionesUsb();
	}

	void _recargar() {
		if (!mounted) {
			return;
		}
		setState(() {
			if (widget.controlador.alumnoActivo == null) {
				_soloAlumno = false;
			}
			_futuroEstadisticas = widget.controlador.cargarEstadisticas(
				soloAlumno: _soloAlumno,
			);
			_futuroUsb = widget.controlador.historialActualizacionesUsb();
		});
	}

	Future<void> _nuevoGrupo() async {
		final TextEditingController campo = TextEditingController();
		final String? nombre = await showDialog<String>(
			context: context,
			builder: (BuildContext ctx) => AlertDialog(
				title: const Text('Nuevo grupo'),
				content: TextField(
					controller: campo,
					autofocus: true,
					maxLength: 30,
					decoration: const InputDecoration(
						hintText: 'Por ejemplo: 5° A',
						helperText: 'Escribe solo el nombre del grupo, no de los niños.',
					),
				),
				actions: <Widget>[
					TextButton(
						onPressed: () => Navigator.of(ctx).pop(),
						child: const Text('Cancelar'),
					),
					FilledButton(
						onPressed: () => Navigator.of(ctx).pop(campo.text.trim()),
						child: const Text('Crear'),
					),
				],
			),
		);
		campo.dispose();
		if (nombre == null || nombre.isEmpty) {
			return;
		}
		await widget.controlador.crearGrupo(nombre);
		_recargar();
	}

	String _fecha(DateTime d) {
		String dos(int n) => n.toString().padLeft(2, '0');
		return '${dos(d.day)}/${dos(d.month)}/${d.year} ${dos(d.hour)}:${dos(d.minute)}';
	}

	String _porcentaje(double? valor) =>
		valor == null ? '—' : '${valor.toStringAsFixed(0)} %';

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			body: Container(
				decoration: const BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: <Color>[
							Paleta.cremaFondo,
							Paleta.cremaTarjeta,
							Paleta.salviaSuave,
						],
					),
				),
				child: SafeArea(
					child: ListenableBuilder(
						listenable: widget.controlador,
						builder: (BuildContext context, Widget? _) {
							return Column(
								children: <Widget>[
									_encabezado(context),
									Expanded(
										child: ListView(
											padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
											children: widget.controlador.hayBaseDatos
												? <Widget>[
													_tarjetaGrupos(),
													const SizedBox(height: 12),
													_tarjetaAlumnos(),
													const SizedBox(height: 12),
													_tarjetaAvance(),
													const SizedBox(height: 12),
													_tarjetaBase(),
												]
												: <Widget>[_tarjetaSinBase()],
										),
									),
								],
							);
						},
					),
				),
			),
		);
	}

	Widget _encabezado(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
			child: Row(
				children: <Widget>[
					IconButton(
						tooltip: 'Volver',
						onPressed: () => Navigator.of(context).pop(),
						icon: const Icon(
							Icons.arrow_back_rounded,
							color: Paleta.textoPrimario,
						),
					),
					const Expanded(
						child: Text(
							'Grupo y avance',
							style: TextStyle(
								fontSize: 20,
								fontWeight: FontWeight.w800,
								color: Paleta.textoPrimario,
							),
						),
					),
				],
			),
		);
	}

	Widget _tarjeta({
		required String titulo,
		required IconData icono,
		required List<Widget> hijos,
	}) {
		return Container(
			padding: const EdgeInsets.all(14),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(20),
				border: Border.all(color: Paleta.bordeSuave),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: <Widget>[
					Row(
						children: <Widget>[
							Icon(icono, color: Paleta.verdeBosque, size: 20),
							const SizedBox(width: 8),
							Expanded(
								child: Text(
									titulo,
									style: const TextStyle(
										fontSize: 15.5,
										fontWeight: FontWeight.w800,
										color: Paleta.textoPrimario,
									),
								),
							),
						],
					),
					const SizedBox(height: 10),
					...hijos,
				],
			),
		);
	}

	Widget _opcion({
		required String texto,
		required bool seleccionada,
		required VoidCallback alTocar,
		Widget? extra,
		IconData icono = Icons.person_outline_rounded,
	}) {
		return Padding(
			padding: const EdgeInsets.only(bottom: 6),
			child: InkWell(
				borderRadius: BorderRadius.circular(14),
				onTap: alTocar,
				child: Container(
					padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
					decoration: BoxDecoration(
						color: seleccionada ? Paleta.salviaSuave : Paleta.cremaTarjeta,
						borderRadius: BorderRadius.circular(14),
						border: Border.all(
							color: seleccionada ? Paleta.verdeBosque : Paleta.bordeSuave,
							width: seleccionada ? 1.5 : 1.0,
						),
					),
					child: Row(
						children: <Widget>[
							Icon(
								seleccionada ? Icons.check_circle_rounded : icono,
								size: 19,
								color: Paleta.verdeBosque,
							),
							const SizedBox(width: 10),
							Expanded(
								child: Text(
									texto,
									style: const TextStyle(
										fontSize: 14,
										fontWeight: FontWeight.w700,
										color: Paleta.textoPrimario,
									),
								),
							),
							if (extra != null) extra,
						],
					),
				),
			),
		);
	}

	Widget _tarjetaSinBase() {
		return _tarjeta(
			titulo: 'Base de datos no disponible',
			icono: Icons.storage_rounded,
			hijos: const <Widget>[
				Text(
					'La base de datos local solo funciona en la app instalada en el '
					'teléfono (no en el navegador). Mientras tanto Geograf-IA '
					'responde con normalidad, pero no guarda historial ni avance.',
					style: TextStyle(fontSize: 13, color: Paleta.textoSecundario),
				),
			],
		);
	}

	Widget _tarjetaGrupos() {
		final ControladorTutor c = widget.controlador;
		return _tarjeta(
			titulo: 'Grupo',
			icono: Icons.groups_rounded,
			hijos: <Widget>[
				...c.grupos.map(
					(Grupo g) => _opcion(
						texto: g.nombre,
						icono: Icons.groups_outlined,
						seleccionada: c.grupoActivo?.id == g.id,
						alTocar: () async {
							await c.seleccionarGrupo(g);
							_recargar();
						},
					),
				),
				const SizedBox(height: 4),
				SizedBox(
					width: double.infinity,
					child: OutlinedButton.icon(
						onPressed: _nuevoGrupo,
						icon: const Icon(Icons.add_rounded, size: 18),
						label: const Text('Nuevo grupo'),
					),
				),
			],
		);
	}

	Widget _tarjetaAlumnos() {
		final ControladorTutor c = widget.controlador;
		return _tarjeta(
			titulo: 'Alumnos (códigos anónimos)',
			icono: Icons.badge_outlined,
			hijos: <Widget>[
				const Text(
					'No se guardan nombres: cada niño usa un código como A-01. '
					'El docente anota en papel a quién corresponde cada código.',
					style: TextStyle(fontSize: 12.5, color: Paleta.textoSecundario),
				),
				const SizedBox(height: 8),
				_opcion(
					texto: 'Invitado (sin código)',
					seleccionada: c.alumnoActivo == null,
					alTocar: () {
						c.seleccionarAlumno(null);
						_recargar();
					},
				),
				...c.alumnos.map(
					(Alumno a) => _opcion(
						texto: a.codigo,
						seleccionada: c.alumnoActivo?.id == a.id,
						alTocar: () {
							c.seleccionarAlumno(a);
							_recargar();
						},
						extra: IconButton(
							tooltip: 'Dar de baja',
							visualDensity: VisualDensity.compact,
							onPressed: () async {
								await c.darDeBajaAlumno(a);
								_recargar();
							},
							icon: const Icon(
								Icons.person_remove_outlined,
								size: 19,
								color: Paleta.textoSecundario,
							),
						),
					),
				),
				const SizedBox(height: 4),
				SizedBox(
					width: double.infinity,
					child: OutlinedButton.icon(
						onPressed: () async {
							await c.agregarAlumno();
						},
						icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
						label: const Text('Agregar alumno (nuevo código)'),
					),
				),
			],
		);
	}

	Widget _fila(String etiqueta, String valor) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 4),
			child: Row(
				children: <Widget>[
					Expanded(
						child: Text(
							etiqueta,
							style: const TextStyle(
								fontSize: 13,
								color: Paleta.textoSecundario,
							),
						),
					),
					Text(
						valor,
						style: const TextStyle(
							fontSize: 13.5,
							fontWeight: FontWeight.w800,
							color: Paleta.textoPrimario,
						),
					),
				],
			),
		);
	}

	Widget _tarjetaAvance() {
		final ControladorTutor c = widget.controlador;
		final Alumno? alumno = c.alumnoActivo;
		return _tarjeta(
			titulo: 'Avance',
			icono: Icons.insights_rounded,
			hijos: <Widget>[
				Wrap(
					spacing: 8,
					children: <Widget>[
						ChoiceChip(
							label: const Text('Todo el grupo'),
							selected: !_soloAlumno,
							onSelected: (_) {
								_soloAlumno = false;
								_recargar();
							},
						),
						ChoiceChip(
							label: Text(alumno == null ? 'Un alumno' : 'Solo ${alumno.codigo}'),
							selected: _soloAlumno,
							onSelected: alumno == null
								? null
								: (_) {
									_soloAlumno = true;
									_recargar();
								},
						),
					],
				),
				const SizedBox(height: 8),
				FutureBuilder<ResumenEstadisticas>(
					future: _futuroEstadisticas,
					builder: (
						BuildContext context,
						AsyncSnapshot<ResumenEstadisticas> snap,
					) {
						if (!snap.hasData) {
							return const Padding(
								padding: EdgeInsets.all(8),
								child: LinearProgressIndicator(),
							);
						}
						final ResumenEstadisticas r = snap.data!;
						if (r.consultas == 0 && r.retosRespondidos == 0) {
							return const Text(
								'Todavía no hay consultas guardadas. Haz una pregunta en el chat y vuelve aquí.',
								style: TextStyle(fontSize: 13, color: Paleta.textoSecundario),
							);
						}
						return Column(
							children: <Widget>[
								_fila('Conversaciones', '${r.conversaciones}'),
								_fila('Preguntas hechas', '${r.consultas}'),
								_fila(
									'Remitidas al maestro',
									'${r.remitidas} (${_porcentaje(r.porcentajeRemitidas)})',
								),
								_fila(
									'Tiempo promedio de respuesta',
									'${(r.tiempoPromedioMs / 1000).toStringAsFixed(1)} s (meta 8 s)',
								),
								_fila(
									'Dudas resueltas (meta 80 %)',
									r.valoradas == 0
										? 'Sin valoraciones'
										: '${_porcentaje(r.porcentajeResueltas)} de ${r.valoradas}',
								),
								_fila(
									'Retos acertados',
									r.retosRespondidos == 0
										? 'Sin retos'
										: '${r.retosAcertados} de ${r.retosRespondidos} (${_porcentaje(r.porcentajeAciertosRetos)})',
								),
							],
						);
					},
				),
				Align(
					alignment: Alignment.centerRight,
					child: TextButton.icon(
						onPressed: _recargar,
						icon: const Icon(Icons.refresh_rounded, size: 18),
						label: const Text('Actualizar'),
					),
				),
			],
		);
	}

	Widget _tarjetaBase() {
		final c = widget.controlador;
		final almacen = c.pipelineRAG.baseVectores;
		return _tarjeta(
			titulo: 'Base de conocimiento',
			icono: Icons.storage_rounded,
			hijos: <Widget>[
				_fila('Versión activa', almacen.versionActual),
				_fila('Temas cargados', '${almacen.totalFragmentos}'),
				const SizedBox(height: 6),
				const Text(
					'Últimas actualizaciones por USB',
					style: TextStyle(
						fontSize: 12.5,
						fontWeight: FontWeight.w800,
						color: Paleta.textoSecundario,
					),
				),
				FutureBuilder<List<RegistroActualizacionUsb>>(
					future: _futuroUsb,
					builder: (
						BuildContext context,
						AsyncSnapshot<List<RegistroActualizacionUsb>> snap,
					) {
						final List<RegistroActualizacionUsb> lista =
							snap.data ?? const <RegistroActualizacionUsb>[];
						if (lista.isEmpty) {
							return const Padding(
								padding: EdgeInsets.only(top: 4),
								child: Text(
									'Aún no se ha actualizado por USB.',
									style: TextStyle(
										fontSize: 12.5,
										color: Paleta.textoSecundario,
									),
								),
							);
						}
						return Column(
							children: lista
								.map(
									(RegistroActualizacionUsb a) => Padding(
										padding: const EdgeInsets.only(top: 4),
										child: Row(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: <Widget>[
												Icon(
													a.exitosa
														? Icons.check_circle_rounded
														: Icons.error_outline_rounded,
													size: 16,
													color: a.exitosa
														? Paleta.verdePino
														: Colors.red.shade700,
												),
												const SizedBox(width: 6),
												Expanded(
													child: Text(
														'${_fecha(a.fecha)} · ${a.mensaje}',
														style: const TextStyle(
															fontSize: 12.5,
															color: Paleta.textoPrimario,
														),
													),
												),
											],
										),
									),
								)
								.toList(),
						);
					},
				),
			],
		);
	}
}
