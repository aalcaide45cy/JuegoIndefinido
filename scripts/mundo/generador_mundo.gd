# generador_mundo.gd
# -----------------------------------------------------------------------------
# El mundo grande de 10 km x 10 km, generado por una SEMILLA (el mismo número
# da siempre el mismo mundo, así que no hace falta guardar el mapa: solo la
# semilla y lo que el jugador compra o cambia).
#
# Todo son funciones "puras" (solo datos, sin nodos), para poder ejecutarse en
# hilos en segundo plano desde gestor_trozos.gd. Qué genera:
#   - Terreno: llanuras suaves, colinas y montañas (hasta ~150 m).
#   - Asentamientos: aldeas, pueblos y ciudades con calles en cuadrícula, casas
#     (algunas EN ALQUILER / VENTA) y huertos alquilables o comprables.
#   - Carreteras que unen los asentamientos entre sí y con la ciudad original.
#   - Monte: bosques de pinos donde el ruido lo dice.
# La ciudad original (plaza, mercado, residencial, industrial, campo) es el
# "núcleo": el terreno se aplana a su alrededor y las carreteras empiezan en
# los finales de sus calles.
#
# Las coordenadas son metros de mundo (x, z). El mundo va de -5000 a +5000.
# SIN PROBAR en Godot (la nube no puede ejecutarlo): ver PLAN.md.
# -----------------------------------------------------------------------------
class_name GeneradorMundo
extends RefCounted

const MITAD: float = 5000.0            # El mundo mide 2 * MITAD metros de lado.
const CELDA: float = 700.0             # Una celda de asentamientos (puede tener uno). Antes 1200: ahora hay ~3 veces más.
const CELDA_MIN: int = -7
const CELDA_MAX: int = 6
const SEPARACION_MIN: float = 260.0    # Hueco libre mínimo entre las zonas de dos asentamientos.
const BLOQUE: float = 44.0             # Distancia entre calles de un pueblo.
const CALLE_ANCHO: float = 8.0
const TROZO: float = 128.0             # Trozo de cerca (con choques y detalle).
const CELDAS: int = 32                 # Cuadritos por lado en un trozo cercano (4 m).
const TROZO_LEJOS: float = 512.0       # Trozo de lejos (solo vista).
const CELDAS_LEJOS: int = 32           # Cuadritos por lado (16 m).

static var semilla: int = 1847
static var nucleo: Rect2 = Rect2(-110.0, -120.0, 440.0, 240.0)   # La ciudad original.
static var listo: bool = false
static var conectores: Array = []
static var obras_vistas: Array = []   # Para pruebas: ["puente"|"tunel"|"curva", Vector3 posición, dirección Vector2].
static var _r_cont: FastNoiseLite
static var _r_mont: FastNoiseLite
static var _r_med: FastNoiseLite
static var _r_det: FastNoiseLite
static var _r_bosque: FastNoiseLite
static var _r_color: FastNoiseLite

const SILABAS_A: Array = ["Val", "Mor", "Gra", "Bel", "Ros", "Tor", "Cal", "Nor", "Ald", "Vil", "San", "Pen"]
const SILABAS_B: Array = ["mora", "dena", "lar", "vento", "rubia", "pino", "hondo", "seca", "nova", "cerro", "brisa", "gal"]
const COLORES_PARED: Array = [Color(0.78, 0.7, 0.55), Color(0.7, 0.55, 0.4), Color(0.62, 0.6, 0.58),
		Color(0.66, 0.42, 0.34), Color(0.82, 0.78, 0.68), Color(0.5, 0.52, 0.56)]
const COLORES_TECHO: Array = [Color(0.45, 0.2, 0.15), Color(0.3, 0.3, 0.34), Color(0.38, 0.25, 0.18)]

# Estilos de asentamiento: cada pueblo elige uno (por semilla) y además varía por casa, para que
# no se noten patrones. "pitch" = altura del tejado, "plano" = probabilidad de azotea,
# "ancho" = multiplicador del tamaño de las casas, "vacio" = probabilidad de solar vacío.
const ESTILOS: Array = [
	{"nombre": "piedra clara", "paredes": [Color(0.78, 0.7, 0.55), Color(0.82, 0.78, 0.68), Color(0.7, 0.66, 0.6)],
			"techos": [Color(0.55, 0.25, 0.18), Color(0.5, 0.22, 0.15)], "pitch": 2.4, "plano": 0.05, "ancho": 1.0, "vacio": 0.12},
	{"nombre": "ladrillo", "paredes": [Color(0.66, 0.42, 0.34), Color(0.6, 0.36, 0.3), Color(0.7, 0.5, 0.4)],
			"techos": [Color(0.3, 0.3, 0.34), Color(0.25, 0.26, 0.3)], "pitch": 2.0, "plano": 0.1, "ancho": 1.0, "vacio": 0.1},
	{"nombre": "encalado", "paredes": [Color(0.9, 0.9, 0.86), Color(0.88, 0.86, 0.8), Color(0.85, 0.9, 0.92)],
			"techos": [Color(0.2, 0.35, 0.55), Color(0.6, 0.25, 0.2)], "pitch": 1.6, "plano": 0.4, "ancho": 0.9, "vacio": 0.2},
	{"nombre": "madera", "paredes": [Color(0.45, 0.32, 0.22), Color(0.5, 0.38, 0.26), Color(0.38, 0.28, 0.2)],
			"techos": [Color(0.25, 0.2, 0.17), Color(0.3, 0.25, 0.2)], "pitch": 3.1, "plano": 0.0, "ancho": 0.85, "vacio": 0.22},
	{"nombre": "pizarra", "paredes": [Color(0.5, 0.52, 0.56), Color(0.58, 0.6, 0.62), Color(0.45, 0.47, 0.5)],
			"techos": [Color(0.2, 0.22, 0.26), Color(0.18, 0.2, 0.22)], "pitch": 2.8, "plano": 0.08, "ancho": 1.1, "vacio": 0.14},
	{"nombre": "ocre", "paredes": [Color(0.86, 0.7, 0.45), Color(0.9, 0.6, 0.4), Color(0.8, 0.55, 0.35)],
			"techos": [Color(0.7, 0.3, 0.2), Color(0.62, 0.28, 0.18)], "pitch": 1.8, "plano": 0.3, "ancho": 1.0, "vacio": 0.18},
]


static func estilo_de(sid: int) -> Dictionary:
	return ESTILOS[_h(sid, 31, 500) % ESTILOS.size()]


# Cambia un poco el tono, la saturación y el brillo (cada casa, un color propio).
static func _variar(col: Color, a: int, b: int, c: int) -> Color:
	var h: float = fposmod(col.h + (_f(a, b, c) - 0.5) * 0.04, 1.0)
	var sat: float = clampf(col.s * (0.85 + _f(a, b, c + 1) * 0.3), 0.0, 1.0)
	var v: float = clampf(col.v * (0.86 + _f(a, b, c + 2) * 0.26), 0.0, 1.0)
	return Color.from_hsv(h, sat, v)


# Prepara el generador. "rect_nucleo" es el rectángulo que ocupa la ciudad original.
static func iniciar(sem: int, rect_nucleo: Rect2) -> void:
	semilla = sem
	nucleo = rect_nucleo
	_r_cont = _ruido(sem + 1, 1.0 / 2600.0, 3)
	_r_mont = _ruido(sem + 2, 1.0 / 3200.0, 2)
	_r_med = _ruido(sem + 3, 1.0 / 420.0, 2)
	_r_det = _ruido(sem + 4, 1.0 / 70.0, 1)
	_r_bosque = _ruido(sem + 5, 1.0 / 260.0, 2)
	_r_color = _ruido(sem + 6, 1.0 / 35.0, 1)
	conectores = []
	_calcular_asentamientos()
	_calcular_caminos()
	listo = true
	_calcular_conectores()


static func _ruido(sem: int, frecuencia: float, octavas: int) -> FastNoiseLite:
	var r: FastNoiseLite = FastNoiseLite.new()
	r.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	r.seed = sem
	r.frequency = frecuencia
	if octavas > 1:
		r.fractal_type = FastNoiseLite.FRACTAL_FBM
		r.fractal_octaves = octavas
	else:
		r.fractal_type = FastNoiseLite.FRACTAL_NONE
	return r


# ------------------------------- números al azar -------------------------------

static func _h(a: int, b: int, c: int) -> int:
	var x: int = a * 374761393 + b * 668265263 + c * 1013904223 + semilla * 2246822519
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return x & 0x7fffffff


# Número entre 0 y 1 que depende solo de la semilla y de a, b, c.
static func _f(a: int, b: int, c: int) -> float:
	return float(_h(a, b, c) % 100000) / 100000.0


static func dist_rect(x: float, z: float, r: Rect2) -> float:
	var dx: float = maxf(maxf(r.position.x - x, 0.0), x - r.end.x)
	var dz: float = maxf(maxf(r.position.y - z, 0.0), z - r.end.y)
	return sqrt(dx * dx + dz * dz)


# ---------------------------------- terreno -----------------------------------

# Altura "natural" (sin aplanar pueblos ni ciudad).
static func altura_base(x: float, z: float) -> float:
	var ruido_m: float = _r_mont.get_noise_2d(x, z)
	var m: float = smoothstep(0.1, 0.5, ruido_m)
	var pico: float = smoothstep(0.3, 0.8, ruido_m)   # Las cumbres de verdad: hasta ~550 m.
	return 9.0 * _r_cont.get_noise_2d(x, z) + 3.0 * _r_med.get_noise_2d(x, z) \
			+ 1.0 * _r_det.get_noise_2d(x, z) + m * 150.0 + pico * pico * 400.0


# Altura final teniendo en cuenta los asentamientos de la lista y la ciudad original.
static func altura_lista(x: float, z: float, lista: Array) -> float:
	var h: float = altura_base(x, z)
	h = lerpf(-0.3, h, smoothstep(0.0, 400.0, dist_rect(x, z, nucleo)))
	for s in lista:
		if s.has("camino"):
			continue
		var p: Vector2 = s["pos"]
		var d: float = maxf(absf(x - p.x), absf(z - p.y))
		var plano: float = s["plano"]
		if d < plano + 100.0:
			h = lerpf(s["base"], h, smoothstep(plano, plano + 100.0, d))
	# Carreteras de montaña: el terreno se aplana a la altura de la carretera (terraplén y desmonte).
	for c in lista:
		if c.has("camino"):
			h = _tallar_camino(x, z, h, c)
	return h


static func altura(x: float, z: float) -> float:
	var r: Rect2 = Rect2(x - 1.0, z - 1.0, 2.0, 2.0)
	var lista: Array = asentamientos_cerca(r)
	lista.append_array(caminos_cerca(r.grow(30.0)))
	return altura_lista(x, z, lista)


