# gore.gd
# -----------------------------------------------------------------------------
# Sangre, charcos, trozos y gritos: los efectos "de la vida misma" cuando alguien
# recibe un golpe, un disparo o un atropello. Todo con tope para no matar los FPS.
#
# Ajuste (Esc > Gráficos > Violencia, guardado en user://ajustes.cfg):
#   gore  0 = apagado (solo un destello y sonido de golpe), 1 = reducido, 2 = completo
#   gritos  true/false
#
#   Gore.salpicar(padre, pos, dir, fuerza)     chorro de sangre
#   Gore.charco(padre, pos, radio)             charco que crece y dura un rato
#   Gore.trozos(padre, pos, cuantos, dir)      miembros que saltan (solo gore completo)
#   Gore.muerte(padre, pos, dir, fuerza)       chorro de una muerte violenta (el charco lo pone Cuerpo
#                                              debajo del cadáver cuando acaba de caer)
#   Gore.herida(padre, pos, dir, tipo, f)      orificio de entrada y salida, neblina y mancha en la pared
#   Gore.mancha(padre, pos, normal, tam)       mancha de sangre pegada a una pared o al suelo
#   Gore.reventar(padre, pos, dir)             la cabeza estalla (francotirador, escopeta a bocajarro)
#   Gore.crujido(padre, pos, fuerte)           sonido de hueso roto al arrancar un miembro
#   Gore.chorro()                              partículas para un muñón que sangra
#   Gore.grito(padre, pos, tipo)               0 agudo, 1 grave, 2 dolor
# -----------------------------------------------------------------------------
class_name Gore
extends RefCounted

const MAX_CHARCOS: Array = [0, 14, 40]
const MAX_TROZOS: Array = [0, 0, 20]
const DURACION_CHARCO: Array = [0.0, 45.0, 120.0]
const MAX_MANCHAS: Array = [0, 30, 90]

static var _charcos: Array = []
static var _trozos: Array = []
static var _gritos: Array = []
static var _ultimo_grito: int = 0
static var _malla_gota: SphereMesh = null
static var _mat_sangre: StandardMaterial3D = null
static var _manchas: Array = []
static var _texturas_mancha: Array = []
static var _sonidos: Dictionary = {}
static var _malla_niebla: SphereMesh = null


static func nivel() -> int:
	return clampi(int(Graficos.v.get("gore", 2)), 0, 2)


static func gritos_activos() -> bool:
	return bool(Graficos.v.get("gritos", true))


static func _raiz(padre: Node) -> Node:
	var t: SceneTree = padre.get_tree()
	return t.current_scene if t.current_scene != null else t.root


static func _material() -> StandardMaterial3D:
	if _mat_sangre == null:
		_mat_sangre = StandardMaterial3D.new()
		_mat_sangre.albedo_color = Color(0.55, 0.02, 0.02)
		_mat_sangre.roughness = 0.3
	return _mat_sangre


# Chorro de gotas rojas desde pos, hacia dir.
static func salpicar(padre: Node, pos: Vector3, dir: Vector3 = Vector3.UP, fuerza: float = 1.0) -> void:
	var n: int = nivel()
	if n == 0 or padre == null or not padre.is_inside_tree():
		return
	salpicar_preparar()
	var p: CPUParticles3D = CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(clampf((8.0 if n == 1 else 22.0) * fuerza, 4.0, 40.0))
	p.lifetime = 0.8
	p.mesh = _malla_gota
	p.direction = dir.normalized() + Vector3.UP * 0.5
	p.spread = 45.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.5 * clampf(fuerza, 0.6, 2.0)
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	_raiz(padre).add_child(p)
	p.global_position = pos
	p.emitting = true
	padre.get_tree().create_timer(1.4).timeout.connect(p.queue_free)
	# Donde caen las gotas quedan manchitas en el suelo.
	var horiz: Vector3 = Vector3(dir.x, 0.0, dir.z)
	var manchitas: int = 1 if fuerza < 1.0 else (2 if n == 1 else 3)
	for k in manchitas:
		var donde: Vector3 = pos + horiz.normalized() * randf_range(0.4, 1.6) * clampf(fuerza, 0.5, 2.0) \
				+ Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
		var suelo: Dictionary = Combate.rayo(padre.get_world_3d(), donde + Vector3.UP * 0.5, Vector3.DOWN, 3.5, [])
		if not suelo.is_empty() and not (suelo["collider"] is Node and (suelo["collider"] as Node).has_method("recibir_dano")):
			mancha(padre, suelo["position"], suelo["normal"], randf_range(0.08, 0.2))


