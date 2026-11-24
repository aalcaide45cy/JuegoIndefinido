# Prueba del comportamiento de los personajes (scripts/ia): sin ventana,
#   godot --headless --path . res://tests/prueba_ia.tscn
# En una ciudad de día:
#   1) todos los peatones tienen cerebro; hay parejas que pasean juntas,
#   2) se esquivan: se mide cuántas veces dos peatones se "atraviesan" (centros a < 0,45 m),
#   3) un disparo: la mayoría reacciona (huye, se cubre, llama...) en vez de seguir paseando,
#   4) a un valiente le pegas: se encara contigo a puñetazos y te hace daño,
#   5) uno armado al que pegas saca la pistola y dispara,
#   6) un coche que va directo hacia un peatón: salta a un lado,
#   7) le apuntas con una pistola a uno: suplica, huye, se cubre o saca su arma,
#   8) un civil armado (Ocupante) al que hieres te dispara,
#   9) el árbol de comportamiento (ArbolIA): selector, secuencia, utilidad y enfriamiento.
# Acaba con "RESULTADO: TODO BIEN" o con la lista de fallos.
extends Node

var fallos: Array = []
var J: Node
var jugador: Node3D
var vida_u: Node
var h: float = 0.0
var centro: Vector2


func comprobar(ok: bool, texto: String) -> void:
	print(("  ok  " if ok else "FALLO ") + texto)
	if not ok:
		fallos.append(texto)


func esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _peatones() -> Array:
	return vida_u._peatones.filter(func(q): return is_instance_valid(q) and not q.has_meta("muerto"))


func _histograma(lista: Array) -> Dictionary:
	var hist: Dictionary = {}
	for q in lista:
		var acc: String = q.cerebro.accion if q.cerebro != null and q.cerebro.libre else ("rutina_%d" % q.estado)
		hist[acc] = int(hist.get(acc, 0)) + 1
	return hist


func _calmar_a_todos() -> void:
	J.estrellas = 0
	for q in _peatones():
		if q.cerebro != null:
			q.cerebro.miedo = 0.0
			q.cerebro.ira = 0.0
			q.cerebro.amenaza = null
			q.cerebro.t_incidente = -99.0
			q.cerebro.t_disparo = -99.0
			q.cerebro.amenaza_dispara = false


func _poner_jugador(p: Vector3) -> void:
	jugador.global_position = p
	jugador.velocity = Vector3.ZERO


func _mirar(punto: Vector3) -> void:
	var d: Vector3 = punto - (jugador.global_position + Vector3(0, 1.6, 0))
	jugador._giro = atan2(-d.x, -d.z)
	jugador._inclinacion = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.2, 0.9)


# Un peatón tranquilo, en su acera, lejos de otros y del jugador.
func _elegir_peaton(excluir: Array = []) -> Node3D:
	for q in _peatones():
		if q in excluir or q.estado != 0 or q.cerebro == null or q.cerebro.lider != null:
			continue
		return q
	return null


func _ready() -> void:
	await get_tree().process_frame
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	J = raiz.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	jugador = hud.jugador
	vida_u = escena.find_children("*", "VidaUrbana", true, false)[0]
	J.modo_volar = true
	J.hora = 12.0
	J.velocidad_tiempo = 0.0
	Graficos.v["peatones"] = 4   # Densidad máxima: más cruces entre peatones que medir.
	J.policia_activa = false   # Sin guardias que se metan en medio (las llamadas no suben estrellas).
	_arbol()
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if int(s["tipo"]) == 2 and not bool(s.get("montana", false)):
			centro = s["pos"]
			break
	h = GeneradorMundo.altura(centro.x, centro.y)
	# Que aparezca gente y ande un rato.
	for i in 24:
		_poner_jugador(Vector3(centro.x + 2.0, h + 30.0, centro.y + 2.0))
		await esperar(0.5)
	await _cerebros_y_esquivar()
	await _disparo()
	await _pelea()
	await _armado()
	await _coche()
	await _apuntar()
	await _civil_armado()
	if fallos.is_empty():
		print("RESULTADO: TODO BIEN")
	else:
		print("RESULTADO: FALLO ", fallos)
	get_tree().quit()


func _cerebros_y_esquivar() -> void:
	var peat: Array = _peatones()
	var con: int = peat.filter(func(q): return q.cerebro != null).size()
	var parejas: int = peat.filter(func(q): return q.cerebro != null and q.cerebro.lider != null).size()
	print("Peatones: %d, con cerebro %d, acompañantes %d" % [peat.size(), con, parejas])
	comprobar(peat.size() >= 8 and con == peat.size(), "todos los peatones tienen cerebro (%d/%d)" % [con, peat.size()])
	# Se esquivan: muestras de parejas cercanas (< 3 m) y de cuántas se atraviesan (< 0,45 m).
	var cerca: int = 0
	var cruzan: int = 0
	var acciones: Dictionary = {}
	var t: float = 0.0
	while t < 20.0 or (cerca <= 20 and t < 70.0):   # Si hay poca gente, se mide más rato.
		_poner_jugador(Vector3(centro.x + 2.0, h + 30.0, centro.y + 2.0))
		await esperar(0.1)
		t += 0.1
		peat = _peatones()
		for i in peat.size():
			var a = peat[i]
			var acc: String = a.cerebro.accion if a.cerebro.libre else "pasear"
			acciones[acc] = int(acciones.get(acc, 0)) + 1
			for j in range(i + 1, peat.size()):
				var b = peat[j]
				if a.cerebro.lider == b or b.cerebro.lider == a:
					continue
				var d: float = Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
				if d < 3.0:
					cerca += 1
					if d < 0.45:
						cruzan += 1
	print("Muestras con dos peatones a menos de 3 m: %d; se atraviesan: %d; acciones: %s" % [cerca, cruzan, acciones])
	comprobar(cerca > 20, "hay cruces entre peatones que medir (%d)" % cerca)
	comprobar(cruzan <= maxi(3, cerca / 25), "casi nunca se atraviesan (%d de %d)" % [cruzan, cerca])


