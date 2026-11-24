# vecino.gd
# -----------------------------------------------------------------------------
# Una persona que vive en una casa. De noche duerme; al anochecer, por la mañana o si está en
# casa de día, va de una habitación a otra (cocina, salón, dormitorio...) y se queda un rato.
# Se despierta (o se entera de que hay alguien) por el ruido, la linterna, si te ve o si le tocas.
#
# Desde noviembre de 2026 piensa con el mismo cerebro que los peatones (PersonaIA, árbol
# "vecino" en ia/arboles_ia.gd): según su carácter y la situación puede huir por la puerta,
# esconderse en otra habitación y llamar a la policía, pelear a puñetazos esquivando tus golpes,
# coger un objeto (pala, cuchillo), sacar una pistola y disparar moviéndose, suplicar si le
# apuntas, cubrirse si hay tiros, o socorrer a un familiar herido. La reacción inicial sale de
# Asaltos.elegir_reaccion (huir, llamar, punos, objeto, arma) y se traduce en su carácter, pero
# luego cambia sola: si le das una paliza al valiente, huirá; si hieres a su familia, se enfada.
# Se mueve por la casa pasando por las puertas (CasaAsaltable.ruta_mundo) y esquiva muebles.
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
var cerebro: PersonaIA = null
var modelo: Node3D = null          # Persona animada (null si faltan los modelos: queda el muñeco _cuerpo).

var _jugador: Node3D = null
var _t_estado: float = 0.0
var _t_denuncia: float = 0.0
var _llamo: bool = false
var _cuerpo: Node3D
var _zzz: Label3D
var _vel: float = 3.6
var _reaccion_puesta: String = "#"


func _ready() -> void:
	add_to_group("danable")
	add_to_group("vecinos")
	add_to_group("oyentes_ia")
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
	cerebro = PersonaIA.new(self, "vecino", int(rng.seed) + 77)
	cerebro.armado = armado
	cerebro.vel_correr = _vel * 1.25
	cerebro.vel_andar = clampf(_vel * 0.35, 0.8, 1.4)
	_cuerpo = Node3D.new()
	add_child(_cuerpo)
	var id_rol: String = str(rol.get("id", ""))
	var mujer: bool = id_rol == "madre" or (id_rol == "joven" and rng.randf() < 0.5)
	modelo = Assets.persona("Superhero_Female_FullBody" if mujer else "Superhero_Male_FullBody",
			cerebro.arma_modelo if armado else "", "Idle")
	if modelo != null:
		PersonaIA._mostrar_arma_en(modelo, "")
		_cuerpo.add_child(modelo)
		if id_rol == "abuelo":
			modelo.scale = Vector3.ONE * 0.94
	else:
		var colores: Dictionary = {"padre": Color(0.3, 0.38, 0.55), "madre": Color(0.65, 0.4, 0.5),
				"abuelo": Color(0.5, 0.5, 0.45), "joven": Color(0.35, 0.55, 0.4)}
		Construir.cilindro(_cuerpo, Vector3(0, 0.6, 0), 0.3, 1.2, colores.get(id_rol, Color(0.4, 0.4, 0.5)), false)
		Construir.esfera(_cuerpo, Vector3(0, 1.42, 0), 0.2, Color(0.78, 0.62, 0.5))
		if id_rol == "abuelo":
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
	if modelo != null:
		Assets.poner_animacion(modelo, "Idle", 0.4)


func esta_vivo() -> bool:
	return estado != Estado.MUERTO


func despierto() -> bool:
	return estado == Estado.LEVANTANDOSE or estado == Estado.REACCIONANDO


func esta_durmiendo() -> bool:
	return estado == Estado.DORMIDO


# --------------------------- Lo que pide el cerebro ---------------------------

func ia_vida() -> float:
	return clampf(vida / maxf(vida_max, 1.0), 0.0, 1.0)


func ia_dentro() -> bool:
	return casa != null and casa.has_method("esta_dentro") and casa.esta_dentro(global_position)


func ia_salida() -> Vector3:
	return salida


func ia_ruta(destino: Vector3) -> Array:
	if casa != null and casa.has_method("ruta_mundo"):
		return casa.ruta_mundo(global_position, destino)
	return [destino]


func ia_punto_rutina() -> Vector3:
	if casa != null and casa.has_method("punto_en_sala"):
		return casa.punto_en_sala(rng.randi() % maxi(1, casa.num_salas()))
	return global_position + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))


# Para esconderse: la habitación más lejos del intruso.
func ia_escondite() -> Vector3:
	if casa == null or not casa.has_method("punto_en_sala"):
		return cama + Vector3(0.9, 0, 0)
	var j: Node3D = _jugador
	var mejor: Vector3 = cama
	var mejor_d: float = -1.0
	for i in casa.num_salas():
		var p: Vector3 = casa.punto_en_sala(i)
		var d: float = p.distance_to(j.global_position) if j != null else rng.randf()
		if d > mejor_d:
			mejor_d = d
			mejor = p
	return mejor


