# Prueba del tráfico y los peatones (vida_urbana.gd). Sin ventana:
#   godot --headless --path . res://tests/prueba_trafico.tscn -- [segundos] [tipo_asentamiento 1|2]
# Se coloca en una ciudad, deja correr el tráfico y vigila: coches atascados o
# amontonados, peatones andando por la calzada, cruces hechos y atropellos.
extends Node

var vida: Node
var jugador: Node3D
var fallos: Array = []


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var segundos: float = float(args[0]) if args.size() > 0 else 90.0
	var tipo: int = int(args[1]) if args.size() > 1 else 2
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
	jugador = hud.jugador
	vida = escena.find_children("*", "VidaUrbana", true, false)[0]
	J.hora = 12.0
	J.modo_volar = true
	var elegido: Dictionary = {"pos": Vector2(0, 0), "nombre": "ciudad original"}
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if tipo < 3 and int(s["tipo"]) == tipo and not bool(s.get("montana", false)):
			elegido = s
			break
	var p: Vector2 = elegido["pos"]
	print("Probando en ", elegido["nombre"], " (tipo ", tipo, ") durante ", segundos, " s")
	var h: float = GeneradorMundo.altura(p.x, p.y) if tipo < 3 else 0.0
	var muestras: int = 0
	var atascos_max: float = 0.0
	var solapes: int = 0
	var peat_calzada: int = 0
	var cruces: int = 0
	var golpes: int = 0
	var libres: int = 0
	var parados_cruce: int = 0
	var vistos_cruza: Dictionary = {}
	var infracciones: int = 0
	var heridos: int = 0
	var vistos_golpe: Dictionary = {}
	var max_coches: int = 0
	var max_peat: int = 0
	var t: float = 0.0
	while t < segundos:
		jugador.global_position = Vector3(p.x + 2.0, h + 30.0, p.y + 2.0)
		jugador.velocity = Vector3.ZERO
		await get_tree().create_timer(0.5).timeout
		t += 0.5
		muestras += 1
		var coches: Array = vida._coches.filter(func(c): return is_instance_valid(c))
		var peat: Array = vida._peatones.filter(func(c): return is_instance_valid(c))
		max_coches = maxi(max_coches, coches.size())
		max_peat = maxi(max_peat, peat.size())
		for c in coches:
			if c.espera > 5.0 and muestras % 6 == 0:
				print("  atascado ", c.global_position, " tramo ", c.desde, "->", c.hacia, " d ", c.d, " por ", c.bloqueo)
			atascos_max = maxf(atascos_max, c.espera)
			if c.t_golpe > 0.0 and not vistos_golpe.has(c.get_instance_id()):
				vistos_golpe[c.get_instance_id()] = true
				golpes += 1
			if c.vel < 0.2:
				parados_cruce += 1
		for i in coches.size():
			for k in range(i + 1, coches.size()):
				var a = coches[i]
				var b = coches[k]
				if a.fantasma > 0.0 or b.fantasma > 0.0:
					continue
				if a.global_position.distance_to(b.global_position) < 2.6:
					solapes += 1
		for q in peat:
			if q.estado == 2 and q.cruce_nodo.x != -9999:
				var clave: String = "%d" % q.get_instance_id()
				if not vistos_cruza.has(clave):
					vistos_cruza[clave] = true
					cruces += 1
			if q.estado == 3:
				heridos += 1
			if q.estado == 2 and q.cruce_nodo.x != -9999:
				for c in coches:
					if c.vel > 2.5 and c.global_position.distance_to(q.global_position) < 3.5:
						infracciones += 1
			if q.estado == 4:
				libres += 1
			if q.estado == 0 or q.estado == 1:
				if _en_calzada(q):
					peat_calzada += 1
	print("Muestras ", muestras, " | coches máx ", max_coches, " peatones máx ", max_peat)
	print("Espera máxima de un coche sin motivo: %.1f s" % atascos_max)
	print("Coches solapados (muestras): ", solapes)
	print("Peatones andando por la calzada (muestras): ", peat_calzada)
	print("Peatones distintos que cruzaron por paso: ", cruces, " | muestras cruzando sin paso: ", libres)
	print("Coches que no cedieron a alguien en un paso (muestras): ", infracciones)
	print("Heridos en el suelo (muestras): ", heridos)
	print("Atropellos por coches de la ciudad: ", golpes)
	if atascos_max > 20.0:
		fallos.append("coche atascado %.1f s" % atascos_max)
	if infracciones > 0:
		fallos.append("coches sin ceder el paso")
	if peat_calzada > 0:
		fallos.append("peatones por la calzada")
	if solapes > muestras / 4:
		fallos.append("demasiados coches solapados")
	if fallos.is_empty():
		print("RESULTADO: TODO BIEN")
	else:
		print("RESULTADO: FALLO ", fallos)
	get_tree().quit()


func _en_calzada(q: Node3D) -> bool:
	var red: Dictionary = q.red
	var pos: Vector2 = Vector2(q.global_position.x, q.global_position.z)
	var medio: float = float(red["ancho"]) * 0.5 - 0.3
	for nodo in red["pos"]:
		for v in red["vec"][nodo]:
			var a: Vector2 = red["pos"][nodo]
			var b: Vector2 = red["pos"][v]
			var cp: Vector2 = Geometry2D.get_closest_point_to_segment(pos, a, b)
			if cp.distance_to(pos) < medio:
				# En el cruce (dentro del cuadrado central) tampoco debería estar andando.
				return true
	return false
