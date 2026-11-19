# parques.gd
# -----------------------------------------------------------------------------
# Aceras, parques y jardines de las ciudades, pueblos y aldeas del mundo grande.
# Todo son funciones puras (solo datos), así que se pueden ejecutar en un hilo
# desde generador_mundo.gd, igual que las casas.
#
#   - Cada bloque de 36 x 36 m lleva una acera de 1,2 m alrededor.
#   - Los cuatro bloques de la plaza mayor de las ciudades son parques con su
#     tema: fuente, bosquecillo, juegos infantiles y estatua con quiosco.
#   - Los solares sin casa se llenan de jardín (setos, árboles, banco, farola).
# Dos mallas: "solido" (con choque: troncos, bancos, fuentes) y "verde" (sin choque:
# copas, flores, caminos). Las farolas devuelven un "prop" que enciende una luz de noche.
# -----------------------------------------------------------------------------
class_name Parques
extends RefCounted

const ACERA: float = 1.2
const ALTO_ACERA: float = 0.2     # Sobre el terreno (la carretera está a 0,15: un escalón de 5 cm).
const ALTO_CAMINO: float = 0.08

const C_ACERA: Color = Color(0.58, 0.56, 0.53)
const C_CAMINO: Color = Color(0.66, 0.57, 0.42)
const C_PIEDRA: Color = Color(0.62, 0.62, 0.64)
const C_PIEDRA_OSC: Color = Color(0.45, 0.45, 0.48)
const C_MADERA: Color = Color(0.5, 0.33, 0.18)
const C_TRONCO: Color = Color(0.38, 0.25, 0.15)
const C_SETO: Color = Color(0.16, 0.38, 0.17)
const COPAS: Array = [Color(0.2, 0.5, 0.2), Color(0.28, 0.58, 0.22), Color(0.16, 0.42, 0.24),
		Color(0.72, 0.5, 0.15), Color(0.8, 0.35, 0.18), Color(0.88, 0.55, 0.65)]
const FLORES: Array = [Color(0.9, 0.25, 0.3), Color(0.95, 0.8, 0.25), Color(0.7, 0.4, 0.9),
		Color(0.95, 0.95, 0.9), Color(0.95, 0.5, 0.2)]


# Punto de entrada: decora el bloque (k, l) del asentamiento "s". "props" recibe las farolas.
static func bloque(solido: ConstructorMalla, verde: ConstructorMalla, props: Array,
		s: Dictionary, k: int, l: int) -> void:
	var p: Vector2 = s["pos"]
	var y: float = s["base"]
	var bx: float = p.x + k * GeneradorMundo.BLOQUE + GeneradorMundo.CALLE_ANCHO / 2.0
	var bz: float = p.y + l * GeneradorMundo.BLOQUE + GeneradorMundo.CALLE_ANCHO / 2.0
	var sid: int = int(s["ci"]) * 1009 + int(s["cj"])
	var clave: int = k * 101 + l
	_aceras(solido, bx, bz, y)
	var centro: Vector3 = Vector3(bx + 18.0, y, bz + 18.0)
	if int(s["tipo"]) == 2 and k >= -1 and k <= 0 and l >= -1 and l <= 0:
		match (k + 1) + (l + 1) * 2:
			0: _parque_fuente(solido, verde, props, centro, sid, clave)
			1: _parque_bosque(solido, verde, props, centro, sid, clave)
			2: _parque_juegos(solido, verde, props, centro, sid, clave)
			3: _parque_estatua(solido, verde, props, centro, sid, clave)
		return
	if GeneradorMundo.servicio_de(s, k, l) != "" and GeneradorMundo.servicio_de(s, k, l) == "gasolinera":
		return
	for sub in 4:
		if GeneradorMundo.casa(s, k, l, sub).is_empty():
			var a: int = sub % 2
			var b: int = sub / 2
			var c: Vector3 = Vector3(bx + a * 18.0 + 9.0, y, bz + b * 18.0 + 9.0)
			_jardin(solido, verde, props, c, sid, clave * 4 + sub)


