# maton.gd
# -----------------------------------------------------------------------------
# Un matón de la zona chunga: te ataca cuerpo a cuerpo si te acercas de noche.
# Tiene vida y barra naranja (banda). Se puede esquivar (tecla X) y pelear.
# Lo crea gestor_matones.gd. Ver docs/MUNDO_NOCTURNO_STATS_BANDAS.md (sección 5.2).
# -----------------------------------------------------------------------------
class_name Maton
extends CharacterBody3D

const Bandas = preload("res://scripts/datos/bandas.gd")
const VIDA_MAXIMA: float = 90.0
const VELOCIDAD: float = 3.6
const DANO: float = 9.0
const ALCANCE: float = 1.7
const VISTA: float = 24.0

var vida: float = VIDA_MAXIMA
var vida_max: float = VIDA_MAXIMA
var banda: String = ""
var jefe: bool = false          # Jefe de barrio: más vida y más daño; al caer, el barrio es tuyo.
var aliado: bool = false        # Recluta tuyo: te sigue y pelea contra los matones.
var territorio: String = ""
var dano: float = DANO
var _jugador: Node3D = null
var _golpe: float = 0.0
var _muerto: bool = false
var _enfado: bool = false


func _ready() -> void:
	add_to_group("danable")
	add_to_group("matones")
	collision_layer = 1
	collision_mask = 1
	var forma: CollisionShape3D = CollisionShape3D.new()
	var capsula: CapsuleShape3D = CapsuleShape3D.new()
	capsula.radius = 0.35
	capsula.height = 1.7
	forma.shape = capsula
	forma.position.y = 0.85
	add_child(forma)
	if jefe:
		vida_max = Bandas.VIDA_JEFE
		vida = vida_max
		dano = 14.0
	if aliado:
		remove_from_group("matones")
		remove_from_group("danable")
		add_to_group("aliados")
		collision_layer = 0
	var ropa: Color = Color(0.2, 0.32, 0.5) if aliado else (Color(0.5, 0.2, 0.2) if jefe else Color(0.4, 0.28, 0.26))
	Construir.cilindro(self, Vector3(0, 0.6, 0), 0.3, 1.2, ropa, false)
	Construir.esfera(self, Vector3(0, 1.42, 0), 0.2, Color(0.72, 0.58, 0.48))
	if jefe:
		Construir.cilindro(self, Vector3(0, 1.62, 0), 0.24, 0.12, Color(0.1, 0.1, 0.1), false)   # Sombrero.
	# Pañuelo naranja de la banda.
	Construir.cilindro(self, Vector3(0, 1.0, 0), 0.31, 0.12, Color(0.95, 0.5, 0.1), false)


func recibir_dano(cantidad: float) -> void:
	if _muerto:
		return
	vida -= cantidad
	_enfado = true
	BarraVida.de(self, 2.3 if jefe else 2.1, "neutral" if aliado else "banda").mostrar(vida / vida_max)
	if vida <= 0.0:
		_morir()


func _morir() -> void:
	_muerto = true
	remove_from_group("danable")
	collision_layer = 0
	if aliado:
		Juego.reclutas = maxi(0, Juego.reclutas - 1)
		Juego.avisar("Uno de tus hombres ha caído.")
		queue_free()
		return
	if jefe:
		_caer_jefe()
		return
	var botin: int = randi_range(10, 45)
	Juego.cobrar(botin)
	Juego.ganar_xp(8)
	Juego.sospecha = minf(100.0, Juego.sospecha + 4.0)
	Juego.cambiar_rep("ley", 3)
	Juego.cambiar_rep("hampa", -4)
	Juego.avisar("El matón cae. Le registras los bolsillos: %d $." % botin)
	rotation.x = -PI / 2.0
	var t: SceneTreeTimer = get_tree().create_timer(6.0)
	t.timeout.connect(queue_free)


func _caer_jefe() -> void:
	Juego.cobrar(randi_range(150, 300))
	Juego.ganar_xp(40)
	Juego.cambiar_rep("hampa", 10)
	Juego.cambiar_rep("ley", 2)
	if territorio != "":
		Juego.territorios[territorio] = "jugador"
	Juego.avisar("¡El jefe de barrio cae! Ahora el barrio es tuyo: %d $ de cuota al día." % Bandas.CUOTA_TERRITORIO)
	rotation.x = -PI / 2.0
	get_tree().create_timer(8.0).timeout.connect(queue_free)


# El enemigo más cercano a tu recluta, o null.
func _enemigo_cercano() -> Node3D:
	var mejor: Node3D = null
	var d_mejor: float = 14.0
	for m in get_tree().get_nodes_in_group("matones"):
		var n: Node3D = m as Node3D
		if n == null or not is_instance_valid(n) or n.get("_muerto"):
			continue
		var d: float = n.global_position.distance_to(global_position)
		if d < d_mejor:
			d_mejor = d
			mejor = n
	return mejor


# Un recluta tuyo cercano al matón (le ataca si está a menos de 5 m), o null.
func _aliado_cercano() -> Node3D:
	for a in get_tree().get_nodes_in_group("aliados"):
		var n: Node3D = a as Node3D
		if n != null and is_instance_valid(n) and not n.get("_muerto") and n.global_position.distance_to(global_position) < 5.0:
			return n
	return null


func _physics_process(delta: float) -> void:
	if _muerto:
		return
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
		return
	_golpe -= delta
	velocity.y -= 20.0 * delta
	var objetivo: Node3D = _jugador
	if aliado:
		var enemigo: Node3D = _enemigo_cercano()
		if enemigo != null:
			objetivo = enemigo
	elif _enfado or not Juego.protegido():
		var amigo: Node3D = _aliado_cercano()
		if amigo != null:
			objetivo = amigo
	var al: Vector3 = objetivo.global_position - global_position
	var plano: Vector3 = Vector3(al.x, 0.0, al.z)
	var dist: float = plano.length()
	var activo: bool = _enfado or (not Juego.protegido() and (dist < VISTA * 0.5 or (dist < VISTA and Juego.sospecha > 40.0)))
	if aliado:
		# Sigue al jugador a unos 3 m; ataca si hay un enemigo cerca.
		activo = objetivo != _jugador or dist > 3.5
	elif objetivo != _jugador:
		activo = true
	if activo and dist > (ALCANCE if (not aliado or objetivo != _jugador) else 3.0):
		var dir: Vector3 = plano.normalized()
		velocity.x = dir.x * VELOCIDAD
		velocity.z = dir.z * VELOCIDAD
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 8.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	if activo and dist <= ALCANCE and objetivo != _jugador and _golpe <= 0.0 and absf(al.y) < 2.0:
		_golpe = 1.2
		if objetivo.has_method("recibir_dano"):
			objetivo.recibir_dano(dano)
	elif activo and not aliado and dist <= ALCANCE and _golpe <= 0.0 and absf(al.y) < 2.0:
		_golpe = 1.2
		Juego.cambiar_vida(-dano)   # Si estás esquivando (X) no te toca.
		if Juego.invulnerable <= 0.0:
			Juego.avisar("¡El jefe te pega!" if jefe else "¡El matón te pega!")
	move_and_slide()
