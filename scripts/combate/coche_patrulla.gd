# coche_patrulla.gd
# -----------------------------------------------------------------------------
# Coche de policía que te persigue cuando tienes 3 o más estrellas. Lo crea
# gestor_policia.gd. Va hacia ti en línea recta (esquiva lo que puede deslizándose
# por las paredes); si lleva rato atascado, el gestor lo recoloca. Al alcanzarte:
#   - a pie o con el coche casi parado: te detienen (como un guardia),
#   - si huyes a toda velocidad: te embiste (daña tu vehículo y tu vida).
# Desaparece solo cuando se te acaba la búsqueda. SIN PROBAR a mano en Godot.
# -----------------------------------------------------------------------------
class_name CochePatrulla
extends CharacterBody3D

const DatosPolicia = preload("res://scripts/datos/policia.gd")

const LARGO: float = 4.4
const ANCHO: float = 2.0

var _v: float = 0.0
var _t_luz: float = 0.0
var _rojo: OmniLight3D
var _azul: OmniLight3D
var _t_contacto: float = 0.0
var _t_embestida: float = 0.0
var _t_atasco: float = 0.0
var _pos_atasco: Vector3 = Vector3.ZERO
var atascado: bool = false   # Lo lee gestor_policia.gd para recolocarlo.


func _ready() -> void:
	add_to_group("coches_policia")
	add_to_group("policia_refuerzo")
	var forma: CollisionShape3D = CollisionShape3D.new()
	var caja: BoxShape3D = BoxShape3D.new()
	caja.size = Vector3(ANCHO, 1.3, LARGO)
	forma.shape = caja
	forma.position.y = 0.75
	add_child(forma)
	var m: Node3D = Assets.modelo("kenney/car-kit/police") if Assets.existe("kenney/car-kit/police") else null
	if m != null:
		var ab: AABB = Assets.caja_de(m)
		var largo_x: bool = ab.size.x > ab.size.z
		var esc: float = LARGO / maxf(0.01, maxf(ab.size.x, ab.size.z))
		m.position = Vector3(-ab.get_center().x, -ab.position.y, -ab.get_center().z)
		var envoltorio: Node3D = Node3D.new()
		envoltorio.scale = Vector3.ONE * esc
		envoltorio.rotation.y = PI / 2.0 if largo_x else PI
		envoltorio.add_child(m)
		add_child(envoltorio)
	else:
		Construir.caja(self, Vector3(0, 0.6, 0), Vector3(ANCHO, 0.8, LARGO), Color(0.1, 0.12, 0.25), false)
		Construir.caja(self, Vector3(0, 1.2, 0.3), Vector3(ANCHO - 0.2, 0.6, LARGO * 0.5), Color(0.92, 0.92, 0.95), false)
	_rojo = OmniLight3D.new()
	_rojo.light_color = Color(1.0, 0.1, 0.1)
	_rojo.omni_range = 14.0
	_rojo.position = Vector3(-0.5, 1.9, 0)
	add_child(_rojo)
	_azul = OmniLight3D.new()
	_azul.light_color = Color(0.2, 0.3, 1.0)
	_azul.omni_range = 14.0
	_azul.position = Vector3(0.5, 1.9, 0)
	add_child(_azul)
	Construir.caja(self, Vector3(-0.5, 1.75, 0), Vector3(0.4, 0.15, 0.3), Color(1.0, 0.1, 0.1), false, 1.0)
	Construir.caja(self, Vector3(0.5, 1.75, 0), Vector3(0.4, 0.15, 0.3), Color(0.2, 0.3, 1.0), false, 1.0)
	collision_layer = 1
	collision_mask = 1


func _physics_process(delta: float) -> void:
	_t_luz += delta
	var fase: bool = int(_t_luz * 5.0) % 2 == 0
	_rojo.light_energy = 4.0 if fase else 0.0
	_azul.light_energy = 0.0 if fase else 4.0
	if Juego.estrellas < 3 or not Juego.policia_activa:
		queue_free()
		return
	var lista: Array = get_tree().get_nodes_in_group("jugador")
	if lista.is_empty():
		return
	var jugador: Node3D = lista[0] as Node3D
	var objetivo: Vector3 = jugador.global_position
	var hacia: Vector3 = objetivo - global_position
	hacia.y = 0.0
	var dist: float = hacia.length()
	var vmax: float = 13.0 + 2.5 * float(Juego.estrellas)
	var en_coche: bool = jugador.get("vehiculo") != null
	# Frena al acercarse si no es para embestir (a pie o con el coche casi parado).
	var vel_objetivo: float = vmax
	if Juego.alerta <= 0.0:
		vel_objetivo = 0.0   # Te han perdido: se queda parado hasta que baje la búsqueda.
	elif dist < 7.0 and not (en_coche and _velocidad_jugador(jugador) > 6.0):
		vel_objetivo = 2.0
	_v = move_toward(_v, vel_objetivo, 9.0 * delta)
	if dist > 0.5:
		var d: Vector3 = hacia / dist
		var giro_obj: float = atan2(-d.x, -d.z)
		rotation.y = lerp_angle(rotation.y, giro_obj, minf(1.0, delta * 2.2))
	var adelante: Vector3 = -global_transform.basis.z
	velocity.x = adelante.x * _v
	velocity.z = adelante.z * _v
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 20.0 * delta
	move_and_slide()
	# Atasco: quiere moverse y no avanza.
	if _v > 3.0 and global_position.distance_to(_pos_atasco) < 0.4:
		_t_atasco += delta
		atascado = _t_atasco > 4.0
	else:
		_t_atasco = 0.0
		atascado = false
		_pos_atasco = global_position
	# Contacto con el jugador.
	_t_embestida = maxf(0.0, _t_embestida - delta)
	if dist < 4.2 and Juego.alerta > 0.0 and not Juego.menu_abierto:
		var rapido: bool = en_coche and _velocidad_jugador(jugador) > 6.0
		if rapido:
			_t_contacto = 0.0
			if _t_embestida <= 0.0:
				_t_embestida = 1.5
				var v = jugador.get("vehiculo")
				if v != null:
					v.set("salud", maxf(0.0, float(v.get("salud")) - 8.0))
				Juego.cambiar_vida(-4.0)
				Juego.avisar("¡Un coche patrulla te embiste!")
		else:
			_t_contacto += delta
			if _t_contacto > 1.5 and jugador.has_method("ser_detenido"):
				_t_contacto = 0.0
				jugador.ser_detenido()
	else:
		_t_contacto = maxf(0.0, _t_contacto - delta)


func _velocidad_jugador(jugador: Node3D) -> float:
	var v = jugador.get("vehiculo")
	return absf(float(v.get("_v"))) if v != null else 0.0
