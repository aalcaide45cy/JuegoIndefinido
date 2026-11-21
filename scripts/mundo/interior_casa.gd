# interior_casa.gd
# -----------------------------------------------------------------------------
# Reparto de habitaciones y muebles del interior de una casa del mundo grande.
# Solo calcula DATOS (cajas con posición, tamaño y color), así que es barato y
# siempre da el mismo resultado para la misma casa. Quien lo convierte en
# nodos es GestorInteriores, y solo cuando el jugador se acerca.
#
# Tipos de interior (según el distrito de la casa):
#   vivienda : casas normales y de barrio rico. Si es grande: salón + cocina
#              delante y 2-3 habitaciones detrás (dormitorio, baño, estudio).
#              Si es pequeña: una sola sala con cama, cocina, mesa y sofá.
#   tienda   : casas del centro. Mostrador, estanterías con productos.
#   almacen  : casas del distrito industrial. Estanterías, cajas y barriles.
#
# Coordenadas del plano (las de la casa vista desde su puerta):
#   u  = a lo ancho (de -W/2 a +W/2, 0 = centro de la casa)
#   iv = a lo hondo, desde el muro de la puerta (0) hasta el del fondo (D)
# W y D son las medidas INTERIORES (sin el grosor de los muros).
# -----------------------------------------------------------------------------
class_name InteriorCasa
extends RefCounted

const ALTO_INT: float = 3.0     # Altura libre de la planta baja (del suelo al techo).
const TABIQUE: float = 0.15     # Grosor de las paredes interiores.
const GAP: float = 1.0          # Ancho de las puertas entre habitaciones.

const MADERAS: Array = [Color(0.45, 0.3, 0.18), Color(0.55, 0.4, 0.25), Color(0.35, 0.25, 0.18), Color(0.6, 0.5, 0.35)]
const TELAS: Array = [Color(0.6, 0.2, 0.2), Color(0.2, 0.35, 0.5), Color(0.3, 0.5, 0.35), Color(0.7, 0.6, 0.3), Color(0.5, 0.35, 0.55)]
const BLANCO: Color = Color(0.9, 0.9, 0.88)
const METAL: Color = Color(0.55, 0.57, 0.6)
const NEGRO: Color = Color(0.08, 0.08, 0.1)


