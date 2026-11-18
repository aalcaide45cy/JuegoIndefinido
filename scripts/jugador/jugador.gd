# jugador.gd
# -----------------------------------------------------------------------------
# El alquimista que controlas. Empieza en primera persona; con V cambias a
# tercera persona (cámara detrás del hombro) y viceversa.
#
#   WASD / flechas  moverse        Ratón   mirar
#   Shift           correr         Espacio saltar
#   E               usar           1-9 / rueda   elegir objeto de la barra rápida
#   V               primera/tercera persona   TAB  inventario   F1  administrador
#   Esc             soltar el ratón
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

const Economia = preload("res://scripts/datos/economia.gd")
const Aspecto = preload("res://scripts/jugador/aspecto.gd")

# Si el jugador baja de esta altura (metros), reaparece en la plaza.
const ALTURA_MINIMA: float = -12.0
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
var _detenido: bool = false
var _suelo_pendiente: bool = false   # Tras un viaje rápido: esperando a que se cargue el suelo.
var _t_suelo_pendiente: float = 0.0
var vehiculo = null   # El vehículo que conduces ahora (o null). Ver vehiculo.gd.
var _choque: CollisionShape3D
var _primera_antes: bool = true
var _ropa: Node3D = null       # El aspecto puesto (se rehace al cambiarlo en la ventana de aspecto).
var _modelo_anim: Node3D = null   # Si el cuerpo es un modelo con animaciones, aquí está.
var _pivote: Node3D
var _t_camara: float = 0.0
var _brazo: SpringArm3D
var _camara: Camera3D
var _mano: Node3D = null       # El objeto que llevas en la mano (lo dibuja ModeloMano).
var _id_mano: String = "~"     # Qué objeto se está dibujando ("~" = todavía ninguno).
var _enfriamiento: float = 0.0   # Segundos hasta poder atacar otra vez.
var _zoom: bool = false          # Mira del francotirador.
var _muerto: bool = false
var agachado: bool = false       # Mantén C o Ctrl: te ven menos y vas más despacio.
var en_sombra: bool = false      # De noche y lejos de las farolas.


func _ready() -> void:
	add_to_group("jugador")
	_crear_cuerpo()
	_crear_camara()
	_aplicar_camara()
	if not Juego.menu_abierto:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Juego.cambio.connect(_actualizar_mano)
	_actualizar_mano()


# ------------------------------- Ratón y teclas -------------------------------

