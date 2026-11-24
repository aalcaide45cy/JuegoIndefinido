# cuerpo.gd
# -----------------------------------------------------------------------------
# El cuerpo de las personas: dónde te dan, qué pasa y cómo caen.
#
#   Cuerpo.impactar(cosa, desde, dir, dano, tipo, extra)
#       Lo llaman las armas (balas, perdigones, cuchillos, explosiones). Busca la
#       zona exacta del cuerpo por la que pasa la bala usando los HUESOS del
#       modelo (cabeza, torso, brazos, piernas), multiplica el daño (la cabeza
#       mata, los brazos y piernas duelen menos), deja sangre de entrada y de
#       salida, mancha la pared de detrás y, si el golpe tiene energía para ello,
#       arranca el miembro (gore completo). Devuelve un diccionario con lo que ha
#       pasado ({} si no era una persona; {"fallo": true} si la bala pasa rozando
#       entre el brazo y el cuerpo sin tocar nada).
#
#   Cuerpo.al_morir(quien, modelo, dir, fuerza)
#       Ragdoll: el cuerpo cae con física de verdad (huesos con articulaciones),
#       empujado por el último golpe. Si el modelo no tiene esqueleto, el muñeco
#       cae entero como un bloque con física.
#
#   Cuerpo.derribo(quien, modelo, impulso, segundos)
#       Como al_morir pero se puede levantar luego (atropellos y golpes fuertes).
#   Cuerpo.levantar(quien, modelo)       vuelve a ponerlo de pie y animado.
#   Cuerpo.recomponer(quien, modelo)     le devuelve los miembros (al reaparecer).
#
# Rendimiento: como mucho MAX_RAGDOLL cuerpos con física a la vez; los que ya
# han caído se "congelan" a los pocos segundos (se quedan tal cual, sin física).
# Los miembros sueltos y las manchas también tienen tope.
# -----------------------------------------------------------------------------
class_name Cuerpo
extends RefCounted

const CAPA_RESTOS: int = 1 << 9   # Capa 10: cadáveres y miembros. Chocan con el mundo, no con el jugador.
const MAX_RAGDOLL: int = 8
const MAX_MIEMBROS: Array = [0, 0, 14]
const SEGUNDOS_CONGELAR: float = 6.0
const VIDA_MIEMBRO: float = 45.0

# Multiplicador de daño por zona.
const MULT: Dictionary = {
	"cabeza": 3.2, "torso": 1.0, "brazo_i": 0.55, "brazo_d": 0.55, "pierna_i": 0.65, "pierna_d": 0.65,
}
# Energía acumulada que hace falta para arrancar cada parte.
const UMBRAL_CORTE: Dictionary = {"cabeza": 60.0, "brazo": 40.0, "antebrazo": 30.0, "pierna": 60.0, "pantorrilla": 45.0}

# Huesos físicos del ragdoll: [nombre base, hueso al que apunta ("" = largo fijo), radio, masa,
# tipo de articulación, límites]. Cono: [giro lateral (swing), giro sobre sí mismo (twist)].
# Bisagra (rodilla/codo): [mínimo, máximo] en grados; solo dobla hacia donde dobla una persona.
# Los límites son los de un cuerpo de verdad: así cae "como un trapo" sin retorcerse imposible.
# Nombres del rig de Quaternius; se buscan también con sufijo ("Head_2", "Body_2") y con alias.
const RAGDOLL: Array = [
	["Body", "Hips", 0.17, 12.0, "cono", [0.0, 0.0]],
	["Abdomen", "Torso", 0.16, 9.0, "cono", [28.0, 18.0]],
	["Torso", "Neck", 0.19, 13.0, "cono", [24.0, 18.0]],
	["Head", "", 0.15, 5.0, "cono", [48.0, 45.0]],
	["UpperArm.L", "LowerArm.L", 0.075, 2.5, "cono", [85.0, 55.0]],
	["LowerArm.L", "Middle1.L", 0.065, 2.0, "codo", [0.0, 145.0]],
	["UpperArm.R", "LowerArm.R", 0.075, 2.5, "cono", [85.0, 55.0]],
	["LowerArm.R", "Middle1.R", 0.065, 2.0, "codo", [0.0, 145.0]],
	["UpperLeg.L", "LowerLeg.L", 0.1, 7.0, "cono", [60.0, 22.0]],
	["LowerLeg.L", "Foot.L", 0.085, 4.0, "rodilla", [0.0, 140.0]],
	["UpperLeg.R", "LowerLeg.R", 0.1, 7.0, "cono", [60.0, 22.0]],
	["LowerLeg.R", "Foot.R", 0.085, 4.0, "rodilla", [0.0, 140.0]],
]

# Amortiguación de giro: al principio el cuerpo aún tiene "tono muscular" (se dobla, no
# rebota); en menos de un segundo se suelta del todo (como los cuerpos de GTA, que se
# desploman blandos). Un tiro en la cabeza lo suelta al instante.
const TONO_INICIAL: float = 3.0
const TONO_FINAL: float = 0.35
const SEGUNDOS_SOLTAR: float = 0.7
const SIGNO_RODILLA: float = -1.0   # Comprobado con tests/prueba_cuerpo (rodillas y codos doblan hacia el lado bueno).

# Nombres del rig del Toon Shooter -> rig de las personas (estilo Unreal).
const ALIAS_HUESOS: Dictionary = {
	"Body": "pelvis", "Hips": "pelvis", "Abdomen": "spine_01", "Torso": "spine_03", "Neck": "neck_01",
	"UpperArm.L": "upperarm_l", "LowerArm.L": "lowerarm_l", "Middle1.L": "middle_01_l",
	"UpperArm.R": "upperarm_r", "LowerArm.R": "lowerarm_r", "Middle1.R": "middle_01_r",
	"UpperLeg.L": "thigh_l", "LowerLeg.L": "calf_l", "Foot.L": "foot_l",
	"UpperLeg.R": "thigh_r", "LowerLeg.R": "calf_r", "Foot.R": "foot_r",
}

static var _activos: Array = []    # Esqueletos con ragdoll simulando ahora.
static var _miembros: Array = []   # Miembros sueltos (RigidBody3D).
static var _mat_munon: StandardMaterial3D = null


# =============================== Utilidades ===================================

static func esqueleto(modelo: Node) -> Skeleton3D:
	if modelo == null or not is_instance_valid(modelo):
		return null
	if modelo.has_meta("_esq"):
		var e = modelo.get_meta("_esq")
		if is_instance_valid(e):
			return e as Skeleton3D
	var lista: Array = modelo.find_children("*", "Skeleton3D", true, false)
	var esq: Skeleton3D = lista[0] as Skeleton3D if not lista.is_empty() else null
	modelo.set_meta("_esq", esq)
	return esq


# Índice de un hueso por su nombre base (prueba "Head", "Head_2", "Head_3"...). -1 si no está.
static func hueso(esq: Skeleton3D, base: String) -> int:
	if esq == null:
		return -1
	var i: int = esq.find_bone(base)
	if i >= 0:
		return i
	# Esqueleto de las personas (Universal Base Characters / Universal Animation Library).
	if ALIAS_HUESOS.has(base):
		i = esq.find_bone(ALIAS_HUESOS[base])
		if i >= 0:
			return i
	for suf in ["_2", "_1", "_3", "_001"]:
		i = esq.find_bone(base + suf)
		if i >= 0:
			return i
	return -1


# El modelo visible de un personaje (variable "modelo" o "_modelo").
static func modelo_de(quien: Node) -> Node3D:
	if quien == null:
		return null
	for prop in ["modelo", "_modelo"]:
		var m = quien.get(prop)
		if m is Node3D and is_instance_valid(m):
			return m
	return null


# El dueño de un collider: si la bala da a un hueso de un cadáver, el dueño es el personaje.
static func dueno(collider: Object) -> Node:
	if collider == null or not is_instance_valid(collider):
		return null
	if collider is Node and (collider as Node).has_meta("cuerpo_de"):
		var d = (collider as Node).get_meta("cuerpo_de")
		return d if is_instance_valid(d) else null
	return collider as Node


