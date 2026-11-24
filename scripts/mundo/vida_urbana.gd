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
const P_IA: int = 5      # Fuera de su ruta: lo mueve su cerebro (huir, pelear, mirar, charlar...).
const LAT_ACERA: float = 0.9   # Lo que se puede apartar como mucho de su línea de acera (m).
# La línea del peatón va a 6 m del eje; la acera va de 4 m (bordillo, con árboles a 4,9 m) a 6,5 m.
const LAT_HACIA_CALLE: float = 0.6
const LAT_HACIA_CASAS: float = 0.1
const CICLO_SEMAFORO: float = 24.0
const VERDE: float = 10.0
const AMBAR: float = 12.0
# [modelo, largo]. Los nombres sin guion son los modelos nuevos (assets/vehiculos/, con
# ruedas que giran); los que llevan guion son los de Kenney, de reserva si faltan.
const COCHES: Array = [["sedan", 4.4], ["taxi", 4.4], ["hatchback", 3.9], ["suv", 4.6], ["furgoneta", 4.8],
		["deportivo", 4.2], ["sedan", 4.4]]
const COCHES_KENNEY: Dictionary = {"hatchback": "hatchback-sports", "furgoneta": "van", "deportivo": "sedan-sports"}
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
	# Sin peatones: las avenidas de la ciudad original tienen los edificios pegados a la calzada (a 4 m
	# del eje) y no hay acera por donde andar sin atravesar una fachada o un puesto.
	var red: Dictionary = {"id": "ciudad", "pos": {}, "vec": {}, "luz": {}, "y": 0.0, "ancho": 8.0, "coches": true, "tipo": 3,
			"peatones": false}
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
				if absi(o.x) > n or absi(o.y) > n:
					continue
				# ¿Existe la calle entre c y o? (el trazado irregular quita algunas).
				if GeneradorMundo.arista_existe(s, mini(c.x, o.x), mini(c.y, o.y), d.y == 0):
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
	var vida_max: float = 30.0
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
	var giros: Array = []              # Ruedas del modelo (ModeloVehiculo): ruedan con la velocidad.
	# --- Giros en cruces (curva Bézier de cuatro puntos entre el carril de entrada y el de salida) ---
	var sig: Vector2i = Vector2i(-9999, -9999)   # Nodo al que irá tras el cruce (elegido con tiempo).
	var sig_ok: bool = false
	var en_giro: bool = false
	var curva: Array = []              # [P0, P1, P2, P3] (Vector2)
	var curva_largo: float = 1.0
	var curva_t: float = 0.0
	var curva_vel: float = 99.0        # Velocidad con la que conviene tomar la curva.
	var curva_dir_in: Vector2 = Vector2.RIGHT
	var curva_dir_out: Vector2 = Vector2.RIGHT
	var radios: Array = []
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
	var t_reaccion: float = 0.0        # Mientras es > 0 está en una animación de golpe (no se pisa con andar).
	var dir_golpe: Vector3 = Vector3.UP
	# --- IA (scripts/ia/persona_ia.gd): carácter, emociones, árbol de comportamiento y esquivar ---
	var cerebro: PersonaIA = null
	var lat_ia: float = 0.0            # Se aparta a un lado de la acera para no chocar (m, + = a su derecha).
	var vel_mult: float = 1.0          # Frena si alguien lento le tapa el paso.

	# Lo que oye o ve (disparos, peleas, gritos...): se lo pasa al cerebro.
	func percibir(tipo: String, pos: Vector3, intensidad: float, autor: Object) -> void:
		if cerebro != null and not has_meta("muerto") and estado != VidaUrbana.P_HERIDO:
			cerebro.percibir(tipo, pos, intensidad, autor)

	func ia_vida() -> float:
		return clampf(vida / maxf(vida_max, 1.0), 0.0, 1.0)

	func ia_punto_acera():
		var vu: VidaUrbana = get_parent() as VidaUrbana
		return vu._punto_acera_cercano(self) if vu != null else null

	# Sitio donde ponerse al lado de "lider" (pareja) sin salirse de la acera.
	func ia_sitio_junto_a(lider: Node3D):
		var vu: VidaUrbana = get_parent() as VidaUrbana
		return vu._sitio_acompanante(lider as Agente) if vu != null and lider is Agente else null

	func ia_reenganchar() -> void:
		var vu: VidaUrbana = get_parent() as VidaUrbana
		if vu != null:
			vu._reenganchar(self)

	# Golpe, disparo o explosión del jugador: sangre, grito, reacción y, si es fuerte, derribo.
	func recibir_dano(cantidad: float) -> void:
		if es_coche or has_meta("muerto"):
			return
		vida -= cantidad
		huyendo = true
		BarraVida.de(self, 2.1, "neutral").mostrar(maxf(vida, 0.0) / vida_max)
		var centro: Vector3 = global_position + Vector3(0, 1.1, 0)
		Gore.salpicar(self, centro, dir_golpe, clampf(cantidad / 12.0, 0.5, 2.0))
		Gore.grito(self, centro)
		Sonido.tocar(self, "golpe", -4.0)
		asustar_testigos(16.0, true)
		if vida <= 0.0:
			Juego.sospecha = minf(100.0, Juego.sospecha + 10.0)
			Juego.avisar("Has herido a un ciudadano. La policía lo sabrá.")
			morir(dir_golpe, cantidad / 12.0, true)
		elif cantidad >= 14.0:
			estado = VidaUrbana.P_HERIDO   # Golpe fuerte: lo tira al suelo un rato.
			herido_t = 4.0
			vel = 0.0
			tumbar()
		else:
			t_reaccion = AnimCombate.una_vez(modelo, "HitReact", "Walk")

	# Atropello: daño según la velocidad, salpicadura y salir despedido.
	func derribar(dir3: Vector3, v: float, culpa_jugador: bool) -> void:
		if has_meta("muerto"):
			return
		dir_golpe = dir3
		vida -= v * 3.5
		huyendo = false
		BarraVida.de(self, 2.1, "neutral").mostrar(maxf(vida, 0.0) / vida_max)
		var centro: Vector3 = global_position + Vector3(0, 1.0, 0)
		Gore.salpicar(self, centro, dir3 + Vector3.UP * 0.3, clampf(v / 5.0, 0.6, 2.5))
		Gore.grito(self, centro)
		Sonido.tocar(self, "golpe", 0.0)
		asustar_testigos(22.0, culpa_jugador)
		lanzar(dir3, v)
		if vida <= 0.0:
			morir(dir3, v / 5.0, culpa_jugador, false)
		else:
			estado = VidaUrbana.P_HERIDO
			herido_t = 14.0
			vel = 0.0
			tumbar()
			Gore.charco(self, global_position + dir3 * clampf(v * 0.5, 1.0, 6.0), 0.5)

	func tumbar() -> void:
		if modelo != null:
			modelo.rotation.x = -PI / 2.0
			modelo.position.y = 0.25
			Assets.poner_animacion(modelo, "Idle")

	# Sale despedido en la dirección del golpe (el cuerpo vuela en arco y se queda tumbado).
	func lanzar(dir3: Vector3, v: float) -> void:
		if modelo == null:
			return
		var dist: float = clampf(v * 0.5, 1.0, 6.0)
		var fin: Vector3 = global_basis.inverse() * (dir3 * dist)
		var altura: float = clampf(v * 0.12, 0.4, 1.6)
		var anim: Tween = create_tween()
		anim.tween_method(func(t: float) -> void:
			if is_instance_valid(modelo):
				modelo.position = fin * t + Vector3.UP * (sin(PI * t) * altura + 0.25 * t), 0.0, 1.0, 0.5)

	func morir(dir3: Vector3, fuerza: float, culpa_jugador: bool, con_animacion: bool = true) -> void:
		remove_from_group("danable")
		remove_from_group("peatones")
		set_meta("muerto", true)
		set_meta("muerto_ms", Time.get_ticks_msec())
		collision_layer = 0
		if con_animacion and modelo != null and AnimCombate.una_vez(modelo, "Death") > 0.0:
			pass   # Se desploma con la animación de muerte y se queda en el suelo.
		else:
			tumbar()
		Gore.muerte(self, global_position + dir3 * (clampf(fuerza, 0.0, 3.0) if not con_animacion else 0.0), dir3, fuerza)

	# Avisa a la gente de alrededor de que ha pasado algo violento: cada uno decide según su
	# carácter (huir gritando, socorrer, encararse con el agresor, llamar a la policía, mirar...).
	# Antes esto buscaba el grupo "peatones", que nadie usaba, y no asustaba a nadie.
	# radio 22 = atropello (lo llama derribar); 16 = golpe o disparo (recibir_dano).
	func asustar_testigos(radio: float, culpa_jugador: bool) -> void:
		var jug: Node3D = get_tree().get_first_node_in_group("jugador") as Node3D
		var autor: Node3D = jug if culpa_jugador else null
		if cerebro != null and radio < 20.0:
			cerebro.me_hirieron(autor, vida_max - vida)
		var tipo: String = "atropello" if radio >= 20.0 else "violencia"
		if has_meta("muerto") or vida <= 0.0:
			tipo = "muerte"
		EstimulosIA.emitir(get_tree(), tipo, global_position, radio * 1.6, autor if autor != null else self)
		EstimulosIA.emitir(get_tree(), "grito", global_position, 24.0, self)


