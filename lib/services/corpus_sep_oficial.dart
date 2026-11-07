import '../models/modelos.dart';

/// Base de conocimiento preinstalada con fragmentos reales de los libros de
/// texto de Geografia de la SEP (4to, 5to y 6to de primaria).
/// Cumple con RF-02 (base exclusiva SEP), RF-07 (precarga institucional),
/// RF-08 (adaptacion por grado escolar) y RF-10 (referencia de libro y pagina).
class CorpusSepOficial {
	CorpusSepOficial._();

	static const String versionInicial = 'SEP-2026.1 (Ciclo Escolar Oficial)';

	static const List<FragmentoSEP> fragmentosIniciales = <FragmentoSEP>[
		FragmentoSEP(
			idFragmento: 'SEP-GEO-01',
			gradoNivel: 4,
			nombreLibro: 'Libro SEP Geografía 4° / Quinto Grado',
			bloqueTema: 'Bloque II · El interior de la Tierra y los volcanes',
			numeroPagina: 44,
			textoContenido:
				'volcán volcanes magma lava erupción cráter ceniza montaña relieve '
				'interior de la tierra roca fundida caliente grietas corteza terrestre '
				'cómo se forma un volcán popocatépetl citlaltépetl paricutín fuego.',
			explicacion4to:
				'Bajo la Tierra hay roca muy caliente y fundida llamada magma. '
				'Cuando el magma sube por las grietas del suelo y sale a la superficie, '
				'lo llamamos lava. Al enfriarse con el aire, la lava se vuelve piedra y, '
				'después de muchas erupciones, va formando una gran montaña: ¡un volcán!',
			explicacion5to:
				'En el manto terrestre existen rocas fundidas a altísimas temperaturas '
				'llamadas magma. Debido a la presión interna y al choque de las placas '
				'tectónicas, el magma asciende por una chimenea hasta salir por el cráter '
				'en forma de lava, gases y ceniza. Al enfriarse y acumularse en capas, '
				'da origen a los volcanes del relieve.',
			explicacion6to:
				'El vulcanismo es un proceso interno modelador del relieve terrestre. '
				'Se origina cuando el magma del manto superior asciende a través de '
				'fracturas en la corteza terrestre asociadas a los límites de las placas '
				'tectónicas. Al emerger por el cráter como lava y solidificarse en '
				'sucesivas erupciones, construye conos y cadenas volcánicas como el '
				'Sistema Volcánico Transversal en México.',
			tipoIlustracion: 'volcan',
			notaIlustracion: '¡Mira la flecha! El magma caliente sube desde el interior por la chimenea.',
			preguntaComprobacion: '¿Cómo se llama la roca caliente cuando todavía está debajo de la Tierra?',
			opcionesComprobacion: <String>['Magma', 'Nieve', 'Granizo'],
			indiceRespuestaCorrecta: 0,
		),
		FragmentoSEP(
			idFragmento: 'SEP-GEO-02',
			gradoNivel: 4,
			nombreLibro: 'Libro SEP Geografía 4°',
			bloqueTema: 'Bloque II · El agua y el ciclo de la lluvia',
			numeroPagina: 54,
			textoContenido:
				'por qué llueve lluvia nubes agua evaporación condensación precipitación '
				'ciclo del agua sol calienta mar ríos vapor gotas tormenta clima granizo nieve.',
			explicacion4to:
				'¡Llueve gracias al viaje del agua! Primero, el Sol calienta el agua de '
				'los mares y ríos, y esta sube al cielo como vapor invisible. Allá arriba '
				'hace frío, así que el vapor se junta en gotitas y forma las nubes. '
				'Cuando las gotas pesan mucho, caen a la tierra como lluvia.',
			explicacion5to:
				'La lluvia forma parte del ciclo hidrológico. La energía solar evapora el '
				'agua superficial de océanos y ríos; el vapor asciende en la atmósfera, '
				'se enfría y se condensa formando nubes. Cuando las gotas de agua se '
				'unen y aumentan de peso, descienden por gravedad en forma de precipitación.',
			explicacion6to:
				'La precipitación es una fase clave del ciclo hidrológico atmosférico. '
				'Ocurre cuando la radiación solar provoca la evaporación de cuerpos de '
				'agua y la transpiración vegetal; el aire húmedo asciende, se enfría '
				'adiabáticamente y se condensa alrededor de partículas microscópicas, '
				'precipitándose como lluvia, nieve o granizo para recargar acuíferos y cuencas.',
			tipoIlustracion: 'ciclo_agua',
			notaIlustracion: 'El Sol evapora el agua, sube a las nubes y regresa como lluvia.',
			preguntaComprobacion: '¿Qué hace que el agua de los mares se caliente y suba como vapor?',
			opcionesComprobacion: <String>['El calor del Sol', 'El viento frío', 'Las piedras del fondo'],
			indiceRespuestaCorrecta: 0,
		),
		FragmentoSEP(
			idFragmento: 'SEP-GEO-03',
			gradoNivel: 4,
			nombreLibro: 'Libro SEP Geografía 4°',
			bloqueTema: 'Bloque II · Los ríos de México y sus cuencas',
			numeroPagina: 53,
			textoContenido:
				'a dónde van los ríos río agua dulce montañas cuenca vertiente mar '
				'océano lagos lagunas corriente desemboca bravo usumacinta grijalva lerma papaloapan.',
			explicacion4to:
				'Los ríos nacen en lo alto de las montañas cuando cae la lluvia o se '
				'derrite el hielo. Como el agua siempre baja por las laderas, los ríos '
				'viajan serpenteando por el campo hasta llegar al mar, a un gran lago '
				'o a otro río más grande.',
			explicacion5to:
				'Los ríos se originan en las partes altas de las sierras y escurren por '
				'gravedad siguiendo la pendiente del relieve dentro de una cuenca hídrica. '
				'Sus aguas confluyen en un río principal que finalmente desemboca en el '
				'océano (vertiente externa) o en un lago interior (vertiente interna).',
			explicacion6to:
				'Las corrientes fluviales captan los escurrimientos superficiales de una '
				'cuenca hidrográfica delimitada por las cumbres de las montañas. El caudal '
				'desciende desde las zonas de captación hasta desembocar en tres tipos '
				'de vertientes: del Pacífico, del Atlántico (Golfo de México y Caribe) '
				'o en cuencas endorreicas cerradas del interior continental.',
			tipoIlustracion: 'rios',
			notaIlustracion: 'El agua baja desde las cumbres de las montañas hasta llegar al mar.',
			preguntaComprobacion: '¿Dónde nacen la mayoría de los ríos antes de bajar hacia el mar?',
			opcionesComprobacion: <String>['En lo alto de las montañas', 'En las playas', 'En el desierto seco'],
			indiceRespuestaCorrecta: 0,
		),
		FragmentoSEP(
			idFragmento: 'SEP-GEO-04',
			gradoNivel: 5,
			nombreLibro: 'Libro SEP Geografía 5°',
			bloqueTema: 'Bloque I · La Tierra se mueve: día, noche y estaciones',
			numeroPagina: 17,
			textoContenido:
				'por qué hay día y noche rotación traslación sol tierra gira eje '
				'estaciones del año primavera verano otoño invierno 24 horas 365 días año bisiesto.',
			explicacion4to:
				'Tenemos día y noche porque la Tierra nunca deja de girar sobre sí misma, '
				'como si fuera un trompo. La mitad de la Tierra que queda mirando al Sol '
				'recibe luz y está de día, mientras que la otra mitad queda en la sombra '
				'y está de noche. ¡Dar una vuelta completa le toma 24 horas!',
			explicacion5to:
				'El día y la noche se producen por el movimiento de rotación: la Tierra '
				'gira sobre su propio eje de oeste a este cada 24 horas, iluminándose '
				'solo la cara expuesta al Sol. Además, realiza el movimiento de traslación '
				'alrededor del Sol en 365 días, lo que junto a su inclinación origina '
				'las cuatro estaciones del año.',
			explicacion6to:
				'La sucesión del día y la noche, así como las diferencias de husos horarios, '
				'son consecuencia directa del movimiento de rotación terrestre sobre su '
				'eje inclinado (23° 27\') en un periodo aproximado de 24 horas. Por su parte, '
				'el movimiento de traslación elíptica alrededor del Sol (365 días y 6 horas) '
				'determina las estaciones climáticas y los años bisiestos.',
			tipoIlustracion: 'dia_noche',
			notaIlustracion: 'La mitad iluminada por el Sol está de día y la otra mitad está de noche.',
			preguntaComprobacion: '¿Cuánto tiempo tarda la Tierra en dar una vuelta sobre sí misma?',
			opcionesComprobacion: <String>['24 horas (un día)', 'Un mes entero', '100 años'],
			indiceRespuestaCorrecta: 0,
		),
		FragmentoSEP(
			idFragmento: 'SEP-GEO-05',
			gradoNivel: 4,
			nombreLibro: 'Libro SEP Geografía 4°',
			bloqueTema: 'Bloque I · México y su división política',
			numeroPagina: 19,
			textoContenido:
				'estados de méxico cuántos estados tiene méxico división política '
				'entidades federativas capital fronteras municipios territorio puebla república mexicana.',
			explicacion4to:
				'Nuestro país se llama Estados Unidos Mexicanos y está dividido en '
				'32 entidades federativas: 31 estados y la Ciudad de México, que es '
				'la capital del país. Al norte somos vecinos de Estados Unidos y al '
				'sur de Guatemala y Belice.',
			explicacion5to:
				'El territorio nacional de México se organiza políticamente en 32 entidades '
				'federativas (31 estados libres y soberanos, divididos en municipios, '
				'y la Ciudad de México, dividida en demarcaciones territoriales). Cuenta '
				'con fronteras terrestres al norte y sureste, además de amplios litorales '
				'en el Océano Pacífico y el Golfo de México.',
			explicacion6to:
				'La organización político-administrativa de los Estados Unidos Mexicanos '
				'comprende 32 entidades federativas que integran una república federal. '
				'Su territorio continental, insular y marítimo (mar patrimonial de 200 '
				'millas náuticas) limita al norte con Estados Unidos a lo largo del río '
				'Bravo y al sureste con Guatemala y Belice.',
			tipoIlustracion: 'mexico',
			notaIlustracion: 'México tiene 32 entidades federativas y océanos a ambos lados.',
			preguntaComprobacion: '¿Cuántas entidades federativas (estados y CDMX) tiene México en total?',
			opcionesComprobacion: <String>['32 entidades', '15 entidades', '50 entidades'],
			indiceRespuestaCorrecta: 0,
		),
		FragmentoSEP(
			idFragmento: 'SEP-GEO-06',
			gradoNivel: 5,
			nombreLibro: 'Libro SEP Geografía 5° / Sexto Grado',
			bloqueTema: 'Bloque I · Continentes, océanos y mapas de la Tierra',
			numeroPagina: 29,
			textoContenido:
				'continentes del mundo cuántos continentes hay mapas océanos américa '
				'europa asia áfrica oceanía antártida coordenadas escala rosa de los vientos '
				'paralelos meridianos latitud longitud ecuador.',
			explicacion4to:
				'Las grandes extensiones de tierra del planeta se llaman continentes y '
				'son seis: América (donde vivimos), Europa, Asia, África, Oceanía y la '
				'Antártida. Para ubicarlos usamos los mapas, que tienen una rosa de los '
				'vientos para indicar el Norte, Sur, Este y Oeste.',
			explicacion5to:
				'La superficie continental de la Tierra se divide en seis continentes: '
				'América, Europa, Asia, África, Oceanía y la Antártida, rodeados por '
				'cinco océanos (Pacífico, Atlántico, Índico, Ártico y Antártico). Los '
				'mapas utilizan título, simbología, escala, orientación y coordenadas '
				'geográficas para representarlos con precisión.',
			explicacion6to:
				'El espacio geográfico mundial se organiza en seis masas continentales '
				'(América, Eurasia dividida en Europa y Asia, África, Oceanía y Antártida) '
				'delimitadas por límites naturales, culturales y políticos. Su estudio '
				'cartográfico emplea proyecciones, escalas numéricas y gráficas, así como '
				'la red de paralelos (latitud) y meridianos (longitud).',
			tipoIlustracion: 'continentes',
			notaIlustracion: 'América, Europa, Asia, África, Oceanía y Antártida forman los continentes.',
			preguntaComprobacion: '¿En cuál de los continentes se encuentra México?',
			opcionesComprobacion: <String>['En América', 'En Europa', 'En Asia'],
			indiceRespuestaCorrecta: 0,
		),
		FragmentoSEP(
			idFragmento: 'SEP-GEO-07',
			gradoNivel: 5,
			nombreLibro: 'Libro SEP Geografía 5°',
			bloqueTema: 'Bloque II · Placas tectónicas, sismos y relieve',
			numeroPagina: 42,
			textoContenido:
				'por qué tiembla sismos temblores terremotos placas tectónicas relieve '
				'montañas llanuras mesetas depresiones sierra madre corteza terrestre.',
			explicacion4to:
				'El suelo que pisamos está formado por enormes piezas de roca como un '
				'rompecabezas, llamadas placas tectónicas. Cuando dos de esas piezas se '
				'empujan o rozan entre sí, el suelo se sacude y sentimos un temblor o '
				'sismo. Ese empuje también levanta las montañas del relieve.',
			explicacion5to:
				'La corteza terrestre está fragmentada en placas tectónicas que flotan '
				'sobre el manto. Sus movimientos de contacto (convergentes), separación '
				'(divergentes) y deslizamiento (transformantes) liberan energía en forma '
				'de sismos y modelan las formas del relieve: montañas, mesetas, llanuras '
				'y depresiones.',
			explicacion6to:
				'La dinámica interna de la litosfera se explica mediante la tectónica de '
				'placas. México se ubica sobre cinco placas (Norteamericana, de Cocos, '
				'del Pacífico, de Rivera y del Caribe); la subducción de la placa de '
				'Cocos bajo la Norteamericana origina la alta sismicidad del país y el '
				'levantamiento orogénico de las Sierras Madres.',
			tipoIlustracion: 'placas',
			notaIlustracion: 'Cuando las placas tectónicas chocan o se deslizan, el suelo vibra.',
			preguntaComprobacion: '¿Cómo se llaman las grandes piezas de roca que forman la corteza de la Tierra?',
			opcionesComprobacion: <String>['Placas tectónicas', 'Nubes viajeras', 'Corrientes marinas'],
			indiceRespuestaCorrecta: 0,
		),
		FragmentoSEP(
			idFragmento: 'SEP-GEO-08',
			gradoNivel: 6,
			nombreLibro: 'Libro SEP Geografía 6°',
			bloqueTema: 'Bloque II · Climas, regiones naturales y biodiversidad',
			numeroPagina: 58,
			textoContenido:
				'climas tipos de clima regiones naturales selva bosque desierto tundra '
				'sabana biodiversidad plantas animales temperatura humedad ecuador.',
			explicacion4to:
				'El clima es cómo se siente el tiempo en un lugar durante muchos años: '
				'puede ser cálido, templado, seco o frío. Según el clima que hace, '
				'crecen distintas plantas y viven diferentes animales: por ejemplo, en '
				'la selva llueve mucho y hay monos y tucanes, mientras que en el desierto '
				'casi no llueve y crecen cactus.',
			explicacion5to:
				'Los climas del mundo se clasifican principalmente en tropicales, secos, '
				'templados, fríos y polares, dependiendo de la latitud, la altitud y la '
				'cercanía al mar. Cada clima determina una región natural (selva, sabana, '
				'bosque, estepa, desierto o tundra) y favorece la gran biodiversidad de México.',
			explicacion6to:
				'La distribución de las zonas térmicas y climáticas depende de la inclinación '
				'de los rayos solares según la latitud y de factores modificadores como la '
				'altitud del relieve y las corrientes marinas. Esta interacción configura '
				'las regiones naturales continentales y convierte a México en uno de los '
				'países megadiversos del planeta.',
			tipoIlustracion: 'climas',
			notaIlustracion: 'Cada clima (cálido, templado, seco o frío) tiene su propia flora y fauna.',
			preguntaComprobacion: '¿En qué región natural casi no llueve y viven plantas como los cactus?',
			opcionesComprobacion: <String>['En el desierto', 'En la selva húmeda', 'En los hielos polares'],
			indiceRespuestaCorrecta: 0,
		),
		FragmentoSEP(
			idFragmento: 'SEP-GEO-09',
			gradoNivel: 4,
			nombreLibro: 'Libro SEP Geografía 4°',
			bloqueTema: 'Bloque III · Población rural, urbana y migración',
			numeroPagina: 83,
			textoContenido:
				'población campo ciudad rural urbana migración emigración inmigración '
				'comunidades rurales servicios transporte habitantes censo inegi.',
			explicacion4to:
				'Las personas vivimos en dos tipos de lugares: el campo (localidades '
				'rurales), donde hay menos habitantes, más naturaleza y se cultiva la '
				'tierra; y las ciudades (localidades urbanas), donde viven muchas personas '
				'y hay más edificios y fábricas. Cuando alguien se muda de un lugar a otro '
				'para vivir o trabajar, a eso le llamamos migración.',
			explicacion5to:
				'En México el INEGI considera rurales a las localidades con menos de '
				'2,500 habitantes, dedicadas sobre todo a actividades agropecuarias y '
				'forestales, y urbanas a las que superan esa cifra. El desplazamiento '
				'de población en busca de mejores oportunidades se denomina migración '
				'(interna dentro del país o externa hacia otros países).',
			explicacion6to:
				'La distribución demográfica distingue entre espacios rurales (baja '
				'densidad poblacional y predominio del sector primario) y espacios '
				'urbanos (alta concentración de servicios e industria). Los flujos '
				'migratorios comprenden la emigración (salida) y la inmigración (llegada), '
				'transformando la estructura social y cultural de las regiones receptoras.',
			tipoIlustracion: 'mexico',
			notaIlustracion: 'El campo nos brinda alimentos y las ciudades concentran servicios.',
			preguntaComprobacion: '¿Cómo se llama cuando las personas se mudan de un lugar a otro para vivir?',
			opcionesComprobacion: <String>['Migración', 'Rotación', 'Evaporación'],
			indiceRespuestaCorrecta: 0,
		),
		FragmentoSEP(
			idFragmento: 'SEP-GEO-10',
			gradoNivel: 4,
			nombreLibro: 'Libro SEP Geografía 4° / Quinto Grado',
			bloqueTema: 'Bloque IV · Actividades económicas: campo, industria y comercio',
			numeroPagina: 117,
			textoContenido:
				'actividades económicas agricultura ganadería pesca minería recursos '
				'naturales industria comercio turismo transporte maíz frijol petróleo.',
			explicacion4to:
				'Para tener alimentos, ropa y casas realizamos actividades económicas. '
				'En el campo se siembra maíz y frijol (agricultura), se cuidan animales '
				'(ganadería) y se pesca. Luego, las fábricas transforman esos recursos '
				'en productos que llegan a las tiendas mediante el comercio y el transporte.',
			explicacion5to:
				'Las actividades económicas se dividen en tres sectores: primarias '
				'(agricultura, ganadería, pesca, explotación forestal y minería), '
				'secundarias (industria manufacturera y construcción) y terciarias '
				'(comercio, transporte, educación, salud y turismo).',
			explicacion6to:
				'Las cadenas productivas articulan el sector primario (extracción de '
				'materias primas agropecuarias, pesqueras, forestales y minero-energéticas), '
				'el sector secundario (transformación industrial pesada y ligera) y el '
				'sector terciario (distribución comercial, servicios financieros, '
				'logística y turismo nacional e internacional).',
			tipoIlustracion: 'climas',
			notaIlustracion: 'Del campo (primarias) pasan a las fábricas (secundarias) y al comercio (terciarias).',
			preguntaComprobacion: '¿A qué actividad económica pertenece sembrar maíz, frijol y verduras?',
			opcionesComprobacion: <String>['Agricultura', 'Minería', 'Turismo'],
			indiceRespuestaCorrecta: 0,
		),
	];
}