static func es_persona(quien: Node, modelo: Node3D = null) -> bool:
	if quien == null or quien is Vehiculo or quien is VehicleBody3D or quien.get("es_coche") == true:
		return false
	for g in ["peatones", "guardias", "matones", "vecinos", "personas"]:
		if quien.is_in_group(g):
			return true
	if quien.has_meta("persona") or quien.has_method("derribar"):
		return true
	var esq: Skeleton3D = esqueleto(modelo)
	return esq != null and hueso(esq, "Head") >= 0


static func esta_muerto(quien: Node) -> bool:
	if quien == null or not is_instance_valid(quien):
		return true
	if quien.has_meta("muerto"):
		return true
	var m = quien.get("_muerto")
	if m is bool and m:
		return true
	if quien.get("estado") != null and "Estado" in quien:
		var est: Dictionary = quien.Estado
		if est.has("MUERTO") and quien.estado == est["MUERTO"]:
			return true
	return false


static func _global(esq: Skeleton3D, i: int) -> Transform3D:
	return esq.global_transform * esq.get_bone_global_pose(i)


# Pose de todos los huesos tal como se VEN ahora (espacio del esqueleto): con el
# ragdoll o la pose congelada aplicados. get_bone_global_pose() solo da la animación.
static func _poses_reales(esq: Skeleton3D) -> Array:
	var n: int = esq.get_bone_count()
	var r: Array = []
	r.resize(n)
	var fijas: Dictionary = {}
	var pose: PoseCuerpo = null
	for h in esq.get_children():
		if h is PoseCuerpo:
			pose = h
	if pose != null:
		fijas = pose.fija.duplicate()
	var sim: PhysicalBoneSimulator3D = _simulador(esq)
	if sim != null and sim.is_simulating_physics():
		var inv: Transform3D = esq.global_transform.affine_inverse()
		for pb in sim.get_children():
			if pb is PhysicalBone3D and not pb.is_queued_for_deletion():
				var i: int = esq.find_bone((pb as PhysicalBone3D).bone_name)
				if i >= 0:
					fijas[i] = inv * (pb as Node3D).global_transform * (pb as PhysicalBone3D).body_offset.affine_inverse()
	# Padres antes que hijos (los pies colgados de la pierna tienen el padre con índice mayor).
	var pendientes: Array = []
	for i in n:
		pendientes.append(i)
	var vueltas: int = 0
	while not pendientes.is_empty() and vueltas < 8:
		vueltas += 1
		var quedan: Array = []
		for i in pendientes:
			var p: int = esq.get_bone_parent(i)
			if fijas.has(i):
				r[i] = fijas[i]
			elif p < 0:
				r[i] = esq.get_bone_pose(i)
			elif r[p] != null:
				r[i] = (r[p] as Transform3D) * esq.get_bone_pose(i)
			else:
				quedan.append(i)
		pendientes = quedan
	for i in pendientes:
		r[i] = esq.get_bone_global_pose(i)
	return r


static func _punto_hueso(esq: Skeleton3D, i: int) -> Vector3:
	return _global(esq, i).origin


# Punta de una cadena (mano, pie, coronilla) en coordenadas del mundo.
static func _punta(esq: Skeleton3D, base: String) -> Vector3:
	match base:
		"Head":
			var h: int = hueso(esq, "Head")
			var t: Transform3D = _global(esq, h)
			return t.origin + t.basis.y.normalized() * 0.32
		"LowerArm.L", "LowerArm.R", "UpperArm.L", "UpperArm.R":
			var lado: String = base.right(1)
			var dedo: int = hueso(esq, "Middle1." + lado)
			var codo: int = hueso(esq, "LowerArm." + lado)
			if dedo < 0 or codo < 0:
				return _punto_hueso(esq, hueso(esq, base))
			var a: Vector3 = _punto_hueso(esq, codo)
			var b: Vector3 = _punto_hueso(esq, dedo)
			return b + (b - a).normalized() * 0.15
		_:
			var lado2: String = base.right(1)
			var pie: int = hueso(esq, "Foot." + lado2)
			return _punto_hueso(esq, pie) if pie >= 0 else _punto_hueso(esq, hueso(esq, base))


static func _punta_real(esq: Skeleton3D, base: String, poses: Array) -> Vector3:
	var g: Transform3D = esq.global_transform
	var i: int = hueso(esq, base)
	if base == "Head":
		var t: Transform3D = g * (poses[i] as Transform3D)
		return t.origin + t.basis.y.normalized() * 0.32
	var lado: String = base.right(1)
	if base.contains("Arm"):
		var dedo: int = hueso(esq, "Middle1." + lado)
		var codo: int = hueso(esq, "LowerArm." + lado)
		if dedo < 0 or codo < 0:
			return g * (poses[i] as Transform3D).origin
		var a: Vector3 = g * (poses[codo] as Transform3D).origin
		var b: Vector3 = g * (poses[dedo] as Transform3D).origin
		return b + (b - a).normalized() * 0.15
	var pie: int = hueso(esq, "Foot." + lado)
	return g * (poses[pie if pie >= 0 else i] as Transform3D).origin


# Distancia entre una recta (o + d*t, t >= 0) y un segmento [a, b]. Devuelve [distancia, t].
static func _recta_segmento(o: Vector3, d: Vector3, a: Vector3, b: Vector3) -> Array:
	var u: Vector3 = d.normalized()
	var v: Vector3 = b - a
	var w0: Vector3 = o - a
	var bb: float = u.dot(v)
	var cc: float = v.dot(v)
	var dd: float = u.dot(w0)
	var ee: float = v.dot(w0)
	var den: float = cc - bb * bb
	var s: float = 0.0
	if den > 0.000001:
		s = clampf((ee - bb * dd) / den, 0.0, 1.0)
	var t: float = maxf(0.0, (a + v * s - o).dot(u))
	var p_recta: Vector3 = o + u * t
	if cc > 0.000001:
		s = clampf((p_recta - a).dot(v) / cc, 0.0, 1.0)
	return [p_recta.distance_to(a + v * s), t]


# Segmentos del cuerpo para buscar la zona: [zona, hueso a cortar (base), a, b, radio]
static func _segmentos(esq: Skeleton3D) -> Array:
	var s: Array = []
	var cuello: int = hueso(esq, "Neck")
	var cabeza: int = hueso(esq, "Head")
	var cadera: int = hueso(esq, "Hips")
	if cabeza >= 0:
		s.append(["cabeza", "Head", _punto_hueso(esq, cuello if cuello >= 0 else cabeza), _punta(esq, "Head"), 0.16])
	var pelvis: int = hueso(esq, "Body")
	if pelvis < 0:
		pelvis = cadera
	if pelvis >= 0 and cuello >= 0:
		# Del bajo vientre al cuello (el hueso "Hips" de este rig baja hasta las rodillas: no sirve).
		var p0: Vector3 = _punto_hueso(esq, pelvis)
		var p1: Vector3 = _punto_hueso(esq, cuello)
		s.append(["torso", "", p0 + (p0 - p1).normalized() * 0.05, p1, 0.21])
	for lado in ["L", "R"]:
		var z_b: String = "brazo_i" if lado == "L" else "brazo_d"
		var z_p: String = "pierna_i" if lado == "L" else "pierna_d"
		var hb: int = hueso(esq, "UpperArm." + lado)
		var ab: int = hueso(esq, "LowerArm." + lado)
		if hb >= 0 and ab >= 0:
			s.append([z_b, "UpperArm." + lado, _punto_hueso(esq, hb), _punto_hueso(esq, ab), 0.085])
			s.append([z_b, "LowerArm." + lado, _punto_hueso(esq, ab), _punta(esq, "LowerArm." + lado), 0.08])
		var mu: int = hueso(esq, "UpperLeg." + lado)
		var rd: int = hueso(esq, "LowerLeg." + lado)
		if mu >= 0 and rd >= 0:
			s.append([z_p, "UpperLeg." + lado, _punto_hueso(esq, mu), _punto_hueso(esq, rd), 0.12])
			s.append([z_p, "LowerLeg." + lado, _punto_hueso(esq, rd), _punta(esq, "LowerLeg." + lado), 0.1])
	return s