class Semaforo extends Node3D:
	var lamparas: Array = [[], []]   # Por eje: [rojo, ámbar, verde] (materiales).
	var estado: Array = [-1, -1]


func _ready() -> void:
	add_to_group("vida_urbana")


# Un punto de calle (x, y, z) a entre "minimo" y "maximo" metros del jugador, o null.
func punto_de_calle(minimo: float, maximo: float):
	if _jugador == null or not is_instance_valid(_jugador):
		return null
	_actualizar_redes_cercanas()
	if _cerca.is_empty():
		return null
	var yo: Vector2 = Vector2(_jugador.global_position.x, _jugador.global_position.z)
	for intento in 40:
		var red: Dictionary = _cerca[randi() % _cerca.size()]
		var claves: Array = red["pos"].keys()
		var desde: Vector2i = claves[randi() % claves.size()]
		var vecinos: Array = red["vec"][desde]
		if vecinos.is_empty():
			continue
		var hacia: Vector2i = vecinos[randi() % vecinos.size()]
		var pa: Vector2 = red["pos"][desde]
		var pb: Vector2 = red["pos"][hacia]
		var p: Vector2 = pa.lerp(pb, randf())
		var dist: float = p.distance_to(yo)
		if dist >= minimo and dist <= maximo:
			return Vector3(p.x, _altura(red, p.x, p.y) + 0.15, p.y)
	return null


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
		if bool(red.get("peatones", true)):
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
	return int(roundf(n * Graficos.factor_peatones()))   # Ajuste de gráficos: densidad de peatones.


