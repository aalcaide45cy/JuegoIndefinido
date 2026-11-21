# Captura de sangre, charcos y trozos. Ventana fuera de pantalla:
#   godot --path . --windowed --position -20000,-20000 --resolution 1280x720 res://tests/captura_gore.tscn -- carpeta
extends Node


func _foto(carpeta: String, nombre: String) -> void:
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)
	print("FOTO ", nombre)


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var carpeta: String = args[0] if args.size() > 0 else "."
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	for i in 3:
		await get_tree().process_frame
	var J = raiz.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	J.velocidad_tiempo = 0.0
	J.hora = 14.0
	var jugador = hud.jugador
	await get_tree().create_timer(4.0).timeout
	var base: Vector3 = jugador.global_position
	var fwd: Vector3 = -jugador.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var pos: Vector3 = base + fwd * 4.0
	var gu: Guardia = Guardia.new()
	gu.pasea_ciudad = false
	gu.ruta = [pos]
	escena.add_child(gu)
	await get_tree().process_frame
	gu._poner_activo(true)
	gu.global_position = pos
	await get_tree().create_timer(1.0).timeout
	gu.recibir_dano(500.0)
	Gore.muerte(escena, pos, fwd, 2.2)
	await get_tree().create_timer(0.4).timeout
	await _foto(carpeta, "gore_1_muerte")
	await get_tree().create_timer(3.0).timeout
	await _foto(carpeta, "gore_2_charco")
	get_tree().quit()
