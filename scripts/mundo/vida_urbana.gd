# vida_urbana.gd
# -----------------------------------------------------------------------------
# Hace que las calles estén vivas: peatones, coches y semáforos.
#   - Todo se crea SOLO cerca del jugador (radio ~110 m) y se borra al alejarse.
#   - Peatones: pasean por las aceras, hacen pausas y charlan. De día hay muchos;
#     de noche pocos y algunos van "contentos" (zigzaguean). Con lluvia fuerte hay
#     menos. Si tienes estrellas de búsqueda, huyen de ti. Se les puede hacer daño
#     (y eso sube la sospecha).
#   - Peatones: andan por las aceras y CRUZAN por los pasos de cebra de los cruces
#     (esperan en la esquina a que el semáforo esté en rojo para los coches o a que
#     los coches se paren). Algunos imprudentes cruzan por donde no deben.
#   - Coches: circulan por el carril derecho, giran en los cruces, frenan ante
#     lo que tengan delante (tú, otros coches, peatones) y paran en rojo. Se paran
#     ante los pasos de cebra con gente, ceden el paso en los cruces sin semáforo
#     y, si no hay manera de moverse, se desatascan solos. Si un conductor despistado
#     (o tú) atropella a alguien, lo hiere o lo mata.
#   - Semáforos: en las ciudades (todos los cruces) y en el centro de los pueblos.
#     Ciclo de 24 s: 10 verde, 2 ámbar, 12 rojo, alternando los dos ejes.
# Redes de calles: la ciudad original (3 avenidas, ver CIUDAD_*) y las cuadrículas
# de los asentamientos generados (GeneradorMundo). SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name VidaUrbana
extends Node3D

const RADIO_CREAR: float = 110.0
const RADIO_BORRAR: float = 150.0
const MAX_COCHES: int = 10
const P_ACERA: int = 0
const P_ESPERA: int = 1
const P_CRUZA: int = 2
const P_HERIDO: int = 3
const P_LIBRE: int = 4   # Cruza por donde no debe (sin paso de cebra).
const CICLO_SEMAFORO: float = 24.0
const VERDE: float = 10.0
const AMBAR: float = 12.0
const COCHES: Array = [["sedan", 4.4], ["taxi", 4.4], ["hatchback-sports", 3.9], ["suv", 4.6], ["van", 4.8],
		["sedan-sports", 4.4], ["delivery", 4.6]]
const PERSONAJES: Array = ["Character_Hazmat", "Character_Enemy", "Character_Soldier"]
const COLORES_COCHE: Array = [Color(0.7, 0.2, 0.15), Color(0.2, 0.3, 0.5), Color(0.8, 0.75, 0.2),
		Color(0.25, 0.4, 0.3), Color(0.8, 0.8, 0.8)]

# Avenidas de la ciudad original (nodos y vecinos). Los extremos junto a la plaza llevan semáforo.
const CIUDAD_NODOS: Array = [Vector2(16, -24), Vector2(16, -100), Vector2(24, -16), Vector2(100, -16),
		Vector2(300, -16), Vector2(-16, 24), Vector2(-16, 100)]
const CIUDAD_ARISTAS: Array = [[0, 1], [2, 3], [3, 4], [5, 6]]
const CIUDAD_SEMAFOROS: Array = [0, 2, 5]

var _jugador: Node3D
var _redes: Dictionary = {}       # clave -> red (ver _red_ciudad y _red_asentamiento)
var _cerca: Array = []            # redes cerca del jugador
var _coches: Array = []
var _vehiculos: Array = []        # Vehículos aparcados y el tuyo (grupo "vehiculos"), refrescado cada fotograma.
var _peatones: Array = []
var _semaforos: Dictionary = {}   # "clave_red|nodo" -> Semaforo
var _t_gestion: float = 0.0
var _t_luces: float = 0.0
var _t_sin_jugador: float = 0.0


# ----------------------------------- Redes ------------------------------------
# Una red es un Diccionario: {id, pos: {Vector2i -> Vector2}, vec: {Vector2i -> Array},
# luz: {Vector2i -> true}, y: altura fija, ancho: ancho de la calle, coches: bool}

func _red_ciudad() -> Dictionary:
	if _redes.has("ciudad"):
		return _redes["ciudad"]
	var red: Dictionary = {"id": "ciudad", "pos": {}, "vec": {}, "luz": {}, "y": 0.0, "ancho": 8.0, "coches": true, "tipo": 3}
	for i in CIUDAD_NODOS.size():
		red["pos"][Vector2i(i, 0)] = CIUDAD_NODOS[i]
		red["vec"][Vector2i(i, 0)] = []
	for par in CIUDAD_ARISTAS:
		red["vec"][Vector2i(par[0], 0)].append(Vector2i(par[1], 0))
		red["vec"][Vector2i(par[1], 0)].append(Vector2i(par[0], 0))
	for i in CIUDAD_SEMAFOROS:
		red["luz"][Vector2i(i, 0)] = true
	_redes["ciudad"] = red
	return red


func _red_asentamiento(s: Dictionary) -> Dictionary:
	var id: String = "a_%d_%d" % [int(s["ci"]), int(s["cj"])]
	if _redes.has(id):
		return _redes[id]
	var n: int = int(s["n"])
	var tipo: int = int(s["tipo"])
	var centro: Vector2 = s["pos"]
	var red: Dictionary = {"id": id, "pos": {}, "vec": {}, "luz": {}, "y": float(s["base"]),
			"ancho": GeneradorMundo.CALLE_ANCHO, "coches": tipo >= 1, "tipo": tipo}
	for k in range(-n, n + 1):
		for l in range(-n, n + 1):
			var c: Vector2i = Vector2i(k, l)
			red["pos"][c] = centro + Vector2(k, l) * GeneradorMundo.BLOQUE
			var vecinos: Array = []
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var o: Vector2i = c + d
				if absi(o.x) <= n and absi(o.y) <= n:
					vecinos.append(o)
			red["vec"][c] = vecinos
			var con_luz: bool = tipo == 2 or (tipo == 1 and absi(k) <= 1 and absi(l) <= 1)
			if con_luz and absi(k) < n and absi(l) < n:
				red["luz"][c] = true
	_redes[id] = red
	return red