# Un reparto en marcha. cajas: [pos(mundo), tam, color, solido]. habitaciones: Rect2 en coordenadas de mundo (x, z).
class Plano:
	var x: float
	var y: float
	var z: float
	var cara: float
	var W: float
	var D: float
	var cajas: Array = []
	var luces: Array = []
	var habitaciones: Array = []
	var camas: Array = []      # Para los asaltos: [{"pos": centro de la cama (mundo), "yaw": giro del que duerme}].
	var muebles: Array = []    # Para los asaltos: [{"tipo": cajon|joyero|armario, "pos": mundo}].
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var madera: Color
	var tela: Color

	# Caja centrada en (u, iv) con alto de centro h y tamaño (su a lo ancho, sh alto, sv a lo hondo).
	func caja(u: float, iv: float, h: float, su: float, sh: float, sv: float, col: Color, solido: bool = true) -> void:
		cajas.append([Vector3(x + u, y + 0.1 + h, z + cara * (D / 2.0 - iv)), Vector3(su, sh, sv), col, solido])

	# Pieza pegada a una pared de la sala r (Rect2: x=u0, y=iv0, w=ancho, h=hondo).
	# lx = a lo largo de la pared, lz = separación de la pared hacia dentro.
	func pieza(r: Rect2, pared: String, a: float, off: float, lx: float, ly: float, lz: float,
			sx: float, sy: float, sz: float, col: Color, solido: bool = true) -> void:
		var u0: float = r.position.x
		var u1: float = r.end.x
		var v0: float = r.position.y
		var v1: float = r.end.y
		lz += off
		match pared:
			"S":
				caja(a + lx, v0 + lz, ly, sx, sy, sz, col, solido)
			"N":
				caja(a + lx, v1 - lz, ly, sx, sy, sz, col, solido)
			"W":
				caja(u0 + lz, a + lx, ly, sz, sy, sx, col, solido)
			"E":
				caja(u1 - lz, a + lx, ly, sz, sy, sx, col, solido)

	func luz(u: float, iv: float, h: float) -> void:
		luces.append(Vector3(x + u, y + 0.1 + h, z + cara * (D / 2.0 - iv)))

	func sala(r: Rect2) -> void:
		var za: float = z + cara * (D / 2.0 - r.position.y)
		var zb: float = z + cara * (D / 2.0 - r.end.y)
		habitaciones.append(Rect2(x + r.position.x, minf(za, zb), r.size.x, absf(za - zb)))

	# Anota la cama cuya primera caja es cajas[desde]: el que duerme se tumba con la cabeza hacia la pared más cercana.
	func anotar_cama(desde: int) -> void:
		var cj: Array = cajas[desde]
		var pos: Vector3 = cj[0]
		var tam: Vector3 = cj[1]
		var yaw: float = 0.0
		var rel_x: float = pos.x - x
		var rel_z: float = pos.z - z
		if tam.x > tam.z:
			yaw = -PI / 2.0 if rel_x > 0.0 else PI / 2.0
		else:
			yaw = 0.0 if rel_z * cara < 0.0 else PI
		camas.append({"pos": pos, "yaw": yaw})

	# Anota un mueble con botín cuya primera caja es cajas[desde].
	func anotar_mueble(desde: int, tipo: String) -> void:
		muebles.append({"tipo": tipo, "pos": (cajas[desde] as Array)[0]})

	func color_madera() -> Color:
		return madera

	func color_tela() -> Color:
		return tela


# ------------------------------------------------------------------------------
# Punto de entrada: devuelve {"cajas", "luces", "habitaciones", "tipo", "entrada"}.
# ------------------------------------------------------------------------------
static func generar(c: Dictionary) -> Dictionary:
	var P: Plano = Plano.new()
	var g: float = GeneradorMundo.GROSOR_MURO
	P.x = c["x"]
	P.y = c["y"]
	P.z = c["z"]
	P.cara = float(c["puerta"])
	P.W = float(c["w"]) - 2.0 * g
	P.D = float(c["d"]) - 2.0 * g
	P.rng.seed = int(c.get("var", 0)) * 7919 + int(absf(P.x) * 13.0) + int(absf(P.z) * 29.0) + 17
	P.madera = MADERAS[P.rng.randi() % MADERAS.size()]
	P.tela = TELAS[P.rng.randi() % TELAS.size()]
	var tipo: String = "vivienda"
	var distrito: String = str(c.get("distrito", ""))
	if distrito == "industrial":
		tipo = "almacen"
	elif distrito == "centro":
		tipo = "tienda"
	match tipo:
		"almacen":
			_almacen(P)
		"tienda":
			_tienda(P)
		_:
			if P.W < 8.5 or P.D < 7.5:
				_vivienda_pequena(P)
			else:
				_vivienda_grande(P, distrito == "rico")
	return {"cajas": P.cajas, "luces": P.luces, "habitaciones": P.habitaciones, "tipo": tipo,
			"camas": P.camas, "muebles": P.muebles,
			"entrada": Vector3(P.x, P.y + 0.1, P.z + P.cara * (P.D / 2.0 - 0.6))}


# ------------------------------- Muebles ---------------------------------------

static func _cama(P: Plano, r: Rect2, pared: String, a: float, off: float = 0.0) -> void:
	var m: Color = P.color_madera()
	var n0: int = P.cajas.size()
	P.pieza(r, pared, a, off, 0, 0.28, 1.0, 1.5, 0.4, 2.0, m)
	P.pieza(r, pared, a, off, 0, 0.55, 1.1, 1.42, 0.18, 1.8, P.color_tela())
	P.pieza(r, pared, a, off, 0, 0.7, 0.38, 1.1, 0.14, 0.4, BLANCO, false)
	P.pieza(r, pared, a, off, 0, 0.65, 0.06, 1.6, 1.0, 0.1, m)
	P.anotar_cama(n0)


