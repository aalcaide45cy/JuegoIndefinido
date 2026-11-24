# fisica_coche.gd
# -----------------------------------------------------------------------------
# Física de verdad para los vehículos de suelo (coches, furgonetas, camiones,
# tractores). Sustituye a la conducción "arcade" de antes (un CharacterBody3D que
# se deslizaba sin peso). Ahora el chasis es un RigidBody3D (Jolt) con:
#
#   - SUSPENSIÓN por rueda: un rayo hacia el suelo, muelle y amortiguador. La
#     carrocería se inclina al frenar, al acelerar y en las curvas, y las ruedas
#     siguen los baches y los bordillos.
#   - NEUMÁTICOS con agarre limitado ("círculo de fricción"): si pides más de lo
#     que da el neumático, patina. Así salen los derrapes, los trompos y el humo.
#   - MOTOR con potencia, caja de cambios automática (marchas y revoluciones para
#     el sonido), tracción delantera, trasera o 4x4 según el vehículo.
#   - FRENOS, freno de mano (Espacio: bloquea las ruedas de atrás y el coche
#     derrapa), barras estabilizadoras y ayuda de estabilidad suave.
#   - GOLPES: cuando choca, emite la señal "golpe" con el punto, la dirección y la
#     fuerza (en m/s de cambio de velocidad). Vehiculo la usa para el daño, las
#     abolladuras, las chispas y el sonido.
#
# Aparcado (sin conductor) lleva el freno de mano puesto. Si nadie lo toca se
# duerme (no gasta). Lejos del jugador se congela, para que no caiga si el suelo
# de ese trozo del mapa todavía no está cargado.
# -----------------------------------------------------------------------------
class_name FisicaCoche
extends RigidBody3D

signal golpe(punto: Vector3, normal: Vector3, fuerza: float, otro: Object)

const G: float = 9.8
const RADIO_CONGELAR: float = 170.0

# masa (kg), traccion ("del", "tras", "4x4"), agarre (coeficiente del neumático),
# marchas, rpm_max (corte), frec (Hz de la suspensión: más alto = más dura),
# recorrido (m de suspensión), cdg (altura del centro de gravedad, m), aero (resistencia del aire)
const PERFILES: Dictionary = {
	"hatchback": {"masa": 1100.0, "traccion": "del", "agarre": 1.15, "marchas": 5, "rpm_max": 7000.0,
			"frec": 1.7, "recorrido": 0.17, "cdg": 0.5, "aero": 0.38},
	"sedan": {"masa": 1400.0, "traccion": "del", "agarre": 1.1, "marchas": 6, "rpm_max": 6300.0,
			"frec": 1.45, "recorrido": 0.19, "cdg": 0.52, "aero": 0.34},
	"taxi": {"masa": 1450.0, "traccion": "del", "agarre": 1.08, "marchas": 5, "rpm_max": 6000.0,
			"frec": 1.4, "recorrido": 0.19, "cdg": 0.54, "aero": 0.36},
	"suv": {"masa": 1950.0, "traccion": "4x4", "agarre": 1.05, "marchas": 6, "rpm_max": 5800.0,
			"frec": 1.3, "recorrido": 0.24, "cdg": 0.72, "aero": 0.45},
	"furgoneta": {"masa": 2200.0, "traccion": "del", "agarre": 1.0, "marchas": 5, "rpm_max": 5200.0,
			"frec": 1.35, "recorrido": 0.21, "cdg": 0.8, "aero": 0.5},
	"camion": {"masa": 7000.0, "traccion": "tras", "agarre": 0.95, "marchas": 8, "rpm_max": 2600.0,
			"frec": 1.15, "recorrido": 0.22, "cdg": 1.15, "aero": 0.9},
	"tractor": {"masa": 3800.0, "traccion": "4x4", "agarre": 1.15, "marchas": 4, "rpm_max": 2400.0,
			"frec": 1.2, "recorrido": 0.2, "cdg": 0.95, "aero": 0.8},
	"excavadora": {"masa": 9000.0, "traccion": "4x4", "agarre": 1.1, "marchas": 3, "rpm_max": 2200.0,
			"frec": 1.0, "recorrido": 0.16, "cdg": 0.7, "aero": 0.9},
	"trailer": {"masa": 8000.0, "traccion": "tras", "agarre": 0.95, "marchas": 10, "rpm_max": 2400.0,
			"frec": 1.15, "recorrido": 0.22, "cdg": 1.2, "aero": 0.9},
	"deportivo": {"masa": 1300.0, "traccion": "tras", "agarre": 1.3, "marchas": 6, "rpm_max": 8200.0,
			"frec": 2.0, "recorrido": 0.14, "cdg": 0.42, "aero": 0.3},
}

