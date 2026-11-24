# ui.gd
# -----------------------------------------------------------------------------
# Piezas reutilizables para montar menús con el estilo común (ver tema.gd):
# etiquetas, botones, chips de filtro, buscador, pestañas, tarjetas, barras,
# insignias y las "pistas" de teclas del pie (con iconos de mando si hay uno).
# Todas son funciones estáticas: UI.boton("Comprar", accion, "BotonPrimario").
# -----------------------------------------------------------------------------
class_name UI
extends RefCounted

const NOMBRE_TECLAS: Dictionary = {
	"mover": "Flechas", "aceptar": "Intro", "atras": "Esc", "pestanas": "Re Pág / Av Pág",
	"accion": "Q", "buscar": "Clic", "x": "X", "y": "Y",
}
const ICONO_MANDO: Dictionary = {
	"mover": "joystickLeft", "aceptar": "buttonA", "atras": "buttonB", "pestanas": "buttonL1",
	"x": "buttonX", "y": "buttonY", "inicio": "buttonStart",
}


# ------------------------------- Texto ----------------------------------------
static func etiqueta(texto: String, variacion: String = "", color: Variant = null, tam: int = 0) -> Label:
	var l: Label = Label.new()
	l.text = texto
	if variacion != "":
		l.theme_type_variation = variacion
	if color is Color:
		l.add_theme_color_override("font_color", color)
	if tam > 0:
		l.add_theme_font_size_override("font_size", tam)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func titulo(texto: String) -> Label:
	return etiqueta(texto, "Titulo")


static func subtitulo(texto: String) -> Label:
	return etiqueta(texto, "Subtitulo")


static func nota(texto: String, ajustar: bool = true) -> Label:
	var l: Label = etiqueta(texto, "Nota")
	if ajustar:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# Texto normal que se ajusta al ancho.
static func parrafo(texto: String, color: Variant = null, tam: int = 0) -> Label:
	var l: Label = etiqueta(texto, "", color, tam)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# Un título de sección pequeño en mayúsculas ("MOCHILA"), con una línea fina a la derecha.
static func seccion(texto: String) -> HBoxContainer:
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	var l: Label = etiqueta(texto.to_upper(), "Subtitulo", Tema.ACENTO.darkened(0.1), 13)
	fila.add_child(l)
	var linea: HSeparator = HSeparator.new()
	linea.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linea.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(linea)
	return fila


# "1.234 $" con punto de millares.
static func dinero(n: int) -> String:
	return "%s $" % numero(n)


static func numero(n: int) -> String:
	var s: String = str(absi(n))
	var fuera: String = ""
	var c: int = 0
	for i in range(s.length() - 1, -1, -1):
		fuera = s[i] + fuera
		c += 1
		if c % 3 == 0 and i > 0:
			fuera = "." + fuera
	return ("-" if n < 0 else "") + fuera


# ------------------------------- Botones --------------------------------------
# variacion: "", "BotonPrimario", "BotonPeligro", "BotonSuave", "BotonAcento".
static func boton(texto: String, accion: Callable, variacion: String = "", icono: String = "") -> Button:
	var b: Button = Button.new()
	b.text = texto
	if variacion != "":
		b.theme_type_variation = variacion
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if icono != "":
		var t: Texture2D = Tema.icono(icono)
		if t != null:
			b.icon = t
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 16)
	if accion.is_valid():
		b.pressed.connect(accion)
	return b


# Botón de interruptor pequeño y redondeado (filtros). "al_cambiar" recibe true/false.
static func chip(texto: String, activo: bool, al_cambiar: Callable = Callable()) -> Button:
	var b: Button = Button.new()
	b.text = texto
	b.theme_type_variation = "Chip"
	b.toggle_mode = true
	b.button_pressed = activo
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if al_cambiar.is_valid():
		b.toggled.connect(al_cambiar)
	return b


static func separador() -> HSeparator:
	return HSeparator.new()


static func espaciador() -> Control:
	var c: Control = Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func espaciador_alto(alto: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0, alto)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# Una tecla dibujada como cápsula ("TAB", "P").
