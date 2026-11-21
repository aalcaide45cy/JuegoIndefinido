# vecino.gd
# -----------------------------------------------------------------------------
# Una persona que duerme en una casa que asaltas. Se despierta por el ruido, la luz de la
# linterna o si le tocas, y entonces reacciona: huye, llama a la policía, se enfrenta con
# los puños, con un objeto (sartén, bate...) o con una pistola si va armada.
# Lo crea casa_asaltable.gd. Las reglas y números están en datos/asaltos.gd.
#
# Si le dejas a cero con un golpe fuerte (arma) muere; con un golpe flojo (puños) queda
# inconsciente un rato. Hacerle daño o matarle sube las estrellas de la policía.
# -----------------------------------------------------------------------------
class_name Vecino
extends CharacterBody3D

enum Estado { DORMIDO, LEVANTANDOSE, REACCIONANDO, INCONSCIENTE, MUERTO, ATENTO }

const VISTA: float = 12.0
const TIEMPO_LEVANTARSE: float = 0.9
const SEGUNDOS_INCONSCIENTE: float = 30.0

var casa: Node = null              # CasaAsaltable a la que pertenece.
var rol: Dictionary = {}           # De Asaltos.ROLES.
var armado: bool = false
var reaccion: String = ""          # huir, llamar, punos, objeto o arma (se elige al despertar).
var sueno: float = 1.0             # Lo profundo que duerme.
var cama: Vector3 = Vector3.ZERO   # Dónde duerme (mundo, a la altura del colchón).
var salida: Vector3 = Vector3.ZERO # La puerta (mundo), para huir.
var estado: int = Estado.DORMIDO
var alerta: float = 0.0
var vida: float = 60.0
var vida_max: float = 60.0
var atento: bool = false           # Despierto en casa (de día o al anochecer): reacciona en cuanto te ve u oye.
var testigo: bool = false          # Te ha visto la cara.
var herido_por_jugador: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _jugador: Node3D = null
var _t_estado: float = 0.0
var _t_golpe: float = 0.0
var _t_denuncia: float = 0.0
var _t_atasco: float = 0.0
var _pos_atasco: Vector3 = Vector3.ZERO
var _llamo: bool = false
var _cuerpo: Node3D
var _zzz: Label3D
var _vel: float = 3.6


func _ready() -> void:
	add_to_group("danable")
	add_to_group("vecinos")
	collision_layer = 1
	collision_mask = 1
	vida_max = float(rol.get("vida", 60.0))
	vida = vida_max
	_vel = float(rol.get("vel", 3.6))
	var forma: CollisionShape3D = CollisionShape3D.new()
	var capsula: CapsuleShape3D = CapsuleShape3D.new()
	capsula.radius = 0.32
	capsula.height = 1.7
	forma.shape = capsula
	forma.position.y = 0.85
	add_child(forma)
	_cuerpo = Node3D.new()
	add_child(_cuerpo)
	var colores: Dictionary = {"padre": Color(0.3, 0.38, 0.55), "madre": Color(0.65, 0.4, 0.5),
			"abuelo": Color(0.5, 0.5, 0.45), "joven": Color(0.35, 0.55, 0.4)}
	Construir.cilindro(_cuerpo, Vector3(0, 0.6, 0), 0.3, 1.2, colores.get(str(rol.get("id", "")), Color(0.4, 0.4, 0.5)), false)
	Construir.esfera(_cuerpo, Vector3(0, 1.42, 0), 0.2, Color(0.78, 0.62, 0.5))
	if str(rol.get("id", "")) == "abuelo":
		Construir.esfera(_cuerpo, Vector3(0, 1.5, 0), 0.2, Color(0.85, 0.85, 0.85), Vector3(1.0, 0.5, 1.0))   # Pelo blanco.
	_zzz = Construir.texto(self, Vector3(0, 1.9, 0), "z Z z", 40, Color(0.7, 0.8, 1.0))
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if atento:
		estado = Estado.ATENTO
		_zzz.visible = false
	else:
		_tumbar()
		collision_mask = 0   # Dormido no choca con la cama (el jugador y los golpes sí le alcanzan).


# Se tumba en la cama (tumbado, a la altura del colchón). Quien lo crea le da la posición.
func _tumbar() -> void:
	_cuerpo.rotation.x = -PI / 2.0
	_cuerpo.position = Vector3(0, 0.3, 0)


func esta_vivo() -> bool:
	return estado != Estado.MUERTO


