# efectos_arma.gd
# -----------------------------------------------------------------------------
# Lo que se ve y se oye al disparar, aparte del daño:
#   EfectosArma.boca(padre, pos, dir, forma)        fogonazo (estrella de luz), humo y luz
#   EfectosArma.trazadora(padre, desde, hasta)      línea de luz de la bala (se ve un instante)
#   EfectosArma.casquillo(padre, pos, derecha, arriba, forma)   vaina que sale despedida y tintinea
#   EfectosArma.impacto(padre, choque, dir)         chispas, polvo, astillas y marca según lo que toques
#   EfectosArma.sonido_disparo(padre, forma)        un sonido distinto por arma
#   EfectosArma.marcador(arbol, tipo)               aspa en el centro de la pantalla al acertar
#                                                   ("toque", "muerte", "cabeza")
# Todo tiene tope de objetos vivos para no bajar los FPS.
# -----------------------------------------------------------------------------
class_name EfectosArma
extends RefCounted

const MAX_CASQUILLOS: int = 30

static var _casquillos: Array = []
static var _tex_fogonazo: ImageTexture = null
static var _malla_humo: SphereMesh = null
static var _malla_chispa: BoxMesh = null
static var _malla_lasca: BoxMesh = null
static var _sonidos: Dictionary = {}
static var _marcador: Node = null


static func _raiz(n: Node) -> Node:
	var t: SceneTree = n.get_tree()
	return t.current_scene if t.current_scene != null else t.root


# ------------------------------- Boca del arma --------------------------------

static func boca(padre: Node, pos: Vector3, dir: Vector3, forma: String = "pistola") -> void:
	if padre == null or not padre.is_inside_tree():
		return
	var grande: float = {"pistola": 0.7, "escopeta": 1.3, "rifle": 0.9, "francotirador": 1.2, "lanzagranadas": 1.1}.get(forma, 0.8)
	var raiz: Node = _raiz(padre)
	# Luz de un instante.
	var luz: OmniLight3D = OmniLight3D.new()
	luz.light_color = Color(1.0, 0.75, 0.4)
	luz.light_energy = 4.0 * grande
	luz.omni_range = 7.0 + 4.0 * grande
	luz.shadow_enabled = false
	raiz.add_child(luz)
	luz.global_position = pos
	# Estrella de fuego: dos planos cruzados que miran hacia delante + uno de frente.
	if _tex_fogonazo == null:
		_tex_fogonazo = _textura_fogonazo()
	var flor: Node3D = Node3D.new()
	raiz.add_child(flor)
	var adelante: Vector3 = dir.normalized()
	var arriba: Vector3 = Vector3.UP if absf(adelante.y) < 0.95 else Vector3.RIGHT
	flor.look_at_from_position(pos, pos + adelante, arriba)
	flor.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = _tex_fogonazo
	mat.albedo_color = Color(1.0, 0.85, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	for k in 3:
		var q: MeshInstance3D = MeshInstance3D.new()
		var m: QuadMesh = QuadMesh.new()
		m.material = mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if k < 2:
			m.size = Vector2(0.18, 0.45) * grande   # Llama alargada hacia delante.
			q.mesh = m
			flor.add_child(q)
			q.position = Vector3(0, 0, -0.2 * grande)
			q.rotation = Vector3(-PI / 2.0, 0.0, 0.0) if k == 0 else Vector3(-PI / 2.0, PI / 2.0, 0.0)
		else:
			m.size = Vector2(0.3, 0.3) * grande   # Estrella vista de frente.
			q.mesh = m
			flor.add_child(q)
	var t: Tween = flor.create_tween()
	t.set_parallel(true)
	t.tween_property(flor, "scale", Vector3.ONE * 1.3, 0.05)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.06)
	t.tween_property(luz, "light_energy", 0.0, 0.07)
	t.chain().tween_callback(func() -> void:
		flor.queue_free()
		luz.queue_free())
	humo(padre, pos + adelante * 0.1, adelante, 0.6 * grande)


static func _textura_fogonazo() -> ImageTexture:
	var tam: int = 64
	var img: Image = Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	var c: Vector2 = Vector2(31.5, 31.5)
	for y in tam:
		for x in tam:
			var v: Vector2 = Vector2(x, y) - c
			var r: float = v.length() / 32.0
			var ang: float = atan2(v.y, v.x)
			var puntas: float = 0.55 + 0.45 * pow(absf(cos(ang * 3.0)), 6.0)   # Seis puntas.
			var a: float = clampf(1.0 - r / puntas, 0.0, 1.0)
			a = a * a
			var nucleo: float = clampf(1.0 - r * 3.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 0.8 + 0.2 * nucleo, 0.45 + 0.55 * nucleo, a))
	return ImageTexture.create_from_image(img)


