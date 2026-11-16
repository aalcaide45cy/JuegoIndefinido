# construir.gd
# -----------------------------------------------------------------------------
# Pequeñas funciones para montar el mundo con formas simples (cajas, cilindros,
# luces y carteles) desde código. Así no hace falta modelar nada en Blender
# para el prototipo: cuando haya modelos de verdad, se cambian estas cajas.
#
# Uso:  Construir.caja(padre, posicion, tamaño, color)
# -----------------------------------------------------------------------------
class_name Construir
extends RefCounted


# Crea un material de un color. "brillo" > 0 hace que emita luz propia
# (ventanas encendidas, líquidos mágicos...).
static func material(color: Color, brillo: float = 0.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if brillo > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = brillo
	return mat


# Una caja. Si "solida" es true, el jugador choca con ella.
static func caja(padre: Node3D, pos: Vector3, tam: Vector3, color: Color,
		solida: bool = true, brillo: float = 0.0) -> Node3D:
	var malla: BoxMesh = BoxMesh.new()
	malla.size = tam
	malla.material = material(color, brillo)
	var forma: BoxShape3D = null
	if solida:
		forma = BoxShape3D.new()
		forma.size = tam
	return _colocar(padre, pos, malla, forma)


# Un cilindro (macetas, caldero, farolas...). radio_arriba permite hacer conos.
static func cilindro(padre: Node3D, pos: Vector3, radio: float, alto: float,
		color: Color, solida: bool = false, brillo: float = 0.0,
		radio_arriba: float = -1.0) -> Node3D:
	var malla: CylinderMesh = CylinderMesh.new()
	malla.bottom_radius = radio
	malla.top_radius = radio if radio_arriba < 0.0 else radio_arriba
	malla.height = alto
	malla.radial_segments = 16
	malla.material = material(color, brillo)
	var forma: CylinderShape3D = null
	if solida:
		forma = CylinderShape3D.new()
		forma.radius = radio
		forma.height = alto
	return _colocar(padre, pos, malla, forma)


# Una esfera (cabezas, sombreros de seta...). Se puede aplastar con "escala".
static func esfera(padre: Node3D, pos: Vector3, radio: float, color: Color,
		escala: Vector3 = Vector3.ONE, brillo: float = 0.0) -> Node3D:
	var malla: SphereMesh = SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2.0
	malla.material = material(color, brillo)
	var nodo: Node3D = _colocar(padre, pos, malla, null)
	nodo.scale = escala
	return nodo


# Una luz que ilumina alrededor (farolas, velas, el fuego del caldero).
static func luz(padre: Node3D, pos: Vector3, color: Color, energia: float,
		alcance: float) -> OmniLight3D:
	var foco: OmniLight3D = OmniLight3D.new()
	foco.position = pos
	foco.light_color = color
	foco.light_energy = energia
	foco.omni_range = alcance
	padre.add_child(foco)
	return foco


# Un cartel de texto flotando en el mundo. Por defecto mira hacia +Z.
static func texto(padre: Node3D, pos: Vector3, contenido: String,
		tam: int = 48, color: Color = Color(0.9, 0.88, 0.8)) -> Label3D:
	var etiqueta: Label3D = Label3D.new()
	etiqueta.position = pos
	etiqueta.text = contenido
	etiqueta.font_size = tam
	etiqueta.pixel_size = 0.004
	etiqueta.modulate = color
	etiqueta.outline_size = 8
	etiqueta.outline_modulate = Color(0, 0, 0, 0.8)
	padre.add_child(etiqueta)
	return etiqueta


# Coloca una malla en el mundo; si hay forma de choque, la mete en un StaticBody3D.
static func _colocar(padre: Node3D, pos: Vector3, malla: Mesh, forma: Shape3D) -> Node3D:
	var instancia: MeshInstance3D = MeshInstance3D.new()
	instancia.mesh = malla
	if forma == null:
		instancia.position = pos
		padre.add_child(instancia)
		return instancia
	var cuerpo: StaticBody3D = StaticBody3D.new()
	cuerpo.position = pos
	padre.add_child(cuerpo)
	var choque: CollisionShape3D = CollisionShape3D.new()
	choque.shape = forma
	cuerpo.add_child(choque)
	cuerpo.add_child(instancia)
	return cuerpo