func ia_denunciar() -> void:
	_denunciar()


# Cada disparo suyo se oye en el barrio: la policía se entera.
func ia_disparo_hecho() -> void:
	Juego.exigir_estrellas(Asaltos.ESTRELLAS_ALLANAMIENTO + 1, "Tiroteo en una casa")


func percibir(tipo: String, pos: Vector3, intensidad: float, autor: Object) -> void:
	if estado == Estado.MUERTO or estado == Estado.INCONSCIENTE:
		return
	if estado == Estado.DORMIDO or estado == Estado.ATENTO:
		# Un disparo o una explosión despiertan a cualquiera; los gritos, según lo cerca.
		if tipo in ["disparo", "explosion"] or (tipo in ["grito", "violencia"] and intensidad > 0.4):
			oir(clampf(intensidad * 1.5, 0.0, 1.0), pos, not ia_dentro())
	if cerebro != null:
		cerebro.percibir(tipo, pos, intensidad, autor)


# La reacción de Asaltos se convierte en carácter (luego el cerebro decide momento a momento).
func _aplicar_reaccion() -> void:
	_reaccion_puesta = reaccion
	if cerebro == null:
		return
	var mult: float = float(Asaltos.MULT_DANO[clampi(Asaltos.dificultad, 0, 3)])
	var armas: Dictionary = Asaltos.ARMAS_OCUPANTE
	cerebro.dano_puno = float(armas["punos"]["dano"]) * mult
	cerebro.dano_mano = float(armas["objeto"]["dano"]) * mult
	cerebro.dano_bala = float(armas["arma"]["dano"]) * mult
	cerebro.arma_mano = ""
	match reaccion:
		"huir":
			cerebro.ajustar({"valentia": 0.12, "agresividad": 0.05, "civismo": 0.4})
			cerebro.miedo = 1.0
			cerebro.ira = 0.0
		"llamar":
			cerebro.ajustar({"valentia": 0.15, "agresividad": 0.05, "civismo": 1.0})
			cerebro.miedo = maxf(cerebro.miedo, 0.7)
			cerebro.ira = 0.0
		"punos":
			cerebro.ajustar({"valentia": 0.9, "agresividad": 0.9, "agilidad": rng.randf_range(0.4, 0.9)})
			cerebro.ira = 1.0
			cerebro.miedo = 0.0
		"objeto":
			cerebro.ajustar({"valentia": 0.9, "agresividad": 0.85})
			cerebro.arma_mano = ["Shovel", "Knife"][rng.randi() % 2]
			cerebro._mostrar_arma(cerebro.arma_mano)
			cerebro.ira = 1.0
			cerebro.miedo = 0.0
		"arma":
			cerebro.armado = true
			cerebro.ajustar({"valentia": 0.9, "agresividad": 0.7})
			cerebro.ira = 1.0
			cerebro.miedo = 0.0
	cerebro.amenaza = _jugador
	if _jugador != null:
		cerebro.amenaza_pos = _jugador.global_position
	cerebro.t_amenaza = cerebro.reloj


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
	if cerebro != null:
		cerebro.decir("intruso", 0.8)


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
	if cerebro != null:
		cerebro.me_hirieron(_jugador, cantidad)
		if vida > 0.0 and modelo != null:
			cerebro.una_vez("HitReact")
	# Su familia lo ve: se asusta o se enfada.
	EstimulosIA.emitir(get_tree(), "violencia", global_position, 14.0, _jugador)
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
	set_meta("muerto", true)   # Para los demás cuenta como "caído" (le socorren); se quita al despertar.
	Juego.avisar("%s queda inconsciente." % rol.get("nombre", "Alguien"))
	if cerebro != null:
		cerebro.guardar_arma()
	var anim: Tween = create_tween()
	anim.tween_property(_cuerpo, "rotation:x", -PI / 2.0, 0.3)
	anim.parallel().tween_property(_cuerpo, "position:y", 0.3, 0.3)