# Altura del terreno en (x, z) tras aplanarlo para una carretera de montaña "c".
static func _tallar_camino(x: float, z: float, h: float, c: Dictionary) -> float:
	var r: Rect2 = c["rect"]
	if not r.has_point(Vector2(x, z)):
		return h
	var pts: PackedVector2Array = c["pts"]
	var hs: PackedFloat32Array = c["hs"]
	var mejor_d: float = INF
	var mejor_h: float = h
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if x < minf(a.x, b.x) - 26.0 or x > maxf(a.x, b.x) + 26.0 or z < minf(a.y, b.y) - 26.0 or z > maxf(a.y, b.y) + 26.0:
			continue
		var ab: Vector2 = b - a
		var t: float = clampf(((x - a.x) * ab.x + (z - a.y) * ab.y) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d: float = Vector2(x, z).distance_to(a + ab * t)
		if d < mejor_d:
			mejor_d = d
			mejor_h = lerpf(hs[i], hs[i + 1], t)
	if mejor_d >= 24.0:
		return h
	return lerpf(mejor_h, h, smoothstep(5.0, 24.0, mejor_d))


static func densidad_bosque(x: float, z: float, h: float) -> float:
	return smoothstep(-0.1, 0.4, _r_bosque.get_noise_2d(x, z)) * (1.0 - smoothstep(150.0, 280.0, h))


static func _color_suelo(x: float, z: float, h: float, ny: float) -> Color:
	var g: float = _r_color.get_noise_2d(x, z) * 0.5 + 0.5
	var col: Color = Color(0.23 + 0.07 * g, 0.35 + 0.08 * g, 0.16)
	col = col.lerp(Color(0.12, 0.24, 0.1), densidad_bosque(x, z, h) * 0.6)
	var roca: float = maxf(smoothstep(110.0, 190.0, h), 1.0 - smoothstep(0.7, 0.85, ny))
	col = col.lerp(Color(0.4, 0.38, 0.36), roca)
	col = col.lerp(Color(0.92, 0.94, 0.97), smoothstep(300.0, 360.0, h))
	return col


# ------------------------------- asentamientos --------------------------------

# Los asentamientos se calculan UNA vez en iniciar() y después solo se leen (así es seguro
# pedirlos desde los hilos que generan los trozos).
static var _asentamientos: Dictionary = {}


# El asentamiento de la celda (ci, cj), o {} si no hay.
static func asentamiento(ci: int, cj: int) -> Dictionary:
	return _asentamientos.get(Vector2i(ci, cj), {})


# Primera pasada: dónde cabría un asentamiento en cada celda (sin mirar a los vecinos).
static func _candidato(ci: int, cj: int) -> Dictionary:
	if ci < CELDA_MIN or ci > CELDA_MAX or cj < CELDA_MIN or cj > CELDA_MAX:
		return {}
	if _f(ci, cj, 1) > 0.9:
		return {}
	var cx: float = (ci + 0.5) * CELDA + (_f(ci, cj, 2) - 0.5) * 420.0
	var cz: float = (cj + 0.5) * CELDA + (_f(ci, cj, 3) - 0.5) * 420.0
	if absf(cx) > MITAD - 450.0 or absf(cz) > MITAD - 450.0:
		return {}
	var centro: Vector2 = Vector2(cx, cz)
	if nucleo.grow(900.0).has_point(centro):
		return {}
	var base: float = altura_base(cx, cz)
	var montana: bool = false
	if base > 30.0:
		# Nada de ciudades en lo alto de una montaña... salvo algún pueblo de montaña, al que
		# se llega por una carretera de montaña (ver _calcular_caminos).
		if base > 320.0 or base < 55.0 or _f(ci, cj, 50) > 0.5:
			return {}
		montana = true
	var r: float = _f(ci, cj, 4)
	var tipo: int = 0
	var n: int = 1
	if montana:
		if r < 0.45:
			tipo = 1
			n = 2
	elif r < 0.07:
		tipo = 2
		n = 4
	elif r < 0.35:
		tipo = 1
		n = 2
	return {"ci": ci, "cj": cj, "pos": centro, "tipo": tipo, "n": n, "mitad": n * BLOQUE,
			"plano": n * BLOQUE + 150.0, "base": base,
			"nombre": ("Alto " if montana else "") + _nombre(ci, cj), "montana": montana}


# Segunda pasada: si dos zonas se pisan, se queda la más grande (y a igualdad, la de celda menor).
static func _calcular_asentamientos() -> void:
	_asentamientos = {}
	var candidatos: Dictionary = {}
	for ci in range(CELDA_MIN, CELDA_MAX + 1):
		for cj in range(CELDA_MIN, CELDA_MAX + 1):
			var c: Dictionary = _candidato(ci, cj)
			if not c.is_empty():
				candidatos[Vector2i(ci, cj)] = c
	for clave in candidatos:
		var c: Dictionary = candidatos[clave]
		var gana: bool = true
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var o: Dictionary = candidatos.get(Vector2i(clave.x + dx, clave.y + dz), {})
				if o.is_empty():
					continue
				var hueco: float = float(c["mitad"]) + float(o["mitad"]) + SEPARACION_MIN
				if (c["pos"] as Vector2).distance_to(o["pos"]) >= hueco:
					continue
				var o_mayor: bool = int(o["tipo"]) > int(c["tipo"]) or (int(o["tipo"]) == int(c["tipo"]) \
						and (o["ci"] < c["ci"] or (o["ci"] == c["ci"] and o["cj"] < c["cj"])))
				if o_mayor:
					gana = false
		if gana:
			_asentamientos[clave] = c


static func nombre_tipo(tipo: int) -> String:
	return ["Aldea", "Pueblo", "Ciudad"][tipo]


static func _nombre(ci: int, cj: int) -> String:
	return str(SILABAS_A[_h(ci, cj, 11) % SILABAS_A.size()]) + str(SILABAS_B[_h(ci, cj, 12) % SILABAS_B.size()])


# Asentamientos cuya zona (casas + huertos + aplanado) toca el rectángulo.
static func asentamientos_cerca(rect: Rect2) -> Array:
	var out: Array = []
	var ci0: int = floori(rect.position.x / CELDA) - 1
	var ci1: int = floori(rect.end.x / CELDA) + 1
	var cj0: int = floori(rect.position.y / CELDA) - 1
	var cj1: int = floori(rect.end.y / CELDA) + 1
	for ci in range(ci0, ci1 + 1):
		for cj in range(cj0, cj1 + 1):
			var s: Dictionary = asentamiento(ci, cj)
			if s.is_empty():
				continue
			var p: Vector2 = s["pos"]
			var radio: float = float(s["plano"]) + 100.0
			if rect.intersects(Rect2(p.x - radio, p.y - radio, radio * 2.0, radio * 2.0)):
				out.append(s)
	return out


static func todos_asentamientos() -> Array:
	var out: Array = []
	for ci in range(CELDA_MIN, CELDA_MAX + 1):
		for cj in range(CELDA_MIN, CELDA_MAX + 1):
			var s: Dictionary = asentamiento(ci, cj)
			if not s.is_empty():
				out.append(s)
	return out


# --------------------------------- carreteras ---------------------------------
# Un tramo es [inicio: Vector2, fin: Vector2, ancho: float, tipo: int]
# (tipo 0 = calle de pueblo, 1 = carretera).

static func _calles_de(s: Dictionary) -> Array:
	var out: Array = []
	var p: Vector2 = s["pos"]
	var n: int = s["n"]
	var m: float = s["mitad"]
	for k in range(-n, n + 1):
		out.append([Vector2(p.x + k * BLOQUE, p.y - m), Vector2(p.x + k * BLOQUE, p.y + m), CALLE_ANCHO, 0])
		out.append([Vector2(p.x - m, p.y + k * BLOQUE), Vector2(p.x + m, p.y + k * BLOQUE), CALLE_ANCHO, 0])
	return out


# Punto de la entrada de un asentamiento en la dirección "hacia" (más allá de los huertos).
static func _puerta(s: Dictionary, hacia: Vector2, extra: float) -> Vector2:
	var p: Vector2 = s["pos"]
	var dir: Vector2 = (hacia - p).normalized()
	var escala: float = 1.0 / maxf(maxf(absf(dir.x), absf(dir.y)), 0.001)
	return p + dir * escala * (float(s["mitad"]) + extra)


# Carretera entre dos asentamientos: de puerta a puerta, y un ramal de cada
# puerta a la calle exterior del pueblo.
static func _conexion(s: Dictionary, t: Dictionary) -> Array:
	if bool(s.get("montana", false)) or bool(t.get("montana", false)):
		return []   # Los pueblos de montaña tienen su propia carretera (_caminos).
	var ps: Vector2 = s["pos"]
	var pt: Vector2 = t["pos"]
	var a: Vector2 = _puerta(s, pt, 110.0)
	var b: Vector2 = _puerta(t, ps, 110.0)
	return [[a, b, 9.0, 1], [a, _puerta(s, pt, 0.0), 9.0, 1], [b, _puerta(t, ps, 0.0), 9.0, 1]]


static func _calcular_conectores() -> void:
	# Los tres finales de calle de la ciudad original (norte, sur y campo al este).
	var salidas: Array = [Vector2(300.0, -16.0), Vector2(16.0, -102.0), Vector2(-16.0, 102.0)]
	var todos: Array = todos_asentamientos()
	for inicio in salidas:
		var mejor: Dictionary = {}
		var d_mejor: float = INF
		for s in todos:
			if bool(s.get("montana", false)):
				continue
			var d: float = (s["pos"] as Vector2).distance_to(inicio)
			if d < d_mejor:
				d_mejor = d
				mejor = s
		if mejor.is_empty():
			continue
		var puerta: Vector2 = _puerta(mejor, inicio, 110.0)
		conectores.append({"ci": mejor["ci"], "cj": mejor["cj"], "segs": [
			[inicio, puerta, 9.0, 1], [puerta, _puerta(mejor, inicio, 0.0), 9.0, 1]]})


# Todos los tramos que pueden tocar el rectángulo.
static func segmentos_para(rect: Rect2) -> Array:
	var out: Array = []
	var ci0: int = floori(rect.position.x / CELDA) - 1
	var ci1: int = floori(rect.end.x / CELDA) + 1
	var cj0: int = floori(rect.position.y / CELDA) - 1
	var cj1: int = floori(rect.end.y / CELDA) + 1
	for ci in range(ci0, ci1 + 1):
		for cj in range(cj0, cj1 + 1):
			var s: Dictionary = asentamiento(ci, cj)
			if s.is_empty():
				continue
			var p: Vector2 = s["pos"]
			var m: float = float(s["mitad"]) + 6.0
			if rect.intersects(Rect2(p.x - m, p.y - m, m * 2.0, m * 2.0)):
				out.append_array(_calles_de(s))
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var t: Dictionary = asentamiento(ci + d.x, cj + d.y)
				if not t.is_empty():
					out.append_array(_conexion(s, t))
	for c in conectores:
		out.append_array(c["segs"])
	for cam in caminos_cerca(rect):
		out.append_array(cam["segs"])
	return out


# Todas las carreteras entre asentamientos (para dibujar el mapa grande).
static func todas_las_carreteras() -> Array:
	var out: Array = []
	for ci in range(CELDA_MIN, CELDA_MAX + 1):
		for cj in range(CELDA_MIN, CELDA_MAX + 1):
			var s: Dictionary = asentamiento(ci, cj)
			if s.is_empty():
				continue
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var t: Dictionary = asentamiento(ci + d.x, cj + d.y)
				if not t.is_empty():
					out.append_array(_conexion(s, t))
	for c in conectores:
		out.append_array(c["segs"])
	for cam in _caminos:
		out.append_array(cam["segs"])
	return out


# ------------------------- carreteras de montaña -------------------------
# Cada pueblo de montaña se une al pueblo de abajo más cercano por una carretera con curvas:
# una sinusoide lateral cuyo número de curvas sale de la pendiente máxima (8 %). Guarda los
# puntos y la altura de la carretera en cada uno; el terreno se talla a esa altura
# (_tallar_camino) y se ponen quitamiedos en el lado del precipicio (_quitamiedos).
static var _caminos: Array = []


static func caminos_cerca(rect: Rect2) -> Array:
	var out: Array = []
	for c in _caminos:
		if (c["rect"] as Rect2).intersects(rect):
			out.append(c)
	return out


static func _calcular_caminos() -> void:
	_caminos = []
	var bajos: Array = []
	for clave in _asentamientos:
		var s: Dictionary = _asentamientos[clave]
		if not bool(s.get("montana", false)):
			bajos.append(s)
	for clave in _asentamientos:
		var m: Dictionary = _asentamientos[clave]
		if not bool(m.get("montana", false)):
			continue
		var mejor: Dictionary = {}
		var d_mejor: float = INF
		for b in bajos:
			var d: float = (b["pos"] as Vector2).distance_to(m["pos"])
			if d < d_mejor:
				d_mejor = d
				mejor = b
		if not mejor.is_empty() and d_mejor < 4200.0:
			_caminos.append(_trazar_camino(m, mejor))


static func _longitud_curva(largo: float, amp: float, k: int) -> float:
	var total: float = 0.0
	var prev: Vector2 = Vector2.ZERO
	for i in range(1, 81):
		var t: float = float(i) / 80.0
		var q: Vector2 = Vector2(largo * t, amp * sin(PI * float(k) * t))
		total += prev.distance_to(q) if i > 1 else q.length()
		prev = q
	return total


static func _trazar_camino(m: Dictionary, b: Dictionary) -> Dictionary:
	var puerta_m: Vector2 = _puerta(m, b["pos"], 110.0)
	var puerta_b: Vector2 = _puerta(b, m["pos"], 110.0)
	var h_m: float = m["base"]
	var h_b: float = b["base"]
	var largo: float = puerta_m.distance_to(puerta_b)
	var dir: Vector2 = (puerta_b - puerta_m) / maxf(largo, 1.0)
	var nor: Vector2 = Vector2(-dir.y, dir.x)
	var sid: int = int(m["ci"]) * 1009 + int(m["cj"])
	var amp: float = 70.0 + 70.0 * _f(sid, 51, 1)
	var necesario: float = absf(h_m - h_b) / 0.08
	var k: int = 1
	while k < 40 and _longitud_curva(largo, amp, k) < necesario:
		k += 1
	var arco: float = _longitud_curva(largo, amp, k)
	var n: int = maxi(12, int(arco / 10.0))
	var pts: PackedVector2Array = PackedVector2Array()
	var hs: PackedFloat32Array = PackedFloat32Array()
	pts.append(_puerta(m, b["pos"], 0.0))
	hs.append(h_m)
	var recorrido: Array = []
	var acumulado: float = 0.0
	var anterior: Vector2 = Vector2.ZERO
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		var q: Vector2 = puerta_m + dir * (largo * t) + nor * (amp * sin(PI * float(k) * t))
		if i > 0:
			acumulado += q.distance_to(anterior)
		anterior = q
		recorrido.append([q, acumulado])
	for r in recorrido:
		var f: float = float(r[1]) / maxf(acumulado, 1.0)
		pts.append(r[0])
		hs.append(lerpf(h_m, h_b, f))
	pts.append(_puerta(b, m["pos"], 0.0))
	hs.append(h_b)
	var segs: Array = []
	var rect: Rect2 = Rect2(pts[0], Vector2.ZERO)
	for i in pts.size():
		rect = rect.expand(pts[i])
		if i > 0:
			segs.append([pts[i - 1], pts[i], CALLE_ANCHO, 2])
	return {"camino": true, "pts": pts, "hs": hs, "rect": rect.grow(30.0), "segs": segs, "base": hs[0]}


# Quitamiedos: poste cada punto (~10 m) y una barra entre postes, solo en el lado donde el terreno
# cae más de 1,5 m a 9 m de la carretera. Los puntos de un tramo los pone el trozo que los contiene.
static func _quitamiedos(mb: ConstructorMalla, rect: Rect2, lista: Array) -> void:
	var metal: Color = Color(0.7, 0.72, 0.74)
	var poste: Color = Color(0.35, 0.36, 0.38)
	for c in lista:
		if not c.has("camino"):
			continue
		var pts: PackedVector2Array = c["pts"]
		for i in range(1, pts.size() - 2):
			var a: Vector2 = pts[i]
			if not rect.has_point(a):
				continue
			var b: Vector2 = pts[i + 1]
			var dir: Vector2 = (b - a).normalized()
			var nor: Vector2 = Vector2(-dir.y, dir.x)
			var dentro: float = CALLE_ANCHO / 2.0 + 0.4
			for lado in [-1.0, 1.0]:
				var ya: float = altura_lista(a.x, a.y, lista)
				var fuera: Vector2 = a + nor * lado * 9.0
				if altura_lista(fuera.x, fuera.y, lista) > ya - 1.5:
					continue
				var pa: Vector2 = a + nor * lado * dentro
				var pb: Vector2 = b + nor * lado * dentro
				var yb: float = altura_lista(b.x, b.y, lista)
				mb.caja(Vector3(pa.x, ya + 0.45, pa.y), Vector3(0.14, 0.9, 0.14), poste)
				mb.cuadro(Vector3(pa.x, ya + 0.5, pa.y), Vector3(pb.x, yb + 0.5, pb.y),
						Vector3(pb.x, yb + 0.85, pb.y), Vector3(pa.x, ya + 0.85, pa.y), metal)
				mb.cuadro(Vector3(pa.x, ya + 0.85, pa.y), Vector3(pb.x, yb + 0.85, pb.y),
						Vector3(pb.x, yb + 0.5, pb.y), Vector3(pa.x, ya + 0.5, pa.y), metal)


# Carreteras de montaña: señales de curva y de velocidad, puentes (donde el terreno cae a los dos
# lados) y bocas de túnel (donde la carretera va encajonada entre dos laderas). Todo con cajas.
static func _senales_y_obras(mb: ConstructorMalla, rect: Rect2, lista: Array) -> void:
	var poste: Color = Color(0.35, 0.36, 0.38)
	var piedra: Color = Color(0.5, 0.49, 0.47)
	var hormigon: Color = Color(0.62, 0.62, 0.6)
	for c in lista:
		if not c.has("camino"):
			continue
		var pts: PackedVector2Array = c["pts"]
		var ultimo_tunel: int = -100
		var ultimo_puente: int = -100
		for i in range(2, pts.size() - 3):
			var a: Vector2 = pts[i]
			if not rect.has_point(a):
				continue
			var d0: Vector2 = (pts[i] - pts[i - 1]).normalized()
			var d1: Vector2 = (pts[i + 1] - pts[i]).normalized()
			var nor: Vector2 = Vector2(-d1.y, d1.x)
			var ya: float = altura_lista(a.x, a.y, lista)
			var giro: float = d0.cross(d1)   # >0 / <0: curva a un lado u otro.
			var medio: float = CALLE_ANCHO / 2.0
			# Señal de curva peligrosa (rombo amarillo) en el exterior, una de cada pocas curvas cerradas.
			if absf(giro) > 0.22 and i % 4 == 0:
				var lado: float = -signf(giro)
				obras_vistas.append(["curva", Vector3(a.x, ya, a.y), d1])
				var q: Vector2 = a + nor * lado * (medio + 1.2)
				mb.caja(Vector3(q.x, ya + 1.1, q.y), Vector3(0.1, 2.2, 0.1), poste)
				mb.caja(Vector3(q.x, ya + 2.4, q.y), Vector3(0.9, 0.9, 0.08), Color(1.0, 0.8, 0.1))
				mb.caja(Vector3(q.x, ya + 2.4, q.y), Vector3(0.5, 0.5, 0.1), Color(0.1, 0.1, 0.1))
			# Límite de velocidad cada ~250 m, a la derecha según se avanza.
			elif i % 25 == 0:
				var q2: Vector2 = a - nor * (medio + 1.2)
				mb.caja(Vector3(q2.x, ya + 1.1, q2.y), Vector3(0.1, 2.2, 0.1), poste)
				mb.caja(Vector3(q2.x, ya + 2.4, q2.y), Vector3(0.85, 0.85, 0.08), Color(0.85, 0.1, 0.1))
				mb.caja(Vector3(q2.x, ya + 2.4, q2.y), Vector3(0.6, 0.6, 0.1), Color(0.95, 0.95, 0.95))
			var izq: Vector2 = a + nor * 8.0
			var der: Vector2 = a - nor * 8.0
			var hi: float = altura_lista(izq.x, izq.y, lista)
			var hd: float = altura_lista(der.x, der.y, lista)
			# Puente: la tierra cae más de 4 m a los dos lados.
			if hi < ya - 2.2 and hd < ya - 2.2 and i - ultimo_puente > 6 and absf(giro) < 0.2:
				ultimo_puente = i
				obras_vistas.append(["puente", Vector3(a.x, ya, a.y), d1])
				var largo: float = a.distance_to(pts[i + 1]) + 0.6
				var cx: Vector2 = (a + pts[i + 1]) / 2.0
				var cubierta: Vector3 = Vector3(largo + 1.0, 0.9, CALLE_ANCHO + 1.2) if absf(d1.x) > absf(d1.y) 						else Vector3(CALLE_ANCHO + 1.2, 0.9, largo + 1.0)
				mb.caja(Vector3(cx.x, ya - 0.5, cx.y), cubierta, hormigon)
				for lado2 in [-1.0, 1.0]:
					var pp: Vector2 = cx + nor * lado2 * (medio - 0.8)
					var suelo: float = minf(altura_lista(pp.x, pp.y, lista), ya - 1.0)
					mb.caja(Vector3(pp.x, (ya - 0.9 + suelo) / 2.0, pp.y), Vector3(1.0, ya - 0.9 - suelo, 1.0), hormigon.darkened(0.15))
			# Túnel: laderas altas a los dos lados. La galería cubierta rodea la carretera y, en la entrada
			# y la salida, lleva un portal de piedra con dintel.
			if _es_tramo_tunel(pts, i, lista):
				_galeria(mb, a, pts[i + 1], medio, ya, altura_lista(pts[i + 1].x, pts[i + 1].y, lista))
				if not _es_tramo_tunel(pts, i - 1, lista):
					_portal(mb, a, nor, d1, medio, ya)
					obras_vistas.append(["tunel", Vector3(a.x, ya, a.y), d1])
				if not _es_tramo_tunel(pts, i + 1, lista):
					_portal(mb, pts[i + 1], nor, d1, medio, altura_lista(pts[i + 1].x, pts[i + 1].y, lista))


# ¿El tramo i->i+1 de una carretera de montaña va encajonado entre dos laderas altas y casi recto?
static func _es_tramo_tunel(pts: PackedVector2Array, i: int, lista: Array) -> bool:
	if i < 2 or i >= pts.size() - 3:
		return false
	var a: Vector2 = pts[i]
	var d0: Vector2 = (pts[i] - pts[i - 1]).normalized()
	var d1: Vector2 = (pts[i + 1] - pts[i]).normalized()
	if absf(d0.cross(d1)) > 0.15:
		return false
	var nor: Vector2 = Vector2(-d1.y, d1.x)
	var ya: float = altura_lista(a.x, a.y, lista)
	var izq: Vector2 = a + nor * 8.0
	var der: Vector2 = a - nor * 8.0
	return altura_lista(izq.x, izq.y, lista) > ya + 3.0 and altura_lista(der.x, der.y, lista) > ya + 3.0


# Paredes y techo de la galería de un tramo (a doble cara, para verse y chocar desde dentro y desde fuera).
static func _galeria(mb: ConstructorMalla, a: Vector2, b: Vector2, medio: float, ya: float, yb: float) -> void:
	var dir: Vector2 = (b - a).normalized()
	var nor: Vector2 = Vector2(-dir.y, dir.x)
	var ancho: float = medio + 0.6
	var alto: float = 6.2
	var roca: Color = Color(0.46, 0.44, 0.42)
	var techo: Color = Color(0.3, 0.29, 0.28)
	var lampara: Color = Color(1.0, 0.9, 0.6)
	for lado in [-1.0, 1.0]:
		var pa: Vector2 = a + nor * lado * ancho
		var pb: Vector2 = b + nor * lado * ancho
		_losa(mb, Vector3(pa.x, ya, pa.y), Vector3(pb.x, yb, pb.y), Vector3(pb.x, yb + alto, pb.y), Vector3(pa.x, ya + alto, pa.y), roca)
	var i0: Vector2 = a + nor * ancho
	var i1: Vector2 = a - nor * ancho
	var j0: Vector2 = b + nor * ancho
	var j1: Vector2 = b - nor * ancho
	_losa(mb, Vector3(i0.x, ya + alto, i0.y), Vector3(j0.x, yb + alto, j0.y), Vector3(j1.x, yb + alto, j1.y), Vector3(i1.x, ya + alto, i1.y), techo)
	var c: Vector2 = (a + b) / 2.0
	mb.caja(Vector3(c.x, (ya + yb) / 2.0 + alto - 0.1, c.y), Vector3(0.5, 0.2, 0.5), lampara)   # Lámpara del techo.


static func _losa(mb: ConstructorMalla, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col: Color) -> void:
	mb.cuadro(p0, p1, p2, p3, col)
	mb.cuadro(p3, p2, p1, p0, col)


static func _portal(mb: ConstructorMalla, a: Vector2, nor: Vector2, d1: Vector2, medio: float, ya: float) -> void:
	var piedra: Color = Color(0.5, 0.49, 0.47)
	for lado in [-1.0, 1.0]:
		var pl: Vector2 = a + nor * lado * (medio + 0.9)
		mb.caja(Vector3(pl.x, ya + 3.4, pl.y), Vector3(1.4, 6.8, 1.4), piedra)
	mb.caja(Vector3(a.x, ya + 7.0, a.y), Vector3(1.4, 1.4, CALLE_ANCHO + 3.4) if absf(d1.x) > absf(d1.y) 			else Vector3(CALLE_ANCHO + 3.4, 1.4, 1.4), piedra.darkened(0.1))


# Parte del segmento a-b que cae dentro del rectángulo, como (t0, t1) entre 0 y 1.
# Devuelve (-1, -1) si no entra.
static func _recortar(a: Vector2, b: Vector2, r: Rect2) -> Vector2:
	var t0: float = 0.0
	var t1: float = 1.0
	var d: Vector2 = b - a
	var p: Array = [-d.x, d.x, -d.y, d.y]
	var q: Array = [a.x - r.position.x, r.end.x - a.x, a.y - r.position.y, r.end.y - a.y]
	for i in 4:
		var pi: float = p[i]
		var qi: float = q[i]
		if absf(pi) < 0.000001:
			if qi < 0.0:
				return Vector2(-1.0, -1.0)
		else:
			var t: float = qi / pi
			if pi < 0.0:
				if t > t1:
					return Vector2(-1.0, -1.0)
				t0 = maxf(t0, t)
			else:
				if t < t1:
					t1 = t
				if t1 < t0:
					return Vector2(-1.0, -1.0)
	return Vector2(t0, t1)


static func _distancia_a_carreteras(p: Vector2, segs: Array, margen: float) -> bool:
	for sg in segs:
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, sg[0], sg[1])
		if q.distance_to(p) < float(sg[2]) * 0.5 + margen:
			return true
	return false