static func _aceras(m: ConstructorMalla, bx: float, bz: float, y: float) -> void:
	var t: float = 36.0
	var yc: float = y + ALTO_ACERA / 2.0 - 0.05
	var grosor: float = ALTO_ACERA + 0.1
	m.caja(Vector3(bx + t / 2.0, yc, bz + ACERA / 2.0), Vector3(t, grosor, ACERA), C_ACERA)
	m.caja(Vector3(bx + t / 2.0, yc, bz + t - ACERA / 2.0), Vector3(t, grosor, ACERA), C_ACERA)
	m.caja(Vector3(bx + ACERA / 2.0, yc, bz + t / 2.0), Vector3(ACERA, grosor, t - 2.0 * ACERA), C_ACERA)
	m.caja(Vector3(bx + t - ACERA / 2.0, yc, bz + t / 2.0), Vector3(ACERA, grosor, t - 2.0 * ACERA), C_ACERA)


# ------------------------------ piezas sueltas ------------------------------

static func arbol(solido: ConstructorMalla, verde: ConstructorMalla, base: Vector3, esc: float,
		col: Color, estilo: int) -> void:
	solido.cono(base, 0.2 * esc, 1.6 * esc, 6, C_TRONCO, 0.14 * esc)
	var c: Vector3 = base + Vector3(0, 1.3 * esc, 0)
	if estilo == 0:   # Copa redonda de tres pisos.
		verde.cono(c, 1.0 * esc, 0.7 * esc, 7, col, 1.5 * esc)
		verde.cono(c + Vector3(0, 0.7 * esc, 0), 1.5 * esc, 0.9 * esc, 7, col.lightened(0.08), 1.0 * esc)
		verde.cono(c + Vector3(0, 1.6 * esc, 0), 1.0 * esc, 0.8 * esc, 7, col.lightened(0.15), 0.0)
	elif estilo == 1:   # Abeto.
		verde.cono(c, 1.5 * esc, 1.3 * esc, 8, col.darkened(0.2), 0.3 * esc)
		verde.cono(c + Vector3(0, 1.1 * esc, 0), 1.2 * esc, 1.2 * esc, 8, col.darkened(0.1), 0.2 * esc)
		verde.cono(c + Vector3(0, 2.1 * esc, 0), 0.8 * esc, 1.2 * esc, 8, col, 0.0)
	else:   # Árbol de flor, copa ancha y baja.
		verde.cono(c, 1.2 * esc, 0.5 * esc, 8, col, 2.0 * esc)
		verde.cono(c + Vector3(0, 0.5 * esc, 0), 2.0 * esc, 0.8 * esc, 8, col.lightened(0.1), 1.0 * esc)
		verde.cono(c + Vector3(0, 1.3 * esc, 0), 1.0 * esc, 0.4 * esc, 8, col.lightened(0.2), 0.0)


static func banco(solido: ConstructorMalla, c: Vector3, a_lo_largo_de_x: bool) -> void:
	var largo: Vector3 = Vector3(1.8, 0.1, 0.5) if a_lo_largo_de_x else Vector3(0.5, 0.1, 1.8)
	var resp: Vector3 = Vector3(1.8, 0.45, 0.08) if a_lo_largo_de_x else Vector3(0.08, 0.45, 1.8)
	solido.caja(c + Vector3(0, 0.45, 0), largo, C_MADERA)
	var atras: Vector3 = Vector3(0, 0.75, -0.22) if a_lo_largo_de_x else Vector3(-0.22, 0.75, 0)
	solido.caja(c + atras, resp, C_MADERA.darkened(0.1))
	for lado in [-0.75, 0.75]:
		var pata: Vector3 = Vector3(lado, 0.22, 0) if a_lo_largo_de_x else Vector3(0, 0.22, lado)
		solido.caja(c + pata, Vector3(0.1, 0.44, 0.45) if a_lo_largo_de_x else Vector3(0.45, 0.44, 0.1), C_PIEDRA_OSC)


