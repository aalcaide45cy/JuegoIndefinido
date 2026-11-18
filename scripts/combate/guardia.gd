# guardia.gd
# -----------------------------------------------------------------------------
# Un guardia del Prefecto. De noche patrulla su ruta; si te ve con algo ilegal
# (pociones, hierbas, armas de fuego o explosivos en el inventario) te persigue
# y te golpea. De día no sale. Se le puede dañar con cualquier arma; si cae,
# vuelve a aparecer a los 90 segundos.
# -----------------------------------------------------------------------------
class_name Guardia
extends CharacterBody3D

const Economia = preload("res://scripts/datos/economia.gd")

const VELOCIDAD_PATRULLA: float = 1.8
const VELOCIDAD_PERSECUCION: float = 4.5
const DISTANCIA_MINIMA: float = 3.0   # Si estás así de cerca, te notan aunque estés agachado.
const VIDA_MAXIMA: float = 60.0

# Puntos por los que patrulla (posiciones del mundo). Los pone quien lo crea.
var ruta: Array[Vector3] = []
# true: solo existe de noche (los refuerzos nocturnos). false: también de día (en modo tranquilo).
var solo_noche: bool = false
# true: pasea por toda la ciudad por la red de calles (como una persona), en vez de su ruta fija.
var pasea_ciudad: bool = true

var _vida: float = VIDA_MAXIMA
var _punto: int = 0
var _persiguiendo: bool = false
var _ultima_pos: Vector3 = Vector3.ZERO   # Dónde te vieron por última vez.
var _golpe: float = 0.0
var _muerto: bool = false
var _cuerpo: Node3D
var _material: StandardMaterial3D
static var _destinos: Dictionary = {}   # guardia -> nodo al que va (para repartirse)
var _t_puertas: float = 0.0
var _nodo_destino: String = ""
var _espera: float = 0.0
var _t_atasco: float = 0.0            # Segundos intentando andar sin avanzar.
var _pos_atasco: Vector3 = Vector3.ZERO
var _modelo: Node3D   # Personaje de Quaternius (null = muñeco de cajas).


func _ready() -> void:
	add_to_group("danable")
	# Los guardias no chocan entre sí: si no, dos que se cruzan de frente en una
	# calle se quedan empujándose sin avanzar.
	for otro in get_tree().get_nodes_in_group("guardias"):
		add_collision_exception_with(otro)
		(otro as PhysicsBody3D).add_collision_exception_with(self)
	add_to_group("guardias")
	var forma: CollisionShape3D = CollisionShape3D.new()
	var capsula: CapsuleShape3D = CapsuleShape3D.new()
	capsula.radius = 0.35
	capsula.height = 1.7
	forma.shape = capsula
	forma.position.y = 0.85
	add_child(forma)
	_cuerpo = Node3D.new()
	add_child(_cuerpo)
	var abrigo: Node3D = Construir.cilindro(_cuerpo, Vector3(0, 0.6, 0), 0.34, 1.2, Color(0.12, 0.14, 0.26), false, 0.0, 0.26)
	_material = Construir.material_propio(abrigo)   # Propio: brilla rojo al recibir daño.
	Construir.esfera(_cuerpo, Vector3(0, 1.42, 0), 0.2, Color(0.75, 0.62, 0.52))
	Construir.cilindro(_cuerpo, Vector3(0, 1.68, 0), 0.2, 0.2, Color(0.1, 0.1, 0.18), false, 0.0, 0.16)
	Construir.caja(_cuerpo, Vector3(0.35, 1.0, -0.1), Vector3(0.05, 0.05, 0.9), Color(0.5, 0.5, 0.55), false)  # Lanza.
	Construir.caja(_cuerpo, Vector3(0, 1.42, -0.2), Vector3(0.06, 0.06, 0.1), Color(0.7, 0.55, 0.45), false)
	# Si está el modelo de Quaternius, sustituye al muñeco de cajas.
	var soldado: Node3D = Assets.personaje("quaternius/toon-shooter-game-kit/Characters/Character_Soldier", "Shotgun", "Walk")
	if soldado != null:
		for h in _cuerpo.get_children():
			(h as Node3D).visible = false
		_cuerpo.add_child(soldado)
		_modelo = soldado
	if not ruta.is_empty():
		global_position = ruta[0]
	_poner_activo(false)