# --- Configuración (la pone Vehiculo antes de añadirlo al árbol) ---
var tipo: String = "sedan"
var vmax: float = 40.0
var acel: float = 8.0
var giro_max: float = 0.6         # Ángulo máximo de las ruedas a poca velocidad (rad).
var ruedas: Array = []            # Ver preparar().
var factor_motor: float = 1.0     # Lo baja el daño (motor tocado).
var tiron: float = 0.0            # Desvío de la dirección por daño (-1..1).

# --- Mandos (los pone Vehiculo cada fotograma) ---
var conducido: bool = false
var entrada: float = 0.0          # -1 atrás/freno · +1 acelerar
var direccion: float = 0.0        # -1 derecha · +1 izquierda (como Input.get_axis("derecha", "izquierda"))
var freno_mano: bool = false
var sin_gasolina: bool = false

# --- Estado (para el HUD, el sonido y los efectos) ---
var velocidad: float = 0.0        # m/s hacia delante (negativa = marcha atrás)
var rpm: float = 900.0
var marcha: int = 1               # 0 = marcha atrás
var acelerador: float = 0.0       # 0..1 lo que se pisa de verdad
var frenando: bool = false
var ruedas_en_suelo: int = 0
var deslizamiento: float = 0.0    # El mayor deslizamiento de todas las ruedas (m/s).
var volcado_t: float = 0.0

var _p: Dictionary
var _masa_rueda: float = 300.0
var _k: float = 30000.0
var _c: float = 3000.0
var _recorrido: float = 0.2
var _largo_reposo: float = 0.3
var _potencia: float = 100000.0
var _aero: float = 0.4
var _angulo: float = 0.0
var _cambio_t: float = 0.0
var _t_lejos: float = 0.0
var _v_antes: Vector3 = Vector3.ZERO
var _t_golpe: float = 0.0
var _excluir: Array = []


# Prepara las ruedas. Cada rueda de "datos" es {pivote: Node3D, giro: Node3D, radio: float,
# del: bool}. La posición de reposo se toma del pivote (en coordenadas del chasis).
func preparar(datos: Array, largo: float) -> void:
	_p = PERFILES.get(tipo, PERFILES["sedan"])
	mass = float(_p["masa"])
	_recorrido = float(_p["recorrido"])
	_aero = float(_p["aero"])
	var n: int = maxi(1, datos.size())
	_masa_rueda = mass / float(n)
	var w: float = TAU * float(_p["frec"])
	_k = _masa_rueda * w * w
	_c = 2.0 * 0.42 * sqrt(_k * _masa_rueda)
	var hundido: float = _masa_rueda * G / _k     # Lo que baja el muelle con el peso.
	_largo_reposo = _recorrido + hundido
	var traccion: String = str(_p["traccion"])
	ruedas.clear()
	for r in datos:
		var piv: Node3D = r["pivote"]
		var delantera: bool = bool(r["del"])
		var motriz: bool = traccion == "4x4" or (traccion == "del") == delantera
		ruedas.append({"pivote": piv, "giro": r["giro"], "radio": float(r["radio"]), "del": delantera,
				"motriz": motriz, "reposo": piv.position, "x": _recorrido, "suelo": false,
				"punto": Vector3.ZERO, "normal": Vector3.UP, "carga": 0.0, "w": 0.0, "desliz": 0.0,
				"lado": signf(piv.position.x), "pinchada": 0.0, "pinchar": false})
	# Potencia: buena aceleración abajo y la velocidad punta justo en vmax.
	_potencia = mass * acel * vmax * 0.36
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	# Centro de gravedad entre los ejes (si no, un vehículo con las ruedas descentradas, como la
	# excavadora, carga un eje el doble y cabecea).
	var z_medio: float = 0.0
	for r in ruedas:
		z_medio += (r["reposo"] as Vector3).z / float(ruedas.size())
	center_of_mass = Vector3(0.0, float(_p["cdg"]), z_medio * 0.85)
	# Inercia algo mayor que la de una caja: el coche no "baila" tanto al girar.
	var ancho: float = 2.0
	for r in ruedas:
		ancho = maxf(ancho, absf((r["reposo"] as Vector3).x) * 2.0 + 0.4)
	inertia = Vector3(mass * (ancho * ancho + 1.6) / 12.0 * 1.4,
			mass * (ancho * ancho + largo * largo) / 12.0 * 1.1,
			mass * (largo * largo + 1.6) / 12.0 * 1.2)
	collision_mask = 1 | 4   # Capa 3 (valor 4): objetos del escenario con física (farolas, bancos...).
	contact_monitor = true
	max_contacts_reported = 6
	can_sleep = true
	# REPLACE: si no, Godot suma su amortiguación por defecto (0,1), que frena el coche como un
	# ancla (a 100 km/h quitaba 3 m/s² de aceleración).
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.3
	continuous_cd = true
	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = 0.45   # La carrocería contra las paredes resbala (no se queda pegada).
	mat.bounce = 0.05
	physics_material_override = mat