func _gestionar() -> void:
	var yo3: Vector3 = _jugador.global_position
	# Borrar los lejanos o caídos.
	for lista in [_coches, _peatones]:
		for a in lista.duplicate():
			var lejos: bool = not is_instance_valid(a) or a.global_position.distance_to(yo3) > RADIO_BORRAR
			if not lejos and a.has_meta("muerto") and Time.get_ticks_msec() - int(a.get_meta("muerto_ms", 0)) > 20000:
				lejos = true   # El cadáver se queda 20 s en el suelo.
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
			# Parejas y grupos de amigos que pasean juntos (más de día).
			var p_grupo: float = 0.22 if Juego.hora >= 9.0 and Juego.hora < 22.0 else 0.1
			if randf() < p_grupo:
				var b: Agente = _acompanante(a)
				if b != null:
					_peatones.append(b)
	creados = 0
	while _coches.size() < int(roundf(MAX_COCHES * Graficos.factor_trafico())) and creados < 2:
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
	if not coche and not bool(red.get("peatones", true)):
		return null
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
			a.add_to_group("peatones")
			a.add_to_group("oyentes_ia")
			a.cerebro = PersonaIA.new(a, "peaton")
			a.vmax = a.cerebro.vel_andar
			if a.alegre:
				a.cerebro.agilidad *= 0.5         # Ha bebido: torpe...
				a.cerebro.valentia = minf(1.0, a.cerebro.valentia + 0.25)   # ...y valiente.
				a.cerebro.agresividad = minf(1.0, a.cerebro.agresividad + 0.2)
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
	var nuevo: Dictionary = ModeloVehiculo.crear(str(elegido[0]), a.largo, false)
	if not nuevo.is_empty():
		a.add_child(nuevo["nodo"])
		a.modelo = nuevo["nodo"]
		a.giros = nuevo["giros"]
		a.radios = nuevo["radios"]
		return
	var nombre: String = "kenney/car-kit/" + str(COCHES_KENNEY.get(str(elegido[0]), str(elegido[0])))
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
	var lat: float = float(a.s) * _hs(a.red) + a.lat_ia
	if a.alegre:
		lat += sin(a.fase) * 0.45
	return pa + dir * a.d + derecha * lat


