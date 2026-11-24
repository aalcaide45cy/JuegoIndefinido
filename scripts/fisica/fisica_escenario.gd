# fisica_escenario.gd
# -----------------------------------------------------------------------------
# Efectos de física y destrucción que usan los objetos del escenario (y que
# pueden usar las armas, las explosiones o los vehículos):
#   - onda(): onda expansiva de una explosión. Empuja TODO cuerpo rígido cercano
#     (objetos, escombros, y en el futuro coches y cuerpos) y daña los objetos.
#   - impacto_bala(): lo que hace una bala al dar en algo con física.
#   - estallar(): un objeto se rompe en sus piezas, que salen volando.
#   - particulas(): chispas (metal), astillas (madera), polvo (piedra),
#     cristales, trocitos de plástico o de cerámica.
#   - chorro(): el géiser de una boca de riego rota.
# Todo tiene tope (MAX_ESCOMBROS, MAX_PARTICULAS) para no hundir los FPS, y se
# puede apagar o rebajar desde el panel de admin (activa, calidad).
# -----------------------------------------------------------------------------
class_name FisicaEscenario
extends RefCounted

const CAPA_ESCOMBROS: int = 16   # Capa 5: los escombros chocan con el mundo y los objetos, no entre sí.
const MAX_ESCOMBROS: Array = [12, 60, 140]   # Por calidad (0 baja, 1 media, 2 alta).
const MAX_PARTICULAS: Array = [8, 20, 36]
const VIDA_ESCOMBRO: Array = [5.0, 10.0, 16.0]

static var activa: bool = true
static var calidad: int = -1          # -1 = la del menú de gráficos ("destruccion"); 0-2 para forzarla.
static var pendientes: Array = []     # Bidones que explotan en el siguiente fotograma: [padre, pos].
static var _escombros: Array = []
static var _particulas: Array = []
static var _recursos: Dictionary = {} # Mallas, materiales y curvas de partículas (compartidos).
static var _formas_escombro: Dictionary = {}


# Calidad de los efectos: 0 baja, 1 media, 2 alta.
static func _q() -> int:
	if calidad >= 0:
		return clampi(calidad, 0, 2)
	return clampi(int(Graficos.v.get("destruccion", 2)), 0, 2)


static func _raiz(nodo: Node) -> Node:
	if nodo == null or not nodo.is_inside_tree():
		return null
	var escena: Node = nodo.get_tree().current_scene
	return escena if escena != null else nodo.get_tree().root


# -------------------------------------------------------- onda expansiva ----

# Explosión en "pos" de "radio" metros. Llamada desde Combate.explosion().
static func onda(padre: Node3D, pos: Vector3, radio: float, dano: float) -> void:
	if not activa or padre == null or not padre.is_inside_tree():
		return
	var alcance: float = radio * 1.6
	var consulta: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var esfera: SphereShape3D = SphereShape3D.new()
	esfera.radius = alcance
	consulta.shape = esfera
	consulta.transform = Transform3D(Basis(), pos)
	# Dos consultas: primero solo objetos y escombros (así los miles de troncos y muros del trozo
	# no llenan la lista y dejan fuera un bidón), luego la capa 1 para coches o cuerpos rígidos.
	var espacio: PhysicsDirectSpaceState3D = padre.get_world_3d().direct_space_state
	consulta.collision_mask = ObjetoFisico.CAPA | CAPA_ESCOMBROS
	var res: Array = espacio.intersect_shape(consulta, 160)
	consulta.collision_mask = 1
	res.append_array(espacio.intersect_shape(consulta, 64))
	var vistos: Dictionary = {}
	for r in res:
		var cuerpo: Object = r["collider"]
		if not (cuerpo is RigidBody3D) or vistos.has(cuerpo):
			continue
		vistos[cuerpo] = true
		var rb: RigidBody3D = cuerpo as RigidBody3D
		var off: Vector3 = rb.global_position - pos
		var d: float = off.length()
		var k: float = clampf(1.0 - d / alcance, 0.0, 1.0)
		if k <= 0.0:
			continue
		var dir: Vector3 = (off.normalized() + Vector3.UP * 0.8).normalized() if d > 0.05 else Vector3.UP
		var dv: float = minf(26.0, (4.0 + 18.0 * k) * sqrt(maxf(radio, 1.0) / 6.0))
		if rb is ObjetoFisico:
			(rb as ObjetoFisico).onda_expansiva(dir, dv, dano * k * 1.6)
		elif rb.has_method("onda_expansiva"):
			rb.call("onda_expansiva", dir, dv, dano * k)
		else:
			if rb.freeze:
				continue   # Congelado y sin saber qué es: mejor no tocarlo.
			rb.sleeping = false
			rb.apply_impulse(dir * dv * rb.mass, Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.3), randf_range(-0.2, 0.2)))
	# Polvo y cascotes que levanta la explosión del suelo.
	particulas(padre, pos, Vector3.UP, "polvo", clampf(radio / 4.0, 0.6, 2.0))
	_avisar_ia(padre, pos, radio)


