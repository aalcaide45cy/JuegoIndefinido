# Prueba de los negocios con interior (restaurante, bar, cafetería, panadería, taberna, taller). Sin ventana:
#   godot --headless --path . res://tests/prueba_negocios.tscn
# Usa la carpeta de datos del proyecto: ejecútala en un clon con custom_user_dir propio.
extends Node

const Locales = preload("res://scripts/datos/locales.gd")
const CELDA: float = 0.2
const RADIO: float = 0.3

var fallos: int = 0


func comprobar(condicion: bool, texto: String) -> void:
	if not condicion:
		fallos += 1
		print("FALLO: ", texto)


func _ready() -> void:
	await get_tree().process_frame
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
	await get_tree().process_frame

	# --- Datos ---
	var efectos = load("res://scripts/datos/efectos.gd")
	for id in Locales.LOCALES:
		var l: Dictionary = Locales.LOCALES[id]
		comprobar((l["nombres"] as Array).size() >= 3, "%s tiene nombres para la variedad" % id)
		for pid in l["carta"]:
			comprobar(Locales.PRODUCTOS.has(pid), "%s: el producto %s existe" % [id, pid])
			var pr: Dictionary = Locales.PRODUCTOS[pid]
			comprobar(pr.has("nombre") and pr.has("precio"), "%s tiene nombre y precio" % pid)
			if pr.has("magico"):
				comprobar(J.DatosObjetos.existe(str(pr["magico"])), "%s: objeto mágico existe" % pid)
			if pr.has("objeto"):
				comprobar(J.DatosObjetos.existe(str(pr["objeto"])), "%s: objeto para llevar existe" % pid)
			for e in pr.get("efectos", []):
				comprobar(efectos.LISTA.has(str(e["id"])), "%s: efecto %s existe" % [pid, e["id"]])
		comprobar(GeneradorMundo.SERVICIOS_CIUDAD.values().has(id) or GeneradorMundo.SERVICIOS_PUEBLO.values().has(id), "%s está en el mundo" % id)
	var distintos: int = 0
	for s in range(1, 12):
		if Locales.nombre_local("bar", s) != Locales.nombre_local("bar", s + 1) or str(Locales.carta("bar", s)) != str(Locales.carta("bar", s + 1)):
			distintos += 1
	comprobar(distintos >= 8, "los bares se distinguen (%d de 11 cambian)" % distintos)
	comprobar(str(Locales.carta("bar", 5)) == str(Locales.carta("bar", 5)), "la carta de un local es estable")
	var con_dia: int = 0
	for it in Locales.carta("restaurante", 3):
		if bool(it.get("dia", false)):
			con_dia += 1
	comprobar(con_dia == 1, "un plato del día por local")
	comprobar(Locales.abierto("panaderia", 8.0) and not Locales.abierto("panaderia", 20.0), "horario de panadería")
	comprobar(Locales.abierto("bar", 1.0) and not Locales.abierto("bar", 8.0), "el bar pasa de medianoche")

	# --- Mundo: cada local aparece como edificio de servicio ---
	var encontrados: Dictionary = {}
	for s in GeneradorMundo.todos_asentamientos():
		var p: Vector2 = s["pos"]
		var m: float = float(s["mitad"]) + 60.0
		var rect: Rect2 = Rect2(p.x - m, p.y - m, m * 2.0, m * 2.0)
		for c in GeneradorMundo._casas_en(s, rect):
			if c.has("servicio") and Locales.existe(str(c["servicio"])):
				encontrados[c["servicio"]] = int(encontrados.get(c["servicio"], 0)) + 1
				comprobar(float(c["w"]) == float(Locales.LOCALES[c["servicio"]]["ancho"]), "tamaño del edificio de " + str(c["servicio"]))
	for id in Locales.LOCALES:
		comprobar(encontrados.has(id), "el mundo genera un/a " + id)
	print("Edificios de negocio en el mundo: ", encontrados)

	# --- Interiores: nada fuera del local, pasillo libre y el mostrador se alcanza desde la puerta ---
	for id in Locales.LOCALES:
		for semilla in [11, 222, 3333]:
			var sv: ServicioMundo = ServicioMundo.new()
			sv.servicio = id
			sv.position = Vector3(semilla, 1.0, semilla * 2.0)
			escena.add_child(sv)
			var lm: LocalMundo = null
			for h in sv.get_children():
				if h is LocalMundo:
					lm = h
			comprobar(lm != null, "%s crea su interior" % id)
			if lm == null:
				continue
			_comprobar_interior(lm, "%s/%d" % [id, semilla])
			sv.queue_free()
	await get_tree().process_frame

	# --- Pedir comida y bebida ---
	LocalMundo.reiniciar_copas()
	J.hambre = 80.0
	J.sed = 60.0
	J.dinero = 500
	var ensalada: Dictionary = Locales.carta("restaurante", 4)[0]
	var antes: int = J.dinero
	var r: Dictionary = LocalMundo.pedir(ensalada)
	comprobar(bool(r["ok"]) and J.hambre < 80.0 and J.dinero == antes - int(ensalada["precio"]), "pedir una ensalada baja el hambre y cobra")
	J.dinero = 0
	r = LocalMundo.pedir(ensalada)
	comprobar(not bool(r["ok"]) and J.hambre >= 55.0, "sin dinero no se pide")
	J.dinero = 500
	var trucha: Dictionary = (Locales.PRODUCTOS["trucha_bruma"] as Dictionary).duplicate()
	trucha["id"] = "trucha_bruma"
	r = LocalMundo.pedir(trucha)
	comprobar(not bool(r["ok"]) and J.dinero == 500, "el plato mágico exige hoja de bruma")
	J.anadir("hierba_bruma", 2)
	r = LocalMundo.pedir(trucha)
	comprobar(bool(r["ok"]) and J.efectos_activos.has("vision") and J.cuenta("hierba_bruma") == 1, "plato mágico: gasta una hoja y da visión")
	J.resistencia = 20.0
	r = LocalMundo.pedir(Locales.carta("cafeteria", 4)[0])
	comprobar(bool(r["ok"]) and J.resistencia > 20.0, "el café da energía")
	var cerveza: Dictionary = (Locales.PRODUCTOS["cerveza"] as Dictionary).duplicate()
	for i in 3:
		LocalMundo.pedir(cerveza)
	comprobar(not J.efectos_activos.has("mareo"), "tres copas no marean")
	LocalMundo.pedir(cerveza)
	comprobar(J.efectos_activos.has("mareo"), "la cuarta copa marea")
	var pan: Dictionary = (Locales.PRODUCTOS["pan_llevar"] as Dictionary).duplicate()
	var n_pan: int = J.cuenta("pan")
	r = LocalMundo.pedir(pan)
	comprobar(bool(r["ok"]) and J.cuenta("pan") == n_pan + 1, "pan para llevar")

	# --- Taller con un vehículo de mentira ---
	var coche: Node3D = _vehiculo_falso(escena)
	coche.set("salud", 40.0)
	coche.set("gasolina", 30.0)
	var rep: Dictionary = Locales.PRODUCTOS["reparar"]
	var precio_rep: int = LocalMundo.precio_taller(rep, coche)
	comprobar(precio_rep > 0, "precio de reparación (%d)" % precio_rep)
	J.dinero = 500
	r = LocalMundo.pedir(rep, coche)
	comprobar(bool(r["ok"]) and float(coche.get("salud")) == 100.0 and J.dinero == 500 - precio_rep, "reparar arregla y cobra")
	r = LocalMundo.pedir(rep, coche)
	comprobar(not bool(r["ok"]), "no se repara lo que está bien")
	r = LocalMundo.pedir(Locales.PRODUCTOS["repostar"], coche)
	comprobar(bool(r["ok"]) and float(coche.get("gasolina")) == 100.0, "repostar llena el depósito")
	r = LocalMundo.pedir(Locales.PRODUCTOS["repostar"], null)
	comprobar(not bool(r["ok"]), "sin vehículo no hay servicio")
	coche.set("salud", 10.0)
	coche.set("gasolina", 5.0)
	var bruma: Dictionary = Locales.PRODUCTOS["aceite_bruma"]
	J.quitar("hierba_bruma", J.cuenta("hierba_bruma"))
	r = LocalMundo.pedir(bruma, coche)
	comprobar(not bool(r["ok"]), "el aceite de bruma exige hoja")
	J.anadir("hierba_bruma", 1)
	r = LocalMundo.pedir(bruma, coche)
	comprobar(bool(r["ok"]) and float(coche.get("salud")) == 100.0 and float(coche.get("gasolina")) == 100.0, "aceite de bruma: todo nuevo")

	# --- Ventana ---
	var sv2: ServicioMundo = ServicioMundo.new()
	sv2.servicio = "restaurante"
	sv2.position = Vector3(40.0, 1.0, 40.0)
	escena.add_child(sv2)
	var lm2: LocalMundo = null
	for h in sv2.get_children():
		if h is LocalMundo:
			lm2 = h
	J.hora = 14.0
	J.dinero = 300
	var v: VentanaLocal = VentanaLocal.new()
	v.local_mundo = lm2
	hud.abrir_ventana(v)
	await get_tree().process_frame
	comprobar(v._filas.size() == (Locales.LOCALES["restaurante"]["carta"] as Array).size(), "la ventana lista la carta entera")
	v._pedir(v._filas[0]["item"])
	await get_tree().process_frame
	comprobar(J.dinero < 300, "pedir desde la ventana cobra")
	v.cerrar()
	J.hora = 5.0
	lm2._actualizar_abierto(false)
	comprobar(not lm2.esta_abierto(), "el restaurante cierra de madrugada")
	J.hora = 14.0
	lm2._actualizar_abierto(false)
	comprobar(lm2.esta_abierto(), "y abre al mediodía")

	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


