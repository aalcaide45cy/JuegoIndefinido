# Prueba de los peatones: que no atraviesen edificios y que sus piernas vayan al ritmo de su velocidad.
#   godot --headless --path . res://tests/prueba_peatones.tscn
# 1) Pueblos y ciudades generados: para cada casa o servicio de cada asentamiento se mide la
#    distancia hasta la línea por la que andan los peatones (a 2 m de la calzada, más el
#    zigzag de los borrachos). Debe ser mayor que el radio del peatón.
# 2) Ciudad original: se barre una cápsula del tamaño de un peatón por sus aceras con el motor de
#    físicas y se cuentan los choques con cosas macizas.
# 3) Animación: el ritmo de Walk/Run sale de dividir la velocidad entre la que "recorre" la animación.
extends Node

const RADIO: float = 0.35
const ZIGZAG: float = 0.7
const SEGUNDOS: float = 40.0

var fallos: Array = []


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
	_pueblos()
	await _ciudad_original(escena, hud, J)
	_animacion()
	if fallos.is_empty():
		print("RESULTADO: TODO BIEN")
	else:
		print("RESULTADO: FALLO ", fallos)
	get_tree().quit()


# Distancia mínima entre una línea de acera y un rectángulo de casa.
func _dist_rect(p: Vector2, x: float, z: float, w: float, d: float) -> float:
	var dx: float = maxf(absf(p.x - x) - w / 2.0, 0.0)
	var dz: float = maxf(absf(p.y - z) - d / 2.0, 0.0)
	return Vector2(dx, dz).length()


func _pueblos() -> void:
	var hs: float = GeneradorMundo.CALLE_ANCHO * 0.5 + 2.0
	var total: int = 0
	var casas: int = 0
	var choques: int = 0
	var peor: float = 99.0
	var por_tipo: Dictionary = {}
	for s in GeneradorMundo.todos_asentamientos():
		total += 1
		var n: int = int(s["n"])
		var p: Vector2 = s["pos"]
		var tipo: int = int(s["tipo"])
		por_tipo[tipo] = int(por_tipo.get(tipo, 0)) + 1
		for k in range(-n, n):
			for l in range(-n, n):
				for sub in 4:
					var c: Dictionary = GeneradorMundo.casa(s, k, l, sub)
					if c.is_empty():
						continue
					casas += 1
					var cx: float = c["x"]
					var cz: float = c["z"]
					var w: float = c["w"]
					var d: float = c["d"]
					# Las aceras que rodean la manzana (k, l): a hs del eje de cada calle.
					var x0: float = p.x + k * GeneradorMundo.BLOQUE
					var z0: float = p.y + l * GeneradorMundo.BLOQUE
					var x1: float = x0 + GeneradorMundo.BLOQUE
					var z1: float = z0 + GeneradorMundo.BLOQUE
					var menor: float = 99.0
					for lat in [hs - ZIGZAG, hs, hs + ZIGZAG]:
						for paso in range(0, 45):
							var t: float = hs + float(paso) * 0.8
							# Calle del borde izquierdo (x0) y derecho (x1): aceras en x0 + lat y x1 - lat.
							menor = minf(menor, _dist_rect(Vector2(x0 + lat, z0 + t), cx, cz, w, d))
							menor = minf(menor, _dist_rect(Vector2(x1 - lat, z0 + t), cx, cz, w, d))
							menor = minf(menor, _dist_rect(Vector2(x0 + t, z0 + lat), cx, cz, w, d))
							menor = minf(menor, _dist_rect(Vector2(x0 + t, z1 - lat), cx, cz, w, d))
					peor = minf(peor, menor)
					if menor < RADIO:
						choques += 1
						if choques <= 6:
							print("  casa dentro de la acera: ", s["nombre"], " bloque ", k, ",", l, " solar ", sub, " distancia ", menor)
	print("Asentamientos ", total, " ", por_tipo, " | casas ", casas, " | casas que pisan la acera ", choques, " | holgura mínima %.2f m" % peor)
	if choques > 0:
		fallos.append("%d casas pisan la acera de los peatones" % choques)