# Bocanada de humo gris que sube y se deshace.
static func humo(padre: Node, pos: Vector3, dir: Vector3, cantidad: float = 1.0, color: Color = Color(0.6, 0.6, 0.6, 0.35)) -> void:
	if _malla_humo == null:
		_malla_humo = SphereMesh.new()
		_malla_humo.radius = 0.5
		_malla_humo.height = 1.0
		_malla_humo.radial_segments = 6
		_malla_humo.rings = 3
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = int(clampf(5.0 * cantidad, 3.0, 14.0))
	p.lifetime = 1.1
	p.local_coords = false
	p.mesh = _malla_humo
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	p.material_override = mat
	p.direction = dir.normalized() + Vector3.UP * 0.4
	p.spread = 25.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 0.6, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.16
	var curva: Curve = Curve.new()
	curva.add_point(Vector2(0.0, 0.4))
	curva.add_point(Vector2(1.0, 2.2))
	p.scale_amount_curve = curva
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_raiz(padre).add_child(p)
	p.global_position = pos
	p.emitting = true
	padre.get_tree().create_timer(1.6).timeout.connect(p.queue_free)


# ------------------------------- Trazadora -------------------------------------

static func trazadora(padre: Node, desde: Vector3, hasta: Vector3, color: Color = Color(1.0, 0.85, 0.5)) -> void:
	if padre == null or not padre.is_inside_tree():
		return
	var largo: float = desde.distance_to(hasta)
	if largo < 1.5:
		return
	# La línea empieza un poco por delante del arma para no tapar la mira.
	var inicio: Vector3 = desde + (hasta - desde).normalized() * 1.0
	largo -= 1.0
	var m: MeshInstance3D = MeshInstance3D.new()
	var caja: BoxMesh = BoxMesh.new()
	caja.size = Vector3(0.012, 0.012, minf(largo, 6.0))
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	caja.material = mat
	m.mesh = caja
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_raiz(padre).add_child(m)
	var arriba: Vector3 = Vector3.UP if absf((hasta - desde).normalized().y) < 0.95 else Vector3.RIGHT
	m.look_at_from_position(inicio, hasta, arriba)
	# La raya viaja de la boca al blanco (a ~400 m/s, más lenta que una bala real para que se vea).
	var tramo: float = minf(largo, 6.0)
	var dur: float = clampf(largo / 400.0, 0.03, 0.25)
	var dir: Vector3 = (hasta - inicio).normalized()
	m.global_position = inicio + dir * tramo * 0.5
	var t: Tween = m.create_tween()
	t.tween_property(m, "global_position", hasta - dir * tramo * 0.5, dur)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.03)
	t.tween_callback(m.queue_free)


# ------------------------------- Casquillos ------------------------------------

static func casquillo(padre: Node, pos: Vector3, derecha: Vector3, arriba: Vector3, forma: String = "pistola") -> void:
	if padre == null or not padre.is_inside_tree() or forma == "lanzagranadas":
		return
	var rb: RigidBody3D = RigidBody3D.new()
	rb.collision_layer = 0
	rb.collision_mask = 1
	rb.mass = 0.02
	rb.angular_damp = 0.5
	var escopeta: bool = forma == "escopeta"
	var largo: float = 0.06 if escopeta else (0.05 if forma in ["rifle", "francotirador"] else 0.025)
	var radio: float = 0.011 if escopeta else 0.006
	var forma_c: CollisionShape3D = CollisionShape3D.new()
	var cil: CylinderShape3D = CylinderShape3D.new()
	cil.height = largo
	cil.radius = radio
	forma_c.shape = cil
	rb.add_child(forma_c)
	var vista: MeshInstance3D = MeshInstance3D.new()
	var m: CylinderMesh = CylinderMesh.new()
	m.height = largo
	m.top_radius = radio
	m.bottom_radius = radio
	m.radial_segments = 6
	m.rings = 1
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.15, 0.1) if escopeta else Color(0.85, 0.65, 0.25)   # Cartucho rojo o latón.
	mat.metallic = 0.0 if escopeta else 0.8
	mat.roughness = 0.35
	m.material = mat
	vista.mesh = m
	rb.add_child(vista)
	_raiz(padre).add_child(rb)
	rb.global_position = pos
	rb.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	rb.linear_velocity = derecha * randf_range(1.8, 3.0) + arriba * randf_range(1.5, 2.6) + derecha.cross(arriba) * randf_range(-0.4, 0.4)
	rb.angular_velocity = Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))
	rb.contact_monitor = true
	rb.max_contacts_reported = 1
	var sonado: Array = [false]
	rb.body_entered.connect(func(_c: Node) -> void:
		if not sonado[0] and is_instance_valid(rb):
			sonado[0] = true
			tocar_en(rb, "casquillo_escopeta" if escopeta else "casquillo", rb.global_position, -14.0, randf_range(0.9, 1.2)))
	_casquillos.append(rb)
	padre.get_tree().create_timer(8.0).timeout.connect(rb.queue_free)
	while _casquillos.size() > MAX_CASQUILLOS:
		var v = _casquillos.pop_front()
		if is_instance_valid(v):
			v.queue_free()


