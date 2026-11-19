# gestor_matones.gd
# -----------------------------------------------------------------------------
# De noche, en las zonas chungas (zona industrial de las ciudades), hay matones
# de la banda del barrio rondando. Se crean cerca del jugador (máx. 3) y se
# borran al irse. Vive en el mundo (lo añade mundo.gd).
# -----------------------------------------------------------------------------
class_name GestorMatones
extends Node

const MAX_MATONES: int = 3
const RADIO_MIN: float = 18.0
const RADIO_MAX: float = 40.0

var _t: float = 2.0


static func zona_activa() -> bool:
	if Juego.distrito_actual.get("id", "") != "industrial" or Juego.interiores > 0:
		return false
	return Juego.hora >= 21.0 or Juego.hora < 5.0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 3.0
	var jugador: Node3D = get_tree().get_first_node_in_group("jugador") as Node3D
	if jugador == null:
		return
	var matones: Array = get_tree().get_nodes_in_group("matones")
	var activa: bool = zona_activa()
	for m in matones:
		var lejos: bool = (m as Node3D).global_position.distance_to(jugador.global_position) > 90.0
		if is_instance_valid(m) and (lejos or not activa) and not m.get("_muerto"):
			m.queue_free()
	if not activa or matones.size() >= MAX_MATONES:
		return
	var vida_urbana: Node = get_tree().get_first_node_in_group("vida_urbana")
	if vida_urbana == null or not vida_urbana.has_method("punto_de_calle"):
		return
	var p = vida_urbana.punto_de_calle(RADIO_MIN, RADIO_MAX)
	if p == null:
		return
	var m: Maton = Maton.new()
	m.position = p
	get_parent().add_child(m)
