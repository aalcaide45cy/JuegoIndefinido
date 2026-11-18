# Auditoría jugable automática: recorre el mundo de verdad (sin ventana) y busca cosas raras:
# gente o coches bajo el suelo o flotando, objetos en (0,0,0), NaN, atascos del jugador, vehículos
# clavados en montañas, fugas de nodos, tirones. Se lanza con un lanzador mínimo (ver LEEME.md):
#   godot --headless --fixed-fps 60 --path . -s mec.gd -- res://tests/aud_recorrido.gd fase=todo
# Fases (fase=...): mundo, andar, trafico, vehiculos, tiempo, guardado, volar. Por defecto: todo.
extends Node

var fallos: Array = []
var avisos: Array = []
var J
var jugador
var escena
var hud
var _fase: String = "todo"
var _t_sim: float = 0.0
var _max_ms: float = 0.0
var _ult_us: int = 0


func _arg(clave: String, defecto: String) -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with(clave + "="):
			return str(a).substr(clave.length() + 1)
	return defecto


func fallo(texto: String) -> void:
	if fallos.size() < 400:
		fallos.append(texto)
	print("FALLO: ", texto)


func aviso(texto: String) -> void:
	if avisos.size() < 400:
		avisos.append(texto)
	print("AVISO: ", texto)


func _ready() -> void:
	_fase = _arg("fase", "todo")
	await get_tree().process_frame
	await _ejecutar()


func _ejecutar() -> void:
	randomize()
	var sem: int = int(_arg("azar", "1"))
	seed(sem)
	var raiz: Node = get_tree().root
	escena = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	for i in 3:
		await get_tree().physics_frame
	J = raiz.get_node("Juego")
	hud = escena.find_children("*", "Hud", true, false)[0]
	jugador = hud.jugador
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	J.policia_activa = false
	J.dinero = 1000000
	Engine.max_fps = 0
	print("== Auditoría fase=%s azar=%d ==" % [_fase, sem])
	var inicio_nodos: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var mem0: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	for f in ["mundo", "andar", "montana", "trafico", "vehiculos", "tiempo", "guardado", "volar", "inventario", "servicios", "aire"]:
		if _fase == "todo" or _fase == f:
			print("--- fase ", f)
			await call("_fase_" + f)
	var fin_nodos: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("Nodos: %d -> %d | memoria estática %.0f -> %.0f MB | huérfanos %d | tick máx %.1f ms" % [inicio_nodos, fin_nodos,
			mem0 / 1048576.0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), _max_ms])
	print("RESULTADO: %d fallos, %d avisos" % [fallos.size(), avisos.size()])
	get_tree().quit(0 if fallos.is_empty() else 1)


# ------------------------------------ utilidades ------------------------------------

func esperar(segundos: float, vigilar: bool = true) -> void:
	var n: int = int(segundos * 60.0)
	for i in n:
		await get_tree().physics_frame
		_t_sim += 1.0 / 60.0
		var us: int = Time.get_ticks_usec()
		if _ult_us != 0:
			_max_ms = maxf(_max_ms, (us - _ult_us) / 1000.0)
		_ult_us = us
		if vigilar and i % 30 == 0:
			_vigilar()
		if vigilar and i % 6 == 0:
			_historial()


# Pone al jugador en el suelo (espera a que haya terreno cargado).
func colocar(x: float, z: float, y_extra: float = 2.0) -> bool:
	jugador.vehiculo = null
	var h: float = GeneradorMundo.altura(x, z)
	jugador.global_position = Vector3(x, h + y_extra, z)
	jugador.velocity = Vector3.ZERO
	jugador._suelo_pendiente = true
	jugador._t_suelo_pendiente = 0.0
	for i in 60 * 20:
		await get_tree().physics_frame
		if not jugador._suelo_pendiente and jugador.is_on_floor():
			return true
	return false


func altura_aqui(p: Vector3) -> float:
	return GeneradorMundo.altura(p.x, p.z)


func _vigilar() -> void:
	var p: Vector3 = jugador.global_position
	if is_nan(p.x) or is_nan(p.y) or is_nan(p.z) or p.is_equal_approx(Vector3.ZERO):
		fallo("jugador en posición rara %s" % str(p))
	var vu = escena.find_children("*", "VidaUrbana", false, false)
	if vu.size() > 0:
		_vigilar_agentes(vu[0])
	for v in get_tree().get_nodes_in_group("vehiculos"):
		var q: Vector3 = v.global_position
		if is_nan(q.x) or is_nan(q.y) or is_nan(q.z):
			fallo("vehículo con NaN %s" % v.name)
		elif q.y < altura_aqui(q) - 2.0 and v.tipo != "":
			var d: float = Vector2(q.x, q.z).distance_to(Vector2(p.x, p.z))
			if d < 400.0:
				fallo("vehículo %s (%s) bajo el suelo: y=%.1f suelo=%.1f en %s" % [v.id, v.tipo, q.y, altura_aqui(q), str(q)])