func _morir() -> void:
	estado = Estado.MUERTO
	remove_from_group("danable")
	remove_from_group("oyentes_ia")
	set_meta("muerto", true)
	collision_layer = 0
	_zzz.visible = false
	Juego.exigir_estrellas(Asaltos.ESTRELLAS_MUERTE, "Homicidio en una casa")
	Juego.cambiar_rep("ley", -8)
	Juego.avisar("%s ha muerto. La cosa se ha puesto muy fea." % rol.get("nombre", "Alguien"))
	if casa != null and casa.has_method("hubo_violencia"):
		casa.hubo_violencia()
	EstimulosIA.emitir(get_tree(), "muerte", global_position, 20.0, _jugador)
	# Cae con física (ragdoll si tiene modelo con huesos; si no, el muñeco entero).
	var m: Node3D = Cuerpo.modelo_de(self)
	if Cuerpo.al_morir(self, m if m != null else _cuerpo, Vector3.ZERO, 2.5):
		return
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
			else:
				_mover_con_cerebro(delta)   # Hace su vida por la casa.
				return
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
			return
		Estado.INCONSCIENTE:
			if _t_estado >= SEGUNDOS_INCONSCIENTE:
				estado = Estado.REACCIONANDO
				_t_estado = 0.0
				reaccion = "huir"
				_t_denuncia = 0.0
				remove_meta("muerto")
				var anim: Tween = create_tween()
				anim.tween_property(_cuerpo, "rotation:x", 0.0, 0.6)
				anim.parallel().tween_property(_cuerpo, "position:y", 0.0, 0.6)
	if estado == Estado.MUERTO or estado == Estado.DORMIDO or estado == Estado.INCONSCIENTE:
		return   # Tumbados: no se mueven ni chocan.
	velocity.y -= 20.0 * delta
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	if modelo != null:
		Assets.animar_por_velocidad(modelo, 0.0)


func _ve_al_jugador() -> bool:
	if _jugador == null:
		return false
	var ojos: Vector3 = global_position + Vector3(0, 1.5, 0)
	var objetivo: Vector3 = _jugador.global_position + Vector3(0, 1.1, 0)
	var d: float = ojos.distance_to(objetivo)
	if d > VISTA:
		return false
	# Solo ve lo que tiene delante (un campo de visión de ~220º) salvo si estás pegado.
	var al: Vector3 = (objetivo - ojos).normalized()
	if d > 2.0 and (-global_basis.z).dot(al) < -0.35:
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


# Aplica lo que decide el cerebro: velocidad (con choques reales) y hacia dónde mira.
func _mover_con_cerebro(delta: float) -> void:
	if cerebro == null:
		return
	collision_mask = 1   # Despierto choca con todo (dormido no, para no pelearse con la cama).
	cerebro.pensar(delta)
	var v: Vector2 = cerebro.vel if cerebro.libre else Vector2.ZERO
	velocity.x = v.x
	velocity.z = v.y
	velocity.y -= 20.0 * delta
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = -0.5
	move_and_slide()
	var m: Vector2 = cerebro.mirar
	if m == Vector2.ZERO and v.length() > 0.2:
		m = v.normalized()
	if m != Vector2.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-m.x, -m.y), minf(1.0, delta * 9.0))
	if modelo != null:
		cerebro.animar(modelo)


func _reaccionar(delta: float) -> void:
	if reaccion != _reaccion_puesta:
		_aplicar_reaccion()
	var vio: bool = _ve_al_jugador()
	if vio and not testigo:
		testigo = true
		if casa != null and casa.has_method("testigo_te_vio"):
			casa.testigo_te_vio(self)
	# Mientras sigas cerca (o dentro de su casa) no se olvida de ti.
	if cerebro != null and _jugador != null:
		var cerca: bool = global_position.distance_to(_jugador.global_position) < 25.0
		if cerca or vio:
			cerebro.amenaza = _jugador
			cerebro.amenaza_pos = _jugador.global_position
			if vio:
				cerebro.t_amenaza = cerebro.reloj
			match reaccion:
				"huir", "llamar":
					cerebro.miedo = maxf(cerebro.miedo, 0.45)
				_:
					if cerebro.vida() > 0.3:
						cerebro.ira = maxf(cerebro.ira, 0.5)
	_mover_con_cerebro(delta)
	# El que llama a la policía lo consigue si no estás a su lado.
	var a_su_lado: bool = _jugador != null and global_position.distance_to(_jugador.global_position) < 3.0
	if reaccion == "llamar" and not a_su_lado:
		_t_denuncia += delta
		if _t_denuncia >= Asaltos.SEGUNDOS_HASTA_DENUNCIA:
			_denunciar()
	# Un testigo que no acaba de ser atendido termina avisando a la policía.
	elif testigo and not _llamo:
		_t_denuncia += delta
		var espera: float = Asaltos.SEGUNDOS_HASTA_DENUNCIA * (0.7 if reaccion == "huir" else 3.0)
		if _t_denuncia >= espera:
			_denunciar()


func _denunciar() -> void:
	if _llamo:
		return
	_llamo = true
	if cerebro != null:
		cerebro.llamo_policia = true
	if casa != null and casa.has_method("denunciar"):
		casa.denunciar(self)