func _actualizar_redes_cercanas() -> void:
	_cerca.clear()
	var p: Vector3 = _jugador.global_position
	var yo: Vector2 = Vector2(p.x, p.z)
	var ciudad: Dictionary = _red_ciudad()
	for c in ciudad["pos"]:
		if (ciudad["pos"][c] as Vector2).distance_to(yo) < RADIO_CREAR + 60.0:
			_cerca.append(ciudad)
			break
	for s in GeneradorMundo.asentamientos_cerca(Rect2(yo.x - 200.0, yo.y - 200.0, 400.0, 400.0)):
		var m: float = float(s["mitad"])
		var centro: Vector2 = s["pos"]
		if absf(centro.x - yo.x) < m + RADIO_CREAR and absf(centro.y - yo.y) < m + RADIO_CREAR:
			_cerca.append(_red_asentamiento(s))


func _altura(red: Dictionary, x: float, z: float) -> float:
	if red["id"] == "ciudad":
		return 0.0
	return float(red["y"])


# ------------------------------- Semáforos (lógica) ----------------------------

# 0 verde, 1 ámbar, 2 rojo. "eje": 0 = circulando por X, 1 = circulando por Z.
static func estado_semaforo(eje: int, nodo: Vector2i) -> int:
	var t: float = Time.get_ticks_msec() / 1000.0 + float((nodo.x + nodo.y) & 1) * 6.0
	if eje == 1:
		t += CICLO_SEMAFORO * 0.5
	t = fmod(t, CICLO_SEMAFORO)
	if t < VERDE:
		return 0
	if t < AMBAR:
		return 1
	return 2


# ---------------------------------- Agentes ------------------------------------

class Agente extends AnimatableBody3D:
	var red: Dictionary
	var desde: Vector2i
	var hacia: Vector2i
	var d: float = 0.0            # Metros recorridos desde "desde".
	var vel: float = 0.0
	var vmax: float = 8.0
	var es_coche: bool = false
	var largo: float = 4.4
	var lado: float = 2.0         # Desplazamiento a la derecha del eje de la calle (negativo = izquierda).
	var pausa: float = 0.0
	var alegre: bool = false      # Peatón de noche que va zigzagueando.
	var huyendo: bool = false
	var vida: float = 30.0
	var modelo: Node3D = null
	var fase: float = 0.0
	# --- Coches ---
	var dir2: Vector2 = Vector2.RIGHT
	var corr: Vector2 = Vector2.ZERO   # Desfase que se va deshaciendo tras un giro (evita saltos).
	var espera: float = 0.0            # Segundos parado sin motivo legítimo (rojo, peatón).
	var fantasma: float = 0.0          # Si es > 0 ignora a los otros coches (para desatascarse).
	var frenazo: float = 0.0
	var t_golpe: float = 0.0
	var desvio: float = 0.0            # Metros que se aparta a la izquierda para rodear algo aparcado.
	var bloqueo: String = ""          # Qué lo frena (para depurar).
	var atento: bool = true            # El 12 % va despistado y ve tarde a los imprudentes.
	# --- Peatones ---
	var estado: int = 0
	var s: int = 1                     # Lado de la acera respecto al sentido del tramo.
	var p2: Vector2 = Vector2.ZERO     # Posición libre (al cruzar).
	var destino: Vector2 = Vector2.ZERO
	var nuevo: Array = []              # [desde, hacia, s] al terminar de cruzar.
	var cruce_nodo: Vector2i = Vector2i(-9999, -9999)
	var cruce_brazo: Vector2i = Vector2i(-9999, -9999)
	var imprudente: bool = false
	var d_libre: float = -1.0
	var cuidadoso: bool = true
	var t_espera: float = 0.0
	var herido_t: float = 0.0

	func recibir_dano(cantidad: float) -> void:
		if es_coche:
			return
		vida -= cantidad
		huyendo = true
		if vida <= 0.0:
			Juego.sospecha = minf(100.0, Juego.sospecha + 10.0)
			Juego.avisar("Has herido a un ciudadano. La policía lo sabrá.")
			remove_from_group("danable")
			set_meta("muerto", true)
			visible = false
			collision_layer = 0


class Semaforo extends Node3D:
	var lamparas: Array = [[], []]   # Por eje: [rojo, ámbar, verde] (materiales).
	var estado: Array = [-1, -1]


func _physics_process(delta: float) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
		return
	_t_gestion -= delta
	if _t_gestion <= 0.0:
		_t_gestion = 1.5
		_actualizar_redes_cercanas()
		_gestionar()
	_t_luces -= delta
	if _t_luces <= 0.0:
		_t_luces = 0.25
		_actualizar_semaforos()
	_vehiculos = get_tree().get_nodes_in_group("vehiculos")
	for a in _coches:
		_mover_coche(a, delta)
	for a in _peatones:
		_mover_peaton(a, delta)


# ------------------------------- Crear y borrar --------------------------------

func _objetivo_peatones() -> int:
	var h: float = Juego.hora
	# Según el mayor asentamiento cercano: aldea (0), pueblo (1), ciudad (2) o ciudad original (3).
	var tipo: int = 0
	for red in _cerca:
		tipo = maxi(tipo, int(red.get("tipo", 0)))
	var dia: Array = [9, 13, 16, 16]
	var tarde: Array = [5, 8, 10, 10]
	var noche: Array = [2, 3, 5, 5]
	var n: int = int(noche[tipo])
	if h >= 7.0 and h < 20.0:
		n = int(dia[tipo])
	elif h >= 20.0 and h < 23.0:
		n = int(tarde[tipo])
	if Clima.lluvia > 0.6:
		n = int(n * 0.4)
	return n