# Dibuja las carreteras que caen en "rect" como tiras que siguen el terreno.
static func _dibujar_carreteras(mb: ConstructorMalla, segs: Array, rect: Rect2, paso: float,
		lista: Array, subir: float, ensanchar: float) -> void:
	for sg in segs:
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var ancho: float = float(sg[2]) + ensanchar
		var tr: Vector2 = _recortar(a, b, rect)
		if tr.x < 0.0 or tr.y - tr.x < 0.0001:
			continue
		var largo: float = (b - a).length() * (tr.y - tr.x)
		var pasos: int = maxi(1, ceili(largo / paso))
		var dir: Vector2 = (b - a).normalized()
		var lado: Vector2 = Vector2(-dir.y, dir.x) * ancho * 0.5
		var col: Color = Color(0.17, 0.17, 0.19) if int(sg[3]) == 0 else Color(0.26, 0.24, 0.21)
		if int(sg[3]) == 2:
			col = Color(0.2, 0.2, 0.23)   # Carretera de montaña asfaltada.
		var prev_i: Vector3 = Vector3.ZERO
		var prev_d: Vector3 = Vector3.ZERO
		for j in range(pasos + 1):
			var pt: Vector2 = a.lerp(b, lerpf(tr.x, tr.y, float(j) / float(pasos)))
			var pi: Vector2 = pt - lado
			var pd: Vector2 = pt + lado
			var vi: Vector3 = Vector3(pi.x, altura_lista(pi.x, pi.y, lista) + subir, pi.y)
			var vd: Vector3 = Vector3(pd.x, altura_lista(pd.x, pd.y, lista) + subir, pd.y)
			if j > 0:
				mb.tira(prev_i, prev_d, vi, vd, col)
			prev_i = vi
			prev_d = vd


