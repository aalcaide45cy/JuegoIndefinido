# persona_ia.gd
# -----------------------------------------------------------------------------
# El "cerebro" de un personaje (peatón, vecino de una casa...). Une cuatro piezas:
#
#   1. CARÁCTER (rasgos, 0-1, distintos en cada persona): valentía, agresividad, curiosidad,
#      sociabilidad, civismo (ayudar / llamar a la policía), agilidad, prisa. Algunos van armados.
#   2. EMOCIONES que suben con lo que pasa y bajan solas con el tiempo: miedo, ira, alerta.
#   3. PERCEPCIÓN: lo que ve (al jugador, si lleva un arma, si le apunta, si viene un coche
#      encima, heridos...) y lo que oye (EstimulosIA: disparos, explosiones, gritos, peleas).
#   4. DECISIÓN con un árbol de comportamiento (ArbolIA, ver arboles_ia.gd) que elige qué hacer
#      puntuando opciones según el carácter y las emociones: huir, pelear a puñetazos, sacar la
#      pistola, cubrirse, suplicar, llamar a la policía, socorrer, mirar, quejarse, charlar...
#
# Y para MOVERSE con naturalidad, un "piloto" (steering):
#   - esquiva a los demás ANTES de chocar (predice dónde estará cada uno en ~2 s),
#   - evita paredes y obstáculos con 3 "bigotes" (rayos) que miran hacia delante,
#   - acelera y frena con suavidad, y cada persona tiene su ritmo.
#
# El cerebro NO mueve el cuerpo directamente: calcula "vel" (m/s en el plano XZ), "mirar" (hacia
# dónde girarse) y "libre" (si quiere el control o deja la rutina normal al dueño). Quien lo usa
# (VidaUrbana para los peatones, Vecino para los de las casas) lo aplica a su manera.
#
# Lo que el cuerpo puede ofrecer (todo opcional, se mira con has_method / get):
#   modelo (Node3D animado de Quaternius), ia_vida() -> 0..1, ia_punto_acera() -> Vector2 o null,
#   ia_reenganchar(), ia_ruta(destino: Vector3) -> Array de Vector3, ia_salida() -> Vector3,
#   ia_escondite() -> Vector3, ia_denunciar(), ia_puede_moverse() -> bool.
# -----------------------------------------------------------------------------
class_name PersonaIA
extends RefCounted

const R: int = ArbolIA.EXITO
const F: int = ArbolIA.FALLO
const C: int = ArbolIA.CORRIENDO

const RADIO_PERSONAL: float = 0.42     # Radio de "burbuja" de una persona (para esquivar).
const VISTA: float = 28.0
const PERIODO_PENSAR: float = 0.12     # El árbol se recorre ~8 veces por segundo.
const PERIODO_PERCIBIR: float = 0.25

# Frases cortas que dicen en voz alta (bocadillo sobre la cabeza). Dan mucha vida.
const FRASES: Dictionary = {
	"huir": ["¡Socorro!", "¡Corred!", "¡Ayuda!", "¡Está loco!", "¡Que alguien haga algo!", "¡Aaah!"],
	"disparo": ["¡Al suelo!", "¡Está disparando!", "¡Tiros!", "¡Cuidado!"],
	"pelear": ["¡Te vas a enterar!", "¿Buscas pelea?", "¡Ven aquí!", "¡Ahora verás!", "¡Cobarde!"],
	"arma": ["¡Quieto o disparo!", "¡Suelta eso!", "¡No te muevas!", "¡Atrás!"],
	"suplicar": ["¡No dispare, por favor!", "¡Tengo familia!", "¡Tranquilo, tranquilo!", "¡No me haga daño!"],
	"robo": ["¡Toma, toma, llévatelo!", "¡Es todo lo que llevo!", "¡Cógelo y vete!"],
	"llamar": ["¿Policía? ¡Vengan rápido!", "¡Estoy llamando a la policía!", "¡Ya vienen los guardias!"],
	"socorrer": ["¿Está bien?", "¡Una ambulancia!", "¡No se mueva!", "Tranquilo, ya viene ayuda."],
	"mirar": ["Madre mía...", "¿Qué ha pasado?", "Qué barbaridad.", "¿Lo has visto?", "Esto no es normal."],
	"quejarse": ["¡Eh! ¡Mira por dónde vas!", "¡Cuidado, hombre!", "¿Estás ciego?", "¡Oye!"],
	"coche": ["¡Animal!", "¡Casi me matas!", "¡Mira por dónde conduces!", "¡Loco!"],
	"saludo": ["¡Buenas!", "Hola.", "¡Buen día!", "¿Qué tal?"],
	"nervioso": ["Eh, tranquilo...", "Guarda eso, ¿vale?", "No quiero problemas."],
	"charla": ["...y entonces le dije...", "¡No me digas!", "Ya ves.", "¡Qué me cuentas!", "Pues eso."],
	"intruso": ["¿Quién anda ahí?", "¡Fuera de mi casa!", "¡Ladrón!", "¡Sal de aquí!"],
	"herido": ["¡Ay!", "¡Ugh!", "¡Para!"],
}

static var _arboles: Dictionary = {}          # tipo -> ArbolIA.Nodo (compartidos)
static var _cache_frame: int = -1
static var _cache_personas: Array = []        # Personas con IA cerca (se refresca 1 vez por fotograma)

var cuerpo: Node3D
var tipo: String = "peaton"
var bb: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# --- Carácter ---
var valentia: float = 0.5
var agresividad: float = 0.3
var curiosidad: float = 0.5
var sociabilidad: float = 0.5
var civismo: float = 0.5
var agilidad: float = 0.5
var prisa: float = 0.5
var armado: bool = false
var arma_modelo: String = "Pistol"   # Nodo del modelo de Quaternius que se enseña al sacarla.
var arma_mano: String = ""           # Arma cuerpo a cuerpo (Shovel, Knife) o "" = puños.
var dano_puno: float = 6.0
var dano_mano: float = 14.0
var dano_bala: float = 11.0
var punteria: float = 0.6
var vel_andar: float = 1.3
var vel_correr: float = 4.6

# --- Emociones ---
var miedo: float = 0.0
var ira: float = 0.0
var alerta: float = 0.0

# --- Memoria ---
var amenaza: Node3D = null
var amenaza_pos: Vector3 = Vector3.ZERO
var t_amenaza: float = -99.0          # reloj de la última vez que la amenaza hizo algo
var amenaza_dispara: bool = false
var incidente_pos: Vector3 = Vector3.ZERO
var t_incidente: float = -99.0
var herido: Node3D = null
var t_disparo: float = -99.0          # último disparo oído cerca
var apuntado: bool = false
var jugador_armado: int = 0           # 0 nada, 1 arma de mano, 2 arma de fuego
var empujado: bool = false
var llamo_policia: bool = false
var robado: bool = false
var lider: Node3D = null              # Si va acompañando a alguien.
var coche_peligro: Node3D = null
var coche_vel: Vector3 = Vector3.ZERO

# --- Salida hacia el cuerpo ---
var libre: bool = false               # true: el cerebro quiere el control del movimiento.
var vel: Vector2 = Vector2.ZERO       # Velocidad actual (m/s) en el plano.
var mirar: Vector2 = Vector2.ZERO     # Hacia dónde mirar (ZERO = hacia donde anda).
var anim_fija: String = ""            # Animación en bucle mientras dure ("Duck", "Idle_Shoot"...).
var t_anim: float = 0.0               # > 0: suena una animación de una vez (no pisar con andar).
var arma_fuera: bool = false
var accion: String = ""               # Nombre de lo que hace (para depurar y pruebas).

var reloj: float = 0.0
var _deseo: Vector2 = Vector2.ZERO    # Velocidad que pide la acción (antes de esquivar).
var _t_pensar: float = 0.0
var _acum: float = 0.0
var _t_percibir: float = 0.0
var _t_bigotes: float = 0.0
var _evita: Vector2 = Vector2.ZERO    # Corrección por paredes (de los bigotes).
var _enfr_jugador: float = 0.0        # Para notar cuándo el jugador lanza un golpe.
var _jugador: Node3D = null
var _bocadillo: Label3D = null
var _t_bocadillo: float = 0.0
var _lat_pref: float = 0.0            # Carril personal en la acera.
var _ruta: Array = []                 # Puntos intermedios (dentro de casas).
var _ruta_destino: Vector3 = Vector3.INF