# Solo existe de noche (y mientras no esté caído).
func _poner_activo(activo: bool) -> void:
	visible = activo
	collision_layer = 1 if activo else 0
	collision_mask = 1 if activo else 0


func _physics_process(delta: float) -> void:
	if _muerto:
		return
	var de_noche: bool = Juego.es_de_noche()
	var activo: bool = Juego.policia_activa and (de_noche or not solo_noche)
	if activo != visible:
		_poner_activo(activo)
		_persiguiendo = false
	if not activo:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	_golpe -= delta

	_t_puertas -= delta
	if _t_puertas <= 0.0:
		_t_puertas = 5.0
		_revisar_puertas(de_noche)

	var jugador: Node3D = _buscar_jugador()
	var ve: bool = jugador != null and _ve_ilegal(jugador, de_noche)
	if jugador != null and not ve:
		ve = _vigilar_trafico(jugador)
	if ve:
		_persiguiendo = true
		_ultima_pos = jugador.global_position
		Juego.alerta = 100.0
		if de_noche:
			Juego.motivo_alerta = "Un guardia te ha visto con: " + ", ".join(Juego.motivos_ilegales())
		else:
			Juego.motivo_alerta = "Te han visto vender cosas ilegales en la calle"
	# Sigue buscando mientras la alerta no baje a cero (ver Juego._process).
	if _persiguiendo and Juego.alerta <= 0.0:
		_persiguiendo = false

	var destino: Vector3 = global_position
	var velocidad: float = 0.0
	if _persiguiendo and jugador != null:
		destino = _ultima_pos
		velocidad = VELOCIDAD_PERSECUCION
		if not ve and global_position.distance_to(Vector3(destino.x, global_position.y, destino.z)) < 1.0:
			velocidad = 0.0   # Ha llegado donde te vio y mira a su alrededor.
		if ve and global_position.distance_to(jugador.global_position) < 1.6:
			velocidad = 0.0
			if _golpe <= 0.0:
				_golpe = 1.0
				Juego.cambiar_vida(-8.0)
				Juego.avisar("¡Un guardia te golpea!")
	elif pasea_ciudad:
		velocidad = VELOCIDAD_PATRULLA
		if _espera > 0.0:
			_espera -= delta
			velocidad = 0.0
			_mirar_cacheo(jugador, de_noche)
		else:
			if _nodo_destino == "":
				_nodo_destino = RedCalles.nodo_mas_cercano(global_position)
			destino = RedCalles.NODOS[_nodo_destino]
			if global_position.distance_to(Vector3(destino.x, global_position.y, destino.z)) < 0.8:
				var vecinos: Array = RedCalles.VECINOS[_nodo_destino]
				var libres: Array = []
				for v in vecinos:
					var ocupado: bool = false
					for otro in _destinos:
						if otro != self and is_instance_valid(otro) and _destinos[otro] == v:
							ocupado = true
					if not ocupado:
						libres.append(v)
				var candidatos: Array = libres if not libres.is_empty() else vecinos
				_nodo_destino = candidatos[randi() % candidatos.size()]
				_destinos[self] = _nodo_destino
				if randf() < 0.5:
					_espera = randf_range(2.0, 7.0)   # Se para a mirar a su alrededor.
			else:
				_mirar_cacheo(jugador, de_noche)
	elif not ruta.is_empty():
		destino = ruta[_punto]
		velocidad = VELOCIDAD_PATRULLA
		if global_position.distance_to(Vector3(destino.x, global_position.y, destino.z)) < 0.6:
			_punto = (_punto + 1) % ruta.size()

	var hacia: Vector3 = destino - global_position
	hacia.y = 0.0
	if hacia.length() > 0.1 and velocidad > 0.0:
		var d: Vector3 = hacia.normalized()
		velocity.x = d.x * velocidad
		velocity.z = d.z * velocidad
		_cuerpo.rotation.y = lerp_angle(_cuerpo.rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * 8.0))
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	_vigilar_atasco(delta, velocidad > 0.0 and hacia.length() > 0.1)
	if _modelo != null:
		var corre: bool = velocity.length() > 0.2
		Assets.poner_animacion(_modelo, "Run" if velocity.length() > 3.0 else ("Walk" if corre else "Idle"))


