# amortigua_ragdoll.gd
# -----------------------------------------------------------------------------
# Frena el giro de cada hueso del ragdoll respecto a su padre, con impulsos iguales y
# contrarios (el vuelco del cuerpo entero no se toca). Sin esto, manos y antebrazos se
# quedan bamboleando. Idea tomada de Drop-In Ragdoll (MIT, github.com/debugalot/drop-in-ragdoll).
# Lo crea Cuerpo._amortiguar_articulaciones() dentro del PhysicalBoneSimulator3D.
# -----------------------------------------------------------------------------
class_name AmortiguaRagdoll
extends Node

const FUERZA: float = 8.0          # Por segundo: cuánto giro relativo se quita.
const QUIETO: float = 0.6          # m/s: por debajo, el cuerpo se está asentando y frena más.

var pares: Array = []              # [[hijo: PhysicalBone3D, padre: PhysicalBone3D], ...]
var _calma: float = 0.0


func _physics_process(delta: float) -> void:
	var rapido: float = 0.0
	var a: float = 1.0 - exp(-FUERZA * delta)
	for par in pares:
		if not is_instance_valid(par[0]) or not is_instance_valid(par[1]):
			continue   # Miembro cortado: su hueso físico ya no existe.
		var hijo: PhysicalBone3D = par[0]
		var padre: PhysicalBone3D = par[1]
		rapido = maxf(rapido, hijo.linear_velocity.length())
		# Reparte según la masa: el hueso ligero (mano) cede más que el pesado (tronco).
		var mh: float = hijo.mass
		var mp: float = padre.mass
		var rel: Vector3 = (hijo.angular_velocity - padre.angular_velocity) * a
		hijo.angular_velocity -= rel * (mp / (mh + mp))
		padre.angular_velocity += rel * (mh / (mh + mp))
	# Al asentarse, más freno general: brazos y piernas se paran en vez de temblar.
	_calma = _calma + delta if rapido < QUIETO else 0.0
	if _calma > 0.25:
		var m: float = 1.0 + 7.0 * clampf((_calma - 0.25) / 1.0, 0.0, 1.0)
		for par in pares:
			if is_instance_valid(par[0]):
				(par[0] as PhysicalBone3D).linear_damp = 0.08 * m
