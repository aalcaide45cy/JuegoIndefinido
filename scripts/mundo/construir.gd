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


# Materiales ya creados, por color y brillo. Todas las cajas del mismo color
# comparten material: así la tarjeta gráfica cambia menos de estado y las mallas
# se pueden fusionar (ver fusionar_estaticos). OJO: si vas a cambiar el color o
# el brillo de un objeto mientras juegas, pídele antes material_propio().
static var _materiales: Dictionary = {}
static var _material_cristal: StandardMaterial3D = null


# Material de un color (compartido). "brillo" > 0 hace que emita luz propia
# (ventanas encendidas, líquidos mágicos...).
static func material(color: Color, brillo: float = 0.0) -> StandardMaterial3D:
	var clave: String = "%s|%.3f" % [color.to_html(true), brillo]
	if not _materiales.has(clave):
		_materiales[clave] = material_unico(color, brillo)
	return _materiales[clave]


# Da a la malla de "nodo" (una caja, cilindro o esfera hecha con estas funciones)
# un material solo suyo, para poder cambiarle el color o el brillo sin tocar los
# demás objetos del mismo color. Devuelve ese material.
static func material_propio(nodo: Node3D) -> StandardMaterial3D:
	var instancia: MeshInstance3D = nodo as MeshInstance3D
	if instancia == null:
		return null
	var primitiva: PrimitiveMesh = instancia.mesh as PrimitiveMesh
	if primitiva == null:
		return null
	var copia: StandardMaterial3D = (primitiva.material as StandardMaterial3D).duplicate() as StandardMaterial3D
	primitiva.material = copia
	return copia


# Como material(), pero siempre nuevo (no compartido).
static func material_unico(color: Color, brillo: float = 0.0) -> StandardMaterial3D:
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
	if _material_cristal == null:
		_material_cristal = StandardMaterial3D.new()
		_material_cristal.albedo_color = Color(0.55, 0.7, 0.75, 0.18)
		_material_cristal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material_cristal.roughness = 0.1
	malla.material = _material_cristal
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


# Una luz que ilumina alrededor (farolas, velas, el fuego del caldero).
static func luz(padre: Node3D, pos: Vector3, color: Color, energia: float,
		alcance: float) -> OmniLight3D:
	var foco: OmniLight3D = OmniLight3D.new()
	foco.position = pos
	foco.light_color = color
	foco.light_energy = energia
	foco.omni_range = alcance
	# Las luces lejos de la cámara se apagan solas (ciclo_dia.gd): con el
	# renderizador Compatibilidad cada luz cuesta una pasada más por objeto.
	foco.add_to_group("luces_lod")
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


# ---------------------- Fusionar mallas que no se mueven -----------------------
# La ciudad se monta con miles de piezas (cajas, paredes, ventanas, tejados...)
# y cada pieza es una "llamada de dibujo" para la tarjeta gráfica. Esta función
# las junta: todas las piezas del mismo material que caen en el mismo cuadrado
# de CELDA_FUSION x CELDA_FUSION metros pasan a ser UNA sola malla.
#   - Los choques no se tocan (siguen en sus StaticBody3D).
#   - No se fusiona nada que tenga script propio (puertas, macetas, caldero,
#     tenderos, guardias, dianas...), porque se mueve o cambia de color.
#   - Las ventanas que se encienden de noche (grupo "ventanas_noche") se juntan
#     aparte y las mallas nuevas siguen en ese grupo.
# Se llama una vez al terminar de construir el mundo (mundo.gd).
const CELDA_FUSION: float = 16.0


static func fusionar_estaticos(raiz: Node3D, celda: float = CELDA_FUSION) -> int:
	var grupos: Dictionary = {}       # clave -> Array de entradas [arrays, Transform3D]
	var materiales: Dictionary = {}   # clave -> Material (o null)
	var nocturnos: Dictionary = {}    # clave -> true si son ventanas de noche
	var cache_arrays: Dictionary = {} # "id_malla:superficie" -> arrays (mallas compartidas)
	var usadas: Array[MeshInstance3D] = []
	var inversa: Transform3D = raiz.global_transform.affine_inverse()
	_recoger_mallas(raiz, inversa, celda, grupos, materiales, nocturnos, cache_arrays, usadas)
	if usadas.is_empty():
		return 0
	var contenedor: Node3D = Node3D.new()
	contenedor.name = "MallasFusionadas"
	raiz.add_child(contenedor)
	for clave in grupos:
		var malla: ArrayMesh = _construir_malla(grupos[clave])
		if malla == null:
			continue
		if materiales[clave] != null:
			malla.surface_set_material(0, materiales[clave])
		var instancia: MeshInstance3D = MeshInstance3D.new()
		instancia.mesh = malla
		contenedor.add_child(instancia)
		if nocturnos[clave]:
			instancia.visible = false
			instancia.add_to_group("ventanas_noche")
	for m in usadas:
		if m.is_in_group("ventanas_noche"):
			m.remove_from_group("ventanas_noche")
		if m.get_child_count() == 0:
			m.queue_free()
		else:
			m.mesh = null
	return usadas.size()


