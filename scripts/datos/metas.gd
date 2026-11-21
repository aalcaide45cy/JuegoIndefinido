# metas.gd
# -----------------------------------------------------------------------------
# Metas encadenadas del móvil (pestaña "Metas"): dan rumbo y una recompensa en dinero.
# Para añadir una: una entrada en LISTA y su condición en cumplida(). Se usa con preload.
# -----------------------------------------------------------------------------
extends RefCounted

const LISTA: Array = [
	{"id": "huerto", "texto": "Consigue tu primer huerto (alquilado o comprado).", "premio": 100},
	{"id": "techo", "texto": "Alquila una vivienda.", "premio": 150},
	{"id": "nivel5", "texto": "Llega al nivel 5.", "premio": 300},
	{"id": "reputacion", "texto": "Reputación 30: clientes que te recomiendan.", "premio": 400},
	{"id": "negocio", "texto": "Monta un negocio legal (pestaña Negocios).", "premio": 600},
	{"id": "prefecto", "texto": "Nivel 10, reputación 50 y que el Prefecto no te busque.", "premio": 1500},
]


static func cumplida(id: String) -> bool:
	match id:
		"huerto": return not Juego.huertos.is_empty()
		"techo": return not Juego.viviendas.is_empty()
		"nivel5": return Juego.nivel >= 5
		"reputacion": return Juego.reputacion >= 30
		"negocio":
			var neg = Juego.negocio
			return neg is Dictionary and (neg.get("activos", []) as Array).size() > 0
		"prefecto": return Juego.nivel >= 10 and Juego.reputacion >= 50 and Juego.sospecha <= 1.0
	return false