static func farola(solido: ConstructorMalla, props: Array, c: Vector3) -> void:
	solido.cono(c, 0.1, 0.35, 8, C_PIEDRA_OSC, 0.08)
	solido.cono(c + Vector3(0, 0.35, 0), 0.06, 3.0, 6, Color(0.14, 0.14, 0.16), 0.05)
	solido.caja(c + Vector3(0, 3.5, 0), Vector3(0.42, 0.12, 0.42), Color(0.12, 0.12, 0.14))
	solido.cono(c + Vector3(0, 3.56, 0), 0.3, 0.22, 4, Color(0.12, 0.12, 0.14), 0.05)
	props.append({"tipo": "farola", "pos": c + Vector3(0, 3.3, 0)})


static func seto(solido: ConstructorMalla, c: Vector3, tam: Vector3) -> void:
	solido.caja(c + Vector3(0, tam.y / 2.0, 0), tam, C_SETO)
	solido.caja(c + Vector3(0, tam.y + 0.04, 0), Vector3(tam.x * 0.92, 0.08, tam.z * 0.92), C_SETO.lightened(0.12))


static func parterre(solido: ConstructorMalla, verde: ConstructorMalla, c: Vector3, r: float, sid: int, clave: int) -> void:
	solido.cono(c, r, 0.35, 10, C_PIEDRA, r)
	verde.cono(c + Vector3(0, 0.35, 0), r - 0.1, 0.12, 10, C_SETO.lightened(0.05), r - 0.3)
	var n: int = int(r * 4.0)
	for i in n:
		var a: float = TAU * float(i) / float(n) + GeneradorMundo._f(sid, clave, i) * 0.5
		var rr: float = r * (0.25 + 0.6 * GeneradorMundo._f(sid, clave + 3, i))
		var col: Color = FLORES[GeneradorMundo._h(sid, clave, i + 40) % FLORES.size()]
		verde.caja(c + Vector3(cos(a) * rr, 0.62, sin(a) * rr), Vector3(0.22, 0.22, 0.22), col)
		verde.caja(c + Vector3(cos(a) * rr, 0.48, sin(a) * rr), Vector3(0.05, 0.2, 0.05), Color(0.2, 0.45, 0.2))


static func fuente(solido: ConstructorMalla, verde: ConstructorMalla, c: Vector3, r: float) -> void:
	solido.cono(c, r + 0.4, 0.15, 12, C_PIEDRA_OSC, r + 0.4)        # Base
	solido.cono(c + Vector3(0, 0.15, 0), r, 0.7, 12, C_PIEDRA, r)    # Muro de la pila
	solido.cono(c + Vector3(0, 0.85, 0), r + 0.2, 0.12, 12, C_PIEDRA.lightened(0.1), r + 0.2)   # Borde
	verde.disco(c + Vector3(0, 0.62, 0), r - 0.05, 12, Color(0.3, 0.62, 0.78))                 # Agua
	solido.cono(c + Vector3(0, 0.15, 0), 0.5, 1.5, 8, C_PIEDRA, 0.35)                           # Pie
	solido.cono(c + Vector3(0, 1.6, 0), 1.3, 0.2, 12, C_PIEDRA, 1.1)                            # Plato
	verde.disco(c + Vector3(0, 1.81, 0), 1.05, 10, Color(0.4, 0.7, 0.85))
	solido.cono(c + Vector3(0, 1.7, 0), 0.22, 1.3, 6, C_PIEDRA.lightened(0.08), 0.15)           # Surtidor
	verde.cono(c + Vector3(0, 3.0, 0), 0.18, 0.3, 6, Color(0.7, 0.88, 0.95), 0.0)


static func camino(verde: ConstructorMalla, x0: float, x1: float, z0: float, z1: float, y: float, col: Color = C_CAMINO) -> void:
	verde.caja(Vector3((x0 + x1) / 2.0, y + ALTO_CAMINO / 2.0 - 0.02, (z0 + z1) / 2.0),
			Vector3(x1 - x0, ALTO_CAMINO + 0.04, z1 - z0), col)


