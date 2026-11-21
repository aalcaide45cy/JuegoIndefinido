# Capturas de los interiores de las casas (de día y de noche) y mide los FPS. Ventana fuera de pantalla:
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_interiores.tscn -- /carpeta
extends Node

var carpeta: String = "."
var jugador: Node3D
var gestor: Node
var J: Node


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _ir(pos: Vector3, giro: float, incl: float) -> void:
	jugador.global_position = pos
	jugador.velocity = Vector3.ZERO
	jugador._giro = giro
	jugador._inclinacion = incl


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)


# Busca una casa por tipo de interior y tamaño mínimo.
func _buscar(tipo_ciudad: int, distrito: String, min_w: float, min_d: float, max_w: float = 99.0) -> Dictionary:
	for s in GeneradorMundo.todos_asentamientos():
		if int(s["tipo"]) != tipo_ciudad or bool(s.get("montana", false)):
			continue
		var p: Vector2 = s["pos"]
		var m: float = float(s["mitad"])
		for c in GeneradorMundo._casas_en(s, Rect2(p.x - m, p.y - m, m * 2.0, m * 2.0)):
			if c.has("servicio") or int(c["pisos"]) < 1:
				continue
			if distrito != "" and str(c.get("distrito", "")) != distrito:
				continue
			if float(c["w"]) >= min_w and float(c["d"]) >= min_d and float(c["w"]) <= max_w:
				return c
	return {}


func _frente(c: Dictionary, metros: float) -> Vector3:
	var cara: float = c["puerta"]
	return Vector3(c["x"], float(c["y"]) + 0.2, float(c["z"]) + cara * (float(c["d"]) / 2.0 + metros))


# giro para mirar hacia +z (cara=-1, es decir hacia z positivo) o -z.
func _giro_hacia(c: Dictionary, entrando: bool) -> float:
	var cara: float = c["puerta"]
	# giro 0 mira a -Z; PI mira a +Z.
	return 0.0 if cara > 0.0 else PI


func _visitar(nombre: String, c: Dictionary, noche: bool = false) -> void:
	if c.is_empty():
		print("SIN CASA para ", nombre)
		return
	var cara: float = c["puerta"]
	var d: Dictionary = InteriorCasa.generar(c)
	print("== %s: casa (%.0f, %.0f) %.1fx%.1f tipo %s, %d piezas, %d habitaciones" % [nombre, c["x"], c["z"], c["w"], c["d"], d["tipo"], d["cajas"].size(), d["habitaciones"].size()])
	J.hora = 22.5 if noche else 12.0
	var suf: String = "noche" if noche else "dia"
	# Fuera, delante de la puerta.
	_ir(_frente(c, 9.0), _giro_hacia(c, false), -0.1)
	await _esperar(7.0)
	_ir(_frente(c, 9.0), _giro_hacia(c, false), -0.1)
	gestor.actualizar(jugador.global_position, 99)
	await _esperar(1.0)
	await _foto("%s_%s_1fuera" % [nombre, suf])
	# Puerta abierta, desde más cerca.
	var puerta: Node = null
	for nodo in get_tree().get_nodes_in_group("puertas_casa"):
		if (nodo as Node3D).global_position.distance_to(Vector3(c["x"], c["y"], float(c["z"]) + cara * float(c["d"]) / 2.0)) < 1.0:
			puerta = nodo
	if puerta != null:
		puerta.poner_abierta(true, false)
	_ir(_frente(c, 3.5), _giro_hacia(c, false), -0.05)
	await _esperar(0.6)
	await _foto("%s_%s_2puerta" % [nombre, suf])
	# Dentro: justo pasada la puerta, mirando hacia el fondo.
	var ent: Vector3 = d["entrada"]
	_ir(ent + Vector3(0, 0.05, 0), _giro_hacia(c, true), -0.15)
	await _esperar(1.0)
	await _foto("%s_%s_3entrada" % [nombre, suf])
	# Una vista por cada habitación (desde su lado más cercano a la puerta, mirando al interior).
	var n: int = 0
	for h in d["habitaciones"]:
		var r: Rect2 = h
		var centro: Vector2 = r.get_center()
		var desde: Vector3 = Vector3(centro.x, float(c["y"]) + 0.2, centro.y + cara * r.size.y * 0.3)
		var giro: float = _giro_hacia(c, true)
		_ir(desde, giro, -0.35)
		await _esperar(0.5)
		await _foto("%s_%s_4sala%d" % [nombre, suf, n])
		n += 1
		if n >= 3:
			break
	if puerta != null:
		puerta.poner_abierta(false, false)


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
	await _visitar("vivienda_grande", _buscar(2, "residencial", 11.0, 12.0))
	await _visitar("vivienda_pequena", _buscar(1, "residencial", 6.0, 6.5, 8.0))
	await _visitar("casa_rica", _buscar(2, "rico", 12.0, 11.0))
	await _visitar("tienda", _buscar(2, "centro", 9.0, 9.0))
	await _visitar("almacen", _buscar(2, "industrial", 9.0, 9.0))
	await _visitar("vivienda_grande", _buscar(2, "residencial", 11.0, 12.0), true)
	print("Gestor: ", gestor.cuenta())
	var ms: Array = []
	for i in 120:
		await get_tree().process_frame
		ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	print("Proceso medio por fotograma: %.2f ms; FPS %d" % [ms.reduce(func(a, b): return a + b, 0.0) / ms.size(), Engine.get_frames_per_second()])
	get_tree().quit()
