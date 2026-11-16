# jugador.gd
# -----------------------------------------------------------------------------
# El alquimista que controlas. Empieza en primera persona; con V cambias a
# tercera persona (cámara detrás del hombro) y viceversa.
#
#   WASD / flechas  moverse        Ratón   mirar
#   Shift           correr         Espacio saltar
#   E               usar           Q       cambiar hierba en la mano
#   V               primera/tercera persona   TAB  inventario   Esc soltar el ratón
#
# Estructura (se crea sola en _ready):
#   Jugador (CharacterBody3D)  <- se mueve, pero nunca gira
#    ├─ Cuerpo (Node3D)        <- el muñeco; gira hacia donde caminas
#    └─ Pivote (Node3D)        <- gira con el ratón a izquierda/derecha
#        └─ Brazo (SpringArm3D) <- sube/baja con el ratón; se acorta si hay pared
#            └─ Camara (Camera3D)
# -----------------------------------------------------------------------------
class_name Jugador
extends CharacterBody3D

const VELOCIDAD_ANDAR: float = 3.5
const VELOCIDAD_CORRER: float = 6.5
const FUERZA_SALTO: float = 4.5
const SENSIBILIDAD_RATON: float = 0.0025
const DISTANCIA_CAMARA: float = 3.0
# Cámara un poco a la derecha (por encima del hombro) para que el muñeco no tape el centro.
const DESPLAZAMIENTO_HOMBRO: float = 0.6

# El HUD (lo pone mundo.gd): ventanas, fundidos y mensajes.
var hud: Hud
# Lo que tienes delante y puedes usar con E (o null si no hay nada).
var objetivo: Interactuable = null
var primera_persona: bool = true   # Empieza en primera persona; V cambia.

var _giro: float = 0.0        # Izquierda/derecha de la cámara (radianes).
var _inclinacion: float = -0.2  # Arriba/abajo de la cámara.
var _bloqueado: bool = false   # Para quietos momentáneos (por ejemplo, escenas).

var _cuerpo: Node3D
var _pivote: Node3D
var _brazo: SpringArm3D
var _camara: Camera3D


func _ready() -> void:
	_crear_cuerpo()
	_crear_camara()
	_aplicar_camara()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ------------------------------- Ratón y teclas -------------------------------

func _unhandled_input(evento: InputEvent) -> void:
	if Juego.menu_abierto:
		return  # Con una ventana abierta, el ratón y las teclas son para la ventana.
	var raton_capturado: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if evento is InputEventMouseMotion and raton_capturado:
		var movimiento: InputEventMouseMotion = evento
		_giro -= movimiento.relative.x * SENSIBILIDAD_RATON
		_inclinacion -= movimiento.relative.y * SENSIBILIDAD_RATON
		_inclinacion = clampf(_inclinacion, -1.3, 1.0)
	elif evento is InputEventMouseButton and evento.pressed and not raton_capturado:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # Clic para volver a jugar.
	elif evento.is_action_pressed("liberar_raton"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif evento.is_action_pressed("cambiar_camara"):
		primera_persona = not primera_persona
		_aplicar_camara()
	elif evento.is_action_pressed("cambiar_hierba"):
		Juego.siguiente_hierba()
	elif evento.is_action_pressed("usar") and objetivo != null and not _bloqueado:
		objetivo.usar(self)


# --------------------------------- Movimiento ---------------------------------

func _physics_process(delta: float) -> void:
	_pivote.rotation.y = _giro
	_brazo.rotation.x = _inclinacion

	# Gravedad.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Dirección según las teclas, relativa a hacia dónde mira la cámara.
	var teclas: Vector2 = Vector2.ZERO
	if not _bloqueado and not Juego.menu_abierto:
		teclas = Input.get_vector("izquierda", "derecha", "adelante", "atras")
		if Input.is_action_just_pressed("saltar") and is_on_floor():
			velocity.y = FUERZA_SALTO
	var direccion: Vector3 = Basis(Vector3.UP, _giro) * Vector3(teclas.x, 0.0, teclas.y)

	var velocidad: float = VELOCIDAD_CORRER if Input.is_action_pressed("correr") else VELOCIDAD_ANDAR
	var deseada: Vector3 = direccion * velocidad
	# "lerp" suaviza: no frenas ni arrancas de golpe.
	velocity.x = lerpf(velocity.x, deseada.x, minf(1.0, delta * 12.0))
	velocity.z = lerpf(velocity.z, deseada.z, minf(1.0, delta * 12.0))
	move_and_slide()

	# El muñeco mira hacia donde caminas (o hacia la cámara en primera persona).
	if primera_persona:
		_cuerpo.rotation.y = _giro
	elif direccion.length() > 0.1:
		var angulo: float = atan2(-direccion.x, -direccion.z)
		_cuerpo.rotation.y = lerp_angle(_cuerpo.rotation.y, angulo, minf(1.0, delta * 10.0))

	_buscar_objetivo()


func _aplicar_camara() -> void:
	_brazo.spring_length = 0.0 if primera_persona else DISTANCIA_CAMARA
	_brazo.position.x = 0.0 if primera_persona else DESPLAZAMIENTO_HOMBRO
	_cuerpo.visible = not primera_persona


# Busca el objeto usable más cercano que esté delante de la cámara.
func _buscar_objetivo() -> void:
	var delante: Vector3 = -_pivote.global_basis.z
	delante.y = 0.0
	delante = delante.normalized()
	var mejor: Interactuable = null
	var mejor_distancia: float = INF
	for nodo in get_tree().get_nodes_in_group("interactuable"):
		var cosa: Interactuable = nodo as Interactuable
		if cosa == null or not cosa.is_visible_in_tree():
			continue
		var hacia: Vector3 = cosa.global_position - global_position
		if absf(hacia.y) > 2.0:
			continue
		hacia.y = 0.0
		var d: float = hacia.length()
		if d > cosa.distancia:
			continue
		if d > 0.3 and delante.dot(hacia / d) < 0.25:
			continue  # Está detrás o muy de lado.
		if d < mejor_distancia and _se_ve(cosa):
			mejor = cosa
			mejor_distancia = d
	objetivo = mejor


# true si no hay una pared entre los ojos del jugador y el objeto.
func _se_ve(cosa: Interactuable) -> bool:
	var ojos: Vector3 = global_position + Vector3(0, 1.5, 0)
	var destino: Vector3 = cosa.global_position + Vector3(0, 0.3, 0)
	var consulta: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ojos, destino)
	consulta.exclude = [get_rid()]
	var choque: Dictionary = get_world_3d().direct_space_state.intersect_ray(consulta)
	# Si choca, solo vale si es con el propio objeto (o muy cerca de él).
	return choque.is_empty() or choque["position"].distance_to(destino) < 0.8


