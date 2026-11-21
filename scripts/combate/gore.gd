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
#   Gore.muerte(padre, pos, dir, fuerza)       todo junto para una muerte violenta
#   Gore.grito(padre, pos, tipo)               0 agudo, 1 grave, 2 dolor
# -----------------------------------------------------------------------------
class_name Gore
extends RefCounted

const MAX_CHARCOS: Array = [0, 14, 40]
const MAX_TROZOS: Array = [0, 0, 20]
const DURACION_CHARCO: Array = [0.0, 45.0, 120.0]

static var _charcos: Array = []
static var _trozos: Array = []
static var _gritos: Array = []
static var _ultimo_grito: int = 0
static var _malla_gota: SphereMesh = null
static var _mat_sangre: StandardMaterial3D = null


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
	if _malla_gota == null:
		_malla_gota = SphereMesh.new()
		_malla_gota.radius = 0.04
		_malla_gota.height = 0.08
		_malla_gota.radial_segments = 4
		_malla_gota.rings = 2
		_malla_gota.material = _material()
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


# Un charco en el suelo bajo pos: crece despacio y se desvanece al cabo de un rato.
static func charco(padre: Node, pos: Vector3, radio: float = 0.7) -> void:
	var n: int = nivel()
	if n == 0 or padre == null or not padre.is_inside_tree():
		return
	var y: float = pos.y
	var suelo: Dictionary = Combate.rayo(padre.get_world_3d(), pos + Vector3.UP * 1.0, Vector3.DOWN, 4.0, [])
	if not suelo.is_empty():
		y = suelo["position"].y
	var disco: MeshInstance3D = MeshInstance3D.new()
	var malla: CylinderMesh = CylinderMesh.new()
	malla.top_radius = radio
	malla.bottom_radius = radio
	malla.height = 0.01
	malla.radial_segments = 12
	malla.rings = 1
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.0, 0.0, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.2
	malla.material = mat
	disco.mesh = malla
	disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_raiz(padre).add_child(disco)
	disco.global_position = Vector3(pos.x, y + 0.025, pos.z)
	disco.scale = Vector3(0.15, 1.0, 0.15)
	var anim: Tween = disco.create_tween()
	anim.tween_property(disco, "scale", Vector3(1.0, 1.0, 1.0), 6.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	anim.tween_interval(DURACION_CHARCO[n])
	anim.tween_property(mat, "albedo_color:a", 0.0, 6.0)
	anim.tween_callback(disco.queue_free)
	_charcos.append(disco)
	_recortar(_charcos, int(MAX_CHARCOS[n]))


# Miembros y trozos que saltan. Solo con gore completo.
static func trozos(padre: Node, pos: Vector3, cuantos: int, dir: Vector3 = Vector3.UP) -> void:
	if nivel() < 2 or padre == null or not padre.is_inside_tree():
		return
	var colores: Array = [Color(0.72, 0.5, 0.42), Color(0.5, 0.03, 0.03), Color(0.2, 0.2, 0.3), Color(0.55, 0.05, 0.05)]
	for i in cuantos:
		var c: RigidBody3D = RigidBody3D.new()
		c.collision_layer = 0   # No empujan al jugador ni a los coches.
		c.collision_mask = 1
		c.mass = 0.5
		var tam: Vector3 = Vector3(randf_range(0.1, 0.18), randf_range(0.1, 0.35), randf_range(0.1, 0.18))
		var forma: CollisionShape3D = CollisionShape3D.new()
		var caja: BoxShape3D = BoxShape3D.new()
		caja.size = tam
		forma.shape = caja
		c.add_child(forma)
		var vista: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = tam
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = colores[randi() % colores.size()]
		bm.material = m
		vista.mesh = bm
		c.add_child(vista)
		_raiz(padre).add_child(c)
		c.global_position = pos + Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.4), randf_range(-0.2, 0.2))
		c.linear_velocity = (dir.normalized() * randf_range(1.5, 4.0)) + Vector3(randf_range(-2, 2), randf_range(2.5, 5.5), randf_range(-2, 2))
		c.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		_trozos.append(c)
		padre.get_tree().create_timer(randf_range(18.0, 26.0)).timeout.connect(func() -> void:
			if is_instance_valid(c):
				c.queue_free())
	_recortar(_trozos, int(MAX_TROZOS[nivel()]))


# Una muerte violenta: chorro, charco grande y, si ha sido muy bestia, miembros.
static func muerte(padre: Node, pos: Vector3, dir: Vector3 = Vector3.UP, fuerza: float = 1.0) -> void:
	salpicar(padre, pos + Vector3.UP * 0.9, dir, 1.0 + fuerza * 0.4)
	charco(padre, pos, 0.9 + clampf(fuerza, 0.0, 2.0) * 0.35)
	if fuerza >= 1.6:
		trozos(padre, pos + Vector3.UP * 0.5, 3 + int(fuerza * 1.5), dir)


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
