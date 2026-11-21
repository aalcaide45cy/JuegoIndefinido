# Economía por región: las regiones se detectan bien y pagan / piden distinto.
#   godot --headless --path . res://tests/prueba_regiones.tscn
extends Node

var fallos: int = 0


func comprobar(c: bool, t: String) -> void:
	if not c:
		fallos += 1
		print("FALLO: ", t)


func _ready() -> void:
	await get_tree().process_frame
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	var J = raiz.get_node("Juego")
	J.reiniciar()
	comprobar(Regiones.de_posicion(0, 0)["id"] == "ciudad_original", "el origen es la ciudad original")
	var vistos: Dictionary = {}
	for s in GeneradorMundo.todos_asentamientos():
		var p: Vector2 = s["pos"]
		var r: Dictionary = Regiones.de_posicion(p.x, p.y)
		vistos[r["id"]] = true
		if bool(s.get("montana", false)):
			continue
		var esperado: String = ["aldea", "pueblo", "ciudad"][int(s["tipo"])]
		comprobar(r["id"] == esperado, "%s debería ser %s y sale %s" % [s["nombre"], esperado, r["id"]])
	print("Regiones vistas en asentamientos: ", vistos.keys())
	# Pociones pedidas: ciudad (caras) vs aldea (baratas).
	var ids: Array = GameData.pedibles()
	var suma_c: float = 0.0
	var suma_a: float = 0.0
	for i in 200:
		suma_c += float(GameData.pocion(Regiones.elegir_pocion(ids, "caras"))["precio"])
		suma_a += float(GameData.pocion(Regiones.elegir_pocion(ids, "baratas"))["precio"])
	print("Precio medio pedido: ciudad %.1f, aldea %.1f" % [suma_c / 200.0, suma_a / 200.0])
	comprobar(suma_c > suma_a, "la ciudad pide pociones más caras que la aldea")
	# Una oferta creada con el jugador en la ciudad original lleva su región.
	Encargos_probar(J)
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit()


func Encargos_probar(J) -> void:
	var enc: Node = null
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("_crear_oferta"):
			enc = n
			break
	comprobar(enc != null, "existe el gestor de encargos")
	if enc == null:
		return
	J.encargos.clear()
	enc._crear_oferta()
	comprobar(J.encargos.size() == 1 and J.encargos[0].get("region", "") == "Ciudad original", "el encargo apunta su región: %s" % str(J.encargos[0].get("region", "")))
