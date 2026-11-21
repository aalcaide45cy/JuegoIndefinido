# Prueba y capturas del "Aparecer cualquier cosa" del panel admin.
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 res://tests/captura_admin.tscn -- /carpeta
extends Node

var fallos: int = 0


func _ok(cond: bool, texto: String) -> void:
	print(("OK    " if cond else "FALLO ") + texto)
	if not cond:
		fallos += 1


func _foto(nombre: String, carpeta: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [carpeta, nombre])
	print("FOTO ", nombre)


func _ready() -> void:
	await get_tree().process_frame
	var carpeta: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "."
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	get_tree().root.add_child(escena)
	for i in 6:
		await get_tree().process_frame
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	var J = get_tree().root.get_node("Juego")
	J.reiniciar()
	J.hora = 14.0
	var jug: Node3D = get_tree().get_first_node_in_group("jugador")
	for i in 30:
		await get_tree().physics_frame

	# Catálogo.
	var todas: Array = AdminCatalogo.entradas()
	print("Entradas: ", todas.size(), "  categorías: ", AdminCatalogo.categorias())
	_ok(todas.size() > 60, "catálogo con más de 60 entradas")
	_ok(AdminCatalogo.entradas("", "pistola").size() >= 1, "buscador encuentra la pistola")
	_ok(AdminCatalogo.entradas(AdminCatalogo.CAT_ARMAS).size() >= 10, "categoría armas")
	var ejecutado: Array = [false]
	AdminCatalogo.registrar("prueba", "Cosa de prueba", "Explosivos",
			func(c: int, s: bool, _j: Node3D) -> String:
				ejecutado[0] = true
				return "ok %d %s" % [c, s])
	_ok(AdminCatalogo.entradas("", "cosa de prueba").size() == 1, "registro de entrada propia")
	AdminCatalogo.dar(AdminCatalogo.entradas("", "cosa de prueba")[0], 3, false, jug)
	_ok(ejecutado[0], "la acción registrada se ejecuta")
	AdminCatalogo.quitar_registro("prueba")

	# Acciones.
	AdminCatalogo.dar_objeto("cuchillo", 1, false, jug)
	_ok(J.tiene("cuchillo"), "objeto al inventario")
	var msg: String = AdminCatalogo.equipar("pistola")
	print(msg)
	_ok(J.id_en_mano() == "pistola", "pistola equipada en la mano")
	_ok(int(J.en_mano().get("balas", 0)) == 12, "pistola cargada")
	_ok(J.cuenta("municion_pistola") >= 48, "munición de reserva")
	AdminCatalogo.dar_municion(30)
	var d0: int = J.dinero
	for e in AdminCatalogo.entradas(AdminCatalogo.CAT_DINERO):
		if e["clave"] == "d:1000":
			AdminCatalogo.dar(e, 2, false, jug)
	_ok(J.dinero == d0 + 2000, "dinero limpio")
	var antes: int = get_tree().get_nodes_in_group("interactuable").size()
	AdminCatalogo.dar_objeto("granada", 3, true, jug)
	_ok(get_tree().get_nodes_in_group("interactuable").size() == antes + 1, "objeto en el suelo")
	var suelo: Array = get_tree().get_nodes_in_group("interactuable").filter(func(n): return n is ObjetoSuelo)
	_ok(suelo.size() == 1, "ObjetoSuelo creado")
	suelo[0].usar(jug)
	_ok(J.cuenta("granada") == 3, "coger del suelo")
	AdminCatalogo.dar_vehiculo("sedan", jug)
	_ok(J.vehiculos.size() >= 1, "vehículo aparece")
	for tipo in ["guardia", "maton", "jefe", "recluta", "vecino"]:
		var n0: int = jug.get_parent().get_child_count()
		AdminCatalogo.dar_npc(tipo, 1, jug)
		_ok(jug.get_parent().get_child_count() == n0 + 1, "PNJ " + tipo)
	for e in AdminCatalogo.entradas(AdminCatalogo.CAT_ROPA):
		if e["id"] == "sombrero:1":
			AdminCatalogo.dar(e, 1, false, jug)
	_ok(int(J.aspecto.get("sombrero", 0)) == 1, "ropa")
	for i in 20:
		await get_tree().physics_frame

	# Capturas de la ventana.
	var v: VentanaObjetosAdmin = VentanaObjetosAdmin.new()
	v.jugador = jug
	hud._abrir_menu(v)
	await _foto("1_aparecer_todo", carpeta)
	v._buscador.text = "pis"
	v._rellenar()
	await _foto("2_buscador_pis", carpeta)
	v._buscador.text = ""
	v._elegir_categoria(AdminCatalogo.CAT_ARMAS)
	await _foto("3_armas", carpeta)
	v._elegir_categoria(AdminCatalogo.CAT_NPC)
	await _foto("4_npc", carpeta)
	v.cerrar()
	for i in 10:
		await get_tree().process_frame
	await _foto("5_mundo_con_cosas", carpeta)
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit()
