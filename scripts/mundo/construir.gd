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


static var _textura_ruido: ImageTexture = null


# Una textura de grano suave (hecha con código) que da algo de relieve y
# variación a paredes y suelos en vez de un color liso. Se crea una sola vez.
static func _ruido() -> ImageTexture:
	if _textura_ruido == null:
		var generador: FastNoiseLite = FastNoiseLite.new()
		generador.noise_type = FastNoiseLite.TYPE_CELLULAR
		generador.frequency = 0.045
		generador.seed = 7
		var fino: FastNoiseLite = FastNoiseLite.new()
		fino.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fino.frequency = 0.25
		fino.seed = 11
		var imagen: Image = Image.create(256, 256, false, Image.FORMAT_L8)
		for y in 256:
			for x in 256:
				var a: float = generador.get_noise_2d(x, y) * 0.5 + 0.5
				var b: float = fino.get_noise_2d(x, y) * 0.5 + 0.5
				var v: float = 0.8 + 0.12 * a + 0.08 * b
				imagen.set_pixel(x, y, Color(v, v, v))
		imagen.generate_mipmaps()
		_textura_ruido = ImageTexture.create_from_image(imagen)
	return _textura_ruido


# Crea un material de un color. "brillo" > 0 hace que emita luz propia
# (ventanas encendidas, líquidos mágicos...).
static func material(color: Color, brillo: float = 0.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if brillo <= 0.0:
		# Grano en el espacio del objeto: no hace falta UV y se ve bien en cajas grandes.
		mat.albedo_texture = _ruido()
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * 0.4
	if brillo > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = brillo
	return mat


# Una caja. Si "solida" es true, el jugador choca con ella.
static func caja(padre: Node3D, pos: Vector3, tam: Vector3, color: Color,
		solida: bool = true, brillo: float = 0.0, material_extra: Material = null) -> Node3D:
	var malla: BoxMesh = BoxMesh.new()
	malla.size = tam
	malla.material = material_extra if material_extra != null else material(color, brillo)
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


# Un cristal: una caja fina y semitransparente (escaparates, ventanas).
static func cristal(padre: Node3D, pos: Vector3, tam: Vector3) -> Node3D:
	var malla: BoxMesh = BoxMesh.new()
	malla.size = tam
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.7, 0.75, 0.18)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	malla.material = mat
	var forma: BoxShape3D = BoxShape3D.new()
	forma.size = tam
	return _colocar(padre, pos, malla, forma)


# Una pared a lo largo del eje X (en "z") con huecos para puertas y ventanas.
# Cada hueco es un diccionario: {"x": centro, "ancho": m, "abajo": m, "arriba": m,
# "cristal": true/false}. La pared va de x = -ancho/2 a x = ancho/2.
static func pared_con_huecos(padre: Node3D, z: float, ancho: float, alto: float,
		grosor: float, huecos: Array, color: Color, material_extra: Material = null) -> void:
	# Cortamos la pared en columnas por los bordes de cada hueco.
	var cortes: Array[float] = [-ancho / 2.0, ancho / 2.0]
	for h in huecos:
		cortes.append(h["x"] - h["ancho"] / 2.0)
		cortes.append(h["x"] + h["ancho"] / 2.0)
	cortes.sort()
	for i in cortes.size() - 1:
		var x0: float = cortes[i]
		var x1: float = cortes[i + 1]
		if x1 - x0 < 0.001:
			continue
		var centro_x: float = (x0 + x1) / 2.0
		var hueco: Dictionary = {}
		for h in huecos:
			if absf(h["x"] - centro_x) < h["ancho"] / 2.0:
				hueco = h
		if hueco.is_empty():
			caja(padre, Vector3(centro_x, alto / 2.0, z), Vector3(x1 - x0, alto, grosor), color, true, 0.0, material_extra)
			continue
		# Columna con hueco: pared por debajo y por encima.
		var abajo: float = hueco["abajo"]
		var arriba: float = hueco["arriba"]
		if abajo > 0.0:
			caja(padre, Vector3(centro_x, abajo / 2.0, z), Vector3(x1 - x0, abajo, grosor), color, true, 0.0, material_extra)
		if arriba < alto:
			caja(padre, Vector3(centro_x, (arriba + alto) / 2.0, z), Vector3(x1 - x0, alto - arriba, grosor), color, true, 0.0, material_extra)
		if hueco.get("cristal", false):
			cristal(padre, Vector3(centro_x, (abajo + arriba) / 2.0, z), Vector3(x1 - x0, arriba - abajo, 0.04))


# Oculta todas las mallas de un nodo pero deja sus choques (para poner un
# modelo descargado encima de un mueble hecho con cajas).
static func ocultar_mallas(nodo: Node) -> void:
	for malla in nodo.find_children("*", "MeshInstance3D", true, false):
		(malla as MeshInstance3D).visible = false


