# interactuable.gd
# -----------------------------------------------------------------------------
# Base para todo lo que se puede usar con la tecla E: puertas, macetas, el
# caldero, el mostrador...
#
# Cada objeto concreto "hereda" de este (extends Interactuable) y cambia dos
# funciones:
#   texto_accion() -> lo que aparece en pantalla, por ejemplo "Cosechar".
#   usar(jugador)  -> lo que pasa al pulsar E.
#
# El jugador busca el Interactuable más cercano que tenga delante.
# -----------------------------------------------------------------------------
class_name Interactuable
extends Node3D

# Hasta qué distancia (en metros) se puede usar.
var distancia: float = 1.8
# true para objetos grandes (vehículos): se pueden usar aunque el rayo choque antes con su propia carrocería.
var ignora_vista: bool = false


func _enter_tree() -> void:
	add_to_group("interactuable")


func texto_accion() -> String:
	return "Usar"


func usar(_jugador: Node) -> void:
	pass