static func _cortados(esq: Skeleton3D) -> Array:
	var r: Array = []
	for h in esq.get_children():
		if h is PoseCuerpo:
			for c in (h as PoseCuerpo).cortes:
				r.append_array(_descendientes(esq, c))
	return r


# Zona por la que pasa un disparo. {"zona", "hueso", "punto", "fallo"}.
static func zona_de(quien: Node3D, modelo: Node3D, desde: Vector3, dir: Vector3, punto_choque: Vector3) -> Dictionary:
	var esq: Skeleton3D = esqueleto(modelo)
	if esq == null or esq.get_bone_count() < 10:
		return _zona_sin_huesos(quien, punto_choque)
	var mejor: Dictionary = {}
	var mejor_d: float = INF
	var cortados: Array = _cortados(esq)
	for seg in _segmentos(esq):
		if seg[1] != "" and cortados.has(hueso(esq, seg[1])):
			continue   # Ese miembro ya no está: la bala pasa por donde estaba.
		var r: Array = _recta_segmento(desde, dir, seg[2], seg[3])
		var holgura: float = float(r[0]) - float(seg[4])
		if holgura < mejor_d:
			mejor_d = holgura
			mejor = {"zona": seg[0], "hueso": seg[1], "punto": desde + dir.normalized() * float(r[1])}
	if mejor.is_empty():
		return _zona_sin_huesos(quien, punto_choque)
	# Pasa a más de 6 cm de cualquier parte: ha pasado rozando sin tocar.
	mejor["fallo"] = mejor_d > 0.06
	return mejor


static func _zona_sin_huesos(quien: Node3D, p: Vector3) -> Dictionary:
	var local: Vector3 = quien.global_transform.affine_inverse() * p
	var zona: String = "torso"
	if local.y > 1.4:
		zona = "cabeza"
	elif local.y < 0.8:
		zona = "pierna_i" if local.x < 0.0 else "pierna_d"
	elif absf(local.x) > 0.24:
		zona = "brazo_i" if local.x < 0.0 else "brazo_d"
	return {"zona": zona, "hueso": "", "punto": p, "fallo": false}


# ============================== Impactos ======================================

# tipo: "bala", "perdigon", "filo", "contundente", "explosion", "atropello".
# extra: {"distancia": m, "fuerza": empuje, "arma": id}
static func impactar(collider: Object, desde: Vector3, dir: Vector3, dano: float, tipo: String,
		extra: Dictionary = {}) -> Dictionary:
	var quien: Node = dueno(collider)
	if quien == null or not quien.has_method("recibir_dano"):
		return {}
	var q3: Node3D = quien as Node3D
	var modelo: Node3D = modelo_de(quien)
	var choque: Vector3 = extra.get("punto", desde + dir.normalized() * desde.distance_to(q3.global_position))
	var info: Dictionary = {}
	if not es_persona(quien, modelo):
		# Coches con física (hilo de vehículos): abollan la chapa y pinchan la rueda donde da.
		if quien.has_method("recibir_impacto") and tipo != "explosion":
			quien.recibir_impacto(choque, dir.normalized(), dano)
		else:
			quien.recibir_dano(dano)
		return {"persona": false}
	if collider is PhysicalBone3D and (collider as Node).has_meta("zona"):
		info = {"zona": (collider as Node).get_meta("zona"), "hueso": (collider as Node).get_meta("base"),
				"punto": choque, "fallo": false}
	elif tipo == "explosion" or tipo == "atropello":
		info = {"zona": "torso", "hueso": "", "punto": q3.global_position + Vector3.UP, "fallo": false}
	else:
		info = zona_de(q3, modelo, desde, dir, choque)
	if info.get("fallo", false) and tipo in ["bala", "perdigon"]:
		return {"persona": true, "fallo": true}
	var zona: String = info["zona"]
	var mult: float = float(MULT.get(zona, 1.0)) if tipo in ["bala", "perdigon", "filo", "contundente"] else 1.0
	if tipo == "perdigon":
		mult *= clampf(1.5 - float(extra.get("distancia", 5.0)) / 14.0, 0.25, 1.5)   # La escopeta pierde fuerza con la distancia.
	var punto: Vector3 = info["punto"]
	quien.set_meta("ult_impacto", {"dir": dir.normalized(), "punto": punto, "tipo": tipo, "zona": zona,
			"fuerza": float(extra.get("fuerza", _empuje(tipo, dano))), "ms": Time.get_ticks_msec()})
	if "dir_golpe" in quien:
		quien.dir_golpe = dir.normalized()
	var muerto_antes: bool = esta_muerto(quien)
	var final: float = dano * mult
	if not muerto_antes:
		quien.recibir_dano(final)
		# Un balazo de verdad en la cabeza no se aguanta (un perdigón lejano sí).
		if zona == "cabeza" and tipo == "bala" and dano >= 15.0 and not esta_muerto(quien):
			quien.recibir_dano(9999.0)
	# Sangre y heridas.
	if tipo != "contundente" or final > 14.0:
		Gore.herida(q3, punto, dir, tipo, clampf(final / 15.0, 0.4, 2.5))
	# Si ya era un cadáver tirado, el disparo lo mueve.
	if muerto_antes:
		_empujar_cadaver(modelo, punto, dir * float(extra.get("fuerza", _empuje(tipo, dano))))
	# ¿Arranca el miembro?
	var resultado: Dictionary = {"persona": true, "zona": zona, "dano": final, "punto": punto,
			"mato": not muerto_antes and esta_muerto(quien), "corte": ""}
	var corte: String = _quizas_cortar(quien, modelo, info, tipo, dano, dir, extra)   # Con el daño del arma, sin el de zona.
	resultado["corte"] = corte
	if corte != "" and not esta_muerto(quien):
		if corte in ["cabeza", "reventar"] or corte.begins_with("UpperLeg") or corte.begins_with("LowerLeg"):
			quien.recibir_dano(9999.0)   # Sin cabeza o sin pierna no sigue en pie.
		else:
			quien.recibir_dano(15.0)
		resultado["mato"] = esta_muerto(quien)
	return resultado


# ¿Este golpe lo tira al suelo? Un tiro en la pierna a veces (se le dobla), un golpe
# muy bruto siempre; un balazo normal en el pecho no: lo encaja y sigue (o huye).
static func debe_caer(quien: Node, cantidad: float, umbral: float = 26.0) -> bool:
	var zona: String = ""
	if reciente(quien, 120):
		zona = String((quien.get_meta("ult_impacto") as Dictionary).get("zona", ""))
	if zona.begins_with("pierna"):
		return cantidad >= 8.0 and randf() < 0.6
	if zona == "" and cantidad >= 14.0:
		return cantidad >= umbral or randf() < 0.35   # Puñetazos y patadas fuertes (sin zona).
	return cantidad >= umbral


# Animación de golpe según dónde le han dado.
static func reaccion(quien: Node) -> String:
	if reciente(quien, 120) and String((quien.get_meta("ult_impacto") as Dictionary).get("zona", "")) == "cabeza":
		return "HitHead"
	return "HitReact"


# true si este golpe acaba de pasar por Cuerpo.impactar (para no poner la sangre dos veces).
# Ejecuta f dentro de s segundos, salvo que el nodo desaparezca antes (va atado a él).
static func luego(nodo: Node, s: float, f: Callable) -> void:
	if nodo == null or not is_instance_valid(nodo) or not nodo.is_inside_tree():
		return
	var t: Tween = nodo.create_tween()
	t.tween_interval(s)
	t.tween_callback(f)


static func reciente(quien: Node, ms: int = 80) -> bool:
	if quien == null or not quien.has_meta("ult_impacto"):
		return false
	return Time.get_ticks_msec() - int((quien.get_meta("ult_impacto") as Dictionary).get("ms", -99999)) <= ms


