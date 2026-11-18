# Aldeas: cuenta peatones y saca capturas de día y de noche. Ventana fuera de pantalla:
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_aldeas.tscn -- /carpeta
extends Node

var carpeta: String = "."
var jugador: Node3D
var vida: Node


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
	get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.88)


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
	vida = escena.find_children("*", "VidaUrbana", true, false)[0]
	J.velocidad_tiempo = 0.0
	var aldeas: Array = []
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if int(s["tipo"]) == 0 and not bool(s.get("montana", false)):
			aldeas.append(s)
	print("Aldeas: ", aldeas.size())
	var cuantas: int = mini(3, aldeas.size())
	for i in cuantas:
		var s: Dictionary = aldeas[i * 7 % aldeas.size()]
		var p: Vector2 = s["pos"]
		var h: float = GeneradorMundo.altura(p.x, p.y)
		for hora in [12.0, 23.5]:
			J.hora = hora
			_ir(Vector3(p.x + 2.0, h + 1.0, p.y + 22.0), 0.6, -0.12)
			await _esperar(7.0)
			_ir(Vector3(p.x + 2.0, h + 1.0, p.y + 22.0), 0.6, -0.12)
			await _esperar(1.5)
			var cerca: int = 0
			for a in vida._peatones:
				if is_instance_valid(a) and Vector2(a.global_position.x, a.global_position.z).distance_to(p) < 80.0:
					cerca += 1
			print("ALDEA %s hora %.1f: peatones totales %d, a menos de 80 m del centro %d" % [s["nombre"], hora, vida._peatones.size(), cerca])
			await _foto("aldea%d_%s" % [i + 1, "dia" if hora < 20.0 else "noche"])
	get_tree().quit()
