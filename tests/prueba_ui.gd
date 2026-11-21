# Prueba automática de las ventanas nuevas (caldero, médico, admin), la cama y el
# guardado. Abre el mundo de verdad (sin ventana). Se ejecuta con:
#   godot --headless --path . res://tests/prueba_ui.tscn
extends Node

var fallos: int = 0


func comprobar(condicion: bool, texto: String) -> void:
	if not condicion:
		fallos += 1
		print("FALLO: ", texto)


func _ready() -> void:
	await get_tree().process_frame
	await _probar()


func _probar() -> void:
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	var J = raiz.get_node("Juego")
	var huds: Array = escena.find_children("*", "Hud", true, false)
	comprobar(huds.size() == 1, "hay un HUD")
	var hud = huds[0]
	var jugador = hud.jugador
	comprobar(jugador != null, "hay jugador")
	# Cerrar el menú inicial.
	if hud._menu != null:
		hud._menu.cerrar()
	await get_tree().process_frame
	J.reiniciar()
	J.nivel = 9
	for id in ["hierba_bruma", "hierba_raiz_ardiente", "aditivo_miel", "aditivo_sal", "aditivo_azufre"]:
		J.anadir(id, 5)
	J.dinero = 5000

	# Caldero.
	hud.abrir_caldero()
	await get_tree().process_frame
	var cal = hud._menu
	comprobar(cal != null and cal.get_class() != "", "caldero abierto")
	comprobar(cal._slots.size() == 4, "nivel 9 = 4 casillas, hay %d" % cal._slots.size())
	var objetos: Array = ["hierba_bruma", "aditivo_miel", "hierba_raiz_ardiente"]
	for i in objetos.size():
		J.quitar(objetos[i])
		cal._slots[i] = {"id": objetos[i], "cantidad": 1}
	J.cambio.emit()
	await get_tree().process_frame
	var id_p: String = GameData.buscar_pocion(objetos)
	comprobar(id_p.begins_with("m_"), "mezcla generada " + id_p)
	cal._terminar_cocinado(3, id_p)
	await get_tree().process_frame
	comprobar(J.recetario.has(id_p), "receta apuntada")
	comprobar(J.cuenta("pocion_" + id_p) == 3, "3 pociones perfectas")
	comprobar(cal._botones_receta.has(id_p), "la receta sale en la lista")
	print("Resultado caldero: ", cal._resultado.text)
	comprobar(GameData.pedibles().has(id_p), "se puede pedir")
	cal.cerrar()
	await get_tree().process_frame

	# Beber.
	for i in J.inventario.size():
		if J.inventario[i] != null and J.inventario[i]["id"] == "pocion_" + id_p:
			J.seleccion = i
	J.vida = 100.0
	J.usar_en_mano()
	comprobar(J.efectos_activos.size() >= 1, "efectos tras beber")
	await get_tree().process_frame
	await get_tree().process_frame
	# Guardar y cargar con efectos.
	var antes: Dictionary = J.efectos_activos.duplicate(true)
	comprobar(Guardado.guardar(get_tree(), jugador), "guardar")
	J.efectos_activos.clear()
	J.recetario.clear()
	comprobar(Guardado.cargar(get_tree(), jugador), "cargar")
	var k1: Array = J.efectos_activos.keys()
	var k2: Array = antes.keys()
	k1.sort()
	k2.sort()
	comprobar(k1 == k2, "efectos restaurados %s vs %s" % [k1, k2])
	comprobar(J.recetario.has(id_p), "recetario restaurado")
	comprobar(J.cuenta("pocion_" + id_p) == 2, "pociones restauradas (%d)" % J.cuenta("pocion_" + id_p))

	# Médico.
	J.vida = 20.0
	J.aplicar_efecto("veneno", 50.0)
	hud.abrir_medico()
	await get_tree().process_frame
	comprobar(hud._menu is VentanaMedico, "médico abierto")
	var d0: int = J.dinero
	hud._menu._revision(VentanaMedico.precio_curar() + 45)
	comprobar(J.vida == 100.0 and not J.efectos_activos.has("veneno"), "revisión cura")
	comprobar(J.dinero < d0, "revisión cobra")
	hud._menu.cerrar()
	await get_tree().process_frame

	# Admin y efectos en pantalla (sin errores de script al dibujar).
	hud._abrir_menu(Ventanas.Admin.new())
	await get_tree().process_frame
	comprobar(hud._menu is Ventanas.Admin, "admin abierto")
	hud._menu.cerrar()
	await get_tree().process_frame
	for tienda in ["botica", "herbolario", "panaderia", "ferreteria"]:
		hud.abrir_tienda(tienda, "Prueba")
		await get_tree().process_frame
		comprobar(hud._menu is Ventanas.Tienda, "tienda " + tienda)
		hud._menu.cerrar()
		await get_tree().process_frame
	# Cama: al dormir se cura y se pasan los efectos malos.
	J.vida = 30.0
	J.aplicar_efecto("veneno", 50.0)
	for n in escena.find_children("*", "Interactuable", true, false):
		if n.texto_accion().begins_with("Dormir"):
			n.usar(jugador)
			break
	for i in 120:
		await get_tree().process_frame
	comprobar(J.vida == 100.0 and not J.efectos_activos.has("veneno"), "dormir cura (vida %f)" % J.vida)
	J.aplicar_efecto("mareo", 30.0)
	J.aplicar_efecto("vision", 30.0)
	for i in 5:
		await get_tree().process_frame
	comprobar(hud._efectos_pantalla.visible, "efectos de pantalla visibles")

	# Cama.
	var camas: Array = escena.find_children("*", "Interactuable", true, false).filter(
			func(n: Node) -> bool: return n.get_script() != null and n.get_script().get_global_name() == &"" and n.has_method("texto_accion") and n.texto_accion().begins_with("Dormir"))
	print("Camas encontradas: ", camas.size())

	print("RESULTADO UI: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)
