# Capturas del menú de ajustes y de la linterna con distintos valores (ventana fuera de pantalla):
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_ajustes.tscn -- <carpeta>
extends Node

var carpeta: String = "."


func _foto(nombre: String) -> void:
	for i in 3:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	DirAccess.make_dir_recursive_absolute(carpeta)
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
	var jug = hud.jugador
	J.velocidad_tiempo = 0.0
	J.hora = 23.0
	jug.global_position = Vector3(0, 0.5, 14)
	jug.velocity = Vector3.ZERO
	jug._giro = 0.0
	jug._inclinacion = -0.12
	jug.poner_linterna(true)
	await get_tree().create_timer(4.0).timeout
	await _foto("1_linterna_de_serie")
	AjustesMundo.aplicar({"linterna_energia": 12.0, "linterna_alcance": 70.0, "linterna_angulo": 55.0, "linterna_color": "9fd0ff"})
	await get_tree().create_timer(1.0).timeout
	await _foto("2_linterna_potente_azul")
	AjustesMundo.guardar("Linterna azul potente")
	AjustesMundo.cargar("Predeterminado")
	await get_tree().create_timer(1.0).timeout
	await _foto("3_tras_cargar_predeterminado")
	AjustesMundo.cargar("Linterna azul potente")
	# El menú, abierto de verdad con F1 > botón.
	hud._abrir_menu(Ventanas.Admin.new())
	await get_tree().process_frame
	var v: VentanaAjustes = VentanaAjustes.new()
	hud._menu.add_child(v)
	v._refrescar()
	v._lista.select(1)
	v._mensaje.text = "Preset «Linterna azul potente» guardado."
	await _foto("4_menu_ajustes")
	AjustesMundo.borrar("Linterna azul potente")
	print("FIN")
	get_tree().quit()