# --------------------------------- distritos ----------------------------------
# Cada bloque (k, l) de una ciudad o pueblo pertenece a un distrito. El distrito cambia el
# aspecto de las casas, el precio de las propiedades (prestigio) y cuánta vigilancia hay.
#   centro: el corazón del asentamiento (más alto y claro)
#   rico: barrio alto de la ciudad (casas grandes, caras)
#   industrial: almacenes bajos y oscuros (baratos)
#   residencial: el resto
const DISTRITOS: Dictionary = {
	"centro": {"nombre": "Centro", "prestigio": 1.5, "vigilancia": 1.3},
	"rico": {"nombre": "Barrio alto", "prestigio": 2.2, "vigilancia": 1.6},
	"residencial": {"nombre": "Barrio residencial", "prestigio": 1.0, "vigilancia": 1.0},
	"industrial": {"nombre": "Zona industrial", "prestigio": 0.7, "vigilancia": 0.7},
}

# Servicios de la ciudad (edificios con letrero y un uso con la tecla E). Posición: bloque (k, l).
# Una ciudad tiene banco, taberna, hospital, taller y gasolinera; un pueblo, gasolinera y taberna.
const SERVICIOS_CIUDAD: Dictionary = {Vector2i(1, 1): "banco", Vector2i(-2, -1): "taberna",
		Vector2i(2, -3): "hospital", Vector2i(-3, 2): "taller", Vector2i(2, 1): "gasolinera"}
const SERVICIOS_PUEBLO: Dictionary = {Vector2i(1, -1): "gasolinera", Vector2i(-2, 0): "taberna"}
const COLOR_SERVICIO: Dictionary = {"banco": Color(0.7, 0.62, 0.35), "taberna": Color(0.5, 0.3, 0.18),
		"hospital": Color(0.88, 0.88, 0.86), "taller": Color(0.3, 0.32, 0.36), "gasolinera": Color(0.85, 0.85, 0.8)}
const NOMBRE_SERVICIO: Dictionary = {"banco": "BANCO", "taberna": "TABERNA", "hospital": "HOSPITAL",
		"taller": "TALLER", "gasolinera": "GASOLINERA"}


static func servicio_de(s: Dictionary, k: int, l: int) -> String:
	var tipo: int = s["tipo"]
	if tipo == 2:
		return str(SERVICIOS_CIUDAD.get(Vector2i(k, l), ""))
	if tipo == 1:
		return str(SERVICIOS_PUEBLO.get(Vector2i(k, l), ""))
	return ""


static func distrito_de(s: Dictionary, k: int, l: int) -> String:
	var tipo: int = s["tipo"]
	var dx: float = k + 0.5
	var dz: float = l + 0.5
	var cerca: float = maxf(absf(dx), absf(dz))
	if tipo == 2:
		if cerca < 2.0:
			return "centro"
		if dx > 0.0 and dz < 0.0:
			return "rico"
		if dx < 0.0 and dz > 0.0:
			return "industrial"
		return "residencial"
	if tipo == 1 and cerca < 1.0:
		return "centro"
	return "residencial"


# El distrito en el punto (x, z) del mundo: {id, nombre, prestigio, vigilancia, lugar} o {} si
# estás en el campo (o en la ciudad original, que no tiene distritos de este tipo).
static func distrito_en(x: float, z: float) -> Dictionary:
	var punto: Vector2 = Vector2(x, z)
	if nucleo.has_point(punto):
		return {"id": "ciudad", "nombre": "Ciudad original", "prestigio": 1.0, "vigilancia": 1.2, "lugar": ""}
	for s in asentamientos_cerca(Rect2(x - 2.0, z - 2.0, 4.0, 4.0)):
		var p: Vector2 = s["pos"]
		var m: float = s["mitad"]
		if absf(x - p.x) > m or absf(z - p.y) > m:
			continue
		var k: int = floori((x - p.x) / BLOQUE)
		var l: int = floori((z - p.y) / BLOQUE)
		var id: String = distrito_de(s, k, l)
		var d: Dictionary = (DISTRITOS[id] as Dictionary).duplicate()
		d["id"] = id
		d["lugar"] = "%s %s" % [nombre_tipo(int(s["tipo"])), s["nombre"]]
		d["nombre"] = "%s (%s)" % [d["nombre"], s["nombre"]]
		return d
	return {}


# Coordenadas y dibujo de un edificio de servicio (ocupa el solar 0 del bloque; el resto queda libre).
static func _servicio_edificio(s: Dictionary, k: int, l: int, serv: String) -> Dictionary:
	var p: Vector2 = s["pos"]
	var bx: float = p.x + k * BLOQUE + CALLE_ANCHO / 2.0
	var bz: float = p.y + l * BLOQUE + CALLE_ANCHO / 2.0
	var ancho: float = 18.0
	var fondo: float = 12.0
	var pisos: int = 1
	var cz: float = bz + 14.0
	match serv:
		"banco":
			ancho = 20.0
			pisos = 2
		"hospital":
			ancho = 22.0
			fondo = 14.0
			pisos = 3
		"taberna":
			ancho = 16.0
			fondo = 11.0
		"taller":
			ancho = 20.0
			fondo = 14.0
		"gasolinera":
			ancho = 8.0
			fondo = 6.0
			cz = bz + 8.0
	return {"x": bx + 18.0, "z": cz, "y": s["base"], "w": ancho, "d": fondo, "pisos": pisos,
			"alto": pisos * 3.2 + (0.8 if serv == "gasolinera" else 0.0), "puerta": 1, "plano": true,
			"color": COLOR_SERVICIO[serv], "techo": Color(0.25, 0.25, 0.28), "id": "", "servicio": serv}


# ---------------------------------- casas -------------------------------------

# La casa del solar "sub" (0-3) del bloque (k, l) de un asentamiento, o {} si ahí no hay.
static func casa(s: Dictionary, k: int, l: int, sub: int) -> Dictionary:
	var n: int = s["n"]
	var tipo: int = s["tipo"]
	if tipo == 2 and k >= -1 and k <= 0 and l >= -1 and l <= 0:
		return {}   # La plaza mayor de la ciudad queda libre.
	var serv: String = servicio_de(s, k, l)
	if serv != "":
		return _servicio_edificio(s, k, l, serv) if sub == 0 else {}
	var sid: int = int(s["ci"]) * 1009 + int(s["cj"])
	var clave: int = k * 101 + l
	var est: Dictionary = estilo_de(sid)
	if es_parque(s, k, l):
		return {}
	var vacio: float = float(est["vacio"]) * (1.0 if tipo == 0 else 0.7)
	if _f(sid, clave + 7919, sub * 16) < vacio:
		return {}
	var p: Vector2 = s["pos"]
	var a: int = sub % 2
	var b: int = sub / 2
	var r1: float = _f(sid, clave, sub * 16 + 1)
	var r2: float = _f(sid, clave, sub * 16 + 2)
	var ancho: float = clampf((7.0 + 8.5 * pow(r1, 1.4)) * float(est["ancho"]), 6.0, 15.5)
	var fondo: float = clampf(7.0 + 8.0 * pow(r2, 1.2), 6.5, 15.5)
	var r: float = _f(sid, clave, sub * 16 + 5)
	var pisos: int = 1 + int(r * 2.0)
	if tipo == 2:
		var cerca: float = maxf(absf(k + 0.5), absf(l + 0.5))
		pisos = 1 + int(r * 3.0) + (2 if cerca < 2.0 else 0)
	var distrito: String = distrito_de(s, k, l)
	if distrito == "rico":
		ancho = minf(ancho + 2.0, 15.5)
		fondo = minf(fondo + 1.0, 15.5)
		pisos = maxi(2, pisos)
	elif distrito == "industrial":
		pisos = 1
		ancho = minf(ancho + 2.0, 15.5)
	# La casa se mueve dentro de su solar de 18 m (más holgura cuanto más pequeña).
	var holgura_x: float = maxf(0.0, (18.0 - ancho) / 2.0 - 0.4)
	var holgura_z: float = maxf(0.0, (18.0 - fondo) / 2.0 - 0.4)
	var cx: float = p.x + k * BLOQUE + CALLE_ANCHO / 2.0 + a * 18.0 + 9.0 + (_f(sid, clave, sub * 16 + 3) * 2.0 - 1.0) * holgura_x
	var cz: float = p.y + l * BLOQUE + CALLE_ANCHO / 2.0 + b * 18.0 + 9.0 + (_f(sid, clave, sub * 16 + 4) * 2.0 - 1.0) * holgura_z
	var v: int = _h(sid, clave, sub * 16 + 9)
	var paredes: Array = est["paredes"]
	var techos: Array = est["techos"]
	var pared: Color = _variar(paredes[_h(sid, clave, sub * 16 + 6) % paredes.size()], sid, clave, sub * 16 + 10)
	var techo: Color = _variar(techos[_h(sid, clave, sub * 16 + 7) % techos.size()], sid, clave, sub * 16 + 11)
	var plano: bool = pisos > 3 or _f(sid, clave, sub * 16 + 12) < float(est["plano"])
	var c: Dictionary = {"x": cx, "z": cz, "y": s["base"], "w": ancho, "d": fondo, "pisos": pisos,
			"alto": pisos * (3.0 + _f(sid, clave, sub * 16 + 13) * 0.5), "puerta": -1 if b == 0 else 1, "plano": plano,
			"color": pared, "techo": techo, "id": "", "pitch": float(est["pitch"]) * (0.8 + _f(sid, clave, sub * 16 + 14) * 0.5),
			"var": v}
	if distrito == "industrial":
		c["color"] = (c["color"] as Color).darkened(0.35)
	elif distrito == "rico":
		c["color"] = (c["color"] as Color).lightened(0.18)
	c["distrito"] = distrito
	var prob_alquiler: float = [0.14, 0.1, 0.07][tipo]
	if _f(sid, clave + 31, sub * 16 + 8) < prob_alquiler:
		c["id"] = "w_c_%d_%d_%d_%d_%d" % [s["ci"], s["cj"], k, l, sub]
	return c


# Bloques que son parque o plaza (sin casas): rompen la cuadrícula. No en el centro ni con servicios.
static func es_parque(s: Dictionary, k: int, l: int) -> bool:
	var tipo: int = s["tipo"]
	if tipo == 0 or servicio_de(s, k, l) != "":
		return false
	if distrito_de(s, k, l) == "centro":
		return false
	var sid: int = int(s["ci"]) * 1009 + int(s["cj"])
	return _f(sid, k * 101 + l, 77) < 0.08