static func _arboles_borde(solido: ConstructorMalla, verde: ConstructorMalla, c: Vector3, n: int, sid: int, clave: int, estilo: int = -1) -> void:
	# Árboles repartidos por el cuadrado, lejos del centro y de los caminos en cruz.
	for i in n:
		var x: float = (GeneradorMundo._f(sid, clave, i * 3) - 0.5) * 28.0
		var z: float = (GeneradorMundo._f(sid, clave, i * 3 + 1) - 0.5) * 28.0
		if absf(x) < 2.6 or absf(z) < 2.6 or (absf(x) < 5.5 and absf(z) < 5.5):
			continue
		var col: Color = COPAS[GeneradorMundo._h(sid, clave, i * 3 + 2) % COPAS.size()]
		var est: int = estilo if estilo >= 0 else GeneradorMundo._h(sid, clave, i + 90) % 3
		var esc: float = 0.8 + 0.5 * GeneradorMundo._f(sid, clave, i + 200)
		arbol(solido, verde, c + Vector3(x, 0, z), esc, col, est)


static func _cruz(verde: ConstructorMalla, c: Vector3) -> void:
	camino(verde, c.x - 1.4, c.x + 1.4, c.z - 15.5, c.z + 15.5, c.y)
	camino(verde, c.x - 15.5, c.x + 15.5, c.z - 1.4, c.z + 1.4, c.y)


# --------------------------------- parques ----------------------------------

static func _parque_fuente(sol: ConstructorMalla, ver: ConstructorMalla, props: Array, c: Vector3, sid: int, clave: int) -> void:
	_cruz(ver, c)
	camino(ver, c.x - 5.2, c.x + 5.2, c.z - 5.2, c.z + 5.2, c.y, C_PIEDRA.darkened(0.1))
	fuente(sol, ver, c, 3.2)
	for q in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		parterre(sol, ver, c + Vector3(q.x * 10.5, 0, q.y * 10.5), 3.2, sid, clave + int(q.x * 3 + q.y))
		banco(sol, c + Vector3(q.x * 5.8, 0, q.y * 0.0 + 0.0 + (2.4 if q.y > 0 else -2.4)), true)
		farola(sol, props, c + Vector3(q.x * 6.2, 0, q.y * 6.2))
	_arboles_borde(sol, ver, c, 12, sid, clave, 2)


static func _parque_bosque(sol: ConstructorMalla, ver: ConstructorMalla, props: Array, c: Vector3, sid: int, clave: int) -> void:
	camino(ver, c.x - 1.2, c.x + 1.2, c.z - 15.5, c.z + 15.5, c.y)
	camino(ver, c.x - 15.5, c.x + 15.5, c.z - 1.2, c.z + 1.2, c.y)
	_arboles_borde(sol, ver, c, 34, sid, clave)
	# Zona de picnic en el centro.
	for d in [-1.0, 1.0]:
		sol.caja(c + Vector3(d * 5.0, 0.75, 4.0), Vector3(1.6, 0.08, 0.9), C_MADERA)
		sol.caja(c + Vector3(d * 5.0, 0.4, 3.1), Vector3(1.6, 0.06, 0.3), C_MADERA.darkened(0.1))
		sol.caja(c + Vector3(d * 5.0, 0.4, 4.9), Vector3(1.6, 0.06, 0.3), C_MADERA.darkened(0.1))
		sol.caja(c + Vector3(d * 5.0, 0.38, 4.0), Vector3(0.12, 0.76, 0.9), C_MADERA.darkened(0.2))
		banco(sol, c + Vector3(d * 5.0, 0, -4.0), true)
	for q in [Vector2(1, 1), Vector2(-1, -1)]:
		farola(sol, props, c + Vector3(q.x * 3.2, 0, q.y * 3.2))