func _init(c: Node3D, t: String = "peaton", semilla: int = 0) -> void:
	cuerpo = c
	tipo = t
	if semilla != 0:
		rng.seed = semilla
	else:
		rng.randomize()
	_tirar_caracter()
	_t_pensar = rng.randf() * PERIODO_PENSAR   # Que no piensen todos en el mismo fotograma.
	_t_percibir = rng.randf() * PERIODO_PERCIBIR


# Cada persona es distinta: rasgos al azar con alguna correlación (los agresivos suelen ser
# valientes; los cívicos, menos agresivos).
func _tirar_caracter() -> void:
	valentia = clampf(rng.randfn(0.45, 0.22), 0.0, 1.0)
	agresividad = clampf(rng.randfn(0.25 + valentia * 0.3, 0.2), 0.0, 1.0)
	curiosidad = clampf(rng.randfn(0.5, 0.25), 0.0, 1.0)
	sociabilidad = clampf(rng.randfn(0.5, 0.25), 0.0, 1.0)
	civismo = clampf(rng.randfn(0.6 - agresividad * 0.3, 0.2), 0.0, 1.0)
	agilidad = clampf(rng.randfn(0.55, 0.2), 0.05, 1.0)
	prisa = clampf(rng.randfn(0.45, 0.25), 0.0, 1.0)
	# 6 % lleva pistola (más los agresivos); nunca los muy cobardes.
	armado = valentia > 0.3 and rng.randf() < 0.03 + agresividad * 0.1
	arma_modelo = ["Pistol", "Revolver", "Revolver_Small"][rng.randi() % 3]
	vel_andar = clampf(1.0 + prisa * 0.55 + rng.randfn(0.0, 0.08), 0.85, 1.75)
	vel_correr = clampf(3.8 + agilidad * 1.6, 3.6, 5.6)
	dano_puno = 4.0 + agresividad * 4.0
	punteria = clampf(rng.randfn(0.55, 0.15), 0.25, 0.85)
	_lat_pref = rng.randf_range(-0.35, 0.35)


# Rasgos fijados por quien crea a la persona (p. ej. los vecinos según Asaltos.elegir_reaccion).
func ajustar(rasgos: Dictionary) -> void:
	for k in rasgos:
		if k in self:
			set(k, rasgos[k])


func arbol() -> ArbolIA.Nodo:
	if not _arboles.has(tipo):
		_arboles[tipo] = ArbolesIA.construir(tipo)
	return _arboles[tipo]


# ================================ Cada fotograma ===============================

func pensar(delta: float) -> void:
	if cuerpo == null or not is_instance_valid(cuerpo):
		return
	reloj += delta
	bb["reloj"] = reloj
	t_anim -= delta
	_t_bocadillo -= delta
	if _bocadillo != null and _t_bocadillo <= 0.0:
		if is_instance_valid(_bocadillo):
			_bocadillo.queue_free()
		_bocadillo = null
	# Las emociones se calman solas (el valiente se calma antes).
	miedo = maxf(0.0, miedo - delta * (0.035 + valentia * 0.05))
	ira = maxf(0.0, ira - delta * 0.025)
	alerta = maxf(0.0, alerta - delta * 0.05)
	_t_percibir -= delta
	if _t_percibir <= 0.0:
		_t_percibir = PERIODO_PERCIBIR
		_percibir()
	_acum += delta
	_t_pensar -= delta
	if _t_pensar <= 0.0:
		_t_pensar = PERIODO_PENSAR
		arbol().tick(self, bb, _acum)
		_acum = 0.0
	# Piloto: la velocidad sigue al deseo con aceleración limitada y esquivando.
	if libre:
		var objetivo: Vector2 = _dirigir(_deseo, delta)
		var acel: float = 9.0 if objetivo.length() > vel.length() else 12.0
		vel = vel.move_toward(objetivo, acel * delta)
	else:
		vel = Vector2.ZERO


# Decide la animación base (quien la aplica llama a esto cada fotograma).
func animar(modelo: Node3D) -> void:
	if modelo == null or t_anim > 0.0:
		return
	var v: float = vel.length() if libre else -1.0
	if anim_fija != "":
		if arma_fuera and v > 0.4:
			Assets.poner_animacion(modelo, "Run_Shoot" if v > 3.0 else "Walk_Shoot")
		else:
			Assets.poner_animacion(modelo, anim_fija)
		return
	if v < 0.0:
		return   # En rutina anima el dueño.
	if arma_fuera and v > 3.0:
		Assets.poner_animacion(modelo, "Run_Gun", clampf(v / Assets.VEL_ANIM_CORRER, 0.6, 1.6))
	else:
		Assets.animar_por_velocidad(modelo, v)


func una_vez(nombre: String, volver: String = "") -> float:
	var m: Node3D = cuerpo.get("modelo") as Node3D
	var dur: float = AnimCombate.una_vez(m, nombre, volver)
	if dur > 0.0:
		t_anim = dur * 0.92
	return dur


func decir(clase: String, prob: float = 1.0) -> void:
	if not FRASES.has(clase) or rng.randf() > prob or _t_bocadillo > 0.6:
		return
	var lista: Array = FRASES[clase]
	if _bocadillo != null and is_instance_valid(_bocadillo):
		_bocadillo.queue_free()
	var col: Color = Color(1, 0.95, 0.85)
	if clase in ["huir", "disparo", "suplicar", "herido"]:
		col = Color(1.0, 0.75, 0.6)
	elif clase in ["pelear", "arma", "intruso", "coche", "quejarse"]:
		col = Color(1.0, 0.55, 0.45)
	_bocadillo = Construir.texto(cuerpo, Vector3(0, 2.25, 0), str(lista[rng.randi() % lista.size()]), 34, col)
	_bocadillo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bocadillo.no_depth_test = false
	_t_bocadillo = 2.2


# ================================= Percepción ==================================

func jugador() -> Node3D:
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = cuerpo.get_tree().get_first_node_in_group("jugador") as Node3D
	return _jugador


func pos2() -> Vector2:
	return Vector2(cuerpo.global_position.x, cuerpo.global_position.z)


func frente() -> Vector2:
	var b: Vector3 = -cuerpo.global_basis.z
	return Vector2(b.x, b.z).normalized()


func vida() -> float:
	return float(cuerpo.ia_vida()) if cuerpo.has_method("ia_vida") else 1.0


# Lo que ve, 4 veces por segundo.
func _percibir() -> void:
	var j: Node3D = jugador()
	apuntado = false
	jugador_armado = 0
	empujado = false
	if j != null and not bool(j.get("_muerto")):
		var al: Vector3 = j.global_position - cuerpo.global_position
		var d: float = al.length()
		var en_coche: bool = j.get("vehiculo") != null
		if d < VISTA and not en_coche:
			var casilla = Juego.en_mano()
			if casilla != null:
				var t: String = str(Juego.DatosObjetos.datos(casilla["id"]).get("tipo", ""))
				jugador_armado = 2 if t == "arma_fuego" or t == "explosivo" else (1 if t == "arma_cc" else 0)
			# ¿Le apunta? (la cámara mira hacia él, cerca y con arma de fuego)
			if jugador_armado == 2 and d < 22.0:
				var cam: Camera3D = cuerpo.get_viewport().get_camera_3d()
				if cam != null:
					var hacia: Vector3 = (cuerpo.global_position + Vector3(0, 1.1, 0) - cam.global_position).normalized()
					apuntado = (-cam.global_basis.z).dot(hacia) > 0.985 - clampf(1.5 / maxf(d, 1.0), 0.0, 0.05)
			if jugador_armado > 0 and d < 12.0:
				alerta = minf(1.0, alerta + 0.2)
				miedo = minf(1.0, miedo + (0.06 if jugador_armado == 2 else 0.02) * (1.2 - valentia))
				if armado and valentia > 0.6 and jugador_armado == 2:
					ira = minf(1.0, ira + 0.03)
			if apuntado:
				miedo = minf(1.0, miedo + 0.18 * (1.3 - valentia))
				_poner_amenaza(j)
			# Te chocas con él.
			var vj: Vector3 = j.get("velocity") if j.get("velocity") != null else Vector3.ZERO
			if d < 0.95 and Vector2(vj.x, vj.z).length() > 1.2:
				empujado = true
			# Con estrellas de búsqueda la gente te tiene miedo.
			if Juego.estrellas > 0 and d < 30.0:
				miedo = minf(1.0, miedo + 0.05 * Juego.estrellas)
				_poner_amenaza(j, false)
		# Detectar golpes del jugador (para esquivarlos): su enfriamiento salta hacia arriba.
		var e: float = float(j.get("_enfriamiento")) if j.get("_enfriamiento") != null else 0.0
		if e > _enfr_jugador + 0.2 and d < 3.0:
			bb["golpe_jugador"] = reloj
		_enfr_jugador = e
	_buscar_coche_peligroso()
	_buscar_herido()
	if amenaza != null and not is_instance_valid(amenaza):
		amenaza = null