# Pone al agente en su sitio y lo orienta. "ya" = sin suavizar (al nacer).
func _colocar(a: Agente, ya: bool = false, delta: float = 0.0) -> void:
	var pa: Vector2 = a.red["pos"][a.desde]
	var pb: Vector2 = a.red["pos"][a.hacia]
	var dir: Vector2 = (pb - pa).normalized()
	var punto: Vector2
	var yaw: float
	if a.es_coche and a.en_giro:
		punto = _bezier(a.curva, a.curva_t)
		var tg: Vector2 = _tangente(a.curva, a.curva_t)
		a.dir2 = a.curva_dir_in if a.curva_t < 0.5 else a.curva_dir_out
		yaw = atan2(-tg.x, -tg.y)
	elif a.es_coche:
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
			if a.pausa > 0.0 and a.vel < 0.3:
				var escaparate: Vector2 = Vector2(-dir.y, dir.x) * float(a.s)   # Mira hacia las casas.
				yaw = atan2(-escaparate.x, -escaparate.y)
	var y: float = _altura(a.red, punto.x, punto.y)
	if a.es_coche and a.red["id"] != "ciudad":
		y += 0.17   # Las calzadas de los pueblos van 0,15 m por encima del suelo.
	elif a.es_coche:
		y += 0.05
	else:
		y = _suelo_peaton(a, punto, y, ya, delta)
	a.global_position = Vector3(punto.x, y, punto.y)
	if ya:
		a.rotation.y = yaw
	else:
		var rapidez: float = 22.0 if (a.es_coche and a.en_giro) else 9.0
		a.rotation.y = lerp_angle(a.rotation.y, yaw, 1.0 - exp(-rapidez * delta))


# Altura de los pies de un peatón. En pueblos y ciudades la acera está 0,3 m por encima del suelo
# del pueblo y la calzada 0,15 m (antes andaban con los pies hundidos en la acera). Libre (huyendo,
# peleando...) puede ir por cualquier sitio: mira el suelo con un rayo hacia abajo de vez en cuando.
func _suelo_peaton(a: Agente, punto: Vector2, base: float, ya: bool, delta: float) -> float:
	var objetivo: float = base
	var con_acera: bool = a.red["id"] != "ciudad" and int(a.red.get("tipo", 0)) >= 1
	if a.estado == P_ACERA or a.estado == P_ESPERA:
		objetivo = base + (0.3 if con_acera else 0.0)
	else:
		var t: float = float(a.get_meta("t_suelo", 0.0)) - delta
		if t <= 0.0 or not a.has_meta("suelo_y"):
			t = 0.15
			var desde: Vector3 = Vector3(punto.x, base + 2.5, punto.y)
			var cons: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 3.0)
			cons.exclude = [a.get_rid()]
			var choque: Dictionary = get_world_3d().direct_space_state.intersect_ray(cons)
			var sy: float = float(a.get_meta("suelo_y", a.global_position.y))
			if not choque.is_empty() and not (choque["collider"] is AnimatableBody3D or choque["collider"] is CharacterBody3D or choque["collider"] is RigidBody3D):
				var hy: float = (choque["position"] as Vector3).y
				if hy < base + 1.2:
					sy = hy   # Más alto sería un tejado o un muro: no se sube.
			a.set_meta("suelo_y", sy)
		a.set_meta("t_suelo", t)
		objetivo = float(a.get_meta("suelo_y", base))
	if ya:
		return objetivo
	return lerpf(a.global_position.y, objetivo, 1.0 - exp(-14.0 * delta))


# --------------------------------- Movimiento ----------------------------------

# Metros antes del nodo donde empieza la curva (y después donde acaba): coincide con la línea de detención.
func _radio_giro(a: Agente) -> float:
	return _hs(a.red) + 2.0


