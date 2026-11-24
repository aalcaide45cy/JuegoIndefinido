# Prueba de caos: un minuto de jaleo en una ciudad llena de gente, como cuando el jugador se vuelve
# loco: disparos al aire, tiros a peatones, puñetazos, atropellos, explosiones y apuntar a la gente.
#   godot --headless --path . res://tests/prueba_caos.tscn
# Se comprueba que el juego aguanta y que la gente se comporta con sentido:
#   1) nadie acaba en una posición imposible (NaN, bajo tierra, volando),
#   2) durante el jaleo casi todos los cercanos reaccionan (huyen, se cubren, miran, llaman...),
#   3) pasado el jaleo la gente se calma y vuelve a su vida (nadie se queda "atascado" asustado),
#   4) hay variedad de reacciones (no todos hacen lo mismo).
# Los errores de script los cuenta quien lanza la prueba (grep "SCRIPT ERROR" en la salida).
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


func _vivos() -> Array:
	return vida_u._peatones.filter(func(q): return is_instance_valid(q) and not q.has_meta("muerto"))


func _poner_jugador(p: Vector3) -> void:
	jugador.global_position = p
	jugador.velocity = Vector3.ZERO


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
	J.policia_activa = false
	J.invulnerable = 9999.0
	Graficos.v["peatones"] = 4
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if int(s["tipo"]) == 2 and not bool(s.get("montana", false)):
			centro = s["pos"]
			break
	h = GeneradorMundo.altura(centro.x, centro.y)
	for i in 24:
		_poner_jugador(Vector3(centro.x + 2.0, h + 30.0, centro.y + 2.0))
		await esperar(0.5)
	await _caos()
	if fallos.is_empty():
		print("RESULTADO: TODO BIEN")
	else:
		print("RESULTADO: FALLO ", fallos)
	get_tree().quit()


const REACCIONES: Array = ["huir", "cubrirse", "llamar", "suplicar", "pelear", "disparar", "esquivar_coche",
		"alejarse", "mirar", "socorrer", "esconderse", "nervioso", "quejarse"]


func _caos() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var raras: int = 0
	var muestras: int = 0
	var reaccionan: int = 0
	var cercanos: int = 0
	var acciones: Dictionary = {}
	var eventos: Dictionary = {}
	J.inventario[J.seleccion] = {"id": "pistola", "cantidad": 1, "balas": 99}
	var t: float = 0.0
	while t < 40.0:
		var vivos: Array = _vivos()
		if vivos.is_empty():
			await esperar(0.5)
			t += 0.5
			continue
		var q: Node3D = vivos[rng.randi() % vivos.size()]
		# El jugador se planta cerca de alguien y hace algo.
		_poner_jugador(q.global_position + Vector3(rng.randf_range(-4, 4), 0.1, rng.randf_range(-4, 4)))
		var ev: int = rng.randi() % 6
		match ev:
			0:
				Sonido.tocar(jugador, "disparo")
				eventos["disparo_aire"] = int(eventos.get("disparo_aire", 0)) + 1
			1:
				Sonido.tocar(jugador, "disparo")
				q.recibir_dano(12.0)
				eventos["tiro"] = int(eventos.get("tiro", 0)) + 1
			2:
				q.recibir_dano(4.0)
				eventos["punetazo"] = int(eventos.get("punetazo", 0)) + 1
			3:
				q.derribar(Vector3(1, 0, 0), rng.randf_range(5.0, 18.0), true)
				eventos["atropello"] = int(eventos.get("atropello", 0)) + 1
			4:
				Combate.explosion(jugador.get_parent() as Node3D, q.global_position + Vector3(rng.randf_range(-6, 6), 0.3, rng.randf_range(-6, 6)), 5.0, 40.0)
				eventos["explosion"] = int(eventos.get("explosion", 0)) + 1
			5:
				var d: Vector3 = q.global_position + Vector3(0, 1.1, 0) - (jugador.global_position + Vector3(0, 1.6, 0))
				jugador._giro = atan2(-d.x, -d.z)
				jugador._inclinacion = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.2, 0.9)
				eventos["apuntar"] = int(eventos.get("apuntar", 0)) + 1
		for k in 4:
			await esperar(0.25)
			t += 0.25
			for p in _vivos():
				muestras += 1
				var pos: Vector3 = p.global_position
				var suelo: float = GeneradorMundo.altura(pos.x, pos.z)
				if is_nan(pos.x) or is_nan(pos.y) or pos.y < suelo - 6.0 or pos.y > suelo + 25.0:
					raras += 1
					if raras <= 3:
						print("  posición rara: ", pos, " suelo ", suelo, " estado ", p.estado)
				if k == 3 and pos.distance_to(jugador.global_position) < 18.0:
					cercanos += 1
					var acc: String = p.cerebro.accion if p.cerebro != null and p.cerebro.libre else "pasear"
					acciones[acc] = int(acciones.get(acc, 0)) + 1
					if acc in REACCIONES or p.estado == 3:
						reaccionan += 1
	J.inventario[J.seleccion] = null
	print("Eventos: ", eventos)
	print("Acciones de los cercanos durante el jaleo: ", acciones)
	comprobar(raras == 0, "nadie acaba en una posición imposible (%d de %d)" % [raras, muestras])
	comprobar(cercanos > 0 and reaccionan * 10 >= cercanos * 6, "la mayoría de los cercanos reacciona (%d de %d)" % [reaccionan, cercanos])
	var distintas: int = 0
	for k in acciones:
		if k in REACCIONES:
			distintas += 1
	comprobar(distintas >= 3, "hay variedad de reacciones (%d tipos)" % distintas)
	# Calma: el jugador se va lejos y pasa medio minuto.
	_poner_jugador(Vector3(centro.x + 2.0, h + 60.0, centro.y + 2.0))
	await esperar(30.0)
	var vivos2: Array = _vivos()
	var asustados: int = 0
	var hist: Dictionary = {}
	for p in vivos2:
		var acc: String = p.cerebro.accion if p.cerebro != null and p.cerebro.libre else "rutina"
		hist[acc] = int(hist.get(acc, 0)) + 1
		if acc in ["huir", "cubrirse", "suplicar", "pelear", "disparar", "esconderse"]:
			asustados += 1
	print("30 s después: ", hist)
	comprobar(asustados * 5 <= maxi(vivos2.size(), 1), "pasado el jaleo la gente se calma (%d de %d siguen asustados)" % [asustados, vivos2.size()])
