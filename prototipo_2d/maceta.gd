# maceta.gd
# -----------------------------------------------------------------------------
# Una maceta del huerto. Puede estar en tres estados:
#   VACIA     -> no hay nada plantado.
#   CRECIENDO -> hay una planta que todavía no está lista.
#   LISTA     -> la planta ha crecido y se puede cosechar.
#
# La maceta no decide nada por su cuenta: cuando el jugador hace clic,
# avisa al juego (con la señal "pulsada") y el juego decide qué hacer.
#
# El dibujo está hecho con formas simples en la función _draw().
# Cuando tengamos arte de verdad, se puede cambiar por un Sprite2D.
# -----------------------------------------------------------------------------
class_name Maceta
extends Control

# Señal que se emite cuando el jugador hace clic en la maceta.
signal pulsada(maceta: Maceta)

enum Estado { VACIA, CRECIENDO, LISTA }

var estado: Estado = Estado.VACIA
var tipo_hierba: String = ""     # Qué hay plantado, por ejemplo "bruma".
var progreso: float = 0.0        # De 0.0 (recién plantada) a 1.0 (lista).

var _raton_encima: bool = false  # Para iluminar la maceta al pasar el ratón.


func _ready() -> void:
	custom_minimum_size = Vector2(130, 170)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_al_entrar_raton)
	mouse_exited.connect(_al_salir_raton)


func _al_entrar_raton() -> void:
	_raton_encima = true
	queue_redraw()


func _al_salir_raton() -> void:
	_raton_encima = false
	queue_redraw()


# _process se ejecuta en cada fotograma. "delta" son los segundos que han
# pasado desde el fotograma anterior.
func _process(delta: float) -> void:
	if estado == Estado.CRECIENDO:
		var tiempo_total: float = GameData.HIERBAS[tipo_hierba]["tiempo"]
		progreso += delta / tiempo_total
		if progreso >= 1.0:
			progreso = 1.0
			estado = Estado.LISTA
		queue_redraw()  # Pide a Godot que vuelva a llamar a _draw().
	elif estado == Estado.LISTA:
		queue_redraw()  # Para que la planta lista "brille" de forma animada.


# Godot llama a esta función cuando ocurre algo con el ratón sobre la maceta.
func _gui_input(event: InputEvent) -> void:
	var clic: InputEventMouseButton = event as InputEventMouseButton
	if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
		pulsada.emit(self)


# Planta una semilla. La llama main.gd después de cobrar la semilla.
func plantar(id_hierba: String) -> void:
	tipo_hierba = id_hierba
	progreso = 0.0
	estado = Estado.CRECIENDO
	queue_redraw()


# Vacía la maceta y devuelve qué hierba había. La llama main.gd al cosechar.
func cosechar() -> String:
	var cosechada: String = tipo_hierba
	tipo_hierba = ""
	progreso = 0.0
	estado = Estado.VACIA
	queue_redraw()
	return cosechada


# --------------------------- DIBUJO ------------------------------------------
func _draw() -> void:
	var ancho: float = size.x
	var alto: float = size.y

	# Fondo de la casilla (más claro si el ratón está encima).
	var fondo: Color = Color(0.1, 0.1, 0.12) if not _raton_encima else Color(0.16, 0.16, 0.2)
	draw_rect(Rect2(Vector2.ZERO, size), fondo)

	# La maceta: un trapecio marrón (más ancho arriba que abajo).
	var arriba_y: float = alto - 60.0
	var abajo_y: float = alto - 12.0
	var puntos: PackedVector2Array = [
		Vector2(ancho * 0.2, arriba_y),
		Vector2(ancho * 0.8, arriba_y),
		Vector2(ancho * 0.7, abajo_y),
		Vector2(ancho * 0.3, abajo_y),
	]
	draw_colored_polygon(puntos, Color(0.4, 0.27, 0.2))
	# Tierra
	draw_rect(Rect2(ancho * 0.22, arriba_y, ancho * 0.56, 8.0), Color(0.3, 0.2, 0.12))

	if estado == Estado.VACIA:
		_dibujar_texto_centrado("Vacía", alto * 0.35, Color(0.8, 0.75, 0.65))
		return

	var color_planta: Color = GameData.HIERBAS[tipo_hierba]["color"]
	var base: Vector2 = Vector2(ancho * 0.5, arriba_y)

	# El tallo crece con el progreso.
	var altura_tallo: float = lerpf(10.0, 70.0, progreso)
	var punta: Vector2 = base - Vector2(0, altura_tallo)
	draw_line(base, punta, Color(0.25, 0.55, 0.2), 4.0)

	if GameData.HIERBAS[tipo_hierba]["forma"] == "seta":
		# Un hongo: sombrero (medio círculo) con manchas oscuras.
		var radio: float = lerpf(6.0, 26.0, progreso)
		draw_circle(punta, radio, color_planta)
		draw_rect(Rect2(punta.x - radio, punta.y, radio * 2.0, radio), fondo)
		draw_line(punta, punta + Vector2(0, radio), Color(0.75, 0.72, 0.68), 5.0)  # Pie del hongo.
		draw_circle(punta + Vector2(-radio * 0.4, -radio * 0.4), radio * 0.16, Color(0.2, 0.15, 0.25))
		draw_circle(punta + Vector2(radio * 0.35, -radio * 0.55), radio * 0.12, Color(0.2, 0.15, 0.25))
	else:
		# Una planta de hojas alargadas y puntiagudas, abiertas en abanico.
		var largo: float = lerpf(8.0, 34.0, progreso)
		for angulo_grados in [-70.0, -35.0, 0.0, 35.0, 70.0]:
			var direccion: Vector2 = Vector2.UP.rotated(deg_to_rad(angulo_grados))
			var lado: Vector2 = direccion.orthogonal() * largo * 0.18
			# Las hojas laterales son un poco más cortas que la central.
			var factor: float = 1.0 - absf(angulo_grados) / 200.0
			var hoja: PackedVector2Array = [
				punta,
				punta + direccion * largo * factor * 0.5 + lado,
				punta + direccion * largo * factor,
				punta + direccion * largo * factor * 0.5 - lado,
			]
			draw_colored_polygon(hoja, color_planta)

	if estado == Estado.CRECIENDO:
		# Barra de progreso arriba.
		draw_rect(Rect2(10, 10, ancho - 20, 10), Color(0.1, 0.1, 0.1))
		draw_rect(Rect2(10, 10, (ancho - 20) * progreso, 10), Color(0.4, 0.8, 0.4))
	else:
		# Lista: un brillo que parpadea y el texto "¡Cosechar!".
		var parpadeo: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
		draw_circle(punta, 34.0, Color(1, 1, 0.6, 0.15 * parpadeo))
		_dibujar_texto_centrado("¡Cosechar!", 24.0, Color(1, 0.95, 0.5))


func _dibujar_texto_centrado(texto: String, y: float, color: Color) -> void:
	var fuente: Font = get_theme_default_font()
	var tam: int = 16
	draw_string(fuente, Vector2(0, y), texto, HORIZONTAL_ALIGNMENT_CENTER, size.x, tam, color)
