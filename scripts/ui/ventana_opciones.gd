# ventana_opciones.gd
# -----------------------------------------------------------------------------
# Base para las ventanas de opciones (Sonido y juego, Controles): filas con un texto a la
# izquierda y un control a la derecha (deslizador, casilla, desplegable o botón).
# Cada hija monta sus filas en rellenar(); "lista" es la caja donde van.
# -----------------------------------------------------------------------------
class_name VentanaOpciones
extends Ventana

var lista: VBoxContainer
var aviso: Label


func montar(titulo: String, tam: Vector2 = Vector2(860, 680)) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var caja: VBoxContainer = panel_centrado(tam)
	cabecera(caja, titulo)
	lista = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 6)
	caja.add_child(lista)
	aviso = Hud.crear_label(16, Color(1, 0.92, 0.6))
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(aviso)


func vaciar() -> void:
	for h in lista.get_children():
		lista.remove_child(h)
		h.queue_free()


func titulo(t: String) -> void:
	var l: Label = Hud.crear_label(20, Color(0.6, 0.9, 0.6))
	l.text = t
	lista.add_child(l)


func fila(texto: String) -> HBoxContainer:
	var f: HBoxContainer = HBoxContainer.new()
	f.add_theme_constant_override("separation", 12)
	var l: Label = Hud.crear_label(17, Color(0.9, 0.92, 0.88))
	l.text = texto
	l.custom_minimum_size.x = 320
	f.add_child(l)
	lista.add_child(f)
	return f


# Deslizador de "minimo" a "maximo"; muestra el valor con "formato" (valor x "mult").
func deslizador(texto: String, valor: float, minimo: float, maximo: float, paso: float,
		formato: String, mult: float, al_cambiar: Callable) -> HSlider:
	var f: HBoxContainer = fila(texto)
	var s: HSlider = HSlider.new()
	s.min_value = minimo
	s.max_value = maximo
	s.step = paso
	s.value = valor
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size.y = 28
	f.add_child(s)
	var val: Label = Hud.crear_label(17, Color(1, 0.92, 0.6))
	val.custom_minimum_size.x = 80
	val.text = formato % int(roundf(s.value * mult))
	f.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		val.text = formato % int(roundf(x * mult))
		al_cambiar.call(x))
	return s


func casilla(texto: String, valor: bool, al_cambiar: Callable) -> CheckBox:
	var f: HBoxContainer = fila(texto)
	var c: CheckBox = CheckBox.new()
	c.button_pressed = valor
	c.toggled.connect(al_cambiar)
	f.add_child(c)
	return c


func opcion(texto: String, etiquetas: Array, elegido: int, al_cambiar: Callable) -> OptionButton:
	var f: HBoxContainer = fila(texto)
	var o: OptionButton = OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.add_theme_font_size_override("font_size", 16)
	for t in etiquetas:
		o.add_item(String(t))
	o.select(elegido)
	o.item_selected.connect(al_cambiar)
	f.add_child(o)
	return o
