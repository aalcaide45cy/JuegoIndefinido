# destruccion.gd
# -----------------------------------------------------------------------------
# Efectos de destruccion: crateres, coches quemados y fuego. Combate.explosion()
# lo llama; todo tiene tope para no gastar rendimiento. Ajustes en Destruccion.activa
# y Destruccion.max_crateres (el panel de admin puede cambiarlos).
# -----------------------------------------------------------------------------
class_name Destruccion
extends RefCounted

static var activa: bool = true
static var max_crateres: int = 40
static var max_fuegos: int = 12
static var _crateres: Array = []
static var _fuegos: Array = []


# Crater: disco oscuro hundido y un borde de tierra, pegado al suelo.
static func crater(padre: Node, pos: Vector3, radio: float) -> void:
	if not activa:
		return
	var nodo: Node3D = Node3D.new()
	var disco: MeshInstance3D = MeshInstance3D.new()
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = radio * 0.55
	m.bottom_radius = radio * 0.45
	m.height = 0.12
	m.radial_segments = 12
	m.material = Construir.material_unico(Color(0.08, 0.06, 0.05), 0.0)
	disco.mesh = m
	disco.position = Vector3(0, -0.02, 0)
	nodo.add_child(disco)
	var borde: MeshInstance3D = MeshInstance3D.new()
	var t: TorusMesh = TorusMesh.new()
	t.inner_radius = radio * 0.55
	t.outer_radius = radio * 0.8
	t.rings = 8
	t.ring_segments = 3
	t.material = Construir.material_unico(Color(0.3, 0.22, 0.14), 0.0)
	borde.mesh = t
	borde.scale = Vector3(1, 0.25, 1)
	nodo.add_child(borde)
	padre.add_child(nodo)
	nodo.global_position = pos
	_crateres.append(nodo)
	while _crateres.size() > max_crateres:
		var viejo = _crateres.pop_front()
		if is_instance_valid(viejo):
			viejo.queue_free()


# Oscurece todo el modelo de un coche (queda carbonizado).
static func quemar_modelo(raiz: Node) -> void:
	var negro: StandardMaterial3D = StandardMaterial3D.new()
	negro.albedo_color = Color(0.06, 0.05, 0.05)
	negro.roughness = 1.0
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = negro


# Llamas con luz parpadeante y humo (se apagan solas al rato; hay un maximo a la vez).
static func fuego_en(padre: Node3D, pos: Vector3, duracion: float = 25.0) -> void:
	if not activa:
		return
	var llama: OmniLight3D = OmniLight3D.new()
	llama.light_color = Color(1.0, 0.5, 0.15)
	llama.light_energy = 2.0
	llama.omni_range = 7.0
	padre.add_child(llama)
	llama.global_position = pos
	var tw: Tween = llama.create_tween().set_loops()
	tw.tween_property(llama, "light_energy", 3.0, 0.15)
	tw.tween_property(llama, "light_energy", 1.4, 0.2)
	var humo: CPUParticles3D = CPUParticles3D.new()
	humo.amount = 14
	humo.lifetime = 2.5
	humo.direction = Vector3.UP
	humo.spread = 15.0
	humo.initial_velocity_min = 1.5
	humo.initial_velocity_max = 2.5
	humo.gravity = Vector3(0, 0.3, 0)
	humo.scale_amount_min = 0.6
	humo.scale_amount_max = 1.2
	var esf: SphereMesh = SphereMesh.new()
	esf.radius = 0.3
	esf.height = 0.6
	esf.radial_segments = 6
	esf.rings = 3
	esf.material = Construir.material_unico(Color(0.15, 0.15, 0.15), 0.0)
	humo.mesh = esf
	llama.add_child(humo)
	_fuegos.append(llama)
	while _fuegos.size() > max_fuegos:
		var v = _fuegos.pop_front()
		if is_instance_valid(v):
			v.queue_free()
	var apagar: Timer = Timer.new()
	apagar.wait_time = duracion
	apagar.one_shot = true
	apagar.autostart = true
	apagar.timeout.connect(func() -> void:
		if is_instance_valid(llama):
			tw.kill()
			llama.queue_free())
	llama.add_child(apagar)