static func tecla(texto: String) -> PanelContainer:
	var t: PanelContainer = PanelContainer.new()
	t.add_theme_stylebox_override("panel", Tema.caja(Color(0.14, 0.16, 0.18), Tema.BORDE, 1, 5, 8, 2))
	t.add_child(etiqueta(texto, "Subtitulo", Tema.TEXTO, 13))
	t.custom_minimum_size.x = 34
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# ------------------------------- Campos ---------------------------------------
# Buscador con lupa y botón de borrar. "al_cambiar" recibe el texto en minúsculas.
static func buscador(sugerencia: String, al_cambiar: Callable) -> LineEdit:
	var campo: LineEdit = LineEdit.new()
	campo.placeholder_text = sugerencia
	campo.clear_button_enabled = true
	campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lupa: Texture2D = Tema.icono("zoom")
	if lupa != null:
		campo.right_icon = null
	campo.text_changed.connect(func(t: String) -> void: al_cambiar.call(t.strip_edges().to_lower()))
	return campo


# ------------------------------- Contenedores ---------------------------------
# Tarjeta redondeada. Con "seleccion" tiene borde dorado.
static func tarjeta(seleccion: bool = false) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.theme_type_variation = "TarjetaSeleccion" if seleccion else "Tarjeta"
	return p


static func hondo() -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.theme_type_variation = "PanelHondo"
	return p


# Una insignia pequeña de color ("NUEVO", "BLOQUEADO"...).
static func insignia(texto: String, color: Color = Tema.ACENTO) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var estilo: StyleBoxFlat = Tema.caja(Color(color.r, color.g, color.b, 0.16), Color(color.r, color.g, color.b, 0.55), 1, 9, 8, 2)
	p.add_theme_stylebox_override("panel", estilo)
	p.add_child(etiqueta(texto, "", color, 12))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# Barra de progreso con el color dado. "texto" se dibuja encima (puede ir vacío).
static func barra(valor: float, maximo: float, color: Color = Tema.BRUMA, alto: float = 14.0, texto: String = "") -> ProgressBar:
	var b: ProgressBar = ProgressBar.new()
	b.max_value = maxf(maximo, 0.001)
	b.value = valor
	b.show_percentage = texto != ""
	b.custom_minimum_size = Vector2(60, alto)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("fill", Tema.caja(color, Color(0, 0, 0, 0), 0, int(alto / 2.0), 0, 0))
	b.add_theme_stylebox_override("background", Tema.caja(Color(0.04, 0.045, 0.055, 0.95), Tema.BORDE_SUAVE, 1, int(alto / 2.0), 0, 0))
	return b


# ------------------------------- Pistas de teclas -----------------------------
# "accion": mover, aceptar, atras, pestanas, x, y, inicio... o un texto de tecla libre.
static func hay_mando() -> bool:
	return not Input.get_connected_joypads().is_empty()


static func pista(caja: Container, accion: String, texto: String) -> void:
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hay_mando() and ICONO_MANDO.has(accion) and Tema.icono(ICONO_MANDO[accion]) != null:
		var ic: TextureRect = TextureRect.new()
		ic.texture = Tema.icono(ICONO_MANDO[accion])
		ic.custom_minimum_size = Vector2(20, 20)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.modulate = Tema.TEXTO_SUAVE
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(ic)
		if accion == "pestanas":
			var ic2: TextureRect = ic.duplicate()
			ic2.texture = Tema.icono("buttonR1")
			fila.add_child(ic2)
	else:
		var tecla: PanelContainer = PanelContainer.new()
		tecla.add_theme_stylebox_override("panel", Tema.caja(Color(0.14, 0.16, 0.18), Tema.BORDE, 1, 5, 7, 1))
		tecla.add_child(etiqueta(str(NOMBRE_TECLAS.get(accion, accion)), "Subtitulo", Tema.TEXTO, 12))
		tecla.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(tecla)
	fila.add_child(etiqueta(texto, "Nota"))
	caja.add_child(fila)


# ------------------------------- Foco -----------------------------------------
static func primer_enfocable(raiz: Node) -> Control:
	for h in raiz.get_children():
		var c: Control = h as Control
		if c != null:
			if c.visible and c.focus_mode == Control.FOCUS_ALL and not (c is BaseButton and (c as BaseButton).disabled) \
					and not c is LineEdit and not c is SpinBox:
				return c
			var dentro: Control = primer_enfocable(c)
			if dentro != null:
				return dentro
		else:
			var d2: Control = primer_enfocable(h)
			if d2 != null:
				return d2
	return null