static func _parque_juegos(sol: ConstructorMalla, ver: ConstructorMalla, props: Array, c: Vector3, sid: int, clave: int) -> void:
	_cruz(ver, c)
	# Arenero.
	ver.caja(c + Vector3(7.0, 0.1, 7.0), Vector3(6.0, 0.2, 6.0), Color(0.86, 0.78, 0.56))
	for d in [-3.0, 3.0]:
		sol.caja(c + Vector3(7.0 + d, 0.3, 7.0), Vector3(0.25, 0.6, 6.3), C_MADERA)
		sol.caja(c + Vector3(7.0, 0.3, 7.0 + d), Vector3(6.3, 0.6, 0.25), C_MADERA)
	# Columpios: dos postes en A, una barra y dos asientos.
	var cc: Vector3 = c + Vector3(-8.0, 0, 8.0)
	for d in [-2.0, 2.0]:
		sol.caja(cc + Vector3(d, 1.3, 0.0), Vector3(0.14, 2.6, 0.14), Color(0.85, 0.2, 0.2))
	sol.caja(cc + Vector3(0, 2.55, 0), Vector3(4.3, 0.14, 0.14), Color(0.85, 0.2, 0.2))
	for d in [-0.8, 0.8]:
		ver.caja(cc + Vector3(d, 1.3, 0), Vector3(0.03, 2.4, 0.03), C_PIEDRA_OSC)
		ver.caja(cc + Vector3(d, 0.5, 0), Vector3(0.6, 0.06, 0.3), Color(0.95, 0.8, 0.2))
	# Tobogán: escalera, plataforma y rampa.
	var tc: Vector3 = c + Vector3(-8.0, 0, -8.0)
	sol.caja(tc + Vector3(0, 1.6, 0), Vector3(1.2, 0.1, 1.2), Color(0.2, 0.45, 0.85))
	for esq in [Vector2(-0.55, -0.55), Vector2(0.55, -0.55), Vector2(-0.55, 0.55), Vector2(0.55, 0.55)]:
		sol.caja(tc + Vector3(esq.x, 0.8, esq.y), Vector3(0.1, 1.6, 0.1), Color(0.85, 0.7, 0.2))
	sol.caja(tc + Vector3(-0.9, 0.8, 0), Vector3(0.1, 1.6, 0.9), Color(0.85, 0.7, 0.2))
	sol.cuadro(tc + Vector3(0.6, 1.62, -0.5), tc + Vector3(0.6, 1.62, 0.5), tc + Vector3(3.2, 0.1, 0.5),
			tc + Vector3(3.2, 0.1, -0.5), Color(0.9, 0.35, 0.25))
	banco(sol, c + Vector3(8.0, 0, -7.5), true)
	banco(sol, c + Vector3(-1.0, 0, 11.5), true)
	for q in [Vector2(1, 1), Vector2(-1, -1)]:
		farola(sol, props, c + Vector3(q.x * 12.0, 0, q.y * 12.0))
	_arboles_borde(sol, ver, c, 14, sid, clave)


