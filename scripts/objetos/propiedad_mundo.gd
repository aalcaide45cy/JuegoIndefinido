# propiedad_mundo.gd
# -----------------------------------------------------------------------------
# La puerta de una casa del mundo grande que se alquila o se vende.
#   E          -> alquilar (pago único).
#   Mayús + E  -> comprar (40 veces el alquiler; se vende por el 70 %).
# Cuando ya es tuya, E descansa un rato y recupera vida.
# Los huertos del mundo usan Parcela (que hace lo mismo con su id "w_h_...").
# La ficha (precio, tamaño, nombre) sale del id con GeneradorMundo.propiedad().
# SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name PropiedadMundo
extends Interactuable

const Propiedades = preload("res://scripts/datos/propiedades.gd")

var id_prop: String = ""
var _ficha: Dictionary = {}


func _ready() -> void:
	distancia = 2.6
	_ficha = Propiedades.de_id(id_prop)


func texto_accion() -> String:
	if _ficha.is_empty():
		return ""
	if Juego.viviendas.has(id_prop):
		return "Descansar en tu casa (%s)" % _ficha["lugar"]
	return "%s: alquilar %d $  ·  Mayús+E comprar %d $" % [_ficha["nombre"], _ficha["alquiler"],
			Propiedades.precio_compra(_ficha)]


func usar(_jugador: Node) -> void:
	if _ficha.is_empty():
		return
	if Juego.viviendas.has(id_prop):
		Juego.cambiar_vida(30.0)
		Juego.avisar("Descansas un rato en tu casa. Te sientes mejor.")
		return
	Propiedades.contratar(_ficha, Input.is_action_pressed("correr"))