func _disparo() -> void:
	_calmar_a_todos()
	var peat: Array = _peatones()
	# El jugador baja a la calle junto a un peatón y dispara al aire.
	var q: Node3D = peat[0]
	_poner_jugador(q.global_position + Vector3(3.0, 0.2, 0.0))
	await esperar(0.3)
	Sonido.tocar(jugador, "disparo")
	await esperar(2.5)
	var cerca: Array = _peatones().filter(func(x): return x.global_position.distance_to(jugador.global_position) < 25.0)
	var hist: Dictionary = _histograma(cerca)
	var reaccionan: int = 0
	for k in hist:
		if str(k) in ["huir", "cubrirse", "llamar", "suplicar", "pelear", "disparar", "esquivar_coche", "alejarse", "mirar"]:
			reaccionan += int(hist[k])
	print("Tras el disparo (%d cerca): %s" % [cerca.size(), hist])
	comprobar(cerca.size() > 0 and reaccionan * 10 >= cerca.size() * 6, "la mayoría reacciona al disparo (%d de %d)" % [reaccionan, cerca.size()])
	await esperar(3.0)


func _pelea() -> void:
	_calmar_a_todos()
	await esperar(0.5)
	var q: Node3D = _elegir_peaton()
	if q == null:
		comprobar(false, "hay un peatón para la pelea")
		return
	q.cerebro.ajustar({"valentia": 0.95, "agresividad": 0.95, "armado": false, "agilidad": 0.6})
	J.vida = 100.0
	J.invulnerable = 0.0
	var al: Vector3 = (-q.global_basis.z) * 1.3
	_poner_jugador(q.global_position + al)
	q.recibir_dano(4.0)   # Le pegas tú (recibir_dano lo achaca al jugador).
	var vida_min: float = 100.0
	var acciones: Dictionary = {}
	for i in 40:
		await esperar(0.1)
		_poner_jugador(Vector3(jugador.global_position.x, q.global_position.y + 0.05, jugador.global_position.z))
		acciones[q.cerebro.accion] = int(acciones.get(q.cerebro.accion, 0)) + 1
		vida_min = minf(vida_min, J.vida)
	print("Pelea: acciones %s, tu vida %.0f" % [acciones, vida_min])
	comprobar(acciones.has("pelear"), "el valiente se encara a puñetazos")
	comprobar(vida_min < 100.0, "y te hace daño (vida %.0f)" % vida_min)


func _armado() -> void:
	_calmar_a_todos()
	_poner_jugador(Vector3(centro.x + 2.0, h + 30.0, centro.y + 2.0))
	await esperar(1.5)
	var q: Node3D = _elegir_peaton()
	if q == null:
		comprobar(false, "hay un peatón para el armado")
		return
	q.cerebro.ajustar({"valentia": 0.9, "agresividad": 0.8, "armado": true})
	J.vida = 100.0
	_poner_jugador(q.global_position + (-q.global_basis.z) * 7.0 + Vector3(0, 0.05, 0))
	q.recibir_dano(4.0)
	var acciones: Dictionary = {}
	var vida_min: float = 100.0
	var saco: bool = false
	for i in 60:
		await esperar(0.1)
		acciones[q.cerebro.accion] = int(acciones.get(q.cerebro.accion, 0)) + 1
		saco = saco or q.cerebro.arma_fuera
		vida_min = minf(vida_min, J.vida)
	print("Armado: acciones %s, tu vida %.0f" % [acciones, vida_min])
	comprobar(acciones.has("disparar") and saco, "el armado saca la pistola y dispara")
	comprobar(vida_min < 100.0, "y alguna bala te da (vida %.0f)" % vida_min)


