# escalera_edificio.gd
# -----------------------------------------------------------------------------
# La escalera de los edificios de varios pisos: una escalera "en U" de dos tramos que va
# pegada a una pared lateral, al fondo del edificio, y se repite igual en cada piso.
#
#   Planta (visto desde arriba; la puerta de la casa está abajo, en iv = 0):
#
#        pared lateral (exterior)                        resto de la casa
#        ┌───────────────┬───┬───────────────┐ ┆
#        │  tramo A ▲    │   │   tramo B ▲   │ ┆  <- iv = D - 0.9 .. D: descansillo (a mitad de piso)
#        │  (sube hacia  │ r │  (sube hacia  │ ┆
#        │   el fondo)   │ a │   el frente)  │ ┆
#        │               │ i │               │ ┆
#        └───────────────┴───┴───────────────┘ ┆  <- iv = D - 3.5: borde de la planta (aquí se entra)
#        rellano (pasillo) delante de la escalera
#
# Se entra al tramo A por delante (iv = D - 3.5) y se sale del tramo B por el mismo borde, un
# piso más arriba. Cada tramo sube 1,6 m en 2,6 m de largo (32°: se anda por ella sin saltar).
# El suelo de cada piso tiene un hueco del tamaño de la escalera (lo hace CascaraEdificio).
# Todo se calcula solo con los datos del edificio, así el muro, el hueco y los muebles de dentro
# coinciden siempre.
# -----------------------------------------------------------------------------
class_name EscaleraEdificio
extends RefCounted

const ANCHO: float = 2.4       # Ancho total (dos tramos de 1,1 m y un hueco de 0,2 m).
const CARRIL: float = 1.1
const LARGO: float = 3.5       # Fondo total (tramos + descansillo).
const DESCANSO: float = 0.9
const MADERA: Color = Color(0.5, 0.36, 0.22)
const MADERA2: Color = Color(0.4, 0.28, 0.17)
const BARANDA: Color = Color(0.32, 0.22, 0.14)


# Datos de la escalera del edificio "c" o {} si no la tiene (un solo piso o demasiado pequeño).
static func de(c: Dictionary) -> Dictionary:
	if int(c["pisos"]) < 2:
		return {}
	var m: MarcoEdificio = MarcoEdificio.new().configurar(c)
	if m.W < 5.9 or m.D < 5.8:
		return {}
	var h: int = int(absf(m.x) * 7.0) + int(absf(m.z) * 13.0) + int(c.get("var", 0))
	var lado: float = -1.0 if h % 2 == 0 else 1.0
	var ua: float = -m.W / 2.0 if lado < 0.0 else m.W / 2.0 - ANCHO
	var ub: float = ua + ANCHO
	var iv_f: float = m.D - LARGO
	var r: Dictionary = {"lado": lado, "franja": Rect2(ua, 0.0, ANCHO, m.D), "bloque": Rect2(ua, iv_f, ANCHO, LARGO),
			"iv_frente": iv_f, "iv_medio": m.D - DESCANSO, "u_borde": ub if lado < 0.0 else ua}
	# Tramo A (el de fuera, pegado a la pared exterior) y tramo B (el de dentro).
	if lado < 0.0:
		r["a"] = Vector2(ua, ua + CARRIL)
		r["b"] = Vector2(ub - CARRIL, ub)
	else:
		r["a"] = Vector2(ub - CARRIL, ub)
		r["b"] = Vector2(ua, ua + CARRIL)
	return r