# Elige con tiempo el nodo al que irá tras el cruce y calcula la curva si hay que girar.
func _elegir_siguiente(a: Agente) -> void:
	var vecinos: Array = (a.red["vec"][a.hacia] as Array).duplicate()
	if vecinos.size() > 1:
		vecinos.erase(a.desde)   # No se da la vuelta salvo en un fondo de saco.
	a.sig = vecinos[randi() % vecinos.size()]
	a.sig_ok = true
	var pa: Vector2 = a.red["pos"][a.desde]
	var pb: Vector2 = a.red["pos"][a.hacia]
	var pc: Vector2 = a.red["pos"][a.sig]
	var dir_in: Vector2 = (pb - pa).normalized()
	var dir_out: Vector2 = (pc - pb).normalized()
	a.curva_dir_in = dir_in
	a.curva_dir_out = dir_out
	var angulo: float = absf(dir_in.angle_to(dir_out))
	a.curva = []
	a.curva_vel = 99.0
	if angulo < 0.2:
		return   # Recto: no hace falta curva.
	var r: float = _radio_giro(a)
	var p_ent: Vector2 = pb - dir_in * r + Vector2(-dir_in.y, dir_in.x) * a.lado
	var p_sal: Vector2 = pb + dir_out * r + Vector2(-dir_out.y, dir_out.x) * a.lado
	var cuerda: float = p_ent.distance_to(p_sal)
	var h: float = maxf(cuerda * 0.4, 2.5) if angulo > 2.6 else cuerda * 0.4
	a.curva = [p_ent, p_ent + dir_in * h, p_sal - dir_out * h, p_sal]
	var largo: float = 0.0
	var prev: Vector2 = p_ent
	for i in range(1, 9):
		var q: Vector2 = _bezier(a.curva, float(i) / 8.0)
		largo += prev.distance_to(q)
		prev = q
	a.curva_largo = maxf(largo, 1.0)
	# Cuanto más cerrada la curva, más despacio: ~15 km/h en un giro de 90 grados, ~10 en una vuelta en U.
	a.curva_vel = lerpf(a.vmax, 4.2, clampf(angulo / 1.2, 0.0, 1.0))
	if angulo > 2.6:
		a.curva_vel = 3.0


static func _bezier(c: Array, t: float) -> Vector2:
	var u: float = 1.0 - t
	return (c[0] as Vector2) * (u * u * u) + (c[1] as Vector2) * (3.0 * u * u * t) 			+ (c[2] as Vector2) * (3.0 * u * t * t) + (c[3] as Vector2) * (t * t * t)


static func _tangente(c: Array, t: float) -> Vector2:
	var u: float = 1.0 - t
	var v: Vector2 = ((c[1] as Vector2) - (c[0] as Vector2)) * (3.0 * u * u) 			+ ((c[2] as Vector2) - (c[1] as Vector2)) * (6.0 * u * t) 			+ ((c[3] as Vector2) - (c[2] as Vector2)) * (3.0 * t * t)
	return v.normalized() if v.length() > 0.001 else Vector2.RIGHT


# Pasa al tramo siguiente sin curva (cruce recto o fondo de saco con salto de carril).
func _siguiente_nodo(a: Agente) -> void:
	if not a.sig_ok:
		_elegir_siguiente(a)
	var antes: Vector2 = _punto_tramo(a)
	a.desde = a.hacia
	a.hacia = a.sig
	a.sig_ok = false
	a.d = 0.0
	a.corr = antes - _punto_tramo(a)


# Entra en la curva: el coche deja de seguir el tramo recto y sigue la Bézier.
func _empezar_giro(a: Agente, pasado: float = 0.0) -> void:
	a.en_giro = true
	a.curva_t = clampf(pasado / a.curva_largo, 0.0, 0.5)   # Si ya se pasó del inicio, entra por donde toca.
	a.corr = Vector2.ZERO


