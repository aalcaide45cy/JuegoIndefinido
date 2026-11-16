# minijuego_machacar.gd
# -----------------------------------------------------------------------------
# Mortero: machaca 2 hierbas pulsando Espacio (o el botón) lo más rápido posible
# durante 4 segundos. 14+ golpes: salen 3 hierbas; 8+: salen 2; menos: sale 1.
# Es rejugable y no bloquea (si fallas pierdes una hierba como mucho).
# SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name MinijuegoMachacar
extends Ventana

const TIEMPO: float = 4.0

var hierba: String = ""
var _golpes: int = 0
var _resto: float = TIEMPO
var _etiqueta: Label
var _fin: Label
var _acabado: bool = false


func construir() -> void:
	var caja: VBoxContainer = panel_centrado(Vector2(480, 300))
	cabecera(caja, "Mortero")
	subtitulo(caja, "Machaca 2 %s: ¡pulsa Espacio lo más rápido que puedas!" % DatosObjetos.nombre(hierba))
	_etiqueta = Hud.crear_label(32, Color(1.0, 0.85, 0.5))
	caja.add_child(_etiqueta)
	var b: Button = Ventanas.boton_grande("¡Machacar!", _golpe)
	caja.add_child(b)
	_fin = Hud.crear_label(18, Color(0.7, 1.0, 0.7))
	_fin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_fin)
	_actualizar()


const DatosObjetos = preload("res://scripts/datos/objetos.gd")


func _process(delta: float) -> void:
	if _acabado:
		return
	_resto -= delta
	if _resto <= 0.0:
		_terminar()
	_actualizar()


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_SPACE:
		_golpe()
		get_viewport().set_input_as_handled()


func _golpe() -> void:
	if not _acabado:
		_golpes += 1


func _actualizar() -> void:
	_etiqueta.text = "Golpes: %d    Tiempo: %.1f s" % [_golpes, maxf(0.0, _resto)]


func _terminar() -> void:
	_acabado = true
	if not Juego.tiene(hierba, 2):
		_fin.text = "Te faltan hierbas."
		return
	Juego.quitar(hierba, 2)
	var sale: int = 3 if _golpes >= 14 else (2 if _golpes >= 8 else 1)
	var sobra: int = Juego.anadir(hierba, sale)
	Juego.ganar_xp(4 * sale)
	_fin.text = "Has sacado %d x %s.%s Cierra o vuelve a probar." % [sale - sobra, DatosObjetos.nombre(hierba),
			"" if sobra == 0 else " (algo no cabía)"]
