# cascara_edificio.gd
# -----------------------------------------------------------------------------
# La "cáscara" de cualquier edificio visitable: cuatro muros con hueco de puerta y ventanas de
# verdad en TODOS los pisos, un suelo por piso (con el hueco de la escalera) y las rampas de la
# escalera. Lo usan el mundo grande (dentro de la malla del trozo, ver GeneradorMundo._edificio) y
# los edificios de la ciudad original (Barrio.edificio).
# Los muebles, las paredes de dentro y las luces NO van aquí: los pone GestorInteriores al
# acercarte (InteriorCasa). Escalera, hueco y muros se calculan con los mismos datos, así que
# encajan siempre.
# -----------------------------------------------------------------------------
class_name CascaraEdificio
extends RefCounted

const PUERTA_ANCHO: float = 1.3
const PUERTA_ALTO: float = 2.1
const VENT_ANCHO: float = 1.1
const VENT_BAJO: float = 1.0
const VENT_ALTO: float = 2.2
const COLOR_SUELO: Color = Color(0.42, 0.3, 0.19)


# Posiciones (u relativa al centro) de las ventanas de cada piso de un edificio de ancho w.
# (Las casas, de hasta 15,5 m, tienen dos; los edificios más anchos tienen cuatro.)
static func ventanas_x(w: float) -> Array:
	if w > 15.9:
		return [-w * 0.36, -w * 0.2, w * 0.2, w * 0.36]
	return [-w * 0.3, w * 0.3]


static func generar(mb: ConstructorMalla, c: Dictionary) -> void:
	var m: MarcoEdificio = MarcoEdificio.new().configurar(c)
	var y: float = m.y
	var alto: float = float(c["alto"])
	var col: Color = c["color"]
	var g: float = MarcoEdificio.GROSOR
	var y0: float = y - 0.1
	var y1: float = y + alto + 0.1
	var vent: Color = [Color(0.12, 0.17, 0.26), Color(0.16, 0.2, 0.2), Color(0.2, 0.17, 0.12)][int(c.get("var", 0)) % 3]
	var marco: Color = col.lightened(0.25)
	var pisos: int = m.pisos
	# Muros laterales (macizos, de arriba abajo).
	for lado in [-1.0, 1.0]:
		m.caja_en(mb, lado * (m.W / 2.0 + g / 2.0), m.D / 2.0, (y0 + y1) / 2.0, g, y1 - y0, m.D + 2.0 * g, col)
	# Muros de delante y de detrás, piso a piso (puerta solo abajo; ventanas en todos).
	var xs: Array = ventanas_x(float(c["w"]))
	for n in pisos:
		var ya: float = y0 if n == 0 else m.suelo_y(n) - 0.2
		var yb: float = y1 if n == pisos - 1 else m.suelo_y(n + 1) - 0.2
		var piso_y: float = m.suelo_y(n)
		var v_bajo: float = piso_y + (VENT_BAJO - 0.1)
		var v_alto: float = piso_y + (VENT_ALTO - 0.1)
		var huecos: Array = []
		for vx in xs:
			huecos.append([vx, VENT_ANCHO, v_bajo, v_alto])
		var huecos_f: Array = huecos.duplicate()
		if n == 0:
			huecos_f.append([0.0, PUERTA_ANCHO, y - 0.05, y + PUERTA_ALTO])
		huecos_f.sort_custom(func(a, b): return a[0] < b[0])
		_muro(mb, m, -g / 2.0, ya, yb, col, huecos_f)
		_muro(mb, m, m.D + g / 2.0, ya, yb, col, huecos)
		# Cristales (los de dentro se ven igual de oscuros), marcos y alféizares.
		for atras in [false, true]:
			var iv_c: float = m.D + g / 2.0 if atras else -g / 2.0
			var fuera: float = 0.1 if atras else -0.1
			for vx in xs:
				var yc: float = (v_bajo + v_alto) / 2.0
				m.caja_en(mb, vx, iv_c, yc, VENT_ANCHO, v_alto - v_bajo, 0.06, vent)
				m.caja_en(mb, vx, iv_c, yc, 0.06, v_alto - v_bajo, 0.08, marco)
				m.caja_en(mb, vx, iv_c + fuera, v_bajo - 0.04, VENT_ANCHO + 0.3, 0.08, g + 0.2, marco)
	# Marco de la puerta.
	for lado in [-1.0, 1.0]:
		m.caja_en(mb, lado * (PUERTA_ANCHO / 2.0 + 0.04), -g / 2.0, y + PUERTA_ALTO / 2.0, 0.08, PUERTA_ALTO, g + 0.04, marco.darkened(0.4))
	# Suelo de la planta baja.
	m.caja_en(mb, 0.0, m.D / 2.0, y + 0.05, m.W, 0.1, m.D, COLOR_SUELO)
	# Techo de cada piso: con hueco de escalera salvo el último.
	var e: Dictionary = EscaleraEdificio.de(c)
	var col_t: Color = col.lightened(0.1)
	for n in range(1, pisos + 1):
		var yc: float = m.suelo_y(n) - 0.1
		if n < pisos and not e.is_empty():
			var b: Rect2 = e["bloque"]
			m.caja_en(mb, 0.0, b.position.y / 2.0, yc, m.W, 0.2, b.position.y, col_t)
			var u_a: float = -m.W / 2.0
			var u_b: float = b.position.x
			if float(e["lado"]) < 0.0:
				u_a = b.end.x
				u_b = m.W / 2.0
			m.caja_en(mb, (u_a + u_b) / 2.0, b.position.y + b.size.y / 2.0, yc, u_b - u_a, 0.2, b.size.y, col_t)
		else:
			m.caja_en(mb, 0.0, m.D / 2.0, yc, m.W, 0.2, m.D, col_t)
	EscaleraEdificio.emitir(mb, c)


# Muro recto a lo largo de u (en el plano), centrado en "iv_c", de la altura ya a yb, con huecos
# [u_centro, ancho, y_bajo, y_alto] (ordenados por u). Cubre de u = -W/2 a +W/2.
static func _muro(mb: ConstructorMalla, m: MarcoEdificio, iv_c: float, ya: float, yb: float, col: Color, huecos: Array) -> void:
	var g: float = MarcoEdificio.GROSOR
	var cursor: float = -m.W / 2.0
	for h in huecos:
		var hc: float = h[0]
		var hw: float = h[1]
		var izq: float = hc - hw / 2.0
		if izq - cursor > 0.01:
			m.caja_en(mb, (cursor + izq) / 2.0, iv_c, (ya + yb) / 2.0, izq - cursor, yb - ya, g, col)
		if float(h[2]) - ya > 0.12:
			m.caja_en(mb, hc, iv_c, (ya + float(h[2])) / 2.0, hw, float(h[2]) - ya, g, col)
		if yb - float(h[3]) > 0.01:
			m.caja_en(mb, hc, iv_c, (float(h[3]) + yb) / 2.0, hw, yb - float(h[3]), g, col)
		cursor = hc + hw / 2.0
	var fin: float = m.W / 2.0
	if fin - cursor > 0.01:
		m.caja_en(mb, (cursor + fin) / 2.0, iv_c, (ya + yb) / 2.0, fin - cursor, yb - ya, g, col)