# Un charco en el suelo bajo pos: crece despacio y se desvanece al cabo de un rato.
static func charco(padre: Node, pos: Vector3, radio: float = 0.7) -> void:
	var n: int = nivel()
	if n == 0 or padre == null or not padre.is_inside_tree():
		return
	var y: float = pos.y
	var suelo: Dictionary = Combate.rayo(padre.get_world_3d(), pos + Vector3.UP * 1.0, Vector3.DOWN, 4.0, [])
	if not suelo.is_empty():
		y = suelo["position"].y
	if _texturas_mancha.is_empty():
		for k in 4:
			_texturas_mancha.append(_textura_mancha(k))
	var disco: MeshInstance3D = MeshInstance3D.new()
	var malla: QuadMesh = QuadMesh.new()
	malla.size = Vector2(radio, radio) * 2.6
	malla.orientation = PlaneMesh.FACE_Y
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = _texturas_mancha[randi() % _texturas_mancha.size()]
	mat.albedo_color = Color(0.3, 0.0, 0.0, 0.93)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.metallic_specular = 0.8
	malla.material = mat
	disco.mesh = malla
	disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_raiz(padre).add_child(disco)
	disco.global_position = Vector3(pos.x, y + 0.018 + randf() * 0.006, pos.z)
	disco.rotation.y = randf() * TAU
	disco.scale = Vector3(0.15, 1.0, 0.15)
	var anim: Tween = disco.create_tween()
	anim.tween_property(disco, "scale", Vector3(1.0, 1.0, 1.0), 7.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	anim.tween_interval(DURACION_CHARCO[n])
	anim.tween_property(mat, "albedo_color:a", 0.0, 6.0)
	anim.tween_callback(disco.queue_free)
	_charcos.append(disco)
	_recortar(_charcos, int(MAX_CHARCOS[n]))


# Miembros y trozos que saltan. Solo con gore completo.
static func trozos(padre: Node, pos: Vector3, cuantos: int, dir: Vector3 = Vector3.UP, cabeza: bool = false) -> void:
	if nivel() < 2 or padre == null or not padre.is_inside_tree():
		return
	var colores: Array = [Color(0.5, 0.03, 0.03), Color(0.62, 0.12, 0.1), Color(0.4, 0.02, 0.02), Color(0.7, 0.35, 0.32)]
	if cabeza:
		colores = [Color(0.72, 0.5, 0.42), Color(0.85, 0.6, 0.6), Color(0.5, 0.03, 0.03), Color(0.9, 0.88, 0.8)]
	for i in cuantos:
		var c: RigidBody3D = RigidBody3D.new()
		c.collision_layer = 0   # No empujan al jugador ni a los coches.
		c.collision_mask = 1
		c.mass = 0.5
		var tam: Vector3 = Vector3(randf_range(0.05, 0.12), randf_range(0.04, 0.1), randf_range(0.05, 0.12))
		var forma: CollisionShape3D = CollisionShape3D.new()
		var caja: BoxShape3D = BoxShape3D.new()
		caja.size = tam
		forma.shape = caja
		c.add_child(forma)
		var vista: MeshInstance3D = MeshInstance3D.new()
		var bm: SphereMesh = SphereMesh.new()   # Bulto irregular low poly (esfera de pocas caras aplastada).
		bm.radius = 0.5
		bm.height = 1.0
		bm.radial_segments = 5
		bm.rings = 3
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = colores[randi() % colores.size()]
		m.roughness = 0.3
		bm.material = m
		vista.mesh = bm
		vista.scale = tam
		c.add_child(vista)
		_raiz(padre).add_child(c)
		c.global_position = pos + Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.4), randf_range(-0.2, 0.2))
		c.linear_velocity = (dir.normalized() * randf_range(1.5, 4.0)) + Vector3(randf_range(-2, 2), randf_range(2.5, 5.5), randf_range(-2, 2))
		c.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		_trozos.append(c)
		padre.get_tree().create_timer(randf_range(18.0, 26.0)).timeout.connect(c.queue_free)
	_recortar(_trozos, int(MAX_TROZOS[nivel()]))