func excluir(rid: RID) -> void:
	if not _excluir.has(rid):
		_excluir.append(rid)


func _physics_process(delta: float) -> void:
	if ruedas.is_empty():
		return
	_vigilar_distancia(delta)
	if freeze:
		return
	if sleeping and not conducido:
		return   # Aparcado y quieto: no gasta nada hasta que algo lo golpee.
	_t_golpe = maxf(0.0, _t_golpe - delta)
	var b: Basis = global_transform.basis
	var arriba: Vector3 = b.y
	var adelante: Vector3 = -b.z
	velocidad = linear_velocity.dot(adelante)
	var rapidez: float = linear_velocity.length()
	_mandos(delta, rapidez)
	var espacio: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var cdg_global: Vector3 = global_transform * center_of_mass
	ruedas_en_suelo = 0
	deslizamiento = 0.0
	# 1) Suspensión: rayo por rueda, muelle + amortiguador.
	for r in ruedas:
		_suspension(r, espacio, b, delta)
	_estabilizadoras(b)
	# 2) Neumáticos: fuerzas en el suelo con agarre limitado.
	var motrices: int = 0
	for r in ruedas:
		if r["motriz"] and r["suelo"]:
			motrices += 1
	var fuerza_motor: float = _fuerza_motor(rapidez)
	var fuerza_freno: float = 0.0
	if frenando:
		fuerza_freno = mass * 10.5
	for r in ruedas:
		_neumatico(r, b, cdg_global, delta, fuerza_motor / float(maxi(1, motrices)), fuerza_freno)
	# 3) Aire, ayudas y volcado.
	var horizontal: Vector3 = linear_velocity - arriba * linear_velocity.dot(arriba)
	apply_central_force(-horizontal * horizontal.length() * _aero)
	if ruedas_en_suelo > 0:
		apply_central_force(-arriba * rapidez * rapidez * 0.12 * mass / 1000.0)   # Algo de carga aerodinámica.
	_ayudas(b, rapidez)
	_volcado(delta, arriba, rapidez)
	_ruedas_visuales(delta)
	_comprobar_golpe_por_velocidad(delta)