static func _mesilla(P: Plano, r: Rect2, pared: String, a: float) -> void:
	var n0: int = P.cajas.size()
	P.pieza(r, pared, a, 0.0, 0, 0.25, 0.25, 0.45, 0.5, 0.45, P.color_madera())
	P.pieza(r, pared, a, 0.0, 0, 0.6, 0.25, 0.2, 0.16, 0.2, Color(0.95, 0.85, 0.4), false)
	P.anotar_mueble(n0, "joyero" if P.muebles.size() % 2 == 0 else "cajon")   # Asaltos: la mesilla de noche.


static func _armario(P: Plano, r: Rect2, pared: String, a: float) -> void:
	var n0: int = P.cajas.size()
	P.pieza(r, pared, a, 0.0, 0, 1.05, 0.35, 1.3, 2.1, 0.7, P.color_madera().darkened(0.15))
	for s in [-0.12, 0.12]:
		P.pieza(r, pared, a, 0.0, s, 1.0, 0.72, 0.05, 0.3, 0.03, METAL, false)
	P.anotar_mueble(n0, "armario")   # Asaltos.


static func _sofa(P: Plano, r: Rect2, pared: String, a: float, off: float = 0.0) -> void:
	var t: Color = P.color_tela()
	P.pieza(r, pared, a, off, 0, 0.65, 0.18, 2.0, 0.7, 0.36, t)
	P.pieza(r, pared, a, off, 0, 0.28, 0.55, 2.0, 0.5, 0.9, t.lightened(0.05))
	for s in [-0.95, 0.95]:
		P.pieza(r, pared, a, off, s, 0.5, 0.55, 0.18, 0.35, 0.9, t.darkened(0.15))


static func _tele(P: Plano, r: Rect2, pared: String, a: float) -> void:
	P.pieza(r, pared, a, 0.0, 0, 0.28, 0.25, 1.5, 0.56, 0.5, P.color_madera())
	P.pieza(r, pared, a, 0.0, 0, 0.88, 0.2, 1.0, 0.55, 0.07, NEGRO)


static func _estanteria(P: Plano, r: Rect2, pared: String, a: float) -> void:
	P.pieza(r, pared, a, 0.0, 0, 1.0, 0.2, 1.4, 2.0, 0.4, P.color_madera())
	for i in 3:
		var libro: Color = TELAS[(i + P.rng.randi()) % TELAS.size()]
		P.pieza(r, pared, a, 0.0, 0, 0.55 + i * 0.55, 0.37, 1.2, 0.3, 0.06, libro, false)


static func _encimera(P: Plano, r: Rect2, pared: String, a: float) -> void:
	P.pieza(r, pared, a, 0.0, 0, 0.45, 0.35, 2.0, 0.9, 0.7, Color(0.8, 0.78, 0.72))
	P.pieza(r, pared, a, 0.0, 0, 0.92, 0.37, 2.0, 0.05, 0.74, Color(0.25, 0.25, 0.28))
	P.pieza(r, pared, a, 0.0, 0.4, 0.95, 0.35, 0.6, 0.03, 0.45, METAL, false)


static func _nevera(P: Plano, r: Rect2, pared: String, a: float) -> void:
	P.pieza(r, pared, a, 0.0, 0, 0.95, 0.35, 0.7, 1.9, 0.7, Color(0.85, 0.85, 0.88))


static func _planta(P: Plano, r: Rect2, pared: String, a: float) -> void:
	P.pieza(r, pared, a, 0.0, 0, 0.2, 0.25, 0.35, 0.4, 0.35, Color(0.65, 0.35, 0.22))
	P.pieza(r, pared, a, 0.0, 0, 0.7, 0.25, 0.5, 0.6, 0.5, Color(0.2, 0.5, 0.25), false)