# ==============================================================================
# Pestañas propias: barra de botones con la activa subrayada en dorado, y LB/RB del mando
# (o Re Pág / Av Pág) para pasar de una a otra. Cada pestaña es un Control que se muestra u oculta.
class Pestanas extends VBoxContainer:
	signal cambiada(indice: int)

	var _barra: HBoxContainer
	var _extra: HBoxContainer       # Hueco a la derecha de la barra (buscador, botones...).
	var _pila: Control
	var _botones: Array[Button] = []
	var _contenidos: Array[Control] = []
	var actual: int = -1

	func _init() -> void:
		add_theme_constant_override("separation", 8)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		var fila: HBoxContainer = HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		add_child(fila)
		_barra = HBoxContainer.new()
		_barra.add_theme_constant_override("separation", 4)
		fila.add_child(_barra)
		var hueco: Control = Control.new()
		hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(hueco)
		_extra = HBoxContainer.new()
		_extra.add_theme_constant_override("separation", 8)
		fila.add_child(_extra)
		var linea: HSeparator = HSeparator.new()
		add_child(linea)
		_pila = Control.new()
		_pila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pila.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_pila.clip_contents = true
		add_child(_pila)

	# Añade una pestaña. "contenido" puede ser cualquier Control (se estira para llenar).
	func anadir(nombre: String, contenido: Control, icono: String = "") -> void:
		var b: Button = Button.new()
		b.text = nombre
		b.toggle_mode = true
		b.theme_type_variation = "Pestana"
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if icono != "" and Tema.icono(icono) != null:
			b.icon = Tema.icono(icono)
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 16)
		var i: int = _botones.size()
		b.pressed.connect(func() -> void: elegir(i))
		_barra.add_child(b)
		_botones.append(b)
		contenido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contenido.visible = false
		_pila.add_child(contenido)
		_contenidos.append(contenido)
		if actual < 0:
			elegir(0)

	func elegir(i: int) -> void:
		if i < 0 or i >= _contenidos.size():
			return
		actual = i
		for k in _contenidos.size():
			_contenidos[k].visible = k == i
			_botones[k].set_pressed_no_signal(k == i)
		cambiada.emit(i)

	func indice_de(contenido_buscado: Control) -> int:
		return _contenidos.find(contenido_buscado)

	func renombrar(i: int, texto: String) -> void:
		if i >= 0 and i < _botones.size():
			_botones[i].text = texto

	func hueco_extra() -> HBoxContainer:
		return _extra

	# Solo la barra de pestañas (sin zona de contenido): el contenido lo pone quien llama debajo.
	func solo_barra() -> void:
		_pila.visible = false
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	func contenido(i: int) -> Control:
		return _contenidos[i]

	func total() -> int:
		return _contenidos.size()

	func _input(evento: InputEvent) -> void:
		if not is_visible_in_tree() or _contenidos.size() < 2:
			return
		var paso: int = 0
		var b: InputEventJoypadButton = evento as InputEventJoypadButton
		if b != null and b.pressed:
			if b.button_index == JOY_BUTTON_LEFT_SHOULDER:
				paso = -1
			elif b.button_index == JOY_BUTTON_RIGHT_SHOULDER:
				paso = 1
		elif evento.is_action_pressed("ui_page_up"):
			paso = -1
		elif evento.is_action_pressed("ui_page_down"):
			paso = 1
		if paso != 0:
			elegir(posmod(actual + paso, _contenidos.size()))
			get_viewport().set_input_as_handled()


# ==============================================================================
# Fila de chips exclusivos (uno solo encendido): categorías y filtros. Emite "cambiado(clave)".
class Filtros extends HFlowContainer:
	signal cambiado(clave: String)

	var clave: String = ""
	var _chips: Dictionary = {}

	func _init() -> void:
		add_theme_constant_override("h_separation", 6)
		add_theme_constant_override("v_separation", 6)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func anadir(c: String, texto: String) -> void:
		var chip: Button = UI.chip(texto, _chips.is_empty())
		if _chips.is_empty():
			clave = c
		chip.pressed.connect(func() -> void: elegir(c))
		add_child(chip)
		_chips[c] = chip

	func elegir(c: String) -> void:
		if not _chips.has(c):
			return
		clave = c
		for k in _chips:
			(_chips[k] as Button).set_pressed_no_signal(k == c)
		cambiado.emit(c)

	func texto_de(c: String, texto: String) -> void:
		if _chips.has(c):
			(_chips[c] as Button).text = texto