# Traduce W/S en acelerador, freno y marcha atrás, y suaviza la dirección.
func _mandos(delta: float, rapidez: float) -> void:
	acelerador = 0.0
	frenando = false
	if conducido and not sin_gasolina:
		if entrada > 0.05:
			if velocidad < -1.0:
				frenando = true          # Ibas marcha atrás: primero frena.
			else:
				acelerador = entrada
				if marcha == 0:
					marcha = 1
		elif entrada < -0.05:
			if velocidad > 1.0:
				frenando = true
			else:
				acelerador = -entrada
				marcha = 0
	elif conducido and entrada < -0.05 and velocidad > 1.0:
		frenando = true
	# La dirección gira menos cuanto más rápido vas (si no, a 150 km/h darías la vuelta en seco).
	var limite: float = lerpf(giro_max, giro_max * 0.2, clampf(rapidez / 38.0, 0.0, 1.0))
	var objetivo: float = clampf(direccion + tiron * 0.25, -1.0, 1.0) * limite if conducido else 0.0
	var vel_giro: float = 2.6 if absf(objetivo) > absf(_angulo) else 4.5
	_angulo = move_toward(_angulo, objetivo, vel_giro * delta)
	# Caja de cambios automática (solo afecta a las revoluciones, al sonido y a un tirón al cambiar).
	var n: int = int(_p["marchas"])
	var rpm_max: float = float(_p["rpm_max"])
	var ralenti: float = rpm_max * 0.14
	_cambio_t = maxf(0.0, _cambio_t - delta)
	if marcha > 0:
		var v_marcha: float = vmax * pow(float(marcha) / float(n), 0.85) * 1.02
		var r: float = absf(velocidad) / maxf(1.0, v_marcha)
		if r > 0.95 and marcha < n and acelerador > 0.0:
			marcha += 1
			_cambio_t = 0.2
		elif marcha > 1:
			var v_baja: float = vmax * pow(float(marcha - 1) / float(n), 0.85) * 1.02
			if absf(velocidad) / v_baja < 0.6:
				marcha -= 1
		v_marcha = vmax * pow(float(marcha) / float(n), 0.85) * 1.02
		var objetivo_rpm: float = ralenti + (rpm_max - ralenti) * clampf(absf(velocidad) / v_marcha, 0.0, 1.05)
		if acelerador > 0.0 and _patina_motriz():
			objetivo_rpm = minf(rpm_max * 1.02, objetivo_rpm + rpm_max * 0.35 * acelerador)
		rpm = lerpf(rpm, objetivo_rpm, clampf(delta * 8.0, 0.0, 1.0))
	else:
		var objetivo_r: float = ralenti + (rpm_max - ralenti) * clampf(absf(velocidad) / (vmax * 0.3), 0.0, 1.0)
		rpm = lerpf(rpm, objetivo_r, clampf(delta * 8.0, 0.0, 1.0))
	if not conducido:
		rpm = lerpf(rpm, 0.0, clampf(delta * 2.0, 0.0, 1.0))


func _patina_motriz() -> bool:
	for r in ruedas:
		if r["motriz"] and float(r["desliz"]) > 3.0:
			return true
	return false


# Fuerza total que empuja el motor (N), con signo (negativa = marcha atrás).
func _fuerza_motor(rapidez: float) -> float:
	if acelerador <= 0.0:
		return 0.0
	var tope: float = vmax if marcha > 0 else vmax * 0.3
	var f: float = minf(mass * acel * 1.05, _potencia / maxf(rapidez, 3.0))
	f *= clampf((tope - absf(velocidad)) / (tope * 0.06), 0.0, 1.0)   # Corte de inyección al llegar a la punta.
	if _cambio_t > 0.0:
		f *= 0.35
	f *= acelerador * factor_motor
	return f if marcha > 0 else -f


func _suspension(r: Dictionary, espacio: PhysicsDirectSpaceState3D, b: Basis, delta: float) -> void:
	var reposo: Vector3 = r["reposo"]
	var radio: float = float(r["radio"]) * (1.0 - 0.4 * float(r["pinchada"]))   # Pinchada: va sobre la llanta.
	var ancla: Vector3 = global_transform * (reposo + Vector3.UP * _recorrido)
	var abajo: Vector3 = -b.y
	var largo_rayo: float = _recorrido * 2.0 + radio
	var consulta: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ancla, ancla + abajo * largo_rayo)
	var excl: Array[RID] = [get_rid()]
	for e in _excluir:
		excl.append(e)
	consulta.exclude = excl
	var hit: Dictionary = {}
	for intento in 3:
		hit = espacio.intersect_ray(consulta)
		if hit.is_empty():
			break
		var otro: Object = hit["collider"]
		# Las ruedas no se suben encima de las personas ni de otros cuerpos que se mueven solos.
		if otro is StaticBody3D or otro is RigidBody3D or otro is CSGShape3D:
			break
		excl.append(hit["rid"])
		consulta.exclude = excl
		hit = {}
	var x_antes: float = r["x"]
	if hit.is_empty():
		r["suelo"] = false
		r["carga"] = 0.0
		r["x"] = move_toward(x_antes, _recorrido * 2.0, delta * 3.0)
		return
	var x: float = maxf(0.0, ancla.distance_to(hit["position"]) - radio)
	r["x"] = x
	r["suelo"] = true
	r["punto"] = hit["position"]
	r["normal"] = hit["normal"]
	ruedas_en_suelo += 1
	var vel_x: float = (x - x_antes) / maxf(delta, 0.001)
	var f: float = _k * (_largo_reposo - x) - _c * vel_x
	if x < 0.03:
		f += _k * 6.0 * (0.03 - x)   # Tope de la suspensión: no atraviesa el suelo en una caída.
	f = maxf(0.0, f)
	r["carga"] = f
	# El muelle empuja perpendicular al suelo (no según la inclinación de la carrocería): si no, un
	# coche que cabecea se empuja solo hacia delante.
	var n: Vector3 = (hit["normal"] as Vector3)
	apply_force(n * f * maxf(0.0, n.dot(b.y)), ancla - global_position)