# Red de seguridad: si intenta andar y no avanza (un mueble, una esquina, una pared
# entre él y su destino tras una persecución), primero prueba otro camino y, si
# sigue igual, vuelve de golpe al punto de la red de calles más cercano.
func _vigilar_atasco(delta: float, intenta_andar: bool) -> void:
	if not intenta_andar or global_position.distance_to(_pos_atasco) > 0.6:
		_pos_atasco = global_position
		_t_atasco = 0.0
		return
	_t_atasco += delta
	if _t_atasco > 8.0:
		_nodo_destino = RedCalles.nodo_mas_cercano(global_position)
		global_position = RedCalles.NODOS[_nodo_destino] + Vector3(0, 0.1, 0)
		velocity = Vector3.ZERO
		_persiguiendo = false
		_t_atasco = 0.0
		_pos_atasco = global_position
	elif _t_atasco > 2.5 and pasea_ciudad and not _persiguiendo and _nodo_destino != "":
		# Cambia de destino a otro vecino (una sola vez por atasco).
		if _t_atasco - delta <= 2.5:
			var vecinos: Array = RedCalles.VECINOS[_nodo_destino]
			_nodo_destino = vecinos[randi() % vecinos.size()]


func _buscar_jugador() -> Node3D:
	var lista: Array = get_tree().get_nodes_in_group("jugador")
	return null if lista.is_empty() else lista[0] as Node3D


# true si el jugador está cerca, a la vista y lleva algo ilegal.
func _ve_ilegal(jugador: Node3D, de_noche: bool = true) -> bool:
	var alcance: float = DISTANCIA_MINIMA
	if jugador.has_method("radio_deteccion"):
		alcance = maxf(DISTANCIA_MINIMA, jugador.radio_deteccion())
	if global_position.distance_to(jugador.global_position) > alcance:
		return false
	# De noche basta con llevar algo ilegal; de día solo si te vieron vender en la calle.
	if de_noche:
		if not Juego.lleva_ilegal():
			return false
	elif Juego.delito_visto <= 0.0:
		return false
	var desde: Vector3 = global_position + Vector3(0, 1.5, 0)
	var hasta: Vector3 = jugador.global_position + Vector3(0, 1.2, 0)
	var consulta: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(desde, hasta)
	consulta.exclude = [get_rid()]
	var choque: Dictionary = get_world_3d().direct_space_state.intersect_ray(consulta)
	return _le_ve_el_choque(choque, jugador)


# El rayo llega hasta el jugador o hasta el vehículo que conduce.
func _le_ve_el_choque(choque: Dictionary, jugador: Node3D) -> bool:
	if choque.is_empty() or choque["collider"] == jugador:
		return true
	var v = jugador.get("vehiculo")
	return v != null and choque["collider"] == v.get("chasis")


