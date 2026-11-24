# marcador_acierto.gd
# -----------------------------------------------------------------------------
# Aspa que aparece un instante en el centro de la pantalla cuando aciertas:
# blanca = tocado, roja = muerto, grande y roja con círculo = en la cabeza.
# La crea EfectosArma.marcador(); va en su propia capa por encima del HUD.
# -----------------------------------------------------------------------------
class_name MarcadorAcierto
extends CanvasLayer

var _dibujo: Control
var _t: float = 0.0
var _tipo: String = "toque"
const DURACION: float = 0.28


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dibujo = Control.new()
	_dibujo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dibujo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dibujo.draw.connect(_pintar)
	add_child(_dibujo)


func mostrar(tipo: String) -> void:
	_tipo = tipo
	_t = DURACION if tipo == "toque" else DURACION * 1.8
	if _dibujo != null:
		_dibujo.queue_redraw()


func _process(delta: float) -> void:
	if _t > 0.0:
		_t -= delta
		_dibujo.queue_redraw()


func _pintar() -> void:
	if _t <= 0.0:
		return
	var c: Vector2 = _dibujo.size * 0.5
	var a: float = clampf(_t / DURACION, 0.0, 1.0)
	var color: Color = Color(1, 1, 1, a)
	var hueco: float = 7.0
	var largo: float = 9.0
	var grosor: float = 2.0
	if _tipo != "toque":
		color = Color(1.0, 0.15, 0.1, a)
		largo = 12.0
		grosor = 3.0
	if _tipo == "cabeza":
		hueco = 9.0
		largo = 15.0
		_dibujo.draw_arc(c, 24.0, 0.0, TAU, 24, color, 2.0, true)
	for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var d: Vector2 = (s as Vector2).normalized()
		_dibujo.draw_line(c + d * hueco, c + d * (hueco + largo), color, grosor, true)
