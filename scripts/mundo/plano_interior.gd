# plano_interior.gd
# -----------------------------------------------------------------------------
# Un reparto de interior en marcha: va juntando CAJAS (muebles, paredes de dentro, suelos de
# colores), luces y habitaciones de un edificio, planta por planta. Solo calcula DATOS (nada de
# nodos), así que es barato y siempre da el mismo resultado para el mismo edificio.
# Quien lo convierte en nodos es GestorInteriores, y solo cuando el jugador se acerca.
#
# Además sabe colocar muebles solo: "hueco" busca un sitio libre pegado a una pared de una
# habitación, sin tapar las puertas ni chocar con lo ya puesto.
# -----------------------------------------------------------------------------
class_name PlanoInterior
extends MarcoEdificio

const TABIQUE: float = 0.15     # Grosor de las paredes interiores.
const GAP: float = 1.0          # Ancho de las puertas entre habitaciones.

var cajas: Array = []           # [pos(mundo), tam, color, solido]
var luces: Array = []           # Vector3 (mundo)
var habitaciones: Array = []    # Rect2 (mundo) de la planta baja.
var salas: Array = []           # {"nivel", "rol", "rect" (plano), "mundo" (Rect2)} de todas las plantas.
var camas: Array = []           # Para los asaltos (solo planta baja).
var muebles: Array = []         # Para los asaltos (solo planta baja).
var paredes_info: Array = []    # Para las pruebas: tabiques con sus puertas.
var nombre_pieza_vital: bool = false   # La pieza que se está colocando no puede faltar (la cama).
var holg_extra: float = 0.0      # Más paso libre en las habitaciones estrechas.
var ocupado: Array = []         # Rect2 del plano que ya no se puede usar en esta planta.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var est: Dictionary = {}
var nivel: int = 0
var base_y: float = 0.0


func ir_a_nivel(n: int) -> void:
	nivel = n
	base_y = suelo_y(n)
	ocupado.clear()


# Caja centrada en (u, iv), con altura del centro "h" sobre el suelo de esta planta.
func caja(u: float, iv: float, h: float, su: float, sh: float, sv: float, col: Color, solido: bool = true) -> void:
	cajas.append([punto(u, iv, base_y + h), tam(su, sh, sv), col, solido])


# Pieza pegada a una pared de la sala r (Rect2 del plano: x = u0, y = iv0, ancho, hondo).
# pared: "S" (la de la puerta), "N" (la del fondo), "W" / "E" (laterales).
# a = posición a lo largo de la pared, lx = desplazamiento extra a lo largo, lz = separación
# de la pared hacia dentro (+ off).
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
	luces.append(punto(u, iv, base_y + h))


# Anota una sala (para las luces, las pruebas y los asaltos).
func sala(r: Rect2, rol: String) -> void:
	var rm: Rect2 = rect_mundo(r)
	if nivel == 0:
		habitaciones.append(rm)
	salas.append({"nivel": nivel, "rol": rol, "rect": r, "mundo": rm})


# Suelo de color de una sala (una lámina fina sin choque).
func suelo(r: Rect2, col: Color) -> void:
	caja(r.get_center().x, r.get_center().y, 0.012, r.size.x, 0.024, r.size.y, col, false)


# Marca una zona como ocupada (puertas, escalera...).
func reservar(r: Rect2) -> void:
	ocupado.append(r)


# Zona libre delante de una puerta de pared interior. eje "x": pared a lo largo de u en iv = fijo,
# puerta en u = hc. eje "z": pared a lo largo de iv en u = fijo, puerta en iv = hc.
func zona_puerta(eje: String, fijo: float, hc: float) -> void:
	if eje == "x":
		ocupado.append(Rect2(hc - 1.0, fijo - 1.2, 2.0, 2.4))
	else:
		ocupado.append(Rect2(fijo - 1.2, hc - 1.0, 2.4, 2.0))


func _huella(r: Rect2, pared: String, a: float, largo: float, fondo: float) -> Rect2:
	match pared:
		"S":
			return Rect2(a - largo / 2.0, r.position.y, largo, fondo)
		"N":
			return Rect2(a - largo / 2.0, r.end.y - fondo, largo, fondo)
		"W":
			return Rect2(r.position.x, a - largo / 2.0, fondo, largo)
	return Rect2(r.end.x - fondo, a - largo / 2.0, fondo, largo)


