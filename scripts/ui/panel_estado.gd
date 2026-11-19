# panel_estado.gd
# -----------------------------------------------------------------------------
# El panel de arriba a la izquierda: vida, dinero y nivel, con iconos dibujados
# por código (corazón, moneda, escudo). Lee los datos de Juego cada fotograma,
# así que siempre está al día. Si la vida baja del 25%, la barra parpadea.
# -----------------------------------------------------------------------------
class_name PanelEstado
extends Control

const ANCHO: float = 270.0
const ALTO: float = 168.0

var _vida_mostrada: float = 100.0   # La barra se mueve suave hacia la vida real.
var _tiempo: float = 0.0
const Estadisticas = preload("res://scripts/datos/estadisticas.gd")


func _ready() -> void:
	custom_minimum_size = Vector2(ANCHO, ALTO)
	size = Vector2(ANCHO, ALTO)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vida_mostrada = Juego.vida


func _process(delta: float) -> void:
	_tiempo += delta
	_vida_mostrada = move_toward(_vida_mostrada, Juego.vida, delta * 60.0)
	queue_redraw()


func _draw() -> void:
	var fuente: Font = ThemeDB.fallback_font
	# Fondo del panel.
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(0.05, 0.06, 0.07, 0.8)
	estilo.border_color = Color(0.88, 0.74, 0.38, 0.8)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(10)
	draw_style_box(estilo, Rect2(0, 0, ANCHO, ALTO))

	# --- Vida: corazón y barra ---
	var fraccion: float = clampf(_vida_mostrada / Juego.vida_max(), 0.0, 1.0)
	var baja: bool = Juego.vida / Juego.vida_max() < 0.25
	var latido: float = 1.0 + (0.12 * sin(_tiempo * 9.0) if baja else 0.0)
	_corazon(Vector2(24, 26), latido)
	var barra: Rect2 = Rect2(46, 16, 208, 20)
	draw_rect(barra, Color(0.14, 0.05, 0.05))
	var color_vida: Color = Color(0.82, 0.16, 0.16)
	if baja and int(_tiempo * 4.0) % 2 == 0:
		color_vida = Color(1.0, 0.35, 0.3)
	draw_rect(Rect2(barra.position, Vector2(barra.size.x * fraccion, barra.size.y)), color_vida)
	draw_rect(Rect2(barra.position, Vector2(barra.size.x * fraccion, 6.0)), Color(1, 1, 1, 0.18))   # Brillo.
	draw_rect(barra, Color(0, 0, 0, 0.8), false, 1.5)
	var texto_vida: String = "%d / %d" % [int(ceil(Juego.vida)), int(Juego.vida_max())]
	_texto_centrado(fuente, texto_vida, barra.position.x + barra.size.x / 2.0, barra.position.y + 15.0, 14, Color.WHITE)

	# --- Dinero: moneda y cifra ---
	_moneda(Vector2(24, 60))
	draw_string_outline(fuente, Vector2(46, 69), "%d $" % Juego.dinero, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 5, Color.BLACK)
	draw_string(fuente, Vector2(46, 69), "%d $" % Juego.dinero, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.86, 0.35))

	# --- Clima: nombre del tiempo, a la derecha de la fila del dinero ---
	var texto_clima: String = Clima.nombre()
	draw_string(fuente, Vector2(ANCHO - 12 - fuente.get_string_size(texto_clima, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, 67),
			texto_clima, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.82, 0.95))

	# --- Nivel: escudo, número y barra de experiencia ---
	_escudo(Vector2(24, 96))
	draw_string(fuente, Vector2(46, 92), "Nivel %d" % Juego.nivel, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.9, 1.0))
	var necesaria: int = maxi(1, Juego.xp_necesaria())
	var xp_barra: Rect2 = Rect2(46, 100, 208, 8)
	draw_rect(xp_barra, Color(0.05, 0.08, 0.14))
	draw_rect(Rect2(xp_barra.position, Vector2(xp_barra.size.x * clampf(float(Juego.xp) / necesaria, 0.0, 1.0), xp_barra.size.y)),
			Color(0.3, 0.6, 1.0))
	draw_rect(xp_barra, Color(0, 0, 0, 0.8), false, 1.0)
	var texto_xp: String = "%d / %d XP" % [Juego.xp, necesaria]
	draw_string(fuente, Vector2(ANCHO - 12 - fuente.get_string_size(texto_xp, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, 92),
			texto_xp, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.65, 0.78, 0.95))

	# --- Vitales: resistencia, hambre y sed (barras finas) ---
	_barra_fina(fuente, "Aliento", Juego.resistencia / Estadisticas.RESISTENCIA_MAX, 122.0,
			Color(0.95, 0.75, 0.2) if not Juego.agotado else Color(0.6, 0.35, 0.15))
	_barra_fina(fuente, "Hambre", Juego.hambre / 100.0, 138.0, Color(0.85, 0.5, 0.25))
	_barra_fina(fuente, "Sed", Juego.sed / 100.0, 154.0, Color(0.3, 0.6, 0.9))


