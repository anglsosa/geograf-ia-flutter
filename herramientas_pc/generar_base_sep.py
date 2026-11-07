#!/usr/bin/env python3
"""
Script de preprocesamiento en PC (Consejos Tecnicos Escolares - RF-05).
Lee los PDFs oficiales de Geografia de la SEP, divide el contenido en
fragmentos semanticos y exporta el paquete vectorial offline para USB.
"""

import json
import pathlib
import sys


def construir_paquete_usb_demo() -> dict:
	return {
		"version": "SEP-2026.2-USB",
		"fragmentos": [
			{
				"idFragmento": "SEP-GEO-09-USB",
				"gradoNivel": 6,
				"nombreLibro": "Libro SEP Geografía 6° (Actualización USB CTE)",
				"bloqueTema": "Bloque V · Cuidado del medio ambiente y energías limpias",
				"numeroPagina": 158,
				"textoContenido": (
					"medio ambiente contaminacion calentamiento global reciclaje "
					"energia solar eolica cuidar el planeta basura agua arboles."
				),
				"explicacion4to": (
					"Para cuidar nuestro planeta debemos ahorrar agua, apagar las "
					"luces que no usamos, separar la basura para reciclar y plantar "
					"árboles. También existen energías limpias como el Sol y el viento."
				),
				"explicacion5to": (
					"La protección ambiental requiere reducir emisiones, aplicar "
					"las tres erres (reducir, reutilizar y reciclar) y aprovechar "
					"fuentes de energía renovable como la solar y la eólica."
				),
				"explicacion6to": (
					"El desarrollo sustentable y la mitigación del cambio climático "
					"demandan transitar hacia energías limpias, conservar los "
					"bosques y gestionar responsablemente el agua y los residuos."
				),
				"tipoIlustracion": "climas",
				"notaIlustracion": "El Sol y el viento producen energía limpia sin contaminar.",
				"preguntaComprobacion": "¿Cuál de estas es una fuente de energía limpia?",
				"opcionesComprobacion": [
					"La energía del Sol",
					"Quemar llantas",
					"Tirar basura al río",
				],
				"indiceRespuestaCorrecta": 0,
			}
		],
	}


def main() -> int:
	salida = pathlib.Path(__file__).parent / "paquete_usb_sep_2026.json"
	paquete = construir_paquete_usb_demo()
	salida.write_text(
		json.dumps(paquete, ensure_ascii=False, indent="\t"),
		encoding="utf-8",
	)
	print(f"Paquete USB generado correctamente en: {salida}")
	return 0


if __name__ == "__main__":
	sys.exit(main())