# Si la rama de comportamiento de personajes está unida, avisa a los PNJ (huyen, se agachan...).
static func _avisar_ia(padre: Node, pos: Vector3, radio: float) -> void:
	const RUTA: String = "res://scripts/ia/estimulos_ia.gd"
	if not ResourceLoader.exists(RUTA):
		return
	var s: Script = load(RUTA)
	if s == null:
		return
	for m in s.get_script_method_list():
		if str(m.get("name", "")) == "emitir":
			s.call("emitir", padre.get_tree(), "explosion", pos, radio * 3.0, true)
			return


static func explotar_bidon(padre: Node3D, pos: Vector3) -> void:
	if is_instance_valid(padre) and padre.is_inside_tree():
		Combate.explosion(padre, pos, 6.0, 90.0)


# GestorFisica lo llama en cada fotograma de física.
static func procesar_pendientes() -> void:
	if pendientes.is_empty():
		return
	var lista: Array = pendientes.duplicate()
	pendientes.clear()
	for p in lista:
		explotar_bidon(p[0], p[1])


# --------------------------------------------------------------- balas ------

# Para el hilo de armas: llama a esto con el resultado del rayo de la bala. Empuja cualquier
# cuerpo rígido y, si es un objeto del escenario, le hace daño y saca sus partículas.
# Devuelve true si ha dado en algo con física (para no poner la marca de bala de pared).
static func impacto_bala(choque: Dictionary, dir: Vector3, dano: float, impulso: float = -1.0) -> bool:
	if choque.is_empty():
		return false
	var cuerpo: Object = choque["collider"]
	if impulso < 0.0:
		impulso = dano * 0.8
	if cuerpo is ObjetoFisico:
		(cuerpo as ObjetoFisico).impacto(choque["position"], dir.normalized(), dano, impulso, choque["normal"])
		return true
	if cuerpo is RigidBody3D and not (cuerpo as RigidBody3D).freeze:
		var rb: RigidBody3D = cuerpo as RigidBody3D
		rb.sleeping = false
		rb.apply_impulse(dir.normalized() * impulso, (choque["position"] as Vector3) - rb.global_position)
		return true
	return false


# ---------------------------------------------------------- escombros -------

# El objeto se rompe: cada pieza se convierte en un escombro con física que sale
# disparado. Si tiene pocas piezas, se trocean para que no quede un solo bloque.
static func estallar(origen: Node3D, piezas: Array, xf: Transform3D, vel: Vector3, empuje_dv: Vector3,
		mat: String) -> void:
	var raiz: Node = _raiz(origen)
	if raiz == null or not activa:
		return
	var lista: Array = _trocear(piezas)
	var maximo: int = [3, 6, 10][_q()]
	if lista.size() > maximo:
		lista.shuffle()
		lista.resize(maximo)
	var centro: Vector3 = xf.origin
	for p in lista:
		var pos_local: Vector3
		var tam: Vector3
		if p[0] == "c":
			pos_local = p[1]
			tam = p[2]
		else:
			var dim: Vector3 = p[2]
			var r: float = maxf(dim.x, dim.z)
			pos_local = (p[1] as Vector3) + Vector3(0, dim.y / 2.0, 0)
			tam = Vector3(r * 1.5, dim.y, r * 1.5)
		var pos: Vector3 = xf * pos_local
		var fuera: Vector3 = (pos - centro)
		fuera = fuera.normalized() if fuera.length() > 0.01 else Vector3(randf_range(-1, 1), 1, randf_range(-1, 1)).normalized()
		var v: Vector3 = vel + empuje_dv * randf_range(0.6, 1.2) + fuera * randf_range(1.0, 3.5) + Vector3.UP * randf_range(0.5, 2.5)
		escombro(raiz, Transform3D(xf.basis, pos), tam, p[3], v, mat)
	particulas(origen, centro + Vector3.UP * 0.4, Vector3.UP, mat, 1.6)
	if mat == "madera" or mat == "piedra" or mat == "ceramica":
		particulas(origen, centro + Vector3.UP * 0.3, Vector3.UP, "polvo", 0.8)
	Sonido.tocar(origen, "golpe", -2.0)