func _poner_amenaza(quien: Node3D, refrescar_tiempo: bool = true) -> void:
	if quien == null or quien == cuerpo:
		return
	amenaza = quien
	amenaza_pos = quien.global_position
	if refrescar_tiempo or reloj - t_amenaza > 8.0:
		t_amenaza = reloj


# Lo que oye o nota (lo envía EstimulosIA.emitir).
func percibir(tipo_e: String, pos: Vector3, intensidad: float, autor: Object) -> void:
	var autor3: Node3D = autor as Node3D if autor is Node3D else null
	var yo_soy_autor: bool = autor3 == cuerpo
	if yo_soy_autor:
		return
	alerta = minf(1.0, alerta + intensidad)
	match tipo_e:
		"disparo":
			t_disparo = reloj
			miedo = minf(1.0, miedo + 0.9 * intensidad * (1.25 - valentia))
			if autor3 != null:
				_poner_amenaza(autor3)
				amenaza_dispara = true
			_incidente(pos)
			decir("disparo", 0.35)
		"explosion":
			t_disparo = reloj
			miedo = minf(1.0, miedo + 1.2 * intensidad)
			_incidente(pos)
			if autor3 != null:
				_poner_amenaza(autor3)
		"violencia", "herido_yo":
			miedo = minf(1.0, miedo + 0.55 * intensidad * (1.15 - valentia))
			# Los valientes y agresivos se enfadan (defienden a la víctima).
			ira = minf(1.0, ira + 0.5 * intensidad * agresividad * (0.4 + valentia))
			if autor3 != null:
				_poner_amenaza(autor3)
			_incidente(pos)
		"grito":
			miedo = minf(1.0, miedo + 0.18 * intensidad * (1.1 - valentia))
			_incidente(pos)
		"muerte", "atropello":
			miedo = minf(1.0, miedo + 0.35 * intensidad * (1.1 - valentia))
			_incidente(pos)
			if autor3 != null and EstimulosIA.es_jugador(autor3):
				_poner_amenaza(autor3, false)
		"arma_vista":
			miedo = minf(1.0, miedo + 0.3 * intensidad * (1.2 - valentia))
			if autor3 != null:
				_poner_amenaza(autor3, false)
		"empujon":
			empujado = true


# Me han hecho daño a mí.
func me_hirieron(quien: Node3D, cantidad: float) -> void:
	ira = minf(1.0, ira + 0.25 + agresividad * 0.5)
	miedo = minf(1.0, miedo + clampf(cantidad / 30.0, 0.1, 0.6) * (1.2 - valentia))
	alerta = 1.0
	if quien != null:
		_poner_amenaza(quien)
	bb["herido_en"] = reloj
	decir("herido", 0.5)


func _incidente(pos: Vector3) -> void:
	incidente_pos = pos
	t_incidente = reloj


# ¿Viene un coche (o el tuyo) directo hacia mí?
func _buscar_coche_peligroso() -> void:
	coche_peligro = null
	var yo: Vector3 = cuerpo.global_position
	var lista: Array = cuerpo.get_tree().get_nodes_in_group("vehiculos")
	var vu: Node = cuerpo.get_tree().get_first_node_in_group("vida_urbana")
	if vu != null and vu.get("_coches") != null:
		lista = lista + (vu.get("_coches") as Array)
	for c in lista:
		if not is_instance_valid(c) or not (c is Node3D):
			continue
		var p: Vector3 = (c as Node3D).global_position
		var rel: Vector3 = yo - p
		rel.y = 0.0
		if rel.length() > 16.0 or absf(yo.y - p.y) > 3.0:
			continue
		var v: Vector3 = _velocidad_de(c)
		v.y = 0.0
		if v.length() < 3.0:
			continue
		# Tiempo hasta el punto más cercano y distancia en ese momento.
		var t: float = rel.dot(v) / v.length_squared()
		if t < 0.0 or t > 1.6:
			continue
		var paso: float = (rel - v * t).length()
		if paso < 2.0:
			coche_peligro = c
			coche_vel = v
			return


static func _velocidad_de(n: Object) -> Vector3:
	var lv = n.get("linear_velocity")
	if lv is Vector3:
		return lv
	var dir2 = n.get("dir2")
	var ve = n.get("vel")
	if dir2 is Vector2 and (ve is float or ve is int):
		return Vector3(dir2.x, 0.0, dir2.y) * float(ve)
	var v = n.get("velocity")
	if v is Vector3:
		return v
	return Vector3.ZERO


func _buscar_herido() -> void:
	if herido != null and (not is_instance_valid(herido) or herido.global_position.distance_to(cuerpo.global_position) > 25.0):
		herido = null
	if herido != null:
		return
	for n in _personas_cerca():
		if n == cuerpo or not is_instance_valid(n):
			continue
		var tumbado: bool = n.has_meta("muerto") or int(n.get("estado") if n.get("estado") != null else -1) == 3 and n.get("es_coche") == false
		if tumbado and n.global_position.distance_to(cuerpo.global_position) < 18.0:
			herido = n
			_incidente(n.global_position)
			return


# Personas con IA (y el jugador) — lista compartida, refrescada una vez por fotograma.
func _personas_cerca() -> Array:
	var f: int = Engine.get_physics_frames()
	if f != _cache_frame:
		_cache_frame = f
		_cache_personas = cuerpo.get_tree().get_nodes_in_group("oyentes_ia")
	return _cache_personas


# ================================== Piloto =====================================

# Toma la velocidad que pide la acción y la corrige para no chocar con nadie ni con paredes.
func _dirigir(deseo: Vector2, delta: float) -> Vector2:
	var yo: Vector2 = pos2()
	var empuje: Vector2 = Vector2.ZERO
	var otros: Array = _personas_cerca()
	var j: Node3D = jugador()
	if j != null:
		otros = otros + [j]
	for n in otros:
		if n == cuerpo or not is_instance_valid(n) or n.has_meta("muerto"):
			continue
		var p3: Vector3 = (n as Node3D).global_position
		if absf(p3.y - cuerpo.global_position.y) > 2.0:
			continue
		var r: Vector2 = Vector2(p3.x, p3.z) - yo
		var dist: float = r.length()
		if dist > 4.5 or dist < 0.001:
			continue
		var vo: Vector2 = _vel_de_persona(n)
		var vrel: Vector2 = vo - vel
		var suma_r: float = RADIO_PERSONAL * 2.0 + 0.1
		# Separación si ya estamos encima.
		if dist < suma_r:
			empuje -= r / dist * (suma_r - dist) * 6.0
		# Predicción: ¿dónde estaremos en el momento más cercano?
		var vv: float = vrel.length_squared()
		if vv > 0.01:
			var t: float = clampf(-r.dot(vrel) / vv, 0.0, 2.5)
			var cerca: Vector2 = r + vrel * t
			var d_cerca: float = cerca.length()
			if d_cerca < suma_r + 0.25:
				var lejos: Vector2 = -cerca / maxf(d_cerca, 0.05)
				if d_cerca < 0.05:
					lejos = Vector2(-r.y, r.x).normalized()   # De frente exacto: ambos a su derecha.
				empuje += lejos * (suma_r + 0.25 - d_cerca) / (t + 0.35) * 2.2
	# Paredes y obstáculos: 3 bigotes cada 0,15 s.
	_t_bigotes -= delta
	if _t_bigotes <= 0.0:
		_t_bigotes = 0.15
		_evita = _bigotes(deseo if deseo.length() > 0.1 else vel)
	var final: Vector2 = deseo + empuje + _evita * maxf(deseo.length(), 1.0)
	var maximo: float = maxf(deseo.length(), 0.6) * 1.15
	if final.length() > maximo:
		final = final.normalized() * maximo
	return final


