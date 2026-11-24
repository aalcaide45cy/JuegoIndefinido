# marcas_frenada.gd
# -----------------------------------------------------------------------------
# Marcas negras de neumático en el suelo cuando un coche derrapa, frena en seco o
# patina al arrancar. Todas las marcas del mundo van en UNA sola malla múltiple
# (MultiMesh) con un máximo de trozos: las más viejas se reutilizan. Así cuestan
# una sola llamada de dibujo aunque haya cientos.
#   MarcasFrenada.poner(arbol, clave_rueda, punto, normal, ancho, fuerza)
#   MarcasFrenada.cortar(clave_rueda)   # la rueda dejó de patinar: la próxima marca empieza de nuevo
# -----------------------------------------------------------------------------
class_name MarcasFrenada
extends MultiMeshInstance3D

const MAXIMO: int = 1200
const TRAMO_MIN: float = 0.35   # Distancia mínima entre puntos (m).

static var _yo: MarcasFrenada = null

var _siguiente: int = 0
var _ultimo: Dictionary = {}    # clave -> último punto (Vector3)


static func _obtener(arbol: SceneTree) -> MarcasFrenada:
	if _yo != null and is_instance_valid(_yo) and _yo.is_inside_tree():
		return _yo
	_yo = MarcasFrenada.new()
	if arbol.current_scene != null:
		arbol.current_scene.add_child(_yo)
	else:
		arbol.root.add_child(_yo)
	return _yo


static func cortar(clave: int) -> void:
	if _yo != null and is_instance_valid(_yo):
		_yo._ultimo.erase(clave)


static func poner(arbol: SceneTree, clave: int, punto: Vector3, normal: Vector3, ancho: float, fuerza: float) -> void:
	if arbol == null:
		return
	_obtener(arbol)._poner(clave, punto, normal, ancho, fuerza)


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.orientation = PlaneMesh.FACE_Y
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.03, 0.03, 1.0)
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = -1
	quad.material = mat
	mm.mesh = quad
	mm.instance_count = MAXIMO
	mm.visible_instance_count = 0
	multimesh = mm


func _poner(clave: int, punto: Vector3, normal: Vector3, ancho: float, fuerza: float) -> void:
	if not _ultimo.has(clave):
		_ultimo[clave] = punto
		return
	var antes: Vector3 = _ultimo[clave]
	var tramo: Vector3 = punto - antes
	var largo: float = tramo.length()
	if largo < TRAMO_MIN:
		return
	_ultimo[clave] = punto
	if largo > 3.0:
		return   # Un salto (teletransporte o fotograma largo): no dibujar una raya enorme.
	var centro: Vector3 = (punto + antes) * 0.5 + normal * 0.025
	var z: Vector3 = tramo / largo
	var x: Vector3 = normal.cross(z).normalized()
	var y: Vector3 = normal
	var base: Basis = Basis(x * ancho, y, z * (largo + 0.05))
	var i: int = _siguiente
	multimesh.set_instance_transform(i, Transform3D(base, centro))
	multimesh.set_instance_color(i, Color(1, 1, 1, clampf(0.25 + fuerza * 0.05, 0.25, 0.75)))
	_siguiente = (_siguiente + 1) % MAXIMO
	multimesh.visible_instance_count = maxi(multimesh.visible_instance_count, i + 1)