# Parte las piezas grandes por la mitad (por su lado más largo) hasta tener al menos 4.
static func _trocear(piezas: Array) -> Array:
	var lista: Array = piezas.duplicate()
	var vueltas: int = 0
	while lista.size() < 4 and vueltas < 6:
		vueltas += 1
		var mayor: int = 0
		var vol_mayor: float = -1.0
		for i in lista.size():
			var t: Vector3 = _tam_pieza(lista[i])
			var vol: float = t.x * t.y * t.z
			if vol > vol_mayor:
				vol_mayor = vol
				mayor = i
		var p: Array = lista[mayor]
		var c: Vector3 = p[1] if p[0] == "c" else (p[1] as Vector3) + Vector3(0, (p[2] as Vector3).y / 2.0, 0)
		var t2: Vector3 = _tam_pieza(p)
		var eje: int = 0 if t2.x >= t2.y and t2.x >= t2.z else (1 if t2.y >= t2.z else 2)
		var mitad: Vector3 = t2
		mitad[eje] = t2[eje] / 2.0
		var paso: Vector3 = Vector3.ZERO
		paso[eje] = t2[eje] / 4.0
		lista.remove_at(mayor)
		lista.append(["c", c - paso, mitad * 0.96, p[3]])
		lista.append(["c", c + paso, mitad * 0.96, (p[3] as Color).darkened(0.08)])
	return lista


static func _tam_pieza(p: Array) -> Vector3:
	if p[0] == "c":
		return p[2]
	var dim: Vector3 = p[2]
	var r: float = maxf(dim.x, dim.z)
	return Vector3(r * 1.5, dim.y, r * 1.5)


# Un trozo suelto con física que se encoge y desaparece a los pocos segundos.
static func escombro(raiz: Node, xf: Transform3D, tam: Vector3, color: Color, vel: Vector3, mat: String) -> RigidBody3D:
	tam = tam.max(Vector3.ONE * 0.04)
	var rb: RigidBody3D = RigidBody3D.new()
	rb.collision_layer = CAPA_ESCOMBROS
	rb.collision_mask = 1 | ObjetoFisico.CAPA
	var densidad: float = 600.0 if mat == "madera" else (2000.0 if mat == "piedra" or mat == "ceramica" else 1500.0)
	rb.mass = clampf(tam.x * tam.y * tam.z * densidad, 0.2, 60.0)
	rb.angular_damp = 0.8
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = tam
	bm.material = Construir.material(color)
	mi.mesh = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if _q() < 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	rb.add_child(mi)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var clave: String = "%.2f_%.2f_%.2f" % [tam.x, tam.y, tam.z]
	if not _formas_escombro.has(clave):
		var f: BoxShape3D = BoxShape3D.new()
		f.size = tam
		_formas_escombro[clave] = f
	cs.shape = _formas_escombro[clave]
	rb.add_child(cs)
	raiz.add_child(rb)
	rb.global_transform = xf
	rb.linear_velocity = vel
	rb.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	# Se queda un rato en el suelo, luego encoge y se va.
	var tw: Tween = rb.create_tween()
	tw.tween_interval(VIDA_ESCOMBRO[_q()] * randf_range(0.8, 1.2))
	tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.8)
	tw.tween_callback(rb.queue_free)
	_escombros.append(rb)
	var tope: int = MAX_ESCOMBROS[_q()]
	while _escombros.size() > tope:
		var viejo = _escombros.pop_front()
		if is_instance_valid(viejo):
			viejo.queue_free()
	return rb


