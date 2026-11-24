# Capturas de la magia: grimorio, barra de maná y un hechizo lanzado de noche en la plaza.
#   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 res://tests/captura_magia.tscn -- /carpeta
extends Node

var carpeta: String = "."


func _foto(nombre: String) -> void:
	for i in 3:
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
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	Juego.reiniciar()
	Juego.velocidad_tiempo = 0.0
	Juego.hora = 22.0
	Juego.policia_activa = false
	var M: Node = raiz.get_node("Magia")
	M.xp = {"naturaleza": 300.0, "ilusion": 90.0, "fuerza": 700.0, "sombras": 40.0}
	var j: Node3D = hud.jugador
	j.global_position = Vector3(6.0, 1.0, 14.0)
	j._giro = 0.3
	j._inclinacion = -0.15
	await get_tree().create_timer(4.0).timeout
	var v: VentanaGrimorio = VentanaGrimorio.new()
	hud._abrir_menu(v)
	await _foto("magia_1_grimorio")
	v.cerrar()
	await get_tree().process_frame
	M.preparar("zancada")
	M.lanzar("zancada")
	await get_tree().create_timer(0.15).timeout
	await _foto("magia_2_hechizo_fuerza")
	await get_tree().create_timer(1.2).timeout
	M.esperas.clear()
	M.lanzar("sanar")
	await get_tree().create_timer(0.15).timeout
	await _foto("magia_3_hechizo_naturaleza_y_mana")
	print("RESULTADO: TODO BIEN")
	get_tree().quit()