# Se coloca al jugador en la ciudad original y en un pueblo, deja andar a los peatones y barre una
# cápsula en el sitio de cada uno (sin contar a otros agentes) para ver si están dentro de algo macizo.
func _ciudad_original(escena: Node, hud: Node, J: Node) -> void:
	var jugador: Node3D = hud.jugador
	var vida: Node = escena.find_children("*", "VidaUrbana", true, false)[0]
	J.modo_volar = true
	J.hora = 12.0
	var forma: CapsuleShape3D = CapsuleShape3D.new()
	forma.radius = RADIO
	forma.height = 1.4   # Del tobillo (0,4 m) a los hombros (1,8 m): ni bordillos ni copas bajas de los árboles de la acera.
	var lugares: Array = [["ciudad original", Vector2(20.0, -20.0), 0.0]]
	var vistos: Dictionary = {}
	for tipo in [0, 1, 2]:
		for clave in GeneradorMundo._asentamientos:
			var s: Dictionary = GeneradorMundo._asentamientos[clave]
			if int(s["tipo"]) == tipo and not bool(s.get("montana", false)) and not vistos.has(tipo):
				vistos[tipo] = true
				lugares.append([str(s["nombre"]) + " (tipo %d)" % tipo, s["pos"], GeneradorMundo.altura(s["pos"].x, s["pos"].y)])
	for lugar in lugares:
		var p: Vector2 = lugar[1]
		var h: float = lugar[2]
		var muestras: int = 0
		var dentro: int = 0
		var rozan_libres: int = 0
		var max_peat: int = 0
		var ejemplos: Array = []
		var t: float = 0.0
		while t < SEGUNDOS:
			jugador.global_position = Vector3(p.x + 2.0, h + 30.0, p.y + 2.0)
			jugador.velocity = Vector3.ZERO
			await get_tree().create_timer(0.5).timeout
			t += 0.5
			var espacio: PhysicsDirectSpaceState3D = jugador.get_world_3d().direct_space_state
			var peat: Array = vida._peatones.filter(func(q): return is_instance_valid(q))
			max_peat = maxi(max_peat, peat.size())
			for q in peat:
				if q.estado == 3:
					continue
				muestras += 1
				var cons: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
				cons.shape = forma
				cons.transform = Transform3D(Basis(), q.global_position + Vector3(0, 1.1, 0))
				cons.exclude = [jugador.get_rid()]
				for hit in espacio.intersect_shape(cons, 8):
					var o: Object = hit["collider"]
					if o is AnimatableBody3D or o is CharacterBody3D:
						continue   # Coches, otros peatones, guardias.
					if q.estado == 5:
						rozan_libres += 1   # Libre (huyendo, charlando...): rozar un tronco un instante se tolera.
						break
					dentro += 1
					if ejemplos.size() < 3:
						var cb: CollisionObject3D = o as CollisionObject3D
						var info: String = ""
						var dueno: int = cb.shape_find_owner(int(hit["shape"]))
						var cs: Node = cb.shape_owner_get_owner(dueno)
						if cs is CollisionShape3D and (cs as CollisionShape3D).shape is BoxShape3D:
							var cs3: CollisionShape3D = cs as CollisionShape3D
							info = "caja %s en (%.1f, %.1f, %.1f) girada %.0f, nombre %s, padre %s, abuelo %s" % [((cs3.shape as BoxShape3D).size), cs3.global_position.x, cs3.global_position.y, cs3.global_position.z, rad_to_deg(cs3.global_rotation.y), cs3.name, cs3.get_parent().name, cs3.get_parent().get_parent().name]
						if info == "" and cs is CollisionShape3D:
							var f3: CollisionShape3D = cs as CollisionShape3D
							info = "forma %s hueso %s en (%.1f, %.1f, %.1f) cuerpo %s ruta %s y_peaton %.2f" % [f3.shape.get_class(), f3.name, f3.global_position.x, f3.global_position.y, f3.global_position.z, cb.name, cb.get_path(), q.global_position.y]
						ejemplos.append("rel (%.1f, %.1f) estado %d %s" % [fposmod(q.global_position.x - p.x, 44.0), fposmod(q.global_position.z - p.y, 44.0), q.estado, info])
					break
		print("  ", lugar[0], ": peatones máx ", max_peat, " | muestras ", muestras, " | dentro de algo macizo ", dentro, " | libres que rozan algo ", rozan_libres, " ", ejemplos)
		if dentro > 0 or rozan_libres > maxi(2, muestras / 100):
			fallos.append("peatones dentro de edificios en " + str(lugar[0]))
		if lugar[0] == "ciudad original" and max_peat > 0:
			fallos.append("hay peatones en las avenidas de la ciudad original (no tienen acera)")


func _animacion() -> void:
	# A velocidad natural, ritmo 1; al doble de velocidad, el doble de ritmo (con tope).
	var p: Node3D = Assets.personaje("quaternius/toon-shooter-game-kit/Characters/Character_Hazmat", "", "Idle")
	add_child(p)
	var r: AnimationPlayer = p.get_meta("animaciones")
	var casos: Array = [[0.0, "Idle", 1.0], [Assets.VEL_ANIM_ANDAR, "Walk", 1.0], [1.05, "Walk", 0.5],
			[Assets.VEL_ANIM_CORRER, "Run", 1.0], [6.5, "Run", 6.5 / Assets.VEL_ANIM_CORRER]]
	for caso in casos:
		Assets.animar_por_velocidad(p, float(caso[0]))
		var nombre: String = r.current_animation.get_slice("|", r.current_animation.get_slice_count("|") - 1)
		var ok: bool = nombre == str(caso[1]) and absf(r.speed_scale - float(caso[2])) < 0.01
		print("  v=%.2f -> %s ritmo %.2f %s" % [float(caso[0]), nombre, r.speed_scale, "ok" if ok else "MAL"])
		if not ok:
			fallos.append("animación a %.2f m/s" % float(caso[0]))
	p.queue_free()