# -------------------------------- Impactos -------------------------------------

# Qué hay al otro lado de la bala: "carne", "metal", "madera", "tierra", "piedra" o "agua".
static func superficie(collider: Object, pos: Vector3) -> String:
	if collider == null or not is_instance_valid(collider):
		return "piedra"
	if collider is Node:
		var n: Node = collider
		if n.has_meta("cuerpo_de") or n.is_in_group("peatones") or n.is_in_group("guardias") or n.is_in_group("matones") or n.is_in_group("vecinos"):
			return "carne"
		if n.has_meta("superficie"):
			return String(n.get_meta("superficie"))
		var nombre: String = String(n.name).to_lower()
		if n.is_in_group("vehiculos") or n is VehicleBody3D or n is Vehiculo or nombre.contains("coche") or nombre.contains("vehic"):
			return "metal"
		if n.get("es_coche") == true:
			return "metal"
		for clave in ["farola", "semaforo", "valla", "barandilla", "poste", "señal", "senal", "contenedor"]:
			if nombre.contains(clave):
				return "metal"
		for clave2 in ["arbol", "árbol", "madera", "puerta", "mueble", "banco", "caja", "tronco"]:
			if nombre.contains(clave2):
				return "madera"
		if nombre.contains("terreno") or nombre.contains("suelo") or nombre.contains("hierba") or nombre.contains("campo"):
			return "tierra"
	return "piedra"


static func impacto(padre: Node, choque: Dictionary, dir: Vector3) -> void:
	if padre == null or not padre.is_inside_tree() or choque.is_empty():
		return
	var pos: Vector3 = choque["position"]
	var normal: Vector3 = choque["normal"]
	var sup: String = superficie(choque.get("collider"), pos)
	if sup == "carne":
		return   # La sangre la pone Gore.herida.
	var rebote: Vector3 = dir.normalized().bounce(normal) if normal.length() > 0.1 else -dir
	match sup:
		"metal":
			chispas(padre, pos, (normal + rebote).normalized(), 14)
			tocar_en(padre, "impacto_metal", pos, -6.0, randf_range(0.85, 1.2))
		"madera":
			lascas(padre, pos, normal, Color(0.55, 0.38, 0.2), 7)
			humo(padre, pos, normal, 0.5, Color(0.6, 0.5, 0.4, 0.35))
			tocar_en(padre, "impacto_madera", pos, -6.0, randf_range(0.9, 1.1))
		"tierra":
			humo(padre, pos, normal, 1.0, Color(0.45, 0.38, 0.28, 0.5))
			lascas(padre, pos, normal, Color(0.35, 0.28, 0.2), 6)
			tocar_en(padre, "impacto_tierra", pos, -8.0, randf_range(0.9, 1.1))
		_:
			humo(padre, pos, normal, 0.9, Color(0.7, 0.68, 0.64, 0.45))
			lascas(padre, pos, normal, Color(0.6, 0.58, 0.55), 6)
			if randf() < 0.35:
				chispas(padre, pos, (normal + rebote).normalized(), 5)
				tocar_en(padre, "rebote", pos, -7.0, randf_range(0.85, 1.25))
			else:
				tocar_en(padre, "impacto_piedra", pos, -7.0, randf_range(0.9, 1.15))


