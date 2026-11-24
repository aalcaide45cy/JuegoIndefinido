# ropa.gd
# -----------------------------------------------------------------------------
# Viste a los personajes de la "Universal Base Characters" (que vienen en ropa interior) y les pone
# pelo. No hay modelos de ropa en el proyecto, así que la ropa se "pinta" sobre el cuerpo:
#   - Se copia la malla del cuerpo una vez por estilo (manga larga/corta/tirantes, pantalón
#     largo/corto/falda) y se marca cada vértice, según su sitio en la pose de reposo (en T), como
#     camisa (rojo), pantalón (verde), zapatos (azul) o piel. Se guarda en caché: 2 cuerpos x 9
#     estilos como mucho.
#   - Un shader mezcla la textura de piel con los colores de la ropa, que van por personaje
#     (parámetros de instancia), así que miles de peatones distintos comparten unas pocas mallas.
#   - El pelo (y la barba) son mallas del mismo pack pegadas al hueso de la cabeza.
#
#   Ropa.vestir(modelo, semilla)            -> ropa y pelo al azar (siempre igual para la misma semilla)
#   Ropa.vestir(modelo, semilla, {"camisa": Color.NAVY, "manga": 2, ...})   -> forzando prendas
# -----------------------------------------------------------------------------
class_name Ropa
extends RefCounted

const PELOS: String = "res://assets/quaternius/universal-base-characters/hairstyles-head-bone/"
const PELO_HOMBRE: Array = ["Hair_SimpleParted", "Hair_Buzzed", "Hair_SimpleParted", "", "Hair_Long"]
const PELO_MUJER: Array = ["Hair_Long", "Hair_Buns", "Hair_BuzzedFemale", "Hair_Long", "Hair_SimpleParted"]

# Hasta dónde llega la manga (|x| en la pose en T): tirantes, corta, larga.
const MANGA: Array = [0.24, 0.42, 0.78]
# Dónde acaba el pantalón por abajo: largo, corto (rodilla), falda (sin pernera, más ancha).
const PIERNA: Array = [0.09, 0.5, 0.5]

const CAMISAS: Array = [Color(0.85, 0.85, 0.82), Color(0.18, 0.22, 0.32), Color(0.55, 0.12, 0.12), Color(0.2, 0.38, 0.25),
		Color(0.85, 0.7, 0.3), Color(0.35, 0.5, 0.75), Color(0.12, 0.12, 0.13), Color(0.6, 0.45, 0.6), Color(0.9, 0.5, 0.35),
		Color(0.45, 0.42, 0.38)]
const PANTALONES: Array = [Color(0.15, 0.2, 0.35), Color(0.1, 0.1, 0.12), Color(0.4, 0.33, 0.25), Color(0.3, 0.3, 0.32),
		Color(0.55, 0.5, 0.4), Color(0.22, 0.28, 0.2)]
const ZAPATOS: Array = [Color(0.08, 0.06, 0.05), Color(0.3, 0.2, 0.12), Color(0.85, 0.85, 0.85), Color(0.15, 0.15, 0.18)]
# Tonos de piel: se multiplican por la textura original.
const PIELES: Array = [Color(1.0, 1.0, 1.0), Color(1.12, 1.08, 1.04), Color(0.82, 0.72, 0.66), Color(0.6, 0.5, 0.45), Color(1.05, 0.95, 0.85)]
const PELO_COLOR: Array = [Color(0.08, 0.06, 0.05), Color(0.3, 0.18, 0.1), Color(0.55, 0.4, 0.22), Color(0.8, 0.7, 0.45), Color(0.5, 0.5, 0.5)]

static var _mallas: Dictionary = {}
static var _shader: Shader = null
static var _materiales: Dictionary = {}
static var _pelos: Dictionary = {}

const CODIGO_SHADER: String = """
shader_type spatial;
uniform sampler2D textura : source_color, filter_linear_mipmap;
instance uniform vec4 camisa : source_color = vec4(0.3, 0.4, 0.6, 1.0);
instance uniform vec4 pantalon : source_color = vec4(0.15, 0.2, 0.35, 1.0);
instance uniform vec4 zapatos : source_color = vec4(0.1, 0.08, 0.06, 1.0);
instance uniform vec4 piel = vec4(1.0);
void fragment() {
	vec3 t = texture(textura, UV).rgb;
	float l = dot(t, vec3(0.299, 0.587, 0.114));
	float tela = 0.82 + 0.45 * l;   // Conserva un poco de las sombras del cuerpo en la tela.
	vec3 c = t * piel.rgb;
	c = mix(c, camisa.rgb * tela, COLOR.r);
	c = mix(c, pantalon.rgb * tela, COLOR.g);
	c = mix(c, zapatos.rgb * tela, COLOR.b);
	ALBEDO = c;
	float m = max(COLOR.r, max(COLOR.g, COLOR.b));
	ROUGHNESS = mix(0.55, 0.92, m);
	SPECULAR = mix(0.5, 0.2, m);
}
"""


