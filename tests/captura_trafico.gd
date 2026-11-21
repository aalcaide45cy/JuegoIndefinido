# Capturas del tráfico y los peatones: pasos de cebra con gente cruzando, coches parados
# ante peatones, semáforos y un atropello provocado. Con ventana fuera de pantalla:
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_trafico.tscn -- /carpeta
extends Node

var carpeta: String = "."
var jugador: Node3D
var vida: Node
var J


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.88)
	print("FOTO ", nombre)


# Pone la cámara a "dist" metros del punto, mirándolo desde la dirección "desde_dir".
func _mirar(punto: Vector3, dist: float, altura: float, ang: float) -> void:
	var dir: Vector2 = Vector2(cos(ang), sin(ang))
	jugador.global_position = punto + Vector3(dir.x * dist, altura, dir.y * dist)
	jugador.velocity = Vector3.ZERO
	var al: Vector2 = -dir
	jugador._giro = atan2(-al.x, -al.y)
	jugador._inclinacion = -atan2(altura - 1.0, dist)


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
	vida = escena.find_children("*", "VidaUrbana", true, false)[0]
	J.hora = 12.0
	J.velocidad_tiempo = 0.0 if "velocidad_tiempo" in J else 1.0
	J.modo_volar = true
	var elegido: Dictionary = {}
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if int(s["tipo"]) == 2 and not bool(s.get("montana", false)):
			elegido = s
			break
	var p: Vector2 = elegido["pos"]
	var h: float = GeneradorMundo.altura(p.x, p.y)
	jugador.global_position = Vector3(p.x, h + 20.0, p.y + 30.0)
	await get_tree().create_timer(8.0).timeout
	# Vista general desde arriba del centro de la ciudad.
	_mirar(Vector3(p.x, h, p.y), 38.0, 22.0, 1.2)
	await get_tree().create_timer(1.0).timeout
	await _foto("01_ciudad_vista_general_trafico")
	var t0: int = Time.get_ticks_usec()
	var peor: int = 0
	var ult: int = t0
	for i in 300:
		await get_tree().process_frame
		var tt: int = Time.get_ticks_usec()
		peor = maxi(peor, tt - ult)
		ult = tt
	var medio: float = float(ult - t0) / 1000.0 / 300.0
	print("FPS ciudad con trafico: %.2f ms (%d FPS), peor %.1f ms, coches %d, peatones %d" % [medio, int(1000.0 / medio), peor / 1000.0, vida._coches.size(), vida._peatones.size()])

	var hechas: Dictionary = {}
	var t: float = 0.0
	while t < 200.0 and hechas.size() < 2:
		jugador.global_position = jugador.global_position   # (se queda donde está)
		await get_tree().create_timer(0.3).timeout
		t += 0.3
		for q in vida._peatones:
			if not is_instance_valid(q) or q.estado != 2 or q.cruce_nodo.x == -9999:
				continue
			var centro: Vector2 = (q.p2 + q.destino) * 0.5
			var parado: Node3D = null
			for c in vida._coches:
				if is_instance_valid(c) and c.vel < 0.3 and c.global_position.distance_to(q.global_position) < 14.0:
					parado = c
			var con_luz: bool = q.red["luz"].has(q.cruce_nodo)
			var clave: String = "paso_con_semaforo" if con_luz else "paso_sin_semaforo"
			if parado != null and not hechas.has(clave):
				hechas[clave] = true
				var pt: Vector3 = Vector3(q.global_position.x, q.global_position.y, q.global_position.z)
				var dir: Vector2 = (q.destino - q.p2).normalized()
				# Cámara en diagonal al paso para ver al peatón, los coches parados y el semáforo.
				var ang: float = atan2(dir.y, dir.x) + 2.1
				_mirar(pt, 15.0, 6.0, ang)
				await get_tree().create_timer(0.4).timeout
				await _foto("0%d_peatones_cruzando_%s_coches_parados" % [2 + hechas.size() - 1, clave])
	print("Pasos fotografiados: ", hechas.keys())

	# Atropello provocado: un coche despistado golpea a un peatón imprudente.
	var coche: Node3D = null
	for c in vida._coches:
		if is_instance_valid(c) and c.vel > 3.0 and c.global_position.distance_to(Vector3(p.x, h, p.y)) < 90.0:
			coche = c
			break
	var peaton: Node3D = null
	for q in vida._peatones:
		if is_instance_valid(q):
			peaton = q
			break
	if coche != null and peaton != null:
		var dir: Vector2 = coche.dir2
		var delante: Vector3 = coche.global_position + Vector3(dir.x, 0.0, dir.y) * 2.6
		peaton.estado = 4
		peaton.p2 = Vector2(delante.x, delante.z)
		peaton.destino = peaton.p2
		peaton.t_espera = -1.0
		peaton.global_position = Vector3(delante.x, delante.y, delante.z)
		vida._atropellar_peaton(coche, peaton)
		await get_tree().create_timer(0.3).timeout
		_mirar(coche.global_position, 10.0, 4.0, atan2(dir.y, dir.x) + 2.4)
		await _foto("05_atropello_peaton_herido_en_el_suelo")
	get_tree().quit()