# Acaba la curva: ya está en el carril del tramo nuevo, a "radio" metros del cruce.
func _terminar_giro(a: Agente, sobra: float) -> void:
	a.en_giro = false
	a.desde = a.hacia
	a.hacia = a.sig
	a.sig_ok = false
	a.d = _radio_giro(a) + sobra
	a.corr = Vector2.ZERO
	a.dir2 = a.curva_dir_out


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
		if qo.distance_to(pb) < hs + 1.0:
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
	var radio: float = _radio_giro(a)
	if a.en_giro:
		dir = _tangente(a.curva, a.curva_t)   # Dentro del cruce, "delante" es hacia donde apunta la curva.
	var objetivo: float = a.vmax
	var motivo: int = 0   # 0 libre, 1 parada legítima (rojo, paso de peatones), 2 atasco.
	var parar: int = 0    # Debe esperar en la línea de detención: 0 no, 1 semáforo, 2 tráfico.
	a.t_golpe = maxf(0.0, a.t_golpe - delta)
	a.fantasma = maxf(0.0, a.fantasma - delta)
	if a.frenazo > 0.0:
		a.frenazo -= delta
		objetivo = 0.0
		motivo = 1
	var restante: float = largo_tramo - a.d
	if not a.en_giro:
		if not a.sig_ok and restante < 45.0:
			_elegir_siguiente(a)
		# --- Línea de detención ante el cruce al que llegamos ---
		var linea: float = restante - radio
		if linea > -0.5 and linea < 30.0 and not (linea <= 0.0 and a.vel > 0.8):
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
			if parar == 0 and a.sig_ok and _peaton_en_paso(a.red, a.hacia, a.sig):
				parar = 1   # Gente cruzando justo en la calle por la que voy a salir.
			if parar > 0:
				objetivo = minf(objetivo, _frenar_para(linea, 0.0))
				motivo = maxi(motivo, parar)
				a.bloqueo = "semaforo" if parar == 1 else "cruce"
		# --- Frenar antes de una curva cerrada ---
		if a.sig_ok and a.curva_vel < a.vmax and linea < 30.0:
			objetivo = minf(objetivo, sqrt(a.curva_vel * a.curva_vel + 2.0 * 4.5 * maxf(0.0, linea)))
		# --- Paso de peatones justo después de salir de un cruce ---
		if a.d < hs - 2.0 and _peaton_en_paso(a.red, a.desde, a.hacia):
			objetivo = minf(objetivo, _frenar_para(hs - 2.0 - a.d, 0.0))
			motivo = maxi(motivo, 1)
	else:
		objetivo = minf(objetivo, a.curva_vel)
	# --- Algo aparcado en mi carril: lo rodeo por el otro carril si no viene nadie de frente ---
	var quiere_rodear: bool = not a.en_giro and restante > radio + 14.0 and a.d > radio + 2.0 			and _estorbo_estatico(a, dir) and (a.desvio > 0.5 or _carril_contrario_libre(a))
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
	for i in a.giros.size():
		(a.giros[i] as Node3D).rotation.x -= a.vel * delta / maxf(0.05, float(a.radios[i]))
	var dist_j: float = (a.global_position - _jugador.global_position).length()
	if a.en_giro:
		a.curva_t += a.vel * delta / a.curva_largo
		if a.curva_t >= 1.0:
			_terminar_giro(a, (a.curva_t - 1.0) * a.curva_largo)
	else:
		a.d += a.vel * delta
		if parar > 0:
			a.d = minf(a.d, largo_tramo - radio + 0.3)   # Ni un palmo más allá de la línea con rojo.
		if a.d >= largo_tramo - radio and a.curva.size() == 4 and a.sig_ok and parar == 0:
			if (a.red["vec"][a.hacia] as Array).size() == 1 and dist_j > 45.0:
				a.set_meta("muerto", true)   # Fin de calle sin salida y fuera de la vista.
				a.d = largo_tramo - radio    # (se queda quieto hasta que lo borre _gestionar)
				a.vel = 0.0
			else:
				_empezar_giro(a, minf(a.d - (largo_tramo - radio), 0.6))
		elif a.d >= largo_tramo and parar == 0:
			var sobra: float = a.d - largo_tramo
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
	var v: float = a.vel
	var dir3: Vector3 = p.global_position - a.global_position
	dir3.y = 0.0
	dir3 = dir3.normalized() if dir3.length() > 0.01 else Vector3.FORWARD
	a.vel = 0.0
	a.frenazo = 2.5
	p.derribar(dir3, v, false)
	if not p.has_meta("muerto") and _jugador.global_position.distance_to(p.global_position) < 30.0:
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
		# Cada uno espera en un sitio algo distinto de la esquina (no todos en el mismo punto).
		a.p2 = k0 + Vector2(randf_range(-0.7, 0.7), randf_range(-0.7, 0.7))
	if a.estado == P_ESPERA or a.estado == P_CRUZA:
		a.destino += Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))


