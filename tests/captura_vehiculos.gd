extends Node
# Monta cada vehiculo en una rejilla, mide y hace capturas. Uso:
# godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_vehiculos.tscn -- /carpeta

var carpeta: String = "."

func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [carpeta, nombre])
	print("FOTO ", nombre)

func _aabb_mallas(n: Node, acum: Array) -> void:
	if n is MeshInstance3D:
		var a: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
		acum.append(a)
	for h in n.get_children():
		_aabb_mallas(h, acum)

func _union(n: Node) -> AABB:
	var l: Array = []
	_aabb_mallas(n, l)
	var r: AABB = l[0]
	for a in l:
		r = r.merge(a)
	return r

func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	var suelo: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(120, 80)
	suelo.mesh = pm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.55, 0.5)
	suelo.material_override = mat
	add_child(suelo)
	var sol: DirectionalLight3D = DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sol)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.7, 0.8, 0.95)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	add_child(env)
	var claves: Array = ModeloVehiculo.claves()
	var i: int = 0
	var modelos: Dictionary = {}
	for c in claves:
		var largo: float = float(Vehiculo.TIPOS[c]["largo"]) if Vehiculo.TIPOS.has(c) else 5.0
		var r: Dictionary = ModeloVehiculo.crear(c, largo, true)
		if r.is_empty():
			print("FALTA ", c)
			continue
		var nodo: Node3D = r["nodo"]
		var col: int = i % 5
		var fila: int = i / 5
		nodo.position = Vector3(-40 + col * 20, 0, -20 + fila * 18)
		add_child(nodo)
		var lb: Label3D = Label3D.new()
		lb.text = c
		lb.font_size = 140
		lb.position = nodo.position + Vector3(0, 0.1, 5.5)
		lb.rotation_degrees.x = -90
		add_child(lb)
		modelos[c] = r
		i += 1
	await get_tree().process_frame
	await get_tree().process_frame
	for c in modelos:
		var r: Dictionary = modelos[c]
		var nodo: Node3D = r["nodo"]
		var cuerpo: AABB = _union(nodo)
		var largo: float = float(Vehiculo.TIPOS[c]["largo"]) if Vehiculo.TIPOS.has(c) else 5.0
		var s: String = "%s largo_pedido=%.2f caja z=%.2f x=%.2f y=[%.2f..%.2f]" % [c, largo, cuerpo.size.z, cuerpo.size.x, cuerpo.position.y - nodo.global_position.y, cuerpo.end.y - nodo.global_position.y]
		var rm: float = 99.0
		for g in r["giros"]:
			var a: AABB = _union(g)
			rm = minf(rm, a.position.y - nodo.global_position.y)
		if r["giros"].size() > 0:
			s += " rueda_min_y=%.3f" % rm
		print(s)
	# Vistas
	var cam: Camera3D = Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0, 38, 55)
	cam.look_at(Vector3(0, 0, -2))
	await _foto("veh_01_rejilla_3_4")
	cam.global_position = Vector3(0, 70, 1)
	cam.look_at(Vector3(0, 0, 0), Vector3(0, 0, -1))
	await _foto("veh_02_rejilla_arriba")
	# Lateral desde +X
	cam.global_position = Vector3(60, 3, -2)
	cam.fov = 22
	cam.look_at(Vector3(-5, 2, -2))
	await _foto("veh_03_lateral")
	# Rodar y virar: comprobar signos
	var sed: Dictionary = modelos["sedan"]
	var g0: Node3D = sed["giros"][0]
	var rx0: float = g0.rotation.x
	for p in sed["pivotes"]:
		p.rotation.y = 0.5   # izquierda
	g0.rotation.x -= 1.0
	cam.fov = 40
	cam.global_position = (sed["nodo"] as Node3D).global_position + Vector3(0, 14, -9)
	cam.look_at((sed["nodo"] as Node3D).global_position)
	await _foto("veh_04_sedan_viraje_izquierda")
	get_tree().quit()
