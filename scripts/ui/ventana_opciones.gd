# ventana_opciones.gd
# -----------------------------------------------------------------------------
# Base de las páginas de ajustes (Gráficos, Sonido y juego, Controles): filas con
# un texto a la izquierda y un control a la derecha (deslizador, casilla,
# desplegable o botón), agrupadas por secciones.
#
# Se puede usar de dos formas:
#   - Suelta, como ventana propia (montar()).
#   - Incrustada en una pestaña de VentanaAjustes (incrustada = true, montar_en()).
# El buscador de VentanaAjustes llama a filtrar(texto): oculta las filas que no
# encajan y las secciones que se quedan vacías.
# Cada hija monta sus filas en rellenar(); "lista" es la caja donde van.
# -----------------------------------------------------------------------------
class_name VentanaOpciones
extends Ventana

var lista: VBoxContainer
var aviso: Label
var _desplazable: ScrollContainer
var _filtro: String = ""
var _seccion_txt: String = ""   # Título de la sección actual (también cuenta al buscar).


# Como ventana propia.
func montar(titulo_ventana: String, tam: Vector2 = Vector2(860, 680), sub: String = "") -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cuerpo: VBoxContainer = marco(titulo_ventana, sub, tam)
	_montar_lista(cuerpo)


# Dentro de una pestaña (VentanaAjustes): sin marco propio.
func montar_incrustada() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cuerpo: VBoxContainer = VBoxContainer.new()
	cuerpo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cuerpo.add_theme_constant_override("separation", 8)
	add_child(cuerpo)
	_montar_lista(cuerpo)


func _montar_lista(cuerpo: VBoxContainer) -> void:
	_desplazable = ScrollContainer.new()
	_desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_desplazable.follow_focus = true
	cuerpo.add_child(_desplazable)
	lista = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 6)
	_desplazable.add_child(lista)
	aviso = UI.parrafo("", Tema.ACENTO)
	cuerpo.add_child(aviso)


func vaciar() -> void:
	for h in lista.get_children():
		lista.remove_child(h)
		h.queue_free()


# Título de sección (se oculta al buscar).
func titulo(t: String) -> void:
	_seccion_txt = t.to_lower()
	var s: HBoxContainer = UI.seccion(t)
	s.set_meta("seccion", true)
	s.custom_minimum_size.y = 34
	lista.add_child(s)


# Una fila: etiqueta a la izquierda; el control lo añade quien llama a "f".
func fila(texto: String, ayuda: String = "") -> HBoxContainer:
	var f: HBoxContainer = HBoxContainer.new()
	f.add_theme_constant_override("separation", 14)
	f.set_meta("texto", texto.to_lower() + " " + ayuda.to_lower() + " " + _seccion_txt)
	var l: Label = UI.etiqueta(texto, "", Tema.TEXTO)
	l.custom_minimum_size.x = 300
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ayuda != "":
		l.tooltip_text = ayuda
		l.mouse_filter = Control.MOUSE_FILTER_PASS
	f.add_child(l)
	lista.add_child(f)
	return f


# Oculta las filas que no encajan con "texto" (vacío = todo visible) y las secciones vacías.
func filtrar(texto: String) -> void:
	_filtro = texto.strip_edges().to_lower()
	var seccion_actual: Control = null
	var hay_en_seccion: bool = false
	for h in lista.get_children():
		var c: Control = h as Control
		if c == null:
			continue
		if c.has_meta("seccion"):
			if seccion_actual != null:
				seccion_actual.visible = _filtro == "" or hay_en_seccion
			seccion_actual = c
			hay_en_seccion = false
		elif c.has_meta("texto"):
			var encaja: bool = _filtro == "" or str(c.get_meta("texto")).contains(_filtro)
			c.visible = encaja
			hay_en_seccion = hay_en_seccion or encaja
	if seccion_actual != null:
		seccion_actual.visible = _filtro == "" or hay_en_seccion


# Cuántas filas encajan con el buscador ahora mismo.
func coincidencias() -> int:
	var n: int = 0
	for h in lista.get_children():
		if h.has_meta("texto") and (h as Control).visible:
			n += 1
	return n


# Deslizador de "minimo" a "maximo"; muestra el valor con "formato" (valor x "mult").
func deslizador(texto: String, valor: float, minimo: float, maximo: float, paso: float,
		formato: String, mult: float, al_cambiar: Callable, ayuda: String = "") -> HSlider:
	var f: HBoxContainer = fila(texto, ayuda)
	var s: HSlider = HSlider.new()
	s.min_value = minimo
	s.max_value = maximo
	s.step = paso
	s.value = valor
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size.y = 26
	s.focus_mode = Control.FOCUS_ALL
	f.add_child(s)
	var val: Label = UI.etiqueta(formato % int(roundf(s.value * mult)), "Dinero")
	val.custom_minimum_size.x = 76
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	f.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		val.text = formato % int(roundf(x * mult))
		al_cambiar.call(x))
	return s


func casilla(texto: String, valor: bool, al_cambiar: Callable, ayuda: String = "") -> CheckButton:
	var f: HBoxContainer = fila(texto, ayuda)
	f.add_child(UI.espaciador())
	var c: CheckButton = CheckButton.new()
	c.button_pressed = valor
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(al_cambiar)
	f.add_child(c)
	return c


func opcion(texto: String, etiquetas: Array, elegido: int, al_cambiar: Callable, ayuda: String = "") -> OptionButton:
	var f: HBoxContainer = fila(texto, ayuda)
	var o: OptionButton = OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.focus_mode = Control.FOCUS_ALL
	for t in etiquetas:
		o.add_item(String(t))
	o.select(elegido)
	o.item_selected.connect(al_cambiar)
	f.add_child(o)
	return o


# Un botón suelto dentro de la lista.
func boton_fila(texto: String, accion: Callable, variacion: String = "") -> Button:
	var b: Button = UI.boton(texto, accion, variacion)
	var f: HBoxContainer = HBoxContainer.new()
	f.set_meta("texto", texto.to_lower() + " " + _seccion_txt)
	f.add_child(b)
	lista.add_child(f)
	return b


# Una nota larga (se queda siempre visible).
func nota_fila(texto: String) -> void:
	lista.add_child(UI.nota(texto))