func _entrar_tramo(a: Agente, nuevo: Array) -> void:
	var antes: Vector2 = a.p2
	a.desde = nuevo[0]
	a.hacia = nuevo[1]
	a.s = int(nuevo[2])
	a.d = _hs(a.red)
	a.estado = P_ACERA
	a.cruce_nodo = Vector2i(-9999, -9999)
	a.cruce_brazo = Vector2i(-9999, -9999)
	# Sin saltos: conserva lo apartado que venía respecto a la línea de la acera nueva.
	var pa: Vector2 = a.red["pos"][a.desde]
	var pb: Vector2 = a.red["pos"][a.hacia]
	var dir: Vector2 = (pb - pa).normalized()
	var rel: Vector2 = antes - pa
	a.lat_ia = clampf(rel.dot(Vector2(-dir.y, dir.x)) - float(a.s) * _hs(a.red), -LAT_ACERA, LAT_ACERA)
	a.d = clampf(rel.dot(dir), _hs(a.red), maxf(_hs(a.red), pa.distance_to(pb) - _hs(a.red)))
	if randf() < 0.15:
		a.pausa = 2.0 + randf() * 5.0   # Se para a mirar un escaparate (las charlas las decide su cerebro).
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
	if not is_instance_valid(a) or a.has_meta("muerto"):
		return
	a.t_reaccion -= delta
	if a.estado == P_HERIDO:
		a.herido_t -= delta
		if a.herido_t <= 0.0:
			# Se levanta; su cerebro decide (normalmente huir del que le hizo daño o pedir ayuda).
			if a.modelo != null:
				a.modelo.rotation.x = 0.0
				a.modelo.position.y = 0.0
			a.estado = P_IA
			if a.cerebro != null:
				a.cerebro.miedo = maxf(a.cerebro.miedo, 0.6)
				a.cerebro.libre = true
		_colocar(a, false, delta)
		return
	var cer: PersonaIA = a.cerebro
	if cer != null:
		cer.pensar(delta)
		if cer.libre:
			# Su cerebro manda: se mueve libre por donde haga falta, esquivando a todos.
			if a.estado != P_IA:
				a.p2 = Vector2(a.global_position.x, a.global_position.z)
				a.estado = P_IA
				a.pausa = 0.0
			a.p2 += cer.vel * delta
			a.vel = cer.vel.length()
			var m: Vector2 = cer.mirar
			if m == Vector2.ZERO and cer.vel.length() > 0.15:
				m = cer.vel.normalized()
			a.destino = a.p2 + m
			_colocar(a, false, delta)
			if a.modelo != null and a.t_reaccion <= 0.0:
				cer.animar(a.modelo)
			return
		elif a.estado == P_IA:
			_reenganchar(a)
	var objetivo: float = a.vmax * a.vel_mult
	if a.alegre:
		objetivo = 0.9 * a.vel_mult
	# Nadie anda a velocidad de robot: el paso oscila un poco.
	objetivo *= 1.0 + 0.06 * sin(a.fase * 0.37)
	match a.estado:
		P_ACERA:
			if a.pausa > 0.0:
				a.pausa -= delta
				objetivo = 0.0
			var pa2: Vector2 = a.red["pos"][a.desde]
			var pb2: Vector2 = a.red["pos"][a.hacia]
			var largo_tramo: float = pa2.distance_to(pb2)
			# Esquivar en la acera: se aparta a un lado y ajusta el paso según quién venga.
			if cer != null:
				var lims: Vector2 = _lims_lat(a)
				var esq: Array = cer.esquiva_acera(a.lat_ia, (pb2 - pa2).normalized(), a.vel, lims.x, lims.y, delta)
				a.lat_ia = float(esq[0])
				a.vel_mult = move_toward(a.vel_mult, float(esq[1]), delta * 2.5)
			a.vel = move_toward(a.vel, objetivo, 4.0 * delta)
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
				var v_cruce: float = maxf(1.6, a.vmax * 1.25)
				a.vel = move_toward(a.vel, v_cruce, 6.0 * delta)
				var falta: Vector2 = a.destino - a.p2
				var paso: float = a.vel * delta
				if falta.length() <= paso + 0.05:
					a.p2 = a.destino
					if a.estado == P_LIBRE:
						a.s = -a.s
						_entrar_tramo(a, [a.desde, a.hacia, a.s])
						a.d_libre = -1.0
					else:
						_entrar_tramo(a, a.nuevo)
				else:
					var deseo: Vector2 = falta.normalized() * a.vel
					if cer != null:
						deseo = cer.esquivar_paso(deseo, delta)   # En el paso de cebra también se esquivan.
					a.p2 += deseo * delta
	_colocar(a, false, delta)
	if a.modelo != null and a.estado != P_HERIDO and a.t_reaccion <= 0.0:
		Assets.animar_por_velocidad(a.modelo, a.vel)


# Límites de lo que se aparta en la acera, en el sentido "a su derecha" (+): depende de en qué
# lado de la calle vaya (s = +1: las casas quedan a su derecha).
func _lims_lat(a: Agente) -> Vector2:
	if a.s >= 0:
		return Vector2(-LAT_HACIA_CALLE, LAT_HACIA_CASAS)
	return Vector2(-LAT_HACIA_CASAS, LAT_HACIA_CALLE)