func despierto() -> bool:
	return estado == Estado.LEVANTANDOSE or estado == Estado.REACCIONANDO


func esta_durmiendo() -> bool:
	return estado == Estado.DORMIDO


# ------------------------------- Despertar -----------------------------------

# Un ruido de intensidad 0 a 1 que sale de "origen" (mundo). "pared": viene de fuera de la casa.
func oir(intensidad: float, origen: Vector3, pared: bool) -> void:
	if estado != Estado.DORMIDO and estado != Estado.ATENTO:
		return
	var d: float = global_position.distance_to(origen)
	var a: float = Asaltos.alerta_por_ruido(intensidad, d, sueno, pared)
	alerta += a * (2.0 if estado == Estado.ATENTO else 1.0)   # Despierto se entera antes.
	if alerta >= (0.5 if estado == Estado.ATENTO else Asaltos.UMBRAL_DESPERTAR):
		despertar("ruido")


# La linterna del jugador le apunta a la cara.
func iluminar(delta: float) -> void:
	if estado != Estado.DORMIDO:
		return
	alerta += Asaltos.GANANCIA_LUZ * delta * float(Asaltos.MULT_DESPERTAR[clampi(Asaltos.dificultad, 0, 3)]) / maxf(sueno, 0.1)
	if alerta >= Asaltos.UMBRAL_DESPERTAR:
		despertar("luz")


func despertar(motivo: String = "") -> void:
	if estado != Estado.DORMIDO and estado != Estado.ATENTO:
		return
	var estaba_tumbado: bool = estado == Estado.DORMIDO
	estado = Estado.LEVANTANDOSE
	_t_estado = 0.0
	_zzz.visible = false
	collision_mask = 1
	reaccion = Asaltos.elegir_reaccion(str(rol.get("id", "padre")), armado, rng)
	if casa != null and casa.has_method("vecino_desperto"):
		casa.vecino_desperto(self, motivo)
	if estaba_tumbado:
		var anim: Tween = create_tween()
		anim.tween_property(_cuerpo, "rotation:x", 0.0, TIEMPO_LEVANTARSE)
		anim.parallel().tween_property(_cuerpo, "position:y", 0.0, TIEMPO_LEVANTARSE)


# ------------------------------- Daño ----------------------------------------

func recibir_dano(cantidad: float) -> void:
	if estado == Estado.MUERTO or estado == Estado.INCONSCIENTE:
		return
	vida -= cantidad
	BarraVida.de(self, 2.1, "neutral").mostrar(maxf(vida, 0.0) / vida_max)
	if not herido_por_jugador:
		herido_por_jugador = true
		Juego.exigir_estrellas(Asaltos.ESTRELLAS_HERIDO, "Agresión en una casa")
		if casa != null and casa.has_method("hubo_violencia"):
			casa.hubo_violencia()
	testigo = true
	if estado == Estado.DORMIDO or estado == Estado.ATENTO:
		despertar("golpe")
	# Al que le pegan y no huye, se enfada: se enfrenta.
	if reaccion in ["huir", "llamar"] and vida > 0.0 and rng.randf() < 0.35:
		reaccion = "arma" if armado else "objeto"
	if vida <= 0.0:
		if cantidad >= Asaltos.DANO_MORTAL:
			_morir()
		else:
			_quedar_inconsciente()


func _quedar_inconsciente() -> void:
	estado = Estado.INCONSCIENTE
	_t_estado = 0.0
	vida = vida_max * 0.2
	velocity = Vector3.ZERO
	_zzz.visible = false
	Juego.avisar("%s queda inconsciente." % rol.get("nombre", "Alguien"))
	var anim: Tween = create_tween()
	anim.tween_property(_cuerpo, "rotation:x", -PI / 2.0, 0.3)
	anim.parallel().tween_property(_cuerpo, "position:y", 0.3, 0.3)


func _morir() -> void:
	estado = Estado.MUERTO
	remove_from_group("danable")
	collision_layer = 0
	_zzz.visible = false
	Juego.exigir_estrellas(Asaltos.ESTRELLAS_MUERTE, "Homicidio en una casa")
	Juego.cambiar_rep("ley", -8)
	Juego.avisar("%s ha muerto. La cosa se ha puesto muy fea." % rol.get("nombre", "Alguien"))
	if casa != null and casa.has_method("hubo_violencia"):
		casa.hubo_violencia()
	var anim: Tween = create_tween()
	anim.tween_property(_cuerpo, "rotation:x", -PI / 2.0, 0.3)
	anim.parallel().tween_property(_cuerpo, "position:y", 0.3, 0.3)