func _gestionar() -> void:
	var yo3: Vector3 = _jugador.global_position
	# Borrar los lejanos o caídos.
	for lista in [_coches, _peatones]:
		for a in lista.duplicate():
			var lejos: bool = not is_instance_valid(a) or a.global_position.distance_to(yo3) > RADIO_BORRAR
			if not lejos and a.has_meta("muerto"):
				lejos = true
			if lejos:
				lista.erase(a)
				if is_instance_valid(a):
					a.queue_free()
	for clave in _semaforos.keys():
		var sem: Node3D = _semaforos[clave]
		if sem.global_position.distance_to(yo3) > RADIO_BORRAR:
			sem.queue_free()
			_semaforos.erase(clave)
	if _cerca.is_empty():
		return
	# Rutina: al anochecer los vecinos "se van a casa" (los que están lejos de ti desaparecen poco a poco).
	var objetivo_actual: int = _objetivo_peatones()
	if _peatones.size() > objetivo_actual:
		for a in _peatones.duplicate():
			if is_instance_valid(a) and a.global_position.distance_to(yo3) > 45.0:
				_peatones.erase(a)
				a.queue_free()
				break
	# Crear, como mucho 2 de cada cosa por pasada.
	var objetivo: int = _objetivo_peatones()
	var creados: int = 0
	while _peatones.size() < objetivo and creados < 2:
		creados += 1
		var red: Dictionary = _cerca[randi() % _cerca.size()]
		var a: Agente = _nuevo_agente(red, false)
		if a != null:
			_peatones.append(a)
	creados = 0
	while _coches.size() < MAX_COCHES and creados < 2:
		creados += 1
		var red: Dictionary = _cerca[randi() % _cerca.size()]
		if not red["coches"]:
			continue
		var a: Agente = _nuevo_agente(red, true)
		if a != null:
			_coches.append(a)
	_crear_semaforos_cercanos()


# Mitad del ancho de la calle + 2 m: línea por la que andan los peatones y donde
# están los pasos de cebra (a esa distancia del centro del cruce, en cada calle).
func _hs(red: Dictionary) -> float:
	return float(red["ancho"]) * 0.5 + 2.0


func _eje_de(v: Vector2) -> int:
	return 0 if absf(v.x) > absf(v.y) else 1


# Elige un tramo y un punto a 35-110 m del jugador, libre de otros agentes.
func _nuevo_agente(red: Dictionary, coche: bool) -> Agente:
	var claves: Array = red["pos"].keys()
	var yo3: Vector3 = _jugador.global_position
	var hs: float = _hs(red)
	for intento in 8:
		var desde: Vector2i = claves[randi() % claves.size()]
		var vecinos: Array = red["vec"][desde]
		if vecinos.is_empty():
			continue
		var hacia: Vector2i = vecinos[randi() % vecinos.size()]
		var a_pos: Vector2 = red["pos"][desde]
		var b_pos: Vector2 = red["pos"][hacia]
		var largo_tramo: float = a_pos.distance_to(b_pos)
		if largo_tramo < hs * 2.0 + 8.0:
			continue
		# Peatones y coches nacen lejos de los cruces.
		var dist: float = hs + 4.0 + randf() * (largo_tramo - 2.0 * hs - 8.0)
		var punto: Vector2 = a_pos.lerp(b_pos, dist / largo_tramo)
		var lejania: float = Vector2(yo3.x, yo3.z).distance_to(punto)
		if lejania < 35.0 or lejania > RADIO_CREAR:
			continue
		if _hay_alguien_cerca(punto, 8.0):
			continue
		var a: Agente = Agente.new()
		a.red = red
		a.desde = desde
		a.hacia = hacia
		a.d = dist
		a.es_coche = coche
		a.collision_layer = 1
		a.collision_mask = 0
		a.sync_to_physics = false
		if coche:
			_vestir_coche(a)
			a.vmax = 11.0 if float(red["ancho"]) >= 8.0 else 8.0
			a.lado = float(red["ancho"]) * 0.25
			a.atento = randf() > 0.06
		else:
			_vestir_peaton(a)
			a.vmax = 1.3
			a.s = 1 if randf() < 0.5 else -1
			a.alegre = Juego.hora >= 23.0 or Juego.hora < 6.0
			if a.alegre and randf() < 0.5:
				a.alegre = false
			a.fase = randf() * 6.28
			a.imprudente = randf() < 0.22
			a.cuidadoso = randf() < 0.6
			_planear_imprudencia(a)
			a.add_to_group("danable")
		add_child(a)
		_colocar(a, true)
		return a
	return null


func _hay_alguien_cerca(p: Vector2, radio: float) -> bool:
	for lista in [_coches, _peatones]:
		for a in lista:
			if is_instance_valid(a) and Vector2(a.global_position.x, a.global_position.z).distance_to(p) < radio:
				return true
	return false


func _vestir_coche(a: Agente) -> void:
	var elegido: Array = COCHES[randi() % COCHES.size()]
	a.largo = float(elegido[1])
	var forma: CollisionShape3D = CollisionShape3D.new()
	var caja: BoxShape3D = BoxShape3D.new()
	caja.size = Vector3(2.0, 1.3, a.largo)
	forma.shape = caja
	forma.position.y = 0.75
	a.add_child(forma)
	var nombre: String = "kenney/car-kit/" + str(elegido[0])
	var m: Node3D = Assets.modelo(nombre) if Assets.existe(nombre) else null
	if m != null:
		var ab: AABB = Assets.caja_de(m)
		var largo_x: bool = ab.size.x > ab.size.z
		var esc: float = a.largo / maxf(0.01, maxf(ab.size.x, ab.size.z))
		m.position = Vector3(-ab.get_center().x, -ab.position.y, -ab.get_center().z)
		var envoltorio: Node3D = Node3D.new()
		envoltorio.scale = Vector3.ONE * esc
		envoltorio.rotation.y = PI / 2.0 if largo_x else PI
		envoltorio.add_child(m)
		a.add_child(envoltorio)
		a.modelo = envoltorio
	else:
		var col: Color = COLORES_COCHE[randi() % COLORES_COCHE.size()]
		Construir.caja(a, Vector3(0, 0.6, 0), Vector3(1.9, 0.8, a.largo), col, false)
		Construir.caja(a, Vector3(0, 1.2, 0.3), Vector3(1.7, 0.6, a.largo * 0.5), col.lightened(0.2), false)