static func _inodoro(P: Plano, r: Rect2, pared: String, a: float) -> void:
	P.pieza(r, pared, a, 0.0, 0, 0.22, 0.36, 0.4, 0.44, 0.55, BLANCO)
	P.pieza(r, pared, a, 0.0, 0, 0.6, 0.12, 0.4, 0.4, 0.2, BLANCO)


static func _lavabo(P: Plano, r: Rect2, pared: String, a: float) -> void:
	P.pieza(r, pared, a, 0.0, 0, 0.82, 0.25, 0.55, 0.12, 0.4, BLANCO)
	P.pieza(r, pared, a, 0.0, 0, 0.4, 0.2, 0.2, 0.8, 0.2, BLANCO)
	P.pieza(r, pared, a, 0.0, 0, 1.55, 0.03, 0.5, 0.6, 0.04, Color(0.6, 0.72, 0.82), false)


static func _banera(P: Plano, r: Rect2, pared: String, a: float) -> void:
	P.pieza(r, pared, a, 0.0, 0, 0.3, 0.4, 1.7, 0.6, 0.8, BLANCO)
	P.pieza(r, pared, a, 0.0, 0, 0.61, 0.4, 1.5, 0.02, 0.6, Color(0.4, 0.65, 0.85), false)


static func _escritorio(P: Plano, r: Rect2, pared: String, a: float) -> void:
	var n0: int = P.cajas.size()
	var m: Color = P.color_madera()
	P.pieza(r, pared, a, 0.0, 0, 0.72, 0.35, 1.3, 0.06, 0.7, m)
	for s in [-0.6, 0.6]:
		P.pieza(r, pared, a, 0.0, s, 0.35, 0.35, 0.06, 0.7, 0.6, m.darkened(0.2))
	P.pieza(r, pared, a, 0.0, 0.2, 0.95, 0.2, 0.5, 0.3, 0.05, NEGRO, false)
	P.pieza(r, pared, a, 0.0, 0, 0.25, 0.9, 0.45, 0.5, 0.45, m.lightened(0.1))   # La silla.
	P.anotar_mueble(n0, "cajon")   # Asaltos.


static func _caja(P: Plano, r: Rect2, pared: String, a: float, off: float, lado: float) -> void:
	P.pieza(r, pared, a, off, 0, lado / 2.0, lado / 2.0 + 0.05, lado, lado, lado, Color(0.62, 0.48, 0.28).darkened(P.rng.randf() * 0.2))


static func _barril(P: Plano, r: Rect2, pared: String, a: float, off: float) -> void:
	P.pieza(r, pared, a, off, 0, 0.45, 0.35, 0.65, 0.9, 0.65, Color(0.4, 0.28, 0.15))
	P.pieza(r, pared, a, off, 0, 0.7, 0.35, 0.68, 0.06, 0.68, METAL.darkened(0.3), false)


static func _estante_metal(P: Plano, r: Rect2, pared: String, a: float, largo: float = 1.6) -> void:
	P.pieza(r, pared, a, 0.0, 0, 1.1, 0.25, largo, 2.2, 0.5, METAL.darkened(0.1))
	for i in 3:
		var col: Color = TELAS[P.rng.randi() % TELAS.size()].darkened(0.2)
		for k in 2:
			P.pieza(r, pared, a, 0.0, (k - 0.5) * largo * 0.45, 0.35 + i * 0.7, 0.5, largo * 0.35, 0.4, 0.15, col, false)


static func _mesa_libre(P: Plano, u: float, iv: float, su: float, sv: float) -> void:
	var m: Color = P.color_madera()
	P.caja(u, iv, 0.76, su, 0.08, sv, m)
	for dx in [-1.0, 1.0]:
		for dz in [-1.0, 1.0]:
			P.caja(u + dx * (su / 2.0 - 0.08), iv + dz * (sv / 2.0 - 0.08), 0.37, 0.08, 0.74, 0.08, m.darkened(0.2))
	for dz in [-1.0, 1.0]:
		P.caja(u, iv + dz * (sv / 2.0 + 0.3), 0.25, 0.4, 0.5, 0.4, m.lightened(0.1))


