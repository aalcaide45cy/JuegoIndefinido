# Capturas del mapa grande (N) con el marcador del jugador:
#   godot --windowed --position -20000,-20000 --resolution 1920x1080 --path . res://tests/captura_mapa.tscn -- /carpeta
extends Node


func _guardar(nombre: String, carpeta: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [carpeta, nombre])


func _ready() -> void:
	await get_tree().process_frame
	var carpeta: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	get_tree().root.add_child(escena)
	for i in 4:
		await get_tree().process_frame
	var J = get_tree().root.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	var jug: Jugador = get_tree().get_first_node_in_group("jugador")
	J.hora = 14.0
	# 1) En la ciudad, mirando al este.
	jug.global_position = Vector3(20, 0.5, 20)
	jug._giro = -PI / 2.0
	var mapa: MapaGrande = MapaGrande.new()
	mapa.jugador = jug
	hud._abrir_menu(mapa)
	await _guardar("1_ciudad", carpeta)
	mapa._cambiar_modo()
	await _guardar("2_mundo", carpeta)
	mapa.cerrar()
	# 2) Lejos de la ciudad: debe abrirse en el mapa del mundo.
	jug.global_position = Vector3(-2500, 0.5, 1800)
	jug._giro = PI * 0.75
	var mapa2: MapaGrande = MapaGrande.new()
	mapa2.jugador = jug
	hud._abrir_menu(mapa2)
	await _guardar("3_lejos_abre_mundo", carpeta)
	print("abre en modo mundo: ", mapa2._modo_mundo)
	mapa2._cambiar_modo()
	await _guardar("4_lejos_en_ciudad_borde", carpeta)
	get_tree().quit()