var _vistos_malos: Dictionary = {}
var _hist: Dictionary = {}


func _historial() -> void:
	var vu = escena.find_children("*", "VidaUrbana", false, false)
	if vu.is_empty():
		return
	for a in vu[0].get("_coches"):
		if not is_instance_valid(a):
			continue
		var h: Array = _hist.get(a.get_instance_id(), [])
		h.append("t=%.1f d=%.1f v=%.1f dv=%.2f %s->%s pos=(%.1f,%.1f)" % [_t_sim, a.d, a.vel, a.desvio, str(a.desde), str(a.hacia), a.global_position.x, a.global_position.z])
		if h.size() > 12:
			h.pop_front()
		_hist[a.get_instance_id()] = h


func _vigilar_agentes(vu) -> void:
	var cuentas: Array = []
	for lista_nombre in ["_coches", "_peatones"]:
		var lista: Array = vu.get(lista_nombre)
		for a in lista:
			if not is_instance_valid(a):
				continue
			var q: Vector3 = a.global_position
			var clave: String = "%d" % a.get_instance_id()
			var motivo: String = ""
			if is_nan(q.x) or is_nan(q.y) or is_nan(q.z):
				motivo = "NaN"
			elif absf(q.x) < 0.01 and absf(q.z) < 0.01:
				motivo = "en (0,0,0)"
			else:
				var h: float = altura_aqui(q)
				var dy: float = q.y - h
				if a.red["id"] == "ciudad":
					h = 0.0
					dy = q.y
				if dy < -1.0:
					motivo = "bajo el suelo (%.1f m)" % dy
				elif dy > 2.0:
					motivo = "flotando (%.1f m)" % dy
			if motivo != "" and not _vistos_malos.has(clave):
				_vistos_malos[clave] = true
				fallo("%s %s: %s en %s (red %s)" % ["coche" if a.es_coche else "peatón", a.name, motivo, str(q), a.red["id"]])
	# Coches uno dentro de otro.
	var cs: Array = vu.get("_coches")
	for i in cs.size():
		for j in range(i + 1, cs.size()):
			if not is_instance_valid(cs[i]) or not is_instance_valid(cs[j]):
				continue
			var a = cs[i]
			var b = cs[j]
			var d2: float = Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
			if d2 < 1.8:
				var clave2: String = "%d-%d" % [a.get_instance_id(), b.get_instance_id()]
				if not _vistos_malos.has(clave2):
					_vistos_malos[clave2] = true
					print("  historial A: ", "
    ".join(_hist.get(a.get_instance_id(), [])))
					print("  historial B: ", "
    ".join(_hist.get(b.get_instance_id(), [])))
					fallo("dos coches atravesados (dist %.2f) en %s, red %s | A %s->%s d=%.1f vel=%.1f desv=%.1f | B %s->%s d=%.1f vel=%.1f desv=%.1f" % [d2, str(a.global_position), a.red["id"], str(a.desde), str(a.hacia), a.d, a.vel, a.desvio, str(b.desde), str(b.hacia), b.d, b.vel, b.desvio])


# ------------------------------------- fases ----------------------------------------

func _fase_mundo() -> void:
	# Visita asentamientos de cada tipo (incluidas las aldeas de montaña) y quédate un rato.
	var todos: Array = GeneradorMundo.todos_asentamientos()
	var por_tipo: Dictionary = {0: [], 1: [], 2: [], 9: []}
	for s in todos:
		if s["montana"]:
			por_tipo[9].append(s)
		else:
			por_tipo[int(s["tipo"])].append(s)
	var n_por: int = int(_arg("n", "3"))
	var plan: Array = [Vector2(0, 8)]
	for t in por_tipo:
		var l: Array = por_tipo[t]
		l.shuffle()
		for k in mini(n_por, l.size()):
			plan.append(l[k]["pos"] + Vector2(0, 6))
	for destino in plan:
		var t0: float = Time.get_ticks_msec() / 1000.0
		var ok: bool = await colocar(destino.x, destino.y)
		var tcarga: float = Time.get_ticks_msec() / 1000.0 - t0
		if not ok:
			fallo("no hay suelo al llegar a %s (esperé 20 s)" % str(destino))
			continue
		var h: float = altura_aqui(jugador.global_position)
		if jugador.global_position.y < h - 0.8:
			fallo("jugador bajo el terreno en %s: y=%.1f suelo=%.1f" % [str(destino), jugador.global_position.y, h])
		print("  %s: suelo en %.1f s real, y=%.1f" % [str(destino), tcarga, jugador.global_position.y])
		await esperar(12.0)


func _fase_andar() -> void:
	# Camina por carreteras de verdad: ¿se atasca el jugador con algo que no debería estar en la vía?
	var segs: Array = GeneradorMundo.todas_las_carreteras()
	var n_muestras: int = int(_arg("n", "12"))
	var buenos: Array = []
	for sg in segs:
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		if a.distance_to(b) > 60.0 and int(sg[3]) <= 1 and absf(a.x) < 4800.0 and absf(a.y) < 4800.0:
			buenos.append(sg)
	buenos.shuffle()
	J.modo_volar = false
	for k in mini(n_muestras, buenos.size()):
		var sg = buenos[k]
		var a2: Vector2 = sg[0]
		var b2: Vector2 = sg[1]
		var largo: float = a2.distance_to(b2)
		var inicio: Vector2 = a2.lerp(b2, 0.1)
		var dir: Vector2 = (b2 - a2).normalized()
		var ok: bool = await colocar(inicio.x, inicio.y)
		if not ok:
			fallo("andar: sin suelo en %s" % str(inicio))
			continue
		jugador._giro = atan2(-dir.x, -dir.y)
		var p0: Vector3 = jugador.global_position
		Input.action_press("adelante")
		Input.action_press("correr")
		var secs: float = minf(largo * 0.7, 120.0) / 6.0
		await esperar(secs)
		Input.action_release("adelante")
		Input.action_release("correr")
		var avance: float = Vector2(jugador.global_position.x - p0.x, jugador.global_position.z - p0.z).dot(dir)
		var esperado: float = 6.0 * secs * 0.6
		var estado: String = "ok"
		if avance < esperado:
			estado = "ATASCADO"
			fallo("andar por carretera (%s -> %s tipo %s): avanzó %.0f m de ~%.0f en %.0f s, parado en %s" % [str(inicio),
					str(dir), str(sg[3]), avance, esperado / 0.6, secs, str(jugador.global_position)])
		print("  tramo tipo %s en (%.0f,%.0f): avance %.0f/%.0f m %s" % [str(sg[3]), inicio.x, inicio.y, avance, 6.0 * secs, estado])
		await esperar(0.5)


func _fase_montana() -> void:
	# Sigue a pie, punto a punto, las carreteras de montaña (curvas, puentes, túneles, quitamiedos).
	var caminos: Array = GeneradorMundo._caminos.duplicate()
	caminos.shuffle()
	var n_muestras: int = int(_arg("n", "4"))
	J.modo_volar = false
	for k in mini(n_muestras, caminos.size()):
		var pts: PackedVector2Array = caminos[k]["pts"]
		var i0: int = randi() % maxi(1, pts.size() - 60)
		if _arg("solo", "") != "" and k != int(_arg("solo", "0")):
			continue
		var i1: int = mini(pts.size() - 1, i0 + 50)
		var ok: bool = await colocar(pts[i0].x, pts[i0].y)
		if not ok:
			fallo("montaña: sin suelo en %s" % str(pts[i0]))
			continue
		Input.action_press("adelante")
		Input.action_press("correr")
		var idx: int = i0 + 1
		var t_sin_avance: float = 0.0
		var ultimo: Vector3 = jugador.global_position
		var fallo_ya: bool = false
		var t_total: float = 0.0
		var traza: Array = []
		while idx <= i1 and t_total < 200.0 and not fallo_ya:
			var objetivo: Vector2 = pts[idx]
			var yo: Vector2 = Vector2(jugador.global_position.x, jugador.global_position.z)
			var d: Vector2 = objetivo - yo
			if d.length() < 3.5:
				idx += 1
				continue
			jugador._giro = atan2(-d.x, -d.y)
			await esperar(0.25)
			t_total += 0.25
			if int(t_total * 4.0) % 8 == 0:
				var pj3: Vector3 = jugador.global_position
				var dmin: float = 1e9
				for q in pts:
					dmin = minf(dmin, Vector2(pj3.x, pj3.z).distance_to(q))
				traza.append("t=%.0f idx=%d pos=(%.1f,%.1f,%.1f) a_la_carretera=%.1f m vel=%.1f suelo=%s" % [t_total, idx, pj3.x, pj3.y, pj3.z, dmin, jugador.velocity.length(), str(jugador.is_on_floor())])
				if traza.size() > 400:
					traza.pop_front()
			if jugador.global_position.distance_to(ultimo) < 0.4:
				t_sin_avance += 0.25
				if t_sin_avance >= 1.0:
					Input.action_press("saltar")   # Un jugador de verdad saltaría para salir de un bache.
					await esperar(0.15, false)
					Input.action_release("saltar")
			else:
				t_sin_avance = 0.0
				ultimo = jugador.global_position
			if t_sin_avance > 4.0:
				fallo_ya = true
				fallo("montaña: jugador atascado en carretera de montaña en %s (punto %d de %d, y=%.1f)" % [str(jugador.global_position), idx, i1, jugador.global_position.y])
		if not fallo_ya and idx <= i1:
			fallo_ya = true
			fallo("montaña: no avanza (200 s) en carretera de montaña en %s, punto %d de %d" % [str(jugador.global_position), idx, i1])
		if fallo_ya:
			print("  TRAZA:
    " + "
    ".join(traza.slice(0, 16)))
			var yo2: Vector2 = Vector2(jugador.global_position.x, jugador.global_position.z)
			print("  DEPURACIÓN: jugador %s altura analítica %.2f; objetivo pts[%d]=%s (dist %.1f, altura %.2f hs=%.2f); pts[%d]=%s" % [str(yo2), altura_aqui(jugador.global_position), idx, str(pts[mini(idx, pts.size() - 1)]), yo2.distance_to(pts[mini(idx, pts.size() - 1)]), GeneradorMundo.altura(pts[mini(idx, pts.size() - 1)].x, pts[mini(idx, pts.size() - 1)].y), caminos[k]["hs"][mini(idx + 1, pts.size())], idx - 1, str(pts[idx - 1])])
		Input.action_release("adelante")
		Input.action_release("correr")
		print("  carretera de montaña %d: puntos %d..%d, llegué al %d en %.0f s %s" % [k, i0, i1, idx, t_total, "ATASCADO" if fallo_ya else "ok"])


func _fase_trafico() -> void:
	# Quédate quieto en la ciudad, en un pueblo y en una aldea y observa coches/peatones largo rato.
	var lugares: Array = [Vector2(0, 8), Vector2(60, -16), Vector2(16, -60)]
	for s in GeneradorMundo.todos_asentamientos():
		if int(s["tipo"]) == 2 and not s["montana"]:
			lugares.append(s["pos"] + Vector2(0, 6))
			break
	for s in GeneradorMundo.todos_asentamientos():
		if int(s["tipo"]) == 1 and not s["montana"]:
			lugares.append(s["pos"] + Vector2(0, 6))
			break
	var minutos: float = float(_arg("min", "3"))
	for lugar in lugares:
		await colocar(lugar.x, lugar.y)
		var vu = escena.find_children("*", "VidaUrbana", false, false)[0]
		var parados: Dictionary = {}
		var t_fin: float = _t_sim + minutos * 60.0
		J.hora = 12.0
		while _t_sim < t_fin:
			await esperar(5.0)
			# Coches parados mucho tiempo sin motivo (semáforo o algo delante).
			for a in vu.get("_coches"):
				if not is_instance_valid(a):
					continue
				var id: int = a.get_instance_id()
				if a.vel < 0.05:
					parados[id] = float(parados.get(id, 0.0)) + 5.0
					if float(parados[id]) == 60.0:
						aviso("coche parado más de 60 s en %s (red %s): %s" % [str(a.global_position), a.red["id"], _quien_estorba(vu, a)])
				else:
					parados[id] = 0.0
		print("  %s: %d coches, %d peatones" % [str(lugar), vu.get("_coches").size(), vu.get("_peatones").size()])


func _fase_vehiculos() -> void:
	var gv: GestorVehiculos = escena.find_children("*", "GestorVehiculos", false, false)[0]
	await colocar(40, -10)
	J.policia_activa = false
	var tipos: Array = Vehiculo.TIPOS.keys()
	for t in tipos:
		if str(Vehiculo.TIPOS[t].get("clase", "suelo")) == "remolque":
			continue
		var pos: Vector3 = Vector3(45, 0.3, -18.5)
		var id_v: String = gv.entregar(t, pos, -PI / 2.0)
		await esperar(0.3, false)
		var v: Vehiculo = null
		for n in get_tree().get_nodes_in_group("vehiculos"):
			if (n as Vehiculo).id == id_v:
				v = n
		if v == null:
			fallo("vehículo %s no se creó" % t)
			continue
		jugador.global_position = v.global_position + Vector3(0, 0, 3)
		v.usar(jugador)
		await esperar(0.5, false)
		if jugador.vehiculo != v:
			fallo("no se pudo subir a %s" % t)
			continue
		var aire: bool = v.clase() == "aire"
		Input.action_press("adelante")
		if aire:
			Input.action_press("saltar")   # Subir.
		await esperar(6.0, false)
		Input.action_press("izquierda")
		await esperar(0.4, false)
		Input.action_release("izquierda")
		Input.action_release("saltar")
		await esperar(3.0, false)
		var q: Vector3 = v.chasis.global_position
		var h: float = altura_aqui(q)
		print("  %s: v=%.1f m/s pos=(%.0f, %.1f, %.0f) suelo %.1f" % [t, v._v, q.x, q.y, q.z, h])
		if is_nan(q.x) or is_nan(q.y):
			fallo("vehículo %s NaN" % t)
		if q.y < h - 1.0:
			fallo("vehículo %s bajo el suelo: y=%.1f suelo %.1f" % [t, q.y, h])
		Input.action_release("adelante")
		# Frena y aterriza.
		if aire:
			Input.action_press("agacharse")
			await esperar(10.0, false)
			Input.action_release("agacharse")
		await esperar(3.0, false)
		v._v = 0.0
		await esperar(2.0, false)
		var q_bajar: Vector3 = v.chasis.global_position
		v.bajar()
		await esperar(1.0, false)
		var pj: Vector3 = jugador.global_position
		if jugador.vehiculo != null:
			aviso("%s: no deja bajar (en el aire o al aterrizar)" % t)
			v.chasis.global_position = Vector3(q.x, altura_aqui(q) + 0.3, q.z)
			await esperar(1.0, false)
			v.bajar()
		else:
			var hj: float = altura_aqui(pj)
			if pj.y < hj - 0.5:
				fallo("tras bajar de %s el jugador queda bajo el suelo: y=%.1f suelo=%.1f" % [t, pj.y, hj])
			if pj.distance_to(q_bajar) > 12.0:
				fallo("tras bajar de %s el jugador queda a %.1f m del vehículo" % [t, pj.distance_to(q_bajar)])
		gv.retirar(id_v)
		await esperar(0.2, false)
		jugador.global_position = Vector3(40, 0.5, -10)
		jugador.velocity = Vector3.ZERO
		await esperar(0.5, false)

	# Coche por una carretera de montaña: ¿lo aplasta el techo de vuelo?
	var cumbre: Vector2 = Vector2.ZERO
	var mejor: float = 0.0
	for s in GeneradorMundo.todos_asentamientos():
		if s["montana"] and float(s["base"]) > mejor:
			mejor = float(s["base"])
			cumbre = s["pos"]
	if mejor > 0.0:
		await colocar(cumbre.x, cumbre.y + 6.0)
		var id2: String = gv.entregar("sedan", Vector3(cumbre.x + 4.0, GeneradorMundo.altura(cumbre.x + 4.0, cumbre.y + 6.0) + 0.5, cumbre.y + 6.0), 0.0)
		await esperar(0.5, false)
		var v2: Vehiculo = null
		for n in get_tree().get_nodes_in_group("vehiculos"):
			if (n as Vehiculo).id == id2:
				v2 = n
		jugador.global_position = v2.global_position + Vector3(0, 0, 3)
		v2.usar(jugador)
		await esperar(1.0, false)
		var y_ant: float = v2.chasis.global_position.y
		Input.action_press("adelante")
		await esperar(4.0, false)
		Input.action_release("adelante")
		var q2: Vector3 = v2.chasis.global_position
		var h2: float = altura_aqui(q2)
		print("  coche en pueblo de montaña (base %.0f): y %.1f -> %.1f, suelo %.1f" % [mejor, y_ant, q2.y, h2])
		if q2.y < h2 - 1.0 or q2.y <= Vehiculo.ALTURA_MAXIMA + 0.5 and h2 > Vehiculo.ALTURA_MAXIMA + 5.0:
			fallo("coche en montaña a %.0f m de altura: queda clavado/aplastado (y=%.1f, suelo=%.1f)" % [mejor, q2.y, h2])
		v2.bajar()
		await esperar(0.5, false)
		gv.retirar(id2)


func _fase_tiempo() -> void:
	await colocar(0, 8)
	for h in [0.0, 5.5, 6.5, 12.0, 18.5, 19.5, 21.0, 23.5]:
		J.hora = h
		for clima in ["despejado", "nublado", "lluvia", "tormenta", "niebla"]:
			Clima.actual = clima
			var o = Clima.TIPOS[clima]
			Clima.restante = 6.0
			await esperar(2.0)
			if is_nan(Clima.lluvia) or is_nan(Clima.niebla):
				fallo("clima NaN a las %.1f con %s" % [h, clima])
	print("  clima/hora recorridos")


func _fase_guardado() -> void:
	await colocar(0, 8)
	var gv: GestorVehiculos = escena.find_children("*", "GestorVehiculos", false, false)[0]
	var id_v: String = gv.entregar("hatchback", Vector3(8, 0.3, 20), 1.0)
	J.dinero = 1234
	J.anadir("hierba_bruma", 7)
	J.hora = 14.5
	jugador.global_position = Vector3(20, 0.3, 10)
	var ok: bool = Guardado.guardar(get_tree(), jugador, 5)
	if not ok:
		fallo("guardar ranura 5")
	J.dinero = 9
	J.vaciar_para_prueba() if J.has_method("vaciar_para_prueba") else null
	jugador.global_position = Vector3(300, 5, 300)
	ok = Guardado.cargar(get_tree(), jugador, 5)
	await esperar(1.0, false)
	if not ok:
		fallo("cargar ranura 5")
	if J.dinero != 1234:
		fallo("tras cargar el dinero es %d (esperado 1234)" % J.dinero)
	if J.cuenta("hierba_bruma") != 7:
		fallo("tras cargar hierba_bruma = %d" % J.cuenta("hierba_bruma"))
	if jugador.global_position.distance_to(Vector3(20, 0.3, 10)) > 3.0:
		fallo("tras cargar el jugador está en %s" % str(jugador.global_position))
	var hay: int = 0
	for n in get_tree().get_nodes_in_group("vehiculos"):
		if (n as Vehiculo).id == id_v:
			hay += 1
	if hay != 1:
		fallo("tras cargar hay %d copias del vehículo comprado" % hay)
	# Guardar y cargar 6 veces: que no se dupliquen vehículos ni aparezcan nodos de más.
	var antes: int = get_tree().get_nodes_in_group("vehiculos").size()
	for i in 6:
		Guardado.guardar(get_tree(), jugador, 5)
		Guardado.cargar(get_tree(), jugador, 5)
		await esperar(0.3, false)
	var despues: int = get_tree().get_nodes_in_group("vehiculos").size()
	if despues != antes:
		fallo("tras guardar/cargar 6 veces los vehículos pasan de %d a %d" % [antes, despues])
	Guardado.borrar(5)


func _fase_volar() -> void:
	J.modo_volar = true
	J.velocidad_vuelo = 400.0
	await colocar(0, 8, 60.0)
	jugador.global_position = Vector3(0, 80, 8)
	var recorridos: Array = [Vector2(1, 0), Vector2(0, 1), Vector2(-1, -1).normalized()]
	var peor_ms: float = 0.0
	for dir in recorridos:
		jugador._giro = atan2(-dir.x, -dir.y)
		jugador._inclinacion = 0.0
		Input.action_press("adelante")
		Input.action_press("correr")
		for i in 40:
			await esperar(1.0, false)
			var p: Vector3 = jugador.global_position
			if is_nan(p.x) or is_nan(p.y):
				fallo("volar: NaN")
				break
			if absf(p.x) > 5100.0 or absf(p.z) > 5100.0:
				fallo("volar: salí del mundo %s" % str(p))
				break
		Input.action_release("adelante")
		Input.action_release("correr")
		print("  vuelo hacia %s: llegué a %s, tick máx %.1f ms, nodos %d" % [str(dir), str(jugador.global_position), _max_ms,
				int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	J.modo_volar = false
	await esperar(0.5, false)
	await colocar(jugador.global_position.x, jugador.global_position.z, 4.0)
	await colocar(0, 8)


func _fase_inventario() -> void:
	# Operaciones al azar: la suma de cada objeto se conserva y no hay casillas rotas.
	var ids: Array = ["hierba_bruma", "hierba_raiz_ardiente", "aditivo_miel", "aditivo_sal", "bidon_gasolina", "kit_reparacion"]
	var esperado: Dictionary = {}
	J.reiniciar()
	J.inventario.fill(null)
	J.estanteria.fill(null)
	J.nivel = 20
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = int(_arg("azar", "1"))
	for paso in 3000:
		var op: int = rnd.randi() % 8
		var id: String = ids[rnd.randi() % ids.size()]
		var lista_a: Array = J.inventario if rnd.randf() < 0.6 else J.estanteria
		var lista_b: Array = J.inventario if rnd.randf() < 0.5 else J.estanteria
		match op:
			0, 1:
				var n: int = rnd.randi_range(1, 40)
				var sobra: int = J.anadir(id, n)
				esperado[id] = int(esperado.get(id, 0)) + n - sobra
			2:
				var n2: int = rnd.randi_range(1, 30)
				if J.quitar(id, n2):
					esperado[id] = int(esperado.get(id, 0)) - n2
			3:
				J.mover(lista_a, rnd.randi() % lista_a.size(), lista_b, rnd.randi() % lista_b.size())
			4:
				J.dividir(lista_a, rnd.randi() % lista_a.size())
			5:
				J.ordenar(lista_a, 9 if lista_a == J.inventario else 0)
			6:
				if is_same(lista_a, lista_b):
					lista_b = J.estanteria if is_same(lista_a, J.inventario) else J.inventario
				J.mover_rapido(lista_a, rnd.randi() % lista_a.size(), lista_b, 0 if lista_b != J.inventario else 9)
			7:
				J.seleccionar(rnd.randi() % 9)
		if paso % 100 == 99:
			_comprobar_inventario(esperado, paso)
	_comprobar_inventario(esperado, 3000)
	print("  inventario: 3000 operaciones al azar hechas")


func _comprobar_inventario(esperado: Dictionary, paso: int) -> void:
	var real: Dictionary = {}
	for lista in [J.inventario, J.estanteria]:
		for c in lista:
			if c == null:
				continue
			if int(c["cantidad"]) <= 0:
				fallo("inventario (paso %d): casilla con cantidad %d de %s" % [paso, int(c["cantidad"]), str(c["id"])])
			var maximo: int = DatosObjetos_pila(str(c["id"]))
			if int(c["cantidad"]) > maximo:
				fallo("inventario (paso %d): pila de %d de %s (máx %d)" % [paso, int(c["cantidad"]), str(c["id"]), maximo])
			real[c["id"]] = int(real.get(c["id"], 0)) + int(c["cantidad"])
	for id in esperado:
		if int(real.get(id, 0)) != int(esperado[id]):
			fallo("inventario (paso %d): %s debería sumar %d y suma %d" % [paso, id, int(esperado[id]), int(real.get(id, 0))])
			esperado[id] = int(real.get(id, 0))   # No repetir el mismo fallo en cada comprobación.


func DatosObjetos_pila(id: String) -> int:
	return load("res://scripts/datos/objetos.gd").pila(id)


func _fase_servicios() -> void:
	# Banco, hospital, taberna, gasolinera y taller: el dinero nunca crece solo ni se vuelve negativo.
	await colocar(40, -10)
	var gv: GestorVehiculos = escena.find_children("*", "GestorVehiculos", false, false)[0]
	var servs: Dictionary = {}
	for nombre in ["banco", "hospital", "taberna", "gasolinera", "taller"]:
		var sv: ServicioMundo = ServicioMundo.new()
		sv.servicio = nombre
		sv.position = Vector3(40, 0.0, -10)
		escena.add_child(sv)
		servs[nombre] = sv
	var id_v: String = gv.entregar("sedan", Vector3(46, 0.3, -18.5), -PI / 2.0)
	await esperar(0.3, false)
	J.dinero = 1000
	J.banco = 0
	var total0: int = J.dinero + J.banco
	for i in 40:
		servs["banco"].usar(jugador)
		Input.action_press("correr")
		servs["banco"].usar(jugador)
		Input.action_release("correr")
	var total1: int = J.dinero + J.banco
	print("  banco: 1000 -> %d tras 40 ingresos/retiradas (comisiones)" % total1)
	if total1 > total0:
		fallo("el banco regala dinero: %d -> %d" % [total0, total1])
	if J.dinero < 0 or J.banco < 0:
		fallo("dinero negativo: %d, banco %d" % [J.dinero, J.banco])
	J.dinero = 5
	for nombre in ["hospital", "taberna", "gasolinera", "taller"]:
		J.vida = 20.0
		servs[nombre].usar(jugador)
	if J.dinero < 0:
		fallo("dinero negativo tras servicios sin fondos: %d" % J.dinero)
	J.dinero = 100000
	J.vida = 10.0
	servs["hospital"].usar(jugador)
	if J.vida < Juego.VIDA_MAX - 1.0:
		fallo("el hospital no cura: vida %.0f" % J.vida)
	for n in servs:
		(servs[n] as Node).queue_free()
	gv.retirar(id_v)


# Depuración: qué tiene delante un coche parado.
func _quien_estorba(vu, a) -> String:
	var pa: Vector2 = a.red["pos"][a.desde]
	var pb: Vector2 = a.red["pos"][a.hacia]
	var dir: Vector2 = (pb - pa).normalized()
	var yo: Vector2 = Vector2(a.global_position.x, a.global_position.z)
	var mejor: String = "nada a la vista (semáforo?) restante %.1f nodo luz %s" % [pa.distance_to(pb) - a.d, str(a.red["luz"].has(a.hacia))]
	var mejor_h: float = 99.0
	var cand: Array = [jugador]
	cand.append_array(get_tree().get_nodes_in_group("vehiculos"))
	cand.append_array(vu.get("_coches"))
	cand.append_array(vu.get("_peatones"))
	for o in cand:
		if o == a or not is_instance_valid(o):
			continue
		var p: Vector3 = (o as Node3D).global_position
		var rel: Vector2 = Vector2(p.x, p.z) - yo
		var d: float = rel.dot(dir)
		var lat: float = absf(rel.dot(Vector2(-dir.y, dir.x)))
		if d > 0.0 and d < 20.0 and lat < 1.9 and d < mejor_h:
			mejor_h = d
			mejor = "%s '%s' a %.1f m (lateral %.1f, vel %s)" % [o.get_class(), o.name, d, lat, str(o.vel) if "vel" in o else "-"]
	return mejor


func _fase_aire() -> void:
	# Helicóptero y avioneta: despegar, volar, aterrizar y bajar, con la traza segundo a segundo.
	var gv: GestorVehiculos = escena.find_children("*", "GestorVehiculos", false, false)[0]
	for t in ["helicoptero", "avion"]:
		await colocar(1500, 1500)
		var h0: float = GeneradorMundo.altura(1500, 1500)
		var id_v: String = gv.entregar(t, Vector3(1500, h0 + 0.5, 1500), 0.0)
		await esperar(0.3, false)
		var v: Vehiculo = null
		for n in get_tree().get_nodes_in_group("vehiculos"):
			if (n as Vehiculo).id == id_v:
				v = n
		jugador.global_position = v.global_position + Vector3(0, 0, 3)
		v.usar(jugador)
		await esperar(0.5, false)
		Input.action_press("adelante")
		Input.action_press("saltar")
		for i in 12:
			await esperar(1.0, false)
			var q: Vector3 = v.chasis.global_position
			print("  %s t=%d: pos=(%.0f, %.1f, %.0f) suelo %.1f v=%.1f vy=%.1f gas=%.1f" % [t, i, q.x, q.y, q.z, altura_aqui(q), v._v, v._vy, v.gasolina])
		Input.action_release("saltar")
		Input.action_press("agacharse")
		for i in 14:
			await esperar(1.0, false)
			print("    descenso t=%d: avión %s en suelo=%s jugador %s vy=%.1f" % [i, str(v.chasis.global_position.snapped(Vector3.ONE)), str(v.chasis.is_on_floor()), str(jugador.global_position.snapped(Vector3.ONE)), v._vy])
			if v.chasis.is_on_floor():
				break
		Input.action_release("agacharse")
		Input.action_release("adelante")
		for i in 6:
			await esperar(0.5, false)
			print("    rodando t=%.1f: vehículo %s v=%.1f suelo=%s jugador %s" % [0.5 * i, str(v.chasis.global_position.snapped(Vector3.ONE)), v._v, str(v.chasis.is_on_floor()), str(jugador.global_position.snapped(Vector3.ONE))])
		var q2: Vector3 = v.chasis.global_position
		print("  %s tras aterrizar: pos=(%.0f, %.1f, %.0f) suelo %.1f en el suelo=%s salud=%.0f vida=%.0f" % [t, q2.x, q2.y, q2.z, altura_aqui(q2), str(v.chasis.is_on_floor()), v.salud, J.vida])
		print("  %s antes de bajar: jugador %s avisos %s" % [t, str(jugador.global_position), str(J.avisos.slice(0, 3))])
		v.bajar()
		await esperar(1.0, false)
		print("  %s después de bajar: jugador %s avisos %s" % [t, str(jugador.global_position), str(J.avisos.slice(0, 3))])
		if jugador.vehiculo != null:
			fallo("%s: no se puede bajar tras aterrizar (en el suelo: %s)" % [t, str(v.chasis.is_on_floor())])
			jugador.vehiculo = null
			v.conductor = null
		var pj: Vector3 = jugador.global_position
		print("  %s jugador tras bajar: %s a %.1f m del vehículo" % [t, str(pj), pj.distance_to(q2)])
		if pj.distance_to(q2) > 12.0:
			fallo("%s: el jugador sale a %.1f m del vehículo" % [t, pj.distance_to(q2)])
		if pj.y < altura_aqui(pj) - 0.5:
			fallo("%s: el jugador sale bajo el suelo" % t)
		gv.retirar(id_v)