# Delitos de tráfico: atropellar a alguien a la vista o conducir sin carnet. Devuelve true si
# este guardia lo ha visto (entonces te persigue); la primera vez que te alcanza te multa.
func _vigilar_trafico(jugador: Node3D) -> bool:
	var v = jugador.get("vehiculo")
	var motivo: String = ""
	if Juego.atropello_visto > 0.0:
		motivo = "Has atropellado a alguien"
	elif v != null and not Juego.tiene_carnet() and absf(float(v.get("_v"))) > 1.0:
		motivo = "Conduces sin carnet"
	if motivo == "":
		return false
	if global_position.distance_to(jugador.global_position) > 28.0:
		return false
	var desde: Vector3 = global_position + Vector3(0, 1.5, 0)
	var hasta: Vector3 = jugador.global_position + Vector3(0, 1.2, 0)
	var consulta: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(desde, hasta)
	consulta.exclude = [get_rid()]
	if not _le_ve_el_choque(get_world_3d().direct_space_state.intersect_ray(consulta), jugador):
		return false
	Juego.motivo_alerta = "Un guardia te ha visto: " + motivo.to_lower()
	if global_position.distance_to(jugador.global_position) < 5.0 and Juego.multa_trafico_enfriamiento <= 0.0:
		var multa: int = mini(Juego.dinero, Economia.MULTA_ATROPELLO if Juego.atropello_visto > 0.0 else Economia.MULTA_SIN_CARNET)
		Juego.dinero -= multa
		Juego.multa_trafico_enfriamiento = 60.0
		Juego.atropello_visto = 0.0
		Juego.cambio.emit()
		Juego.avisar("¡Alto! %s. Multa de %d $. Hazte el carnet con un instructor." % [motivo, multa] if not Juego.tiene_carnet() \
				else "¡Alto! %s. Multa de %d $." % [motivo, multa])
	return true


# Si pasa cerca de una casa tuya con la puerta abierta, puede entrar a registrarla.
func _revisar_puertas(de_noche: bool) -> void:
	for nodo in get_tree().get_nodes_in_group("puertas"):
		var puerta: PuertaCasa = nodo as PuertaCasa
		if puerta == null or not puerta.abierta or not Juego.alquilada(puerta.id_casa):
			continue
		if global_position.distance_to(puerta.global_position) > 14.0:
			continue
		var prob: float = (0.35 if de_noche else 0.12) * (1.0 + Juego.sospecha / 60.0)
		var jug: Node3D = _buscar_jugador()
		if jug != null and jug.global_position.distance_to(puerta.global_position) < 8.0:
			prob *= 0.3   # Si estás cerca de tu casa, es menos probable que se atrevan.
		if randf() < prob:
			Juego.avisar(Juego.registrar_casa())
			puerta.abierta = false
			puerta._giro_objetivo = 0.0
			return


# Con probabilidad baja (más alta de noche y si llevas algo ilegal) te pide un cacheo.
func _mirar_cacheo(jugador: Node3D, de_noche: bool) -> void:
	if jugador == null or Juego.menu_abierto or Juego.enfriamiento_cacheo > 0.0 or Juego.interiores > 0:
		return
	if global_position.distance_to(jugador.global_position) > 5.0:
		return
	var prob: float = 0.004   # Por fotograma físico a 60 FPS: ~ una vez cada 4 minutos de día.
	if de_noche:
		prob = 0.012
	if Juego.lleva_ilegal():
		prob *= 1.5
	prob *= 1.0 + Juego.sospecha / 40.0
	if randf() < prob / 6.0 and "hud" in jugador and jugador.hud != null:
		Juego.enfriamiento_cacheo = 150.0
		Juego.avisar("¡Alto! Un guardia quiere registrarte.")
		jugador.hud.abrir_cacheo()


func recibir_dano(cantidad: float) -> void:
	if _muerto or not visible:
		return
	_vida -= cantidad
	_persiguiendo = true
	Juego.alerta = 100.0
	Juego.motivo_alerta = "Has atacado a un guardia"
	var jug: Node3D = _buscar_jugador()
	if jug != null:
		_ultima_pos = jug.global_position
	_material.emission_enabled = true
	_material.emission = Color(1, 0.2, 0.1)
	if _vida <= 0.0:
		_caer()
		return
	await get_tree().create_timer(0.15).timeout
	_material.emission_enabled = false


func _caer() -> void:
	_muerto = true
	_poner_activo(false)
	_material.emission_enabled = false
	Juego.cobrar(15)
	Juego.avisar("Un guardia cae. Llevaba 15 $ encima.")
	await get_tree().create_timer(90.0).timeout
	_vida = VIDA_MAXIMA
	_persiguiendo = false
	if pasea_ciudad:
		_nodo_destino = RedCalles.nodo_mas_cercano(global_position)
		global_position = RedCalles.NODOS[_nodo_destino]
	elif not ruta.is_empty():
		global_position = ruta[0]
	_muerto = false
