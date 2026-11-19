# Capturas de la plaza, paredes, linterna y zonas verdes (ventana fuera de pantalla):
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_plaza.tscn -- <carpeta> <prefijo> [filtro]
extends Node

var carpeta: String = "."
var jugador: Node3D
var J


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)


func _ir(pos: Vector3, giro: float, incl: float) -> void:
	jugador.global_position = pos
	jugador.velocity = Vector3.ZERO
	jugador._giro = giro
	jugador._inclinacion = incl


func _sitios() -> Array:
	# [nombre, posición, giro, inclinación, hora, linterna]
	var out: Array = [
		["plaza_dia", Vector3(0, 0.5, 14), 0.0, -0.12, 12.0, false],
		["plaza_fuente_cerca", Vector3(6, 0.5, 7), 0.8, -0.2, 12.0, false],
		["plaza_alta", Vector3(0, 12, 26), 0.0, -0.5, 12.0, false],
		["plaza_noche", Vector3(0, 0.5, 14), 0.0, -0.12, 22.5, false],
		["plaza_noche_linterna", Vector3(0, 0.5, 14), 0.0, -0.12, 23.0, true],
		["pared_herboristeria", Vector3(-2.5, 1.6, -15.5), 0.35, -0.05, 12.0, false],
		["pared_vivienda", Vector3(15.0, 1.6, -3.0), -1.0, -0.05, 12.0, false],
		["pared_lejos", Vector3(-14, 1.6, 6), 0.25, 0.0, 12.0, false],
		["calle_noche_linterna", Vector3(16, 0.5, -45), 0.0, -0.1, 23.0, true],
	]
	for s in GeneradorMundo.todos_asentamientos():
		if int(s["tipo"]) == 2 and not bool(s.get("montana", false)):
			var p: Vector2 = s["pos"]
			var h: float = GeneradorMundo.altura(p.x, p.y)
			out.append(["ciudad_plaza_mayor", Vector3(p.x + 40.0, h + 1.2, p.y + 40.0), 2.35, -0.15, 12.0, false])
			out.append(["ciudad_plaza_mayor_alta", Vector3(p.x + 20.0, h + 45.0, p.y + 60.0), 0.3, -0.6, 12.0, false])
			out.append(["ciudad_plaza_mayor_noche", Vector3(p.x + 40.0, h + 1.2, p.y + 40.0), 2.35, -0.15, 22.5, true])
			break
	return out


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	var pref: String = args[1] if args.size() > 1 else "x"
	var filtro: String = args[2] if args.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(carpeta)
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
	J.velocidad_tiempo = 0.0
	print("RENDER ", get_window().size)
	for s in _sitios():
		if filtro != "" and not (s[0] as String).contains(filtro):
			continue
		J.hora = s[4]
		_ir(s[1], s[2], s[3])
		if jugador.has_method("poner_linterna"):
			jugador.poner_linterna(s[5])
		await _esperar(4.0)
		_ir(s[1], s[2], s[3])
		await _esperar(1.0)
		var t0: int = Time.get_ticks_usec()
		for i in 120:
			await get_tree().process_frame
		print("MS|%s|%.2f" % [s[0], float(Time.get_ticks_usec() - t0) / 1000.0 / 120.0])
		await _foto("%s_%s" % [pref, s[0]])
		print("FOTO ", s[0])
	print("FIN")
	get_tree().quit()