static func _empuje(tipo: String, dano: float) -> float:
	match tipo:
		"bala":
			# Una bala casi no empuja (en GTA el cuerpo se desploma, no sale volando).
			return clampf(dano / 30.0, 0.8, 2.6)
		"perdigon":
			return 1.6
		"explosion":
			return clampf(dano / 8.0, 4.0, 14.0)
		"atropello":
			return clampf(dano / 3.5, 3.0, 22.0)
		"filo":
			return 1.0
	return 2.0


static func _empujar_cadaver(modelo: Node3D, punto: Vector3, impulso: Vector3) -> void:
	var esq: Skeleton3D = esqueleto(modelo)
	if esq == null:
		return
	var mejor: PhysicalBone3D = null
	var d_mejor: float = INF
	for pb in esq.find_children("*", "PhysicalBone3D", true, false):
		var d: float = (pb as Node3D).global_position.distance_to(punto)
		if d < d_mejor:
			d_mejor = d
			mejor = pb
	if mejor != null:
		mejor.apply_central_impulse(impulso * mejor.mass * 0.6)


# Energía que el golpe puede usar para arrancar un trozo.
static func _energia(tipo: String, dano: float, extra: Dictionary) -> float:
	match tipo:
		"bala":
			return dano * (1.0 if dano >= 28.0 else 0.4)   # Una pistola apenas arranca nada.
		"perdigon":
			return dano * clampf(1.7 - float(extra.get("distancia", 5.0)) / 7.0, 0.0, 1.7)
		"filo":
			return dano * 1.25
		"explosion":
			return dano * 1.3
		"atropello":
			return maxf(0.0, dano - 40.0) * 1.2
	return 0.0


static func _quizas_cortar(quien: Node, modelo: Node3D, info: Dictionary, tipo: String, dano: float,
		dir: Vector3, extra: Dictionary) -> String:
	if Gore.nivel() < 2:
		return ""
	var esq: Skeleton3D = esqueleto(modelo)
	if esq == null:
		return ""
	var e: float = _energia(tipo, dano, extra)
	if e <= 0.0:
		return ""
	# Explosiones y atropellos brutales: pueden arrancar varias partes al azar.
	if tipo == "explosion" or tipo == "atropello":
		var hecho: String = ""
		var opciones: Array = ["UpperArm.L", "UpperArm.R", "LowerLeg.L", "LowerLeg.R", "LowerArm.L", "LowerArm.R", "UpperLeg.L", "UpperLeg.R", "Head"]
		opciones.shuffle()
		var veces: int = clampi(int(e / 45.0), 0, 4)
		for i in veces:
			if randf() < (0.75 if tipo == "explosion" else 0.4):
				var base: String = opciones[i]
				if base == "Head" and e > 110.0:
					desmembrar(quien, modelo, "reventar", dir, e)
					hecho = "reventar"
				else:
					desmembrar(quien, modelo, base, dir, e)
					hecho = base if hecho == "" else hecho
		return hecho
	var base2: String = info.get("hueso", "")
	if base2 == "":
		return ""
	var clave: String = base2
	var acum: Dictionary = quien.get_meta("_herida_miembro", {})
	acum[clave] = float(acum.get(clave, 0.0)) + e
	quien.set_meta("_herida_miembro", acum)
	var umbral: float = UMBRAL_CORTE["cabeza"]
	if base2.begins_with("UpperArm"):
		umbral = UMBRAL_CORTE["brazo"]
	elif base2.begins_with("LowerArm"):
		umbral = UMBRAL_CORTE["antebrazo"]
	elif base2.begins_with("UpperLeg"):
		umbral = UMBRAL_CORTE["pierna"]
	elif base2.begins_with("LowerLeg"):
		umbral = UMBRAL_CORTE["pantorrilla"]
	if float(acum[clave]) < umbral:
		return ""
	if base2 == "Head" and e >= 80.0 and tipo != "filo":
		desmembrar(quien, modelo, "reventar", dir, e)   # Francotirador o escopeta a bocajarro.
		return "reventar"
	desmembrar(quien, modelo, base2, dir, e)
	return "cabeza" if base2 == "Head" else base2


# ============================ Desmembrar ======================================

static func _pose(esq: Skeleton3D) -> PoseCuerpo:
	for h in esq.get_children():
		if h is PoseCuerpo:
			return h
	var p: PoseCuerpo = PoseCuerpo.new()
	p.name = "PoseCuerpo"
	esq.add_child(p)
	return p


static func _mover_al_final(esq: Skeleton3D, nodo: Node) -> void:
	esq.move_child(nodo, esq.get_child_count() - 1)


# Los pies del rig de Quaternius cuelgan de la raíz (IK). Para cortar la pierna o
# hacer ragdoll hay que colgarlos de la pantorrilla, manteniendo donde están.
static func _colgar_pies(esq: Skeleton3D) -> void:
	if esq.has_meta("_pies_colgados"):
		return
	esq.set_meta("_pies_colgados", true)
	var originales: Dictionary = {}
	for lado in ["L", "R"]:
		var pie: int = hueso(esq, "Foot." + lado)
		var pierna: int = hueso(esq, "LowerLeg." + lado)
		if pie < 0 or pierna < 0 or esq.get_bone_parent(pie) == pierna:
			continue
		originales[pie] = esq.get_bone_parent(pie)
		var g_pie: Transform3D = esq.get_bone_global_pose(pie)
		var g_pierna: Transform3D = esq.get_bone_global_pose(pierna)
		esq.set_bone_parent(pie, pierna)
		var local: Transform3D = g_pierna.affine_inverse() * g_pie
		esq.set_bone_pose_position(pie, local.origin)
		esq.set_bone_pose_rotation(pie, local.basis.get_rotation_quaternion())
	esq.set_meta("_pies_padres", originales)


static func _descolgar_pies(esq: Skeleton3D) -> void:
	if not esq.has_meta("_pies_colgados"):
		return
	var originales: Dictionary = esq.get_meta("_pies_padres", {})
	for pie in originales.keys():
		esq.set_bone_parent(int(pie), int(originales[pie]))
	esq.remove_meta("_pies_colgados")


static func _descendientes(esq: Skeleton3D, i: int) -> Array:
	var r: Array = [i]
	var k: int = 0
	while k < r.size():
		for h in esq.get_bone_children(r[k]):
			r.append(h)
		k += 1
	return r


static func _animador(modelo: Node3D) -> AnimationPlayer:
	if modelo.has_meta("animaciones"):
		var a = modelo.get_meta("animaciones")
		if a is AnimationPlayer and is_instance_valid(a):
			return a
	var l: Array = modelo.find_children("*", "AnimationPlayer", true, false)
	return l[0] if not l.is_empty() else null


# base: "Head", "UpperArm.L", "LowerArm.R", "UpperLeg.L", "LowerLeg.R"... o "reventar" (la cabeza estalla).
static func desmembrar(quien: Node, modelo: Node3D, base: String, dir: Vector3, energia: float) -> bool:
	var esq: Skeleton3D = esqueleto(modelo)
	if esq == null or not esq.is_inside_tree():
		return false
	var reventar: bool = base == "reventar"
	var nombre: String = "Head" if reventar else base
	var i: int = hueso(esq, nombre)
	if i < 0:
		return false
	var pose: PoseCuerpo = _pose(esq)
	if pose.cortes.has(i):
		return false
	for c in pose.cortes:   # Si ya se cortó un hueso padre, este ya no está.
		if _descendientes(esq, c).has(i):
			return false
	if nombre.contains("Leg"):
		_colgar_pies(esq)
	var g_corte: Transform3D = esq.global_transform * (_poses_reales(esq)[i] as Transform3D)
	var raiz: Node = _raiz(esq)
	# 1) El trozo que sale volando (copia del modelo en la que solo queda ese miembro).
	if not reventar:
		_soltar_miembro(esq, modelo, i, nombre, dir, energia, raiz)
	# 2) Quitarlo del cuerpo (y del ragdoll, si está cayendo).
	pose.cortes.append(i)
	_mover_al_final(esq, pose)
	var quitar: Array = _descendientes(esq, i)
	for pb in esq.find_children("*", "PhysicalBone3D", true, false):
		var bi: int = esq.find_bone((pb as PhysicalBone3D).bone_name)
		if quitar.has(bi):
			pb.queue_free()
	# 3) Muñón y chorro.
	_munon(esq, i, g_corte, dir)
	var en_mundo: Vector3 = g_corte.origin
	if reventar:
		Gore.reventar(esq, en_mundo + g_corte.basis.y.normalized() * 0.12, dir)
	else:
		Gore.salpicar(esq, en_mundo, dir + Vector3.UP * 0.4, 2.2)
	Gore.crujido(esq, en_mundo, reventar)
	quien.set_meta("mutilado", true)
	return true