static func _casas_en(s: Dictionary, rect: Rect2) -> Array:
	var out: Array = []
	var n: int = s["n"]
	var p: Vector2 = s["pos"]
	for k in range(-n, n):
		for l in range(-n, n):
			var bloque: Rect2 = Rect2(p.x + k * BLOQUE + CALLE_ANCHO / 2.0, p.y + l * BLOQUE + CALLE_ANCHO / 2.0, 36.0, 36.0)
			if not bloque.intersects(rect):
				continue
			for sub in 4:
				var c: Dictionary = casa(s, k, l, sub)
				if not c.is_empty() and rect.has_point(Vector2(c["x"], c["z"])):
					out.append(c)
	return out


# Huertos de un asentamiento (4 lados, varios por lado), sin los que estorban a una carretera.
static func huertos_de(s: Dictionary) -> Array:
	var out: Array = []
	var p: Vector2 = s["pos"]
	var m: float = s["mitad"]
	var cnt: int = clampi(int(s["n"]) * 2, 2, 6)
	var paso: float = 2.0 * m / float(cnt)
	var sid: int = int(s["ci"]) * 1009 + int(s["cj"])
	var vias: Array = []
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var t: Dictionary = asentamiento(int(s["ci"]) + d.x, int(s["cj"]) + d.y)
		if not t.is_empty():
			vias.append_array(_conexion(s, t))
	for c in conectores:
		if c["ci"] == s["ci"] and c["cj"] == s["cj"]:
			vias.append_array(c["segs"])
	for lado in 4:
		for slot in cnt:
			var idn: int = lado * 10 + slot
			var along: float = (slot + 0.5 - cnt / 2.0) * paso
			var w: float = 20.0 + 16.0 * _f(sid, 900 + idn, 1)
			var dp: float = 18.0 + 14.0 * _f(sid, 900 + idn, 2)
			var off: float = m + 75.0
			var ctr: Vector2
			var ex: float = w
			var ez: float = dp
			var puerta: Vector2
			var frente: Vector2
			if lado == 0:
				ctr = Vector2(p.x + along, p.y - off)
				puerta = Vector2(ctr.x, ctr.y + ez / 2.0)
				frente = Vector2(0, 1)
			elif lado == 1:
				ctr = Vector2(p.x + along, p.y + off)
				puerta = Vector2(ctr.x, ctr.y - ez / 2.0)
				frente = Vector2(0, -1)
			elif lado == 2:
				ctr = Vector2(p.x - off, p.y + along)
				ex = dp
				ez = w
				puerta = Vector2(ctr.x + ex / 2.0, ctr.y)
				frente = Vector2(1, 0)
			else:
				ctr = Vector2(p.x + off, p.y + along)
				ex = dp
				ez = w
				puerta = Vector2(ctr.x - ex / 2.0, ctr.y)
				frente = Vector2(-1, 0)
			var hueco: float = maxf(ex, ez) / 2.0 + 8.0
			if _distancia_a_carreteras(ctr, vias, hueco):
				continue
			out.append({"id": "w_h_%d_%d_%d" % [s["ci"], s["cj"], idn], "ctr": ctr, "ex": ex, "ez": ez,
					"puerta": puerta, "frente": frente, "y": s["base"], "m2": int(ex * ez)})
	return out


# Versión de la distribución del mundo. La 2 es la de las ciudades vivas (celdas de 700 m): las
# partidas guardadas sin este número usan ids de propiedad de la distribución antigua (celdas de 1200 m).
const VERSION_MUNDO: int = 2


# Traduce el id de una casa o huerto de la distribución antigua a uno equivalente del mundo actual:
# el mismo tipo (casa/huerto), en el asentamiento más cercano al sitio donde estaba antes, y que no
# esté ya en "usados" (ids ya repartidos). Así nadie pierde lo que alquiló o compró al mover los pueblos.
# Devuelve "" si no es un id del mundo o si el mundo aún no está listo.
static func migrar_id(id: String, usados: Dictionary) -> String:
	if not listo:
		return ""
	var partes: PackedStringArray = id.split("_")
	if partes.size() < 5 or partes[0] != "w" or not (partes[1] == "c" or partes[1] == "h"):
		return ""
	var ci: int = int(partes[2])
	var cj: int = int(partes[3])
	var antes: Vector2 = Vector2((ci + 0.5) * 1200.0 + (_f(ci, cj, 2) - 0.5) * 500.0,
			(cj + 0.5) * 1200.0 + (_f(ci, cj, 3) - 0.5) * 500.0)
	var lista: Array = _asentamientos.values()
	lista.sort_custom(func(a, b): return (a["pos"] as Vector2).distance_squared_to(antes) < (b["pos"] as Vector2).distance_squared_to(antes))
	for s in lista:
		for cand in _alquilables(s, partes[1] == "h"):
			if not usados.has(cand):
				return cand
	return ""


# Ids de las casas en alquiler/venta (o de los huertos) de un asentamiento.
static func _alquilables(s: Dictionary, huertos: bool) -> Array:
	var out: Array = []
	if huertos:
		for h in huertos_de(s):
			out.append(h["id"])
		return out
	var n: int = s["n"]
	for k in range(-n, n):
		for l in range(-n, n):
			for sub in 4:
				var c: Dictionary = casa(s, k, l, sub)
				if not c.is_empty() and str(c["id"]) != "":
					out.append(c["id"])
	return out


# La ficha de una propiedad del mundo a partir de su id ("w_c_..." casa, "w_h_..." huerto).
# Devuelve {} si el id no existe en este mundo.
static func propiedad(id: String) -> Dictionary:
	if not listo:
		return {}
	var partes: PackedStringArray = id.split("_")
	if partes.size() < 5 or partes[0] != "w":
		return {}
	var s: Dictionary = asentamiento(int(partes[2]), int(partes[3]))
	if s.is_empty():
		return {}
	var lugar: String = "%s %s" % [nombre_tipo(int(s["tipo"])), s["nombre"]]
	if partes[1] == "c" and partes.size() == 7:
		var c: Dictionary = casa(s, int(partes[4]), int(partes[5]), int(partes[6]))
		if c.is_empty():
			return {}
		var m2: int = int(float(c["w"]) * float(c["d"]) * int(c["pisos"]))
		var mult: float = [1.0, 1.3, 1.7][int(s["tipo"])]
		mult *= float(DISTRITOS[distrito_de(s, int(partes[4]), int(partes[5]))]["prestigio"])   # El distrito encarece o abarata.
		return {"id": id, "tipo": "casa", "nombre": "Casa de %d m² (%s)" % [m2, lugar], "m2": m2,
				"alquiler": int((40.0 + m2 * 0.9) * mult), "lugar": s["nombre"],
				"pos": Vector3(c["x"], c["y"], c["z"])}
	if partes[1] == "h" and partes.size() == 5:
		var idn: int = int(partes[4])
		for h in huertos_de(s):
			if h["id"] == id:
				var ctr: Vector2 = h["ctr"]
				return {"id": id, "tipo": "huerto", "nombre": "Huerto de %d m² (%s)" % [h["m2"], lugar],
						"m2": h["m2"], "alquiler": int(h["m2"] * 0.35) + 30, "lugar": s["nombre"],
						"pos": Vector3(ctr.x, h["y"], ctr.y)}
		return {}
	return {}


# Sitio donde está una propiedad (para el mapa y para avisar de lo lejos que queda).
static func posicion_de(id: String) -> Vector3:
	var p: Dictionary = propiedad(id)
	return p["pos"] if not p.is_empty() else Vector3.ZERO


# ------------------------------- trozos cercanos ------------------------------

static func _cuadricula(x0: float, z0: float, celdas: int, paso: float, lista: Array) -> PackedFloat32Array:
	var n: int = celdas + 3
	var g: PackedFloat32Array = PackedFloat32Array()
	g.resize(n * n)
	for j in n:
		for i in n:
			g[i + j * n] = altura_lista(x0 + (i - 1) * paso, z0 + (j - 1) * paso, lista)
	return g


# Devuelve {"arrays": [...], "caras": PackedVector3Array}.
static func _terreno(x0: float, z0: float, celdas: int, paso: float, g: PackedFloat32Array) -> Dictionary:
	var n: int = celdas + 3
	var nv: int = celdas + 1
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var cols: PackedColorArray = PackedColorArray()
	verts.resize(nv * nv)
	norms.resize(nv * nv)
	cols.resize(nv * nv)
	for j in nv:
		for i in nv:
			var gi: int = (i + 1) + (j + 1) * n
			var h: float = g[gi]
			var dhdx: float = (g[gi + 1] - g[gi - 1]) / (2.0 * paso)
			var dhdz: float = (g[gi + n] - g[gi - n]) / (2.0 * paso)
			var nor: Vector3 = Vector3(-dhdx, 1.0, -dhdz).normalized()
			var x: float = x0 + i * paso
			var z: float = z0 + j * paso
			verts[i + j * nv] = Vector3(x, h, z)
			norms[i + j * nv] = nor
			cols[i + j * nv] = _color_suelo(x, z, h, nor.y)
	var idx: PackedInt32Array = PackedInt32Array()
	idx.resize(celdas * celdas * 6)
	var q: int = 0
	for j in celdas:
		for i in celdas:
			var a: int = i + j * nv
			var b: int = a + 1
			var c: int = a + nv
			var d: int = c + 1
			idx[q] = a
			idx[q + 1] = b
			idx[q + 2] = d
			idx[q + 3] = a
			idx[q + 4] = d
			idx[q + 5] = c
			q += 6
	var caras: PackedVector3Array = PackedVector3Array()
	caras.resize(idx.size())
	for t in idx.size():
		caras[t] = verts[idx[t]]
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	return {"arrays": arrays, "caras": caras}


# Una casa completa: paredes, ventanas, puerta y techo (con cartel verde si se alquila).
static func _edificio(mb: ConstructorMalla, c: Dictionary, detalle: bool) -> void:
	var y: float = c["y"]
	var w: float = c["w"]
	var d: float = c["d"]
	var alto: float = c["alto"]
	var centro: Vector3 = Vector3(c["x"], y + alto / 2.0 - 0.2, c["z"])
	var hueca: bool = detalle and str(c["id"]) != ""   # Las casas en alquiler o venta tienen interior.
	if hueca:
		_paredes_con_interior(mb, c)
	else:
		mb.caja(centro, Vector3(w, alto + 0.4, d), c["color"])
	if bool(c["plano"]):
		mb.caja(Vector3(c["x"], y + alto + 0.2, c["z"]), Vector3(w + 0.4, 0.4, d + 0.4), (c["techo"] as Color).darkened(0.2))
	else:
		mb.techo(Vector3(c["x"], y + alto, c["z"]), w + 0.8, d + 0.8, float(c.get("pitch", 2.2)), c["techo"])
	if not detalle:
		return
	_extras_casa(mb, c)
	var cara: float = float(c["puerta"])
	var zf: float = c["z"] + cara * (d / 2.0 + 0.04)
	if not hueca:
		var puertas: Array = [Color(0.25, 0.15, 0.1), Color(0.15, 0.25, 0.2), Color(0.4, 0.12, 0.1), Color(0.18, 0.2, 0.3)]
		mb.caja(Vector3(c["x"], y + 1.05, zf), Vector3(1.1, 2.1, 0.1), puertas[(int(c.get("var", 0)) / 7) % 4])
	var vent: Color = [Color(0.12, 0.17, 0.26), Color(0.16, 0.2, 0.2), Color(0.2, 0.17, 0.12)][int(c.get("var", 0)) % 3]
	for piso in int(c["pisos"]):
		for lado in [-1.0, 1.0]:
			for pared in [1.0, -1.0]:
				var vx: float = c["x"] + lado * w * 0.27
				var vz: float = c["z"] + pared * (d / 2.0 + 0.04)
				if piso == 0 and pared == cara:
					vx = c["x"] + lado * w * 0.36   # La puerta ocupa el centro.
				mb.caja(Vector3(vx, y + 1.6 + piso * 3.2, vz), Vector3(1.0, 1.2, 0.08), vent)
	if str(c["id"]) != "":
		mb.caja(Vector3(c["x"], y + 2.9, zf + cara * 0.04), Vector3(1.6, 0.5, 0.08), Color(0.2, 0.65, 0.3))
	if c.has("servicio"):
		_decorar_servicio(mb, c)