# ---------------------------------------------------------- partículas ------

# "tipo": metal/chispas, madera, piedra/polvo, cristal, plastico, ceramica, agua.
static func particulas(origen: Node, pos: Vector3, normal: Vector3, tipo: String, cantidad: float = 1.0) -> void:
	if not activa:
		return
	var raiz: Node = _raiz(origen)
	if raiz == null:
		return
	if _particulas.size() >= MAX_PARTICULAS[_q()]:
		var vieja = _particulas.pop_front()
		if is_instance_valid(vieja):
			vieja.queue_free()
	var mult: float = cantidad * [0.4, 0.7, 1.0][_q()]
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.local_coords = false
	p.direction = normal.normalized() if normal.length() > 0.01 else Vector3.UP
	p.gravity = Vector3(0, -9.8, 0)
	var t: String = tipo
	if t == "metal":
		t = "chispas"
	match t:
		"chispas":
			p.amount = maxi(4, int(14 * mult))
			p.lifetime = 0.45
			p.spread = 55.0
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 9.0
			p.mesh = _malla("chispa")
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.2
			# Otro puñado más lento de trocitos de metal gris.
			_trocitos(raiz, pos, normal, Color(0.45, 0.46, 0.5), mult * 0.5)
		"madera":
			p.amount = maxi(4, int(12 * mult))
			p.lifetime = 0.9
			p.spread = 60.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 5.0
			p.mesh = _malla("astilla")
			p.angular_velocity_min = -400.0
			p.angular_velocity_max = 400.0
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.3
		"piedra", "polvo":
			p.amount = maxi(4, int(10 * mult))
			p.lifetime = 1.6
			p.spread = 70.0
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 2.2
			p.gravity = Vector3(0, 0.4, 0)
			p.damping_min = 1.0
			p.damping_max = 2.0
			p.mesh = _malla("polvo")
			p.scale_amount_min = 0.8 * maxf(1.0, cantidad)
			p.scale_amount_max = 1.8 * maxf(1.0, cantidad)
			p.scale_amount_curve = _curva_crecer()
			p.color_ramp = _rampa(Color(0.55, 0.52, 0.48, 0.55))
			if t == "piedra":
				_trocitos(raiz, pos, normal, Color(0.5, 0.49, 0.47), mult)
		"cristal":
			p.amount = maxi(6, int(18 * mult))
			p.lifetime = 1.1
			p.spread = 70.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 4.5
			p.mesh = _malla("cristal")
			p.angular_velocity_min = -600.0
			p.angular_velocity_max = 600.0
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.4
		"ceramica":
			p.amount = maxi(5, int(12 * mult))
			p.lifetime = 0.9
			p.spread = 70.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 5.0
			p.mesh = _malla("ceramica")
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.5
		"agua":
			p.amount = maxi(8, int(20 * mult))
			p.lifetime = 0.9
			p.spread = 40.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 4.0
			p.mesh = _malla("agua")
		_:   # plástico
			p.amount = maxi(4, int(10 * mult))
			p.lifetime = 0.8
			p.spread = 65.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 5.0
			p.mesh = _malla("plastico")
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.2
	raiz.add_child(p)
	p.global_position = pos
	p.emitting = true
	_particulas.append(p)
	p.get_tree().create_timer(p.lifetime + 0.4, false).timeout.connect(p.queue_free)


# Trocitos que rebotan en el suelo (partículas con gravedad fuerte).
static func _trocitos(raiz: Node, pos: Vector3, normal: Vector3, color: Color, mult: float) -> void:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.amount = maxi(3, int(8 * mult))
	p.lifetime = 0.9
	p.direction = normal.normalized() if normal.length() > 0.01 else Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -12.0, 0)
	p.mesh = _malla("trozo")
	p.color = color
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	raiz.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(1.3, false).timeout.connect(p.queue_free)