static func vestir(modelo: Node3D, semilla: int, forzar: Dictionary = {}) -> void:
	if modelo == null:
		return
	var cuerpo: MeshInstance3D = _malla_cuerpo(modelo)
	if cuerpo == null:
		return   # No es un personaje de la librería base (p. ej. los muñecos toon ya van vestidos).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = semilla * 7919 + 13
	var mujer: bool = (cuerpo.mesh.resource_name + str(cuerpo.name)).to_lower().contains("female")
	var manga: int = int(forzar.get("manga", rng.randi_range(0, 2) if mujer else [1, 1, 2, 2, 0][rng.randi() % 5]))
	var pierna: int = int(forzar.get("pierna", ([0, 0, 2, 1][rng.randi() % 4]) if mujer else ([0, 0, 0, 1][rng.randi() % 4])))
	var clave: String = "%s|%d|%d" % [cuerpo.mesh.resource_name if cuerpo.mesh.resource_name != "" else str(cuerpo.mesh.get_instance_id()), manga, pierna]
	if not _mallas.has(clave):
		_mallas[clave] = _malla_vestida(cuerpo.mesh, manga, pierna)
	var nueva: ArrayMesh = _mallas[clave]
	if nueva == null:
		return
	cuerpo.mesh = nueva
	cuerpo.material_override = null
	cuerpo.set_surface_override_material(0, _material(cuerpo, clave))
	var camisa: Color = forzar.get("camisa", CAMISAS[rng.randi() % CAMISAS.size()])
	var pantalon: Color = forzar.get("pantalon", PANTALONES[rng.randi() % PANTALONES.size()])
	if pierna == 2 and not forzar.has("pantalon"):
		pantalon = camisa.darkened(0.15) if rng.randf() < 0.5 else PANTALONES[rng.randi() % PANTALONES.size()]   # Vestido o falda.
	var var_tono: float = rng.randf_range(-0.06, 0.06)
	cuerpo.set_instance_shader_parameter("camisa", Color(camisa.r + var_tono, camisa.g + var_tono, camisa.b + var_tono))
	cuerpo.set_instance_shader_parameter("pantalon", pantalon)
	cuerpo.set_instance_shader_parameter("zapatos", forzar.get("zapatos", ZAPATOS[rng.randi() % ZAPATOS.size()]))
	cuerpo.set_instance_shader_parameter("piel", forzar.get("piel", PIELES[rng.randi() % PIELES.size()]))
	var lista: Array = PELO_MUJER if mujer else PELO_HOMBRE
	var pelo: String = str(forzar.get("pelo", lista[rng.randi() % lista.size()]))
	var color_pelo: Color = forzar.get("color_pelo", PELO_COLOR[rng.randi() % PELO_COLOR.size()])
	if pelo != "":
		_poner_pelo(modelo, cuerpo, pelo, color_pelo)
	if not mujer and rng.randf() < 0.25:
		_poner_pelo(modelo, cuerpo, "Hair_Beard", color_pelo)
	# Las cejas, del color del pelo.
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).name.begins_with("Eyebrows"):
			var mat: StandardMaterial3D = _mat_pelo(color_pelo)
			(mi as MeshInstance3D).material_override = mat


static func _malla_cuerpo(modelo: Node3D) -> MeshInstance3D:
	var mejor: MeshInstance3D = null
	for n in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var tam: Vector3 = mi.mesh.get_aabb().size
		if tam.y > 1.4 and tam.x > 1.2 and (mejor == null or tam.y > mejor.mesh.get_aabb().size.y):
			mejor = mi   # El cuerpo en pose de T: alto y con los brazos abiertos.
	if mejor != null and not ((mejor.mesh.resource_name + str(mejor.name)).to_lower().contains("superhero") or mejor.mesh.has_meta("ropa")):
		return null
	return mejor


