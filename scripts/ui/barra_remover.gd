# barra_remover.gd
# -----------------------------------------------------------------------------
# Minijuego de cocinar: el caldero hierve y hay que remover justo cuando el
# marcador pasa por la zona verde. Son 3 rondas; cada vez la zona es más estrecha
# y está en otro sitio. Nunca bloquea: pase lo que pase, al final se emite
# "terminado(aciertos)" con 0 a 3 aciertos.
# SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name BarraRemover
extends PanelContainer

signal terminado(aciertos: int)

const RONDAS: int = 3

var _ronda: int = 0
var _aciertos: int = 0
var _pos: float = 0.0
var _dir: float = 1.0
var _velocidad: float = 0.9
var _zona_ini: float = 0.4
var _zona_ancho: float = 0.25
var _barra: Control
var _info: Label
var _hecho: bool = false


func _ready() -> void:
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(0.06, 0.07, 0.07, 0.97)
	estilo.border_color = Color(0.95, 0.65, 0.25)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(10)
	estilo.set_content_margin_all(18)
	add_theme_stylebox_override("panel", estilo)
	Hud.centrar(self, Vector2(520.0, 190.0))
	var caja: VBoxContainer = VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	add_child(caja)
	_info = Hud.crear_label(20, Color(1.0, 0.85, 0.5))
	caja.add_child(_info)
	_barra = Control.new()
	_barra.custom_minimum_size = Vector2(480.0, 36.0)
	_barra.draw.connect(_dibujar)
	caja.add_child(_barra)
	caja.add_child(Hud.crear_boton("¡Remover! (Espacio)", _remover))
	_nueva_ronda()


func _nueva_ronda() -> void:
	_ronda += 1
	_pos = 0.0
	_dir = 1.0
	_velocidad = 0.8 + 0.35 * _ronda
	_zona_ancho = 0.3 - 0.06 * _ronda
	_zona_ini = randf_range(0.1, 0.9 - _zona_ancho)
	_info.text = "Remueve a tiempo: ronda %d de %d  (aciertos: %d)" % [_ronda, RONDAS, _aciertos]


func _process(delta: float) -> void:
	if _hecho:
		return
	_pos += _dir * _velocidad * delta
	if _pos >= 1.0:
		_pos = 1.0
		_dir = -1.0
	elif _pos <= 0.0:
		_pos = 0.0
		_dir = 1.0
	_barra.queue_redraw()


func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_SPACE:
		_remover()
		get_viewport().set_input_as_handled()


func _remover() -> void:
	if _hecho:
		return
	if _pos >= _zona_ini and _pos <= _zona_ini + _zona_ancho:
		_aciertos += 1
	if _ronda >= RONDAS:
		_hecho = true
		terminado.emit(_aciertos)
		queue_free()
	else:
		_nueva_ronda()


func _dibujar() -> void:
	var w: float = _barra.size.x
	var h: float = _barra.size.y
	_barra.draw_rect(Rect2(0, 0, w, h), Color(0.15, 0.15, 0.18))
	_barra.draw_rect(Rect2(_zona_ini * w, 0, _zona_ancho * w, h), Color(0.25, 0.75, 0.35))
	_barra.draw_rect(Rect2(_pos * w - 4.0, -4.0, 8.0, h + 8.0), Color(1.0, 0.95, 0.6))