# El chorro de agua de una boca de riego rota (dura unos 12 segundos).
static func chorro(padre: Node3D, pos: Vector3) -> void:
	if not activa or not padre.is_inside_tree():
		return
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = [16, 32, 56][_q()]
	p.lifetime = 1.6
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 9.0
	p.initial_velocity_min = 7.0
	p.initial_velocity_max = 10.0
	p.gravity = Vector3(0, -9.8, 0)
	p.mesh = _malla("agua")
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	padre.add_child(p)
	p.global_position = pos
	p.emitting = true
	var tw: Tween = p.create_tween()
	tw.tween_interval(12.0)
	tw.tween_property(p, "emitting", false, 0.0)
	tw.tween_interval(p.lifetime + 0.2)
	tw.tween_callback(p.queue_free)


# --------------------------------------------------------- recursos ---------

static func _malla(nombre: String) -> Mesh:
	if _recursos.has(nombre):
		return _recursos[nombre]
	var m: Mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.roughness = 0.8
	match nombre:
		"chispa":
			var b: BoxMesh = BoxMesh.new()
			b.size = Vector3(0.025, 0.025, 0.09)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(1.0, 0.75, 0.3)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.6, 0.2)
			mat.emission_energy_multiplier = 4.0
			b.material = mat
			m = b
		"astilla":
			var b2: BoxMesh = BoxMesh.new()
			b2.size = Vector3(0.025, 0.025, 0.14)
			mat.albedo_color = Color(0.62, 0.45, 0.26)
			b2.material = mat
			m = b2
		"polvo":
			var e: SphereMesh = SphereMesh.new()
			e.radius = 0.22
			e.height = 0.44
			e.radial_segments = 6
			e.rings = 3
			mat.vertex_color_use_as_albedo = true
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(1, 1, 1, 1)
			e.material = mat
			m = e
		"cristal":
			var b3: BoxMesh = BoxMesh.new()
			b3.size = Vector3(0.07, 0.006, 0.05)
			mat.albedo_color = Color(0.75, 0.9, 1.0, 0.7)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.metallic = 0.3
			mat.roughness = 0.05
			mat.emission_enabled = true
			mat.emission = Color(0.4, 0.5, 0.6)
			mat.emission_energy_multiplier = 0.4
			b3.material = mat
			m = b3
		"ceramica":
			var b4: BoxMesh = BoxMesh.new()
			b4.size = Vector3(0.07, 0.03, 0.06)
			mat.albedo_color = Color(0.68, 0.38, 0.24)
			b4.material = mat
			m = b4
		"agua":
			var e2: SphereMesh = SphereMesh.new()
			e2.radius = 0.1
			e2.height = 0.2
			e2.radial_segments = 5
			e2.rings = 2
			mat.albedo_color = Color(0.7, 0.85, 1.0, 0.65)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.roughness = 0.1
			e2.material = mat
			m = e2
		"trozo":
			var b5: BoxMesh = BoxMesh.new()
			b5.size = Vector3(0.05, 0.04, 0.05)
			mat.vertex_color_use_as_albedo = true
			b5.material = mat
			m = b5
		_:
			var b6: BoxMesh = BoxMesh.new()
			b6.size = Vector3(0.06, 0.02, 0.05)
			mat.albedo_color = Color(0.85, 0.85, 0.82)
			b6.material = mat
			m = b6
	_recursos[nombre] = m
	return m


static func _curva_crecer() -> Curve:
	if not _recursos.has("curva_crecer"):
		var c: Curve = Curve.new()
		c.add_point(Vector2(0.0, 0.4))
		c.add_point(Vector2(0.4, 1.0))
		c.add_point(Vector2(1.0, 1.3))
		_recursos["curva_crecer"] = c
	return _recursos["curva_crecer"]


static func _rampa(color: Color) -> Gradient:
	var clave: String = "rampa_" + color.to_html(true)
	if not _recursos.has(clave):
		var g: Gradient = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		var fin: Color = color
		fin.a = 0.0
		g.colors = PackedColorArray([color, fin])
		_recursos[clave] = g
	return _recursos[clave]
