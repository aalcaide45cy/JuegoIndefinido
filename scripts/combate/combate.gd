# combate.gd
# -----------------------------------------------------------------------------
# Ayudas para disparar, golpear y explotar: rayos, marcas de bala, explosiones
# y granadas. Las usa jugador.gd. Todo lo que pueda recibir daño debe estar en
# el grupo "danable" y tener una función recibir_dano(cantidad).
# -----------------------------------------------------------------------------
class_name Combate
extends RefCounted

const MAX_MARCAS: int = 150

static var _marcas: Array = []
static var _textura_marca: GradientTexture2D = null


# Lanza un rayo y devuelve lo que toca (diccionario vacío si no toca nada).
static func rayo(mundo: World3D, desde: Vector3, direccion: Vector3, alcance: float,
		excluir: Array) -> Dictionary:
	var consulta: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			desde, desde + direccion.normalized() * alcance)
	var fuera: Array[RID] = []
	for rid in excluir:
		fuera.append(rid)
	consulta.exclude = fuera
	return mundo.direct_space_state.intersect_ray(consulta)


# Un agujerito oscuro que se queda pegado donde ha pegado la bala.
static func marca_bala(padre: Node, pos: Vector3, normal: Vector3) -> void:
	if _textura_marca == null:
		_textura_marca = GradientTexture2D.new()
		_textura_marca.fill = GradientTexture2D.FILL_RADIAL
		_textura_marca.fill_from = Vector2(0.5, 0.5)
		_textura_marca.fill_to = Vector2(0.5, 0.0)
		var degradado: Gradient = Gradient.new()
		degradado.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		degradado.colors = PackedColorArray([Color(0, 0, 0, 0.95), Color(0.02, 0.02, 0.02, 0.9),
				Color(0, 0, 0, 0)])
		_textura_marca.gradient = degradado
	var marca: MeshInstance3D = MeshInstance3D.new()
	var malla: QuadMesh = QuadMesh.new()
	malla.size = Vector2(0.12, 0.12)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = _textura_marca
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	malla.material = material
	marca.mesh = malla
	padre.add_child(marca)
	var arriba: Vector3 = Vector3.RIGHT if absf(normal.y) > 0.99 else Vector3.UP
	marca.look_at_from_position(pos + normal * 0.012, pos + normal * 2.0, arriba)
	_marcas.append(marca)
	while _marcas.size() > MAX_MARCAS:
		var vieja = _marcas.pop_front()
		if is_instance_valid(vieja):
			vieja.queue_free()


# Una explosión: luz, bola de fuego, mancha en el suelo y daño en un radio.
static func explosion(padre: Node3D, pos: Vector3, radio: float, dano: float) -> void:
	Sonido.tocar(padre, "explosion", 0.0)
	var arbol: SceneTree = padre.get_tree()
	# Destello.
	var luz: OmniLight3D = OmniLight3D.new()
	luz.light_color = Color(1.0, 0.65, 0.3)
	luz.light_energy = 10.0
	luz.omni_range = radio * 2.5
	luz.position = pos
	padre.add_child(luz)
	var bola: MeshInstance3D = MeshInstance3D.new()
	var esfera: SphereMesh = SphereMesh.new()
	esfera.radius = 0.5
	esfera.height = 1.0
	var material: StandardMaterial3D = Construir.material_unico(Color(1.0, 0.55, 0.2), 4.0)   # Único: se desvanece.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	esfera.material = material
	bola.mesh = esfera
	bola.position = pos
	padre.add_child(bola)
	var animacion: Tween = luz.create_tween()
	animacion.set_parallel(true)
	animacion.tween_property(luz, "light_energy", 0.0, 0.5)
	animacion.tween_property(bola, "scale", Vector3.ONE * radio * 0.9, 0.35)
	animacion.tween_property(material, "albedo_color:a", 0.0, 0.45)
	animacion.chain().tween_callback(func() -> void:
		luz.queue_free()
		bola.queue_free())
	# Mancha quemada en el suelo.
	var suelo: Dictionary = rayo(padre.get_world_3d(), pos + Vector3.UP * 0.5, Vector3.DOWN, radio, [])
	if not suelo.is_empty():
		marca_bala(padre, suelo["position"], Vector3.UP)
		var ultima = _marcas.back()
		if is_instance_valid(ultima):
			ultima.scale = Vector3.ONE * radio * 2.0
	# Daño a lo que esté cerca (más cuanto más cerca).
	for nodo in arbol.get_nodes_in_group("danable"):
		var cosa: Node3D = nodo as Node3D
		if cosa == null or not cosa.has_method("recibir_dano"):
			continue
		var d: float = cosa.global_position.distance_to(pos)
		if d < radio:
			cosa.recibir_dano(dano * (1.0 - d / radio))
	for nodo in arbol.get_nodes_in_group("jugador"):
		var d: float = (nodo as Node3D).global_position.distance_to(pos)
		if d < radio:
			Juego.cambiar_vida(-dano * 0.5 * (1.0 - d / radio))


# Lanza un proyectil (granada o cohete) con física.
static func lanzar(padre: Node3D, pos: Vector3, velocidad: Vector3, mecha: float,
		al_chocar: bool, radio: float, dano: float, color: Color, tam: float) -> void:
	var p: Proyectil = Proyectil.new()
	p.mecha = mecha
	p.al_chocar = al_chocar
	p.radio = radio
	p.dano = dano
	p.color = color
	p.tam = tam
	p.position = pos
	padre.add_child(p)
	p.linear_velocity = velocidad


# Detona todas las cargas C4 que hayas pegado.
static func detonar_c4(arbol: SceneTree) -> int:
	var cargas: Array = arbol.get_nodes_in_group("c4")
	for carga in cargas:
		carga.detonar()
	return cargas.size()