func _vestir_peaton(a: Agente) -> void:
	var forma: CollisionShape3D = CollisionShape3D.new()
	var capsula: CapsuleShape3D = CapsuleShape3D.new()
	capsula.radius = 0.35
	capsula.height = 1.7
	forma.shape = capsula
	forma.position.y = 0.85
	a.add_child(forma)
	var nombre: String = "quaternius/toon-shooter-game-kit/Characters/" + str(PERSONAJES[randi() % PERSONAJES.size()])
	var persona: Node3D = Assets.personaje(nombre, "", "Walk")
	if persona != null:
		a.add_child(persona)
		a.modelo = persona
	else:
		var col: Color = Color.from_hsv(randf(), 0.4, 0.5)
		var cuerpo: Node3D = Node3D.new()
		a.add_child(cuerpo)
		Construir.cilindro(cuerpo, Vector3(0, 0.6, 0), 0.3, 1.2, col, false)
		Construir.esfera(cuerpo, Vector3(0, 1.42, 0), 0.2, Color(0.75, 0.62, 0.52))
		a.modelo = cuerpo


# ------------------------------ Geometría de los tramos -----------------------

# Posición (x, z) de un agente según su tramo, su sitio dentro del tramo y su lado.
func _punto_tramo(a: Agente) -> Vector2:
	var pa: Vector2 = a.red["pos"][a.desde]
	var pb: Vector2 = a.red["pos"][a.hacia]
	var dir: Vector2 = (pb - pa).normalized()
	var derecha: Vector2 = Vector2(-dir.y, dir.x)
	if a.es_coche:
		return pa + dir * a.d + derecha * (a.lado - a.desvio)
	var lat: float = float(a.s) * _hs(a.red)
	if a.alegre:
		lat += sin(a.fase) * 0.7
	return pa + dir * a.d + derecha * lat


# Pone al agente en su sitio y lo orienta. "ya" = sin suavizar (al nacer).
func _colocar(a: Agente, ya: bool = false, delta: float = 0.0) -> void:
	var pa: Vector2 = a.red["pos"][a.desde]
	var pb: Vector2 = a.red["pos"][a.hacia]
	var dir: Vector2 = (pb - pa).normalized()
	var punto: Vector2
	var yaw: float
	if a.es_coche:
		a.dir2 = dir
		a.corr = a.corr * exp(-5.0 * delta)
		punto = _punto_tramo(a) + a.corr
		yaw = atan2(-dir.x, -dir.y)
	else:
		if a.estado != P_ACERA:
			punto = a.p2
			if a.estado == P_HERIDO:
				yaw = a.rotation.y
			else:
				var mira: Vector2 = a.destino - a.p2
				yaw = atan2(-mira.x, -mira.y) if mira.length() > 0.05 else a.rotation.y
		else:
			punto = _punto_tramo(a)
			a.p2 = punto
			yaw = atan2(-dir.x, -dir.y)
	var y: float = _altura(a.red, punto.x, punto.y)
	if a.es_coche and a.red["id"] != "ciudad":
		y += 0.17   # Las calzadas de los pueblos van 0,15 m por encima del suelo.
	elif a.es_coche:
		y += 0.05
	a.global_position = Vector3(punto.x, y, punto.y)
	if ya:
		a.rotation.y = yaw
	else:
		a.rotation.y = lerp_angle(a.rotation.y, yaw, 1.0 - exp(-9.0 * delta))


# --------------------------------- Movimiento ----------------------------------

func _siguiente_nodo(a: Agente) -> void:
	var llegado: Vector2i = a.hacia
	var vecinos: Array = (a.red["vec"][llegado] as Array).duplicate()
	var previo: Vector2i = a.desde
	if vecinos.size() > 1:
		vecinos.erase(previo)   # No se da la vuelta salvo en un fondo de saco.
	var elegido: Vector2i = vecinos[randi() % vecinos.size()]
	var antes: Vector2 = _punto_tramo(a)
	a.desde = llegado
	a.hacia = elegido
	a.d = 0.0
	# Tras girar, el coche se desliza al carril nuevo en vez de dar un salto.
	a.corr = antes - _punto_tramo(a)


func _frenar_para(libre: float, margen: float = 2.0, decel: float = 5.0) -> float:
	# Velocidad máxima desde la que se puede parar a "libre" metros.
	return sqrt(2.0 * decel * maxf(0.0, libre - margen))


# Lo primero que estorba por delante: [metros libres, quién].
func _distancia_libre(a: Agente, dir: Vector2) -> Array:
	var ventana: float = 12.0 + a.vel * 1.5
	if not a.atento:
		ventana = 7.0 + a.vel * 0.3
	var libre: float = ventana
	var quien: Node3D = null
	var yo: Vector2 = Vector2(a.global_position.x, a.global_position.z)
	var lat_dir: Vector2 = Vector2(-dir.y, dir.x)
	var mitad: float = a.largo * 0.5
	# [nodo, lateral permitido]
	var candidatos: Array = []
	candidatos.append([_jugador, 1.5])
	for v in _vehiculos:
		candidatos.append([v, 1.7])   # Un coche aparcado en la acera no cuenta; uno en medio del carril, sí.
	if a.fantasma <= 0.0:
		for o in _coches:
			if o != a:
				candidatos.append([o, 1.9])
	for o in _peatones:
		candidatos.append([o, 1.8 if (o as Agente).estado != P_LIBRE else 2.6])
	for c in candidatos:
		var o: Node3D = c[0]
		if not is_instance_valid(o):
			continue
		var p: Vector3 = o.global_position
		var rel: Vector2 = Vector2(p.x, p.z) - yo
		var delante: float = rel.dot(dir)
		if delante <= 0.0 or delante > ventana + mitad:
			continue
		if absf(p.y - a.global_position.y) > 3.0:
			continue
		var lateral: float = absf(rel.dot(lat_dir))
		if lateral < float(c[1]) and delante - mitad < libre:
			libre = maxf(0.0, delante - mitad)
			quien = o
	return [libre, quien]