# Una muerte violenta: chorro fuerte. El charco lo pone Cuerpo bajo el cadáver
# cuando ha terminado de caer (antes salía en el sitio equivocado).
static func muerte(padre: Node, pos: Vector3, dir: Vector3 = Vector3.UP, fuerza: float = 1.0) -> void:
	salpicar(padre, pos + Vector3.UP * 0.9, dir, 1.0 + fuerza * 0.4)


# ------------------------------ Heridas de bala --------------------------------

# Orificio de entrada (poca sangre, hacia el que dispara), de salida (mucha, hacia
# delante), una neblina roja de un instante y manchas en lo que haya detrás.
static func herida(padre: Node, pos: Vector3, dir: Vector3, tipo: String = "bala", fuerza: float = 1.0) -> void:
	var n: int = nivel()
	if n == 0 or padre == null or not padre.is_inside_tree():
		return
	var d: Vector3 = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	match tipo:
		"bala", "perdigon":
			salpicar(padre, pos, -d + Vector3.UP * 0.2, 0.35 * fuerza)        # Entrada.
			salpicar(padre, pos + d * 0.15, d, 0.8 * fuerza)                  # Salida.
			niebla(padre, pos + d * 0.1, 0.25 + 0.1 * fuerza)
			_manchar_detras(padre, pos, d, 3.5, 0.25 + 0.15 * fuerza)
		"filo":
			salpicar(padre, pos, d.cross(Vector3.UP) + Vector3.UP * 0.3, 0.9 * fuerza)
			_manchar_detras(padre, pos, d, 1.5, 0.2)
		"explosion":
			salpicar(padre, pos, Vector3.UP + d, 1.8)
			niebla(padre, pos, 0.6)
		_:
			salpicar(padre, pos, d + Vector3.UP * 0.3, 0.6 * fuerza)
	# Unas gotas caen al suelo justo debajo.
	if n >= 1 and randf() < 0.6:
		var suelo: Dictionary = Combate.rayo(padre.get_world_3d(), pos + d * randf_range(0.2, 0.8), Vector3.DOWN, 3.0, [])
		if not suelo.is_empty():
			mancha(padre, suelo["position"], suelo["normal"], randf_range(0.15, 0.3))


static func _manchar_detras(padre: Node, pos: Vector3, d: Vector3, alcance: float, tam: float) -> void:
	var extra: Array = []
	var choque: Dictionary = Combate.rayo(padre.get_world_3d(), pos + d * 0.45, d, alcance, extra)
	if choque.is_empty():
		return
	var c = choque["collider"]
	if c is Node and ((c as Node).has_method("recibir_dano") or (c as Node).has_meta("cuerpo_de") or c is RigidBody3D):
		return   # Otra persona o un trozo suelto: no se mancha.
	mancha(padre, choque["position"], choque["normal"], tam * randf_range(0.8, 1.6))