static func _raiz(n: Node) -> Node:
	var t: SceneTree = n.get_tree()
	return t.current_scene if t.current_scene != null else t.root


static func _material_munon() -> StandardMaterial3D:
	if _mat_munon == null:
		_mat_munon = StandardMaterial3D.new()
		_mat_munon.albedo_color = Color(0.45, 0.02, 0.03)
		_mat_munon.roughness = 0.25
	return _mat_munon


# Muñón rojo en la articulación del cuerpo, con chorro de sangre que late unos segundos.
static func _munon(esq: Skeleton3D, i: int, g_corte: Transform3D, dir: Vector3) -> void:
	var padre: int = esq.get_bone_parent(i)
	if padre < 0:
		return
	var anclaje: BoneAttachment3D = BoneAttachment3D.new()
	anclaje.bone_name = esq.get_bone_name(padre)
	anclaje.set_meta("_munon", true)
	esq.add_child(anclaje)
	var local: Vector3 = esq.get_bone_rest(i).origin
	var bola: MeshInstance3D = MeshInstance3D.new()
	var esfera: SphereMesh = SphereMesh.new()
	var r: float = 0.08 if esq.get_bone_name(i).begins_with("Head") else 0.065
	esfera.radius = r
	esfera.height = r * 1.6
	esfera.radial_segments = 8
	esfera.rings = 4
	esfera.material = _material_munon()
	bola.mesh = esfera
	anclaje.add_child(bola)
	bola.position = local
	if Gore.nivel() < 2:
		return
	var chorro: CPUParticles3D = Gore.chorro()
	anclaje.add_child(chorro)
	chorro.position = local
	chorro.direction = local.normalized() if local.length() > 0.01 else Vector3.UP
	chorro.emitting = true
	var t: Tween = chorro.create_tween()
	for k in 6:   # Late como un corazón y se va apagando.
		t.tween_property(chorro, "initial_velocity_max", 3.2 - k * 0.4, 0.12)
		t.tween_property(chorro, "initial_velocity_max", 1.0, 0.45)
	t.tween_callback(func() -> void: chorro.emitting = false)
	t.tween_interval(1.0)
	t.tween_callback(chorro.queue_free)


# Copia el modelo entero y en la copia deja solo el miembro cortado; la mete en un
# cuerpo con física y la lanza. Así el brazo que vuela es el brazo de verdad (con
# su manga, su guante y hasta el arma que llevaba en la mano).
static func _soltar_miembro(esq: Skeleton3D, modelo: Node3D, i: int, nombre: String, dir: Vector3,
		energia: float, raiz: Node) -> void:
	var tope: int = int(MAX_MIEMBROS[Gore.nivel()])
	if tope <= 0:
		return
	var poses_globales: Array = _poses_reales(esq)
	var g_corte: Transform3D = esq.global_transform * (poses_globales[i] as Transform3D)
	var punta: Vector3 = _punta_real(esq, nombre, poses_globales)
	var copia: Node3D = modelo.duplicate() as Node3D
	for anim in copia.find_children("*", "AnimationPlayer", true, false):
		anim.queue_free()
	for basura in copia.find_children("*", "PoseCuerpo", true, false):
		basura.free()
	for basura2 in copia.find_children("*", "PhysicalBoneSimulator3D", true, false):
		basura2.free()
	for basura3 in copia.find_children("*", "CPUParticles3D", true, false):
		basura3.free()
	for barra in copia.find_children("*", "Label3D", true, false):
		barra.free()
	var ce: Skeleton3D = esqueleto(copia)
	copia.remove_meta("_esq")
	ce = esqueleto(copia)
	if ce == null:
		copia.free()
		return
	# Las mismas conexiones de huesos (pies colgados de la pierna, si se hizo).
	for k in ce.get_bone_count():
		if ce.get_bone_parent(k) != esq.get_bone_parent(k):
			ce.set_bone_parent(k, esq.get_bone_parent(k))
	# El miembro pasa a ser raíz y conserva su sitio; todo lo demás se encoge a nada.
	ce.set_bone_parent(i, -1)
	var mantener: Array = _descendientes(ce, i)
	for k in ce.get_bone_count():
		var g: Transform3D = poses_globales[k]
		var p: int = ce.get_bone_parent(k)
		var local: Transform3D = g if p < 0 else (poses_globales[p] as Transform3D).affine_inverse() * g
		ce.set_bone_pose_position(k, local.origin)
		ce.set_bone_pose_rotation(k, local.basis.get_rotation_quaternion())
		ce.set_bone_pose_scale(k, Vector3.ONE)
	var pc: PoseCuerpo = PoseCuerpo.new()
	for k in ce.get_bone_count():
		if ce.get_bone_parent(k) < 0 and not mantener.has(k):
			pc.cortes.append(k)
	ce.add_child(pc)
	# Cuerpo físico.
	var rb: RigidBody3D = RigidBody3D.new()
	rb.collision_layer = CAPA_RESTOS
	rb.collision_mask = 1
	rb.mass = 3.0 if nombre.contains("Leg") else (4.5 if nombre == "Head" else 2.0)
	rb.angular_damp = 1.0
	rb.linear_damp = 0.1
	var a: Vector3 = g_corte.origin
	var largo: float = maxf(0.15, a.distance_to(punta))
	var forma: CollisionShape3D = CollisionShape3D.new()
	var capsula: CapsuleShape3D = CapsuleShape3D.new()
	capsula.radius = 0.11 if nombre == "Head" else 0.07
	capsula.height = maxf(largo, capsula.radius * 2.0 + 0.01)
	forma.shape = capsula
	rb.add_child(forma)
	raiz.add_child(rb)
	var centro: Vector3 = (a + punta) * 0.5
	rb.global_position = centro
	var eje: Vector3 = (punta - a).normalized()
	if eje.length() > 0.5:
		forma.global_basis = Basis(Quaternion(Vector3.UP, eje))
	var t_modelo: Transform3D = modelo.global_transform
	rb.add_child(copia)
	copia.global_transform = t_modelo
	var tapa: MeshInstance3D = MeshInstance3D.new()   # Carne roja en el extremo cortado.
	var esf: SphereMesh = SphereMesh.new()
	esf.radius = 0.075 if nombre == "Head" else 0.06
	esf.height = esf.radius * 1.5
	esf.radial_segments = 8
	esf.rings = 4
	esf.material = _material_munon()
	tapa.mesh = esf
	rb.add_child(tapa)
	tapa.global_position = a
	rb.set_meta("miembro", nombre)
	var empuje: float = clampf(energia / 20.0, 2.0, 9.0)
	rb.linear_velocity = dir.normalized() * empuje + Vector3.UP * randf_range(1.5, 3.5) \
			+ Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	rb.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
	# Va dejando un reguero de gotas.
	var gotas: CPUParticles3D = Gore.chorro()
	gotas.amount = 12
	gotas.initial_velocity_max = 0.6
	rb.add_child(gotas)
	gotas.global_position = a
	gotas.emitting = true
	luego(gotas, 2.5, func() -> void: gotas.emitting = false)
	# Al caer al suelo, una mancha.
	luego(rb, 1.6, func() -> void: Gore.charco(rb, rb.global_position, 0.35))
	_miembros.append(rb)
	rb.get_tree().create_timer(45.0).timeout.connect(rb.queue_free)
	while _miembros.size() > tope:
		var viejo = _miembros.pop_front()
		if is_instance_valid(viejo):
			viejo.queue_free()