# ¿Hay gente esperando o cruzando en el paso de cebra de la calle "brazo" del cruce "nodo"?
func _peaton_en_paso(red: Dictionary, nodo: Vector2i, brazo: Vector2i) -> bool:
	var con_luz: bool = red["luz"].has(nodo)
	for p in _peatones:
		if not is_instance_valid(p) or p.cruce_nodo != nodo or p.cruce_brazo != brazo:
			continue
		if (p as Agente).red["id"] != red["id"]:
			continue
		if p.estado == P_CRUZA or (p.estado == P_ESPERA and not con_luz):
			return true
	return false


func _prioridad(o: Agente) -> float:
	# Segundos que tardaría en llegar al cruce (los parados cuentan por distancia).
	var pa: Vector2 = o.red["pos"][o.desde]
	var pb: Vector2 = o.red["pos"][o.hacia]
	var rest: float = pa.distance_to(pb) - o.d
	return rest / maxf(o.vel, 1.0)


# ¿Debe esperar este coche por el tráfico que cruza el cruce al que llega?
func _cruce_ocupado(a: Agente, pb: Vector2, dir: Vector2, hs: float) -> bool:
	if a.fantasma > 0.0:
		return false
	var con_luz: bool = a.red["luz"].has(a.hacia)
	var mi_t: float = _prioridad(a)
	for o in _coches:
		if o == a or not is_instance_valid(o) or o.red["id"] != a.red["id"]:
			continue
		if absf(o.dir2.dot(dir)) > 0.5:
			continue   # Misma calle (delante, detrás o de frente): no cruza mi paso.
		var qo: Vector2 = Vector2(o.global_position.x, o.global_position.z)
		if qo.distance_to(pb) < hs:
			return true   # Ya está dentro del cruce.
		if not con_luz and o.hacia == a.hacia:
			var t_o: float = _prioridad(o)
			if t_o < mi_t - 0.3 or (absf(t_o - mi_t) <= 0.3 and o.get_instance_id() < a.get_instance_id()):
				if (Vector2(o.global_position.x, o.global_position.z)).distance_to(pb) < 16.0 + hs:
					return true
	return false


# ¿Hay un vehículo aparcado (o el tuyo) en mi carril, por delante o justo al lado?
func _estorbo_estatico(a: Agente, dir: Vector2) -> bool:
	var lat_dir: Vector2 = Vector2(-dir.y, dir.x)
	var pa: Vector2 = a.red["pos"][a.desde]
	var centro_carril: Vector2 = pa + dir * a.d + lat_dir * a.lado
	for v in _vehiculos:
		if not is_instance_valid(v):
			continue
		var p: Vector3 = (v as Node3D).global_position
		var rel: Vector2 = Vector2(p.x, p.z) - centro_carril
		var delante: float = rel.dot(dir)
		if delante > -(a.largo * 0.5 + 3.0) and delante < 16.0 and absf(rel.dot(lat_dir)) < 1.7:
			return true
	return false


# ¿No viene ningún coche de frente por este tramo (en los próximos 45 m)?
func _carril_contrario_libre(a: Agente) -> bool:
	var yo: Vector2 = Vector2(a.global_position.x, a.global_position.z)
	for o in _coches:
		if o == a or not is_instance_valid(o) or o.red["id"] != a.red["id"]:
			continue
		if o.desde == a.hacia and o.hacia == a.desde and Vector2(o.global_position.x, o.global_position.z).distance_to(yo) < 45.0:
			return false
	return true


func _mover_coche(a: Agente, delta: float) -> void:
	if not is_instance_valid(a):
		return
	var pa: Vector2 = a.red["pos"][a.desde]
	var pb: Vector2 = a.red["pos"][a.hacia]
	var largo_tramo: float = pa.distance_to(pb)
	var dir: Vector2 = (pb - pa).normalized()
	var hs: float = _hs(a.red)
	var objetivo: float = a.vmax
	var motivo: int = 0   # 0 libre, 1 parada legítima (rojo, paso de peatones), 2 atasco.
	a.t_golpe = maxf(0.0, a.t_golpe - delta)
	a.fantasma = maxf(0.0, a.fantasma - delta)
	if a.frenazo > 0.0:
		a.frenazo -= delta
		objetivo = 0.0
		motivo = 1
	var restante: float = largo_tramo - a.d
	# --- Línea de detención ante el cruce al que llegamos ---
	var linea: float = restante - (hs + 2.0)
	if linea > -0.5 and linea < 30.0 and not (linea <= 0.0 and a.vel > 0.8):
		var parar: int = 0   # 0 no, 1 semáforo, 2 tráfico
		if a.red["luz"].has(a.hacia):
			var e: int = estado_semaforo(_eje_de(dir), a.hacia)
			if e == 2:
				parar = 1
			elif e == 1 and a.vel * a.vel / 9.0 < linea:
				parar = 1
		if parar == 0 and linea < 14.0 and _cruce_ocupado(a, pb, dir, hs):
			parar = 2
		if parar == 0 and _peaton_en_paso(a.red, a.hacia, a.desde):
			parar = 1
		if parar > 0:
			objetivo = minf(objetivo, _frenar_para(linea, 0.0))
			motivo = maxi(motivo, parar)
			a.bloqueo = "semaforo" if parar == 1 else "cruce"
	# --- Paso de peatones justo después de salir de un cruce ---
	if a.d < hs - 2.0 and _peaton_en_paso(a.red, a.desde, a.hacia):
		objetivo = minf(objetivo, _frenar_para(hs - 2.0 - a.d, 0.0))
		motivo = maxi(motivo, 1)
	# --- Algo aparcado en mi carril: lo rodeo por el otro carril si no viene nadie de frente ---
	var quiere_rodear: bool = _estorbo_estatico(a, dir) and (a.desvio > 0.5 or _carril_contrario_libre(a))
	a.desvio = move_toward(a.desvio, 3.6 if quiere_rodear else 0.0, 3.0 * delta)
	# --- Obstáculos por delante ---
	var libre: Array = _distancia_libre(a, dir)
	var quien: Node3D = libre[1]
	if quien != null:
		objetivo = minf(objetivo, _frenar_para(float(libre[0]), 2.0, 5.5))
		if objetivo < 0.5:
			a.bloqueo = str(quien.name) + ("(coche)" if quien is Agente and quien.es_coche else "")
			var legitimo: bool = quien is Agente and not (quien as Agente).es_coche
			motivo = maxi(motivo, 1 if legitimo else 2)
	# --- Desatasco: si lleva parado sin motivo, se las apaña ---
	if a.vel < 0.3 and motivo == 2:
		a.espera += delta
		if a.espera > 7.0 and a.fantasma <= 0.0 and not (quien != null and not (quien is Agente)):
			a.fantasma = 6.0   # Ignora a los otros coches un rato y sale.
		if a.espera > 12.0 and quien != null and not (quien is Agente):
			a.set_meta("muerto", true)   # Tapado por un vehículo parado: se retira.
		if a.espera > 30.0:
			a.set_meta("muerto", true)   # Se retira (lo borra _gestionar).
	elif a.vel >= 0.3 or motivo != 2:
		a.espera = maxf(0.0, a.espera - delta * 2.0)
	a.vel = move_toward(a.vel, objetivo, (7.0 if objetivo < a.vel else 3.0) * delta)
	a.d += a.vel * delta
	if a.d >= largo_tramo:
		var sobra: float = a.d - largo_tramo
		var dist_j: float = (a.global_position - _jugador.global_position).length()
		if (a.red["vec"][a.hacia] as Array).size() == 1 and dist_j > 45.0:
			a.set_meta("muerto", true)   # Fin de calle sin salida y fuera de la vista.
		else:
			_siguiente_nodo(a)
			a.d = sobra
	_colocar(a, false, delta)
	_comprobar_atropello(a, dir)