# Crea a alguien que pasea junto a "lider" (pareja o amigo), justo a su lado.
func _acompanante(lider: Agente) -> Agente:
	var b: Agente = Agente.new()
	b.red = lider.red
	b.desde = lider.desde
	b.hacia = lider.hacia
	b.d = maxf(_hs(lider.red), lider.d - 0.4)
	b.s = lider.s
	b.lat_ia = clampf(lider.lat_ia - 0.8, -LAT_ACERA, LAT_ACERA)
	b.collision_layer = 1
	b.collision_mask = 0
	b.sync_to_physics = false
	_vestir_peaton(b)
	b.add_to_group("danable")
	b.add_to_group("peatones")
	b.add_to_group("oyentes_ia")
	b.cerebro = PersonaIA.new(b, "peaton")
	b.cerebro.lider = lider
	if lider.cerebro != null:
		lider.cerebro._lat_pref = 0.1 if lider.s >= 0 else -0.1   # El líder va hacia las casas; su pareja, al lado de la calle.
	b.cerebro.libre = true
	b.vmax = lider.vmax
	b.alegre = false
	add_child(b)
	_colocar(b, true)
	b.p2 = Vector2(b.global_position.x, b.global_position.z)
	b.estado = P_IA
	return b


# Al lado del líder, hacia la calle, en su misma acera (null si el líder no va por la acera).
func _sitio_acompanante(l: Agente):
	if l == null or not is_instance_valid(l) or l.estado != P_ACERA:
		return null
	var pa: Vector2 = l.red["pos"][l.desde]
	var pb: Vector2 = l.red["pos"][l.hacia]
	var dir: Vector2 = (pb - pa).normalized()
	var lat: float = float(l.s) * _hs(l.red) + l.lat_ia - float(l.s) * 0.72
	return pa + dir * (l.d - 0.2) + Vector2(-dir.y, dir.x) * lat


# Punto de acera más cercano a un peatón que anda libre (para que vuelva a su ruta).
# Guarda en el peatón el tramo elegido (meta "acera") para _reenganchar.
func _punto_acera_cercano(a: Agente):
	if a.red.is_empty():
		return null
	var yo: Vector2 = Vector2(a.global_position.x, a.global_position.z)
	var hs: float = _hs(a.red)
	var mejor: float = 1.0e9
	var res = null
	var frente3: Vector3 = -a.global_basis.z
	var frente: Vector2 = Vector2(frente3.x, frente3.z)
	for k in a.red["vec"]:
		var pk: Vector2 = a.red["pos"][k]
		if pk.distance_to(yo) > GeneradorMundo.BLOQUE * 1.6:
			continue
		for v in a.red["vec"][k]:
			var pv: Vector2 = a.red["pos"][v]
			var largo: float = pk.distance_to(pv)
			if largo < hs * 2.0 + 1.0:
				continue
			var dir: Vector2 = (pv - pk) / largo
			var der: Vector2 = Vector2(-dir.y, dir.x)
			var rel: Vector2 = yo - pk
			var d: float = clampf(rel.dot(dir), hs, largo - hs)
			var lado: int = 1 if rel.dot(der) >= 0.0 else -1
			var punto: Vector2 = pk + dir * d + der * float(lado) * hs
			var dist: float = punto.distance_to(yo)
			# Entre los dos sentidos del mismo tramo, el que va hacia donde ya mira.
			if dir.dot(frente) < 0.0:
				dist += 0.01
			if dist < mejor:
				mejor = dist
				res = punto
				a.set_meta("acera", [k, v, d, lado])
	return res


# Vuelve a su ruta normal por la acera más cercana.
func _reenganchar(a: Agente) -> void:
	if not a.has_meta("acera"):
		_punto_acera_cercano(a)
	if not a.has_meta("acera"):
		return
	var t: Array = a.get_meta("acera")
	a.remove_meta("acera")
	a.desde = t[0]
	a.hacia = t[1]
	a.s = int(t[3])
	a.p2 = Vector2(a.global_position.x, a.global_position.z)
	_entrar_tramo(a, [a.desde, a.hacia, a.s])
	a.pausa = 0.0
	a.vel_mult = 1.0
	if a.cerebro != null:
		a.cerebro.libre = false


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