# Detalles que cambian de una casa a otra: chimenea, porche, anexo trasero y torrecilla.
static func _extras_casa(mb: ConstructorMalla, c: Dictionary) -> void:
	if c.has("servicio"):
		return
	var v: int = int(c.get("var", 0))
	var y: float = c["y"]
	var x: float = c["x"]
	var z: float = c["z"]
	var w: float = c["w"]
	var d: float = c["d"]
	var alto: float = c["alto"]
	var cara: float = float(c["puerta"])
	var piedra: Color = (c["color"] as Color).darkened(0.3)
	if v % 3 == 0 and not bool(c["plano"]):   # Chimenea.
		mb.caja(Vector3(x + w * 0.22 * (1.0 if (v / 5) % 2 == 0 else -1.0), y + alto + 1.8, z - cara * d * 0.15),
				Vector3(0.7, 2.2, 0.7), piedra)
	if (v / 3) % 4 == 0:   # Porche sobre la puerta.
		var zp: float = z + cara * (d / 2.0 + 1.0)
		mb.caja(Vector3(x, y + 2.7, zp), Vector3(3.0, 0.18, 2.0), (c["techo"] as Color))
		for sx in [-1.3, 1.3]:
			mb.caja(Vector3(x + sx, y + 1.3, zp + cara * 0.8), Vector3(0.15, 2.6, 0.15), Color(0.35, 0.25, 0.18))
	if (v / 12) % 5 == 0 and d < 12.5:   # Anexo por detrás (cobertizo).
		var za: float = z - cara * (d / 2.0 + 1.2)
		mb.caja(Vector3(x + w * 0.1, y + 1.2, za), Vector3(w * 0.55, 2.4, 2.4), (c["color"] as Color).darkened(0.12))
		mb.caja(Vector3(x + w * 0.1, y + 2.5, za), Vector3(w * 0.55 + 0.4, 0.2, 2.8), (c["techo"] as Color).darkened(0.15))
	if int(c["pisos"]) >= 2 and ((v / 60) % 9 == 0 or str(c.get("distrito", "")) == "rico"):   # Torrecilla en una esquina.
		var sx2: float = 1.0 if (v / 11) % 2 == 0 else -1.0
		mb.caja(Vector3(x + sx2 * (w / 2.0 - 1.4), y + alto + 1.6, z + cara * (d / 2.0 - 1.4)), Vector3(2.4, 3.2, 2.4), c["color"])
		mb.techo(Vector3(x + sx2 * (w / 2.0 - 1.4), y + alto + 3.2, z + cara * (d / 2.0 - 1.4)), 3.0, 3.0, 2.0, c["techo"])


# Franja de color sobre la puerta de un servicio y, en la gasolinera, marquesina con dos surtidores.
static func _decorar_servicio(mb: ConstructorMalla, c: Dictionary) -> void:
	var serv: String = c["servicio"]
	var y: float = c["y"]
	var x: float = c["x"]
	var z: float = c["z"]
	var w: float = c["w"]
	var d: float = c["d"]
	var cara: float = c["puerta"]
	var franjas: Dictionary = {"banco": Color(0.15, 0.45, 0.25), "taberna": Color(0.7, 0.2, 0.15),
			"hospital": Color(0.85, 0.15, 0.15), "taller": Color(0.95, 0.7, 0.1), "gasolinera": Color(0.9, 0.2, 0.1)}
	var franja: Color = franjas[serv]
	mb.caja(Vector3(x, y + 3.4, z + cara * (d / 2.0 + 0.1)), Vector3(minf(w - 2.0, 8.0), 0.9, 0.14), franja)
	if serv == "hospital":
		var zc: float = z + cara * (d / 2.0 + 0.1)
		mb.caja(Vector3(x, y + 6.6, zc), Vector3(3.0, 0.8, 0.14), franja)
		mb.caja(Vector3(x, y + 6.6, zc), Vector3(0.8, 3.0, 0.14), franja)
	if serv == "gasolinera":
		var cz: float = z + cara * (d / 2.0 + 9.0)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				mb.caja(Vector3(x + sx * 6.5, y + 2.3, cz + sz * 3.5), Vector3(0.5, 4.6, 0.5), Color(0.8, 0.8, 0.78))
		mb.caja(Vector3(x, y + 4.8, cz), Vector3(14.5, 0.5, 8.5), franja)
		mb.caja(Vector3(x, y + 0.1, cz), Vector3(10.0, 0.2, 1.4), Color(0.35, 0.35, 0.37))
		for sx in [-2.5, 2.5]:
			mb.caja(Vector3(x + sx, y + 0.95, cz), Vector3(0.8, 1.7, 0.6), Color(0.85, 0.15, 0.12))
			mb.caja(Vector3(x + sx, y + 1.3, cz + 0.32), Vector3(0.5, 0.35, 0.05), Color(0.15, 0.15, 0.18))


# Dónde se usa el servicio (E): en la puerta, o junto a los surtidores en la gasolinera.
static func _punto_servicio(c: Dictionary) -> Vector3:
	var cara: float = c["puerta"]
	var d: float = c["d"]
	if str(c["servicio"]) == "gasolinera":
		return Vector3(c["x"], float(c["y"]) + 1.0, float(c["z"]) + cara * (d / 2.0 + 9.0))
	return Vector3(c["x"], float(c["y"]) + 1.0, float(c["z"]) + cara * (d / 2.0 + 0.5))


# Casa hueca: cuatro muros con un hueco de puerta de 1,3 m, suelo, techo bajo y unos muebles
# (cama y mesa). Si la casa tiene varios pisos, los de arriba son macizos.
static func _paredes_con_interior(mb: ConstructorMalla, c: Dictionary) -> void:
	var x: float = c["x"]
	var z: float = c["z"]
	var y: float = c["y"]
	var w: float = c["w"]
	var d: float = c["d"]
	var alto: float = c["alto"]
	var cara: float = float(c["puerta"])
	var col: Color = c["color"]
	var g: float = 0.3          # Grosor de los muros.
	var hueco: float = 1.3      # Ancho de la puerta.
	var h_muro: float = alto + 0.2
	var yc: float = y + h_muro / 2.0 - 0.1
	# Muro del fondo y muros laterales.
	mb.caja(Vector3(x, yc, z - cara * (d / 2.0 - g / 2.0)), Vector3(w, h_muro, g), col)
	for lado in [-1.0, 1.0]:
		mb.caja(Vector3(x + lado * (w / 2.0 - g / 2.0), yc, z), Vector3(g, h_muro, d), col)
	# Muro del frente partido por la puerta, con dintel encima.
	var zf: float = z + cara * (d / 2.0 - g / 2.0)
	var lado_w: float = (w - g * 2.0 - hueco) / 2.0
	for lado in [-1.0, 1.0]:
		mb.caja(Vector3(x + lado * (hueco / 2.0 + lado_w / 2.0 + g), yc, zf), Vector3(lado_w + 2.0 * g, h_muro, g), col)
	mb.caja(Vector3(x, y + 2.1 + (h_muro - 2.1) / 2.0 - 0.1, zf), Vector3(hueco, h_muro - 2.1, g), col)
	# Suelo y techo de la planta baja; pisos de arriba macizos.
	mb.caja(Vector3(x, y + 0.05, z), Vector3(w - 2.0 * g, 0.1, d - 2.0 * g), Color(0.38, 0.26, 0.16))
	mb.caja(Vector3(x, y + 3.2, z), Vector3(w - 2.0 * g, 0.2, d - 2.0 * g), col.darkened(0.15))
	if int(c["pisos"]) > 1:
		mb.caja(Vector3(x, y + (3.3 + alto) / 2.0, z), Vector3(w, alto - 3.3, d), col)
	# Muebles sencillos: cama contra una pared lateral al fondo y una mesa con dos sillas.
	var fondo_z: float = z - cara * (d / 2.0 - g - 1.2)
	mb.caja(Vector3(x - w / 2.0 + g + 0.55, y + 0.35, fondo_z), Vector3(1.0, 0.5, 2.0), Color(0.5, 0.15, 0.15))
	mb.caja(Vector3(x - w / 2.0 + g + 0.55, y + 0.2, fondo_z), Vector3(1.1, 0.2, 2.1), Color(0.3, 0.2, 0.12))
	mb.caja(Vector3(x + 1.0, y + 0.42, z - cara * 1.0), Vector3(1.4, 0.84, 0.8), Color(0.35, 0.24, 0.14))
	mb.caja(Vector3(x + 1.0, y + 0.25, z - cara * 2.0), Vector3(0.4, 0.5, 0.4), Color(0.3, 0.2, 0.12))
	mb.caja(Vector3(x + 1.0, y + 0.25, z), Vector3(0.4, 0.5, 0.4), Color(0.3, 0.2, 0.12))


# Un huerto: tierra, surcos, valla con entrada hacia el pueblo.
static func _huerto(mb: ConstructorMalla, h: Dictionary) -> void:
	var ctr: Vector2 = h["ctr"]
	var ex: float = h["ex"]
	var ez: float = h["ez"]
	var y: float = h["y"]
	var tierra: Color = Color(0.22, 0.14, 0.09)
	mb.caja(Vector3(ctr.x, y + 0.04, ctr.y), Vector3(ex - 1.0, 0.12, ez - 1.0), tierra)
	var frente: Vector2 = h["frente"]
	var surcos_en_x: bool = absf(frente.y) > 0.5   # El huerto "mira" en z: surcos a lo largo de x.
	var n: int = int(((ez if surcos_en_x else ex) - 3.0) / 1.6)
	for i in n:
		var t: float = -((ez if surcos_en_x else ex) - 3.0) / 2.0 + i * 1.6
		if surcos_en_x:
			mb.caja(Vector3(ctr.x, y + 0.14, ctr.y + t), Vector3(ex - 3.0, 0.1, 0.5), tierra.lightened(0.12))
		else:
			mb.caja(Vector3(ctr.x + t, y + 0.14, ctr.y), Vector3(0.5, 0.1, ez - 3.0), tierra.lightened(0.12))
	var madera: Color = Color(0.4, 0.28, 0.17)
	var hx: float = ex / 2.0
	var hz: float = ez / 2.0
	var cual: int = 0
	var gate: Vector2 = h["puerta"]
	# Cuatro lados; el del frente se parte en dos con una entrada de 3 m.
	var lados: Array = [
		[Vector2(ctr.x, ctr.y - hz), Vector2(ex, 0.12), Vector2(0, -1)],
		[Vector2(ctr.x, ctr.y + hz), Vector2(ex, 0.12), Vector2(0, 1)],
		[Vector2(ctr.x - hx, ctr.y), Vector2(0.12, ez), Vector2(-1, 0)],
		[Vector2(ctr.x + hx, ctr.y), Vector2(0.12, ez), Vector2(1, 0)],
	]
	for l in lados:
		var pos: Vector2 = l[0]
		var tam: Vector2 = l[1]
		var dir: Vector2 = l[2]
		if dir == -frente:
			if absf(dir.y) > 0.5:
				var mitad_l: float = (tam.x - 3.0) / 2.0
				mb.caja(Vector3(pos.x - 1.5 - mitad_l / 2.0, y + 0.5, pos.y), Vector3(mitad_l, 1.0, tam.y), madera)
				mb.caja(Vector3(pos.x + 1.5 + mitad_l / 2.0, y + 0.5, pos.y), Vector3(mitad_l, 1.0, tam.y), madera)
			else:
				var mitad_l2: float = (tam.y - 3.0) / 2.0
				mb.caja(Vector3(pos.x, y + 0.5, pos.y - 1.5 - mitad_l2 / 2.0), Vector3(tam.x, 1.0, mitad_l2), madera)
				mb.caja(Vector3(pos.x, y + 0.5, pos.y + 1.5 + mitad_l2 / 2.0), Vector3(tam.x, 1.0, mitad_l2), madera)
		else:
			mb.caja(Vector3(pos.x, y + 0.5, pos.y), Vector3(tam.x, 1.0, tam.y), madera)
	# Cartel verde junto a la entrada.
	mb.caja(Vector3(gate.x + frente.y * 2.4, y + 1.4, gate.y - frente.x * 2.4), Vector3(0.9, 0.6, 0.9), Color(0.2, 0.65, 0.3))