func _vel_de_persona(n: Node) -> Vector2:
	var cer = n.get("cerebro")
	if cer != null and cer is PersonaIA and (cer as PersonaIA).libre:
		return (cer as PersonaIA).vel
	var v3: Vector3 = _velocidad_de(n)
	if n.get("dir2") == null:
		# Peatón en su acera: la dirección es hacia donde mira.
		var ve = n.get("vel")
		if ve is float and n.get("es_coche") == false:
			var b: Vector3 = -(n as Node3D).global_basis.z
			return Vector2(b.x, b.z).normalized() * float(ve)
	return Vector2(v3.x, v3.z)


func _bigotes(dir: Vector2) -> Vector2:
	if dir.length() < 0.1:
		return Vector2.ZERO
	var d: Vector2 = dir.normalized()
	var mundo: World3D = cuerpo.get_world_3d()
	if mundo == null:
		return Vector2.ZERO
	var origen: Vector3 = cuerpo.global_position + Vector3(0, 0.9, 0)
	var excluir: Array = []
	if cuerpo is CollisionObject3D:
		excluir.append((cuerpo as CollisionObject3D).get_rid())
	var largo: float = clampf(vel.length() * 0.6, 1.1, 2.6)
	var res: Vector2 = Vector2.ZERO
	var angs: Array = [0.0, 0.6, -0.6]
	var libres: Array = [1.0, 1.0, 1.0]
	for i in 3:
		var dd: Vector2 = d.rotated(angs[i])
		var l: float = largo * (1.0 if i == 0 else 0.75)
		var choque: Dictionary = Combate.rayo(mundo, origen, Vector3(dd.x, 0.0, dd.y), l, excluir)
		if not choque.is_empty():
			var col = choque["collider"]
			if col is Node and ((col as Node).is_in_group("oyentes_ia") or (col as Node).is_in_group("jugador")):
				continue   # A las personas ya las esquiva el otro sistema.
			var f: float = (choque["position"] as Vector3).distance_to(origen) / l
			libres[i] = f
			var n3: Vector3 = choque["normal"]
			var n2: Vector2 = Vector2(n3.x, n3.z)
			res += n2.normalized() * (1.0 - f) * (1.4 if i == 0 else 0.8) if n2.length() > 0.01 else Vector2.ZERO
	# De frente contra una pared: gira hacia el lado más libre.
	if float(libres[0]) < 0.6:
		var lado: float = 1.0 if float(libres[1]) >= float(libres[2]) else -1.0
		res += d.rotated(lado * PI / 2.0) * (1.0 - float(libres[0]))
	return res


# Para cuando el dueño mueve al personaje (p. ej. cruzando un paso de cebra) pero quiere que
# esquive a los demás: devuelve la velocidad corregida.
func esquivar_paso(deseo: Vector2, delta: float) -> Vector2:
	vel = deseo
	var r: Vector2 = _dirigir(deseo, delta)
	vel = Vector2.ZERO
	return r


# --- Utilidades de movimiento para las acciones ---

# Pide ir hacia un punto (llegada suave). Devuelve la distancia que falta.
func ir_a(destino: Vector3, rapidez: float) -> float:
	var al: Vector2 = Vector2(destino.x, destino.z) - pos2()
	var d: float = al.length()
	if d < 0.15:
		_deseo = Vector2.ZERO
		return d
	var v: float = rapidez * clampf(d / 1.2, 0.25, 1.0)
	_deseo = al / d * v
	mirar = Vector2.ZERO
	return d


# Igual que ir_a pero siguiendo la ruta del cuerpo (habitaciones y puertas), si la tiene.
func ir_por_ruta(destino: Vector3, rapidez: float) -> float:
	if not cuerpo.has_method("ia_ruta"):
		return ir_a(destino, rapidez)
	if _ruta_destino.distance_to(destino) > 0.8 or (_ruta.is_empty() and pos3_dist(destino) > 0.5):
		_ruta = cuerpo.ia_ruta(destino)
		_ruta_destino = destino
	while not _ruta.is_empty() and pos3_dist(_ruta[0]) < 0.45:
		_ruta.pop_front()
	if _ruta.is_empty():
		return ir_a(destino, rapidez)
	ir_a(_ruta[0], rapidez)
	if _ruta.size() > 1:
		_deseo = _deseo.normalized() * rapidez   # Sin frenar en los puntos de paso.
	return pos3_dist(destino)


func pos3_dist(p: Vector3) -> float:
	return Vector2(p.x, p.z).distance_to(pos2())


func huir_de(p: Vector3, rapidez: float) -> void:
	var al: Vector2 = pos2() - Vector2(p.x, p.z)
	if al.length() < 0.01:
		al = Vector2.RIGHT.rotated(rng.randf() * TAU)
	# Un poco de zigzag y de "elegir calle": el ángulo se tuerce poco a poco.
	var giro: float = float(bb.get("huir_giro", rng.randf_range(-0.5, 0.5)))
	giro += rng.randf_range(-0.08, 0.08)
	giro = clampf(giro, -0.8, 0.8)
	bb["huir_giro"] = giro
	_deseo = al.normalized().rotated(giro) * rapidez
	mirar = Vector2.ZERO


func parar() -> void:
	_deseo = Vector2.ZERO


func mirar_a(p: Vector3) -> void:
	var al: Vector2 = Vector2(p.x, p.z) - pos2()
	if al.length() > 0.05:
		mirar = al.normalized()


func dist_amenaza() -> float:
	if amenaza == null or not is_instance_valid(amenaza):
		return 999.0
	return cuerpo.global_position.distance_to(amenaza.global_position)


func ve_a(n: Node3D) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	var ojos: Vector3 = cuerpo.global_position + Vector3(0, 1.5, 0)
	var obj: Vector3 = n.global_position + Vector3(0, 1.1, 0)
	var d: float = ojos.distance_to(obj)
	if d > VISTA:
		return false
	var excluir: Array = []
	if cuerpo is CollisionObject3D:
		excluir.append((cuerpo as CollisionObject3D).get_rid())
	var choque: Dictionary = Combate.rayo(cuerpo.get_world_3d(), ojos, obj - ojos, d + 0.3, excluir)
	if choque.is_empty():
		return true
	var c = choque["collider"]
	return c == n or (c is Node and (n as Node).is_ancestor_of(c as Node))


# ================================ Armas a mano =================================

func sacar_arma() -> void:
	if arma_fuera:
		return
	arma_fuera = true
	_mostrar_arma(arma_modelo)
	EstimulosIA.emitir(cuerpo.get_tree(), "arma_vista", cuerpo.global_position, 14.0, cuerpo)


func guardar_arma() -> void:
	if not arma_fuera:
		return
	arma_fuera = false
	anim_fija = ""
	_mostrar_arma(arma_mano)


func _mostrar_arma(nombre: String) -> void:
	var m: Node3D = cuerpo.get("modelo") as Node3D
	if m == null:
		return
	_mostrar_arma_en(m, nombre)


static func _mostrar_arma_en(nodo: Node, nombre: String) -> void:
	for h in nodo.get_children():
		var n: String = String(h.name)
		var base: String = n.rsplit("_", true, 1)[0] if n.get_slice_count("_") > 1 and n.rsplit("_", true, 1)[1].is_valid_int() else n
		if h is Node3D and (Assets.ARMAS_PERSONAJE.has(n) or Assets.ARMAS_PERSONAJE.has(base)):
			(h as Node3D).visible = nombre != "" and (n == nombre or (base == nombre and n.ends_with("_1")))
		_mostrar_arma_en(h, nombre)


