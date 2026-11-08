/// Esquema de la base de datos local de Geograf-IA (SQLite).
///
/// 11 tablas en tercera forma normal. Solo se usa SQL basico (sin UPSERT, JSON1
/// ni funciones de ventana) para funcionar tambien en versiones antiguas de
/// SQLite de Android. Las fechas se guardan como texto ISO-8601 y los valores
/// booleanos como 0 o 1.
///
/// Privacidad (RNF-10): no existe ninguna columna con nombres ni datos
/// personales. El alumno solo tiene un codigo anonimo asignado por la app.
class EsquemaSql {
	EsquemaSql._();

	static const int version = 1;
	static const String nombreArchivo = 'geograf_ia.db';

	/// Sentencias CREATE TABLE en orden de dependencia (primero las tablas padre).
	static const List<String> tablas = <String>[
		'''
CREATE TABLE grupo (
	id_grupo INTEGER PRIMARY KEY AUTOINCREMENT,
	nombre TEXT NOT NULL,
	fecha_creacion TEXT NOT NULL,
	ultimo_uso TEXT NOT NULL,
	activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1))
)''',
		'''
CREATE TABLE alumno (
	id_alumno INTEGER PRIMARY KEY AUTOINCREMENT,
	id_grupo INTEGER NOT NULL REFERENCES grupo (id_grupo) ON DELETE CASCADE,
	codigo TEXT NOT NULL,
	fecha_alta TEXT NOT NULL,
	activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)),
	UNIQUE (id_grupo, codigo)
)''',
		'''
CREATE TABLE configuracion_aula (
	id_configuracion INTEGER PRIMARY KEY AUTOINCREMENT,
	id_grupo INTEGER NOT NULL UNIQUE REFERENCES grupo (id_grupo) ON DELETE CASCADE,
	grado_actual INTEGER NOT NULL DEFAULT 4 CHECK (grado_actual BETWEEN 4 AND 6),
	velocidad_voz REAL NOT NULL DEFAULT 1.0 CHECK (velocidad_voz BETWEEN 0.6 AND 1.4),
	tamano_texto INTEGER NOT NULL DEFAULT 16 CHECK (tamano_texto BETWEEN 14 AND 22),
	alto_contraste INTEGER NOT NULL DEFAULT 0 CHECK (alto_contraste IN (0, 1)),
	voz_automatica INTEGER NOT NULL DEFAULT 1 CHECK (voz_automatica IN (0, 1)),
	actualizado_en TEXT NOT NULL
)''',
		'''
CREATE TABLE version_base (
	id_version INTEGER PRIMARY KEY AUTOINCREMENT,
	codigo TEXT NOT NULL UNIQUE,
	origen TEXT NOT NULL CHECK (origen IN ('precargada', 'usb')),
	fecha_instalacion TEXT NOT NULL,
	activa INTEGER NOT NULL DEFAULT 0 CHECK (activa IN (0, 1)),
	total_fragmentos INTEGER NOT NULL DEFAULT 0
)''',
		'''
CREATE TABLE fragmento_sep (
	id_fragmento INTEGER PRIMARY KEY AUTOINCREMENT,
	clave TEXT NOT NULL UNIQUE,
	id_version INTEGER NOT NULL REFERENCES version_base (id_version),
	grado_nivel INTEGER NOT NULL CHECK (grado_nivel BETWEEN 4 AND 6),
	nombre_libro TEXT NOT NULL,
	bloque_tema TEXT NOT NULL,
	numero_pagina INTEGER NOT NULL DEFAULT 0,
	palabras_clave TEXT NOT NULL,
	explicacion_4to TEXT NOT NULL,
	explicacion_5to TEXT NOT NULL DEFAULT '',
	explicacion_6to TEXT NOT NULL DEFAULT '',
	tipo_ilustracion TEXT NOT NULL DEFAULT '',
	nota_ilustracion TEXT NOT NULL DEFAULT ''
)''',
		'''
CREATE TABLE reto (
	id_reto INTEGER PRIMARY KEY AUTOINCREMENT,
	id_fragmento INTEGER NOT NULL REFERENCES fragmento_sep (id_fragmento) ON DELETE CASCADE,
	pregunta TEXT NOT NULL
)''',
		'''
CREATE TABLE opcion_reto (
	id_opcion INTEGER PRIMARY KEY AUTOINCREMENT,
	id_reto INTEGER NOT NULL REFERENCES reto (id_reto) ON DELETE CASCADE,
	orden INTEGER NOT NULL,
	texto TEXT NOT NULL,
	es_correcta INTEGER NOT NULL DEFAULT 0 CHECK (es_correcta IN (0, 1)),
	UNIQUE (id_reto, orden)
)''',
		'''
CREATE TABLE conversacion (
	id_conversacion INTEGER PRIMARY KEY AUTOINCREMENT,
	id_grupo INTEGER NOT NULL REFERENCES grupo (id_grupo) ON DELETE CASCADE,
	id_alumno INTEGER REFERENCES alumno (id_alumno) ON DELETE SET NULL,
	titulo TEXT NOT NULL,
	inicio TEXT NOT NULL,
	fin TEXT
)''',
		'''
CREATE TABLE consulta (
	id_consulta INTEGER PRIMARY KEY AUTOINCREMENT,
	id_conversacion INTEGER NOT NULL REFERENCES conversacion (id_conversacion) ON DELETE CASCADE,
	id_fragmento INTEGER REFERENCES fragmento_sep (id_fragmento) ON DELETE SET NULL,
	fecha TEXT NOT NULL,
	pregunta TEXT NOT NULL,
	respuesta TEXT NOT NULL,
	grado INTEGER NOT NULL CHECK (grado BETWEEN 4 AND 6),
	por_voz INTEGER NOT NULL DEFAULT 0 CHECK (por_voz IN (0, 1)),
	remitida_maestro INTEGER NOT NULL DEFAULT 0 CHECK (remitida_maestro IN (0, 1)),
	generada_por_ia INTEGER NOT NULL DEFAULT 0 CHECK (generada_por_ia IN (0, 1)),
	similitud REAL NOT NULL DEFAULT 0,
	tiempo_ms INTEGER NOT NULL DEFAULT 0,
	quedo_clara INTEGER CHECK (quedo_clara IN (0, 1))
)''',
		'''
CREATE TABLE respuesta_reto (
	id_respuesta INTEGER PRIMARY KEY AUTOINCREMENT,
	id_reto INTEGER NOT NULL REFERENCES reto (id_reto) ON DELETE CASCADE,
	id_opcion INTEGER NOT NULL REFERENCES opcion_reto (id_opcion) ON DELETE CASCADE,
	id_alumno INTEGER REFERENCES alumno (id_alumno) ON DELETE SET NULL,
	id_conversacion INTEGER REFERENCES conversacion (id_conversacion) ON DELETE SET NULL,
	fecha TEXT NOT NULL
)''',
		'''
CREATE TABLE actualizacion_usb (
	id_actualizacion INTEGER PRIMARY KEY AUTOINCREMENT,
	id_version_anterior INTEGER REFERENCES version_base (id_version),
	id_version_nueva INTEGER REFERENCES version_base (id_version),
	fecha TEXT NOT NULL,
	ruta_paquete TEXT NOT NULL,
	exitosa INTEGER NOT NULL CHECK (exitosa IN (0, 1)),
	mensaje TEXT NOT NULL,
	fragmentos_cargados INTEGER NOT NULL DEFAULT 0,
	duracion_seg REAL NOT NULL DEFAULT 0
)''',
	];

	/// Indices para las consultas mas frecuentes (historial y estadisticas).
	static const List<String> indices = <String>[
		'CREATE INDEX idx_alumno_grupo ON alumno (id_grupo)',
		'CREATE INDEX idx_conversacion_grupo ON conversacion (id_grupo, inicio)',
		'CREATE INDEX idx_consulta_conversacion ON consulta (id_conversacion)',
		'CREATE INDEX idx_consulta_fragmento ON consulta (id_fragmento)',
		'CREATE INDEX idx_reto_fragmento ON reto (id_fragmento)',
		'CREATE INDEX idx_respuesta_alumno ON respuesta_reto (id_alumno)',
	];
}