# ================================ Ragdoll =====================================

# Muerte: cae con física, empujado por el último golpe (si fue hace poco) o por "dir".
static func al_morir(quien: Node3D, modelo: Node3D, dir: Vector3 = Vector3.ZERO, fuerza: float = 2.0) -> bool:
	if quien == null or not quien.is_inside_tree():
		return false
	var impulso: Vector3 = _impulso_reciente(quien, dir, fuerza)
	if modelo == null:
		modelo = _agrupar_visual(quien)   # Muñeco de piezas sueltas: se juntan y caen como un bloque.
	var ok: bool = ragdoll(quien, modelo, impulso, true)
	var m: Node3D = modelo
	luego(quien, 1.8, func() -> void: Gore.charco(quien, centro(quien, m), 0.8 + clampf(fuerza, 0.0, 3.0) * 0.2))
	return ok


static func _impulso_reciente(quien: Node, dir: Vector3, fuerza: float) -> Vector3:
	var ult: Dictionary = quien.get_meta("ult_impacto", {}) if quien.has_meta("ult_impacto") else {}
	if not ult.is_empty() and Time.get_ticks_msec() - int(ult.get("ms", 0)) < 400:
		return (ult["dir"] as Vector3) * float(ult.get("fuerza", fuerza))
	var d: Vector3 = dir
	if d.length() < 0.01:
		d = -(quien as Node3D).global_basis.z
	return d.normalized() * fuerza


# Centro del cuerpo ahora (la pelvis si está cayendo), en el mundo.
static func centro(quien: Node3D, modelo: Node3D) -> Vector3:
	var esq: Skeleton3D = esqueleto(modelo)
	if esq != null:
		for pb in esq.find_children("*", "PhysicalBone3D", true, false):
			if (pb as PhysicalBone3D).bone_name.begins_with("Body"):
				return (pb as Node3D).global_position
		var b: int = hueso(esq, "Body")
		if b >= 0:
			return esq.global_transform * (_poses_reales(esq)[b] as Transform3D).origin
	if modelo != null and modelo.has_meta("_rigido"):
		var r = modelo.get_meta("_rigido")
		if is_instance_valid(r):
			return (r as Node3D).global_position
	return quien.global_position


# Derribo con posibilidad de levantarse.
static func derribo(quien: Node3D, modelo: Node3D, impulso: Vector3) -> bool:
	return ragdoll(quien, modelo, impulso, false)


static func ragdoll(quien: Node3D, modelo: Node3D, impulso: Vector3, muerte: bool) -> bool:
	if modelo == null or not is_instance_valid(modelo) or not modelo.is_inside_tree():
		return false
	var esq: Skeleton3D = esqueleto(modelo)
	if esq == null or hueso(esq, "Body") < 0 or hueso(esq, "Torso") < 0:
		return _caida_rigida(quien, modelo, impulso)
	var sim: PhysicalBoneSimulator3D = _simulador(esq)
	if sim != null and sim.is_simulating_physics():
		# Ya está en el suelo: solo se le empuja.
		for pb in sim.get_children():
			if pb is PhysicalBone3D:
				pb.apply_central_impulse(impulso * (pb as PhysicalBone3D).mass * 0.5)
		return true
	var anim: AnimationPlayer = _animador(modelo)
	if anim != null:
		anim.pause()
	_colgar_pies(esq)
	if sim == null:
		sim = _construir_ragdoll(esq, quien)
	var pose: PoseCuerpo = _pose(esq)
	pose.fijar({})
	_mover_al_final(esq, pose)
	sim.active = true
	sim.physical_bones_start_simulation()
	_amortiguar_articulaciones(esq, sim)
	# Como en GTA: el cuerpo sigue con la inercia que llevaba (si corría, sigue hacia
	# delante), el golpe se aplica en el hueso tocado y en el punto exacto (un tiro en el
	# hombro lo hace girar), y los músculos se sueltan poco a poco (se desploma doblando
	# rodillas, no cae como una tabla).
	var inercia: Vector3 = Vector3.ZERO
	if "velocity" in quien:
		inercia = quien.velocity
		inercia.y = maxf(inercia.y, -2.0)
	var ult: Dictionary = quien.get_meta("ult_impacto", {}) if quien.has_meta("ult_impacto") else {}
	var reciente_golpe: bool = not ult.is_empty() and Time.get_ticks_msec() - int(ult.get("ms", 0)) < 400
	var zona_golpe: String = String(ult.get("zona", "")) if reciente_golpe else ""
	var punto_golpe: Vector3 = ult.get("punto", Vector3.ZERO) if reciente_golpe else Vector3.ZERO
	var tocado: PhysicalBone3D = null
	var mejor: float = 0.45
	for pb in sim.get_children():
		if not pb is PhysicalBone3D:
			continue
		var b: PhysicalBone3D = pb
		# El tronco se lleva el golpe; las piernas casi no (los pies se quedan y el cuerpo se dobla).
		var nb: String = b.bone_name
		var peso: float = 0.7
		if nb.begins_with("Torso") or nb.begins_with("Abdomen") or nb.begins_with("spine") or nb.begins_with("Head") or nb.begins_with("neck"):
			peso = 1.0
		elif nb.contains("Leg") or nb.begins_with("thigh") or nb.begins_with("calf"):
			peso = 0.25 if muerte and reciente_golpe and String(ult.get("tipo", "")) in ["bala", "perdigon", "filo", "contundente"] else 0.6
		b.linear_velocity = inercia * (0.8 if peso < 0.5 else 1.0) + impulso * peso
		b.angular_velocity = Vector3.ZERO
		if impulso.length() > 6.0:
			b.linear_velocity += Vector3.UP * clampf(impulso.length() * 0.25, 0.0, 5.0)
		if reciente_golpe:
			var d: float = b.global_position.distance_to(punto_golpe)
			if d < mejor:
				mejor = d
				tocado = b
	if tocado != null and impulso.length() > 0.5:
		# El hueso tocado recibe un empujón extra justo donde entró la bala: gira y arrastra al resto.
		tocado.apply_impulse(impulso * tocado.mass * 0.6, punto_golpe - tocado.global_position)
	elif impulso.length() > 0.5:
		# Sin punto (atropello, explosión): las piernas se quedan atrás y el cuerpo vuelca.
		for pb in sim.get_children():
			if pb is PhysicalBone3D and ((pb as PhysicalBone3D).bone_name.contains("Leg") or (pb as PhysicalBone3D).bone_name.begins_with("thigh") or (pb as PhysicalBone3D).bone_name.begins_with("calf")):
				(pb as PhysicalBone3D).linear_velocity = inercia + impulso * 0.45
	_soltar_musculos(esq, sim, 0.05 if zona_golpe == "cabeza" else SEGUNDOS_SOLTAR)
	esq.set_meta("_ragdoll_ms", Time.get_ticks_msec())
	esq.set_meta("_ragdoll_muerte", muerte)
	_activos.erase(esq)
	_activos.append(esq)
	while _activos.size() > MAX_RAGDOLL:
		var viejo = _activos.pop_front()
		if is_instance_valid(viejo):
			congelar(viejo)
	var id: int = int(esq.get_meta("_ragdoll_id", 0)) + 1
	esq.set_meta("_ragdoll_id", id)
	if muerte:
		_vigilar_reposo(esq, id, 0)
	return true