func _unhandled_input(evento: InputEvent) -> void:
	if Juego.menu_abierto:
		return  # Con una ventana abierta, el ratón y las teclas son para la ventana.
	var raton_capturado: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if vehiculo != null and evento.is_action_pressed("usar"):
		vehiculo.bajar()
		get_viewport().set_input_as_handled()
		return
	if evento is InputEventMouseMotion and raton_capturado:
		var movimiento: InputEventMouseMotion = evento
		_giro -= movimiento.relative.x * SENSIBILIDAD_RATON
		_inclinacion -= movimiento.relative.y * SENSIBILIDAD_RATON
		_inclinacion = clampf(_inclinacion, -1.3, 1.0)
	elif Juego.modo_volar and evento is InputEventMouseButton and evento.pressed and raton_capturado \
			and (evento.button_index == MOUSE_BUTTON_WHEEL_UP or evento.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		# Volando, la rueda cambia la velocidad (hasta 3000 m/s); un 15 % por muesca.
		var factor: float = 1.15 if evento.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
		Juego.velocidad_vuelo = clampf(Juego.velocidad_vuelo * factor,
				Juego.VELOCIDAD_VUELO_MIN, Juego.VELOCIDAD_VUELO_MAX)
		Juego.avisar("Velocidad de vuelo: %d m/s (%d km/h)" % [int(Juego.velocidad_vuelo), int(Juego.velocidad_vuelo * 3.6)])
		get_viewport().set_input_as_handled()
	elif evento is InputEventMouseButton and evento.pressed and raton_capturado \
			and (evento.button_index == MOUSE_BUTTON_WHEEL_UP or evento.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var paso: int = -1 if evento.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		Juego.seleccionar(Juego.seleccion + paso)
	elif evento is InputEventMouseButton and evento.pressed and raton_capturado \
			and evento.button_index == MOUSE_BUTTON_LEFT:
		_atacar()
	elif evento is InputEventMouseButton and evento.pressed and raton_capturado \
			and evento.button_index == MOUSE_BUTTON_RIGHT:
		_alternar_zoom()
	elif _tecla_barra(evento) >= 0:
		Juego.seleccionar(_tecla_barra(evento))
	elif evento.is_action_pressed("recargar"):
		_recargar()
	elif evento.is_action_pressed("colocar") and not _bloqueado:
		var texto: String = Colocable.colocar_desde(self, Juego.id_en_mano())
		if texto != "":
			Juego.avisar(texto)
	elif evento is InputEventMouseButton and evento.pressed and not raton_capturado:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # Clic para volver a jugar.
	elif evento.is_action_pressed("liberar_raton"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif evento.is_action_pressed("cambiar_camara"):
		primera_persona = not primera_persona
		_aplicar_camara()
	elif evento.is_action_pressed("usar") and objetivo != null and not _bloqueado:
		objetivo.usar(self)


# Devuelve 0-8 si se ha pulsado una tecla del 1 al 9, o -1 si no.
func _tecla_barra(evento: InputEvent) -> int:
	for i in Juego.TAM_BARRA:
		if evento.is_action_pressed("barra_%d" % (i + 1)):
			return i
	return -1


# A qué distancia (en metros) te pueden ver los guardias. Baja si te agachas o
# estás en la sombra, y sube si corres.
func radio_deteccion() -> float:
	var radio: float = 14.0
	if agachado:
		radio *= 0.45
	elif Input.is_action_pressed("correr") and velocity.length() > 3.0:
		radio *= 1.3
	if en_sombra:
		radio *= 0.6
	radio *= clampf(1.0 - Juego.mod("sigilo"), 0.3, 1.8)   # Efectos de sigilo / paranoia.
	radio *= Clima.sigilo()   # Con niebla y lluvia te ven menos.
	return maxf(radio, 3.0)


# true si hay una farola o luz encendida cerca (entonces no estás en la sombra).
func _hay_luz_cerca() -> bool:
	for nodo in get_tree().get_nodes_in_group("luces_noche"):
		var foco: OmniLight3D = nodo as OmniLight3D
		if foco != null and foco.light_energy > 0.3 \
				and foco.global_position.distance_to(global_position + Vector3(0, 1.5, 0)) < foco.omni_range * 0.8:
			return true
	return false


# --------------------------------- Movimiento ---------------------------------

var _t_sombra: float = 0.0


func _physics_process(delta: float) -> void:
	_enfriamiento -= delta
	if Juego.vida <= 0.0 and not _muerto:
		_morir()
	# Red de seguridad: si por algún hueco se cayera del mundo, vuelve a la plaza.
	if global_position.y < ALTURA_MINIMA:
		_reaparecer_en_la_plaza()
	# El rifle dispara en ráfaga mientras mantienes el botón.
	if _enfriamiento <= 0.0 and not Juego.menu_abierto and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var datos_mano: Dictionary = _datos_mano()
		if datos_mano.get("forma", "") == "rifle":
			_atacar()
	_pivote.rotation.y = _giro
	_brazo.rotation.x = _inclinacion
	if vehiculo != null:
		# Conduciendo: el vehículo nos lleva (vehiculo.gd). Aquí solo se mueve la cámara.
		velocity = Vector3.ZERO
		objetivo = null
		return

	_actualizar_modo_volar()
	if Juego.modo_volar:
		_volar(delta)
		return

	if _suelo_pendiente:
		_esperar_suelo(delta)
		return

	# Gravedad.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Dirección según las teclas, relativa a hacia dónde mira la cámara.
	var teclas: Vector2 = Vector2.ZERO
	if not _bloqueado and not Juego.menu_abierto:
		teclas = Input.get_vector("izquierda", "derecha", "adelante", "atras")
		if Input.is_action_just_pressed("saltar") and is_on_floor():
			velocity.y = FUERZA_SALTO * (1.0 + Juego.mod("salto"))
	var direccion: Vector3 = Basis(Vector3.UP, _giro) * Vector3(teclas.x, 0.0, teclas.y)

	agachado = Input.is_action_pressed("agacharse") and not Juego.menu_abierto
	_t_sombra -= delta
	if _t_sombra <= 0.0:   # Solo 4 veces por segundo: recorrer todas las luces cada frame es caro.
		_t_sombra = 0.25
		en_sombra = Juego.es_de_noche() and not _hay_luz_cerca()
	var altura_ojos: float = 1.05 if agachado else 1.6
	if vehiculo != null:
		altura_ojos = 2.6   # Conduciendo la cámara va más alta: no se tapa con el techo ni con otros coches.
		_t_camara -= delta
		if _t_camara <= 0.0:
			_t_camara = 0.4
			_excluir_en_camara()
	_pivote.position.y = lerpf(_pivote.position.y, altura_ojos, minf(1.0, delta * 10.0))
	_cuerpo.scale.y = lerpf(_cuerpo.scale.y, 0.7 if agachado else 1.0, minf(1.0, delta * 10.0))
	var velocidad: float = VELOCIDAD_CORRER if (Input.is_action_pressed("correr") and Juego.sin_correr <= 0.0) else VELOCIDAD_ANDAR
	if agachado:
		velocidad = VELOCIDAD_ANDAR * 0.5
	velocidad *= clampf(1.0 + Juego.mod("velocidad"), 0.3, 2.5)   # Efectos de velocidad / lentitud.
	velocidad *= Clima.velocidad()   # La tormenta frena un poco.
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

	if _modelo_anim != null:
		var plano: float = Vector2(velocity.x, velocity.z).length()
		Assets.poner_animacion(_modelo_anim, "Idle" if plano < 0.3 else ("Run" if plano > 5.0 else "Walk"))
	_buscar_objetivo()


# Modo volar (se activa en el panel de administrador, F1): sin gravedad ni choques.
var _volando_antes: bool = false
var _mascara_antes: int = 1
var _capa_antes: int = 1


func _actualizar_modo_volar() -> void:
	if Juego.modo_volar == _volando_antes:
		return
	_volando_antes = Juego.modo_volar
	if Juego.modo_volar:
		_mascara_antes = collision_mask
		_capa_antes = collision_layer
		collision_mask = 0   # Atraviesa edificios y suelo: a gran velocidad no se queda atascado.
		collision_layer = 0
		_suelo_pendiente = false
	else:
		collision_mask = _mascara_antes
		collision_layer = _capa_antes
		velocity = Vector3.ZERO


func _volar(delta: float) -> void:
	var mando: Vector3 = Vector3.ZERO
	if not _bloqueado and not Juego.menu_abierto:
		var teclas: Vector2 = Input.get_vector("izquierda", "derecha", "adelante", "atras")
		# Hacia donde mira la cámara (incluida la inclinación): W vuela hacia lo que ves.
		var mira: Basis = _camara.global_basis
		mando = mira.x * teclas.x + (-mira.z) * (-teclas.y)
		if Input.is_action_pressed("saltar"):
			mando += Vector3.UP
		if Input.is_action_pressed("agacharse"):
			mando += Vector3.DOWN
	var rapidez: float = Juego.velocidad_vuelo
	if Input.is_action_pressed("correr"):
		rapidez *= 3.0   # Shift: triple.
	var deseada: Vector3 = mando.limit_length(1.0) * rapidez
	velocity = velocity.lerp(deseada, minf(1.0, delta * 8.0))
	global_position += velocity * delta
	if primera_persona:
		_cuerpo.rotation.y = _giro
	objetivo = null
	agachado = false


func _aplicar_camara() -> void:
	_brazo.spring_length = 0.0 if primera_persona else DISTANCIA_CAMARA
	_brazo.position.x = 0.0 if primera_persona else DESPLAZAMIENTO_HOMBRO
	_cuerpo.visible = not primera_persona
	_colocar_mano()


# Dibuja de nuevo la mano solo si ha cambiado el objeto elegido.
func _actualizar_mano() -> void:
	var id: String = Juego.id_en_mano()
	if id == _id_mano:
		return
	_id_mano = id
	if _mano != null:
		_mano.queue_free()
		_mano = null
	_mano = ModeloMano.crear(id)
	_colocar_mano()
	_zoom = false
	_camara.fov = 70.0


# ------------------------- Combate: golpear, disparar, explotar ----------------

func _datos_mano() -> Dictionary:
	var id: String = Juego.id_en_mano()
	return {} if id == "" else Juego.DatosObjetos.datos(id)


# Clic izquierdo: ataca con lo que lleves en la mano (o usa comida y medicinas).
func _atacar() -> void:
	if _enfriamiento > 0.0 or _muerto or vehiculo != null:
		return
	var casilla = Juego.en_mano()
	if casilla == null:
		return
	var datos: Dictionary = Juego.DatosObjetos.datos(casilla["id"])
	match datos["tipo"]:
		"arma_cc":
			_golpear(datos)
		"arma_fuego":
			_disparar(casilla, datos)
		"explosivo":
			_usar_explosivo(casilla, datos)
		"herramienta":
			if casilla["id"] == "detonador":
				_enfriamiento = 0.5
				var n: int = Combate.detonar_c4(get_tree())
				Juego.avisar("¡BUM! %d carga(s) detonada(s)." % n if n > 0 else "No hay cargas colocadas.")
		_:
			Juego.usar_en_mano()


func _origen() -> Vector3:
	return global_position + Vector3(0, 1.5, 0)


func _adelante() -> Vector3:
	return -_camara.global_basis.z


func _escena() -> Node3D:
	return get_parent() as Node3D


# Un pequeño vaivén de la mano para que se note el golpe o el disparo.
func _animar_mano(retroceso: float) -> void:
	if _mano == null:
		return
	var base: Vector3 = _mano.position
	var animacion: Tween = create_tween()
	animacion.tween_property(_mano, "position", base + Vector3(0, 0.03, retroceso), 0.05)
	animacion.tween_property(_mano, "position", base, 0.12)


# Un destello de luz de un instante en la boca del arma.
func _fogonazo() -> void:
	var luz: OmniLight3D = OmniLight3D.new()
	luz.light_color = Color(1.0, 0.8, 0.4)
	luz.light_energy = 3.0
	luz.omni_range = 9.0
	luz.position = _origen() + _adelante() * 1.2
	_escena().add_child(luz)
	get_tree().create_timer(0.06).timeout.connect(luz.queue_free)


# Cuánto daño haces según tus efectos (Fuerza, Temblor...).
func _mult_dano() -> float:
	return clampf(1.0 + Juego.mod("dano_hecho"), 0.2, 3.0)


func _golpear(datos: Dictionary) -> void:
	_enfriamiento = 0.45
	_animar_mano(-0.25)
	var choque: Dictionary = Combate.rayo(get_world_3d(), _origen(), _adelante(), 2.4, [get_rid()])
	if choque.is_empty():
		return
	var cosa = choque["collider"]
	if cosa != null and cosa.has_method("recibir_dano"):
		cosa.recibir_dano(float(datos["dano"]) * _mult_dano())


func _disparar(casilla: Dictionary, datos: Dictionary) -> void:
	if casilla.get("balas", 0) <= 0:
		_enfriamiento = 0.3
		Juego.avisar("Sin balas en el cargador. Pulsa R para recargar.")
		return
	casilla["balas"] -= 1
	Sonido.tocar(self, "disparo")
	var forma: String = datos["forma"]
	var pausa: Dictionary = {"pistola": 0.28, "escopeta": 0.9, "rifle": 0.11, "francotirador": 1.4,
			"lanzagranadas": 1.0}
	_enfriamiento = pausa.get(forma, 0.4)
	_animar_mano(0.12)
	_fogonazo()
	_inclinacion = clampf(_inclinacion + 0.015, -1.3, 1.0)   # Retroceso.
	if forma == "lanzagranadas":
		Combate.lanzar(_escena(), _origen() + _adelante() * 0.8, _adelante() * 26.0, 4.0, true,
				6.0, float(datos["dano"]), Color(0.3, 0.35, 0.25), 0.1)
	else:
		var perdigones: int = int(datos.get("perdigones", 1))
		var dispersion: float = 0.07 if perdigones > 1 else (0.002 if _zoom else 0.008)
		for i in perdigones:
			var dir: Vector3 = _adelante() + _camara.global_basis.x * randf_range(-dispersion, dispersion) \
					+ _camara.global_basis.y * randf_range(-dispersion, dispersion)
			var choque: Dictionary = Combate.rayo(get_world_3d(), _origen(), dir, 150.0, [get_rid()])
			if choque.is_empty():
				continue
			var cosa = choque["collider"]
			if cosa != null and cosa.has_method("recibir_dano"):
				cosa.recibir_dano(float(datos["dano"]) * _mult_dano())
			else:
				Combate.marca_bala(_escena(), choque["position"], choque["normal"])
	Juego.cambio.emit()


# R: llena el cargador con la munición que lleves encima.
func _recargar() -> void:
	var casilla = Juego.en_mano()
	if casilla == null:
		return
	var datos: Dictionary = Juego.DatosObjetos.datos(casilla["id"])
	if datos["tipo"] != "arma_fuego":
		return
	var falta: int = int(datos["cargador"]) - int(casilla.get("balas", 0))
	var disponible: int = Juego.cuenta(datos["municion"])
	var pasa: int = mini(falta, disponible)
	if pasa <= 0:
		Juego.avisar("Cargador lleno." if falta <= 0 else "No tienes munición (%s)." % Juego.DatosObjetos.nombre(datos["municion"]))
		return
	Juego.quitar(datos["municion"], pasa)
	casilla["balas"] = int(casilla.get("balas", 0)) + pasa
	_enfriamiento = 0.8
	Juego.avisar("Recargas %d." % pasa)
	Juego.cambio.emit()


func _usar_explosivo(casilla: Dictionary, datos: Dictionary) -> void:
	_enfriamiento = 0.8
	if casilla["id"] == "c4":
		var choque: Dictionary = Combate.rayo(get_world_3d(), _origen(), _adelante(), 4.0, [get_rid()])
		if choque.is_empty():
			Juego.avisar("Acércate a una superficie para pegar la carga.")
			return
		var carga: CargaC4 = CargaC4.new()
		carga.dano = float(datos["dano"])
		_escena().add_child(carga)
		carga.look_at_from_position(choque["position"] + choque["normal"] * 0.04,
				choque["position"] + choque["normal"] * 2.0,
				Vector3.RIGHT if absf(choque["normal"].y) > 0.99 else Vector3.UP)
		Juego.avisar("Carga colocada. Usa el detonador (clic) para hacerla explotar.")
	else:
		Combate.lanzar(_escena(), _origen() + _adelante() * 0.6, _adelante() * 14.0 + Vector3.UP * 3.0,
				2.5, false, 6.0, float(datos["dano"]), Color(0.25, 0.32, 0.2), 0.08)
	casilla["cantidad"] -= 1
	if casilla["cantidad"] <= 0:
		Juego.inventario[Juego.seleccion] = null
	Juego.cambio.emit()


# Botón derecho con el francotirador: acerca la vista.
func _alternar_zoom() -> void:
	if _datos_mano().get("forma", "") != "francotirador":
		return
	_zoom = not _zoom
	_camara.fov = 22.0 if _zoom else 70.0


# Se llama si el jugador cae por debajo de ALTURA_MINIMA (un hueco del mapa).
func _reaparecer_en_la_plaza() -> void:
	global_position = Vector3(0, 0.2, 8)
	velocity = Vector3.ZERO
	Juego.avisar("Te has caído del mapa. Vuelves a la plaza.")


# La policía te atrapa: fundido, multa, calabozo y apareces en la comisaría (la plaza).
func ser_detenido() -> void:
	if _muerto or _detenido:
		return
	_detenido = true
	if vehiculo != null:
		vehiculo.bajar()
	Juego.menu_abierto = true
	hud.fundido(func() -> void:
		var texto: String = Juego.detener()
		global_position = Vector3(0, 0.2, 8)
		velocity = Vector3.ZERO
		get_tree().call_group("policia_refuerzo", "queue_free")
		Juego.menu_abierto = false
		_detenido = false
		Juego.avisar(texto), 2.0)


# Viaje rápido (taxi): fundido y aparece en el destino. Si el trozo de mundo de allí aún no
# está cargado, espera sin caer (ver _esperar_suelo) hasta que haya suelo.
func viajar_a(destino: Vector3, horas: float = 0.0) -> void:
	if vehiculo != null or _detenido:
		return
	hud.fundido(func() -> void:
		var h: float = GeneradorMundo.altura(destino.x, destino.z) if GeneradorMundo.listo else destino.y
		if absf(destino.y - h) < 1.0 and destino.y > h:
			h = destino.y
		if horas > 0.0:
			Juego.avanzar_horas(horas)
		global_position = Vector3(destino.x, maxf(h, destino.y) + 3.0, destino.z)
		velocity = Vector3.ZERO
		_suelo_pendiente = true
		_t_suelo_pendiente = 0.0, 1.0)


func _esperar_suelo(delta: float) -> void:
	velocity = Vector3.ZERO
	_t_suelo_pendiente += delta
	var desde: Vector3 = global_position + Vector3(0, 60, 0)
	var consulta: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(desde, global_position + Vector3(0, -80, 0))
	consulta.exclude = [get_rid()]
	var choque: Dictionary = get_world_3d().direct_space_state.intersect_ray(consulta)
	if not choque.is_empty():
		global_position = choque["position"] + Vector3(0, 0.4, 0)
		_suelo_pendiente = false
	elif _t_suelo_pendiente > 15.0:
		_suelo_pendiente = false   # Sin suelo tras 15 s: que actúe la red de seguridad del gestor de trozos.


# Si la vida llega a cero: fundido a negro, reaparece en la plaza y pierdes
# una parte del dinero.
func _morir() -> void:
	if vehiculo != null:
		vehiculo.bajar()
	_muerto = true
	Juego.avisar("Has caído. Despiertas en la plaza, y te falta dinero...")
	hud.fundido(func() -> void:
		Juego.estrellas = 0
		Juego.alerta = 0.0
		get_tree().call_group("policia_refuerzo", "queue_free")
		var multa: int = mini(Juego.dinero, maxi(Economia.MULTA_MUERTE_MINIMA, int(Juego.dinero * Economia.MULTA_MUERTE_PORCENTAJE)))
		Juego.dinero -= multa
		Juego.vida = Juego.VIDA_MAX * 0.6
		Juego.efectos_activos.clear()
		Juego.efectos_cambiados.emit()
		global_position = Vector3(0, 0.2, 8)
		velocity = Vector3.ZERO
		_muerto = false
		Juego.cambio.emit(), 1.5)


# En primera persona el objeto cuelga de la cámara; en tercera, del muñeco.
func _colocar_mano() -> void:
	if _mano == null:
		return
	if _mano.get_parent() != null:
		_mano.get_parent().remove_child(_mano)
	if primera_persona:
		_camara.add_child(_mano)
		_mano.position = Vector3(0.28, -0.26, -0.55)
		_mano.rotation = Vector3(0.0, deg_to_rad(-8.0), 0.0)
	else:
		_cuerpo.add_child(_mano)
		_mano.position = Vector3(0.38, 0.95, -0.35)
		_mano.rotation = Vector3.ZERO


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
	if cosa.ignora_vista:
		return true
	var ojos: Vector3 = global_position + Vector3(0, 1.5, 0)
	var destino: Vector3 = cosa.global_position + Vector3(0, 0.3, 0)
	var consulta: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ojos, destino)
	consulta.exclude = [get_rid()]
	var choque: Dictionary = get_world_3d().direct_space_state.intersect_ray(consulta)
	# Si choca, solo vale si es con el propio objeto (o muy cerca de él). Los choques que
	# pertenecen al propio objeto cuentan como "el objeto": si no, un quiosco o un corral
	# con paredes macizas jamás se podían usar (el rayo chocaba con su propia pared).
	if choque.is_empty() or choque["position"].distance_to(destino) < 0.8:
		return true
	var otro = choque["collider"]
	return otro is Node and (cosa.is_ancestor_of(otro) or otro == cosa)


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
	_choque = choque

	# El muñeco (o traje con modelo): ver aspecto.gd. Se cambia con la tecla O.
	_cuerpo = Node3D.new()
	add_child(_cuerpo)
	vestir()


# Rehace el aspecto del jugador según Juego.aspecto.
func vestir() -> void:
	if _ropa != null:
		_ropa.queue_free()
	_ropa = Node3D.new()
	_cuerpo.add_child(_ropa)
	_modelo_anim = Aspecto.vestir(_ropa, Juego.aspecto)


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


# ------------------------------- Vehículos ------------------------------------

# Sube a un vehículo: cuerpo oculto, sin choque, cámara en tercera persona más lejos.
func subir_a(v: Interactuable) -> void:
	vehiculo = v
	_primera_antes = primera_persona
	primera_persona = false
	_aplicar_camara()
	_choque.set_deferred("disabled", true)
	_cuerpo.visible = false
	if _mano != null:
		_mano.visible = false
	_brazo.spring_length = 6.5
	var chasis = v.get("chasis")
	if chasis != null:
		_brazo.add_excluded_object(chasis.get_rid())


# Mientras conduces, la cámara atraviesa los demás vehículos y los guardias (si no, se queda pegada
# a un coche aparcado o a una persona y tapa la pantalla).
func _excluir_en_camara() -> void:
	_brazo.clear_excluded_objects()
	_brazo.add_excluded_object(get_rid())
	for n in get_tree().get_nodes_in_group("vehiculos") + get_tree().get_nodes_in_group("guardias"):
		var c = n.get("chasis")
		if c != null:
			_brazo.add_excluded_object(c.get_rid())
		elif n is CollisionObject3D:
			_brazo.add_excluded_object((n as CollisionObject3D).get_rid())


func bajar_de(v: Interactuable, destino: Vector3) -> void:
	var chasis = v.get("chasis")
	if chasis != null:
		_brazo.remove_excluded_object(chasis.get_rid())
	vehiculo = null
	_brazo.clear_excluded_objects()
	_brazo.add_excluded_object(get_rid())
	global_position = destino
	velocity = Vector3.ZERO
	_choque.set_deferred("disabled", false)
	primera_persona = _primera_antes
	_aplicar_camara()
	if _mano != null:
		_mano.visible = true