# Si el coche se mueve y tiene a alguien delante, lo atropella.
func _comprobar_atropello(a: Agente, dir: Vector2) -> void:
	if a.vel < 1.5 or a.t_golpe > 0.0:
		return
	var frente: Vector2 = Vector2(a.global_position.x, a.global_position.z) + dir * (a.largo * 0.5)
	for p in _peatones:
		if not is_instance_valid(p) or p.has_meta("muerto") or p.estado == P_HERIDO:
			continue
		if Vector2(p.global_position.x, p.global_position.z).distance_to(frente) < 1.3 and absf(p.global_position.y - a.global_position.y) < 2.0:
			_atropellar_peaton(a, p)
			return
	if _jugador.vehiculo == null and not _jugador._muerto:
		var q: Vector3 = _jugador.global_position
		if Vector2(q.x, q.z).distance_to(frente) < 1.5 and absf(q.y - a.global_position.y) < 2.0:
			a.t_golpe = 2.5
			Juego.cambiar_vida(-a.vel * 3.5)
			_jugador.velocity += Vector3(dir.x, 0.0, dir.y) * 7.0 + Vector3.UP * 3.5
			Juego.avisar("¡Un coche te ha atropellado!")
			a.vel = 0.0
			a.frenazo = 2.0


func _atropellar_peaton(a: Agente, p: Agente) -> void:
	a.t_golpe = 2.0
	p.vida -= a.vel * 3.5
	a.vel = 0.0
	a.frenazo = 2.5
	p.huyendo = false
	if p.vida <= 0.0:
		p.remove_from_group("danable")
		p.set_meta("muerto", true)
		p.visible = false
		p.collision_layer = 0
	else:
		p.estado = P_HERIDO
		p.herido_t = 14.0
		p.vel = 0.0
		if p.modelo != null:
			p.modelo.rotation.x = -PI / 2.0
			p.modelo.position.y = 0.25
			Assets.poner_animacion(p.modelo, "Idle")
		if _jugador.global_position.distance_to(p.global_position) < 30.0:
			Juego.avisar("Un coche ha atropellado a un peatón.")


# ------------------------------- Peatones: ruta --------------------------------

# Decide si este peatón cruzará por donde no debe en este tramo.
func _planear_imprudencia(a: Agente) -> void:
	a.d_libre = -1.0
	if not a.imprudente or randf() > 0.7:
		return
	var pa: Vector2 = a.red["pos"][a.desde]
	var pb: Vector2 = a.red["pos"][a.hacia]
	var hs: float = _hs(a.red)
	var fin: float = pa.distance_to(pb) - hs
	if fin - a.d > 8.0:
		a.d_libre = a.d + 4.0 + randf() * (fin - a.d - 6.0)


func _decidir_esquina(a: Agente) -> void:
	var red: Dictionary = a.red
	var nodo: Vector2i = a.hacia
	var pa: Vector2 = red["pos"][a.desde]
	var pb: Vector2 = red["pos"][nodo]
	var hs: float = _hs(red)
	var d: Vector2 = (pb - pa).normalized()
	var r: Vector2 = Vector2(-d.y, d.x)
	var e: Vector2 = r * float(a.s)
	var recto: Vector2i = Vector2i(-9999, 0)
	var lado_e: Vector2i = Vector2i(-9999, 0)
	var lado_ne: Vector2i = Vector2i(-9999, 0)
	for v in red["vec"][nodo]:
		if v == a.desde:
			continue
		var dv: Vector2 = ((red["pos"][v] as Vector2) - pb).normalized()
		if dv.dot(d) > 0.85:
			recto = v
		elif dv.dot(e) > 0.85:
			lado_e = v
		elif dv.dot(e) < -0.85:
			lado_ne = v
	var opciones: Array = []
	if recto.x != -9999:
		opciones.append("recto")
		opciones.append("recto")   # Es lo más habitual.
	if lado_e.x != -9999:
		opciones.append("giro_e")
	if lado_ne.x != -9999:
		opciones.append("giro_ne")
	if opciones.is_empty() or randf() < 0.04:
		opciones = ["vuelta"]
	var eleg: String = opciones[randi() % opciones.size()]
	var k0: Vector2 = pb + e * hs - d * hs
	a.cruce_nodo = Vector2i(-9999, -9999)
	a.cruce_brazo = Vector2i(-9999, -9999)
	match eleg:
		"recto":
			a.nuevo = [nodo, recto, a.s]
			a.p2 = k0
			a.destino = pb + e * hs + d * hs
			if lado_e.x != -9999:
				a.cruce_nodo = nodo
				a.cruce_brazo = lado_e
				a.estado = P_ESPERA
			else:
				a.estado = P_CRUZA
		"giro_e":
			_entrar_tramo(a, [nodo, lado_e, a.s])
		"giro_ne":
			a.nuevo = [nodo, lado_ne, -a.s]
			a.p2 = k0
			a.destino = pb - e * hs - d * hs
			a.cruce_nodo = nodo
			a.cruce_brazo = a.desde
			a.estado = P_ESPERA
		_:
			_entrar_tramo(a, [nodo, a.desde, -a.s])
	a.t_espera = 0.0
	if a.estado == P_ESPERA:
		a.p2 = k0