# Puñetazo (o golpe con objeto) al objetivo si sigue a mano. Daño al jugador o a otra persona.
func golpear(objetivo: Node3D) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		return
	var al: Vector3 = objetivo.global_position - cuerpo.global_position
	if al.length() > 1.9 or absf(al.y) > 1.6:
		Sonido.tocar(cuerpo, "golpe", -16.0)
		return   # Ha fallado (te has apartado).
	var dano: float = dano_mano if arma_mano != "" else dano_puno
	Sonido.tocar(cuerpo, "golpe", -6.0)
	if objetivo.is_in_group("jugador"):
		if objetivo.get("vehiculo") != null:
			return
		Juego.cambiar_vida(-dano)
		if Juego.invulnerable <= 0.0:
			var emp: Vector3 = al.normalized() * 2.5
			emp.y = 0.0
			objetivo.set("velocity", (objetivo.get("velocity") as Vector3) + emp + Vector3.UP * 1.0)
	elif objetivo.has_method("recibir_dano"):
		objetivo.recibir_dano(dano)
	EstimulosIA.emitir(cuerpo.get_tree(), "violencia", cuerpo.global_position, 14.0, cuerpo)


# Disparo al objetivo: rayo con fallo según distancia, movimiento y si va agachado.
func disparar(objetivo: Node3D) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		return
	Sonido.tocar(cuerpo, "disparo", -3.0)
	var boca: Vector3 = cuerpo.global_position + Vector3(0, 1.35, 0) + Vector3(frente().x, 0, frente().y) * 0.5
	var destello: OmniLight3D = OmniLight3D.new()
	destello.light_color = Color(1.0, 0.8, 0.4)
	destello.light_energy = 4.0
	destello.omni_range = 5.0
	var escena: Node = cuerpo.get_tree().current_scene if cuerpo.get_tree().current_scene != null else cuerpo
	escena.add_child(destello)
	destello.global_position = boca
	cuerpo.get_tree().create_timer(0.07).timeout.connect(destello.queue_free)
	var blanco: Vector3 = objetivo.global_position + Vector3(0, 1.1, 0)
	var d: float = boca.distance_to(blanco)
	var p: float = clampf(punteria - d * 0.022, 0.1, 0.85)
	var vj = objetivo.get("velocity")
	if vj is Vector3 and Vector2((vj as Vector3).x, (vj as Vector3).z).length() > 3.0:
		p *= 0.65
	if objetivo.get("agachado") == true:
		p *= 0.75
	if objetivo.get("vehiculo") != null:
		p *= 0.6
	var acierta: bool = rng.randf() < p
	var desv: Vector3 = Vector3.ZERO if acierta else Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.8), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.6, 1.6)
	var dir: Vector3 = (blanco + desv - boca).normalized()
	var excluir: Array = []
	if cuerpo is CollisionObject3D:
		excluir.append((cuerpo as CollisionObject3D).get_rid())
	var choque: Dictionary = Combate.rayo(cuerpo.get_world_3d(), boca, dir, 80.0, excluir)
	var fin: Vector3 = boca + dir * 60.0
	if not choque.is_empty():
		fin = choque["position"]
		var col = choque["collider"]
		if acierta and col is Node and ((col as Node).is_in_group("jugador") or col == objetivo):
			if objetivo.is_in_group("jugador"):
				Juego.cambiar_vida(-dano_bala)
				if Juego.invulnerable <= 0.0:
					Juego.avisar("¡Te han disparado!")
			elif objetivo.has_method("recibir_dano"):
				objetivo.recibir_dano(dano_bala)
		elif col != null and col.has_method("recibir_dano") and col != objetivo and not ((col as Node).is_in_group("jugador")):
			col.recibir_dano(dano_bala * 0.8)   # Bala perdida: le da a otro.
		else:
			Combate.marca_bala(cuerpo.get_tree().current_scene if cuerpo.get_tree().current_scene != null else cuerpo, fin, choque["normal"])
	_trazadora(boca, fin)


