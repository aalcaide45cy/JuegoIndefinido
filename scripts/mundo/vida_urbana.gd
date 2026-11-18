# vida_urbana.gd
# -----------------------------------------------------------------------------
# Hace que las calles estén vivas: peatones, coches y semáforos.
#   - Todo se crea SOLO cerca del jugador (radio ~110 m) y se borra al alejarse.
#   - Peatones: pasean por las aceras, hacen pausas y charlan. De día hay muchos;
#     de noche pocos y algunos van "contentos" (zigzaguean). Con lluvia fuerte hay
#     menos. Si tienes estrellas de búsqueda, huyen de ti. Se les puede hacer daño
#     (y eso sube la sospecha).
#   - Coches: circulan por el carril derecho, giran en los cruces, frenan ante
#     lo que tengan delante (tú, otros coches, peatones) y paran en rojo.
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


# Elige un tramo y un punto a 35-110 m del jugador, libre de otros agentes.
func _nuevo_agente(red: Dictionary, coche: bool) -> Agente:
	var claves: Array = red["pos"].keys()
	var yo3: Vector3 = _jugador.global_position
	for intento in 8:
		var desde: Vector2i = claves[randi() % claves.size()]
		var vecinos: Array = red["vec"][desde]
		if vecinos.is_empty():
			continue
		var hacia: Vector2i = vecinos[randi() % vecinos.size()]
		var a_pos: Vector2 = red["pos"][desde]
		var b_pos: Vector2 = red["pos"][hacia]
		var largo_tramo: float = a_pos.distance_to(b_pos)
		var dist: float = randf() * largo_tramo
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
		a.sync_to_physics = false   # Con true la posición se quedaba en (0,0,0): todos los agentes aparecían en el monumento.
		if coche:
			_vestir_coche(a)
			a.vmax = 11.0 if float(red["ancho"]) >= 8.0 else 8.0
			a.lado = float(red["ancho"]) * 0.25
		else:
			_vestir_peaton(a)
			a.vmax = 1.3
			a.lado = (float(red["ancho"]) * 0.5 + 1.0) * (1.0 if randf() < 0.5 else -1.0)
			a.alegre = Juego.hora >= 23.0 or Juego.hora < 6.0
			if a.alegre and randf() < 0.5:
				a.alegre = false
			a.fase = randf() * 6.28
			a.add_to_group("danable")
		add_child(a)
		_colocar(a)
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
		Construir.cilindro(a, Vector3(0, 0.6, 0), 0.3, 1.2, col, false)
		Construir.esfera(a, Vector3(0, 1.42, 0), 0.2, Color(0.75, 0.62, 0.52))


# Pone al agente en su sitio según su tramo y lo orienta.
func _colocar(a: Agente) -> void:
	var pa: Vector2 = a.red["pos"][a.desde]
	var pb: Vector2 = a.red["pos"][a.hacia]
	var dir: Vector2 = (pb - pa).normalized()
	var derecha: Vector2 = Vector2(-dir.y, dir.x)
	var punto: Vector2 = pa + dir * a.d + derecha * a.lado
	if a.alegre:
		punto += derecha * sin(a.fase) * 0.8
	var y: float = _altura(a.red, punto.x, punto.y)
	if a.es_coche:
		y += 0.05
	a.global_position = Vector3(punto.x, y, punto.y)
	a.rotation.y = atan2(-dir.x, -dir.y)


# --------------------------------- Movimiento ----------------------------------

func _siguiente_nodo(a: Agente) -> void:
	var llegado: Vector2i = a.hacia
	var vecinos: Array = (a.red["vec"][llegado] as Array).duplicate()
	var previo: Vector2i = a.desde
	if vecinos.size() > 1:
		vecinos.erase(previo)   # No se da la vuelta salvo en un fondo de saco.
	var elegido: Vector2i = vecinos[randi() % vecinos.size()]
	if a.huyendo and not a.es_coche:
		var yo: Vector3 = _jugador.global_position
		var mejor: float = -1.0
		for v in vecinos:
			var q: Vector2 = a.red["pos"][v]
			var dd: float = Vector2(yo.x, yo.z).distance_to(q)
			if dd > mejor:
				mejor = dd
				elegido = v
	a.desde = llegado
	a.hacia = elegido
	a.d = 0.0
	if not a.es_coche and randf() < 0.3:
		a.pausa = 3.0 + randf() * 6.0   # Se para a charlar o a mirar escaparates.


