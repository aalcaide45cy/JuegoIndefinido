# brujula.gd
# -----------------------------------------------------------------------------
# La brújula: una tira horizontal arriba en el centro de la pantalla que
# muestra hacia dónde miras (N, NE, E, SE, S, SO, O, NO y los grados), como en
# los juegos de ciudad. Los puntos de interés (tiendas y casas, grupo "poi")
# aparecen como rombos de colores, y debajo se escribe el nombre y la
# distancia del más cercano.
# -----------------------------------------------------------------------------
class_name Brujula
extends Control

const ANCHO_VISTA: float = 140.0     # Grados que se ven a la vez (70 a cada lado).
const LETRAS: Dictionary = {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SO", 270: "O", 315: "NO"}

var _jugador: Jugador


func _ready() -> void:
	custom_minimum_size = Vector2(520, 60)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if _jugador == null:
		_jugador = get_tree().get_first_node_in_group("jugador") as Jugador
	queue_redraw()


# Diferencia entre dos ángulos en grados, entre -180 y 180.
func _diferencia(a: float, b: float) -> float:
	return fposmod(a - b + 180.0, 360.0) - 180.0


func _draw() -> void:
	if _jugador == null:
		return
	var fuente: Font = ThemeDB.fallback_font
	var ancho: float = size.x
	var centro_x: float = ancho / 2.0
	var alto_tira: float = 30.0
	# Rumbo en grados, de 0 (norte) a 360, creciendo hacia la derecha.
	var rumbo: float = fposmod(-rad_to_deg(_jugador._giro), 360.0)

	# Fondo de la tira, más transparente hacia los lados.
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(0.05, 0.06, 0.07, 0.72)
	estilo.border_color = Color(0.88, 0.74, 0.38, 0.8)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(8)
	estilo.corner_detail = 1   # Esquina cortada: estilo low poly
	draw_style_box(estilo, Rect2(0, 0, ancho, alto_tira))

	# Marcas cada 5 grados; letras en los puntos cardinales.
	for grados in range(0, 360, 5):
		var d: float = _diferencia(float(grados), rumbo)
		if absf(d) > ANCHO_VISTA / 2.0:
			continue
		var x: float = centro_x + d / (ANCHO_VISTA / 2.0) * (ancho / 2.0 - 10.0)
		var alfa: float = 1.0 - absf(d) / (ANCHO_VISTA / 2.0) * 0.7
		if LETRAS.has(grados):
			var texto: String = LETRAS[grados]
			var color: Color = Color(1.0, 0.45, 0.4, alfa) if grados == 0 else Color(0.95, 0.93, 0.8, alfa)
			var tam: int = 20 if texto.length() == 1 else 15
			var ancho_t: float = fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
			draw_string(fuente, Vector2(x - ancho_t / 2.0, 22), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, color)
		elif grados % 15 == 0:
			draw_line(Vector2(x, 9), Vector2(x, 21), Color(0.9, 0.88, 0.75, alfa * 0.8), 1.5)
		else:
			draw_line(Vector2(x, 13), Vector2(x, 19), Color(0.9, 0.88, 0.75, alfa * 0.5), 1.0)

	# Puntos de interés: rombos de colores sobre la tira.
	var cercano_nombre: String = ""
	var cercano_dist: float = INF
	for nodo in get_tree().get_nodes_in_group("poi"):
		var poi: Node3D = nodo as Node3D
		var rel: Vector3 = poi.global_position - _jugador.global_position
		var distancia: float = Vector2(rel.x, rel.z).length()
		var rumbo_poi: float = fposmod(rad_to_deg(atan2(rel.x, -rel.z)), 360.0)
		var d: float = _diferencia(rumbo_poi, rumbo)
		if distancia < cercano_dist:
			cercano_dist = distancia
			cercano_nombre = poi.get_meta("poi_nombre", "")
		if absf(d) > ANCHO_VISTA / 2.0:
			continue
		var x: float = centro_x + d / (ANCHO_VISTA / 2.0) * (ancho / 2.0 - 10.0)
		var color: Color = poi.get_meta("poi_color", Color.WHITE)
		if bool(poi.get_meta("poi_grande", false)):
			var r: float = 9.0 + 2.0 * sin(Time.get_ticks_msec() / 160.0)
			draw_circle(Vector2(x, 8), r + 2.0, Color(0, 0, 0, 0.9))
			draw_circle(Vector2(x, 8), r, Color(1.0, 0.55, 0.1))
			var txt: String = "%d m" % int(distancia)
			draw_string_outline(fuente, Vector2(x - 14, 30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
			draw_string(fuente, Vector2(x - 14, 30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.85, 0.5))
			continue
		draw_colored_polygon(PackedVector2Array([Vector2(x, 2), Vector2(x + 6, 8), Vector2(x, 14), Vector2(x - 6, 8)]),
				Color(0, 0, 0, 0.85))
		draw_colored_polygon(PackedVector2Array([Vector2(x, 4), Vector2(x + 4.5, 8), Vector2(x, 12), Vector2(x - 4.5, 8)]),
				color)

	# Marca del centro (hacia dónde miras) y los grados.
	draw_colored_polygon(PackedVector2Array([Vector2(centro_x - 6, alto_tira + 2), Vector2(centro_x + 6, alto_tira + 2),
			Vector2(centro_x, alto_tira - 6)]), Color(1.0, 0.92, 0.55))
	var grados_texto: String = "%d°" % int(round(rumbo))
	draw_string_outline(fuente, Vector2(centro_x + 12, alto_tira + 14), grados_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
	draw_string(fuente, Vector2(centro_x + 12, alto_tira + 14), grados_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.9, 0.9, 0.8))

	# El sitio más cercano, con su distancia, si está a menos de 40 m.
	if cercano_dist < 40.0 and cercano_nombre != "":
		var texto_poi: String = "%s  ·  %d m" % [cercano_nombre, int(cercano_dist)]
		var ancho_p: float = fuente.get_string_size(texto_poi, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string_outline(fuente, Vector2(centro_x - ancho_p / 2.0, alto_tira + 32), texto_poi,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.BLACK)
		draw_string(fuente, Vector2(centro_x - ancho_p / 2.0, alto_tira + 32), texto_poi,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.95, 0.7))
