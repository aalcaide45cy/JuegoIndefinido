# panel_chat.gd
# -----------------------------------------------------------------------------
# La ventana del chat (abajo a la izquierda). Lee del gestor Chat y solo pinta;
# las reglas (alcance, límites, moderación) las decide ServidorChat.
#
#   Enter (o /)  empieza a escribir        Esc          cierra el chat
#   Tab          siguiente canal           ↑ ↓          recupera lo que escribiste
#   ⚙            filtros, silenciados, grupo y facción
#
# Fuera de escribir se queda casi transparente y no estorba: los mensajes nuevos
# la despiertan unos segundos. Pestañas: Todo, Cercano, Grupo, Privado, Facción,
# Gritar y Sistema (con un punto de color cuando hay algo sin leer).
# -----------------------------------------------------------------------------
class_name PanelChat
extends Control

const ANCHO: float = 392.0
const ALTO_LISTA: float = 150.0
const SEG_VISIBLE: float = 9.0

var escribiendo: bool = false
var hud: Hud = null                       # Lo pone el HUD (de ahí sale tu posición).
var pestana: int = Canales.Id.TODO

var _panel: PanelContainer
var _tabs: HBoxContainer
var _botones: Dictionary = {}               # canal -> Button
var _sin_leer: Dictionary = {}              # canal -> int
var _lista: RichTextLabel
var _fila_entrada: HBoxContainer
var _etiqueta_canal: Label
var _destino: LineEdit
var _entrada: LineEdit
var _pista: Label
var _ajustes: PanelContainer
var _ajustes_caja: VBoxContainer
var _t_activo: float = 0.0
var _recuerdo: Array = []                  # Lo que has escrito (para ↑ ↓).
var _pos_recuerdo: int = 0
var _alfa: float = 0.3


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	custom_minimum_size = Vector2(ANCHO, 0)
	offset_left = 16
	offset_right = 16 + ANCHO
	offset_bottom = -34
	offset_top = -34 - (ALTO_LISTA + 96)
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var caja: VBoxContainer = VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(caja)

	# Pestañas por canal + engranaje.
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 2)
	_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(_tabs)
	for id in Canales.ORDEN:
		var b: Button = Button.new()
		b.toggle_mode = false
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_elegir_pestana.bind(id))
		_tabs.add_child(b)
		_botones[id] = b
	var hueco: Control = Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tabs.add_child(hueco)
	var engranaje: Button = Button.new()
	engranaje.text = "⚙"
	engranaje.tooltip_text = "Filtros, silenciados, grupo y facción"
	engranaje.focus_mode = Control.FOCUS_NONE
	engranaje.add_theme_font_size_override("font_size", 12)
	engranaje.add_theme_stylebox_override("normal", Hud.caja_estilo(Color(0.07, 0.09, 0.09, 0.8), Estilo.BORDE_SUAVE, 4, 1, 4, 2))
	engranaje.add_theme_stylebox_override("hover", Hud.caja_estilo(Color(0.14, 0.22, 0.17), Estilo.ACENTO, 4, 1, 4, 2))
	engranaje.add_theme_stylebox_override("pressed", Hud.caja_estilo(Color(0.1, 0.3, 0.18), Estilo.ACENTO, 4, 1, 4, 2))
	engranaje.pressed.connect(_alternar_ajustes)
	_tabs.add_child(engranaje)

	# Lista de mensajes.
	_lista = RichTextLabel.new()
	_lista.bbcode_enabled = true
	_lista.scroll_active = true
	_lista.scroll_following = true
	_lista.selection_enabled = false
	_lista.custom_minimum_size = Vector2(0, ALTO_LISTA)
	_lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lista.add_theme_font_size_override("normal_font_size", 14)
	_lista.add_theme_font_size_override("bold_font_size", 14)
	_lista.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lista.add_theme_constant_override("outline_size", 4)
	_lista.add_theme_constant_override("line_separation", 2)
	caja.add_child(_lista)

	# Línea de escribir.
	_fila_entrada = HBoxContainer.new()
	_fila_entrada.add_theme_constant_override("separation", 4)
	_fila_entrada.visible = false
	caja.add_child(_fila_entrada)
	_etiqueta_canal = Hud.crear_label(14)
	_etiqueta_canal.custom_minimum_size = Vector2(66, 0)
	_fila_entrada.add_child(_etiqueta_canal)
	_destino = LineEdit.new()
	_destino.placeholder_text = "para…"
	_destino.custom_minimum_size = Vector2(80, 0)
	_destino.add_theme_font_size_override("font_size", 14)
	_destino.max_length = Canales.MAX_LARGO_NOMBRE
	_fila_entrada.add_child(_destino)
	_entrada = LineEdit.new()
	_entrada.placeholder_text = "Escribe y pulsa Enter…"
	_entrada.max_length = Canales.MAX_LARGO
	_entrada.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entrada.add_theme_font_size_override("font_size", 14)
	_entrada.text_submitted.connect(_enviar)
	_entrada.gui_input.connect(_teclas_entrada)
	_fila_entrada.add_child(_entrada)
	_pista = Hud.crear_label(12, Estilo.TEXTO_SUAVE)
	_pista.text = "Enter: escribir  ·  Tab: canal  ·  /ayuda"
	caja.add_child(_pista)

	_crear_ajustes()
	Chat.mensaje_nuevo.connect(_al_llegar)
	Chat.historial_cambiado.connect(_repintar)
	Chat.ajustes_cambiados.connect(_al_cambiar_ajustes)
	pestana = Canales.Id.TODO
	_repintar()
	_refrescar_pestanas()
	_estilo(false)