# Genera todo lo de un trozo cercano (128 m). Se puede llamar desde un hilo.
# Resultado: {"vacio": true} si cae entero dentro de la ciudad original; si no
#   "superficies": lista de arrays para ArrayMesh (terreno, carreteras, objetos),
#   "caras": caras para el choque, "arboles": buffer de MultiMesh,
#   "props": propiedades (casas/huertos) para poner interruptores.
static func generar_cercano(c: Vector2i) -> Dictionary:
	var x0: float = c.x * TROZO
	var z0: float = c.y * TROZO
	var rect: Rect2 = Rect2(x0, z0, TROZO, TROZO)
	if nucleo.encloses(rect):
		return {"vacio": true}
	var lista: Array = asentamientos_cerca(rect.grow(10.0))
	var lista_t: Array = lista.duplicate()   # Lo mismo + las carreteras de montaña (para tallar el terreno).
	lista_t.append_array(caminos_cerca(rect.grow(40.0)))
	var segs: Array = segmentos_para(rect.grow(20.0))
	var paso: float = TROZO / CELDAS
	var g: PackedFloat32Array = _cuadricula(x0, z0, CELDAS, paso, lista_t)
	var ter: Dictionary = _terreno(x0, z0, CELDAS, paso, g)
	var superficies: Array = [ter["arrays"]]
	var caras: PackedVector3Array = ter["caras"]

	var vias: ConstructorMalla = ConstructorMalla.new()
	_dibujar_carreteras(vias, segs, rect.grow(2.0), 4.0, lista_t, 0.15, 0.0)
	if not vias.esta_vacio():
		superficies.append(vias.superficie())

	var objetos: ConstructorMalla = ConstructorMalla.new()
	var props: Array = []
	var huecos: Array = []   # Zonas donde no crecen árboles.
	for s in lista:
		for casa_d in _casas_en(s, rect):
			_edificio(objetos, casa_d, true)
			# Aldeas y pueblos: más o menos la mitad de las casas encienden ventanas y una luz de noche.
			if int(s["tipo"]) < 2 and not casa_d.has("servicio") and _f(int(casa_d["x"]), int(casa_d["z"]), 301) < 0.55:
				var cara_l: float = casa_d["puerta"]
				var zf: float = float(casa_d["z"]) + cara_l * (float(casa_d["d"]) / 2.0 + 0.07)
				var vent: Array = []
				for lado_v in [-1.0, 1.0]:
					vent.append(Vector3(float(casa_d["x"]) + lado_v * float(casa_d["w"]) * 0.27, float(casa_d["y"]) + 1.6, zf))
				props.append({"tipo": "luces_casa", "ventanas": vent, "cara": cara_l,
						"luz": Vector3(float(casa_d["x"]), float(casa_d["y"]) + 2.2, float(casa_d["z"]) + cara_l * (float(casa_d["d"]) / 2.0 + 2.5))})
			if casa_d.has("servicio"):
				props.append({"tipo": "servicio", "serv": casa_d["servicio"], "pos": _punto_servicio(casa_d)})
			if str(casa_d["id"]) != "":
				var cara: float = casa_d["puerta"]
				props.append({"id": casa_d["id"], "tipo": "casa",
						"pos": Vector3(casa_d["x"], casa_d["y"] + 1.0, float(casa_d["z"]) + cara * (float(casa_d["d"]) / 2.0 + 0.3))})
		_decorar_asentamiento(objetos, s, rect)
		for h in huertos_de(s):
			var hc: Vector2 = h["ctr"]
			if not rect.has_point(hc):
				continue
			_huerto(objetos, h)
			var gate: Vector2 = h["puerta"]
			props.append({"id": h["id"], "tipo": "huerto", "pos": Vector3(gate.x, h["y"], gate.y),
					"centro": Vector3(hc.x, h["y"], hc.y), "tam": Vector2(float(h["ex"]) - 3.0, float(h["ez"]) - 3.0),
					"m2": h["m2"]})
	_quitamiedos(objetos, rect, lista_t)
	_senales_y_obras(objetos, rect, lista_t)
	for est in _gasolineras_de_carretera(rect, segs):
		_edificio(objetos, est, true)
		var base_y: float = est["y"]
		objetos.caja(Vector3(est["x"], base_y - 0.45, float(est["z"]) + float(est["puerta"]) * 6.0),
				Vector3(24.0, 1.0, 26.0), Color(0.3, 0.3, 0.32))   # Losa de hormigón (tapa las pendientes).
		props.append({"tipo": "servicio", "serv": "gasolinera", "pos": _punto_servicio(est)})
	if not objetos.esta_vacio():
		superficies.append(objetos.superficie())
		caras.append_array(objetos.vertices)

	return {"superficies": superficies, "caras": caras, "arboles": _arboles(x0, z0, rect, lista_t, segs),
			"veg": _vegetacion(x0, z0, rect, lista_t, segs), "props": props}


# Parques (bloques sin casas) y farolas en los cruces de pueblos y ciudades.
static func _decorar_asentamiento(mb: ConstructorMalla, s: Dictionary, rect: Rect2) -> void:
	var tipo: int = s["tipo"]
	if tipo == 0:
		_decorar_aldea(mb, s, rect)
		return
	var n: int = s["n"]
	var p: Vector2 = s["pos"]
	var y: float = s["base"]
	var sid: int = int(s["ci"]) * 1009 + int(s["cj"])
	var poste: Color = Color(0.14, 0.14, 0.16)
	for k in range(-n, n + 1):
		for l in range(-n, n + 1):
			var cx: float = p.x + k * BLOQUE
			var cz: float = p.y + l * BLOQUE
			if rect.has_point(Vector2(cx, cz)) and _f(sid, k * 101 + l, 90) < 0.75:
				var sx: float = 1.0 if _f(sid, k * 101 + l, 91) < 0.5 else -1.0
				var sz: float = 1.0 if _f(sid, k * 101 + l, 92) < 0.5 else -1.0
				mb.caja(Vector3(cx + sx * 5.0, y + 2.3, cz + sz * 5.0), Vector3(0.18, 4.6, 0.18), poste)
				mb.caja(Vector3(cx + sx * 4.6, y + 4.6, cz + sz * 5.0), Vector3(0.9, 0.18, 0.35), Color(1.0, 0.9, 0.6))
			if k < n and l < n and es_parque(s, k, l):
				var bx: float = cx + CALLE_ANCHO / 2.0 + 18.0
				var bz: float = cz + CALLE_ANCHO / 2.0 + 18.0
				if not rect.has_point(Vector2(bx, bz)):
					continue
				var cid: int = k * 101 + l
				mb.caja(Vector3(bx, y + 0.06, bz), Vector3(34.0, 0.14, 34.0), Color(0.22, 0.42, 0.18))
				if _f(sid, cid, 78) < 0.5:   # Con fuente.
					mb.cono(Vector3(bx, y, bz), 3.0, 0.9, 12, Color(0.55, 0.55, 0.58), 2.6)
					mb.caja(Vector3(bx, y + 0.8, bz), Vector3(1.6, 1.2, 1.6), Color(0.5, 0.5, 0.54))
				for i in 6:
					var tx: float = bx + (_f(sid, cid, 80 + i) - 0.5) * 28.0
					var tz: float = bz + (_f(sid, cid, 90 + i) - 0.5) * 28.0
					if absf(tx - bx) < 4.5 and absf(tz - bz) < 4.5:
						continue
					var alt: float = 2.2 + 1.6 * _f(sid, cid, 100 + i)
					mb.caja(Vector3(tx, y + alt / 2.0, tz), Vector3(0.5, alt, 0.5), Color(0.3, 0.2, 0.12))
					mb.cono(Vector3(tx, y + alt - 0.4, tz), 2.0 + _f(sid, cid, 110 + i), 3.2, 8,
							Color(0.18, 0.4, 0.15).lerp(Color(0.4, 0.45, 0.15), _f(sid, cid, 120 + i)))
				for i in 4:
					var ang: float = TAU * float(i) / 4.0 + 0.4
					mb.caja(Vector3(bx + cos(ang) * 7.5, y + 0.5, bz + sin(ang) * 7.5), Vector3(2.0, 0.5, 0.6), Color(0.4, 0.28, 0.18))


# Aldeas: pozo en el cruce, farolillos, y en cada solar algo de vida de pueblo (huertecillo, pajar,
# leña, corral con valla, frutal) y junto a cada casa leña, barriles o una valla. Todo a pie de solar:
# nada a menos de 6 m del eje de las calles.
static func _decorar_aldea(mb: ConstructorMalla, s: Dictionary, rect: Rect2) -> void:
	var n: int = s["n"]
	var p: Vector2 = s["pos"]
	var y: float = s["base"]
	var sid: int = int(s["ci"]) * 1009 + int(s["cj"])
	var piedra: Color = Color(0.55, 0.54, 0.52)
	var madera: Color = Color(0.4, 0.28, 0.17)
	if rect.has_point(p):
		# Pozo en el centro del cruce, con su tejadillo.
		mb.cono(Vector3(p.x, y, p.y), 1.5, 0.9, 12, piedra, 1.4)
		for sx in [-1.1, 1.1]:
			mb.caja(Vector3(p.x + sx, y + 1.4, p.y), Vector3(0.14, 1.6, 0.14), madera)
		mb.techo(Vector3(p.x, y + 2.2, p.y), 3.0, 2.0, 0.9, Color(0.45, 0.22, 0.16))
	for k in range(-n, n):
		for l in range(-n, n):
			var cx: float = p.x + k * BLOQUE
			var cz: float = p.y + l * BLOQUE
			var clave: int = k * 101 + l
			# Farolillo en una esquina de cada bloque.
			if rect.has_point(Vector2(cx + 5.0, cz + 5.0)):
				mb.caja(Vector3(cx + 5.0, y + 1.6, cz + 5.0), Vector3(0.14, 3.2, 0.14), madera)
				mb.caja(Vector3(cx + 5.0, y + 3.3, cz + 5.0), Vector3(0.4, 0.4, 0.4), Color(1.0, 0.85, 0.45))
			for sub in 4:
				var a: int = sub % 2
				var b: int = sub / 2
				var lx: float = cx + CALLE_ANCHO / 2.0 + a * 18.0 + 9.0
				var lz: float = cz + CALLE_ANCHO / 2.0 + b * 18.0 + 9.0
				if not rect.has_point(Vector2(lx, lz)):
					continue
				var casa_d: Dictionary = casa(s, k, l, sub)
				var r: float = _f(sid, clave, 200 + sub)
				var r2: float = _f(sid, clave, 210 + sub)
				if casa_d.is_empty():
					_solar_de_aldea(mb, Vector3(lx, y, lz), r, r2)
				else:
					# Junto a la casa, por el lado contrario a la calle: leña, barriles o un trozo de valla.
					var cara: float = float(casa_d["puerta"])
					var ex: float = float(casa_d["x"]) + float(casa_d["w"]) / 2.0 + 1.1
					var ez: float = float(casa_d["z"]) - cara * (float(casa_d["d"]) / 2.0 - 1.5)
					if r < 0.35:
						for i in 3:
							mb.caja(Vector3(ex, y + 0.2 + i * 0.4, ez), Vector3(0.7, 0.4, 2.0 - i * 0.3), Color(0.5, 0.36, 0.2))   # Pila de leña.
					elif r < 0.6:
						mb.cono(Vector3(ex, y, ez), 0.4, 0.9, 8, Color(0.4, 0.27, 0.15), 0.35)   # Barril.
						mb.cono(Vector3(ex, y, ez + 1.0), 0.4, 0.9, 8, Color(0.36, 0.24, 0.14), 0.35)
					elif r < 0.8:
						for i in 4:
							mb.caja(Vector3(ex, y + 0.45, ez - 2.0 + i * 1.3), Vector3(0.12, 0.9, 0.12), madera)
						mb.caja(Vector3(ex, y + 0.7, ez), Vector3(0.08, 0.1, 4.0), madera)


static func _solar_de_aldea(mb: ConstructorMalla, c: Vector3, r: float, r2: float) -> void:
	var madera: Color = Color(0.4, 0.28, 0.17)
	if r < 0.28:   # Huertecillo con surcos.
		mb.caja(Vector3(c.x, c.y + 0.05, c.z), Vector3(12.0, 0.1, 12.0), Color(0.34, 0.24, 0.15))
		for i in 5:
			mb.caja(Vector3(c.x - 4.0 + i * 2.0, c.y + 0.25, c.z), Vector3(0.9, 0.35, 10.0),
					Color(0.2, 0.45, 0.16).lerp(Color(0.5, 0.5, 0.15), r2))
	elif r < 0.5:   # Pajar.
		mb.cono(Vector3(c.x, c.y, c.z), 2.4, 3.0, 10, Color(0.8, 0.68, 0.3), 0.3)
		mb.cono(Vector3(c.x + 5.0, c.y, c.z - 3.0), 1.6, 2.0, 10, Color(0.75, 0.62, 0.28), 0.25)
	elif r < 0.7:   # Corral con valla y un cobertizo.
		for i in 6:
			mb.caja(Vector3(c.x - 6.0 + i * 2.4, c.y + 0.5, c.z - 6.0), Vector3(0.14, 1.0, 0.14), madera)
			mb.caja(Vector3(c.x - 6.0 + i * 2.4, c.y + 0.5, c.z + 6.0), Vector3(0.14, 1.0, 0.14), madera)
		mb.caja(Vector3(c.x, c.y + 0.8, c.z - 6.0), Vector3(12.0, 0.1, 0.1), madera)
		mb.caja(Vector3(c.x, c.y + 0.8, c.z + 6.0), Vector3(12.0, 0.1, 0.1), madera)
		mb.caja(Vector3(c.x + 3.0, c.y + 1.2, c.z), Vector3(3.0, 2.4, 2.4), Color(0.45, 0.33, 0.22))
		mb.techo(Vector3(c.x + 3.0, c.y + 2.4, c.z), 3.6, 3.0, 0.9, Color(0.35, 0.22, 0.15))
	else:   # Frutal con un banco debajo.
		mb.caja(Vector3(c.x, c.y + 1.2, c.z), Vector3(0.45, 2.4, 0.45), Color(0.3, 0.2, 0.12))
		mb.cono(Vector3(c.x, c.y + 2.0, c.z), 2.6 + r2, 2.6, 8, Color(0.2, 0.42, 0.16), 0.6)
		mb.caja(Vector3(c.x + 2.8, c.y + 0.45, c.z), Vector3(0.6, 0.12, 2.0), madera)


