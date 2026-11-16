# cliente.gd
# -----------------------------------------------------------------------------
# El cliente que espera en el mostrador. Pide una poción concreta y tiene una
# barra de paciencia: si se acaba antes de que le vendas, se marcha enfadado.
#
# Cuando no hay nadie en la tienda, "presente" vale false y no se dibuja nada.
# -----------------------------------------------------------------------------
class_name Cliente
extends Control

# Se emite cuando al cliente se le acaba la paciencia.
signal se_cansa

# Nombres graciosos para los clientes (puedes añadir los que quieras).
const NOMBRES: Array[String] = [
	"Doña Remedios", "El Herrero Tito", "Fray Anselmo", "La Baronesa Pía",
	"Pepe el Bardo", "Sir Gualterio", "La Tía Eulalia", "Un guardia (fuera de turno)",
]

var presente: bool = false
var nombre: String = ""
var pedido: String = ""          # Id de la poción que quiere, por ejemplo "risa".
var paciencia_max: float = 30.0  # Segundos que está dispuesto a esperar.
var paciencia: float = 0.0

# Color aleatorio para la ropa, para que cada cliente parezca distinto.
var _color_ropa: Color = Color.WHITE


func _ready() -> void:
	custom_minimum_size = Vector2(240, 220)


func _process(delta: float) -> void:
	if not presente:
		return
	paciencia -= delta
	if paciencia <= 0.0:
		paciencia = 0.0
		se_cansa.emit()
	queue_redraw()


# Hace entrar a un cliente nuevo que pide una poción al azar.
func llegar() -> void:
	presente = true
	nombre = NOMBRES.pick_random()
	pedido = GameData.POCIONES.keys().pick_random()
	paciencia_max = randf_range(25.0, 40.0)
	paciencia = paciencia_max
	_color_ropa = Color.from_hsv(randf(), 0.5, 0.75)
	queue_redraw()


func marcharse() -> void:
	presente = false
	pedido = ""
	queue_redraw()


# --------------------------- DIBUJO ------------------------------------------
func _draw() -> void:
	if not presente:
		draw_string(get_theme_default_font(), Vector2(0, size.y * 0.5),
				"(No hay nadie... por ahora)", HORIZONTAL_ALIGNMENT_CENTER, size.x, 16,
				Color(0.7, 0.7, 0.7))
		return

	var cx: float = size.x * 0.5
	# Cuerpo: un rectángulo con el color de la ropa.
	draw_rect(Rect2(cx - 35, 120, 70, 90), _color_ropa)
	# Cabeza: un círculo color piel.
	draw_circle(Vector2(cx, 95), 28.0, Color(0.95, 0.8, 0.65))
	# Ojos.
	draw_circle(Vector2(cx - 10, 90), 4.0, Color.BLACK)
	draw_circle(Vector2(cx + 10, 90), 4.0, Color.BLACK)
	# Boca: sonríe si le queda mucha paciencia, se enfada si le queda poca.
	var animo: float = paciencia / paciencia_max
	var curva: float = lerpf(-6.0, 6.0, animo)
	draw_line(Vector2(cx - 10, 106), Vector2(cx, 106 + curva), Color.BLACK, 2.0)
	draw_line(Vector2(cx, 106 + curva), Vector2(cx + 10, 106), Color.BLACK, 2.0)
	# Sombrero de pico (para darle aire medieval).
	var sombrero: PackedVector2Array = [
		Vector2(cx - 32, 72), Vector2(cx + 32, 72), Vector2(cx + 4, 30),
	]
	draw_colored_polygon(sombrero, _color_ropa.darkened(0.4))

	# Nombre y barra de paciencia.
	var fuente: Font = get_theme_default_font()
	draw_string(fuente, Vector2(0, 16), nombre, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16,
			Color(1, 0.95, 0.8))
	var ancho_barra: float = size.x - 40
	draw_rect(Rect2(20, 24, ancho_barra, 8), Color(0.15, 0.15, 0.15))
	var color_barra: Color = Color(0.9, 0.3, 0.3).lerp(Color(0.4, 0.85, 0.4), animo)
	draw_rect(Rect2(20, 24, ancho_barra * animo, 8), color_barra)
