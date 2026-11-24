# gestor_fisica.gd
# -----------------------------------------------------------------------------
# Hace que los objetos del escenario (ObjetoFisico) reaccionen a lo que se mueve:
#   - Coches (los que conduces y el tráfico): mira un poco por delante de cada
#     vehículo en marcha y, si va a dar a un objeto, lo despierta y lo lanza con
#     la velocidad del coche. El coche pierde algo de velocidad según lo que
#     pese el objeto, y contra un bolardo se para en seco.
#     Sirve tanto si el chasis es CharacterBody3D (como ahora) como si es un
#     RigidBody3D (lo que prepara el hilo de vehículos): lee la velocidad que haya.
#   - Jugador: puede empujar al andar cajas, conos, papeleras, sillas, barriles...
#   - Bidones que explotan en cadena (FisicaEscenario.pendientes).
# Lo añade mundo.gd. Solo consulta la física cerca de lo que se mueve, así que
# no importa cuántos objetos haya en el mapa.
# -----------------------------------------------------------------------------
class_name GestorFisica
extends Node3D

const MASA_COCHE: float = 1300.0
const DIST_TRAFICO: float = 160.0   # El tráfico de IA solo se mira cerca del jugador.

var _jugador: CharacterBody3D = null
var _mascara_puesta: bool = false
var _vida_urbana: Node = null
var _caja: BoxShape3D = BoxShape3D.new()
var _esfera: SphereShape3D = SphereShape3D.new()
var _consulta: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	name = "GestorFisica"
	_consulta.collision_mask = ObjetoFisico.CAPA
	_esfera.radius = 0.85


func _physics_process(delta: float) -> void:
	FisicaEscenario.procesar_pendientes()
	if not FisicaEscenario.activa:
		return
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as CharacterBody3D
		_mascara_puesta = false
		if _jugador == null:
			return
	# El jugador choca con los objetos (no los atraviesa). Si está volando (máscara 0) se espera.
	if not _mascara_puesta and _jugador.collision_mask != 0:
		_jugador.collision_mask |= ObjetoFisico.CAPA
		_mascara_puesta = true
	_empujar_con_jugador(delta)
	for v in get_tree().get_nodes_in_group("vehiculos"):
		_vehiculo(v as Node3D, delta)
	_trafico(delta)


func _espacio() -> PhysicsDirectSpaceState3D:
	return get_world_3d().direct_space_state


# ----------------------------------------------------------------- jugador ---

func _empujar_con_jugador(delta: float) -> void:
	var vel: Vector3 = _jugador.velocity
	if Vector2(vel.x, vel.z).length() < 0.6:
		return
	var h: Vector3 = Vector3(vel.x, 0, vel.z).normalized()
	_consulta.shape = _esfera
	_consulta.transform = Transform3D(Basis(), _jugador.global_position + Vector3.UP * 0.6 + h * 0.35)
	for r in _espacio().intersect_shape(_consulta, 8):
		var o: ObjetoFisico = r["collider"] as ObjetoFisico
		if o == null:
			continue
		# Solo lo que tienes delante (no lo que dejas atrás al pasar).
		var hacia: Vector3 = o.global_position - _jugador.global_position
		hacia.y = 0.0
		if hacia.length() > 0.01 and hacia.normalized().dot(h) < 0.2:
			continue
		if o.empujable or (not o.anclado and o.mass <= 80.0):
			o.empujar_andando(vel, delta)


# ---------------------------------------------------------------- vehículos ---

static func velocidad_de(veh: Node) -> Vector3:
	if veh == null:
		return Vector3.ZERO
	if veh.has_meta("vel_choque"):
		return veh.get_meta("vel_choque")
	var chasis: Variant = veh.get("chasis") if "chasis" in veh else veh
	if chasis is RigidBody3D:
		return (chasis as RigidBody3D).linear_velocity
	if chasis is CharacterBody3D:
		return (chasis as CharacterBody3D).velocity
	return Vector3.ZERO


func _vehiculo(veh: Node3D, delta: float) -> void:
	if veh == null or not is_instance_valid(veh):
		return
	var vel: Vector3 = velocidad_de(veh)
	if vel.length() < 2.0:
		return
	var chasis: Node3D = veh.get("chasis") as Node3D if "chasis" in veh else veh
	if chasis == null:
		return
	var largo: float = float(veh.get("_largo")) if "_largo" in veh else 4.4
	var ancho: float = float(veh.get("_ancho")) if "_ancho" in veh else 1.9
	var frac: float = _barrer(chasis.global_transform, ancho, largo, vel, delta, veh)
	if frac <= 0.0:
		return
	# Coche de chasis cinemático (CharacterBody3D): le quitamos nosotros la velocidad.
	# Uno de chasis rígido ya pierde velocidad solo al chocar de verdad.
	if "chasis" in veh and veh.get("chasis") is CharacterBody3D and "_v" in veh:
		var v_act: float = float(veh.get("_v"))
		veh.set("_v", v_act * (1.0 - clampf(frac, 0.0, 1.0)))
		if frac >= 1.0 and absf(v_act) > 4.0 and veh.get("conductor") != null:
			Juego.cambiar_vida(-absf(v_act) * 0.6)
			Juego.avisar("¡Te has comido un bolardo!")


# Mira un poco por delante del vehículo y golpea lo que haya. Devuelve la pérdida de velocidad.
func _barrer(xf: Transform3D, ancho: float, largo: float, vel: Vector3, delta: float, veh: Node) -> float:
	var adelanto: Vector3 = vel * clampf(delta * 3.0, 0.02, 0.12)
	_caja.size = Vector3(ancho + 0.3, 1.5, largo + 0.4)
	_consulta.shape = _caja
	_consulta.transform = Transform3D(xf.basis.orthonormalized(), xf.origin + Vector3.UP * 0.85 + adelanto)
	var res: Array = _espacio().intersect_shape(_consulta, 16)
	var frac: float = 0.0
	for r in res:
		var o: ObjetoFisico = r["collider"] as ObjetoFisico
		if o == null:
			continue
		# Solo lo que queda por delante en el sentido de la marcha.
		if (o.global_position - xf.origin).dot(vel) < -0.5:
			continue
		frac = maxf(frac, o.golpe_vehiculo(vel, MASA_COCHE, veh))
	return frac


func _trafico(delta: float) -> void:
	if _vida_urbana == null or not is_instance_valid(_vida_urbana):
		_vida_urbana = null
		for n in get_parent().get_children():
			if n is VidaUrbana:
				_vida_urbana = n
				break
		if _vida_urbana == null:
			return
	var pj: Vector3 = _jugador.global_position
	for a in _vida_urbana.get_children():
		if not ("es_coche" in a) or not bool(a.get("es_coche")):
			continue
		var n3: Node3D = a as Node3D
		if n3 == null or not n3.visible or n3.global_position.distance_squared_to(pj) > DIST_TRAFICO * DIST_TRAFICO:
			continue
		var vel: Vector3
		if a.has_meta("vel_choque"):
			vel = a.get_meta("vel_choque")
		else:
			var d2: Vector2 = a.get("dir2")
			vel = Vector3(d2.x, 0, d2.y) * float(a.get("vel"))
		if vel.length() < 2.0:
			continue
		var largo: float = float(a.get("largo")) if "largo" in a else 4.4
		var frac: float = _barrer(n3.global_transform, 1.9, largo, vel, delta, null)
		if frac > 0.0:
			a.set("vel", float(a.get("vel")) * (1.0 - clampf(frac, 0.0, 1.0)))