# ------------------------------- Cada fotograma ------------------------------

func _physics_process(delta: float) -> void:
	_t_estado += delta
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	match estado:
		Estado.DORMIDO:
			alerta = maxf(0.0, alerta - Asaltos.BAJADA_ALERTA * delta)
			_zzz.position.y = 1.0 + sin(Time.get_ticks_msec() / 500.0 + position.x) * 0.06
		Estado.ATENTO:
			if _ve_al_jugador():
				testigo = true
				despertar("vista")
		Estado.LEVANTANDOSE:
			_mirar_jugador(delta)
			if _t_estado >= TIEMPO_LEVANTARSE:
				estado = Estado.REACCIONANDO
				_t_estado = 0.0
				if reaccion == "arma":
					Juego.avisar("¡%s coge una pistola!" % rol.get("nombre", "Alguien"))
				elif reaccion == "huir":
					Juego.avisar("¡%s sale corriendo gritando!" % rol.get("nombre", "Alguien"))
		Estado.REACCIONANDO:
			_reaccionar(delta)
		Estado.INCONSCIENTE:
			if _t_estado >= SEGUNDOS_INCONSCIENTE:
				estado = Estado.REACCIONANDO
				_t_estado = 0.0
				reaccion = "huir"
				_t_denuncia = 0.0
				var anim: Tween = create_tween()
				anim.tween_property(_cuerpo, "rotation:x", 0.0, 0.6)
				anim.parallel().tween_property(_cuerpo, "position:y", 0.0, 0.6)
	if estado == Estado.MUERTO or estado == Estado.DORMIDO or estado == Estado.INCONSCIENTE:
		return   # Tumbados: no se mueven ni chocan.
	velocity.y -= 20.0 * delta
	if estado == Estado.LEVANTANDOSE or estado == Estado.ATENTO:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


func _ve_al_jugador() -> bool:
	if _jugador == null:
		return false
	var ojos: Vector3 = global_position + Vector3(0, 1.5, 0)
	var objetivo: Vector3 = _jugador.global_position + Vector3(0, 1.1, 0)
	var d: float = ojos.distance_to(objetivo)
	if d > VISTA:
		return false
	var choque: Dictionary = Combate.rayo(get_world_3d(), ojos, objetivo - ojos, d + 0.4, [get_rid()])
	if choque.is_empty():
		return true
	var c = choque["collider"]
	return c is Node and (c as Node).is_in_group("jugador")


func _mirar_jugador(delta: float) -> void:
	if _jugador == null:
		return
	var al: Vector3 = _jugador.global_position - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-al.x, -al.z), minf(1.0, delta * 8.0))


func _ir_a(destino: Vector3, velocidad: float, delta: float) -> float:
	var al: Vector3 = destino - global_position
	al.y = 0.0
	var dist: float = al.length()
	if dist > 0.2:
		var dir: Vector3 = al / dist
		velocity.x = dir.x * velocidad
		velocity.z = dir.z * velocidad
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 10.0))
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	return dist


func _reaccionar(delta: float) -> void:
	var vio: bool = _ve_al_jugador()
	if vio and not testigo:
		testigo = true
		if casa != null and casa.has_method("testigo_te_vio"):
			casa.testigo_te_vio(self)
	_t_golpe -= delta
	# Si lleva un rato intentando andar sin avanzar, se acobarda en el sitio.
	if velocity.length() > 0.5:
		_t_atasco += delta
		if _t_atasco > 1.6:
			if global_position.distance_to(_pos_atasco) < 0.25 and reaccion != "llamar":
				reaccion = "llamar"
			_t_atasco = 0.0
			_pos_atasco = global_position
	match reaccion:
		"huir":
			_huir(delta)
		"llamar":
			_llamar(delta)
		_:
			_pelear(delta, vio)
	# Un testigo que no acaba de ser atendido termina avisando a la policía.
	if testigo and not _llamo and reaccion != "llamar":
		_t_denuncia += delta
		var espera: float = Asaltos.SEGUNDOS_HASTA_DENUNCIA * (0.7 if reaccion == "huir" else 3.0)
		if _t_denuncia >= espera:
			_denunciar()


