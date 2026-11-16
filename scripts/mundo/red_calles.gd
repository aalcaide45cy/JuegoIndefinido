# red_calles.gd
# -----------------------------------------------------------------------------
# La red de calles de la ciudad como DATOS (no como escena): una lista de tramos
# rectos con su ancho. Sirve para tres cosas que vendrán después:
#   - dibujar el mapa grande y el minimapa sin necesidad de la escena 3D,
#   - el tráfico (los coches siguen los tramos y giran en los cruces),
#   - decidir dónde colocar coches aparcados, compradores y peatones.
# Coordenadas de mundo (x, z) en metros. SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name RedCalles
extends RefCounted

# Cada tramo: [inicio (x, z), fin (x, z), ancho]
const TRAMOS: Array = [
	[Vector2(16, -20), Vector2(16, -102), 8.0],    # Calle norte hacia el Mercado.
	[Vector2(20, -16), Vector2(102, -16), 8.0],    # Calle este hacia el Barrio Residencial.
	[Vector2(-16, 20), Vector2(-16, 102), 8.0],    # Calle sur hacia la Zona Industrial.
	[Vector2(-20, 0), Vector2(20, 0), 10.0],       # Plaza (cruce central, simplificado).
	[Vector2(0, -20), Vector2(0, 20), 10.0],
]


# Punto del tramo más cercano a "p" (para colocar cosas pegadas a la calle).
static func punto_mas_cercano(p: Vector2) -> Vector2:
	var mejor: Vector2 = Vector2.ZERO
	var d_mejor: float = INF
	for t in TRAMOS:
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, t[0], t[1])
		var d: float = q.distance_squared_to(p)
		if d < d_mejor:
			d_mejor = d
			mejor = q
	return mejor


# Límites (Rect2) que cubren toda la red, con un margen en metros.
static func limites(margen: float = 20.0) -> Rect2:
	var r: Rect2 = Rect2(TRAMOS[0][0], Vector2.ZERO)
	for t in TRAMOS:
		r = r.expand(t[0]).expand(t[1])
	return r.grow(margen)
