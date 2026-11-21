# gestor_matones.gd
# -----------------------------------------------------------------------------
# De noche, en las zonas chungas (zona industrial de las ciudades), hay matones
# de la banda del barrio rondando. Se crean cerca del jugador (máx. 3) y se
# borran al irse. Vive en el mundo (lo añade mundo.gd).
# -----------------------------------------------------------------------------
class_name GestorMatones
extends Node

const Bandas = preload("res://scripts/datos/bandas.gd")
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
	_mantener_aliados(jugador)
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
	# El jefe del barrio sale primero (si el barrio aún no es tuyo y no hay otro jefe).
	var clave: String = Bandas.clave_en(jugador.global_position.x, jugador.global_position.z)
	if clave != "" and not Juego.territorios.has(clave) and not _hay_jefe():
		m.jefe = true
		m.territorio = clave
	if clave != "":
		m.banda = Bandas.dueno_de_clave(clave)
	get_parent().add_child(m)
	if m.jefe:
		Juego.avisar("El jefe de %s ronda por aquí. Si lo tumbas, el barrio es tuyo." % Bandas.nombre(m.banda))


func _hay_jefe() -> bool:
	for m in get_tree().get_nodes_in_group("matones"):
		if is_instance_valid(m) and m.get("jefe") and not m.get("_muerto"):
			return true
	return false


# Tus reclutas te siguen a todas partes: se crean o se borran hasta igualar Juego.reclutas.
func _mantener_aliados(jugador: Node3D) -> void:
	var vivos: Array = get_tree().get_nodes_in_group("aliados")
	var n: int = 0
	for a in vivos:
		if is_instance_valid(a) and not a.get("_muerto"):
			n += 1
	if n > Juego.reclutas:
		for a in vivos:
			if n <= Juego.reclutas:
				break
			a.queue_free()
			n -= 1
	for i in range(n, Juego.reclutas):
		var a: Maton = Maton.new()
		a.aliado = true
		a.position = jugador.global_position + Basis(Vector3.UP, randf() * TAU) * Vector3(0, 0, 3.0)
		get_parent().add_child(a)


# Un matón enfadado aparece a 12 m (un cobrador de deudas, o alguien que te vio ganar).
static func enviar_cobrador(arbol: SceneTree, mensaje: String) -> void:
	var jugador: Node3D = arbol.get_first_node_in_group("jugador") as Node3D
	if jugador == null:
		return
	var m: Maton = Maton.new()
	m.position = jugador.global_position + Basis(Vector3.UP, randf() * TAU) * Vector3(0, 0, 12.0)
	m._enfado = true
	jugador.get_parent().add_child(m)
	Juego.avisar(mensaje)