static func chispas(padre: Node, pos: Vector3, dir: Vector3, cuantas: int = 10) -> void:
	if _malla_chispa == null:
		_malla_chispa = BoxMesh.new()
		_malla_chispa.size = Vector3(0.01, 0.01, 0.08)
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.75, 0.3)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = Color(1.0, 0.6, 0.2)
		_malla_chispa.material = m
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = cuantas
	p.lifetime = 0.35
	p.local_coords = false
	p.mesh = _malla_chispa
	p.particle_flag_align_y = true
	p.direction = dir
	p.spread = 35.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_raiz(padre).add_child(p)
	p.global_position = pos
	p.emitting = true
	var luz: OmniLight3D = OmniLight3D.new()
	luz.light_color = Color(1.0, 0.7, 0.3)
	luz.light_energy = 1.2
	luz.omni_range = 2.5
	_raiz(padre).add_child(luz)
	luz.global_position = pos + dir * 0.1
	padre.get_tree().create_timer(0.05).timeout.connect(luz.queue_free)
	padre.get_tree().create_timer(0.8).timeout.connect(p.queue_free)


static func lascas(padre: Node, pos: Vector3, normal: Vector3, color: Color, cuantas: int = 6) -> void:
	if _malla_lasca == null:
		_malla_lasca = BoxMesh.new()
		_malla_lasca.size = Vector3(0.025, 0.025, 0.025)
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = cuantas
	p.lifetime = 0.7
	p.local_coords = false
	p.mesh = _malla_lasca
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	p.material_override = mat
	p.direction = normal
	p.spread = 40.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -9.8, 0)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	_raiz(padre).add_child(p)
	p.global_position = pos + normal * 0.02
	p.emitting = true
	padre.get_tree().create_timer(1.0).timeout.connect(p.queue_free)


# Si está el sistema de física del escenario (otro hilo: FisicaEscenario), le pasa el
# impacto para que mueva o rompa el objeto. true si lo ha gestionado él.
static var _fisica: Variant = null
static func fisica_bala(choque: Dictionary, dir: Vector3, dano: float) -> bool:
	if _fisica == null:
		_fisica = false
		for c in ProjectSettings.get_global_class_list():
			if String(c.get("class", "")) == "FisicaEscenario":
				_fisica = load(String(c["path"]))
	if _fisica is Script:
		return bool((_fisica as Script).call("impacto_bala", choque, dir, dano))
	return false


# ------------------------------- Marcador de acierto ----------------------------

static func marcador(arbol: SceneTree, tipo: String = "toque") -> void:
	if arbol == null:
		return
	if _marcador == null or not is_instance_valid(_marcador):
		_marcador = MarcadorAcierto.new()
		arbol.root.add_child(_marcador)
	(_marcador as MarcadorAcierto).mostrar(tipo)


# ---------------------------------- Sonidos ------------------------------------

static func sonido_disparo(padre: Node, forma: String) -> void:
	if padre == null or not padre.is_inside_tree():
		return
	var clave: String = "disparo_" + forma
	var flujo: AudioStream = _flujo(clave)
	if flujo == null:
		Sonido.tocar(padre, "disparo")
		return
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = flujo
	p.volume_db = {"pistola": -5.0, "escopeta": -2.0, "rifle": -5.0, "francotirador": -1.0}.get(forma, -5.0)
	p.pitch_scale = randf_range(0.95, 1.05)
	padre.get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


static func tocar_en(padre: Node, clave: String, pos: Vector3, volumen: float = -6.0, tono: float = 1.0) -> void:
	if padre == null or not padre.is_inside_tree():
		return
	var flujo: AudioStream = _flujo(clave)
	if flujo == null:
		return
	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.stream = flujo
	p.volume_db = volumen
	p.pitch_scale = tono
	p.max_distance = 40.0
	p.unit_size = 4.0
	_raiz(padre).add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


# Si hay un archivo en assets/sonidos/<clave>.ogg|wav se usa; si no, se genera uno.
static func _flujo(clave: String) -> AudioStream:
	if _sonidos.has(clave):
		return _sonidos[clave]
	var flujo: AudioStream = null
	for ext in ["ogg", "wav"]:
		var ruta: String = "res://assets/sonidos/%s.%s" % [clave, ext]
		if ResourceLoader.exists(ruta):
			flujo = load(ruta) as AudioStream
			break
	if flujo == null:
		flujo = _generar(clave)
	_sonidos[clave] = flujo
	return flujo


