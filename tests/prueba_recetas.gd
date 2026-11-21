# Prueba automática del sistema de recetas, efectos y curación.
# Se ejecuta SIN abrir el juego:
#   godot --headless --path . --script res://tests/prueba_recetas.gd
extends SceneTree

var fallos: int = 0


func comprobar(condicion: bool, texto: String) -> void:
	if not condicion:
		fallos += 1
		print("FALLO: ", texto)


func _initialize() -> void:
	var Mezclas = load("res://scripts/datos/mezclas.gd")
	var Efectos = load("res://scripts/datos/efectos.gd")
	var Objetos = load("res://scripts/datos/objetos.gd")
	print("Combinaciones posibles: ", Mezclas.total_combinaciones())
	comprobar(Mezclas.total_combinaciones() > 7000, "debería haber más de 7000 combinaciones")

	# Pociones de autor: el orden no importa.
	comprobar(Mezclas.buscar(["hierba_bruma", "hierba_bruma"]) == "humo", "bruma+bruma = humo")
	comprobar(Mezclas.buscar(["hierba_sepulcral", "hierba_bruma"]) == "sueno", "orden da igual")
	# Mezclas generadas.
	var a: String = Mezclas.buscar(["hierba_bruma", "aditivo_miel", "hierba_raiz_ardiente"])
	var b: String = Mezclas.buscar(["hierba_raiz_ardiente", "hierba_bruma", "aditivo_miel"])
	comprobar(a == b and a.begins_with("m_"), "misma mezcla, mismo id: " + a)
	comprobar(Mezclas.buscar(["hierba_bruma"]) == "", "una sola cosa no es mezcla")
	comprobar(Mezclas.buscar(["hierba_bruma", "tierra"]) == "", "la tierra no es ingrediente")
	comprobar(Mezclas.buscar(["hierba_bruma", "hierba_bruma", "hierba_bruma", "hierba_bruma", "hierba_bruma"]) == "", "máx 4")
	comprobar(Mezclas.es_valida(a), "es válida")
	comprobar(not Mezclas.es_valida("m_cosa+rara"), "id inventado no es válido")
	comprobar(not Mezclas.es_valida("m_miel+bruma"), "id no canónico no es válido")

	# Recorre TODAS las mezclas y comprueba que cada una da una poción coherente.
	var ids: Array = Mezclas.INGREDIENTES.keys()
	var total: int = 0
	var nombres: Dictionary = {}
	var solo_malas: int = 0
	var precios_min: int = 99999
	var precios_max: int = 0
	var por_efecto: Dictionary = {}
	var combos: Array = []
	for i in ids.size():
		for j in range(i, ids.size()):
			combos.append([ids[i], ids[j]])
			for k in range(j, ids.size()):
				combos.append([ids[i], ids[j], ids[k]])
				for l in range(k, ids.size()):
					combos.append([ids[i], ids[j], ids[k], ids[l]])
	var t0: int = Time.get_ticks_msec()
	for c in combos:
		var id: String = Mezclas.buscar(c)
		if id == "":
			comprobar(false, "sin resultado: " + str(c))
			continue
		total += 1
		var info: Dictionary = Mezclas.info(id)
		comprobar(not info.is_empty(), "sin info " + id)
		if info.is_empty():
			continue
		comprobar(info["efectos"].size() >= 1 and info["efectos"].size() <= 3, "efectos 1-3 en " + id)
		for e in info["efectos"] + info["secundarios"]:
			comprobar(Efectos.existe(e["id"]), "efecto desconocido en " + id)
			comprobar(e["dur"] >= 10.0 and e["f"] > 0.0, "duración/fuerza rara en " + id)
			por_efecto[e["id"]] = int(por_efecto.get(e["id"], 0)) + 1
		comprobar(info["precio"] >= 5, "precio " + id)
		precios_min = mini(precios_min, info["precio"])
		precios_max = maxi(precios_max, info["precio"])
		# El objeto de inventario existe y es coherente.
		var obj: Dictionary = Objetos.datos("pocion_" + id)
		comprobar(obj["tipo"] == "pocion" and obj["pila"] > 0, "objeto pocion " + id)
		comprobar(Objetos.existe("paquete_" + id), "paquete " + id)
		comprobar(Mezclas.es_valida(id), "válida " + id)
		nombres[info["nombre"]] = int(nombres.get(info["nombre"], 0)) + 1
		if info["efectos"].size() > 0 and not Efectos.es_bueno(info["efectos"][0]["id"]):
			solo_malas += 1
	print("Mezclas probadas: ", total, " en ", Time.get_ticks_msec() - t0, " ms")
	print("Nombres distintos: ", nombres.size(), " de ", total)
	print("Mezclas solo malas (venenos): ", solo_malas)
	print("Precio: ", precios_min, " a ", precios_max)
	print("Veces que sale cada efecto: ", por_efecto)
	comprobar(total == Mezclas.total_combinaciones(), "total de combinaciones = %d vs %d" % [total, Mezclas.total_combinaciones()])
	comprobar(nombres.size() > total * 0.6, "demasiados nombres repetidos")

	# Ejemplos para leer.
	for c in [["hierba_bruma", "hierba_raiz_ardiente"], ["hierba_ortiga_negra", "hierba_musgo_dulce"],
			["hierba_lirio_lunar", "aditivo_miel", "aditivo_sal"], ["aditivo_arsenico", "aditivo_arsenico"],
			["hierba_cardo_hierro", "hierba_flor_sol", "hierba_musgo_dulce", "aditivo_miel"]]:
		var id2: String = Mezclas.buscar(c)
		var inf: Dictionary = Mezclas.info(id2)
		print("  ", c, " -> ", inf["nombre"], " (", inf["precio"], " $)  ", inf["resumen"])

	# Objetos de efectos y curación: todos con datos válidos.
	for id in Objetos.LISTA:
		var d: Dictionary = Objetos.LISTA[id]
		for e in d.get("efectos", []):
			comprobar(Efectos.existe(e["id"]), "efecto desconocido en objeto " + id)
		for q in d.get("quita", []):
			comprobar(Efectos.existe(q), "quita desconocido en " + id)
	for id in Objetos.LISTA:
		if id.begins_with("semilla_") and Objetos.LISTA[id].has("hierba"):
			comprobar(GameData.HIERBAS.has(Objetos.LISTA[id]["hierba"]), "semilla sin hierba: " + id)
			comprobar(Objetos.LISTA.has("hierba_" + Objetos.LISTA[id]["hierba"]), "falta hierba_ de " + id)
	for id in Mezclas.INGREDIENTES:
		comprobar(Objetos.LISTA.has(id), "ingrediente sin objeto: " + id)

	# Efectos en Juego.
	var J = root.get_node_or_null("Juego")
	comprobar(J != null, "no hay autoload Juego")
	if J != null:
		J.reiniciar()
		J.aplicar_efecto("velocidad", 10.0, 1.0)
		comprobar(absf(J.mod("velocidad") - 0.35) < 0.001, "mod velocidad")
		J.aplicar_efecto("lentitud", 10.0, 1.0)
		comprobar(absf(J.mod("velocidad")) < 0.001, "velocidad + lentitud se anulan")
		J.efectos_activos.clear()
		J.vida = 50.0
		J.aplicar_efecto("resistencia", 10.0)
		J.cambiar_vida(-10.0)
		comprobar(absf(J.vida - 44.0) < 0.01, "resistencia reduce daño: %f" % J.vida)
		J.efectos_activos.clear()
		J.vida = 50.0
		J.aplicar_efecto("regeneracion", 10.0)
		J._avanzar_efectos(2.0)
		comprobar(J.vida > 52.0, "regeneración cura")
		J._avanzar_efectos(20.0)
		comprobar(J.efectos_activos.is_empty(), "los efectos caducan")
		J.vida = 3.0
		J.aplicar_efecto("veneno", 10.0)
		J._avanzar_efectos(9.0)
		comprobar(J.vida >= 1.0, "el veneno no mata")
		J.efectos_activos.clear()
		# Beber una poción generada.
		J.reiniciar()
		J.inventario[0] = {"id": "pocion_" + a, "cantidad": 2}
		J.seleccion = 0
		J.usar_en_mano()
		comprobar(J.inventario[0]["cantidad"] == 1, "beber gasta una")
		comprobar(not J.efectos_activos.is_empty(), "beber da efectos")
		print("Efectos tras beber: ", J.efectos_activos)
		# Curar.
		J.efectos_activos.clear()
		J.vida = 40.0
		J.inventario[1] = {"id": "botiquin", "cantidad": 1}
		J.seleccion = 1
		J.aplicar_efecto("veneno", 10.0)
		J.usar_en_mano()
		comprobar(absf(J.vida - 100.0) < 0.01 or J.vida >= 99.0, "botiquín cura 60: %f" % J.vida)
		comprobar(not J.efectos_activos.has("veneno"), "botiquín quita veneno")
		comprobar(J.inventario[1] == null, "botiquín gastado")
		# Con vida completa no se gasta.
		J.vida = 100.0
		J.inventario[2] = {"id": "pan", "cantidad": 1}
		J.seleccion = 2
		J.usar_en_mano()
		comprobar(J.inventario[2] != null, "con vida completa no se gasta el pan")
		# Recetario.
		comprobar(J.descubrir_receta(a), "primera vez es nueva")
		comprobar(not J.descubrir_receta(a), "segunda vez no")
		comprobar(J.recetario.has(a), "la receta queda en el recetario")
		comprobar(Mezclas.max_ingredientes(1) == 2 and Mezclas.max_ingredientes(6) == 3 and Mezclas.max_ingredientes(9) == 4, "casillas por nivel")

	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	quit(1 if fallos > 0 else 0)
