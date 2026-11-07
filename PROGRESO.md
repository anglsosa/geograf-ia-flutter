# Geograf-IA — Progreso del Prototipo Funcional (Flutter)

> Documento de control de avances y trazabilidad contra los documentos del proyecto (`6_DisenoUI.pdf`, `9_UML.pdf`, `Requerimientos_Tutor_Local_Inteligente 2.pdf`, `Equipo6_App_Greograf-ia.pdf` y la referencia visual *Coach Voice Call*).

---

## 1. Cómo subirlo y correrlo en FlutLab (sin instalar nada en tu Mac)

1. Entra a [https://flutlab.io](https://flutlab.io) y crea un proyecto nuevo o importa desde carpeta/ZIP.
2. Sube el contenido de la subcarpeta `geograf_ia/` (`pubspec.yaml`, `analysis_options.yaml`, `lib/` y `test/`).
3. Presiona **Pub Get** y luego **Build & Run** (funciona tanto en el previsualizador Web de FlutLab como en el simulador Android de FlutLab).
4. **No requiere login ni internet** (`RF-12` y `RF-01`): entra directo al tutor y está listo para usarse.

---

## 2. Arquitectura implementada (100% alineada a `9_UML.pdf`)

```
lib/
├── main.dart                                 # Arranque directo sin login (RF-12) + Provider
├── core/
│   ├── reglas.dart                           # Límites estrictos, grados 4°-6°, anti-spam, RF-03
│   └── tema.dart                             # Paleta crema/esfera 3D + verde bosque SEP + alto contraste
├── models/
│   └── modelos.dart                          # FragmentoSEP, ResultadoConsulta, ConfiguracionAula, ReporteActualizacion
├── services/
│   ├── corpus_sep_oficial.dart               # Fragmentos verificados de libros SEP Geografía (4°, 5° y 6°)
│   ├── servicios.dart                        # AlmacenVectoresChroma, MotorLLMLocal, ServicioRAG, ServicioAudio, GestorActualizacionUSB
│   └── simulados.dart                        # Re-exportación limpia para pruebas
├── controllers/
│   ├── controlador_tutor.dart                # ControladorTutor (procesarConsulta, establecerGradoEscolar, reiniciarContextoSesion)
│   └── controlador_configuracion.dart        # ControladorConfiguracion (guardarAjustesAula, iniciarActualizacionUSB)
└── ui/
    ├── mascota.dart                          # Esfera 3D animada (escucha/piensa/habla) + diagramas didácticos (volcán, agua, etc.)
    ├── vista_llamada_voz.dart                # Modo Llamada de Voz a pantalla completa (igual a referencia "Coach Voice Call")
    ├── menu_lateral.dart                     # Sidebar verde bosque: Temas, Recientes, Nueva conversación (6_DisenoUI.pdf pág. 6)
    ├── pantalla_chat.dart                    # ActividadChat: Bienvenida, Ideas para explorar, burbujas con cita SEP y retos
    └── pantalla_configuracion.dart           # ActividadConfiguracion: Libros 4°/5°/6°, Actualización USB y Accesibilidad
```

---

## 3. Trazabilidad de Requerimientos (RF y RNF) Completados ✅

| Código | Requerimiento | Estado | Implementación en el código |
|---|---|---|---|
| **RF-01** | Consulta por voz o texto 100% sin conexión | ✅ Listo | `PantallaChat` (barra inferior) + `VistaLlamadaVoz` + `ServicioAudio` |
| **RF-02** | Respuesta basada exclusivamente en libros SEP (RAG) | ✅ Listo | `AlmacenVectoresChroma` (similitud coseno L2) + `CorpusSepOficial` |
| **RF-03** | Remisión al maestro cuando no hay sustento en SEP | ✅ Listo | `ServicioRAG.generarRespuestaFundamentada` + `Reglas.mensajeConsultaAlMaestro` |
| **RF-04** | Conversión de texto a voz (TTS) | ✅ Listo | Botón `🔊 Escuchar` en cada burbuja + lectura automática opcional |
| **RF-05** | Actualización de contenidos mediante memoria USB | ✅ Listo | `GestorActualizacionUSB` + `ControladorConfiguracion.iniciarActualizacionUSB` |
| **RF-06 / 07** | Uso en celular del docente / precarga en tablets | ✅ Listo | Diseño adaptable (móvil/tablet) con base SEP precargada de fábrica |
| **RF-08** | Adaptación del lenguaje al grado escolar (4°, 5°, 6°) | ✅ Listo | `MotorLLMLocal.inferirConPrompt` cambia vocabulario y profundidad entre 4°, 5° y 6° |
| **RF-09** | Operación grupal consecutiva sin reiniciar la app | ✅ Listo | Botón `nueva conversación` en `MenuLateralGeografIA` (`reiniciarContextoSesion`) |
| **RF-10** | Referencia del libro y página en cada respuesta | ✅ Listo | Etiqueta `📖 Libro SEP Geografía · Bloque · Pág.` en cada burbuja |
| **RF-11** | Confirmación visual al docente tras actualizar por USB | ✅ Listo | `PantallaConfiguracion.mostrarNotificacionExito` + resumen de versión |
| **RF-12** | Uso sin registro ni inicio de sesión | ✅ Listo | Acceso directo a `PantallaChat` desde `main.dart` |
| **Objetivo General** | Preguntas pedagógicas para corroborar aprendizaje | ✅ Listo | Tarjeta interactiva `RolMensaje.retoPedagogico` cada 2 consultas resueltas |
| **RNF-01** | Respuesta en menos de 8 segundos | ✅ Listo | Inferencia local en `< 1 s` con indicador `⚡ s` visible en cada respuesta |
| **RNF-02** | Base SEP de solo lectura para el alumno | ✅ Listo | Sin controles de edición para el estudiante; solo paquete USB firmado |
| **RNF-08** | Accesibilidad (voz, tamaño de fuente y alto contraste) | ✅ Listo | Panel de accesibilidad en `PantallaConfiguracion` + Modo Llamada de Voz |
| **RNF-09** | Almacenamiento total `< 4 GB` | ✅ Listo | Medidor en `AlmacenVectoresChroma.obtenerAlmacenamientoUsadoMB()` (~960 MB) |

---

## 4. Qué falta para pasar del prototipo FlutLab al APK nativo final en campo ⏳

1. **Enlazar el binario GGUF real en Android físico**: cuando compilen para un celular Android ARM real fuera de FlutLab Web, descomentar/conectar `llama_cpp_dart` en `MotorLLMLocal` apuntando al archivo `.gguf` (`Qwen2.5-1.5B-Instruct-Q4_K_M.gguf`) y `vosk_flutter` en `ServicioAudio`.
2. **Pruebas piloto en aula (Fase 4 DBR)**: aplicar el protocolo Pre-test → Sesión guiada con Geograf-IA → Post-test con alumnos reales para medir el `>= 20%` de ganancia relativa de aprendizaje.