func _huir(delta: float) -> void:
	var fuera: bool = casa != null and casa.has_method("esta_fuera") and casa.esta_fuera(global_position)
	if not fuera:
		_ir_a(salida, _vel * 1.25, delta)
	else:
		# Ya en la calle: sigue corriendo lejos de ti.
		var lejos: Vector3 = global_position + (global_position - (_jugador.global_position if _jugador != null else salida))
		_ir_a(lejos, _vel * 1.25, delta)
		if _jugador != null and global_position.distance_to(_jugador.global_position) > 30.0:
			_denunciar()
			velocity.x = 0.0
			velocity.z = 0.0


func _llamar(delta: float) -> void:
	# Se encoge junto a la cama y marca. Si estás cerca, no le dejas.
	_cuerpo.scale.y = lerpf(_cuerpo.scale.y, 0.7, minf(1.0, delta * 6.0))
	if global_position.distance_to(cama + Vector3(0.9, 0, 0)) > 2.5:
		_ir_a(cama + Vector3(0.9, 0, 0.0), _vel * 0.6, delta)
	else:
		_mirar_jugador(delta)
	var cerca: bool = _jugador != null and global_position.distance_to(_jugador.global_position) < 3.0
	if not cerca:
		_t_denuncia += delta
		if _t_denuncia >= Asaltos.SEGUNDOS_HASTA_DENUNCIA:
			_denunciar()


func _pelear(delta: float, vio: bool) -> void:
	if _jugador == null:
		return
	var arma: Dictionary = Asaltos.ARMAS_OCUPANTE.get(reaccion, Asaltos.ARMAS_OCUPANTE["punos"])
	var al: Vector3 = _jugador.global_position - global_position
	var plano: float = Vector2(al.x, al.z).length()
	_mirar_jugador(delta)
	var alcance: float = float(arma["alcance"])
	# Los que tienen pistola mantienen distancia; los demás se acercan.
	var ideal: float = 6.0 if reaccion == "arma" else alcance * 0.8
	if plano > ideal + 0.5 and (vio or plano < 25.0):
		_ir_a(_jugador.global_position, _vel, delta)
	elif reaccion == "arma" and plano < 3.0:
		_ir_a(global_position - al, _vel * 0.7, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if _t_golpe > 0.0 or absf(al.y) > 2.2:
		return
	if reaccion == "arma":
		if vio and plano <= alcance:
			_t_golpe = float(arma["pausa"])
			_disparar(plano)
	elif plano <= alcance:
		_t_golpe = float(arma["pausa"])
		_golpear(arma)


func _golpear(arma: Dictionary) -> void:
	var dano: float = float(arma["dano"]) * float(Asaltos.MULT_DANO[clampi(Asaltos.dificultad, 0, 3)])
	if dano <= 0.0:
		return
	Juego.cambiar_vida(-dano)   # Si estás esquivando (X) no te toca.
	if Juego.invulnerable <= 0.0:
		Juego.avisar("¡%s te pega con %s!" % [rol.get("nombre", "Alguien"), arma["nombre"]])


func _disparar(distancia: float) -> void:
	Sonido.tocar(self, "disparo")
	var destello: OmniLight3D = Construir.luz(self, Vector3(0, 1.3, -0.5), Color(1.0, 0.8, 0.4), 3.0, 4.0)
	get_tree().create_timer(0.08).timeout.connect(destello.queue_free)
	# Probabilidad de acertar: baja con la distancia, y si vas agachado o a oscuras.
	var p: float = clampf(0.7 - distancia * 0.025, 0.15, 0.7)
	if _jugador != null and _jugador.get("agachado") == true:
		p *= 0.7
	if _jugador != null and _jugador.get("en_sombra") == true:
		p *= 0.8
	if Juego.invulnerable > 0.0:
		p = 0.0
	var dano: float = float(Asaltos.ARMAS_OCUPANTE["arma"]["dano"]) * float(Asaltos.MULT_DANO[clampi(Asaltos.dificultad, 0, 3)])
	if rng.randf() < p:
		Juego.cambiar_vida(-dano)
		Juego.avisar("¡%s te dispara y te da!" % rol.get("nombre", "Alguien"))
	else:
		Juego.avisar("¡Un disparo pasa muy cerca!")
	# Los tiros se oyen: la policía se entera.
	Juego.exigir_estrellas(Asaltos.ESTRELLAS_ALLANAMIENTO + 1, "Tiroteo en una casa")


func _denunciar() -> void:
	if _llamo:
		return
	_llamo = true
	if casa != null and casa.has_method("denunciar"):
		casa.denunciar(self)