# Sonidos sintetizados: [duración, grave Hz, caída del golpe, caída del ruido, cola (eco)]
static func _generar(clave: String) -> AudioStream:
	var receta: Dictionary = {
		"disparo_pistola": [0.45, 140.0, 30.0, 22.0, 0.25],
		"disparo_escopeta": [0.9, 80.0, 12.0, 9.0, 0.45],
		"disparo_rifle": [0.5, 120.0, 26.0, 18.0, 0.3],
		"disparo_francotirador": [1.4, 70.0, 10.0, 7.0, 0.6],
		"disparo_lanzagranadas": [0.5, 60.0, 14.0, 20.0, 0.15],
	}
	if receta.has(clave):
		return _disparo(receta[clave])
	match clave:
		"impacto_metal":
			return _tono_metal(1800.0, 0.25)
		"casquillo":
			return _tono_metal(4200.0, 0.12)
		"casquillo_escopeta":
			return _tono_metal(900.0, 0.1)
		"rebote":
			return _rebote()
		"impacto_madera":
			return _seco(380.0, 0.12, 30.0)
		"impacto_tierra":
			return _seco(90.0, 0.15, 25.0)
		"impacto_piedra":
			return _seco(900.0, 0.1, 40.0)
	return null


static func _wav(datos: PackedByteArray, tasa: int) -> AudioStreamWAV:
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = tasa
	w.stereo = false
	w.data = datos
	return w


static func _disparo(r: Array) -> AudioStreamWAV:
	var tasa: int = 22050
	var n: int = int(float(r[0]) * tasa)
	var datos: PackedByteArray = PackedByteArray()
	datos.resize(n * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(float(r[1]) * 13.0)
	var filtro: float = 0.0
	var eco: PackedFloat32Array = PackedFloat32Array()
	eco.resize(n)
	for i in n:
		var t: float = float(i) / tasa
		var ruido: float = rng.randf_range(-1.0, 1.0)
		filtro = filtro * 0.55 + ruido * 0.45   # Ruido algo más oscuro.
		var chasquido: float = ruido * exp(-t * 180.0)
		var cuerpo: float = filtro * exp(-t * float(r[3]))
		var golpe: float = sin(TAU * float(r[1]) * t * (1.0 - t * 0.8)) * exp(-t * float(r[2]))
		var v: float = chasquido * 0.9 + cuerpo * 0.9 + golpe * 0.8
		# Eco de calle: la misma señal más baja y retrasada.
		var retraso: int = int(0.09 * tasa)
		if i >= retraso:
			v += eco[i - retraso] * float(r[4])
		eco[i] = v
		datos.encode_s16(i * 2, int(clampf(v * 0.8, -1.0, 1.0) * 31000.0))
	return _wav(datos, tasa)


static func _tono_metal(f: float, dur: float) -> AudioStreamWAV:
	var tasa: int = 22050
	var n: int = int(dur * tasa)
	var datos: PackedByteArray = PackedByteArray()
	datos.resize(n * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(f)
	for i in n:
		var t: float = float(i) / tasa
		var v: float = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.76 * t) * 0.3 + sin(TAU * f * 5.4 * t) * 0.15) * exp(-t * 18.0)
		v += rng.randf_range(-1.0, 1.0) * exp(-t * 120.0) * 0.6
		datos.encode_s16(i * 2, int(clampf(v * 0.7, -1.0, 1.0) * 30000.0))
	return _wav(datos, tasa)


static func _rebote() -> AudioStreamWAV:
	var tasa: int = 22050
	var n: int = int(0.45 * tasa)
	var datos: PackedByteArray = PackedByteArray()
	datos.resize(n * 2)
	var fase: float = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for i in n:
		var t: float = float(i) / tasa
		var f: float = 2600.0 - 1700.0 * t / 0.45   # El "fiiiuu" que baja.
		fase += TAU * f / tasa
		var v: float = sin(fase) * exp(-t * 6.0) * 0.5 + rng.randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.7
		datos.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 28000.0))
	return _wav(datos, tasa)


static func _seco(f: float, dur: float, caida: float) -> AudioStreamWAV:
	var tasa: int = 22050
	var n: int = int(dur * tasa)
	var datos: PackedByteArray = PackedByteArray()
	datos.resize(n * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(f) + 3
	var filtro: float = 0.0
	for i in n:
		var t: float = float(i) / tasa
		filtro = filtro * 0.7 + rng.randf_range(-1.0, 1.0) * 0.3
		var v: float = filtro * 1.6 * exp(-t * caida) + sin(TAU * f * t) * exp(-t * caida * 1.5) * 0.5
		datos.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	return _wav(datos, tasa)