func _libre(rc: Rect2) -> bool:
	var chico: Rect2 = rc.grow(-0.04)
	for o in ocupado:
		if (o as Rect2).intersects(chico):
			return false
	return true


# Busca un sitio para un mueble de "largo" x "fondo" pegado a la pared. Devuelve la posición a lo
# largo de la pared (centro del mueble) o NAN si no cabe; si cabe, deja el sitio reservado.
# "pref" = posición preferida (si no, una al azar de las que caben). "holgura" = paso libre delante.
func hueco(r: Rect2, pared: String, largo: float, fondo: float, pref: float = NAN, holgura: float = 0.35) -> float:
	var a0: float
	var a1: float
	if pared == "S" or pared == "N":
		a0 = r.position.x + largo / 2.0 + 0.02
		a1 = r.end.x - largo / 2.0 - 0.02
	else:
		a0 = r.position.y + largo / 2.0 + 0.02
		a1 = r.end.y - largo / 2.0 - 0.02
	if a1 < a0 - 0.001:
		return NAN
	var f: float = fondo + holgura + holg_extra
	if holgura < 0.0:
		f = fondo
	if (pared == "S" or pared == "N") and f > r.size.y + 0.001:
		return NAN
	if (pared == "W" or pared == "E") and f > r.size.x + 0.001:
		return NAN
	var cand: Array = []
	var a: float = a0
	while a <= a1 + 0.001:
		if _libre(_huella(r, pared, a, largo, f)):
			cand.append(a)
		a += 0.25
	if cand.is_empty():
		if holgura >= 0.0 and nombre_pieza_vital:
			return hueco(r, pared, largo, fondo, pref, -1.0)   # Sin paso extra: más vale apretada que sin cama.
		return NAN
	var elegido: float = cand[rng.randi() % cand.size()]
	if not is_nan(pref):
		var mejor: float = 1.0e9
		for v in cand:
			if absf(float(v) - pref) < mejor:
				mejor = absf(float(v) - pref)
				elegido = v
	ocupado.append(_huella(r, pared, elegido, largo, f))
	return elegido


# Sitio libre en el interior de una sala (para mesas y alfombras), a "margen" m de las paredes.
# Devuelve el centro (u, iv) o null; si cabe, lo deja reservado con un paso de 0,35 m alrededor.
func centro_libre(r: Rect2, su: float, sv: float, margen: float = 0.8, paso: float = 0.35):
	var lx0: float = r.position.x + margen + su / 2.0
	var lx1: float = r.end.x - margen - su / 2.0
	var lz0: float = r.position.y + margen + sv / 2.0
	var lz1: float = r.end.y - margen - sv / 2.0
	if lx1 < lx0 or lz1 < lz0:
		return null
	for i in 24:
		var p: Vector2 = Vector2(rng.randf_range(lx0, lx1), rng.randf_range(lz0, lz1))
		var rc: Rect2 = Rect2(p.x - su / 2.0 - paso, p.y - sv / 2.0 - paso, su + 2.0 * paso, sv + 2.0 * paso)
		if _libre(rc):
			ocupado.append(rc)
			return p
	return null


func color_madera() -> Color:
	return est["madera"]


func color_tela() -> Color:
	var t: Array = est["tela"]
	return t[rng.randi() % t.size()]


# Anota la cama cuya primera caja es cajas[desde]: el que duerme se tumba con la cabeza hacia la pared más cercana.
func anotar_cama(desde: int) -> void:
	var cj: Array = cajas[desde]
	var pos: Vector3 = cj[0]
	var tm: Vector3 = cj[1]
	var yaw: float = 0.0
	var rel_x: float = pos.x - x
	var rel_z: float = pos.z - z
	if tm.x > tm.z:
		yaw = -PI / 2.0 if rel_x > 0.0 else PI / 2.0
	else:
		yaw = 0.0 if rel_z * cara < 0.0 else PI
	camas.append({"pos": pos, "yaw": yaw})


# Anota un mueble con botín cuya primera caja es cajas[desde].
func anotar_mueble(desde: int, tipo: String) -> void:
	muebles.append({"tipo": tipo, "pos": (cajas[desde] as Array)[0]})
