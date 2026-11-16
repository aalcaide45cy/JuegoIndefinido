# caldero.gd
# -----------------------------------------------------------------------------
# El caldero donde se mezclan las pociones.
# Guarda la lista de ingredientes que has echado y los dibuja como un líquido
# de color con burbujas. La lógica de "qué poción sale" está en GameData.
# -----------------------------------------------------------------------------
class_name Caldero
extends Control

# Ingredientes echados, por ejemplo ["risuena", "seta"].
var ingredientes: Array[String] = []

# Pequeño efecto visual: cuando mezclas, el caldero "salta" un momento.
var _sacudida: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(240, 200)


func _process(delta: float) -> void:
	if _sacudida > 0.0:
		_sacudida = maxf(0.0, _sacudida - delta * 3.0)
	queue_redraw()  # Redibujamos siempre para animar las burbujas.


func esta_lleno() -> bool:
	return ingredientes.size() >= GameData.INGREDIENTES_POR_POCION


func echar(id_hierba: String) -> void:
	ingredientes.append(id_hierba)


func vaciar() -> void:
	ingredientes.clear()


# Llama a esto al mezclar para que el caldero dé un saltito.
func sacudir() -> void:
	_sacudida = 1.0


# Mezcla de colores de todos los ingredientes (para pintar el líquido).
func _color_liquido() -> Color:
	if ingredientes.is_empty():
		return Color(0.25, 0.35, 0.45)  # Agua sola.
	var total: Color = Color(0, 0, 0)
	for id_hierba in ingredientes:
		var c: Color = GameData.HIERBAS[id_hierba]["color"]
		total.r += c.r
		total.g += c.g
		total.b += c.b
	var n: float = float(ingredientes.size())
	return Color(total.r / n, total.g / n, total.b / n)


# --------------------------- DIBUJO ------------------------------------------
func _draw() -> void:
	var centro: Vector2 = Vector2(size.x * 0.5, size.y * 0.55)
	centro.y -= sin(_sacudida * PI) * 12.0  # El saltito al mezclar.
	var radio: float = minf(size.x, size.y) * 0.38

	# Fuego debajo (tres triángulos naranjas que tiemblan).
	var t: float = Time.get_ticks_msec() / 150.0
	for i in 3:
		var x: float = centro.x + (i - 1) * radio * 0.5
		var alto_llama: float = 22.0 + 6.0 * sin(t + i * 2.0)
		var llama: PackedVector2Array = [
			Vector2(x - 12, size.y - 4),
			Vector2(x + 12, size.y - 4),
			Vector2(x, size.y - 4 - alto_llama),
		]
		draw_colored_polygon(llama, Color(1.0, 0.55, 0.1))

	# Cuerpo del caldero: un círculo negro grande.
	draw_circle(centro, radio, Color(0.12, 0.12, 0.14))
	# Boca del caldero: una elipse hecha con un círculo achatado.
	var boca_centro: Vector2 = centro - Vector2(0, radio * 0.55)
	draw_set_transform(boca_centro, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, radio * 0.85, Color(0.2, 0.2, 0.22))
	draw_circle(Vector2.ZERO, radio * 0.75, _color_liquido())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)  # Volvemos a la normalidad.

	# Burbujas que suben si hay ingredientes.
	if not ingredientes.is_empty():
		for i in 4:
			var fase: float = fmod(t * 0.3 + i * 0.25, 1.0)
			var bx: float = boca_centro.x + (i - 1.5) * radio * 0.35
			var by: float = boca_centro.y - fase * 40.0
			draw_circle(Vector2(bx, by), 5.0 * (1.0 - fase), _color_liquido().lightened(0.3))

	# Texto con los ingredientes que hay dentro.
	var nombres: PackedStringArray = []
	for id_hierba in ingredientes:
		nombres.append(GameData.HIERBAS[id_hierba]["nombre"])
	var texto: String = "Vacío" if nombres.is_empty() else " + ".join(nombres)
	texto += "  (%d/%d)" % [ingredientes.size(), GameData.INGREDIENTES_POR_POCION]
	draw_string(get_theme_default_font(), Vector2(0, 18), texto,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(0.9, 0.9, 0.85))
