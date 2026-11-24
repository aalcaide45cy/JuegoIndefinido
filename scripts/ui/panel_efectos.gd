# panel_efectos.gd
# -----------------------------------------------------------------------------
# La lista de efectos activos (a la izquierda de la pantalla): un cuadro de
# color, el nombre y una barra con el tiempo que queda. Los malos llevan borde
# rojo. Solo se redibuja mientras haya algún efecto.
# -----------------------------------------------------------------------------
class_name PanelEfectos
extends Control

const ANCHO: float = 230.0
const ALTO_FILA: float = 30.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(ANCHO, 10)


func _process(_delta: float) -> void:
	if Juego.efectos_activos.is_empty():
		if visible:
			visible = false
		return
	visible = true
	queue_redraw()


func _draw() -> void:
	var fuente: Font = Tema.fuente("semibold")
	var y: float = 0.0
	for id in Juego.efectos_activos:
		var e: Dictionary = Juego.efectos_activos[id]
		var datos: Dictionary = Juego.DatosEfectos.LISTA[id]
		var resto: float = clampf(float(e["t"]) / maxf(1.0, float(e["total"])), 0.0, 1.0)
		var fila: Rect2 = Rect2(0, y, ANCHO, ALTO_FILA - 4.0)
		var fondo: StyleBoxFlat = StyleBoxFlat.new()
		fondo.bg_color = Color(0.05, 0.06, 0.07, 0.8)
		fondo.border_color = Color(0.5, 0.85, 0.5, 0.8) if datos["bueno"] else Color(0.95, 0.3, 0.3, 0.9)
		fondo.set_border_width_all(1)
		fondo.set_corner_radius_all(6)
		draw_style_box(fondo, fila)
		draw_rect(Rect2(6, y + 5, 16, 16), datos["color"])
		draw_string(fuente, Vector2(30, y + 15), str(datos["nombre"]), HORIZONTAL_ALIGNMENT_LEFT, 120, 13,
				Color(0.95, 0.95, 0.9))
		draw_string(fuente, Vector2(ANCHO - 54, y + 15), Juego.DatosEfectos.duracion_texto(maxf(0.0, float(e["t"]))),
				HORIZONTAL_ALIGNMENT_RIGHT, 48, 12, Color(0.8, 0.8, 0.75))
		draw_rect(Rect2(30, y + 19, ANCHO - 40, 3), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(30, y + 19, (ANCHO - 40) * resto, 3), datos["color"])
		y += ALTO_FILA
