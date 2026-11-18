# Capturas del chat (ventana fuera de pantalla):
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_chat.tscn -- <carpeta>
extends Node

var carpeta: String = "."


func _foto(nombre: String) -> void:
	await get_tree().create_timer(0.5).timeout
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)


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
	J.hora = 12.0
	J.velocidad_tiempo = 0.0
	J.dinero = 1500
	hud.jugador.global_position = Vector3(0, 0.5, 8)
	Chat.simulacion = false
	Chat.limpiar()
	await get_tree().create_timer(2.0).timeout
	Chat.servidor.mover(101, Chat.servidor.jugadores[1]["pos"] + Vector3(8, 0, 0))
	Chat.servidor.mover(102, Chat.servidor.jugadores[1]["pos"] + Vector3(15, 0, 0))
	Chat.servidor.mover(103, Chat.servidor.jugadores[1]["pos"] + Vector3(70, 0, 0))
	Chat._reloj = 1000.0
	var guion: Array = [
		[101, Canales.Id.CERCANO, "¿Alguien sabe dónde compran hoja de bruma hoy?", ""],
		[1, Canales.Id.CERCANO, "En la herboristería de la plaza, Marta.", ""],
		[102, Canales.Id.GRUPO, "Tengo dos tónicos para tu encargo.", ""],
		[103, Canales.Id.FACCION, "La Bruma pide silencio esta noche.", ""],
		[103, Canales.Id.GRITAR, "¡Redada en el mercado!", ""],
		[101, Canales.Id.PRIVADO, "Oye, ¿sigues vendiendo? Te pago bien.", "Forastero"],
		[1, Canales.Id.PRIVADO, "Claro, pásate por mi casa.", "Marta"],
	]
	for g in guion:
		Chat._reloj += 3.0
		Chat._atender(int(g[0]), int(g[1]), String(g[2]), String(g[3]))
	Chat.sistema("Cobras 120 $ de alquileres.", "cobros")
	Chat.sistema("Mensaje de Dani (Ciudad): quiere 2 x Tónico de la Sombra Propia.", "encargos")
	Chat.sistema("Búsqueda policial: ★★", "policia")
	Chat.sistema("Cosecha lista: Hoja de Bruma (x4).", "cosechas")
	await _foto("chat_1_activo_todo")
	var panel = hud._chat
	panel.abrir()
	panel._entrada.text = "Voy para allá, ¿quedamos en la plaza?"
	await _foto("chat_2_escribiendo")
	panel._elegir_pestana(Canales.Id.PRIVADO)
	await _foto("chat_3_privado")
	panel._elegir_pestana(Canales.Id.SISTEMA)
	await _foto("chat_4_sistema")
	panel._elegir_pestana(Canales.Id.TODO)
	panel._alternar_ajustes()
	await _foto("chat_5_ajustes")
	panel._alternar_ajustes()
	panel.cerrar()
	await get_tree().create_timer(12.0).timeout
	await _foto("chat_6_en_reposo")
	print("FIN")
	get_tree().quit()