func _trazadora(a: Vector3, b: Vector3) -> void:
	var largo: float = a.distance_to(b)
	if largo < 0.5:
		return
	var raya: MeshInstance3D = MeshInstance3D.new()
	var malla: BoxMesh = BoxMesh.new()
	malla.size = Vector3(0.025, 0.025, largo)
	raya.mesh = malla
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.5)
	raya.material_override = mat
	raya.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var padre: Node = cuerpo.get_tree().current_scene if cuerpo.get_tree().current_scene != null else cuerpo
	padre.add_child(raya)
	raya.look_at_from_position((a + b) * 0.5, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	cuerpo.get_tree().create_timer(0.05).timeout.connect(raya.queue_free)


# ================================ Condiciones ==================================

func hay_coche_encima() -> bool:
	return coche_peligro != null and is_instance_valid(coche_peligro)


func hay_amenaza() -> bool:
	if amenaza == null or not is_instance_valid(amenaza) or amenaza.has_meta("muerto"):
		return false
	if bool(amenaza.get("_muerto")):
		return false
	var reciente: bool = reloj - t_amenaza < 25.0
	return (miedo > 0.22 or ira > 0.3) and (reciente or dist_amenaza() < 12.0)


func hay_incidente() -> bool:
	return reloj - t_incidente < 20.0 and incidente_pos.distance_to(cuerpo.global_position) < 30.0


func calmado() -> bool:
	return miedo < 0.2 and ira < 0.25


# --- Puntuaciones de la reacción ante una amenaza (Utilidad) ---

func p_huir() -> float:
	var v: float = miedo * (1.35 - valentia)
	if amenaza_dispara or jugador_armado == 2:
		v += 0.35 * (1.0 - valentia)
	if vida() < 0.4:
		v += 0.4
	if dist_amenaza() > 35.0:
		v *= 0.3
	return v


func p_pelear() -> float:
	if vida() < 0.3:
		return 0.0
	var v: float = ira * (0.35 + agresividad) * (0.3 + valentia) * 1.4
	var d: float = dist_amenaza()
	if d > 18.0:
		v *= 0.3
	# Ir a puñetazos contra alguien con pistola es de muy valientes (o muy tontos).
	if (jugador_armado == 2 or amenaza_dispara) and not armado:
		v *= 0.25 if valentia < 0.85 else 0.6
	return v


func p_disparar() -> float:
	if not armado or vida() < 0.15:
		return 0.0
	var v: float = ira * 0.9 + valentia * 0.45 + (0.4 if amenaza_dispara or jugador_armado == 2 else 0.0)
	return v * (1.0 if dist_amenaza() < 35.0 else 0.2)


func p_cubrirse() -> float:
	if reloj - t_disparo > 3.0 and not apuntado:
		return 0.0
	return miedo * (1.0 - agilidad) * 1.1 * (1.0 if not armado else 0.3)


func p_suplicar() -> float:
	if not apuntado or armado or dist_amenaza() > 9.0:
		return 0.0
	return 0.75 + (1.0 - valentia) * 0.6


func p_llamar() -> float:
	if llamo_policia or not EstimulosIA.es_jugador(amenaza) or not Juego.policia_activa:
		return 0.0
	var d: float = dist_amenaza()
	return civismo * 0.85 * (1.0 if d > 16.0 else 0.15) * (1.0 - miedo * 0.4)


func p_esconderse() -> float:
	if llamo_policia or not cuerpo.has_method("ia_escondite"):
		return 0.0
	return civismo * 0.6 + miedo * (1.0 - valentia) * 0.7


# --- Puntuaciones ante un incidente (alguien herido, pelea a lo lejos) ---

func p_mirar() -> float:
	return curiosidad * (1.0 - miedo) * 0.9


func p_socorrer() -> float:
	if herido == null or not is_instance_valid(herido):
		return 0.0
	return civismo * (1.0 - miedo * 1.5) * 1.1


func p_alejarse() -> float:
	return (1.0 - curiosidad) * 0.5 + miedo * 0.5


# ================================== Acciones ===================================
# Cada acción devuelve R (hecho), F (no se puede) o C (sigo en ello).

func a_saltar_aparte(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "esquivar_coche"
	var t: float = float(bb.get("t_esquivar_coche", 0.0))
	if t < PERIODO_PENSAR * 1.5:
		# Al principio: ¿le da tiempo? (los torpes a veces se quedan clavados)
		if rng.randf() > 0.35 + agilidad * 0.6:
			bb["clavado"] = true
			anim_fija = ""
			una_vez("Duck")
		else:
			bb["clavado"] = false
			var v2: Vector2 = Vector2(coche_vel.x, coche_vel.z).normalized()
			var lateral: Vector2 = Vector2(-v2.y, v2.x)
			var rel: Vector3 = cuerpo.global_position - (coche_peligro.global_position if is_instance_valid(coche_peligro) else cuerpo.global_position)
			if lateral.dot(Vector2(rel.x, rel.z)) < 0.0:
				lateral = -lateral
			bb["salto_dir"] = lateral
			una_vez("Jump")
			decir("coche", 0.6)
			miedo = minf(1.0, miedo + 0.3)
	if bool(bb.get("clavado", false)):
		parar()
	else:
		var dir: Vector2 = bb.get("salto_dir", Vector2.RIGHT)
		_deseo = dir * (6.0 + agilidad * 2.0)
		vel = _deseo   # Salto: sin aceleración progresiva.
	if t > 0.55:
		ira = minf(1.0, ira + 0.15 * agresividad)
		return R
	return C


func a_aturdido(_bb: Dictionary, _d: float) -> int:
	libre = true
	parar()
	return C


func a_huir(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "huir"
	guardar_arma()
	anim_fija = ""
	var t: float = float(bb.get("t_huir", 0.0))
	if t < PERIODO_PENSAR * 1.5:
		decir("huir", 0.7)
		EstimulosIA.emitir(cuerpo.get_tree(), "grito", cuerpo.global_position, 16.0, cuerpo)
	var desde: Vector3 = amenaza.global_position if amenaza != null and is_instance_valid(amenaza) else amenaza_pos
	if cuerpo.has_method("ia_salida") and cuerpo.has_method("ia_dentro") and bool(cuerpo.ia_dentro()):
		ir_por_ruta(cuerpo.ia_salida(), vel_correr)   # Dentro de casa: hacia la puerta.
	else:
		huir_de(desde, vel_correr * (0.85 if vida() < 0.4 else 1.0))
		# A veces mira atrás un momento (frena y se gira).
		if fmod(t, 3.0) > 2.6 and dist_amenaza() > 10.0:
			_deseo *= 0.35
			mirar_a(desde)
	if dist_amenaza() > 45.0 and miedo < 0.35:
		return R
	return C


func a_pelear(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "pelear"
	if arma_mano == "":
		guardar_arma()
	else:
		_mostrar_arma(arma_mano)
	anim_fija = ""
	if amenaza == null or not is_instance_valid(amenaza):
		return F
	var t: float = float(bb.get("t_pelear", 0.0))
	if t < PERIODO_PENSAR * 1.5:
		decir("pelear" if tipo == "peaton" else "intruso", 0.8)
	var objetivo: Vector3 = amenaza.global_position
	var al: Vector3 = objetivo - cuerpo.global_position
	var d: float = Vector2(al.x, al.z).length()
	mirar_a(objetivo)
	if amenaza.get("vehiculo") != null:
		# Va en coche: no puede pegarle. Le insulta de cerca o se aparta.
		if d < 4.0:
			huir_de(objetivo, vel_andar)
		else:
			parar()
		return C
	# Esquivar un golpe del jugador (los ágiles se apartan a un lado).
	if reloj - float(bb.get("golpe_jugador", -9.0)) < 0.25 and d < 2.6 and not bb.has("esquivo") and rng.randf() < agilidad * 0.7:
		bb["esquivo"] = reloj
		var lado: Vector2 = Vector2(-al.z, al.x).normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
		vel = lado * 4.5 - Vector2(al.x, al.z).normalized() * 1.5
		una_vez("Duck")
	if bb.has("esquivo") and reloj - float(bb["esquivo"]) > 1.0:
		bb.erase("esquivo")
	var listo: bool = reloj >= float(bb.get("t_golpe", 0.0))
	var alcance: float = 1.45 if arma_mano == "" else 1.75
	if d > alcance + 0.2:
		# Acercarse rodeando un poco (no en línea recta perfecta).
		var hacia: Vector2 = Vector2(al.x, al.z).normalized()
		var lado2: float = float(bb.get("rodeo", 1.0 if rng.randf() < 0.5 else -1.0))
		bb["rodeo"] = lado2
		var v: float = vel_correr * 0.85 if d > 5.0 else vel_andar * 1.4
		_deseo = (hacia + Vector2(-hacia.y, hacia.x) * lado2 * clampf((d - 2.0) * 0.15, 0.0, 0.4)).normalized() * v
		mirar = hacia
	elif not listo:
		# Guardia: se mueve en círculo y amaga, sin quedarse quieto.
		var hacia2: Vector2 = Vector2(al.x, al.z).normalized()
		var lado3: float = 1.0 if fmod(reloj * (0.6 + agilidad), 2.0) < 1.0 else -1.0
		_deseo = Vector2(-hacia2.y, hacia2.x) * lado3 * 1.2 + hacia2 * (d - 1.2) * 1.5
		mirar = hacia2
	else:
		parar()
		var dur: float = una_vez("Punch")
		bb["t_golpe"] = reloj + maxf(dur, 0.5) + rng.randf_range(0.35, 1.1) * (1.4 - agresividad)
		var quien: Node3D = amenaza
		cuerpo.get_tree().create_timer(maxf(dur * 0.4, 0.2)).timeout.connect(func() -> void:
			if is_instance_valid(cuerpo) and not cuerpo.has_meta("muerto") and vida() > 0.0:
				golpear(quien))
	# Si se lleva una buena paliza, se lo piensa.
	if vida() < 0.3 and valentia < 0.8:
		miedo = minf(1.0, miedo + 0.4)
		ira *= 0.5
		return F
	if d > 30.0:
		return R
	return C


func a_disparar(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "disparar"
	if amenaza == null or not is_instance_valid(amenaza):
		return F
	var objetivo: Vector3 = amenaza.global_position
	var al: Vector3 = objetivo - cuerpo.global_position
	var d: float = Vector2(al.x, al.z).length()
	var t: float = float(bb.get("t_disparar", 0.0))
	mirar_a(objetivo)
	if not arma_fuera:
		sacar_arma()
		anim_fija = "Idle_Shoot"
		decir("arma", 0.9)
		bb["t_tiro"] = reloj + rng.randf_range(0.6, 1.0)   # Tarda un poco en sacarla y apuntar.
	anim_fija = "Idle_Shoot"
	# Distancia ideal 6-14 m: se aparta si estás encima, se acerca si estás lejos, y se mueve de lado.
	var hacia: Vector2 = Vector2(al.x, al.z).normalized()
	var lado: float = 1.0 if fmod(t + float(get_instance_id() % 7), 5.0) < 2.5 else -1.0
	if d < 5.0:
		_deseo = -hacia * vel_andar * 1.6 + Vector2(-hacia.y, hacia.x) * lado
	elif d > 16.0:
		_deseo = hacia * vel_correr * 0.7
	else:
		_deseo = Vector2(-hacia.y, hacia.x) * lado * vel_andar * 0.8
	mirar = hacia
	if reloj >= float(bb.get("t_tiro", 0.0)) and d < 40.0:
		bb["t_tiro"] = reloj + rng.randf_range(0.55, 1.3)
		if ve_a(amenaza):
			disparar(amenaza)
	if vida() < 0.2 and valentia < 0.9:
		miedo = 1.0
		return F
	if d > 45.0:
		guardar_arma()
		return R
	return C


func a_cubrirse(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "cubrirse"
	guardar_arma()
	parar()
	anim_fija = "Duck"
	if amenaza != null and is_instance_valid(amenaza):
		mirar_a(amenaza.global_position)
	if float(bb.get("t_cubrirse", 0.0)) < PERIODO_PENSAR * 1.5:
		decir("disparo", 0.5)
	# Si se le acerca mucho, sale corriendo.
	if dist_amenaza() < 2.5 and rng.randf() < 0.1:
		anim_fija = ""
		return F
	return C


func cortar_anim(_bb: Dictionary) -> void:
	anim_fija = ""


func a_suplicar(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "suplicar"
	parar()
	anim_fija = "Duck"
	var t: float = float(bb.get("t_suplicar", 0.0))
	if amenaza != null and is_instance_valid(amenaza):
		mirar_a(amenaza.global_position)
	if t < PERIODO_PENSAR * 1.5:
		decir("suplicar", 0.9)
	# Si le sigues apuntando de cerca, te da lo que lleva encima (atraco).
	if t > 3.0 and not robado and apuntado and dist_amenaza() < 6.0 and EstimulosIA.es_jugador(amenaza):
		robado = true
		var botin: int = rng.randi_range(5, 45)
		Juego.dinero += botin
		Juego.cambio.emit()
		Juego.avisar("Te da %d monedas temblando." % botin)
		decir("robo", 1.0)
		una_vez("No", "Duck")
		if Juego.policia_activa:
			Juego.exigir_estrellas(1, "Atraco a un ciudadano")
	if not apuntado and t > 1.5:
		anim_fija = ""
		return R   # Deja de apuntarle: ahora huirá o llamará.
	return C


func a_llamar(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "llamar"
	guardar_arma()
	var t: float = float(bb.get("t_llamar", 0.0))
	var d: float = dist_amenaza()
	if d < 14.0:
		# Primero se aleja un poco.
		if amenaza != null and is_instance_valid(amenaza):
			huir_de(amenaza.global_position, vel_correr * 0.8)
		bb["t_llamar"] = 0.0
		return C
	parar()
	anim_fija = "Idle"
	if amenaza != null and is_instance_valid(amenaza):
		mirar_a(amenaza.global_position)
	if t > 0.3 and t < 0.3 + PERIODO_PENSAR * 1.5:
		decir("llamar", 0.9)
	if t > 5.0:
		llamo_policia = true
		anim_fija = ""
		if cuerpo.has_method("ia_denunciar"):
			cuerpo.ia_denunciar()
		else:
			var raiz: Node = cuerpo.get_tree().root
			var ahora: int = Time.get_ticks_msec()
			if ahora - int(raiz.get_meta("llamada_ms", -100000)) > 20000:
				raiz.set_meta("llamada_ms", ahora)
				Juego.exigir_estrellas(1, "Un testigo ha llamado a la policía")
		return R
	return C


func a_mirar(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "mirar"
	var t: float = float(bb.get("t_mirar", 0.0))
	var dist_ok: float = float(bb.get("mirar_dist", rng.randf_range(5.5, 9.0)))
	bb["mirar_dist"] = dist_ok
	var d: float = pos3_dist(incidente_pos)
	if d > dist_ok + 0.5:
		ir_a(incidente_pos, vel_andar * 1.1)
		mirar = Vector2.ZERO
	elif d < dist_ok - 1.5:
		huir_de(incidente_pos, vel_andar * 0.7)
		mirar_a(incidente_pos)
	else:
		parar()
		mirar_a(incidente_pos)
		if fmod(t, 4.0) < PERIODO_PENSAR * 1.5 and t > 1.0:
			if rng.randf() < 0.5:
				una_vez("No")
			decir("mirar", 0.4)
	if t > float(bb.get("mirar_max", rng.randf_range(7.0, 16.0))):
		bb.erase("mirar_dist")
		t_incidente = -99.0
		return R
	bb["mirar_max"] = float(bb.get("mirar_max", rng.randf_range(7.0, 16.0)))
	return C


func a_socorrer(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "socorrer"
	if herido == null or not is_instance_valid(herido):
		anim_fija = ""
		return F
	var t: float = float(bb.get("t_socorrer", 0.0))
	var d: float = ir_a(herido.global_position, vel_correr * 0.7)
	if d < 1.1:
		parar()
		mirar_a(herido.global_position)
		anim_fija = "Duck"   # De rodillas a su lado.
		if not bb.has("socorro_desde"):
			bb["socorro_desde"] = reloj
			decir("socorrer", 0.9)
		if reloj - float(bb["socorro_desde"]) > 9.0:
			anim_fija = ""
			bb.erase("socorro_desde")
			herido = null
			t_incidente = -99.0
			return R
	if t > 30.0:
		anim_fija = ""
		herido = null
		return R
	return C


func cortar_socorro(_bb: Dictionary) -> void:
	anim_fija = ""
	bb.erase("socorro_desde")


func a_alejarse(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "alejarse"
	huir_de(incidente_pos, vel_andar * 1.5)
	if pos3_dist(incidente_pos) > 22.0:
		t_incidente = -99.0
		return R
	return C


func a_quejarse(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "quejarse"
	var j: Node3D = jugador()
	var t: float = float(bb.get("t_quejarse", 0.0))
	if t < PERIODO_PENSAR * 1.5:
		una_vez("No")
		decir("quejarse", 1.0)
		ira = minf(1.0, ira + 0.2 + agresividad * 0.25)
		# Un empujón de vuelta si es de los agresivos.
		if j != null and agresividad > 0.6:
			var emp: Vector3 = (j.global_position - cuerpo.global_position).normalized() * 3.0
			emp.y = 0.0
			j.set("velocity", (j.get("velocity") as Vector3) + emp)
		# Los muy agresivos se encaran contigo.
		if ira > 0.55 and agresividad > 0.65 and j != null:
			_poner_amenaza(j)
	parar()
	if j != null:
		mirar_a(j.global_position)
	empujado = false
	return R if t > 1.2 else C


func a_nervioso(_bb: Dictionary, _d: float) -> int:
	# El jugador lleva un arma a la vista cerca: se aparta mirándole.
	libre = true
	accion = "nervioso"
	var j: Node3D = jugador()
	if j == null:
		return F
	var t: float = float(bb.get("t_nervioso", 0.0))
	if t < PERIODO_PENSAR * 1.5:
		decir("nervioso", 0.5)
	huir_de(j.global_position, vel_andar * 1.3)
	if t > 0.6:
		mirar = Vector2.ZERO
	if j.global_position.distance_to(cuerpo.global_position) > 9.0 or jugador_armado == 0:
		return R
	return C


func a_saludar(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "saludar"
	var j: Node3D = jugador()
	if j == null:
		return F
	var t: float = float(bb.get("t_saludar", 0.0))
	parar()
	mirar_a(j.global_position)
	if t < PERIODO_PENSAR * 1.5:
		una_vez("Wave")
		decir("saludo", 0.8)
	return R if t > 1.6 else C


func quiere_saludar() -> bool:
	var j: Node3D = jugador()
	if j == null or jugador_armado > 0 or Juego.estrellas > 0 or j.get("vehiculo") != null:
		return false
	var d: float = j.global_position.distance_to(cuerpo.global_position)
	if d > 4.5 or d < 1.2 or sociabilidad < 0.55:
		return false
	var cam: Camera3D = cuerpo.get_viewport().get_camera_3d()
	if cam == null:
		return false
	var hacia: Vector3 = (cuerpo.global_position + Vector3(0, 1.2, 0) - cam.global_position).normalized()
	return (-cam.global_basis.z).dot(hacia) > 0.93


func quiere_nervioso() -> bool:
	if jugador_armado == 0:
		return false
	var j: Node3D = jugador()
	return j != null and j.global_position.distance_to(cuerpo.global_position) < 6.0 and valentia < 0.75


# --- Charlar con otro peatón que pasa ---

func busca_charla() -> bool:
	if sociabilidad < 0.45 or not calmado():
		return false
	if bb.has("pareja") and is_instance_valid(bb["pareja"]):
		return true
	for n in _personas_cerca():
		if n == cuerpo or not is_instance_valid(n) or n.has_meta("muerto"):
			continue
		var cer = n.get("cerebro")
		if cer == null or not (cer is PersonaIA):
			continue
		var otro: PersonaIA = cer
		if otro.tipo != tipo or otro.bb.has("pareja") or otro.sociabilidad < 0.4 or not otro.calmado() or otro.libre:
			continue
		if (n as Node3D).global_position.distance_to(cuerpo.global_position) > 2.4:
			continue
		if rng.randf() > 0.25:
			return false
		bb["pareja"] = n
		otro.bb["pareja"] = cuerpo
		var dur: float = rng.randf_range(5.0, 13.0)
		bb["charla_fin"] = reloj + dur
		otro.bb["charla_fin"] = otro.reloj + dur
		return true
	return false


func a_charlar(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "charlar"
	var otro = bb.get("pareja")
	if otro == null or not is_instance_valid(otro) or (otro as Node).has_meta("muerto"):
		bb.erase("pareja")
		return F
	var p: Vector3 = (otro as Node3D).global_position
	var d: float = pos3_dist(p)
	if d > 1.5:
		ir_a(p, vel_andar * 0.8)
	elif d < 1.0:
		huir_de(p, 0.5)
	else:
		parar()
	mirar_a(p)
	if fmod(reloj + float(get_instance_id() % 5), 3.2) < PERIODO_PENSAR * 1.2:
		var gesto: String = ["Yes", "No", "Wave", "Idle"][rng.randi() % 4]
		if gesto != "Idle":
			una_vez(gesto)
		decir("charla", 0.25)
	if reloj > float(bb.get("charla_fin", 0.0)) or not calmado():
		bb.erase("pareja")
		var cer = (otro as Node).get("cerebro")
		if cer != null and cer is PersonaIA:
			(cer as PersonaIA).bb.erase("pareja")
		bb["charla_enfr"] = reloj + 40.0
		return R
	return C


func cortar_charla(_bb: Dictionary) -> void:
	var otro = bb.get("pareja")
	bb.erase("pareja")
	if otro != null and is_instance_valid(otro):
		var cer = (otro as Node).get("cerebro")
		if cer != null and cer is PersonaIA:
			(cer as PersonaIA).bb.erase("pareja")


# --- Acompañar (parejas y grupos que pasean juntos) ---

func acompana() -> bool:
	if lider == null:
		return false
	if not is_instance_valid(lider) or lider.has_meta("muerto"):
		lider = null
		return false
	return true


func a_acompanar(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "acompanar"
	var lp: Vector3 = lider.global_position
	var lv: Vector2 = _vel_de_persona(lider)
	var dirl: Vector2 = lv.normalized() if lv.length() > 0.2 else Vector2(-lider.global_basis.z.x, -lider.global_basis.z.z).normalized()
	# A su derecha y un pelín por detrás.
	var sitio: Vector2 = Vector2(lp.x, lp.z) + Vector2(-dirl.y, dirl.x) * 0.8 - dirl * 0.25
	var al: Vector2 = sitio - pos2()
	var d: float = al.length()
	if d > 0.25:
		_deseo = lv + al.normalized() * clampf(d * 1.8, 0.0, 2.5)
	else:
		_deseo = lv
	mirar = dirl if lv.length() < 0.2 else Vector2.ZERO
	if lv.length() < 0.2 and d < 0.6:
		mirar = (Vector2(lp.x, lp.z) - pos2()).normalized()   # Si para, se miran (charlan).
	return C


# --- Rutina ---

func fuera_de_rutina() -> bool:
	return libre


func a_volver(_bb: Dictionary, _d: float) -> int:
	accion = "volver"
	anim_fija = ""
	guardar_arma()
	if not cuerpo.has_method("ia_punto_acera"):
		libre = false
		return R
	var p = cuerpo.ia_punto_acera()
	if p == null:
		libre = false
		return R
	var punto: Vector2 = p
	var d: float = ir_a(Vector3(punto.x, cuerpo.global_position.y, punto.y), vel_andar * (1.0 + miedo))
	if d < 0.35 or float(bb.get("t_volver", 0.0)) > 25.0:
		libre = false
		if cuerpo.has_method("ia_reenganchar"):
			cuerpo.ia_reenganchar()
		return R
	return C


func a_pasear(_bb: Dictionary, _d: float) -> int:
	accion = "pasear"
	libre = false
	anim_fija = ""
	return C


# --- Rutina dentro de casa (vecinos despiertos): ir de una habitación a otra y quedarse un rato ---

func a_rutina_casa(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "rutina_casa"
	anim_fija = ""
	if not cuerpo.has_method("ia_punto_rutina"):
		parar()
		return C
	if not bb.has("rutina_destino"):
		bb["rutina_destino"] = cuerpo.ia_punto_rutina()
		bb["rutina_pausa"] = rng.randf_range(3.0, 10.0)
	var dest: Vector3 = bb["rutina_destino"]
	var d: float = ir_por_ruta(dest, vel_andar * 0.8)
	if d < 0.5:
		parar()
		bb["rutina_pausa"] = float(bb["rutina_pausa"]) - _d
		if float(bb["rutina_pausa"]) <= 0.0:
			bb.erase("rutina_destino")
	elif float(bb.get("t_rutina_casa", 0.0)) > 40.0:
		bb.erase("rutina_destino")
		bb["t_rutina_casa"] = 0.0
	return C


# Escondite (los que llaman a la policía desde casa): habitación lejos del intruso.
func a_esconderse(_bb: Dictionary, _d: float) -> int:
	libre = true
	accion = "esconderse"
	guardar_arma()
	if not bb.has("escondite"):
		bb["escondite"] = cuerpo.ia_escondite() if cuerpo.has_method("ia_escondite") else cuerpo.global_position
	var dest: Vector3 = bb["escondite"]
	var d: float = ir_por_ruta(dest, vel_correr * 0.8)
	if d < 0.6:
		parar()
		anim_fija = "Duck"
		var t0: float = float(bb.get("escondido_desde", reloj))
		bb["escondido_desde"] = t0
		if reloj - t0 > 1.0 and reloj - t0 < 1.0 + PERIODO_PENSAR * 1.5:
			decir("llamar", 0.9)
		if reloj - t0 > 6.0 and not llamo_policia:
			llamo_policia = true
			if cuerpo.has_method("ia_denunciar"):
				cuerpo.ia_denunciar()
	# Si el intruso le encuentra (muy cerca), reacciona otra vez.
	if dist_amenaza() < 2.2:
		bb.erase("escondite")
		bb.erase("escondido_desde")
		anim_fija = ""
		miedo = 1.0
		return F
	return C


func cortar_escondite(_bb: Dictionary) -> void:
	anim_fija = ""
	bb.erase("escondite")
	bb.erase("escondido_desde")


# ============================ Peatón: esquivar en la acera =====================
# En la rutina el peatón sigue la línea de su acera. Para que no se atraviesen, se aparta a un
# lado (carril) y ajusta el paso según quién venga. lat = desplazamiento lateral actual (+ = a su
# derecha), dir = hacia dónde anda. Devuelve [nuevo_lat, factor_velocidad].
func esquiva_acera(lat: float, dir: Vector2, mi_vel: float, lat_min: float, lat_max: float, delta: float) -> Array:
	var yo: Vector2 = pos2()
	var derecha: Vector2 = Vector2(-dir.y, dir.x)
	var objetivo_lat: float = _lat_pref
	var factor: float = 1.0
	var otros: Array = _personas_cerca()
	var j: Node3D = jugador()
	if j != null and j.get("vehiculo") == null:
		otros = otros + [j]
	var mas_cercano: float = 99.0
	for n in otros:
		if n == cuerpo or not is_instance_valid(n) or n.has_meta("muerto"):
			continue
		var p3: Vector3 = (n as Node3D).global_position
		var r: Vector2 = Vector2(p3.x, p3.z) - yo
		var lon: float = r.dot(dir)
		if lon < -0.6 or lon > 6.0:
			continue
		var lat_rel: float = r.dot(derecha)
		if absf(lat_rel) > 2.0:
			continue
		var vo: Vector2 = _vel_de_persona(n)
		var v_lon: float = vo.dot(dir)
		var acerca: float = mi_vel - v_lon   # >0: nos acercamos.
		if lon < 0.4 and absf(lat_rel) < 0.7:
			# Pegado de lado o casi encima: separarse.
			objetivo_lat -= signf(lat_rel if absf(lat_rel) > 0.05 else 1.0) * 0.8
			continue
		if acerca <= 0.05 and lon > 1.5:
			continue
		var t: float = lon / maxf(acerca, 0.3)
		if t > 3.5:
			continue
		# Viene de frente o le alcanzo: me aparto a MI derecha si hay sitio; si no, a la izquierda.
		var hueco_der: float = lat_max - (lat + 0.75)
		var lado: float = 1.0 if (hueco_der > 0.0 or v_lon < -0.3) else -1.0
		if absf(lat_rel) < 0.85:
			objetivo_lat = clampf(lat_rel - lado * 0.9, lat_min, lat_max) if v_lon >= -0.3 else lat + lado * 0.85
		mas_cercano = minf(mas_cercano, lon)
		# Si va en mi carril, despacio, y no puedo adelantar: igualo su paso.
		if absf(lat_rel) < 0.6 and lon < 1.6 and v_lon > -0.2:
			factor = minf(factor, clampf(v_lon / maxf(mi_vel, 0.1), 0.0, 1.0))
	objetivo_lat = clampf(objetivo_lat, lat_min, lat_max)
	var nuevo: float = move_toward(lat, objetivo_lat, delta * 1.1)
	return [nuevo, factor]
