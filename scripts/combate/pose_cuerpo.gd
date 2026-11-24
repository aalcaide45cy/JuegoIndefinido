# pose_cuerpo.gd
# -----------------------------------------------------------------------------
# Modificador del esqueleto que se aplica DESPUÉS de la animación y del ragdoll:
#   - "cortes": huesos amputados. Se encogen a casi nada, así que el brazo, la
#     pierna o la cabeza desaparecen del cuerpo justo desde la articulación (y con
#     ellos todo lo que cuelga: dedos, pie, el arma de la mano...).
#   - "fija": pose congelada (hueso -> transformación en el espacio del esqueleto).
#     Sirve para que un cadáver se quede tal como cayó sin gastar física.
# Lo crea y lo maneja Cuerpo (cuerpo.gd); no hace falta tocarlo a mano.
# -----------------------------------------------------------------------------
class_name PoseCuerpo
extends SkeletonModifier3D

const CASI_CERO: Vector3 = Vector3(0.0005, 0.0005, 0.0005)

var cortes: Array[int] = []
var fija: Dictionary = {}          # índice de hueso -> Transform3D (espacio del esqueleto)
var orden_fija: Array[int] = []    # Padres antes que hijos.


func _process_modification() -> void:
	_aplicar()


func _process_modification_with_delta(_delta: float) -> void:
	_aplicar()


func _aplicar() -> void:
	var esq: Skeleton3D = get_skeleton()
	if esq == null:
		return
	for i in orden_fija:
		esq.set_bone_global_pose(i, fija[i])
	for i in cortes:
		if i >= 0 and i < esq.get_bone_count():
			esq.set_bone_pose_scale(i, CASI_CERO)


func fijar(poses: Dictionary) -> void:
	fija = poses
	orden_fija.clear()
	for k in poses.keys():
		orden_fija.append(int(k))
	orden_fija.sort()   # En los modelos importados el padre siempre tiene índice menor.
