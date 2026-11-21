# Capturas de los trazados de ciudad: vista aérea y de calle de cada tipo, y un coche girando.
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_trazados.tscn -- /carpeta
extends Node

var carpeta: String = "."
var jugador: Node3D


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)
	print("FOTO ", nombre)


func _mirar(punto: Vector3, dist: float, altura: float, ang: float) -> void:
	var dir: Vector2 = Vector2(cos(ang), sin(ang))
	jugador.global_position = punto + Vector3(dir.x * dist, altura, dir.y * dist)
	jugador.velocity = Vector3.ZERO
	jugador._giro = atan2(dir.x, dir.y) + PI
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
	var J = raiz.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	jugador = hud.jugador
	var vida = escena.find_children("*", "VidaUrbana", true, false)[0]
	J.hora = 12.0
	J.velocidad_tiempo = 0.0 if "velocidad_tiempo" in J else 1.0
	J.modo_volar = true
	var pedidos: Array = [[2, 0, "ciudad_cuadricula"], [2, 3, "ciudad_casco_mixto"], [1, 1, "pueblo_casco_antiguo"], [1, 2, "pueblo_irregular"], [2, 2, "ciudad_irregular"]]
	for pe in pedidos:
		var elegido: Dictionary = {}
		for clave in GeneradorMundo._asentamientos:
			var s: Dictionary = GeneradorMundo._asentamientos[clave]
			if int(s["tipo"]) == pe[0] and int(s.get("trazado", 0)) == pe[1] and not bool(s.get("montana", false)):
				elegido = s
				break
		if elegido.is_empty():
			print("No hay asentamiento para ", pe)
			continue
		var p: Vector2 = elegido["pos"]
		var h: float = GeneradorMundo.altura(p.x, p.y)
		var ctr: Vector3 = Vector3(p.x, h, p.y)
		jugador.global_position = ctr + Vector3(0, 40, 0)
		await get_tree().create_timer(6.0).timeout
		_mirar(ctr + Vector3(0, 0, 0), 45.0, 75.0, 1.0)
		await get_tree().create_timer(1.5).timeout
		await _foto("%s_aerea" % pe[2])
		# Nivel de calle: junto a un cruce, mirando por una calle.
		var cruce: Vector3 = ctr + Vector3(GeneradorMundo.BLOQUE, 0, GeneradorMundo.BLOQUE)
		_mirar(cruce, 22.0, 3.2, 0.6)
		await get_tree().create_timer(1.5).timeout
		await _foto("%s_calle" % pe[2])
		if int(pe[1]) == 1 or int(pe[1]) == 3:
			# Callejón del casco: mirando por el medio de una manzana.
			var medio: Vector3 = ctr + Vector3(GeneradorMundo.BLOQUE * 0.5 + 4.0, 0, GeneradorMundo.BLOQUE * 0.5 + 4.0)
			_mirar(medio, 14.0, 2.4, PI * 0.5)
			await get_tree().create_timer(1.5).timeout
			await _foto("%s_callejon" % pe[2])
		# Coches: espera a ver uno en curva y lo fotografía.
		var t: float = 0.0
		var hecho: bool = false
		while t < 40.0 and not hecho:
			await get_tree().create_timer(0.2).timeout
			t += 0.2
			jugador.global_position = ctr + Vector3(0, 40, 0) if false else jugador.global_position
			for c in vida._coches:
				if is_instance_valid(c) and c.en_giro and c.curva_t > 0.45 and c.curva_t < 0.6:
					_mirar(c.global_position, 11.0, 5.5, 2.3)
					await _foto("%s_coche_girando" % pe[2])
					hecho = true
					break
	get_tree().quit()