static func _recoger_mallas(nodo: Node, inversa: Transform3D, celda: float, grupos: Dictionary,
		materiales: Dictionary, nocturnos: Dictionary, cache_arrays: Dictionary,
		usadas: Array[MeshInstance3D]) -> void:
	for hijo in nodo.get_children():
		# Lo que tiene script propio se deja tal cual (salvo los barrios, que solo construyen).
		if hijo.get_script() != null and not (hijo is Barrio):
			continue
		if (hijo is AnimationPlayer) or (hijo is Skeleton3D) or (hijo is CharacterBody3D) \
				or (hijo is RigidBody3D) or (hijo is AnimatableBody3D) or _tiene_animacion(hijo):
			continue
		var noche: bool = hijo.is_in_group("ventanas_noche")
		if (hijo is Node3D) and not (hijo as Node3D).visible and not noche:
			continue  # Oculto (por ejemplo, la caja de choque bajo un modelo): no se dibuja.
		if hijo is MeshInstance3D:
			_anotar_malla(hijo as MeshInstance3D, noche, inversa, celda, grupos, materiales,
					nocturnos, cache_arrays, usadas)
		_recoger_mallas(hijo, inversa, celda, grupos, materiales, nocturnos, cache_arrays, usadas)


static func _tiene_animacion(nodo: Node) -> bool:
	for h in nodo.get_children():
		if h is AnimationPlayer:
			return true
	return false


# Mira si una malla se puede fusionar y, si se puede, la apunta en su grupo.
static func _anotar_malla(mi: MeshInstance3D, noche: bool, inversa: Transform3D, celda: float,
		grupos: Dictionary, materiales: Dictionary, nocturnos: Dictionary,
		cache_arrays: Dictionary, usadas: Array[MeshInstance3D]) -> void:
	var malla: Mesh = mi.mesh
	if malla == null or mi.skin != null or mi.material_overlay != null or mi.transparency > 0.0:
		return
	if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON or mi.visibility_range_end > 0.0:
		return
	var primitiva: PrimitiveMesh = malla as PrimitiveMesh
	var lista: ArrayMesh = malla as ArrayMesh
	if primitiva == null and lista == null:
		return
	if lista != null and lista.get_blend_shape_count() > 0:
		return
	var t: Transform3D = inversa * mi.global_transform
	var centro: Vector3 = t * malla.get_aabb().get_center()
	var cx: int = floori(centro.x / celda)
	var cz: int = floori(centro.z / celda)
	# Primero se comprueban todas las superficies: o se fusiona entera o nada.
	var piezas: Array = []
	for s in malla.get_surface_count():
		if lista != null:
			if lista.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				return
			if lista.surface_get_format(s) & Mesh.ARRAY_FORMAT_BONES:
				return
		var arrays: Array = []
		if primitiva != null:
			arrays = primitiva.get_mesh_arrays()
		else:
			var clave_cache: String = "%d:%d" % [malla.get_instance_id(), s]
			if not cache_arrays.has(clave_cache):
				cache_arrays[clave_cache] = malla.surface_get_arrays(s)
			arrays = cache_arrays[clave_cache]
		if arrays.size() < Mesh.ARRAY_MAX or arrays[Mesh.ARRAY_VERTEX] == null:
			return
		var mat: Material = mi.get_active_material(s)
		var id_mat: int = 0 if mat == null else mat.get_instance_id()
		var clave: String = "%d|%d|%d|%d" % [cx, cz, id_mat, 1 if noche else 0]
		piezas.append([clave, mat, arrays])
	for p in piezas:
		var clave: String = p[0]
		if not grupos.has(clave):
			grupos[clave] = []
			materiales[clave] = p[1]
			nocturnos[clave] = noche
		grupos[clave].append([p[2], t])
	usadas.append(mi)


static func _tiene(arrays: Array, indice: int) -> bool:
	return arrays[indice] != null and arrays[indice].size() > 0