# Amortiguación entre cada hueso y su padre (idea de Drop-In Ragdoll, MIT): frena que un
# antebrazo o una mano se queden bailando sin frenar el vuelco del cuerpo entero.
static func _amortiguar_articulaciones(esq: Skeleton3D, sim: PhysicalBoneSimulator3D) -> void:
	for h in sim.get_children():
		if h is AmortiguaRagdoll:
			h.queue_free()
	var por_hueso: Dictionary = {}
	for pb in sim.get_children():
		if pb is PhysicalBone3D:
			por_hueso[esq.find_bone((pb as PhysicalBone3D).bone_name)] = pb
	var pares: Array = []
	for i in por_hueso:
		var p: int = esq.get_bone_parent(i)
		while p >= 0 and not por_hueso.has(p):
			p = esq.get_bone_parent(p)
		if p >= 0:
			pares.append([por_hueso[i], por_hueso[p]])
	var am: AmortiguaRagdoll = AmortiguaRagdoll.new()
	am.name = "Amortigua"
	am.pares = pares
	sim.add_child(am)


# Los músculos se sueltan: la amortiguación de giro baja de TONO_INICIAL a TONO_FINAL.
static func _soltar_musculos(esq: Skeleton3D, sim: PhysicalBoneSimulator3D, segundos: float) -> void:
	var huesos: Array = []
	for pb in sim.get_children():
		if pb is PhysicalBone3D:
			huesos.append(pb)
			(pb as PhysicalBone3D).angular_damp = TONO_INICIAL if segundos > 0.1 else TONO_FINAL
	if segundos <= 0.1:
		return
	var tw: Tween = esq.create_tween()
	tw.tween_method(func(v: float) -> void:
		for h in huesos:
			if is_instance_valid(h):
				(h as PhysicalBone3D).angular_damp = v, TONO_INICIAL, TONO_FINAL, segundos).set_ease(Tween.EASE_OUT)


# Se congela cuando el cuerpo ya está quieto (o, como mucho, a los SEGUNDOS_CONGELAR + 4 s).
static func _vigilar_reposo(esq: Skeleton3D, id: int, vueltas: int) -> void:
	luego(esq, 1.0 if vueltas > 0 else 2.5, func() -> void:
		if int(esq.get_meta("_ragdoll_id", 0)) != id:
			return
		var sim: PhysicalBoneSimulator3D = _simulador(esq)
		if sim == null:
			return
		var max_v: float = 0.0
		for pb in sim.get_children():
			if pb is PhysicalBone3D:
				max_v = maxf(max_v, (pb as PhysicalBone3D).linear_velocity.length())
		if max_v < 0.12 or vueltas >= int(SEGUNDOS_CONGELAR) + 2:
			congelar(esq)
		else:
			_vigilar_reposo(esq, id, vueltas + 1))


static func _simulador(esq: Skeleton3D) -> PhysicalBoneSimulator3D:
	for h in esq.get_children():
		if h is PhysicalBoneSimulator3D and not h.is_queued_for_deletion():
			return h
	return null


static func _construir_ragdoll(esq: Skeleton3D, quien: Node) -> PhysicalBoneSimulator3D:
	var sim: PhysicalBoneSimulator3D = PhysicalBoneSimulator3D.new()
	sim.name = "Ragdoll"
	esq.add_child(sim)
	var cortados: Array = []
	var pose: PoseCuerpo = _pose(esq)
	for c in pose.cortes:
		cortados.append_array(_descendientes(esq, c))
	for def in RAGDOLL:
		var i: int = hueso(esq, def[0])
		if i < 0 or cortados.has(i):
			continue
		var objetivo: int = hueso(esq, def[1]) if def[1] != "" else -1
		if objetivo == i:
			objetivo = hueso(esq, "Abdomen")   # En el rig de personas "Hips" y "Body" son el mismo hueso.
		# Punto al que apunta el hueso, en su propio espacio (con la pose de reposo).
		var punta_local: Vector3 = Vector3(0, 0.3, 0)
		if objetivo >= 0:
			punta_local = esq.get_bone_global_rest(i).affine_inverse() * esq.get_bone_global_rest(objetivo).origin
			if String(def[0]).begins_with("LowerArm"):
				punta_local *= 1.3   # Hasta la punta de los dedos.
		var largo: float = maxf(punta_local.length(), 0.12)
		var mitad: float = largo * 0.5
		var pb: PhysicalBone3D = PhysicalBone3D.new()
		pb.bone_name = esq.get_bone_name(i)
		pb.name = "PB_" + pb.bone_name
		pb.mass = float(def[3])
		pb.friction = 0.9
		pb.bounce = 0.0
		pb.linear_damp = 0.08
		pb.angular_damp = TONO_INICIAL
		pb.collision_layer = CAPA_RESTOS
		pb.collision_mask = 1
		var forma: CollisionShape3D = CollisionShape3D.new()
		var capsula: CapsuleShape3D = CapsuleShape3D.new()
		capsula.radius = float(def[2])
		capsula.height = maxf(largo, float(def[2]) * 2.0 + 0.02)
		forma.shape = capsula
		forma.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3.ZERO)
		pb.add_child(forma)
		var b_off: Transform3D = Transform3D()
		b_off.basis = Basis.looking_at(punta_local.normalized() if punta_local.length() > 0.001 else Vector3.UP,
				Vector3.FORWARD if absf(punta_local.normalized().y) > 0.95 else Vector3.UP)
		b_off.origin = b_off.basis * Vector3(0, 0, -mitad)
		pb.body_offset = b_off
		pb.joint_offset = Transform3D(Basis(), Vector3(0, 0, mitad))
		_articulacion(pb, esq, i, b_off, String(def[4]), def[5], punta_local)
		var zona: String = "torso"
		var nb: String = String(def[0])
		if nb == "Head":
			zona = "cabeza"
		elif nb.contains("Arm"):
			zona = "brazo_i" if nb.ends_with("L") else "brazo_d"
		elif nb.contains("Leg"):
			zona = "pierna_i" if nb.ends_with("L") else "pierna_d"
		pb.set_meta("cuerpo_de", quien)
		pb.set_meta("zona", zona)
		pb.set_meta("base", "" if zona == "torso" else nb)
		sim.add_child(pb)
	return sim


# Articulación con los ejes bien puestos. En Godot el cono gira sobre su eje X y la
# bisagra sobre su eje Z, así que: X a lo largo del hueso (hacia el padre) y, en rodillas
# y codos, Z hacia el costado del personaje. Antes los ejes iban cruzados y las rodillas
# de las personas no doblaban (caían tiesas) y en los muñecos doblaban al revés.
static func _articulacion(pb: PhysicalBone3D, esq: Skeleton3D, i: int, b_off: Transform3D, tipo: String, lim: Array, punta_local: Vector3 = Vector3.ZERO) -> void:
	var eje: Vector3 = Vector3(0, 0, 1)   # Del cuerpo físico hacia su articulación (el padre).
	if tipo == "cono":
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		pb.joint_rotation = Vector3.ZERO
		pb.joint_offset = Transform3D(Basis(eje, Vector3(0, 1, 0), Vector3(-1, 0, 0)), pb.joint_offset.origin)
		pb.set("joint_constraints/swing_span", float(lim[0]))
		pb.set("joint_constraints/twist_span", float(lim[1]))
		pb.set("joint_constraints/softness", 0.8)
		pb.set("joint_constraints/relaxation", 1.0)
		return
	# Eje de la bisagra = hueso x hacia dónde dobla (el codo lleva la mano hacia delante,
	# la rodilla lleva el pie hacia atrás). Todo en la pose de reposo del esqueleto.
	var dcha: Vector3 = Vector3.RIGHT
	var cl: int = hueso(esq, "UpperLeg.L")
	var cr: int = hueso(esq, "UpperLeg.R")
	if cl >= 0 and cr >= 0:
		dcha = (esq.get_bone_global_rest(cr).origin - esq.get_bone_global_rest(cl).origin).normalized()
	var arriba: Vector3 = Vector3.UP
	var pel: int = hueso(esq, "Body")
	var cue: int = hueso(esq, "Neck")
	if pel >= 0 and cue >= 0:
		arriba = (esq.get_bone_global_rest(cue).origin - esq.get_bone_global_rest(pel).origin).normalized()
	var delante: Vector3 = arriba.cross(dcha).normalized()
	var dobla: Vector3 = -delante if tipo == "rodilla" else delante
	var g: Transform3D = esq.get_bone_global_rest(i) * b_off
	var dir_hueso: Vector3 = (g.basis * Vector3(0, 0, -1)).normalized()
	var eje_s: Vector3 = dir_hueso.cross(dobla)
	if eje_s.length() < 0.2:
		eje_s = dcha
	var lat: Vector3 = g.basis.inverse() * eje_s.normalized()
	lat = (lat - eje * lat.dot(eje)).normalized()
	pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
	pb.joint_offset = Transform3D(Basis(eje, lat.cross(eje), lat), pb.joint_offset.origin)
	# Los límites se miden desde la pose en la que empieza a caer (como explica Drop-In
	# Ragdoll): si el codo ya iba doblado 40°, solo le quedan 105° más y 40° hasta recto.
	var doblez: float = 0.0
	var padre: int = esq.get_bone_parent(i)
	if padre >= 0 and punta_local.length() > 0.01:
		var poses: Array = _poses_reales(esq)
		var gi: Transform3D = poses[i]
		var arriba_l: Vector3 = (gi.origin - (poses[padre] as Transform3D).origin)
		var abajo_l: Vector3 = (gi * punta_local) - gi.origin
		if arriba_l.length() > 0.01 and abajo_l.length() > 0.01:
			doblez = clampf(rad_to_deg(arriba_l.angle_to(abajo_l)), 0.0, float(lim[1]) - 10.0)
	var a: float = (float(lim[0]) - doblez) * SIGNO_RODILLA
	var b: float = (float(lim[1]) - doblez) * SIGNO_RODILLA
	pb.set("joint_constraints/angular_limit_enabled", true)
	pb.set("joint_constraints/angular_limit_lower", minf(a, b))
	pb.set("joint_constraints/angular_limit_upper", maxf(a, b))
	pb.set("joint_constraints/angular_limit_softness", 0.9)
	pb.set("joint_constraints/angular_limit_relaxation", 1.0)


