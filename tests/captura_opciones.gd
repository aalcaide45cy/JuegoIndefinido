# Capturas del menú de pausa y de las ventanas de Sonido y juego y Controles.
#   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 res://tests/captura_opciones.tscn -- /carpeta
extends Node

var carpeta: String = "."


func _foto(nombre: String) -> void:
	for i in 4:
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
	Juego.hora = 20.5
	await get_tree().create_timer(4.0).timeout
	var pausa = Ventanas.Pausa.new()
	pausa.jugador = hud.jugador
	hud._abrir_menu(pausa)
	await _foto("opciones_1_menu_pausa")
	var s: VentanaSonido = VentanaSonido.new()
	pausa.add_child(s)
	await _foto("opciones_2_sonido_y_juego")
	s.cerrar()
	var c: VentanaControles = VentanaControles.new()
	pausa.add_child(c)
	await get_tree().process_frame
	c._empezar("usar")
	await _foto("opciones_3_controles")
	print("RESULTADO: TODO BIEN")
	get_tree().quit()
