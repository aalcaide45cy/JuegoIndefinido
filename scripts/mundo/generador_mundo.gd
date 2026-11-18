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
const CELDA: float = 1200.0            # Una celda de asentamientos (puede tener uno).
const CELDA_MIN: int = -4
const CELDA_MAX: int = 3
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
	var m: float = smoothstep(0.1, 0.5, _r_mont.get_noise_2d(x, z))
	return 9.0 * _r_cont.get_noise_2d(x, z) + 3.0 * _r_med.get_noise_2d(x, z) \
			+ 1.0 * _r_det.get_noise_2d(x, z) + m * 150.0


# Altura final teniendo en cuenta los asentamientos de la lista y la ciudad original.
static func altura_lista(x: float, z: float, lista: Array) -> float:
	var h: float = altura_base(x, z)
	h = lerpf(-0.3, h, smoothstep(0.0, 400.0, dist_rect(x, z, nucleo)))
	for s in lista:
		var p: Vector2 = s["pos"]
		var d: float = maxf(absf(x - p.x), absf(z - p.y))
		var plano: float = s["plano"]
		if d < plano + 100.0:
			h = lerpf(s["base"], h, smoothstep(plano, plano + 100.0, d))
	return h


static func altura(x: float, z: float) -> float:
	var lista: Array = asentamientos_cerca(Rect2(x - 1.0, z - 1.0, 2.0, 2.0))
	return altura_lista(x, z, lista)


static func densidad_bosque(x: float, z: float, h: float) -> float:
	return smoothstep(-0.1, 0.4, _r_bosque.get_noise_2d(x, z)) * (1.0 - smoothstep(80.0, 140.0, h))


static func _color_suelo(x: float, z: float, h: float, ny: float) -> Color:
	var g: float = _r_color.get_noise_2d(x, z) * 0.5 + 0.5
	var col: Color = Color(0.23 + 0.07 * g, 0.35 + 0.08 * g, 0.16)
	col = col.lerp(Color(0.12, 0.24, 0.1), densidad_bosque(x, z, h) * 0.6)
	var roca: float = maxf(smoothstep(75.0, 115.0, h), 1.0 - smoothstep(0.7, 0.85, ny))
	col = col.lerp(Color(0.4, 0.38, 0.36), roca)
	col = col.lerp(Color(0.92, 0.94, 0.97), smoothstep(135.0, 160.0, h))
	return col


# ------------------------------- asentamientos --------------------------------

# El asentamiento de la celda (ci, cj), o {} si no hay.
static func asentamiento(ci: int, cj: int) -> Dictionary:
	if ci < CELDA_MIN or ci > CELDA_MAX or cj < CELDA_MIN or cj > CELDA_MAX:
		return {}
	if _f(ci, cj, 1) > 0.8:
		return {}
	var cx: float = (ci + 0.5) * CELDA + (_f(ci, cj, 2) - 0.5) * 500.0
	var cz: float = (cj + 0.5) * CELDA + (_f(ci, cj, 3) - 0.5) * 500.0
	if absf(cx) > MITAD - 450.0 or absf(cz) > MITAD - 450.0:
		return {}
	var centro: Vector2 = Vector2(cx, cz)
	if nucleo.grow(900.0).has_point(centro):
		return {}
	var base: float = altura_base(cx, cz)
	if base > 30.0:
		return {}   # Nada de ciudades en lo alto de una montaña.
	var r: float = _f(ci, cj, 4)
	var tipo: int = 0
	var n: int = 1
	if r < 0.1:
		tipo = 2
		n = 4
	elif r < 0.4:
		tipo = 1
		n = 2
	return {"ci": ci, "cj": cj, "pos": centro, "tipo": tipo, "n": n, "mitad": n * BLOQUE,
			"plano": n * BLOQUE + 150.0, "base": base, "nombre": _nombre(ci, cj)}


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
	return out


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


# ---------------------------------- casas -------------------------------------

