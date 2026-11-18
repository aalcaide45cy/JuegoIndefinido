# Capturas del dinero limpio/negro (necesita render):
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 res://tests/captura_dinero.tscn -- carpeta
extends Node


func _guardar(nombre: String, carpeta: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [carpeta, nombre])


func _panel(hud) -> PanelNegocios:
	return hud._menu.find_children("*", "PanelNegocios", true, false)[0]


func _ready() -> void:
	await get_tree().process_frame
	var carpeta: String = OS.get_cmdline_user_args()[0]
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
	J.nivel = 6
	J.dinero = 1850
	J.dinero_negro = 2400
	J.hora = 14.0
	Negocios.estado()["licencias"]["tienda"] = true
	Negocios.estado()["licencias"]["inmobiliaria"] = true
	Negocios.estado()["licencias"]["concesionario"] = true
	J.cambio.emit()
	await _guardar("1_hud_dinero_limpio_y_negro", carpeta)
	hud.abrir_ventana(VentanaNegocios.new())
	await get_tree().process_frame
	_panel(hud)._ir("lavado")
	await _guardar("2_lavado_antes", carpeta)
	Blanqueo.blanquear("tienda", 300)
	Blanqueo.blanquear("inmobiliaria", 1000)
	_panel(hud)._pintar()
	await _guardar("3_lavado_despues_vigilancia_sube", carpeta)
	hud._menu.cerrar()
	J.vigilancia_fiscal = 85.0
	J.sospecha = 55.0
	hud.abrir_cacheo()
	await _guardar("4_cacheo_con_dinero_negro", carpeta)
	hud._menu.cerrar()
	J.dinero_negro = 2400
	Blanqueo.inspeccion()
	await _guardar("5_inspeccion_y_estrellas", carpeta)
	get_tree().quit()
