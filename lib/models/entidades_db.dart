/// Entidades que lee la interfaz desde la base de datos local.

/// Aula o grupo de trabajo (un solo celular puede atender a varios grupos).
class Grupo {
	const Grupo({required this.id, required this.nombre});

	final int id;
	final String nombre;
}

/// Alumno anonimo: solo tiene un codigo (por ejemplo "A-07"), nunca un nombre.
class Alumno {
	const Alumno({required this.id, required this.idGrupo, required this.codigo});

	final int id;
	final int idGrupo;
	final String codigo;
}

/// Una conversacion guardada, tal como se lista en "Consultas recientes".
class ConversacionResumen {
	const ConversacionResumen({
		required this.id,
		required this.titulo,
		required this.inicio,
		required this.totalConsultas,
	});

	final int id;
	final String titulo;
	final DateTime inicio;
	final int totalConsultas;
}

/// Una consulta guardada con lo necesario para volver a mostrarla en el chat.
class ConsultaGuardada {
	const ConsultaGuardada({
		required this.id,
		required this.pregunta,
		required this.respuesta,
		required this.remitidaMaestro,
		required this.generadaPorIA,
		required this.tiempoMs,
		required this.cita,
		required this.tipoIlustracion,
		required this.notaIlustracion,
		required this.quedoClara,
		required this.claveFragmento,
	});

	final int id;
	final String pregunta;
	final String respuesta;
	final bool remitidaMaestro;
	final bool generadaPorIA;
	final int tiempoMs;
	final String cita;
	final String tipoIlustracion;
	final String notaIlustracion;
	final bool? quedoClara;
	final String claveFragmento;
}

/// Indicadores del grupo o de un alumno (las metas del proyecto).
class ResumenEstadisticas {
	const ResumenEstadisticas({
		this.conversaciones = 0,
		this.consultas = 0,
		this.remitidas = 0,
		this.tiempoPromedioMs = 0,
		this.valoradas = 0,
		this.claras = 0,
		this.retosRespondidos = 0,
		this.retosAcertados = 0,
	});

	final int conversaciones;
	final int consultas;

	/// Consultas que se remitieron al maestro (RF-03).
	final int remitidas;
	final double tiempoPromedioMs;

	/// Consultas en las que el nino dijo si le quedo clara la respuesta.
	final int valoradas;
	final int claras;
	final int retosRespondidos;
	final int retosAcertados;

	/// Porcentaje de dudas resueltas (meta del proyecto: 80 %). Se calcula sobre
	/// las respuestas que el nino valoro; null si aun no hay ninguna.
	double? get porcentajeResueltas =>
		valoradas == 0 ? null : claras * 100.0 / valoradas;

	double? get porcentajeRemitidas =>
		consultas == 0 ? null : remitidas * 100.0 / consultas;

	double? get porcentajeAciertosRetos =>
		retosRespondidos == 0 ? null : retosAcertados * 100.0 / retosRespondidos;
}

/// Un registro del historial de actualizaciones por USB.
class RegistroActualizacionUsb {
	const RegistroActualizacionUsb({
		required this.fecha,
		required this.exitosa,
		required this.mensaje,
		required this.versionNueva,
		required this.fragmentosCargados,
		required this.duracionSeg,
	});

	final DateTime fecha;
	final bool exitosa;
	final String mensaje;
	final String versionNueva;
	final int fragmentosCargados;
	final double duracionSeg;
}