# ------------------------------- Estilo y fundido -----------------------------

func _estilo(activo: bool) -> void:
	var e: StyleBoxFlat = Hud.caja_estilo(Color(0.04, 0.055, 0.06, 0.88 if activo else 0.42),
			Estilo.BORDE if activo else Color(0.2, 0.34, 0.27, 0.45), 10, 2 if activo else 1, 10, 8)
	e.content_margin_left = 8
	e.content_margin_right = 8
	_panel.add_theme_stylebox_override("panel", e)


func _process(delta: float) -> void:
	if hud != null and hud.jugador != null and Chat.jugador != hud.jugador:
		Chat.jugador = hud.jugador
	_t_activo = maxf(0.0, _t_activo - delta)
	var objetivo: float = 1.0 if (escribiendo or _t_activo > 0.0) else 0.28
	_alfa = lerpf(_alfa, objetivo, minf(1.0, delta * 6.0))
	modulate.a = _alfa
	_pista.visible = not escribiendo and _t_activo <= 0.0


func _despertar() -> void:
	_t_activo = SEG_VISIBLE


# --------------------------------- Pestañas -----------------------------------

func _elegir_pestana(id: int) -> void:
	pestana = id
	_sin_leer[id] = 0
	if Canales.es_escribible(id):
		Chat.ultimo_canal = id
	_refrescar_pestanas()
	_repintar()
	_actualizar_entrada()


func _refrescar_pestanas() -> void:
	for id in _botones:
		var b: Button = _botones[id]
		var n: int = int(_sin_leer.get(id, 0))
		b.text = Canales.nombre(id) + ("  •%d" % n if n > 0 else "")
		var col: Color = Canales.color(id)
		var elegido: bool = id == pestana
		var fondo: Color = col.darkened(0.55) if elegido else Color(0.07, 0.09, 0.09, 0.8)
		for estado in ["normal", "hover", "pressed", "focus"]:
			var s: StyleBoxFlat = Hud.caja_estilo(fondo.lightened(0.12) if estado == "hover" else fondo,
					col if elegido else Color(col.r, col.g, col.b, 0.35), 4, 1, 3, 2)
			b.add_theme_stylebox_override(estado, s)
		b.add_theme_color_override("font_color", col if (elegido or n > 0) else col.darkened(0.25))
		b.add_theme_color_override("font_hover_color", col.lightened(0.2))


func _siguiente_pestana(paso: int = 1) -> void:
	var i: int = Canales.ORDEN.find(pestana)
	i = posmod(i + paso, Canales.ORDEN.size())
	_elegir_pestana(Canales.ORDEN[i])


# --------------------------------- Mensajes -----------------------------------

func _al_llegar(msg: Dictionary) -> void:
	var canal: int = int(msg["canal"])
	_despertar()
	if _visible_en_pestana(canal):
		_lista.append_text(_formato(msg) + "\n")
	else:
		_sin_leer[canal] = int(_sin_leer.get(canal, 0)) + 1
	if pestana != Canales.Id.TODO and pestana != canal:
		pass
	_refrescar_pestanas()


func _visible_en_pestana(canal: int) -> bool:
	if pestana == Canales.Id.TODO:
		return bool(Chat.filtros.get(canal, true))
	return canal == pestana