# Copia la malla y marca cada vértice como camisa / pantalón / zapatos / piel.
static func _malla_vestida(origen: Mesh, manga: int, pierna: int) -> ArrayMesh:
	if origen.has_meta("ropa"):
		origen = origen.get_meta("ropa")   # Ya estaba vestido: se parte de la malla original.
	var arr: Array = origen.surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var colores: PackedColorArray = PackedColorArray()
	colores.resize(pos.size())
	var alto: float = origen.get_aabb().end.y
	var k: float = alto / 1.81   # Las medidas son del hombre (1,81 m); la mujer es algo más baja.
	var cadera: float = 0.97 * k
	var cuello: float = 1.47 * k
	var lim_manga: float = MANGA[manga] * k
	var bajo: float = PIERNA[pierna] * k
	for i in pos.size():
		var v: Vector3 = pos[i]
		var ax: float = absf(v.x)
		var c: Color = Color(0, 0, 0, 1)
		if v.y < 0.085 * k:
			c = Color(0, 0, 1, 1)                                       # Zapatos.
		elif v.y < cadera and ax < 0.34 * k:
			if v.y >= bajo:
				c = Color(0, 1, 0, 1)                                   # Pantalón o falda.
			elif pierna == 2 and v.y >= bajo - 0.05 * k:
				c = Color(0, 1, 0, 1)
		elif v.y >= cadera and v.y < cuello and ax < lim_manga:
			# Escote: la base del cuello queda al aire.
			if not (v.y > cuello - 0.05 * k and ax < 0.09 * k and v.z > -0.02):
				c = Color(1, 0, 0, 1)                                   # Camisa.
		colores[i] = c
	arr[Mesh.ARRAY_COLOR] = colores
	for canal in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		arr[canal] = null   # Canales extra del glTF que no usamos (y que piden su propio formato).
	var nueva: ArrayMesh = ArrayMesh.new()
	var formato: int = origen.surface_get_format(0)
	var flags: int = formato & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var formas: Array = []
	if origen is ArrayMesh:
		var am: ArrayMesh = origen as ArrayMesh
		for b in am.get_blend_shape_count():
			nueva.add_blend_shape(am.get_blend_shape_name(b))
		nueva.blend_shape_mode = am.blend_shape_mode
		formas = am.surface_get_blend_shape_arrays(0)
	nueva.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, formas, {}, flags)
	nueva.resource_name = origen.resource_name
	nueva.set_meta("ropa", origen)
	return nueva


static func _material(cuerpo: MeshInstance3D, clave: String) -> ShaderMaterial:
	var base: String = clave.get_slice("|", 0)
	if _materiales.has(base):
		return _materiales[base]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODIGO_SHADER
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _shader
	var original: Material = (cuerpo.mesh.get_meta("ropa") as Mesh).surface_get_material(0) if cuerpo.mesh.has_meta("ropa") else null
	if original is StandardMaterial3D:
		mat.set_shader_parameter("textura", (original as StandardMaterial3D).albedo_texture)
	_materiales[base] = mat
	return mat


static func _mat_pelo(color: Color) -> StandardMaterial3D:
	var clave: String = color.to_html()
	if _materiales.has(clave):
		return _materiales[clave]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	_materiales[clave] = m
	return m


# El pelo viene como malla en el espacio del modelo (pegada a la cabeza en reposo): se cuelga del
# hueso "Head" deshaciendo la pose de reposo de ese hueso, así sigue a la cabeza al animar.
static func _poner_pelo(modelo: Node3D, cuerpo: MeshInstance3D, nombre: String, color: Color) -> void:
	var esq: Skeleton3D = cuerpo.get_parent() as Skeleton3D
	if esq == null:
		var l: Array = modelo.find_children("*", "Skeleton3D", true, false)
		if l.is_empty():
			return
		esq = l[0]
	var hueso: int = esq.find_bone("Head")
	if hueso < 0:
		return
	if not _pelos.has(nombre):
		var ruta: String = PELOS + nombre + ".gltf"
		var malla: Mesh = null
		if ResourceLoader.exists(ruta):
			var n: Node = (load(ruta) as PackedScene).instantiate()
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				malla = (mi as MeshInstance3D).mesh
				break
			n.free()
		_pelos[nombre] = malla
	var m: Mesh = _pelos[nombre]
	if m == null:
		return
	var pegado: BoneAttachment3D = BoneAttachment3D.new()
	pegado.name = "Pelo_" + nombre
	pegado.bone_name = "Head"
	esq.add_child(pegado)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _mat_pelo(color)
	# Reposo del hueso en el espacio del esqueleto: el pelo está modelado para el cuerpo masculino;
	# en la mujer se ajusta con la diferencia de altura de la cabeza.
	var reposo: Transform3D = esq.get_bone_global_rest(hueso)
	var ajuste: Vector3 = Vector3(0, reposo.origin.y - 1.5998, reposo.origin.z + 0.0174)
	mi.transform = reposo.affine_inverse() * Transform3D(Basis(), ajuste)
	pegado.add_child(mi)