# ------------------------------ Optimización ----------------------------------
# Funde en una sola malla todas las piezas fijas que cuelgan de "raiz" (paredes,
# tejado, estantes, adornos...). Un edificio hecho con 200 piezas le cuesta a la
# tarjeta gráfica 200 "llamadas de dibujo"; fundido, solo una por material. Se ve
# exactamente igual y los choques no cambian (los cuerpos sólidos se quedan).
#
# NO se funde lo que se mueve o cambia: cualquier cosa con script (puertas,
# vendedores, macetas, muebles que se usan), personajes y modelos con animación.
# Las ventanas que solo se ven de noche se funden aparte y siguen en su grupo.
static func fusionar(raiz: Node3D) -> void:
	var piezas: Array[MeshInstance3D] = []
	_reunir_mallas(raiz, piezas)
	if piezas.size() < 2:
		return
	var inversa: Transform3D = raiz.global_transform.affine_inverse()
	var grupos: Dictionary = {}    # clave -> {"st": SurfaceTool, "mat": Material, "noche": bool}
	for pieza in piezas:
		var visible_del_todo: bool = pieza.visible
		var noche: bool = pieza.is_in_group("ventanas_noche")
		if visible_del_todo or noche:
			var relativa: Transform3D = inversa * pieza.global_transform
			for s in pieza.mesh.get_surface_count():
				var mat: Material = pieza.get_active_material(s)
				var formato: int = 0
				if pieza.mesh is ArrayMesh:
					formato = (pieza.mesh as ArrayMesh).surface_get_format(s)
				var clave: String = "%s|%d|%s" % [_firma_material(mat), formato, noche]
				if not grupos.has(clave):
					var st: SurfaceTool = SurfaceTool.new()
					grupos[clave] = {"st": st, "mat": mat, "noche": noche, "primera": true}
				var g: Dictionary = grupos[clave]
				(g["st"] as SurfaceTool).append_from(pieza.mesh, s, relativa)
		# La pieza suelta ya no hace falta (su choque, si lo tiene, es otro nodo).
		pieza.get_parent().remove_child(pieza)
		pieza.queue_free()
	var malla_dia: ArrayMesh = ArrayMesh.new()
	var malla_noche: ArrayMesh = ArrayMesh.new()
	for clave in grupos:
		var g: Dictionary = grupos[clave]
		var st: SurfaceTool = g["st"]
		st.set_material(g["mat"])
		st.commit(malla_noche if g["noche"] else malla_dia)
	if malla_dia.get_surface_count() > 0:
		var fundida: MeshInstance3D = MeshInstance3D.new()
		fundida.name = "MallaFundida"
		fundida.mesh = malla_dia
		raiz.add_child(fundida)
	if malla_noche.get_surface_count() > 0:
		var luces: MeshInstance3D = MeshInstance3D.new()
		luces.name = "VentanasFundidas"
		luces.mesh = malla_noche
		luces.visible = false
		luces.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		luces.add_to_group("ventanas_noche")
		raiz.add_child(luces)


# Busca las mallas fijas bajo "nodo" sin entrar en lo que tiene vida propia.
static func _reunir_mallas(nodo: Node, salida: Array[MeshInstance3D]) -> void:
	for hijo in nodo.get_children():
		if hijo.get_script() != null or hijo is CharacterBody3D or hijo is RigidBody3D \
				or hijo is AnimationPlayer or hijo is Skeleton3D:
			continue
		if hijo.scene_file_path != "" and not hijo.find_children("*", "AnimationPlayer", true, false).is_empty():
			continue   # Modelo descargado con animación: se deja como está.
		if hijo is MeshInstance3D:
			var m: MeshInstance3D = hijo as MeshInstance3D
			if m.mesh != null and m.skin == null and m.get_child_count() == 0:
				salida.append(m)
				continue
		_reunir_mallas(hijo, salida)


# Dos materiales que se ven igual dan la misma firma, aunque sean copias distintas
# (cada caja crea el suyo): así sus piezas acaban en la misma malla.
static func _firma_material(mat: Material) -> String:
	if mat == null:
		return "nulo"
	var m: BaseMaterial3D = mat as BaseMaterial3D
	if m == null:
		return str(mat.get_rid().get_id())
	var t: Texture2D = m.albedo_texture
	var n: Texture2D = m.normal_texture
	return str([t.get_rid().get_id() if t != null else 0, n.get_rid().get_id() if n != null else 0,
			m.albedo_color, m.transparency, m.cull_mode, m.shading_mode, m.roughness, m.metallic,
			m.emission_enabled, m.emission, m.emission_energy_multiplier, m.uv1_triplanar, m.uv1_scale,
			m.vertex_color_use_as_albedo, m.normal_enabled])


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


# Como luz(), pero se enciende al anochecer y se apaga de día (ver ciclo_dia.gd).
static func luz_noche(padre: Node3D, pos: Vector3, color: Color, energia: float,
		alcance: float) -> OmniLight3D:
	var foco: OmniLight3D = luz(padre, pos, color, energia, alcance)
	foco.set_meta("energia_base", energia)
	foco.add_to_group("luces_noche")
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
