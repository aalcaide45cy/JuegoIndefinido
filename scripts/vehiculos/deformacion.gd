# deformacion.gd
# -----------------------------------------------------------------------------
# Abolladuras de verdad: en un choque se hunden los vértices de la carrocería que
# están cerca del golpe, hacia dentro y en la dirección del impacto. Cuanto más
# fuerte el golpe, más grande y más honda la abolladura (con tope, para que el
# coche no se convierta en un churro). Antes los coches no cambiaban nada al
# chocar.
#
# La primera vez que se abolla un coche, sus mallas se copian (las mallas de los
# modelos están compartidas entre todos los coches del mismo tipo: sin copiar, se
# abollarían todos a la vez).
# -----------------------------------------------------------------------------
class_name Deformacion
extends RefCounted

const HONDO_MAX: float = 0.32        # Lo más que se hunde un punto en un golpe (m).
const ACUMULADO_MAX: float = 0.55    # Lo más que se puede hundir en total (m).


# raiz: el nodo de la carrocería (no las ruedas). punto y direccion en coordenadas globales;
# direccion apunta hacia DENTRO del coche. fuerza en m/s de cambio de velocidad.
static func abollar(raiz: Node3D, punto: Vector3, direccion: Vector3, fuerza: float) -> void:
	if raiz == null or not is_instance_valid(raiz) or fuerza < 3.0:
		return
	var radio: float = clampf(0.45 + fuerza * 0.06, 0.5, 1.6)
	var hondo: float = clampf(fuerza * 0.014, 0.02, HONDO_MAX)
	for mi in raiz.find_children("*", "MeshInstance3D", true, false):
		_abollar_malla(mi as MeshInstance3D, punto, direccion, radio, hondo)


static func _abollar_malla(mi: MeshInstance3D, punto: Vector3, direccion: Vector3, radio: float, hondo: float) -> void:
	if mi.mesh == null:
		return
	var inv: Transform3D = mi.global_transform.affine_inverse()
	var p: Vector3 = inv * punto
	# La escala del modelo puede ser muy distinta de 1: el radio y la profundidad se pasan a
	# coordenadas de la malla.
	var esc: float = maxf(0.0001, mi.global_transform.basis.get_scale().x)
	var r_local: float = radio / esc
	var h_local: float = hondo / esc
	var d_local: Vector3 = (inv.basis * direccion).normalized()
	var aabb: AABB = mi.get_aabb().grow(r_local)
	if not aabb.has_point(p):
		return
	var original: Mesh = mi.mesh
	var malla: ArrayMesh
	if mi.has_meta("malla_propia"):
		malla = mi.mesh as ArrayMesh
	else:
		malla = _copiar(original)
		if malla == null:
			return
		mi.set_meta("malla_original", original)
		mi.mesh = malla
		mi.set_meta("malla_propia", true)
		mi.set_meta("hundido", {})
	var hundido: Dictionary = mi.get_meta("hundido")
	var acum_max: float = ACUMULADO_MAX / esc
	var nueva: ArrayMesh = ArrayMesh.new()
	for s in malla.get_surface_count():
		var arrays: Array = malla.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var cambiado: bool = false
		for i in verts.size():
			var v: Vector3 = verts[i]
			var dist: float = v.distance_to(p)
			if dist >= r_local:
				continue
			var clave: int = s * 1000000 + i
			var ya: float = float(hundido.get(clave, 0.0))
			if ya >= acum_max:
				continue
			# Caída suave (coseno): el centro se hunde más que los bordes.
			var k: float = 0.5 + 0.5 * cos(PI * dist / r_local)
			var mover: float = minf(h_local * k, acum_max - ya)
			# Un poco de ruido: la chapa no se hunde perfectamente redonda.
			mover *= 0.8 + 0.4 * fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
			verts[i] = v + d_local * mover
			hundido[clave] = ya + mover
			cambiado = true
		if cambiado:
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = null   # Que Godot no use normales viejas en la zona hundida
			arrays[Mesh.ARRAY_TANGENT] = null
			_recalcular_normales(arrays)
		nueva.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		nueva.surface_set_material(s, malla.surface_get_material(s))
	mi.mesh = nueva


static func _copiar(original: Mesh) -> ArrayMesh:
	if not (original is ArrayMesh):
		return null
	var copia: ArrayMesh = ArrayMesh.new()
	for s in original.get_surface_count():
		if original.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return null
		var arrays: Array = original.surface_get_arrays(s)
		arrays[Mesh.ARRAY_TANGENT] = null
		copia.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		copia.surface_set_material(s, original.surface_get_material(s))
	return copia


# Normales por vértice a partir de las caras (la luz se ve bien en la abolladura).
static func _recalcular_normales(arrays: Array) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = PackedVector3Array()
	normales.resize(verts.size())
	var indices = arrays[Mesh.ARRAY_INDEX]
	if indices == null or (indices as PackedInt32Array).is_empty():
		for i in range(0, verts.size() - 2, 3):
			var n: Vector3 = (verts[i + 2] - verts[i]).cross(verts[i + 1] - verts[i])
			normales[i] += n
			normales[i + 1] += n
			normales[i + 2] += n
	else:
		var idx: PackedInt32Array = indices
		for t in range(0, idx.size() - 2, 3):
			var a: int = idx[t]
			var b: int = idx[t + 1]
			var c: int = idx[t + 2]
			var n2: Vector3 = (verts[c] - verts[a]).cross(verts[b] - verts[a])
			normales[a] += n2
			normales[b] += n2
			normales[c] += n2
	for i in normales.size():
		normales[i] = normales[i].normalized() if normales[i].length() > 0.000001 else Vector3.UP
	arrays[Mesh.ARRAY_NORMAL] = normales


# Deja la carrocería como nueva (taller o kit de reparación).
static func restaurar(raiz: Node3D) -> void:
	if raiz == null or not is_instance_valid(raiz):
		return
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.has_meta("malla_original"):
			mi.mesh = mi.get_meta("malla_original")
			mi.remove_meta("malla_original")
			mi.remove_meta("malla_propia")
			mi.remove_meta("hundido")
		mi.material_override = null


# Cuánto está abollada (0 = nada): suma de lo hundido, para saber si hace falta restaurar.
static func abollado(raiz: Node3D) -> bool:
	if raiz == null or not is_instance_valid(raiz):
		return false
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).has_meta("malla_original"):
			return true
	return false