# Junta las piezas de un grupo en una ArrayMesh de una sola superficie.
static func _construir_malla(entradas: Array) -> ArrayMesh:
	var con_tangente: bool = false
	var con_color: bool = false
	var con_uv: bool = false
	var con_uv2: bool = false
	for e in entradas:
		var a: Array = e[0]
		con_tangente = con_tangente or _tiene(a, Mesh.ARRAY_TANGENT)
		con_color = con_color or _tiene(a, Mesh.ARRAY_COLOR)
		con_uv = con_uv or _tiene(a, Mesh.ARRAY_TEX_UV)
		con_uv2 = con_uv2 or _tiene(a, Mesh.ARRAY_TEX_UV2)
	var vertices: PackedVector3Array = PackedVector3Array()
	var normales: PackedVector3Array = PackedVector3Array()
	var tangentes: PackedFloat32Array = PackedFloat32Array()
	var colores: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var uvs2: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for e in entradas:
		var a: Array = e[0]
		var t: Transform3D = e[1]
		# Las normales se giran con la inversa traspuesta (así quedan bien aunque
		# la pieza esté estirada más en un eje que en otro).
		var base_normal: Basis = t.basis.inverse().transposed()
		var espejo: bool = t.basis.determinant() < 0.0
		var desde: int = vertices.size()
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: int = v.size()
		var tiene_normal: bool = _tiene(a, Mesh.ARRAY_NORMAL)
		var tiene_tangente: bool = _tiene(a, Mesh.ARRAY_TANGENT)
		var tiene_color: bool = _tiene(a, Mesh.ARRAY_COLOR)
		var tiene_uv: bool = _tiene(a, Mesh.ARRAY_TEX_UV)
		var tiene_uv2: bool = _tiene(a, Mesh.ARRAY_TEX_UV2)
		var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if tiene_normal else PackedVector3Array()
		var tng: PackedFloat32Array = a[Mesh.ARRAY_TANGENT] if tiene_tangente else PackedFloat32Array()
		var col: PackedColorArray = a[Mesh.ARRAY_COLOR] if tiene_color else PackedColorArray()
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if tiene_uv else PackedVector2Array()
		var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2] if tiene_uv2 else PackedVector2Array()
		for k in n:
			vertices.append(t * v[k])
			if tiene_normal:
				normales.append((base_normal * nrm[k]).normalized())
			else:
				normales.append(Vector3.UP)
			if con_tangente:
				if tiene_tangente:
					var tg: Vector3 = (t.basis * Vector3(tng[k * 4], tng[k * 4 + 1], tng[k * 4 + 2])).normalized()
					tangentes.append(tg.x)
					tangentes.append(tg.y)
					tangentes.append(tg.z)
					tangentes.append(-tng[k * 4 + 3] if espejo else tng[k * 4 + 3])
				else:
					tangentes.append(1.0)
					tangentes.append(0.0)
					tangentes.append(0.0)
					tangentes.append(1.0)
			if con_color:
				colores.append(col[k] if tiene_color else Color.WHITE)
			if con_uv:
				uvs.append(uv[k] if tiene_uv else Vector2.ZERO)
			if con_uv2:
				uvs2.append(uv2[k] if tiene_uv2 else Vector2.ZERO)
		# Índices de los triángulos (si la pieza no los trae, van seguidos).
		var ind: PackedInt32Array = PackedInt32Array()
		if _tiene(a, Mesh.ARRAY_INDEX):
			ind = a[Mesh.ARRAY_INDEX]
		else:
			ind.resize(n - n % 3)
			for k in ind.size():
				ind[k] = k
		var tri: int = 0
		while tri + 2 < ind.size():
			indices.append(desde + ind[tri])
			# Si la pieza está reflejada (escala negativa), se da la vuelta al triángulo.
			if espejo:
				indices.append(desde + ind[tri + 2])
				indices.append(desde + ind[tri + 1])
			else:
				indices.append(desde + ind[tri + 1])
				indices.append(desde + ind[tri + 2])
			tri += 3
	if vertices.is_empty() or indices.is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	if con_tangente:
		arrays[Mesh.ARRAY_TANGENT] = tangentes
	if con_color:
		arrays[Mesh.ARRAY_COLOR] = colores
	if con_uv:
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	if con_uv2:
		arrays[Mesh.ARRAY_TEX_UV2] = uvs2
	arrays[Mesh.ARRAY_INDEX] = indices
	var resultado: ArrayMesh = ArrayMesh.new()
	resultado.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return resultado
