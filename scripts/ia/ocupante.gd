# ocupante.gd
# -----------------------------------------------------------------------------
# Una persona dentro de un local (restaurante, bar, cafetería, panadería, taberna, taller,
# peluquería...): quien atiende detrás del mostrador o un cliente. Hace su vida (el empleado se
# mueve por su puesto; los clientes pasean por la sala, se paran, charlan) y piensa con el mismo
# cerebro que peatones y vecinos (PersonaIA, árbol "vecino"): si hay jaleo (disparos, peleas,
# alguien le apunta) cada uno reacciona según su carácter: huye por la puerta, se agacha detrás
# de algo, pelea a puñetazos, suplica o, si va armado (algunos empleados tienen una escopeta
# bajo el mostrador), dispara.
#
# Lo crea LocalMundo (ver _poblar en local_mundo.gd). Coordenadas: "zona" es el rectángulo del
# suelo (x/z) en el espacio del padre; "puesto" (opcional) el sitio fijo del empleado.
# -----------------------------------------------------------------------------
class_name Ocupante
extends CharacterBody3D

var zona: Rect2 = Rect2(-3, -3, 6, 6)    # Suelo del local, en coordenadas del padre.
var puesto: Vector3 = Vector3.INF          # Sitio del empleado (coordenadas del padre); INF = cliente.
var salida_local: Vector3 = Vector3.ZERO   # Puerta (coordenadas del padre).
var armado: bool = false
var arma: String = "Shotgun"
var vida: float = 55.0
var vida_max: float = 55.0
var cerebro: PersonaIA = null
var modelo: Node3D = null
var semilla: int = 0
var muerto: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _herido_por_jugador: bool = false


func _ready() -> void:
	add_to_group("danable")
	add_to_group("oyentes_ia")
	add_to_group("ocupantes")
	collision_layer = 1
	collision_mask = 1
	_rng.seed = semilla
	var forma: CollisionShape3D = CollisionShape3D.new()
	var capsula: CapsuleShape3D = CapsuleShape3D.new()
	capsula.radius = 0.3
	capsula.height = 1.7
	forma.shape = capsula
	forma.position.y = 0.85
	add_child(forma)
	cerebro = PersonaIA.new(self, "vecino", semilla + 101)
	cerebro.armado = armado
	if armado:
		cerebro.arma_modelo = arma
		cerebro.dano_bala = 16.0 if arma == "Shotgun" else 11.0
		cerebro.valentia = maxf(cerebro.valentia, 0.6)
	modelo = Assets.persona("", arma if armado else "", "Idle")
	if modelo == null:
		modelo = Assets.personaje("quaternius/toon-shooter-game-kit/Characters/Character_Enemy", "", "Idle")
	if modelo != null:
		if armado:
			PersonaIA._mostrar_arma_en(modelo, "")
		# Quien atiende va de uniforme claro; los clientes, como cualquiera.
		Ropa.vestir(modelo, semilla, {"camisa": Color(0.92, 0.92, 0.9), "manga": 1, "pierna": 0} if es_empleado() else {})
		add_child(modelo)
	else:
		Construir.cilindro(self, Vector3(0, 0.6, 0), 0.3, 1.2, Color.from_hsv(_rng.randf(), 0.4, 0.5), false)
		Construir.esfera(self, Vector3(0, 1.42, 0), 0.2, Color(0.78, 0.62, 0.5))


func es_empleado() -> bool:
	return puesto != Vector3.INF


# --------------------------- Lo que pide el cerebro ---------------------------

func ia_vida() -> float:
	return clampf(vida / maxf(vida_max, 1.0), 0.0, 1.0)


func ia_dentro() -> bool:
	var l: Vector3 = get_parent().to_local(global_position) if get_parent() is Node3D else position
	return zona.grow(0.2).has_point(Vector2(l.x, l.z))


func ia_salida() -> Vector3:
	var padre: Node3D = get_parent() as Node3D
	return padre.to_global(salida_local + Vector3(0, 0, 1.5)) if padre != null else global_position