static func _parque_estatua(sol: ConstructorMalla, ver: ConstructorMalla, props: Array, c: Vector3, sid: int, clave: int) -> void:
	_cruz(ver, c)
	camino(ver, c.x - 4.5, c.x + 4.5, c.z - 4.5, c.z + 4.5, c.y, C_PIEDRA.darkened(0.1))
	# Pedestal escalonado y estatua de un alquimista con capa.
	sol.cono(c, 3.2, 0.3, 8, C_PIEDRA_OSC, 3.0)
	sol.cono(c + Vector3(0, 0.3, 0), 2.2, 0.3, 8, C_PIEDRA, 2.0)
	sol.caja(c + Vector3(0, 1.4, 0), Vector3(1.4, 1.6, 1.4), C_PIEDRA)
	sol.cono(c + Vector3(0, 2.2, 0), 0.55, 1.7, 7, Color(0.5, 0.5, 0.55), 0.3)   # Cuerpo con capa
	sol.cono(c + Vector3(0, 3.9, 0), 0.28, 0.1, 7, Color(0.5, 0.5, 0.55), 0.26)
	ver.cono(c + Vector3(0, 3.95, 0), 0.26, 0.55, 7, Color(0.45, 0.45, 0.5), 0.0)  # Sombrero de pico
	# Quiosco en una esquina.
	var kc: Vector3 = c + Vector3(10.5, 0, -10.5)
	sol.caja(kc + Vector3(0, 1.1, 0), Vector3(3.0, 2.2, 2.4), Color(0.28, 0.5, 0.58))
	sol.caja(kc + Vector3(0, 1.0, 1.25), Vector3(2.4, 0.9, 0.05), Color(0.15, 0.2, 0.25))
	ver.techo(kc + Vector3(0, 2.2, 0), 3.8, 3.2, 0.9, Color(0.75, 0.3, 0.25))
	# Setos que enmarcan la plaza y bancos mirando a la estatua.
	for d in [-1.0, 1.0]:
		seto(sol, c + Vector3(d * 9.0, 0, 12.5), Vector3(7.0, 1.1, 0.9))
		seto(sol, c + Vector3(d * 9.0, 0, -12.5), Vector3(7.0, 1.1, 0.9))
		banco(sol, c + Vector3(d * 6.0, 0, 3.0), false)
	for q in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
		farola(sol, props, c + Vector3(q.x * 6.0, 0, q.y * 6.0))
	_arboles_borde(sol, ver, c, 14, sid, clave)


# Un solar vacío de 18 x 18 m: jardincito con valla viva.
static func _jardin(sol: ConstructorMalla, ver: ConstructorMalla, props: Array, c: Vector3, sid: int, clave: int) -> void:
	var tipo: int = GeneradorMundo._h(sid, clave, 5) % 4
	camino(ver, c.x - 0.9, c.x + 0.9, c.z - 8.4, c.z + 8.4, c.y)
	# Setos en las esquinas.
	for q in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		seto(sol, c + Vector3(q.x * 6.5, 0, q.y * 8.0), Vector3(4.5, 1.0, 0.8))
	if tipo == 0:      # Huerto de flores.
		parterre(sol, ver, c + Vector3(-4.0, 0, 0), 2.4, sid, clave)
		parterre(sol, ver, c + Vector3(4.0, 0, 0), 2.4, sid, clave + 1)
	elif tipo == 1:    # Arboleda.
		for i in 4:
			var col: Color = COPAS[GeneradorMundo._h(sid, clave, i) % COPAS.size()]
			arbol(sol, ver, c + Vector3(-5.0 if i % 2 == 0 else 5.0, 0, -4.5 if i < 2 else 4.5),
					0.9 + 0.3 * GeneradorMundo._f(sid, clave, i), col, GeneradorMundo._h(sid, clave, i + 9) % 3)
	elif tipo == 2:    # Rincón de descanso.
		banco(sol, c + Vector3(-3.0, 0, 3.0), false)
		banco(sol, c + Vector3(3.0, 0, 3.0), false)
		arbol(sol, ver, c + Vector3(0, 0, -5.0), 1.1, COPAS[GeneradorMundo._h(sid, clave, 1) % COPAS.size()], 2)
		farola(sol, props, c + Vector3(0, 0, 0.0) + Vector3(2.0, 0, -2.0))
	else:              # Solar con contenedores y cajas (zona más dejada).
		sol.caja(c + Vector3(-4.0, 0.6, -4.0), Vector3(2.4, 1.2, 1.2), Color(0.25, 0.4, 0.3))
		sol.caja(c + Vector3(4.2, 0.4, -3.0), Vector3(1.2, 0.8, 1.2), C_MADERA)
		sol.caja(c + Vector3(4.2, 1.1, -3.0), Vector3(0.9, 0.6, 0.9), C_MADERA.lightened(0.1))
		arbol(sol, ver, c + Vector3(3.0, 0, 4.5), 1.0, COPAS[0], 1)
