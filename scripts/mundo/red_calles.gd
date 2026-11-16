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


# Nodos por los que caminan los guardias (mundo, y = 0) y con qué nodos se unen.
# Dentro de la plaza van por las esquinas (la fuente está en el centro).
const NODOS: Dictionary = {
	# (A 12 m del centro: a 15 m chocaban con los barriles, el carro y los puestos
	# de la plaza y los guardias se quedaban atascados para siempre.)
	"pne": Vector3(12, 0, -12), "pse": Vector3(12, 0, 12), "psw": Vector3(-12, 0, 12), "pnw": Vector3(-12, 0, -12),
	"n20": Vector3(16, 0, -22), "mercado": Vector3(16, 0, -58),
	"e20": Vector3(22, 0, -16), "residencial": Vector3(58, 0, -16),
	"s20": Vector3(-16, 0, 22), "industrial": Vector3(-16, 0, 58),
}
const VECINOS: Dictionary = {
	"pne": ["pse", "pnw", "n20", "e20"], "pse": ["pne", "psw"], "psw": ["pse", "pnw", "s20"], "pnw": ["psw", "pne"],
	"n20": ["pne", "mercado"], "mercado": ["n20"],
	"e20": ["pne", "residencial"], "residencial": ["e20"],
	"s20": ["psw", "industrial"], "industrial": ["s20"],
}


static func nodo_mas_cercano(p: Vector3) -> String:
	var mejor: String = "pne"
	var d_mejor: float = INF
	for id in NODOS:
		var d: float = (NODOS[id] as Vector3).distance_squared_to(p)
		if d < d_mejor:
			d_mejor = d
			mejor = id
	return mejor
