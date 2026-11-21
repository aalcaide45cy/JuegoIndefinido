# gestor_policia.gd
# -----------------------------------------------------------------------------
# Mantiene a la policía por estrellas (datos/policia.gd): cuando tienes estrellas
# hace aparecer refuerzos (guardias a pie y, desde 3 estrellas, coches patrulla)
# a unas decenas de metros, en el suelo, y los retira cuando se acaba la búsqueda.
# También avisa del distrito en el que entras (el barrio cambia la vigilancia).
# Lo añade mundo.gd. SIN PROBAR a mano en Godot.
# -----------------------------------------------------------------------------
class_name GestorPolicia
extends Node

const DatosPolicia = preload("res://scripts/datos/policia.gd")

var _t: float = 0.0
var _t_distrito: float = 0.0
var _distrito_actual: String = ""


func _process(delta: float) -> void:
	_t += delta
	_t_distrito += delta
	if _t_distrito >= 2.0:
		_t_distrito = 0.0
		_avisar_distrito()
	if _t < 1.0:
		return
	_t = 0.0
	var jugador: Node3D = get_tree().get_first_node_in_group("jugador") as Node3D
	if jugador == null:
		return
	var n: int = Juego.estrellas
	if n <= 0 or not Juego.policia_activa:
		return
	if Juego.interiores > 0:
		return   # Dentro de un edificio no aparecen refuerzos nuevos.
	# Guardias a pie.
	var objetivo_guardias: int = int(DatosPolicia.REFUERZOS[n])
	if n >= 2 and DatosPolicia.riqueza(Juego.dinero) > 0.6:
		objetivo_guardias += 1
	var guardias: Array = []
	for g in get_tree().get_nodes_in_group("policia_refuerzo"):
		if g is Guardia:
			guardias.append(g)
			if (g as Node3D).global_position.distance_to(jugador.global_position) > DatosPolicia.DISTANCIA_BORRAR_REFUERZO:
				(g as Node3D).queue_free()
	if guardias.size() < objetivo_guardias:
		_crear_guardia(jugador)
	# Coches patrulla.
	var coches: Array = get_tree().get_nodes_in_group("coches_policia")
	for c in coches:
		if (c as CochePatrulla).atascado or (c as Node3D).global_position.distance_to(jugador.global_position) > 220.0:
			(c as Node3D).queue_free()
	if coches.size() < int(DatosPolicia.COCHES[n]):
		_crear_coche(jugador)


func _punto_en_suelo(centro: Vector3, dmin: float, dmax: float) -> Variant:
	for intento in 8:
		var ang: float = randf() * TAU
		var d: float = randf_range(dmin, dmax)
		var p: Vector3 = centro + Vector3(cos(ang) * d, 0.0, sin(ang) * d)
		var consulta: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				Vector3(p.x, centro.y + 30.0, p.z), Vector3(p.x, centro.y - 30.0, p.z))
		var choque: Dictionary = (get_viewport().world_3d.direct_space_state).intersect_ray(consulta)
		if choque.is_empty():
			continue
		var y: float = (choque["position"] as Vector3).y
		if absf(y - centro.y) < 4.0:
			return Vector3(p.x, y + 0.3, p.z)
	return null


func _crear_guardia(jugador: Node3D) -> void:
	var p = _punto_en_suelo(jugador.global_position, DatosPolicia.DISTANCIA_REFUERZO_MIN, DatosPolicia.DISTANCIA_REFUERZO_MAX)
	if p == null:
		return
	var g: Guardia = Guardia.new()
	g.refuerzo = true
	g.estrellas_minimas = 2
	get_parent().add_child(g)
	g.global_position = p
	g.visible = true


func _crear_coche(jugador: Node3D) -> void:
	var p = _punto_en_suelo(jugador.global_position, 80.0, 120.0)
	if p == null:
		return
	var c: CochePatrulla = CochePatrulla.new()
	get_parent().add_child(c)
	c.global_position = p
	var hacia: Vector3 = jugador.global_position - c.global_position
	c.rotation.y = atan2(-hacia.x, -hacia.z)


func _avisar_distrito() -> void:
	var jugador: Node3D = get_tree().get_first_node_in_group("jugador") as Node3D
	if jugador == null or not GeneradorMundo.listo:
		return
	var d: Dictionary = GeneradorMundo.distrito_en(jugador.global_position.x, jugador.global_position.z)
	var nombre: String = "" if d.is_empty() else str(d["nombre"])
	if nombre != _distrito_actual:
		_distrito_actual = nombre
		Juego.distrito_actual = d
		if nombre != "":
			Juego.avisar("Entras en: %s" % nombre)