# Gasolineras sueltas junto a las carreteras largas (cada ~600 m). Devuelve edificios de servicio
# ya colocados (misma forma que _servicio_edificio) cuyo centro cae en "rect".
static func _gasolineras_de_carretera(rect: Rect2, segs: Array) -> Array:
	var out: Array = []
	for sg in segs:
		if int(sg[3]) != 1:
			continue
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var largo: float = a.distance_to(b)
		if largo < 350.0 or absf(b.x - a.x) < absf(b.y - a.y):
			continue   # Solo tramos largos y más bien de este a oeste (la marquesina mira al norte o al sur).
		var ha: int = int(a.x) * 7 + int(a.y) * 13 + int(b.x) * 17 + int(b.y) * 19
		var cuantas: int = maxi(1, int(largo / 600.0))
		for i in cuantas:
			var t: float = (float(i) + 0.3 + 0.4 * _f(ha, i, 41)) / float(cuantas)
			var pt: Vector2 = a.lerp(b, t)
			var norte: bool = _f(ha, i, 42) < 0.5
			var dz: float = -22.0 if norte else 22.0
			var pos: Vector2 = Vector2(pt.x, pt.y + dz)
			if not rect.has_point(pos):
				continue
			var hs: Array = [altura(pos.x - 10.0, pos.y), altura(pos.x + 10.0, pos.y),
					altura(pos.x, pos.y - 12.0), altura(pos.x, pos.y + 12.0), altura(pos.x, pos.y)]
			var h_max: float = -INF
			for hv in hs:
				h_max = maxf(h_max, hv)
			var h_min: float = INF
			for hv in hs:
				h_min = minf(h_min, hv)
			if h_max - h_min > 5.0 or h_max > 80.0:
				continue   # Demasiado empinado (monte).
			var cara: float = 1.0 if norte else -1.0
			var est: Dictionary = {"x": pos.x, "z": pos.y, "y": h_max + 0.2, "w": 8.0, "d": 6.0, "pisos": 1, "alto": 4.0,
					"puerta": cara, "plano": true, "color": COLOR_SERVICIO["gasolinera"],
					"techo": Color(0.25, 0.25, 0.28), "id": "", "servicio": "gasolinera", "var": 1}
			out.append(est)
	return out


# Vegetación variada (además de los pinos): robles, arbustos, rocas y flores. Devuelve cuatro
# buffers de MultiMesh (12 floats por instancia, como los pinos) en este orden.
static func _vegetacion(x0: float, z0: float, rect: Rect2, lista: Array, segs: Array) -> Array:
	var roble: PackedFloat32Array = PackedFloat32Array()
	var arbusto: PackedFloat32Array = PackedFloat32Array()
	var roca: PackedFloat32Array = PackedFloat32Array()
	var flor: PackedFloat32Array = PackedFloat32Array()
	var zona_nucleo: Rect2 = nucleo.grow(30.0)
	var paso: float = 6.0
	var gx0: int = floori(x0 / paso)
	var gz0: int = floori(z0 / paso)
	var ncel: int = int(TROZO / paso) + 1
	for i in ncel:
		for j in ncel:
			var gx: int = gx0 + i
			var gz: int = gz0 + j
			var x: float = (gx + 0.5 + (_f(gx, gz, 31) - 0.5) * 0.9) * paso
			var z: float = (gz + 0.5 + (_f(gx, gz, 32) - 0.5) * 0.9) * paso
			if not rect.has_point(Vector2(x, z)) or zona_nucleo.has_point(Vector2(x, z)):
				continue
			var dentro: bool = false
			for s in lista:
				if s.has("camino"):
					continue
				var pp: Vector2 = s["pos"]
				if maxf(absf(x - pp.x), absf(z - pp.y)) < float(s["plano"]) + 5.0:
					dentro = true
					break
			if dentro:
				continue
			var h: float = altura_lista(x, z, lista)
			var pinar: float = densidad_bosque(x, z, h)
			var fertil: float = smoothstep(-0.2, 0.4, _r_bosque.get_noise_2d(x + 5000.0, z - 3000.0))
			var pos: Vector2 = Vector2(x, z)
			var azar: float = _f(gx, gz, 33)
			var giro: float = TAU * _f(gx, gz, 35)
			var esc: float = 0.7 + 0.8 * _f(gx, gz, 34)
			var cs: float = cos(giro) * esc
			var sn: float = sin(giro) * esc
			var m: PackedFloat32Array = PackedFloat32Array([cs, 0.0, sn, x, 0.0, esc, 0.0, h - 0.1, -sn, 0.0, cs, z])
			if azar < 0.1 and h < 70.0 and fertil > 0.35 and pinar < 0.5:
				if not _distancia_a_carreteras(pos, segs, 5.0):
					roble.append_array(m)
			elif azar < 0.3 and h < 100.0:
				if _f(gx, gz, 36) < 0.25 + 0.5 * maxf(fertil, pinar) and not _distancia_a_carreteras(pos, segs, 3.5):
					arbusto.append_array(m)
			elif azar < 0.34 and (h > 40.0 or _f(gx, gz, 37) < 0.3):
				if not _distancia_a_carreteras(pos, segs, 4.5):
					roca.append_array(m)
			elif azar < 0.56 and fertil > 0.2 and h < 60.0 and pinar < 0.4:
				if not _distancia_a_carreteras(pos, segs, 2.5):
					flor.append_array(m)
	return [roble, arbusto, roca, flor]


# Pinos: una cuadrícula de 8 m con desplazamiento al azar; crecen donde manda el ruido del bosque.
static func _arboles(x0: float, z0: float, rect: Rect2, lista: Array, segs: Array) -> PackedFloat32Array:
	var buf: PackedFloat32Array = PackedFloat32Array()
	var gx0: int = floori(x0 / 8.0)
	var gz0: int = floori(z0 / 8.0)
	var ncel: int = int(TROZO / 8.0)
	var zona_nucleo: Rect2 = nucleo.grow(30.0)
	for i in ncel:
		for j in ncel:
			var gx: int = gx0 + i
			var gz: int = gz0 + j
			var x: float = (gx + 0.5 + (_f(gx, gz, 21) - 0.5) * 0.8) * 8.0
			var z: float = (gz + 0.5 + (_f(gx, gz, 22) - 0.5) * 0.8) * 8.0
			if not rect.has_point(Vector2(x, z)):
				continue
			if zona_nucleo.has_point(Vector2(x, z)):
				continue
			var h: float = altura_lista(x, z, lista)
			if _f(gx, gz, 23) > densidad_bosque(x, z, h) * 0.85:
				continue
			var dentro: bool = false
			for s in lista:
				if s.has("camino"):
					continue
				var p: Vector2 = s["pos"]
				if maxf(absf(x - p.x), absf(z - p.y)) < float(s["plano"]) + 5.0:
					dentro = true
					break
			if dentro or _distancia_a_carreteras(Vector2(x, z), segs, 4.0):
				continue
			var esc: float = 0.8 + 0.9 * _f(gx, gz, 24)
			var giro: float = TAU * _f(gx, gz, 25)
			var cs: float = cos(giro) * esc
			var sn: float = sin(giro) * esc
			buf.append_array(PackedFloat32Array([cs, 0.0, sn, x, 0.0, esc, 0.0, h - 0.15, -sn, 0.0, cs, z]))
	return buf


# ------------------------------- trozos lejanos -------------------------------

# Trozo de 512 m solo para verse de lejos: terreno, carreteras y casas en cajas.
static func generar_lejano(c: Vector2i) -> Dictionary:
	var x0: float = c.x * TROZO_LEJOS
	var z0: float = c.y * TROZO_LEJOS
	var rect: Rect2 = Rect2(x0, z0, TROZO_LEJOS, TROZO_LEJOS)
	if nucleo.encloses(rect):
		return {"vacio": true}
	var lista: Array = asentamientos_cerca(rect.grow(10.0))
	var lista_t: Array = lista.duplicate()
	lista_t.append_array(caminos_cerca(rect.grow(40.0)))
	var segs: Array = segmentos_para(rect.grow(40.0))
	var paso: float = TROZO_LEJOS / CELDAS_LEJOS
	var g: PackedFloat32Array = _cuadricula(x0, z0, CELDAS_LEJOS, paso, lista_t)
	var ter: Dictionary = _terreno(x0, z0, CELDAS_LEJOS, paso, g)
	var superficies: Array = [ter["arrays"]]
	var vias: ConstructorMalla = ConstructorMalla.new()
	_dibujar_carreteras(vias, segs, rect.grow(4.0), 16.0, lista_t, 0.9, 4.0)
	if not vias.esta_vacio():
		superficies.append(vias.superficie())
	var objetos: ConstructorMalla = ConstructorMalla.new()
	for s in lista:
		for casa_d in _casas_en(s, rect):
			_edificio(objetos, casa_d, false)
	if not objetos.esta_vacio():
		superficies.append(objetos.superficie())
	return {"superficies": superficies}


# ------------------------------- imagen del mapa -------------------------------

# Dibuja el mundo entero en una imagen cuadrada (para el mapa grande).
static func imagen_mapa(res: int) -> Image:
	var img: Image = Image.create(res, res, false, Image.FORMAT_RGB8)
	var lado: float = MITAD * 2.0
	var todos: Array = todos_asentamientos()
	for py in res:
		for px in res:
			var x: float = (float(px) + 0.5) / float(res) * lado - MITAD
			var z: float = (float(py) + 0.5) / float(res) * lado - MITAD
			var lista: Array = []
			for s in todos:
				var p: Vector2 = s["pos"]
				if maxf(absf(x - p.x), absf(z - p.y)) < float(s["plano"]) + 100.0:
					lista.append(s)
			var h: float = altura_lista(x, z, lista)
			var col: Color = _color_suelo(x, z, h, 1.0)
			img.set_pixel(px, py, col)
	for sg in todas_las_carreteras():
		_linea_imagen(img, sg[0], sg[1], res, Color(0.75, 0.7, 0.6))
	for s in todos:
		var p: Vector2 = s["pos"]
		var rad: int = [2, 3, 5][int(s["tipo"])]
		var cx: int = int((p.x + MITAD) / lado * res)
		var cy: int = int((p.y + MITAD) / lado * res)
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var ix: int = cx + dx
				var iy: int = cy + dy
				if ix >= 0 and iy >= 0 and ix < res and iy < res:
					img.set_pixel(ix, iy, Color(0.9, 0.3, 0.25))
	# La ciudad original, en dorado.
	var n0: Vector2i = Vector2i(int((nucleo.position.x + MITAD) / lado * res), int((nucleo.position.y + MITAD) / lado * res))
	var n1: Vector2i = Vector2i(int((nucleo.end.x + MITAD) / lado * res), int((nucleo.end.y + MITAD) / lado * res))
	for iy in range(maxi(n0.y - 2, 0), mini(n1.y + 3, res)):
		for ix in range(maxi(n0.x - 2, 0), mini(n1.x + 3, res)):
			img.set_pixel(ix, iy, Color(0.95, 0.8, 0.3))
	return img


static func _linea_imagen(img: Image, a: Vector2, b: Vector2, res: int, col: Color) -> void:
	var lado: float = MITAD * 2.0
	var pasos: int = maxi(2, int((b - a).length() / lado * res * 2.0))
	for i in pasos + 1:
		var p: Vector2 = a.lerp(b, float(i) / float(pasos))
		var ix: int = int((p.x + MITAD) / lado * res)
		var iy: int = int((p.y + MITAD) / lado * res)
		if ix >= 0 and iy >= 0 and ix < res and iy < res:
			img.set_pixel(ix, iy, col)