# Neblina roja de un instante (el "puf" de sangre al entrar una bala).
static func niebla(padre: Node, pos: Vector3, tam: float = 0.3) -> void:
	if nivel() == 0 or padre == null or not padre.is_inside_tree():
		return
	if _malla_niebla == null:
		_malla_niebla = SphereMesh.new()
		_malla_niebla.radius = 0.5
		_malla_niebla.height = 1.0
		_malla_niebla.radial_segments = 8
		_malla_niebla.rings = 4
	var m: MeshInstance3D = MeshInstance3D.new()
	m.mesh = _malla_niebla
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.0, 0.0, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_raiz(padre).add_child(m)
	m.global_position = pos
	m.scale = Vector3.ONE * tam * 0.3
	var t: Tween = m.create_tween()
	t.set_parallel(true)
	t.tween_property(m, "scale", Vector3.ONE * tam, 0.18).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	t.chain().tween_callback(m.queue_free)


# Mancha de sangre pegada a una superficie (pared, suelo, coche).
static func mancha(padre: Node, pos: Vector3, normal: Vector3, tam: float = 0.3) -> void:
	var n: int = nivel()
	if n == 0 or padre == null or not padre.is_inside_tree():
		return
	if _texturas_mancha.is_empty():
		for k in 4:
			_texturas_mancha.append(_textura_mancha(k))
	var q: MeshInstance3D = MeshInstance3D.new()
	var malla: QuadMesh = QuadMesh.new()
	malla.size = Vector2(tam, tam) * 1.4
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = _texturas_mancha[randi() % _texturas_mancha.size()]
	mat.albedo_color = Color(0.36, 0.01, 0.01, 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.25
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	malla.material = mat
	q.mesh = malla
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_raiz(padre).add_child(q)
	var nn: Vector3 = normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var arriba: Vector3 = Vector3.RIGHT if absf(nn.y) > 0.99 else Vector3.UP
	q.look_at_from_position(pos + nn * (0.012 + randf() * 0.004), pos + nn * 2.0, arriba)
	q.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	var anim: Tween = q.create_tween()
	anim.tween_interval(DURACION_CHARCO[n] * 0.8)
	anim.tween_property(mat, "albedo_color:a", 0.0, 5.0)
	anim.tween_callback(q.queue_free)
	_manchas.append(q)
	_recortar(_manchas, int(MAX_MANCHAS[n]))


# Una mancha irregular: un círculo con salpicaduras alrededor (generada una vez).
static func _textura_mancha(semilla: int) -> ImageTexture:
	var tam: int = 64
	var img: Image = Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234 + semilla * 77
	var gotas: Array = [[Vector2(32, 32), rng.randf_range(10.0, 15.0)]]
	for k in rng.randi_range(6, 12):
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(8.0, 28.0)
		gotas.append([Vector2(32, 32) + Vector2(cos(ang), sin(ang)) * dist, rng.randf_range(1.5, 5.0) * (1.0 - dist / 40.0)])
	for y in tam:
		for x in tam:
			var a: float = 0.0
			for g in gotas:
				var dd: float = Vector2(x, y).distance_to(g[0])
				a = maxf(a, clampf((float(g[1]) - dd) / 1.5, 0.0, 1.0))
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# La cabeza estalla: neblina grande, trozos y salpicaduras alrededor.
static func reventar(padre: Node, pos: Vector3, dir: Vector3) -> void:
	if nivel() == 0 or padre == null or not padre.is_inside_tree():
		return
	niebla(padre, pos, 0.9)
	salpicar(padre, pos, dir + Vector3.UP * 0.6, 2.5)
	salpicar(padre, pos, -dir + Vector3.UP, 1.2)
	trozos(padre, pos, 6, dir, true)
	for k in 5:
		var d: Vector3 = (dir + Vector3(randf_range(-0.7, 0.7), randf_range(-0.3, 0.6), randf_range(-0.7, 0.7))).normalized()
		_manchar_detras(padre, pos, d, 4.0, randf_range(0.2, 0.5))


# Partículas de un muñón que sangra (el que las usa decide dirección y duración).
static func chorro() -> CPUParticles3D:
	if _malla_gota == null:
		salpicar_preparar()
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = 28
	p.lifetime = 0.7
	p.local_coords = false
	p.mesh = _malla_gota
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	p.emitting = false
	return p


static func salpicar_preparar() -> void:
	if _malla_gota == null:
		_malla_gota = SphereMesh.new()
		_malla_gota.radius = 0.035
		_malla_gota.height = 0.07
		_malla_gota.radial_segments = 4
		_malla_gota.rings = 2
		_malla_gota.material = _material()


# Crujido de hueso y carne al arrancar un miembro.
static func crujido(padre: Node, pos: Vector3, fuerte: bool = false) -> void:
	if padre == null or not padre.is_inside_tree():
		return
	var clave: String = "crujido_fuerte" if fuerte else "crujido"
	if not _sonidos.has(clave):
		_sonidos[clave] = _generar_crujido(fuerte)
	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.stream = _sonidos[clave]
	p.max_distance = 45.0
	p.unit_size = 6.0
	p.volume_db = 2.0 if fuerte else -1.0
	p.pitch_scale = randf_range(0.9, 1.1)
	_raiz(padre).add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


static func _generar_crujido(fuerte: bool) -> AudioStreamWAV:
	var tasa: int = 22050
	var n: int = int((0.5 if fuerte else 0.35) * tasa)
	var datos: PackedByteArray = PackedByteArray()
	datos.resize(n * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99 if fuerte else 42
	var grano: float = 0.0
	var bajo: float = 0.0
	for i in n:
		var t: float = float(i) / tasa
		# Chasquidos secos (hueso) sobre un golpe grave y húmedo (carne).
		if rng.randf() < 0.012 * exp(-t * 6.0):
			grano = rng.randf_range(0.6, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		grano *= 0.86
		bajo = bajo * 0.97 + rng.randf_range(-1.0, 1.0) * 0.03
		var golpe: float = sin(TAU * 70.0 * t) * exp(-t * 14.0)
		var v: float = grano * 0.8 + bajo * 2.5 * exp(-t * 5.0) + golpe * (0.9 if fuerte else 0.6)
		datos.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = tasa
	w.stereo = false
	w.data = datos
	return w


static func _recortar(lista: Array, maximo: int) -> void:
	while lista.size() > maxi(maximo, 0):
		var vieja = lista.pop_front()
		if is_instance_valid(vieja):
			vieja.queue_free()


# ------------------------------------ Gritos ----------------------------------

static func grito(padre: Node, pos: Vector3, tipo: int = -1) -> void:
	if not gritos_activos() or padre == null or not padre.is_inside_tree():
		return
	var ahora: int = Time.get_ticks_msec()
	if ahora - _ultimo_grito < 250:
		return   # Muchos gritos a la vez se vuelven un ruido: se espacian.
	_ultimo_grito = ahora
	if _gritos.is_empty():
		for f0 in [520.0, 300.0, 380.0]:
			_gritos.append(_generar_grito(f0))
	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.stream = _gritos[(tipo if tipo >= 0 else randi()) % _gritos.size()]
	p.max_distance = 55.0
	p.unit_size = 7.0
	p.volume_db = -2.0
	_raiz(padre).add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


static func _generar_grito(f0: float) -> AudioStreamWAV:
	var tasa: int = 16000
	var n: int = int(0.9 * tasa)
	var datos: PackedByteArray = PackedByteArray()
	datos.resize(n * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(f0)
	var fase: float = 0.0
	for i in n:
		var t: float = float(i) / tasa
		# Sube rápido, aguanta con vibrato y cae al final.
		var f: float = f0 * (0.8 + 0.5 * minf(t * 6.0, 1.0)) * (1.0 + 0.03 * sin(TAU * 7.0 * t)) * (1.0 - 0.25 * maxf(0.0, t - 0.6))
		fase += TAU * f / tasa
		var voz: float = sin(fase) + 0.5 * sin(fase * 2.0) + 0.3 * sin(fase * 3.0) + rng.randf_range(-0.35, 0.35)
		var env: float = minf(t * 40.0, 1.0) * (1.0 - smoothstep(0.55, 0.9, t))
		datos.encode_s16(i * 2, int(clampf(voz * env * 0.5, -1.0, 1.0) * 30000.0))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = tasa
	w.stereo = false
	w.data = datos
	return w