static func _alfombra(P: Plano, u: float, iv: float, su: float, sv: float, col: Color) -> void:
	P.caja(u, iv, 0.115, su, 0.03, sv, col, false)


# Pared interior a lo largo de X (eje "x", iv fijo) o de profundidad (eje "z", u fijo) con puertas.
# a0..a1 = tramo; huecos = centros de puertas. Alto total ALTO_INT; sobre la puerta hay dintel.
static func _tabique(P: Plano, eje: String, fijo: float, a0: float, a1: float, huecos: Array, col: Color) -> void:
	var cursor: float = a0
	var hs: Array = huecos.duplicate()
	hs.sort()
	for hc in hs:
		var izq: float = float(hc) - GAP / 2.0
		_tramo_tabique(P, eje, fijo, cursor, izq, 0.0, ALTO_INT, col)
		_tramo_tabique(P, eje, fijo, izq, float(hc) + GAP / 2.0, 2.1, ALTO_INT, col, false)
		cursor = float(hc) + GAP / 2.0
	_tramo_tabique(P, eje, fijo, cursor, a1, 0.0, ALTO_INT, col)


static func _tramo_tabique(P: Plano, eje: String, fijo: float, a: float, b: float, h0: float, h1: float,
		col: Color, solido: bool = true) -> void:
	if b - a < 0.02:
		return
	var m: float = (a + b) / 2.0
	var l: float = b - a
	var alto: float = h1 - h0
	if eje == "x":
		P.caja(m, fijo, (h0 + h1) / 2.0, l, alto, TABIQUE, col, solido)
	else:
		P.caja(fijo, m, (h0 + h1) / 2.0, TABIQUE, alto, l, col, solido)


# ------------------------------- Interiores -----------------------------------

static func _vivienda_pequena(P: Plano) -> void:
	var u0: float = -P.W / 2.0
	var u1: float = P.W / 2.0
	var D: float = P.D
	var r: Rect2 = Rect2(u0, 0.0, P.W, D)
	P.sala(r)
	# Dormitorio al fondo.
	_cama(P, r, "N", u0 + 0.95)
	_mesilla(P, r, "N", u0 + 2.1)
	_armario(P, r, "N", u1 - 0.75)
	# Cocina en la pared de la izquierda, junto a la puerta.
	_encimera(P, r, "W", 1.5)
	_nevera(P, r, "W", 3.15)
	# Estar a la derecha.
	_sofa(P, r, "E", D * 0.45 + 0.4)
	_estanteria(P, r, "E", 1.3)
	_mesa_libre(P, u0 + P.W * 0.5 - 0.3, D * 0.5, 1.3, 0.9)
	_alfombra(P, u1 - 1.4, D * 0.45 + 0.4, 1.8, 2.4, P.color_tela().darkened(0.2))
	_planta(P, r, "S", u1 - 0.5)
	P.luz(0.0, D * 0.5, 2.7)