func _coche() -> void:
	_calmar_a_todos()
	_poner_jugador(Vector3(centro.x + 2.0, h + 30.0, centro.y + 2.0))
	await esperar(2.0)
	var q: Node3D = _elegir_peaton()
	if q == null:
		comprobar(false, "hay un peatón para el coche")
		return
	q.cerebro.agilidad = 1.0   # Para que le dé tiempo seguro (los torpes a veces se quedan clavados).
	var coche: CharacterBody3D = CharacterBody3D.new()
	coche.add_to_group("vehiculos")
	add_child(coche)
	var dir: Vector3 = -q.global_basis.z
	coche.global_position = q.global_position + dir * 14.0
	var esquivo: bool = false
	for i in 30:
		var hacia: Vector3 = q.global_position - coche.global_position
		hacia.y = 0.0
		coche.velocity = hacia.normalized() * 12.0
		coche.global_position += coche.velocity * 0.05
		await esperar(0.05)
		esquivo = esquivo or q.cerebro.accion == "esquivar_coche"
	coche.queue_free()
	comprobar(esquivo, "salta a un lado cuando un coche va a por él")


func _apuntar() -> void:
	_calmar_a_todos()
	_poner_jugador(Vector3(centro.x + 2.0, h + 30.0, centro.y + 2.0))
	await esperar(2.0)
	var q: Node3D = _elegir_peaton()
	if q == null:
		comprobar(false, "hay un peatón al que apuntar")
		return
	J.inventario[J.seleccion] = {"id": "pistola", "cantidad": 1, "balas": 8}
	var acciones: Dictionary = {}
	for i in 40:
		_poner_jugador(q.global_position + (-q.global_basis.z) * 5.0 + Vector3(0, 0.05, 0) if i == 0 else jugador.global_position)
		_mirar(q.global_position + Vector3(0, 1.1, 0))
		await esperar(0.1)
		acciones[q.cerebro.accion if q.cerebro.libre else "pasear"] = int(acciones.get(q.cerebro.accion if q.cerebro.libre else "pasear", 0)) + 1
	J.inventario[J.seleccion] = null
	print("Apuntado: %s (apuntado=%s)" % [acciones, q.cerebro.apuntado])
	var reacciona: bool = false
	for k in ["suplicar", "huir", "cubrirse", "disparar", "nervioso", "llamar"]:
		reacciona = reacciona or acciones.has(k)
	comprobar(reacciona, "al apuntarle con una pistola reacciona")


func _civil_armado() -> void:
	_calmar_a_todos()
	var base: Vector3 = Vector3(centro.x + 2.0, h + 0.4, centro.y + 2.0)
	var o: Ocupante = Ocupante.new()
	o.semilla = 7
	o.armado = true
	o.arma = "Pistol"
	o.zona = Rect2(base.x - 6.0, base.z - 6.0, 12.0, 12.0)
	get_tree().current_scene.add_child(o) if get_tree().current_scene != null else add_child(o)
	o.global_position = base
	o.cerebro.ajustar({"valentia": 0.9, "agresividad": 0.8})
	J.vida = 100.0
	_poner_jugador(base + Vector3(0, 0, 8.0))
	await esperar(0.5)
	o.recibir_dano(5.0)
	var disparo: bool = false
	for i in 50:
		await esperar(0.1)
		disparo = disparo or o.cerebro.accion == "disparar"
	print("Civil armado: acción %s, tu vida %.0f" % [o.cerebro.accion, J.vida])
	comprobar(disparo, "el civil armado al que hieres te dispara")
	o.queue_free()


# --- El árbol por sí solo ---
class Prueba extends RefCounted:
	var log: Array = []
	var valor_a: float = 0.2
	var valor_b: float = 0.5


func _arbol() -> void:
	var p: Prueba = Prueba.new()
	var bb: Dictionary = {}
	var arbol: ArbolIA.Nodo = ArbolIA.selector("raiz", [
		ArbolIA.secuencia("sec", [
			ArbolIA.si("falso", func(_p, _bb): return false),
			ArbolIA.hacer("nunca", func(pp, _bb, _d): pp.log.append("nunca"); return ArbolIA.EXITO),
		]),
		ArbolIA.utilidad("util", [
			[func(pp, _bb): return pp.valor_a, ArbolIA.hacer("a", func(pp, _bb, _d): pp.log.append("a"); return ArbolIA.CORRIENDO)],
			[func(pp, _bb): return pp.valor_b, ArbolIA.hacer("b", func(pp, _bb, _d): pp.log.append("b"); return ArbolIA.CORRIENDO)],
		], 0.1),
	])
	arbol.tick(p, bb, 0.1)
	p.valor_a = 0.55   # Supera a b, pero no por más de la histéresis (0,1): sigue con b.
	arbol.tick(p, bb, 0.1)
	p.valor_a = 0.9    # Ahora sí cambia.
	arbol.tick(p, bb, 0.1)
	comprobar(p.log == ["b", "b", "a"], "árbol: utilidad con histéresis y secuencia que falla (%s)" % str(p.log))
	var veces: Array = [0]
	var enf: ArbolIA.Nodo = ArbolIA.enfriar(5.0, ArbolIA.hacer("x", func(_pp, _bb, _d): veces[0] += 1; return ArbolIA.EXITO))
	var bb2: Dictionary = {"reloj": 0.0}
	enf.tick(p, bb2, 0.1)
	bb2["reloj"] = 2.0
	enf.tick(p, bb2, 0.1)
	bb2["reloj"] = 6.0
	enf.tick(p, bb2, 0.1)
	comprobar(veces[0] == 2, "árbol: el enfriamiento no repite antes de tiempo (%d)" % veces[0])