func _entrar_tramo(a: Agente, nuevo: Array) -> void:
	a.desde = nuevo[0]
	a.hacia = nuevo[1]
	a.s = int(nuevo[2])
	a.d = _hs(a.red)
	a.estado = P_ACERA
	a.cruce_nodo = Vector2i(-9999, -9999)
	a.cruce_brazo = Vector2i(-9999, -9999)
	if randf() < 0.3:
		a.pausa = 3.0 + randf() * 6.0   # Se para a charlar o a mirar escaparates.
	_planear_imprudencia(a)


# ¿Pueden cruzar ya? Con semáforo, cuando está en rojo para los coches; sin él,
# cuando los coches cercanos están parados. Siempre sin coches pegados al paso.
func _puede_cruzar(a: Agente) -> bool:
	var centro: Vector2 = (a.p2 + a.destino) * 0.5
	if a.cruce_nodo.x != -9999 and a.red["luz"].has(a.cruce_nodo):
		var brazo_pos: Vector2 = a.red["pos"][a.cruce_brazo]
		var eje: int = _eje_de(brazo_pos - (a.red["pos"][a.cruce_nodo] as Vector2))
		if estado_semaforo(eje, a.cruce_nodo) != 2:
			return false
	for c in _coches:
		if not is_instance_valid(c) or c.red["id"] != a.red["id"]:
			continue
		if Vector2(c.global_position.x, c.global_position.z).distance_to(centro) < 14.0 and c.vel > 1.2:
			return false
	return true


func _mover_peaton(a: Agente, delta: float) -> void:
	if not is_instance_valid(a):
		return
	var yo: Vector3 = _jugador.global_position
	var cerca: float = a.global_position.distance_to(yo)
	if a.estado == P_HERIDO:
		a.herido_t -= delta
		if a.herido_t <= 0.0:
			# Se levanta y se aleja cojeando.
			if a.modelo != null:
				a.modelo.rotation.x = 0.0
				a.modelo.position.y = 0.0
			a.estado = P_ACERA
			a.huyendo = true
			var pa: Vector2 = a.red["pos"][a.desde]
			var pb: Vector2 = a.red["pos"][a.hacia]
			var dir: Vector2 = (pb - pa).normalized()
			var rel: Vector2 = a.p2 - pa
			a.d = clampf(rel.dot(dir), _hs(a.red), maxf(_hs(a.red), pa.distance_to(pb) - _hs(a.red)))
			var lat: float = rel.dot(Vector2(-dir.y, dir.x))
			a.s = 1 if lat >= 0.0 else -1
		_colocar(a, false, delta)
		return
	if Juego.estrellas > 0 and cerca < 30.0:
		a.huyendo = true
	elif cerca > 40.0:
		a.huyendo = false
	var objetivo: float = a.vmax
	if a.huyendo:
		objetivo = 4.5
	elif a.alegre:
		objetivo = 0.9
	match a.estado:
		P_ACERA:
			if a.pausa > 0.0:
				a.pausa -= delta
				objetivo = 0.0
				if a.huyendo:
					a.pausa = 0.0
			a.vel = move_toward(a.vel, objetivo, 4.0 * delta)
			var pa2: Vector2 = a.red["pos"][a.desde]
			var pb2: Vector2 = a.red["pos"][a.hacia]
			var largo_tramo: float = pa2.distance_to(pb2)
			a.d += a.vel * delta
			a.fase += delta * 2.0
			if a.d_libre > 0.0 and a.d >= a.d_libre:
				_empezar_cruce_libre(a)
			elif a.d >= largo_tramo - _hs(a.red):
				a.d = largo_tramo - _hs(a.red)
				_decidir_esquina(a)
		P_ESPERA:
			a.vel = move_toward(a.vel, 0.0, 6.0 * delta)
			a.t_espera += delta
			if _puede_cruzar(a) or a.t_espera > 40.0:
				a.estado = P_CRUZA
		P_CRUZA, P_LIBRE:
			if a.estado == P_LIBRE and a.t_espera >= 0.0:
				# Mirando antes de cruzar (los prudentes esperan a que pase el coche).
				a.t_espera += delta
				a.vel = move_toward(a.vel, 0.0, 6.0 * delta)
				if _calle_libre(a) or not a.cuidadoso or a.t_espera > 10.0:
					a.t_espera = -1.0
			else:
				var v_cruce: float = 4.0 if a.huyendo else 1.7
				a.vel = move_toward(a.vel, v_cruce, 6.0 * delta)
				var falta: Vector2 = a.destino - a.p2
				var paso: float = a.vel * delta
				if falta.length() <= paso:
					a.p2 = a.destino
					if a.estado == P_LIBRE:
						a.s = -a.s
						a.estado = P_ACERA
						a.d_libre = -1.0
					else:
						_entrar_tramo(a, a.nuevo)
				else:
					a.p2 += falta.normalized() * paso
	_colocar(a, false, delta)
	if a.modelo != null and a.estado != P_HERIDO:
		var plano: float = a.vel
		Assets.poner_animacion(a.modelo, "Idle" if plano < 0.2 else ("Run" if plano > 3.0 else "Walk"))


func _empezar_cruce_libre(a: Agente) -> void:
	var pa: Vector2 = a.red["pos"][a.desde]
	var pb: Vector2 = a.red["pos"][a.hacia]
	var dir: Vector2 = (pb - pa).normalized()
	var r: Vector2 = Vector2(-dir.y, dir.x)
	a.p2 = _punto_tramo(a)
	a.destino = a.p2 - r * float(a.s) * _hs(a.red) * 2.0
	a.estado = P_LIBRE
	a.t_espera = 0.0
	a.cruce_nodo = Vector2i(-9999, -9999)
	a.cruce_brazo = Vector2i(-9999, -9999)


