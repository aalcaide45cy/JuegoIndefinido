# Capturas de estadísticas y barras de vida. Con xvfb:
#   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/captura_estadisticas.tscn -- /carpeta
extends Node

var carpeta: String = "."


func _foto(nombre: String) -> void:
	for i in 4:
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)
	print("FOTO ", nombre)


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().create_timer(2.0).timeout
	var J = raiz.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	var jugador = hud.jugador
	J.hora = 13.0
	J.velocidad_tiempo = 0.0
	J.resistencia = 55.0
	J.hambre = 82.0
	J.sed = 40.0
	J.vida = 70.0
	J.cambio.emit()
	await get_tree().create_timer(1.0).timeout
	await _foto("est_1_panel_vitales")
	# Un guardia herido con su barra.
	var guardias: Array = get_tree().get_nodes_in_group("guardias")
	if guardias.is_empty():
		print("sin guardias")
		get_tree().quit()
		return
	var g: Node3D = guardias[0]
	g.visible = true
	var gp: Vector3 = g.global_position
	jugador.global_position = gp + Vector3(0, 0.5, 5.0)
	jugador.velocity = Vector3.ZERO
	jugador._giro = atan2(0.0, -1.0) + PI
	jugador._inclinacion = -0.05
	await get_tree().create_timer(0.5).timeout
	g.recibir_dano(22.0)
	await _foto("est_2_guardia_herido_barra")
	get_tree().quit()