static func _vivienda_grande(P: Plano, rico: bool) -> void:
	var u0: float = -P.W / 2.0
	var u1: float = P.W / 2.0
	var D: float = P.D
	var W: float = P.W
	var F: float = clampf(D * 0.55, 4.5, 7.0)
	F = minf(F, D - 3.0)
	var pared_c: Color = Color(0.82, 0.78, 0.7)
	var nb: int = 2 if W < 12.5 else 3
	var ancho_h: float = W / float(nb)
	var gaps: Array = []
	var centros: Array = []
	for i in nb:
		centros.append(u0 + ancho_h * (i + 0.5))
	gaps = centros.duplicate()
	# Paredes: la del salón (con una puerta por habitación) y las que separan las habitaciones.
	_tabique(P, "x", F, u0, u1, gaps, pared_c)
	for i in range(1, nb):
		_tabique(P, "z", u0 + ancho_h * i, F + TABIQUE / 2.0, D, [], pared_c)
	# Salón-cocina.
	var rf: Rect2 = Rect2(u0, 0.0, W, F - TABIQUE / 2.0)
	P.sala(rf)
	_encimera(P, rf, "W", 1.5)
	_nevera(P, rf, "W", 3.15)
	# La tele va en el tramo de pared sin puertas más ancho.
	var tramos: Array = []
	var ini: float = u0
	for gc in gaps:
		tramos.append([ini, float(gc) - GAP / 2.0])
		ini = float(gc) + GAP / 2.0
	tramos.append([ini, u1])
	var mejor: Array = tramos[0]
	for t in tramos:
		if float(t[1]) - float(t[0]) > float(mejor[1]) - float(mejor[0]):
			mejor = t
	var u_tv: float = (float(mejor[0]) + float(mejor[1])) / 2.0
	_tele(P, rf, "N", u_tv)
	_sofa(P, rf, "S", u_tv, 1.5)
	P.caja(u_tv, F - 2.4, 0.2, 1.0, 0.4, 0.6, P.color_madera().lightened(0.1))   # Mesita baja.
	_alfombra(P, u_tv, F - 2.55, 3.0, 2.2, P.color_tela().darkened(0.25))
	_mesa_libre(P, u1 - 1.6, 1.6, 1.3, 0.9)
	_estanteria(P, rf, "E", F * 0.62)
	_planta(P, rf, "S", u1 - 0.45)
	_planta(P, rf, "N", u0 + 0.45)
	if rico:
		P.pieza(rf, "E", F * 0.3, 0.0, 0, 0.45, 0.6, 1.5, 0.9, 1.2, NEGRO)          # Piano.
		P.pieza(rf, "E", F * 0.3, 0.0, 0, 0.92, 0.3, 1.4, 0.05, 0.5, BLANCO, false)
		P.luz(u_tv, F * 0.5, 2.8)
	P.luz(0.0, F * 0.45, 2.7)
	# Habitaciones del fondo.
	var tipos: Array = ["dormitorio", "bano", "estudio"] if nb == 3 else ["dormitorio", "bano"]
	if P.rng.randf() < 0.5:
		tipos.reverse()
	for i in nb:
		var ra: float = u0 + ancho_h * i + (TABIQUE / 2.0 if i > 0 else 0.0)
		var rb: float = u0 + ancho_h * (i + 1) - (TABIQUE / 2.0 if i < nb - 1 else 0.0)
		var rr: Rect2 = Rect2(ra, F + TABIQUE / 2.0, rb - ra, D - F - TABIQUE / 2.0)
		P.sala(rr)
		var cu: float = centros[i]
		var exterior: String = "W" if i == 0 else ("E" if i == nb - 1 else "")
		match tipos[i]:
			"dormitorio":
				_cama(P, rr, "N", cu)
				_mesilla(P, rr, "N", cu - 1.15)
				_mesilla(P, rr, "N", cu + 1.15)
				var lado: String = exterior if exterior != "" else ("W" if P.rng.randf() < 0.5 else "E")
				_armario(P, rr, lado, rr.position.y + rr.size.y * 0.5 + 0.2)
				_alfombra(P, cu, F + 1.3 + TABIQUE / 2.0, 1.8, 1.2, P.color_tela().darkened(0.25))
			"bano":
				_inodoro(P, rr, "N", cu - 0.85)
				_lavabo(P, rr, "N", cu + 0.85)
				_banera(P, rr, "W" if exterior != "E" else "E", D - 1.0)
			"estudio":
				_escritorio(P, rr, "N", cu)
				_estanteria(P, rr, "W" if exterior != "E" else "E", rr.position.y + rr.size.y * 0.5)
				_planta(P, rr, "S", rr.position.x + 0.45 if exterior != "W" else rr.end.x - 0.45)
		P.luz(cu, F + (D - F) * 0.5, 2.7)