# Dibuja la escalera de todos los pisos (rampas, descansillos, barandillas y el muro del lado de dentro).
static func emitir(mb: ConstructorMalla, c: Dictionary) -> void:
	var e: Dictionary = de(c)
	if e.is_empty():
		return
	var m: MarcoEdificio = MarcoEdificio.new().configurar(c)
	var iv_f: float = e["iv_frente"]
	var iv_m: float = e["iv_medio"]
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var franja: Rect2 = e["franja"]
	var pisos: int = int(c["pisos"])
	for n in pisos - 1:
		var y0: float = m.suelo_y(n)
		_rampa(mb, m, a.x, a.y, iv_f, y0, iv_m, y0 + 1.6, y0, MADERA)
		_rampa(mb, m, b.x, b.y, iv_f, y0 + 3.2, iv_m, y0 + 1.6, y0, MADERA2)
		# Descansillo a mitad de piso.
		m.caja_en(mb, franja.get_center().x, (iv_m + m.D) / 2.0, y0 + 0.8, ANCHO, 1.6, m.D - iv_m, MADERA)
	# Muro del lado de dentro, de abajo a arriba, a lo largo del bloque de la escalera.
	var u_muro: float = float(e["u_borde"]) + (-0.075 if float(e["lado"]) < 0.0 else 0.075)
	var y_base: float = m.suelo_y(0)
	var y_alto: float = m.suelo_y(pisos - 1) + MarcoEdificio.ALTO_LIBRE
	m.caja_en(mb, u_muro, (iv_f + m.D) / 2.0, (y_base + y_alto) / 2.0, 0.15, y_alto - y_base, m.D - iv_f, Color(0.82, 0.78, 0.7))
	# Barandillas: la separación entre tramos en cada piso, y el hueco abierto del tramo A en el último.
	var u_med: float = (a.y + b.x) / 2.0 if float(e["lado"]) < 0.0 else (b.y + a.x) / 2.0
	for n in range(1, pisos):
		var yn: float = m.suelo_y(n)
		m.caja_en(mb, u_med, (iv_f + iv_m) / 2.0, yn + 0.5, 0.12, 1.0, iv_m - iv_f, BARANDA)
	var yt: float = m.suelo_y(pisos - 1)
	m.caja_en(mb, (a.x + a.y) / 2.0, iv_f + 0.06, yt + 0.5, CARRIL, 1.0, 0.12, BARANDA)


# Una rampa maciza: de iv_a (altura ya) a iv_b (altura yb), con el fondo plano a "ybase".
# La cara de arriba va a franjas alternas para que parezca una escalera.
static func _rampa(mb: ConstructorMalla, m: MarcoEdificio, u0: float, u1: float, iv_a: float, ya: float,
		iv_b: float, yb: float, ybase: float, col: Color) -> void:
	var v: Array = [m.punto(u0, iv_a, ybase), m.punto(u1, iv_a, ybase), m.punto(u1, iv_b, ybase), m.punto(u0, iv_b, ybase),
			m.punto(u0, iv_a, ya), m.punto(u1, iv_a, ya), m.punto(u1, iv_b, yb), m.punto(u0, iv_b, yb)]
	var c: Vector3 = Vector3.ZERO
	for p in v:
		c += p
	c /= 8.0
	mb.cuadro_fuera(v[0], v[1], v[2], v[3], c, col.darkened(0.2))
	mb.cuadro_fuera(v[0], v[1], v[5], v[4], c, col)
	mb.cuadro_fuera(v[2], v[3], v[7], v[6], c, col)
	mb.cuadro_fuera(v[1], v[2], v[6], v[5], c, col.darkened(0.1))
	mb.cuadro_fuera(v[3], v[0], v[4], v[7], c, col.darkened(0.1))
	var n: int = 9
	for i in n:
		var t0: float = float(i) / float(n)
		var t1: float = float(i + 1) / float(n)
		var p0: Vector3 = v[4].lerp(v[7], t0)
		var p1: Vector3 = v[5].lerp(v[6], t0)
		var p2: Vector3 = v[5].lerp(v[6], t1)
		var p3: Vector3 = v[4].lerp(v[7], t1)
		mb.cuadro_fuera(p0, p1, p2, p3, c, col.lightened(0.1) if i % 2 == 0 else col.darkened(0.08))