func _repintar() -> void:
	_lista.clear()
	for m in Chat.historial:
		if _visible_en_pestana(int(m["canal"])):
			_lista.append_text(_formato(m) + "\n")


func _hex(c: Color) -> String:
	return "#" + c.to_html(false)


func _formato(m: Dictionary) -> String:
	var canal: int = int(m["canal"])
	var texto: String = String(m["texto"]).replace("[", "(").replace("]", ")")
	var hora: String = "[color=#7d8a84]%s[/color] " % String(m.get("hora_juego", ""))
	if canal == Canales.Id.SISTEMA:
		var cat: Dictionary = Canales.CATEGORIAS.get(String(m.get("cat", "otros")), Canales.CATEGORIAS["otros"])
		return "%s[color=%s]■ %s[/color] [color=%s]%s[/color]" % [hora, _hex(cat["color"]), cat["nombre"], _hex(Color(cat["color"]).lightened(0.35)), texto]
	var col: Color = Canales.color(canal)
	var propio: bool = int(m["de_id"]) == Chat.mi_id
	var de: String = "Tú" if propio else String(m["de"]).replace("[", "(").replace("]", ")")
	var etiqueta: String = ""
	if canal == Canales.Id.PRIVADO:
		var otro: String = String(m.get("para", "")) if propio else String(m["de"])
		etiqueta = "[color=%s]%s %s[/color] " % [_hex(col), "para" if propio else "de", otro]
	elif pestana == Canales.Id.TODO:
		etiqueta = "[color=%s][%s][/color] " % [_hex(col.darkened(0.1)), Canales.nombre(canal)]
	var nombre: String = "[b][color=%s]%s[/color][/b]" % [_hex(col.lightened(0.25)), de] if canal != Canales.Id.PRIVADO else ""
	var dos_puntos: String = ": " if nombre != "" else ""
	var cuerpo: String = "[color=%s]%s[/color]" % [_hex(col.lightened(0.55)), texto]
	if canal == Canales.Id.GRITAR:
		cuerpo = "[b]%s[/b]" % cuerpo
	return hora + etiqueta + nombre + dos_puntos + cuerpo


# ------------------------------- Escribir ------------------------------------

func _input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	var k: InputEventKey = evento as InputEventKey
	if not escribiendo:
		if Juego.menu_abierto or not visible:
			return
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			abrir()
			get_viewport().set_input_as_handled()
		elif k.unicode == 47:   # "/"
			abrir("/")
			get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_ESCAPE:
		cerrar()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_TAB:
		_siguiente_pestana(-1 if k.shift_pressed else 1)
		get_viewport().set_input_as_handled()


