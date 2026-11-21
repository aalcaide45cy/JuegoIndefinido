# Saca capturas de las ventanas nuevas (necesita pantalla virtual):
#   xvfb-run -a godot --path . res://tests/captura_ui.tscn -- /ruta/carpeta
extends Node


func _guardar(nombre: String, carpeta: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [carpeta, nombre])


func _ready() -> void:
	await get_tree().process_frame
	var carpeta: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
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
	J.nivel = 9
	for id in ["hierba_bruma", "hierba_raiz_ardiente", "hierba_musgo_dulce", "aditivo_miel", "aditivo_sal", "aditivo_azufre", "hierba_flor_sol", "hierba_lirio_lunar"]:
		J.anadir(id, 4)
	J.anadir("botiquin", 2)
	J.anadir("antidoto", 2)
	J.anadir("cafe", 3)
	J.hora = 22.0
	J.vida = 55.0
	J.aplicar_efecto("velocidad", 70.0)
	J.aplicar_efecto("regeneracion", 30.0)
	J.aplicar_efecto("mareo", 40.0)
	J.aplicar_efecto("veneno", 25.0)
	await _guardar("1_hud_efectos", carpeta)
	hud.abrir_caldero()
	var cal = hud._menu
	for i in 3:
		var it: String = ["hierba_musgo_dulce", "aditivo_miel", "hierba_flor_sol"][i]
		J.quitar(it)
		cal._slots[i] = {"id": it, "cantidad": 1}
	var id_p: String = GameData.buscar_pocion(["hierba_musgo_dulce", "aditivo_miel", "hierba_flor_sol"])
	J.descubrir_receta(id_p)
	J.descubrir_receta(GameData.buscar_pocion(["hierba_bruma", "aditivo_sal"]))
	cal._reconstruir_recetas()
	J.cambio.emit()
	await _guardar("2_caldero", carpeta)
	cal.cerrar()
	hud.abrir_medico()
	await _guardar("3_medico", carpeta)
	hud._menu.cerrar()
	hud.abrir_tienda("botica", "Botica de prueba")
	await _guardar("4_botica", carpeta)
	get_tree().quit()
