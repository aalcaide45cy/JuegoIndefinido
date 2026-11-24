# Capturas de un asalto a una casa real del mundo (puerta cerrada, forzar, vecino durmiendo,
# vecino despierto atacando) con ventana fuera de pantalla:
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_asaltos.tscn -- /carpeta
extends Node

var carpeta: String = "."
var jugador: Node3D
var gestor: Node
var J: Node


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)
	print("FOTO ", nombre)


func _ir(pos: Vector3) -> void:
	jugador.global_position = pos
	jugador.velocity = Vector3.ZERO


# Mira hacia un punto del mundo.
func _mirar(punto: Vector3) -> void:
	var d: Vector3 = punto - (jugador.global_position + Vector3(0, 1.6, 0))
	jugador._giro = atan2(-d.x, -d.z)
	jugador._inclinacion = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.2, 0.9)


func _buscar_casa() -> Dictionary:
	for s in GeneradorMundo.todos_asentamientos():
		if int(s["tipo"]) != 2 or bool(s.get("montana", false)):
			continue
		var p: Vector2 = s["pos"]
		var m: float = float(s["mitad"])
		for c in GeneradorMundo._casas_en(s, Rect2(p.x - m, p.y - m, m * 2.0, m * 2.0)):
			if Asaltos.es_asaltable(c) and str(c.get("distrito", "")) == "residencial" and float(c["w"]) >= 11.0 and float(c["d"]) >= 12.0:
				return c
	return {}


func _casa_nodo() -> CasaAsaltable:
	for n in get_tree().get_nodes_in_group("casas_asaltables"):
		return n as CasaAsaltable
	return null


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	J = raiz.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	jugador = hud.jugador
	gestor = escena.find_children("*", "GestorInteriores", true, false)[0]
	J.velocidad_tiempo = 0.0
	J.hora = 23.0
	J.policia_activa = true
	Asaltos.activo = true
	Asaltos.dificultad = 1
	Asaltos.puertas_cerradas = true
	var c: Dictionary = _buscar_casa()
	if c.is_empty():
		print("SIN CASA")
		get_tree().quit(1)
		return
	var cara: float = float(c["puerta"])
	print("Casa: (%.0f, %.0f) %.1fx%.1f cara %.0f" % [c["x"], c["z"], c["w"], c["d"], cara])
	var delante: Vector3 = Vector3(c["x"], float(c["y"]) + 0.2, float(c["z"]) + cara * (float(c["d"]) / 2.0 + 3.0))
	_ir(delante)
	await _esperar(7.0)
	_ir(delante)
	gestor.actualizar(jugador.global_position, 99)
	await _esperar(1.5)
	var casa: CasaAsaltable = _casa_nodo()
	if casa == null:
		print("SIN CasaAsaltable")
		get_tree().quit(1)
		return
	print("Perfil %s, ocupantes %d, botines %d, ventanas %d" % [casa.perfil, casa.vecinos.size(), casa.botines.size(), casa.ventanas.size()])
	# 1. Fuera: puerta cerrada con llave.
	_mirar(casa.puerta.global_position)
	await _esperar(0.5)
	await _foto("asalto_1_puerta_cerrada")
	# 2. Forzando con ganzúa (a mitad).
	J.anadir("ganzua", 3)
	J.anadir("palanca", 1)
	casa.puerta.forzar_con(jugador, "ganzua", casa.perfil)
	for i in 14:
		casa.puerta.avanzar(0.25)
	await _esperar(0.4)
	await _foto("asalto_2_forzando")
	while casa.puerta.activa:
		casa.puerta.avanzar(0.25)
	await _esperar(0.8)
	var ent: Vector3 = casa.a_mundo(Vector3(0, 0.1, cara * (float(c["d"]) / 2.0 - 1.2)))
	_ir(ent)
	var n_dorm: int = 0
	for v in casa.vecinos:
		if (v as Vecino).esta_durmiendo():
			n_dorm += 1
	print("Durmiendo tras abrir con ganzúa: %d de %d" % [n_dorm, casa.vecinos.size()])
	# 3. Dentro: un vecino durmiendo.
	var v0: Vecino = casa.vecinos[0]
	var pos_v: Vector3 = v0.global_position
	var cerca: Vector3 = pos_v + (ent - pos_v).normalized() * 2.4
	cerca.y = ent.y
	_ir(cerca)
	_mirar(pos_v + Vector3(0, 0.6, 0))
	await _esperar(0.6)
	await _foto("asalto_3_vecino_durmiendo")
	# 4. Registrar un mueble (barra de progreso).
	var b: BotinCasa = casa.botines[0]
	_ir(b.global_position + (ent - b.global_position).normalized() * 1.3 - Vector3(0, 0.9, 0))
	_mirar(b.global_position)
	b.usar(jugador)
	for i in 3:
		b.avanzar(0.25)
	await _esperar(0.4)
	await _foto("asalto_4_registrando")
	b.cancelar()
	# 5. Se despierta y se enfrenta con un objeto.
	v0.armado = false
	v0.despertar("ruido")
	v0.reaccion = "objeto"
	_ir(v0.global_position + (ent - v0.global_position).normalized() * 2.0)
	_mirar(v0.global_position + Vector3(0, 1.2, 0))
	await _esperar(1.6)
	await _foto("asalto_5_despierto_ataca")
	# 6. Otro armado con pistola.
	if casa.vecinos.size() > 1:
		var v1: Vecino = casa.vecinos[1]
		v1.armado = true
		v1.despertar("golpe")
		v1.reaccion = "arma"
		_ir(v1.global_position + (ent - v1.global_position).normalized() * 4.5)
		_mirar(v1.global_position + Vector3(0, 1.2, 0))
		await _esperar(2.6)
		await _foto("asalto_6_armado_dispara")
	print("Estrellas: %d  vida: %.0f  denunciada: %s" % [J.estrellas, J.vida, str(casa.denunciada)])
	get_tree().quit()