func _distancia_libre(a: Agente, dir: Vector2) -> float:
	# Metros libres por delante hasta lo primero que estorba (9 m = vía libre).
	var libre: float = 9.0
	var yo: Vector2 = Vector2(a.global_position.x, a.global_position.z)
	var obstaculos: Array = []
	obstaculos.append(_jugador)
	for v in get_tree().get_nodes_in_group("vehiculos"):
		obstaculos.append(v)
	for o in _coches:
		if o != a:
			obstaculos.append(o)
	for o in _peatones:
		obstaculos.append(o)
	for o in obstaculos:
		if not is_instance_valid(o):
			continue
		var p: Vector3 = (o as Node3D).global_position
		var rel: Vector2 = Vector2(p.x, p.z) - yo
		var delante: float = rel.dot(dir)
		if delante <= 0.0 or delante > libre + a.largo * 0.5:
			continue
		var lateral: float = absf(rel.dot(Vector2(-dir.y, dir.x)))
		if lateral < 1.9 and delante - a.largo * 0.5 < libre:
			libre = maxf(0.0, delante - a.largo * 0.5)
	return libre


func _mover_coche(a: Agente, delta: float) -> void:
	if not is_instance_valid(a):
		return
	var pa: Vector2 = a.red["pos"][a.desde]
	var pb: Vector2 = a.red["pos"][a.hacia]
	var largo_tramo: float = pa.distance_to(pb)
	var dir: Vector2 = (pb - pa).normalized()
	var objetivo: float = a.vmax
	# Semáforo del nodo al que nos acercamos.
	var restante: float = largo_tramo - a.d
	if a.red["luz"].has(a.hacia) and restante > 5.0 and restante < 14.0:
		var eje: int = 0 if absf(dir.x) > absf(dir.y) else 1
		if estado_semaforo(eje, a.hacia) != 0:
			objetivo = 0.0
	# Obstáculos por delante.
	var libre: float = _distancia_libre(a, dir)
	if libre < 9.0:
		objetivo = minf(objetivo, maxf(0.0, (libre - 2.5) * 1.2))
	# Frenar un poco antes de llegar a un fondo de saco o cruce con giro: más lento.
	if restante < 6.0:
		objetivo = minf(objetivo, 5.0)
	a.vel = move_toward(a.vel, objetivo, (6.0 if objetivo < a.vel else 3.0) * delta)
	a.d += a.vel * delta
	if a.d >= largo_tramo:
		var sobra: float = a.d - largo_tramo
		_siguiente_nodo(a)
		a.d = sobra
	_colocar(a)


func _mover_peaton(a: Agente, delta: float) -> void:
	if not is_instance_valid(a):
		return
	var yo: Vector3 = _jugador.global_position
	var cerca: float = a.global_position.distance_to(yo)
	if Juego.estrellas > 0 and cerca < 30.0:
		a.huyendo = true
	elif cerca > 40.0:
		a.huyendo = false
	var objetivo: float = a.vmax
	if a.huyendo:
		objetivo = 4.5
	elif a.alegre:
		objetivo = 0.9
	if a.pausa > 0.0:
		a.pausa -= delta
		objetivo = 0.0
		if a.huyendo:
			a.pausa = 0.0
	a.vel = move_toward(a.vel, objetivo, 4.0 * delta)
	var pa: Vector2 = a.red["pos"][a.desde]
	var pb: Vector2 = a.red["pos"][a.hacia]
	var largo_tramo: float = pa.distance_to(pb)
	a.d += a.vel * delta
	a.fase += delta * 2.0
	if a.d >= largo_tramo:
		var sobra: float = a.d - largo_tramo
		_siguiente_nodo(a)
		a.d = sobra
	_colocar(a)
	# El sentido del muñeco: el modelo mira hacia -Z de su tramo, igual que el coche.
	if a.modelo != null:
		var plano: float = a.vel
		Assets.poner_animacion(a.modelo, "Idle" if plano < 0.2 else ("Run" if plano > 3.0 else "Walk"))


# ------------------------------ Semáforos (dibujo) -----------------------------

func _crear_semaforos_cercanos() -> void:
	var yo3: Vector3 = _jugador.global_position
	for red in _cerca:
		for nodo in red["luz"]:
			var clave: String = "%s|%d_%d" % [red["id"], nodo.x, nodo.y]
			if _semaforos.has(clave):
				continue
			var p: Vector2 = red["pos"][nodo]
			if Vector2(yo3.x, yo3.z).distance_to(p) > 90.0:
				continue
			var sem: Semaforo = _construir_semaforo(red, nodo)
			add_child(sem)
			sem.global_position = Vector3(p.x, _altura(red, p.x, p.y), p.y)
			_semaforos[clave] = sem
			sem.set_meta("nodo", nodo)


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
