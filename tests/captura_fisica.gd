# Capturas de la física y destrucción del escenario. Ventana fuera de pantalla:
#   godot --path . --windowed --position -20000,-20000 --resolution 1280x720 res://tests/captura_fisica.tscn -- carpeta
extends Node

var carpeta: String = "."
var cam: Camera3D


func _foto(nombre: String, esperar: int = 4) -> void:
	for i in esperar:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)
	print("FOTO ", nombre)


func _mirar(desde: Vector3, hacia: Vector3) -> void:
	cam.global_position = desde
	cam.look_at(hacia, Vector3.UP)


func _cerca(centro: Vector3, radio: float, tipo: String = "") -> Array:
	var out: Array = []
	for o in get_tree().get_nodes_in_group("objetos_fisicos"):
		var of: ObjetoFisico = o as ObjetoFisico
		if of == null or of.roto:
			continue
		if tipo != "" and of.tipo != tipo:
			continue
		if of.tipo == "mueble" or of.tipo == "modelo":
			continue
		if of.global_position.distance_to(centro) < radio:
			out.append(of)
	out.sort_custom(func(a, b): return a.global_position.distance_to(centro) < b.global_position.distance_to(centro))
	return out


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	carpeta = args[0] if args.size() > 0 else "."
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	for i in 3:
		await get_tree().process_frame
	var J = raiz.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	J.velocidad_tiempo = 0.0
	J.hora = 13.0
	hud.visible = false
	var jugador = hud.jugador
	cam = Camera3D.new()
	cam.fov = 65.0
	escena.add_child(cam)
	cam.make_current()

	# ---- 1. Plaza de la ciudad principal: farolas, bancos y barriles con física.
	_mirar(Vector3(-9, 3.2, 14), Vector3(4, 0.8, 2))
	await get_tree().create_timer(3.0).timeout
	print("Objetos con física en la ciudad principal: ", get_tree().get_nodes_in_group("objetos_fisicos").size())
	await _foto("fisica_01_plaza_antes")
	Combate.explosion(escena, Vector3(6, 0.4, 6), 6.0, 160.0)
	await _foto("fisica_02_plaza_explosion", 6)
	await get_tree().create_timer(2.5).timeout
	await _foto("fisica_03_plaza_despues")

	# ---- 2. Una ciudad del mundo grande: mobiliario urbano.
	var ciudad: Dictionary = {}
	for s in GeneradorMundo.todos_asentamientos():
		if int(s["tipo"]) == 2 and (s["pos"] as Vector2).length() > 600.0:
			ciudad = s
			break
	var pc: Vector2 = ciudad["pos"]
	var y: float = float(ciudad["base"])
	var k: float = GeneradorMundo.BLOQUE
	var cruce: Vector3 = Vector3(pc.x + k, y, pc.y + k)
	jugador._bloqueado = true
	jugador.global_position = cruce + Vector3(-14, 1.5, 0)
	await get_tree().create_timer(12.0).timeout
	print("Objetos con física cargados: ", get_tree().get_nodes_in_group("objetos_fisicos").size())
	for o in _cerca(cruce, 25.0):
		print("   ", o.tipo, " ", o.global_position - cruce)
	_mirar(cruce + Vector3(0.01, 40.0, 0), cruce)
	await _foto("fisica_00_cenital", 10)
	jugador.global_position = cruce + Vector3(-14, 1.5, 0)
	_mirar(cruce + Vector3(-13, 4.0, -3.5), cruce + Vector3(2, 0.5, 9))
	await _foto("fisica_04_calle_mobiliario", 10)
	_mirar(cruce + Vector3(-2, 2.0, 12), cruce + Vector3(10, 0.6, 16))
	await _foto("fisica_05_acera_detalle", 6)

	# ---- 3. Disparos: chispas en una farola (se rompe el farol), astillas en un banco.
	var farolas: Array = _cerca(cruce, 30.0, "farola")
	if not farolas.is_empty():
		var f: ObjetoFisico = farolas[0]
		var fp: Vector3 = f.global_position
		_mirar(fp + Vector3(-3.5, 3.0, 4.5), fp + Vector3(0, 3.2, 0))
		await _foto("fisica_06_farola_antes", 4)
		var cabeza: Vector3 = f.global_transform * Vector3(0.72, 4.35, 0)
		f.impacto(cabeza, (cabeza - cam.global_position).normalized(), 25.0, 20.0)
		await _foto("fisica_07_farola_disparo", 2)
		# ---- 4. Un coche se la lleva por delante.
		_mirar(fp + Vector3(-7, 2.5, 6), fp + Vector3(1, 1.2, 0))
		f.golpe_vehiculo(Vector3(0, 0, -15).rotated(Vector3.UP, 0.4), 1300.0)
		await get_tree().create_timer(0.35).timeout
		await _foto("fisica_08_farola_atropellada", 1)
		await get_tree().create_timer(1.8).timeout
		if is_instance_valid(f):
			_mirar(f.global_position + Vector3(-5, 3.0, 5), f.global_position)
		await _foto("fisica_09_farola_en_el_suelo", 1)

	# ---- 5. Explosión en mitad del mobiliario de la acera.
	var cosas: Array = _cerca(cruce, 30.0)
	var centro: Vector3 = cruce + Vector3(-4.6, 0.8, 10)
	for o in cosas:
		if (o as ObjetoFisico).tipo != "farola":
			centro = (o as ObjetoFisico).global_position + Vector3(0, 0.6, 0)
			break
	var hacia_calle: Vector3 = Vector3(cruce.x - centro.x, 0, cruce.z - centro.z).normalized()
	_mirar(centro + hacia_calle * 9.0 + Vector3(0, 4.0, 0), centro)
	await _foto("fisica_10_antes_explosion", 3)
	Combate.explosion(escena, centro, 6.0, 160.0)
	await get_tree().create_timer(0.1).timeout
	await _foto("fisica_11_explosion", 1)
	await get_tree().create_timer(0.45).timeout
	await _foto("fisica_12_escombros_volando", 1)
	await get_tree().create_timer(2.5).timeout
	await _foto("fisica_13_despues", 1)

	# ---- 6. Bidones rojos en cadena y una boca de riego reventada (en la acera, al otro lado).
	var base: Vector3 = cruce + Vector3(5.2, 0.3, -14)
	for i in 3:
		var b: ObjetoFisico = ObjetoFisico.crear("bidon_rojo")
		escena.add_child(b)
		b.global_position = base + Vector3(0, 0, i * 1.4)
	var br: ObjetoFisico = ObjetoFisico.crear("boca_riego")
	escena.add_child(br)
	br.global_position = base + Vector3(0, 0, -3)
	_mirar(base + Vector3(-8, 3.0, 5), base + Vector3(0, 0.8, 0))
	await _foto("fisica_14_bidones", 6)
	var primero: ObjetoFisico = _cerca(base, 0.5, "bidon_rojo")[0]
	primero.impacto(primero.global_position + Vector3(0, 0.5, 0.3), Vector3(0, 0, -1), 60.0, 10.0)
	await get_tree().create_timer(0.2).timeout
	await _foto("fisica_15_bidones_cadena", 1)
	await get_tree().create_timer(1.0).timeout
	print("Bidones que quedan enteros: ", _cerca(base, 6.0, "bidon_rojo").size())
	var br2: ObjetoFisico = ObjetoFisico.crear("boca_riego")
	escena.add_child(br2)
	br2.global_position = base + Vector3(0, 0, 8)
	await get_tree().create_timer(0.3).timeout
	br2.golpe_vehiculo(Vector3(0, 0, -16), 1300.0)
	br2.romper(Vector3(0, 0, -400))
	_mirar(base + Vector3(-7, 2.5, 13), base + Vector3(0, 2.0, 8))
	await get_tree().create_timer(1.0).timeout
	await _foto("fisica_16_agua", 1)
	get_tree().quit()