static func _tienda(P: Plano) -> void:
	var u0: float = -P.W / 2.0
	var u1: float = P.W / 2.0
	var D: float = P.D
	var r: Rect2 = Rect2(u0, 0.0, P.W, D)
	P.sala(r)
	var m: Color = P.color_madera()
	# Mostrador cruzado al fondo, con la trastienda detrás y estanterías en la pared.
	var uc: float = u0 + P.W * 0.5
	P.pieza(r, "N", uc, 2.2, 0, 0.55, 0.4, minf(P.W - 3.0, 4.0), 1.1, 0.8, m)
	P.pieza(r, "N", uc, 2.2, 0, 1.12, 0.4, minf(P.W - 3.0, 4.0) + 0.1, 0.06, 0.9, m.lightened(0.15), false)
	P.pieza(r, "N", uc + 0.6, 2.2, 0, 1.25, 0.4, 0.4, 0.25, 0.3, METAL, false)   # La caja registradora.
	var n: int = maxi(2, int(P.W / 2.0))
	for i in n:
		var a: float = u0 + (i + 0.5) * P.W / float(n)
		_estanteria_tienda(P, r, "N", a)
	for lado in ["W", "E"]:
		for k in 2:
			_estanteria_tienda(P, r, lado, 1.5 + k * 2.2)
	_planta(P, r, "S", u1 - 0.5)
	P.luz(0.0, D * 0.4, 2.8)


static func _estanteria_tienda(P: Plano, r: Rect2, pared: String, a: float) -> void:
	P.pieza(r, pared, a, 0.0, 0, 1.0, 0.25, 1.5, 2.0, 0.5, P.color_madera().darkened(0.1))
	for i in 3:
		for k in 3:
			var col: Color = TELAS[P.rng.randi() % TELAS.size()].lightened(0.1)
			P.pieza(r, pared, a, 0.0, (k - 1) * 0.45, 0.5 + i * 0.6, 0.5, 0.32, 0.3, 0.2, col, false)


static func _almacen(P: Plano) -> void:
	var u0: float = -P.W / 2.0
	var u1: float = P.W / 2.0
	var D: float = P.D
	var r: Rect2 = Rect2(u0, 0.0, P.W, D)
	P.sala(r)
	var n: int = maxi(2, int(P.W / 2.4))
	for i in n:
		_estante_metal(P, r, "N", u0 + (i + 0.5) * P.W / float(n), 1.6)
	var a_w: float = 2.4
	while a_w + 0.9 <= D - 0.1:
		_estante_metal(P, r, "W", a_w, 1.6)
		a_w += 2.4
	# Banco de trabajo.
	P.pieza(r, "E", D * 0.55, 0.0, 0, 0.5, 0.45, 1.8, 1.0, 0.8, P.color_madera())
	P.pieza(r, "E", D * 0.55, 0.0, 0.3, 1.05, 0.45, 0.3, 0.1, 0.2, METAL, false)
	_barril(P, r, "S", u1 - 0.5, 0.0)
	_barril(P, r, "S", u1 - 1.3, 0.0)
	# Cajas apiladas en el centro (sin tapar el pasillo de la puerta).
	var puestos: Array = [Vector2(-1.8, 0.45), Vector2(1.6, 0.35), Vector2(-1.2, 0.55), Vector2(1.9, 0.6)]
	for i in 3:
		var pu: Vector2 = puestos[(i + P.rng.randi()) % puestos.size()]
		var uu: float = pu.x * P.W / 8.0
		var vv: float = D * pu.y
		P.caja(uu, vv, 0.35, 0.7, 0.7, 0.7, Color(0.62, 0.48, 0.28).darkened(P.rng.randf() * 0.2))
		if P.rng.randf() < 0.6:
			P.caja(uu, vv, 1.05, 0.6, 0.6, 0.6, Color(0.55, 0.42, 0.25))
	P.luz(0.0, D * 0.35, 2.8)
	P.luz(0.0, D * 0.75, 2.8)