func _teclas_entrada(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed:
		return
	var k: InputEventKey = evento as InputEventKey
	if k.keycode == KEY_UP and not _recuerdo.is_empty():
		_pos_recuerdo = clampi(_pos_recuerdo - 1, 0, _recuerdo.size())
		_entrada.text = String(_recuerdo[_pos_recuerdo]) if _pos_recuerdo < _recuerdo.size() else ""
		_entrada.caret_column = _entrada.text.length()
		_entrada.accept_event()
	elif k.keycode == KEY_DOWN and not _recuerdo.is_empty():
		_pos_recuerdo = clampi(_pos_recuerdo + 1, 0, _recuerdo.size())
		_entrada.text = String(_recuerdo[_pos_recuerdo]) if _pos_recuerdo < _recuerdo.size() else ""
		_entrada.caret_column = _entrada.text.length()
		_entrada.accept_event()


func abrir(previo: String = "") -> void:
	if escribiendo:
		return
	escribiendo = true
	Juego.menu_abierto = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Si estás mirando "Todo" o "Sistema" se escribe en el último canal usado.
	if not Canales.es_escribible(pestana) and not Canales.es_escribible(Chat.ultimo_canal):
		Chat.ultimo_canal = Canales.Id.CERCANO
	_estilo(true)
	_fila_entrada.visible = true
	_mouse_activo(true)
	_actualizar_entrada()
	_entrada.text = previo
	_entrada.grab_focus()
	_entrada.caret_column = _entrada.text.length()
	_pos_recuerdo = _recuerdo.size()
	_despertar()


func cerrar() -> void:
	if not escribiendo:
		return
	escribiendo = false
	_entrada.release_focus()
	_destino.release_focus()
	_fila_entrada.visible = false
	_ajustes.visible = false
	_estilo(false)
	_mouse_activo(false)
	Juego.menu_abierto = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_despertar()


func _mouse_activo(si: bool) -> void:
	var filtro: int = Control.MOUSE_FILTER_STOP if si else Control.MOUSE_FILTER_IGNORE
	_panel.mouse_filter = filtro
	for b in _botones.values():
		(b as Button).mouse_filter = Control.MOUSE_FILTER_STOP
	_lista.mouse_filter = Control.MOUSE_FILTER_STOP if si else Control.MOUSE_FILTER_IGNORE


func _canal_de_escritura() -> int:
	return pestana if Canales.es_escribible(pestana) else Chat.ultimo_canal


func _actualizar_entrada() -> void:
	var c: int = _canal_de_escritura()
	_etiqueta_canal.text = Canales.nombre(c)
	_etiqueta_canal.add_theme_color_override("font_color", Canales.color(c))
	_destino.visible = c == Canales.Id.PRIVADO and escribiendo
	if _destino.visible and _destino.text == "":
		_destino.text = Chat.ultimo_destino


func _enviar(texto: String) -> void:
	var t: String = texto.strip_edges()
	if t != "":
		_recuerdo.append(t)
		if _recuerdo.size() > 40:
			_recuerdo.pop_front()
		Chat.enviar(_canal_de_escritura(), t, _destino.text.strip_edges())
		_t_activo = SEG_VISIBLE
	cerrar()


# --------------------------------- Ajustes ------------------------------------

func _crear_ajustes() -> void:
	_ajustes = PanelContainer.new()
	_ajustes.visible = false
	_ajustes.add_theme_stylebox_override("panel", Hud.caja_estilo(Estilo.FONDO, Estilo.BORDE, 8, 2, 12, 10))
	_ajustes.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_ajustes.position = Vector2(0, -250)
	_ajustes.custom_minimum_size = Vector2(ANCHO, 0)
	_ajustes.z_index = 2
	add_child(_ajustes)
	_ajustes_caja = VBoxContainer.new()
	_ajustes_caja.add_theme_constant_override("separation", 4)
	_ajustes.add_child(_ajustes_caja)


func _alternar_ajustes() -> void:
	_ajustes.visible = not _ajustes.visible
	_al_cambiar_ajustes()


func _al_cambiar_ajustes() -> void:
	_repintar()
	if not _ajustes.visible:
		return
	for h in _ajustes_caja.get_children():
		h.queue_free()
	var t: Label = Hud.crear_label(16, Estilo.ACENTO)
	t.text = "Chat · filtros"
	_ajustes_caja.add_child(t)
	var sub: Label = Hud.crear_label(12, Estilo.TEXTO_SUAVE)
	sub.text = "Qué canales se ven en la pestaña «Todo»"
	_ajustes_caja.add_child(sub)
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	_ajustes_caja.add_child(fila)
	for id in Canales.ORDEN:
		if id == Canales.Id.TODO:
			continue
		var c: CheckBox = CheckBox.new()
		c.text = Canales.nombre(id)
		c.button_pressed = bool(Chat.filtros.get(id, true))
		c.focus_mode = Control.FOCUS_NONE
		c.add_theme_font_size_override("font_size", 12)
		c.add_theme_color_override("font_color", Canales.color(id))
		c.toggled.connect(func(on: bool) -> void: Chat.poner_filtro(id, on))
		fila.add_child(c)
	var g: Label = Hud.crear_label(13, Estilo.TEXTO)
	g.text = "Grupo: %s    ·    Facción: %s" % [Chat.mi_grupo() if Chat.mi_grupo() != "" else "ninguno", Chat.mi_faccion() if Chat.mi_faccion() != "" else "ninguna"]
	_ajustes_caja.add_child(g)
	var ign: Array = Chat.ignorados()
	var s2: Label = Hud.crear_label(12, Estilo.TEXTO_SUAVE)
	s2.text = "Silenciados: " + (", ".join(ign) if not ign.is_empty() else "nadie") + "   (/silenciar NOMBRE)"
	s2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s2.custom_minimum_size = Vector2(ANCHO - 30, 0)
	_ajustes_caja.add_child(s2)
	for n in ign:
		_ajustes_caja.add_child(Hud.crear_boton("Dejar de silenciar a %s" % n, Chat.dejar_de_ignorar.bind(n)))