# Onda expansiva: empuja cadáveres que están cayendo y miembros sueltos.
static func onda(pos: Vector3, radio: float, fuerza: float) -> void:
	for esq in _activos.duplicate():
		if not is_instance_valid(esq):
			continue
		for pb in (esq as Node).find_children("*", "PhysicalBone3D", true, false):
			var d: Vector3 = (pb as Node3D).global_position - pos
			if d.length() < radio:
				(pb as PhysicalBone3D).apply_central_impulse((d.normalized() + Vector3.UP * 0.5) * fuerza * (1.0 - d.length() / radio) * (pb as PhysicalBone3D).mass)
	for m in _miembros:
		if is_instance_valid(m):
			var d2: Vector3 = (m as Node3D).global_position - pos
			if d2.length() < radio:
				(m as RigidBody3D).apply_central_impulse((d2.normalized() + Vector3.UP * 0.5) * fuerza * (m as RigidBody3D).mass)


# Deja el cuerpo quieto tal como está, sin física (para no gastar).
static func congelar(esq: Skeleton3D) -> void:
	_activos.erase(esq)
	if not is_instance_valid(esq) or not esq.is_inside_tree():
		return
	var sim: PhysicalBoneSimulator3D = _simulador(esq)
	if sim == null:
		return
	var poses: Dictionary = {}
	var inv: Transform3D = esq.global_transform.affine_inverse()
	for pb in sim.get_children():
		if not pb is PhysicalBone3D or pb.is_queued_for_deletion():
			continue
		var b: PhysicalBone3D = pb
		var i: int = esq.find_bone(b.bone_name)
		if i >= 0:
			poses[i] = inv * b.global_transform * b.body_offset.affine_inverse()
	sim.physical_bones_stop_simulation()
	sim.active = false
	var pose: PoseCuerpo = _pose(esq)
	pose.fijar(poses)
	_mover_al_final(esq, pose)
	esq.set_meta("_ragdoll_ms", 0)
	sim.queue_free()


# Se levanta: fuera física, vuelve a la animación.
static func levantar(quien: Node3D, modelo: Node3D, animacion: String = "Walk") -> void:
	if modelo == null or not is_instance_valid(modelo):
		return
	if modelo.has_meta("_rigido"):
		_deshacer_rigida(modelo)
		return
	var esq: Skeleton3D = esqueleto(modelo)
	if esq == null:
		return
	_activos.erase(esq)
	var sim: PhysicalBoneSimulator3D = _simulador(esq)
	if sim != null:
		sim.physical_bones_stop_simulation()
		sim.active = false
		sim.queue_free()
	var pose: PoseCuerpo = _pose(esq)
	pose.fijar({})
	esq.set_meta("_ragdoll_ms", 0)
	_descolgar_pies(esq)
	var anim: AnimationPlayer = _animador(modelo)
	if anim != null:
		anim.play()
	Assets.poner_animacion(modelo, animacion)
	quien.set_meta("levantado_ms", Time.get_ticks_msec())


# Vuelve a tener todos los miembros y queda de pie (para guardias que reaparecen).
static func recomponer(quien: Node3D, modelo: Node3D) -> void:
	levantar(quien, modelo, "Idle")
	var esq: Skeleton3D = esqueleto(modelo)
	if esq == null:
		return
	var pose: PoseCuerpo = _pose(esq)
	pose.cortes.clear()
	for h in esq.get_children():
		if h is BoneAttachment3D and h.has_meta("_munon"):
			h.queue_free()
	quien.remove_meta("mutilado")
	quien.remove_meta("_herida_miembro")


static func _agrupar_visual(quien: Node3D) -> Node3D:
	var grupo: Node3D = Node3D.new()
	grupo.name = "MunecoCaido"
	quien.add_child(grupo)
	var piezas: int = 0
	for h in quien.get_children():
		if h != grupo and h is GeometryInstance3D and not h is Label3D:
			(h as Node3D).reparent(grupo, true)
			piezas += 1
	if piezas == 0:
		grupo.queue_free()
		return null
	return grupo


# Muñeco sin huesos: cae entero como un bloque con física.
static func _caida_rigida(quien: Node3D, visual: Node3D, impulso: Vector3) -> bool:
	if visual == null or visual.has_meta("_rigido"):
		return false
	var rb: RigidBody3D = RigidBody3D.new()
	rb.collision_layer = CAPA_RESTOS
	rb.collision_mask = 1
	rb.mass = 70.0
	rb.angular_damp = 0.6
	var forma: CollisionShape3D = CollisionShape3D.new()
	var caja: BoxShape3D = BoxShape3D.new()
	caja.size = Vector3(0.5, 1.7, 0.32)
	forma.shape = caja
	forma.position.y = 0.85
	rb.add_child(forma)
	var padre: Node = visual.get_parent()
	var t: Transform3D = visual.global_transform
	_raiz(quien).add_child(rb)
	rb.global_transform = Transform3D(Basis(Vector3.UP, quien.global_rotation.y), quien.global_position + Vector3.UP * 0.02)
	visual.reparent(rb, true)
	visual.global_transform = t
	rb.linear_velocity = impulso
	var lado: Vector3 = impulso.cross(Vector3.UP)
	if lado.length() < 0.01:
		lado = rb.global_basis.x
	rb.angular_velocity = -lado.normalized() * clampf(impulso.length() * 0.6, 1.5, 6.0)
	visual.set_meta("_rigido", rb)
	visual.set_meta("_padre_antes", padre)
	visual.set_meta("_t_local_antes", padre.global_transform.affine_inverse() * t if padre is Node3D else Transform3D())
	# Si el personaje desaparece, el muñeco caído también.
	quien.tree_exiting.connect(func() -> void:
		if is_instance_valid(rb):
			rb.queue_free())
	return true


static func _deshacer_rigida(visual: Node3D) -> void:
	var rb = visual.get_meta("_rigido")
	var padre = visual.get_meta("_padre_antes")
	if is_instance_valid(padre):
		visual.reparent(padre, false)
		visual.transform = visual.get_meta("_t_local_antes", Transform3D())
	visual.remove_meta("_rigido")
	if is_instance_valid(rb):
		rb.queue_free()