# Una barra pequeña con su nombre. Para hambre y sed, llena = mal (se pone roja).
func _barra_fina(fuente: Font, nombre: String, fraccion: float, y: float, color: Color) -> void:
	fraccion = clampf(fraccion, 0.0, 1.0)
	draw_string(fuente, Vector2(12, y + 8), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.78, 0.8))
	var r: Rect2 = Rect2(70, y, 184, 9)
	draw_rect(r, Color(0.08, 0.08, 0.1))
	var c: Color = color
	if nombre != "Aliento" and fraccion * 100.0 >= Estadisticas.MAL_ESTADO:
		c = Color(0.9, 0.2, 0.2) if int(_tiempo * 3.0) % 2 == 0 else color
	draw_rect(Rect2(r.position, Vector2(r.size.x * fraccion, r.size.y)), c)
	draw_rect(r, Color(0, 0, 0, 0.8), false, 1.0)


func _texto_centrado(fuente: Font, texto: String, x: float, y: float, tam: int, color: Color) -> void:
	var ancho_t: float = fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	draw_string_outline(fuente, Vector2(x - ancho_t / 2.0, y), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 4, Color.BLACK)
	draw_string(fuente, Vector2(x - ancho_t / 2.0, y), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, color)


# Un corazón: dos círculos y un triángulo. "k" lo agranda (para el latido).
func _corazon(c: Vector2, k: float) -> void:
	var rojo: Color = Color(0.9, 0.2, 0.22)
	draw_circle(c + Vector2(-5.0, -3.0) * k, 6.0 * k, rojo)
	draw_circle(c + Vector2(5.0, -3.0) * k, 6.0 * k, rojo)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-10.6, -0.5) * k, c + Vector2(10.6, -0.5) * k,
			c + Vector2(0.0, 11.0) * k]), rojo)


# Una moneda dorada con el signo del dólar.
func _moneda(c: Vector2) -> void:
	draw_circle(c, 11.0, Color(0.55, 0.4, 0.08))
	draw_circle(c, 9.0, Color(1.0, 0.82, 0.25))
	draw_string(ThemeDB.fallback_font, c + Vector2(-4.5, 5.5), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.5, 0.35, 0.05))


# Un escudo azul.
func _escudo(c: Vector2) -> void:
	var puntos: PackedVector2Array = PackedVector2Array([c + Vector2(-9, -9), c + Vector2(9, -9), c + Vector2(9, 1),
			c + Vector2(0, 11), c + Vector2(-9, 1)])
	draw_colored_polygon(puntos, Color(0.18, 0.4, 0.8))
	draw_polyline(PackedVector2Array([puntos[0], puntos[1], puntos[2], puntos[3], puntos[4], puntos[0]]),
			Color(0.8, 0.9, 1.0), 1.5, true)
