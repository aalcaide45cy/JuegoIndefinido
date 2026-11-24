# regiones.gd
# -----------------------------------------------------------------------------
# La economía cambia según DÓNDE estés (ver GeneradorMundo): cada región paga
# distinto las ventas por la ventanilla y genera encargos distintos.
#   precio:   multiplicador de lo que te pagan al vender una poción por la ventanilla.
#   encargo:  multiplicador del pago de los encargos del móvil.
#   cantidad: unidades extra que piden los encargos.
#   gusto:    qué pociones piden: "baratas", "variadas" o "caras" (por su precio).
#   cadencia: multiplicador del tiempo entre encargos (menos de 1 = llegan más seguido).
# -----------------------------------------------------------------------------
class_name Regiones
extends RefCounted

const LISTA: Dictionary = {
	"ciudad_original": {"nombre": "Ciudad original", "precio": 1.0, "encargo": 1.0, "cantidad": 0, "gusto": "variadas", "cadencia": 1.0},
	"ciudad": {"nombre": "Ciudad", "precio": 1.12, "encargo": 1.2, "cantidad": 0, "gusto": "caras", "cadencia": 0.8},
	"pueblo": {"nombre": "Pueblo", "precio": 1.0, "encargo": 1.0, "cantidad": 1, "gusto": "variadas", "cadencia": 1.0},
	"aldea": {"nombre": "Aldea", "precio": 0.9, "encargo": 0.85, "cantidad": 2, "gusto": "baratas", "cadencia": 1.2},
	"montana": {"nombre": "Montaña", "precio": 1.3, "encargo": 1.45, "cantidad": 0, "gusto": "caras", "cadencia": 1.6},
	"campo": {"nombre": "Campo", "precio": 0.95, "encargo": 0.95, "cantidad": 1, "gusto": "baratas", "cadencia": 1.3},
}


# Región de una posición del mundo.
static func de_posicion(x: float, z: float) -> Dictionary:
	var id: String = "campo"
	var punto: Vector2 = Vector2(x, z)
	if GeneradorMundo.nucleo.grow(30.0).has_point(punto):
		id = "ciudad_original"
	else:
		var hallado: bool = false
		for s in GeneradorMundo.asentamientos_cerca(Rect2(x - 2.0, z - 2.0, 4.0, 4.0)):
			var p: Vector2 = s["pos"]
			var radio: float = float(s["mitad"]) + 60.0
			if absf(x - p.x) <= radio and absf(z - p.y) <= radio:
				id = ["aldea", "pueblo", "ciudad"][clampi(int(s["tipo"]), 0, 2)]
				hallado = true
				break
		if not hallado and GeneradorMundo.altura(x, z) > 60.0:
			id = "montana"
	var r: Dictionary = (LISTA[id] as Dictionary).duplicate()
	r["id"] = id
	return r


# Región donde está el jugador ahora (la ciudad original si no hay jugador).
static func actual() -> Dictionary:
	var arbol: SceneTree = Engine.get_main_loop() as SceneTree
	var j: Node3D = arbol.get_first_node_in_group("jugador") as Node3D if arbol != null else null
	if j == null:
		return de_posicion(0.0, 0.0)
	return de_posicion(j.global_position.x, j.global_position.z)


# Elige una poción según el gusto de la región (ordenadas por precio).
static func elegir_pocion(ids: Array, gusto: String) -> String:
	var ordenadas: Array = ids.duplicate()
	ordenadas.sort_custom(func(a: String, b: String) -> bool: return int(GameData.pocion(a)["precio"]) < int(GameData.pocion(b)["precio"]))
	var n: int = ordenadas.size()
	var desde: int = 0
	var hasta: int = n
	if n >= 2:
		var mitad: int = (n + 1) / 2   # Con 3 pociones, las baratas son las 2 primeras y las caras las 2 últimas.
		if gusto == "baratas":
			hasta = mitad
		elif gusto == "caras":
			desde = n - mitad
	return str(ordenadas[randi_range(desde, hasta - 1)])
