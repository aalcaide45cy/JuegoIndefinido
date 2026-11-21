# Prueba de los giros de los coches (vida_urbana.gd). Sin ventana:
#   godot --headless --path . res://tests/prueba_giros.tscn -- [segundos] [tipo 1|2|3]
# Mide en cada fotograma: saltos de posición (teletransportes), giro máximo por segundo y
# cuántas curvas completaron los coches. Acaba en "TODO BIEN" o con la lista de fallos.
extends Node

var vida: Node
var fallos: Array = []
var previos: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var segundos: float = float(args[0]) if args.size() > 0 else 120.0
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
	var jugador: Node3D = hud.jugador
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
	var h: float = GeneradorMundo.altura(p.x, p.y) if tipo < 3 else 0.0
	print("Probando giros en ", elegido["nombre"], " (tipo ", tipo, ") durante ", segundos, " s")
	var t: float = 0.0
	var curvas: int = 0
	var saltos: int = 0
	var giro_max: float = 0.0
	var vel_curva_max: float = 0.0
	var vel_curva_min: float = 99.0
	var en_curva: Dictionary = {}
	while t < segundos:
		jugador.global_position = Vector3(p.x + 2.0, h + 30.0, p.y + 2.0)
		jugador.velocity = Vector3.ZERO
		await get_tree().physics_frame
		var dt: float = get_physics_process_delta_time()
		t += dt
		for c in vida._coches:
			if not is_instance_valid(c):
				continue
			var id: int = c.get_instance_id()
			var pos: Vector3 = c.global_position
			var yaw: float = c.rotation.y
			if previos.has(id):
				var pr: Array = previos[id]
				var salto: float = pos.distance_to(pr[0])
				var maxpaso: float = maxf(c.vmax, 12.0) * dt * 1.5 + 0.05
				if salto > maxpaso:
					saltos += 1
					if saltos < 6:
						print("  SALTO de %.2f m (limite %.2f) de %s a %s tramo %s->%s giro %s t=%.3f vel=%.2f d=%.2f sig=%s" % [salto, maxpaso, str(pr[0]), str(pos), c.desde, c.hacia, c.en_giro, c.curva_t, c.vel, c.d, c.sig])
				var dy: float = absf(angle_difference(yaw, pr[1])) / dt
				if dy > giro_max:
					giro_max = dy
			previos[id] = [pos, yaw]
			if c.en_giro:
				en_curva[id] = true
				vel_curva_max = maxf(vel_curva_max, c.vel)
				vel_curva_min = minf(vel_curva_min, c.vel)
			elif en_curva.has(id):
				en_curva.erase(id)
				curvas += 1
	print("Curvas completadas: %d, saltos: %d, giro maximo: %.2f rad/s (%.0f grados/s), velocidad en curva %.1f - %.1f m/s" % [curvas, saltos, giro_max, rad_to_deg(giro_max), vel_curva_min, vel_curva_max])
	if curvas < 3 and tipo < 3:   # En la ciudad original casi no hay giros (solo vueltas en U al final de calle).
		fallos.append("pocas curvas completadas (%d)" % curvas)
	if saltos > 0:
		fallos.append("%d saltos de posicion" % saltos)
	if giro_max > 2.2:
		fallos.append("giro demasiado brusco (%.2f rad/s)" % giro_max)
	if fallos.is_empty():
		print("TODO BIEN")
	else:
		print("FALLOS: ", fallos)
	get_tree().quit()