# Barras estabilizadoras: reparten la compresión entre la rueda izquierda y la derecha de cada eje.
func _estabilizadoras(b: Basis) -> void:
	var k_barra: float = _k * 0.45
	for i in range(0, ruedas.size() - 1, 2):
		var a: Dictionary = ruedas[i]
		var c: Dictionary = ruedas[i + 1]
		if not (a["suelo"] or c["suelo"]):
			continue
		var dif: float = float(c["x"]) - float(a["x"])   # >0: la rueda "a" está más comprimida.
		var f: float = dif * k_barra
		var pa: Vector3 = global_transform * (a["reposo"] as Vector3)
		var pc: Vector3 = global_transform * (c["reposo"] as Vector3)
		if a["suelo"]:
			apply_force(b.y * f, pa - global_position)
		if c["suelo"]:
			apply_force(-b.y * f, pc - global_position)


func _neumatico(r: Dictionary, b: Basis, cdg: Vector3, delta: float, motor: float, freno: float) -> void:
	r["desliz"] = 0.0
	var radio: float = r["radio"]
	if not r["suelo"]:
		r["w"] = lerpf(float(r["w"]), 0.0 if not r["motriz"] else float(r["w"]), delta * 0.5)
		return
	var n: Vector3 = r["normal"]
	var angulo: float = _angulo if r["del"] else 0.0
	if r["del"] and absf(angulo) > 0.01:
		# Geometría de Ackermann: la rueda de dentro gira un poco más.
		var dentro: bool = signf(angulo) == -float(r["lado"])
		angulo *= 1.08 if dentro else 0.93
	var fwd: Vector3 = (-b.z).rotated(b.y, angulo)
	fwd = (fwd - n * fwd.dot(n)).normalized()
	var lat: Vector3 = n.cross(fwd).normalized()   # Hacia la izquierda de la rueda.
	var punto: Vector3 = r["punto"]
	var aplicar: Vector3 = punto + n * radio * 0.75   # Un poco por encima del suelo: menos balanceo.
	var v: Vector3 = linear_velocity + angular_velocity.cross(punto - cdg)
	var v_long: float = v.dot(fwd)
	var v_lat: float = v.dot(lat)
	var carga: float = float(r["carga"])
	var mu: float = float(_p["agarre"])
	var detras: bool = not r["del"]
	var bloqueada: bool = false
	var aparcado: bool = not conducido
	if (freno_mano and detras) or aparcado:
		mu *= 0.55 if not aparcado else 1.0   # Freno de mano: la parte de atrás suelta y el coche cruza.
		bloqueada = true
	var pinchada: float = float(r["pinchada"])
	mu *= 1.0 - 0.35 * pinchada
	var max_f: float = mu * carga
	# --- Fuerza longitudinal ---
	var fx: float = 0.0
	if bloqueada:
		fx = clampf(-v_long * _masa_rueda / delta, -max_f * 0.9, max_f * 0.9)
	else:
		if r["motriz"]:
			# Control de tracción: por encima de 25 km/h la rueda no patina más de la cuenta (solo
			# se queman ruedas al arrancar a fondo).
			if absf(v_long) > 7.0 and absf(motor) > max_f:
				fx += signf(motor) * max_f * 1.02
			else:
				fx += motor
		if freno > 0.0:
			var reparto: float = 0.62 if r["del"] else 0.38
			var fb: float = freno * reparto / float(maxi(1, ruedas.size() / 2))
			fx += clampf(-v_long * _masa_rueda / delta, -fb, fb)
		elif absf(motor) < 1.0 and absf(v_long) < 0.8 and conducido:
			fx += clampf(-v_long * _masa_rueda / delta, -max_f * 0.5, max_f * 0.5)   # Parado: no se escurre.
		elif absf(motor) < 1.0:
			# Rodadura y freno motor al soltar el pedal.
			var resistencia: float = carga * (0.015 + (0.05 if conducido else 0.0))
			fx += clampf(-v_long * _masa_rueda / delta, -resistencia, resistencia)
	if pinchada > 0.0:
		# Rueda pinchada: frena mucho (la goma se arrastra) y tira el coche hacia ese lado.
		var arrastre: float = carga * 0.06 * pinchada
		fx += clampf(-v_long * _masa_rueda / delta, -arrastre, arrastre)
	# --- Fuerza lateral (curva de agarre por ángulo de deriva) ---
	var deriva: float = atan2(v_lat, maxf(absf(v_long), 2.5))
	var fy: float = -max_f * sin(1.45 * atan(9.0 * deriva))
	var lenta: float = clampf(1.0 - absf(v_long) / 3.0, 0.0, 1.0)
	if lenta > 0.0:
		fy = lerpf(fy, clampf(-v_lat * _masa_rueda / delta * 0.6, -max_f, max_f), lenta)
	# --- Círculo de fricción: lo que pides de frenada/aceleración quita agarre lateral ---
	var total: float = sqrt(fx * fx + fy * fy)
	var patina: float = 0.0
	if total > max_f and total > 0.001:
		var k: float = max_f / total
		patina = (total - max_f) / maxf(1.0, max_f)
		fx *= k
		fy *= k * (0.85 if patina > 0.15 else 1.0)
	apply_force(fwd * fx + lat * fy, aplicar - global_position)
	# --- Lo que se ve: giro de la rueda y deslizamiento para el humo y las marcas ---
	var w_rueda: float = v_long / maxf(radio, 0.05)
	if bloqueada and absf(v_long) > 0.5:
		w_rueda = 0.0
	elif r["motriz"] and patina > 0.05 and absf(motor) > 1.0:
		w_rueda = signf(motor) * maxf(absf(w_rueda), absf(w_rueda) + patina * 60.0)
	r["w"] = lerpf(float(r["w"]), w_rueda, clampf(delta * 12.0, 0.0, 1.0))
	var desliz: float = absf(v_lat) if absf(deriva) > 0.16 else 0.0
	if bloqueada and absf(v_long) > 2.0:
		desliz = maxf(desliz, absf(v_long))
	if patina > 0.05:
		desliz = maxf(desliz, absf(float(r["w"]) * radio - v_long))
	r["desliz"] = desliz
	deslizamiento = maxf(deslizamiento, desliz)