# La casa del solar "sub" (0-3) del bloque (k, l) de un asentamiento, o {} si ahí no hay.
static func casa(s: Dictionary, k: int, l: int, sub: int) -> Dictionary:
	var n: int = s["n"]
	var tipo: int = s["tipo"]
	if tipo == 2 and k >= -1 and k <= 0 and l >= -1 and l <= 0:
		return {}   # La plaza mayor de la ciudad queda libre.
	var sid: int = int(s["ci"]) * 1009 + int(s["cj"])
	var clave: int = k * 101 + l
	if _f(sid, clave + 7919, sub * 16) < (0.1 if tipo > 0 else 0.15):
		return {}
	var p: Vector2 = s["pos"]
	var a: int = sub % 2
	var b: int = sub / 2
	var ancho: float = 9.0 + 5.0 * _f(sid, clave, sub * 16 + 1)
	var fondo: float = 9.0 + 5.0 * _f(sid, clave, sub * 16 + 2)
	var cx: float = p.x + k * BLOQUE + CALLE_ANCHO / 2.0 + a * 18.0 + 9.0 + (_f(sid, clave, sub * 16 + 3) - 0.5) * 2.0
	var cz: float = p.y + l * BLOQUE + CALLE_ANCHO / 2.0 + b * 18.0 + 9.0 + (_f(sid, clave, sub * 16 + 4) - 0.5) * 2.0
	var r: float = _f(sid, clave, sub * 16 + 5)
	var pisos: int = 1 + int(r * 2.0)
	if tipo == 2:
		var cerca: float = maxf(absf(k + 0.5), absf(l + 0.5))
		pisos = 1 + int(r * 3.0) + (2 if cerca < 2.0 else 0)
	var c: Dictionary = {"x": cx, "z": cz, "y": s["base"], "w": ancho, "d": fondo, "pisos": pisos,
			"alto": pisos * 3.2, "puerta": -1 if b == 0 else 1, "plano": pisos > 3,
			"color": COLORES_PARED[_h(sid, clave, sub * 16 + 6) % COLORES_PARED.size()],
			"techo": COLORES_TECHO[_h(sid, clave, sub * 16 + 7) % COLORES_TECHO.size()], "id": ""}
	var prob_alquiler: float = [0.14, 0.1, 0.07][tipo]
	if _f(sid, clave + 31, sub * 16 + 8) < prob_alquiler:
		c["id"] = "w_c_%d_%d_%d_%d_%d" % [s["ci"], s["cj"], k, l, sub]
	return c


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
		mb.techo(Vector3(c["x"], y + alto, c["z"]), w + 0.8, d + 0.8, 2.2, c["techo"])
	if not detalle:
		return
	var cara: float = float(c["puerta"])
	var zf: float = c["z"] + cara * (d / 2.0 + 0.04)
	if not hueca:
		mb.caja(Vector3(c["x"], y + 1.05, zf), Vector3(1.1, 2.1, 0.1), Color(0.25, 0.15, 0.1))
	var vent: Color = Color(0.12, 0.17, 0.26)
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
	var segs: Array = segmentos_para(rect.grow(20.0))
	var paso: float = TROZO / CELDAS
	var g: PackedFloat32Array = _cuadricula(x0, z0, CELDAS, paso, lista)
	var ter: Dictionary = _terreno(x0, z0, CELDAS, paso, g)
	var superficies: Array = [ter["arrays"]]
	var caras: PackedVector3Array = ter["caras"]

	var vias: ConstructorMalla = ConstructorMalla.new()
	_dibujar_carreteras(vias, segs, rect.grow(2.0), 4.0, lista, 0.15, 0.0)
	if not vias.esta_vacio():
		superficies.append(vias.superficie())

	var objetos: ConstructorMalla = ConstructorMalla.new()
	var props: Array = []
	var huecos: Array = []   # Zonas donde no crecen árboles.
	for s in lista:
		for casa_d in _casas_en(s, rect):
			_edificio(objetos, casa_d, true)
			if str(casa_d["id"]) != "":
				var cara: float = casa_d["puerta"]
				props.append({"id": casa_d["id"], "tipo": "casa",
						"pos": Vector3(casa_d["x"], casa_d["y"] + 1.0, float(casa_d["z"]) + cara * (float(casa_d["d"]) / 2.0 + 0.3))})
		for h in huertos_de(s):
			var hc: Vector2 = h["ctr"]
			if not rect.has_point(hc):
				continue
			_huerto(objetos, h)
			var gate: Vector2 = h["puerta"]
			props.append({"id": h["id"], "tipo": "huerto", "pos": Vector3(gate.x, h["y"], gate.y),
					"centro": Vector3(hc.x, h["y"], hc.y), "tam": Vector2(float(h["ex"]) - 3.0, float(h["ez"]) - 3.0),
					"m2": h["m2"]})
	if not objetos.esta_vacio():
		superficies.append(objetos.superficie())
		caras.append_array(objetos.vertices)

	return {"superficies": superficies, "caras": caras, "arboles": _arboles(x0, z0, rect, lista, segs),
			"props": props}


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
	var segs: Array = segmentos_para(rect.grow(40.0))
	var paso: float = TROZO_LEJOS / CELDAS_LEJOS
	var g: PackedFloat32Array = _cuadricula(x0, z0, CELDAS_LEJOS, paso, lista)
	var ter: Dictionary = _terreno(x0, z0, CELDAS_LEJOS, paso, g)
	var superficies: Array = [ter["arrays"]]
	var vias: ConstructorMalla = ConstructorMalla.new()
	_dibujar_carreteras(vias, segs, rect.grow(4.0), 16.0, lista, 0.9, 4.0)
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
