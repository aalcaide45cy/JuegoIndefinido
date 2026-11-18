# estilo.gd
# -----------------------------------------------------------------------------
# Estilo "low poly" de todo el juego: caras planas, pocos polígonos, colores
# lisos y sin texturas pesadas. Aquí viven la paleta común (mundo e interfaz) y
# las ayudas que aplanan modelos descargados y mallas redondas.
#
#   Estilo.aplanar(nodo)        -> cambia las texturas de un modelo por su color medio
#   Estilo.facetar(malla)       -> devuelve la malla con caras planas (sin suavizado)
#   Estilo.color_medio(textura) -> color medio de una textura (con caché)
# -----------------------------------------------------------------------------
class_name Estilo
extends RefCounted

# ---------------- Paleta de la interfaz (tinta oscura + verde bruma + oro) ---
const FONDO: Color = Color(0.055, 0.07, 0.075, 0.96)
const FONDO_2: Color = Color(0.095, 0.12, 0.125, 1.0)
const FONDO_3: Color = Color(0.135, 0.165, 0.17, 1.0)
const BORDE: Color = Color(0.30, 0.56, 0.38)
const BORDE_SUAVE: Color = Color(0.18, 0.30, 0.24)
const ACENTO: Color = Color(0.45, 0.88, 0.58)
const ORO: Color = Color(1.0, 0.82, 0.32)
const TEXTO: Color = Color(0.92, 0.95, 0.90)
const TEXTO_SUAVE: Color = Color(0.68, 0.76, 0.70)
const PELIGRO: Color = Color(0.95, 0.38, 0.34)
const AVISO: Color = Color(1.0, 0.72, 0.28)
const INFO: Color = Color(0.42, 0.78, 0.98)
const MAGIA: Color = Color(0.72, 0.58, 0.98)

static var _medios: Dictionary = {}     # id de textura -> Color
static var _planos: Dictionary = {}     # id de material -> StandardMaterial3D plano


# Color medio de una textura (1 píxel). Se calcula una sola vez por textura.
static func color_medio(tex: Texture2D) -> Color:
	if tex == null:
		return Color.WHITE
	var id: int = tex.get_rid().get_id()
	if _medios.has(id):
		return _medios[id]
	var c: Color = Color(0.7, 0.7, 0.7)
	var img: Image = tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(1, 1, Image.INTERPOLATE_LANCZOS)
		c = img.get_pixel(0, 0)
		c.a = 1.0
	_medios[id] = c
	return c


# Material liso (sin texturas) equivalente a otro con texturas.
static func material_plano(mat: BaseMaterial3D) -> StandardMaterial3D:
	var id: int = mat.get_rid().get_id()
	if _planos.has(id):
		return _planos[id]
	var plano: StandardMaterial3D = StandardMaterial3D.new()
	var base: Color = mat.albedo_color
	if mat.albedo_texture != null:
		var medio: Color = color_medio(mat.albedo_texture)
		base = Color(base.r * medio.r, base.g * medio.g, base.b * medio.b, base.a)
		# Un poco más de color: los medios de textura salen apagados.
		base = base.lerp(Color(base.r, base.g, base.b).lightened(0.05), 0.5)
	plano.albedo_color = base
	plano.transparency = mat.transparency
	plano.cull_mode = mat.cull_mode
	plano.roughness = 1.0
	plano.metallic = 0.0
	plano.metallic_specular = 0.15
	plano.vertex_color_use_as_albedo = mat.vertex_color_use_as_albedo
	plano.emission_enabled = mat.emission_enabled
	plano.emission = mat.emission
	plano.emission_energy_multiplier = mat.emission_energy_multiplier
	_planos[id] = plano
	return plano


# Cambia, en todo el modelo, las texturas por su color medio. Los modelos con
# animación de personaje se dejan como están (la piel y la ropa llevan pintura).
static func aplanar(raiz: Node) -> void:
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(s)
			var base: BaseMaterial3D = mat as BaseMaterial3D
			if base != null and base.albedo_texture != null:
				mi.set_surface_override_material(s, material_plano(base))


# Devuelve una copia de la malla con las normales por cara (aspecto facetado).
static func facetar(malla: Mesh) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.create_from(malla, 0)
	st.deindex()
	st.generate_normals()
	var res: ArrayMesh = st.commit()
	res.surface_set_material(0, malla.surface_get_material(0))
	return res


# Tipografía de la interfaz: una letra geométrica y limpia de las que trae el
# sistema (Bahnschrift en Windows). No se incluye ningún archivo de letra: si no
# existe, se usa la de siempre.
static var _fuente_aplicada: bool = false


static func aplicar_fuente() -> void:
	if _fuente_aplicada:
		return
	_fuente_aplicada = true
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Roboto", "Noto Sans"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	ThemeDB.fallback_font = f


# Animación suave de los botones: crecen un poco al pasar el ratón y se
# hunden al pulsarlos.
static func animar_boton(b: Button) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	b.mouse_entered.connect(func() -> void: _escala(b, 1.04, 0.10))
	b.mouse_exited.connect(func() -> void: _escala(b, 1.0, 0.12))
	b.button_down.connect(func() -> void: _escala(b, 0.96, 0.05))
	b.button_up.connect(func() -> void: _escala(b, 1.04 if b.is_hovered() else 1.0, 0.08))


static func _escala(c: Control, valor: float, seg: float) -> void:
	if not c.is_inside_tree():
		return
	var t: Tween = c.create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(c, "scale", Vector2(valor, valor), seg)