func ia_punto_rutina() -> Vector3:
	var padre: Node3D = get_parent() as Node3D
	if padre == null:
		return global_position
	if es_empleado():
		return padre.to_global(puesto + Vector3(_rng.randf_range(-0.9, 0.9), 0, _rng.randf_range(-0.2, 0.2)))
	var m: float = 0.8
	var x: float = _rng.randf_range(zona.position.x + m, zona.end.x - m)
	var z: float = _rng.randf_range(zona.position.y + m, zona.end.y - m)
	return padre.to_global(Vector3(x, position.y, z))


# Se esconde en la esquina más alejada del jaleo.
func ia_escondite() -> Vector3:
	var padre: Node3D = get_parent() as Node3D
	if padre == null:
		return global_position
	var mejor: Vector3 = global_position
	var mejor_d: float = -1.0
	var j: Node3D = cerebro.jugador() if cerebro != null else null
	for esq in [zona.position, Vector2(zona.end.x, zona.position.y), zona.end, Vector2(zona.position.x, zona.end.y)]:
		var e2: Vector2 = esq
		var c2: Vector2 = zona.get_center()
		var p: Vector3 = padre.to_global(Vector3(lerpf(e2.x, c2.x, 0.15), position.y, lerpf(e2.y, c2.y, 0.15)))
		var d: float = p.distance_to(j.global_position) if j != null else _rng.randf()
		if d > mejor_d:
			mejor_d = d
			mejor = p
	return mejor


func ia_denunciar() -> void:
	var raiz: Node = get_tree().root
	var ahora: int = Time.get_ticks_msec()
	if ahora - int(raiz.get_meta("llamada_ms", -100000)) > 20000:
		raiz.set_meta("llamada_ms", ahora)
		Juego.exigir_estrellas(1, "Llaman a la policía desde un local")


func percibir(tipo: String, pos: Vector3, intensidad: float, autor: Object) -> void:
	if not muerto and cerebro != null:
		cerebro.percibir(tipo, pos, intensidad, autor)


func recibir_dano(cantidad: float) -> void:
	if muerto:
		return
	vida -= cantidad
	BarraVida.de(self, 2.1, "neutral").mostrar(maxf(vida, 0.0) / vida_max)
	var j: Node3D = cerebro.jugador() if cerebro != null else null
	if not _herido_por_jugador:
		_herido_por_jugador = true
		Juego.exigir_estrellas(1, "Agresión en un local")
	Sonido.tocar(self, "golpe", -4.0)
	if cerebro != null:
		cerebro.me_hirieron(j, cantidad)
		if vida > 0.0:
			cerebro.una_vez("HitReact")
	EstimulosIA.emitir(get_tree(), "violencia", global_position, 16.0, j)
	if vida <= 0.0:
		_morir()


func _morir() -> void:
	muerto = true
	set_meta("muerto", true)
	remove_from_group("danable")
	remove_from_group("oyentes_ia")
	collision_layer = 0
	Juego.exigir_estrellas(3, "Homicidio en un local")
	EstimulosIA.emitir(get_tree(), "muerte", global_position, 20.0, cerebro.jugador() if cerebro != null else null)
	if cerebro != null:
		cerebro.guardar_arma()
	if modelo == null or not Cuerpo.al_morir(self, modelo, Vector3.ZERO, 2.5):
		rotation.x = -PI / 2.0


func _physics_process(delta: float) -> void:
	if muerto or not visible or cerebro == null:
		return
	cerebro.pensar(delta)
	var v: Vector2 = cerebro.vel if cerebro.libre else Vector2.ZERO
	velocity.x = v.x
	velocity.z = v.y
	velocity.y = -0.5 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	var m: Vector2 = cerebro.mirar
	if m == Vector2.ZERO and v.length() > 0.2:
		m = v.normalized()
	if m == Vector2.ZERO and es_empleado() and v.length() < 0.2 and get_parent() is Node3D:
		# Detrás del mostrador mira hacia la puerta.
		var hacia: Vector3 = (get_parent() as Node3D).to_global(salida_local) - global_position
		m = Vector2(hacia.x, hacia.z).normalized()
	if m != Vector2.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-m.x, -m.y), minf(1.0, delta * 8.0))
	if modelo != null:
		cerebro.animar(modelo)


# Abierto / cerrado: el local se vacía (sin choques ni pensar).
func activar(si: bool) -> void:
	visible = si
	collision_layer = 1 if si and not muerto else 0
	set_physics_process(si)