# ¿No viene ningún coche en marcha cerca de este tramo?
func _calle_libre(a: Agente) -> bool:
	for c in _coches:
		if not is_instance_valid(c) or c.red["id"] != a.red["id"]:
			continue
		if Vector2(c.global_position.x, c.global_position.z).distance_to(a.p2) < 24.0 and c.vel > 1.0:
			return false
	return true


# ------------------------------ Semáforos (dibujo) -----------------------------

func _crear_semaforos_cercanos() -> void:
	var yo3: Vector3 = _jugador.global_position
	var hechos: int = 0
	for red in _cerca:
		for nodo in red["pos"]:
			var clave: String = "%s|%d_%d" % [red["id"], nodo.x, nodo.y]
			if _semaforos.has(clave):
				continue
			var p: Vector2 = red["pos"][nodo]
			if Vector2(yo3.x, yo3.z).distance_to(p) > 90.0:
				continue
			var pasos: Array = _brazos_con_paso(red, nodo)
			var con_luz: bool = red["luz"].has(nodo)
			if pasos.is_empty() and not con_luz:
				continue
			if hechos >= 3:
				return
			hechos += 1
			var sem: Semaforo = _construir_semaforo(red, nodo) if con_luz else Semaforo.new()
			add_child(sem)
			sem.global_position = Vector3(p.x, _altura(red, p.x, p.y), p.y)
			_semaforos[clave] = sem
			sem.set_meta("nodo", nodo)
			_dibujar_pasos(sem, red, nodo, pasos)


# Calles del cruce que llevan paso de cebra: las que tienen otra calle perpendicular en el cruce.
func _brazos_con_paso(red: Dictionary, nodo: Vector2i) -> Array:
	var salida: Array = []
	var centro: Vector2 = red["pos"][nodo]
	var dirs: Array = []
	for v in red["vec"][nodo]:
		dirs.append(((red["pos"][v] as Vector2) - centro).normalized())
	for i in dirs.size():
		for k in dirs.size():
			if absf((dirs[i] as Vector2).dot(dirs[k])) < 0.3:
				salida.append(dirs[i])
				break
	return salida


# Franjas blancas (una sola malla por cruce) a "hs" metros del centro, en cada calle.
func _dibujar_pasos(sem: Node3D, red: Dictionary, nodo: Vector2i, brazos: Array) -> void:
	if brazos.is_empty():
		return
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ancho: float = float(red["ancho"])
	var hs: float = _hs(red)
	var n: int = int(floor((ancho - 1.0) / 1.2))
	for e in brazos:
		var dir: Vector2 = e
		var lat: Vector2 = Vector2(-dir.y, dir.x)
		var centro: Vector2 = dir * hs
		for i in n:
			var off: float = (i - (n - 1) * 0.5) * 1.2
			var c: Vector2 = centro + lat * off
			var puntos: Array = [c - dir * 1.4 - lat * 0.3, c + dir * 1.4 - lat * 0.3, c + dir * 1.4 + lat * 0.3, c - dir * 1.4 + lat * 0.3]
			for k in [0, 1, 2, 0, 2, 3]:
				var q: Vector2 = puntos[k]
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(q.x, 0.19 if red["id"] != "ciudad" else 0.06, q.y))
	var malla: ArrayMesh = st.commit()
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.88, 0.88, 0.85)
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	malla.surface_set_material(0, m)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = malla
	sem.add_child(mi)


func _construir_semaforo(red: Dictionary, nodo: Vector2i) -> Semaforo:
	var sem: Semaforo = Semaforo.new()
	var mats: Array = [[], []]
	var colores: Array = [Color(1.0, 0.1, 0.1), Color(1.0, 0.7, 0.1), Color(0.1, 1.0, 0.25)]
	for eje in 2:
		for i in 3:
			var m: StandardMaterial3D = StandardMaterial3D.new()
			m.albedo_color = colores[i]
			m.emission_enabled = true
			m.emission = colores[i]
			m.emission_energy_multiplier = 0.0
			mats[eje].append(m)
	sem.lamparas = mats
	var medio: float = float(red["ancho"]) * 0.5 + 1.2
	# Un poste en cada esquina: las esquinas "diagonales" comparten eje.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var eje: int = 0 if sx * sz > 0.0 else 1
			var base: Vector3 = Vector3(sx * medio, 0.0, sz * medio)
			Construir.cilindro(sem, base + Vector3(0, 1.7, 0), 0.07, 3.4, Color(0.15, 0.15, 0.17), false)
			Construir.caja(sem, base + Vector3(0, 3.2, 0), Vector3(0.38, 1.05, 0.38), Color(0.08, 0.08, 0.09), false)
			for i in 3:
				var lampara: MeshInstance3D = MeshInstance3D.new()
				var esfera: SphereMesh = SphereMesh.new()
				esfera.radius = 0.12
				esfera.height = 0.24
				lampara.mesh = esfera
				lampara.material_override = mats[eje][i]
				lampara.position = base + Vector3(0, 3.5 - i * 0.3, 0)
				lampara.scale = Vector3(1.9, 1.0, 1.9)   # Se ven desde cualquier lado.
				sem.add_child(lampara)
	return sem


func _actualizar_semaforos() -> void:
	for clave in _semaforos:
		var sem: Semaforo = _semaforos[clave]
		if sem.lamparas[0].is_empty():
			continue
		var nodo: Vector2i = sem.get_meta("nodo")
		for eje in 2:
			var e: int = estado_semaforo(eje, nodo)
			if e == sem.estado[eje]:
				continue
			sem.estado[eje] = e
			# Posiciones: 0 rojo, 1 ámbar, 2 verde (en las lámparas); estado 0 = verde.
			var enciende: int = 2 if e == 0 else (1 if e == 1 else 0)
			for i in 3:
				(sem.lamparas[eje][i] as StandardMaterial3D).emission_energy_multiplier = 4.0 if i == enciende else 0.1