func _vehiculo_falso(padre: Node) -> Node3D:
	var gd: GDScript = GDScript.new()
	gd.source_code = "extends Node3D\nvar salud: float = 100.0\nvar gasolina: float = 100.0\nvar tipo: String = \"sedan\"\nfunc guardar_estado() -> void:\n\tpass\n"
	gd.reload()
	var n: Node3D = Node3D.new()
	n.set_script(gd)
	padre.add_child(n)
	return n


# Todo cabe dentro, el pasillo de la puerta está libre y desde la puerta se llega al mostrador.
func _comprobar_interior(lm: LocalMundo, etiqueta: String) -> void:
	var W: float = lm.W
	var D: float = lm.D
	var solidas: Array = []
	for cj in lm.cajas:
		var pos: Vector3 = cj[0]
		var tam: Vector3 = cj[1]
		var u0: float = pos.x - tam.x / 2.0
		var u1: float = pos.x + tam.x / 2.0
		var iv0: float = D / 2.0 - (pos.z + tam.z / 2.0)
		var iv1: float = D / 2.0 - (pos.z - tam.z / 2.0)
		comprobar(u0 > -W / 2.0 - 0.15 and u1 < W / 2.0 + 0.15 and iv0 > -0.15 and iv1 < D + 0.15, "%s: una caja se sale del local %s" % [etiqueta, str([u0, u1, iv0, iv1])])
		if bool(cj[3]) and pos.y - tam.y / 2.0 < LocalMundo.SUELO + 1.7 and pos.y + tam.y / 2.0 > LocalMundo.SUELO + 0.25:
			solidas.append([u0, u1, iv0, iv1])
	var nx: int = int(W / CELDA) + 1
	var nz: int = int(D / CELDA) + 1
	var libre: Array = []
	libre.resize(nx * nz)
	for i in nx:
		for j in nz:
			var u: float = -W / 2.0 + i * CELDA
			var iv: float = j * CELDA
			var ok: bool = u > -W / 2.0 + RADIO * 0.5 and u < W / 2.0 - RADIO * 0.5 and iv > 0.0 and iv < D - 0.1
			if ok:
				for b in solidas:
					if u > b[0] - RADIO and u < b[1] + RADIO and iv > b[2] - RADIO and iv < b[3] + RADIO:
						ok = false
						break
			libre[i * nz + j] = ok
	var inicio: Vector2i = Vector2i(int((0.0 + W / 2.0) / CELDA), int(0.6 / CELDA))
	comprobar(bool(libre[inicio.x * nz + inicio.y]), "%s: la puerta está bloqueada" % etiqueta)
	var vistos: Dictionary = {}
	var pila: Array = [inicio]
	vistos[inicio] = true
	while not pila.is_empty():
		var q: Vector2i = pila.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var r: Vector2i = q + d
			if r.x < 0 or r.y < 0 or r.x >= nx or r.y >= nz or vistos.has(r) or not bool(libre[r.x * nz + r.y]):
				continue
			vistos[r] = true
			pila.append(r)
	var iv_m: float = D - 1.7 - 1.1
	var celda_m: Vector2i = Vector2i(int((lm._uc + W / 2.0) / CELDA), int(iv_m / CELDA))
	var alcanzable: bool = false
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			if vistos.has(celda_m + Vector2i(dx, dz)):
				alcanzable = true
	comprobar(alcanzable, "%s: no se llega al mostrador desde la puerta" % etiqueta)
	var total_libres: int = 0
	for i in libre.size():
		if bool(libre[i]):
			total_libres += 1
	comprobar(float(vistos.size()) >= 0.85 * float(total_libres), "%s: demasiadas zonas aisladas (%d de %d)" % [etiqueta, vistos.size(), total_libres])