# Ayuda de estabilidad: sin tocar la dirección, frena el giro sobre sí mismo (que no haga trompos
# solo); en el aire, endereza un poco el coche para que caiga sobre las ruedas.
func _ayudas(b: Basis, rapidez: float) -> void:
	var w_y: float = angular_velocity.dot(b.y)
	if ruedas_en_suelo >= 2 and conducido and not freno_mano and absf(direccion) < 0.1 and rapidez > 4.0:
		apply_torque(-b.y * w_y * mass * 0.9)
	if ruedas_en_suelo == 0:
		var eje: Vector3 = b.y.cross(Vector3.UP)
		apply_torque(eje * mass * 2.5)
		apply_torque(-angular_velocity * mass * 0.6)


# Si se queda volcado o de lado y casi quieto, se endereza solo a los 2,5 s.
func _volcado(delta: float, arriba: Vector3, rapidez: float) -> void:
	if arriba.y < 0.35 and rapidez < 3.0:
		volcado_t += delta
		if volcado_t > 2.5:
			enderezar()
	else:
		volcado_t = 0.0


func enderezar() -> void:
	volcado_t = 0.0
	var adelante: Vector3 = -global_transform.basis.z
	adelante.y = 0.0
	if adelante.length() < 0.1:
		adelante = Vector3.FORWARD
	var yaw: float = atan2(-adelante.x, -adelante.z)
	global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3.UP * 1.2)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