# ------------------------- Construcción del muñeco ----------------------------

func _crear_cuerpo() -> void:
	# Forma de choque: una cápsula de 1,7 m con los pies en el suelo.
	var choque: CollisionShape3D = CollisionShape3D.new()
	var capsula: CapsuleShape3D = CapsuleShape3D.new()
	capsula.radius = 0.35
	capsula.height = 1.7
	choque.shape = capsula
	choque.position.y = 0.85
	add_child(choque)

	# El muñeco: abrigo largo, cabeza, sombrero de ala ancha y una bufanda verde.
	_cuerpo = Node3D.new()
	add_child(_cuerpo)
	Construir.cilindro(_cuerpo, Vector3(0, 0.6, 0), 0.34, 1.2, Color(0.16, 0.12, 0.2), false, 0.0, 0.26)
	Construir.esfera(_cuerpo, Vector3(0, 1.42, 0), 0.2, Color(0.75, 0.62, 0.52))
	Construir.cilindro(_cuerpo, Vector3(0, 1.2, 0), 0.24, 0.12, Color(0.25, 0.5, 0.3))
	Construir.cilindro(_cuerpo, Vector3(0, 1.58, 0), 0.38, 0.04, Color(0.08, 0.07, 0.09))
	Construir.cilindro(_cuerpo, Vector3(0, 1.72, 0), 0.18, 0.26, Color(0.08, 0.07, 0.09), false, 0.0, 0.14)
	# Nariz: para saber hacia dónde mira (en Godot "delante" es -Z).
	Construir.caja(_cuerpo, Vector3(0, 1.42, -0.2), Vector3(0.06, 0.06, 0.1), Color(0.7, 0.55, 0.45), false)


func _crear_camara() -> void:
	_pivote = Node3D.new()
	_pivote.position.y = 1.6
	add_child(_pivote)
	_brazo = SpringArm3D.new()
	_brazo.spring_length = DISTANCIA_CAMARA
	_brazo.margin = 0.2
	_brazo.add_excluded_object(get_rid())  # Que no choque con el propio jugador.
	_pivote.add_child(_brazo)
	_camara = Camera3D.new()
	_camara.fov = 70.0
	_brazo.position.x = DESPLAZAMIENTO_HOMBRO  # (El SpringArm3D coloca a la cámara; por eso se mueve el brazo.)
	_brazo.add_child(_camara)
	_camara.current = true