# Pincha una rueda (bala, explosión): se desinfla en un par de segundos.
func pinchar(i: int) -> void:
	if i < 0 or i >= ruedas.size():
		return
	ruedas[i]["pinchar"] = true
	sleeping = false


func ruedas_pinchadas() -> int:
	var n: int = 0
	for r in ruedas:
		if r["pinchar"]:
			n += 1
	return n


# Las balas y golpes que dan en el chasis se pasan al vehículo (Vehiculo), que es quien lleva el daño.
func recibir_dano(cantidad: float) -> void:
	var v: Node = get_parent()
	if v != null and v.has_method("dano_en_chasis"):
		v.dano_en_chasis(cantidad)


func recibir_impacto(punto: Vector3, direccion: Vector3, dano: float) -> void:
	var v: Node = get_parent()
	if v != null and v.has_method("recibir_impacto"):
		v.recibir_impacto(punto, direccion, dano)


# Coloca las ruedas visibles donde está la suspensión y las hace rodar y virar.
func _ruedas_visuales(delta: float) -> void:
	for r in ruedas:
		if r["pinchar"] and float(r["pinchada"]) < 1.0:
			r["pinchada"] = minf(1.0, float(r["pinchada"]) + delta * 0.5)
		var piv: Node3D = r["pivote"]
		if float(r["pinchada"]) > 0.0:
			var pz: float = float(r["pinchada"])
			piv.scale = Vector3(1.0, 1.0 - 0.32 * pz, 1.0 + 0.04 * pz)   # Goma aplastada.
		var reposo: Vector3 = r["reposo"]
		var y_obj: float = reposo.y + _recorrido - float(r["x"])
		piv.position.y = lerpf(piv.position.y, y_obj, clampf(delta * 30.0, 0.0, 1.0))
		if r["del"]:
			piv.rotation.y = _angulo
		var g: Node3D = r["giro"]
		g.rotation.x -= float(r["w"]) * delta


# Golpes: un cambio brusco de velocidad que no explican el motor ni los frenos.
func _comprobar_golpe_por_velocidad(delta: float) -> void:
	var dv: Vector3 = linear_velocity - _v_antes
	_v_antes = linear_velocity
	var fuerza: float = dv.length() - 10.5 * 2.0 * delta   # Lo que pueden quitar los frenos en un fotograma.
	if fuerza < 2.5 or _t_golpe > 0.0:
		return
	var punto: Vector3 = global_position + Vector3.UP * 0.8
	var normal: Vector3 = dv.normalized()
	var otro: Object = null
	var contactos: Array = get_colliding_bodies()
	if not contactos.is_empty():
		otro = contactos[0]
	# El punto de choque es el lado del coche que mira hacia donde ha llegado el golpe.
	var local_n: Vector3 = global_transform.basis.inverse() * (-normal)
	var caja: Vector3 = _semi_tamano()
	var p_local: Vector3 = Vector3(clampf(local_n.x * 4.0, -1.0, 1.0) * caja.x,
			caja.y, clampf(local_n.z * 4.0, -1.0, 1.0) * caja.z)
	punto = global_transform * p_local
	_t_golpe = 0.25
	golpe.emit(punto, normal, fuerza, otro)


func _semi_tamano() -> Vector3:
	var x: float = 0.9
	var z: float = 2.0
	for r in ruedas:
		var p: Vector3 = r["reposo"]
		x = maxf(x, absf(p.x) + 0.15)
		z = maxf(z, absf(p.z) + 0.8)
	return Vector3(x, float(_p.get("cdg", 0.5)) + 0.25, z)


# Congela el coche cuando está lejos del jugador (el suelo de ese trozo puede no existir).
func _vigilar_distancia(delta: float) -> void:
	_t_lejos -= delta
	if _t_lejos > 0.0:
		return
	_t_lejos = 0.5
	if conducido:
		if freeze:
			freeze = false
		return
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var lejos: bool = cam.global_position.distance_to(global_position) > RADIO_CONGELAR
	if lejos != freeze:
		freeze = lejos
		if not lejos:
			sleeping = false
