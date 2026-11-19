# ventana_ajustes.gd
# -----------------------------------------------------------------------------
# "Ajustes del mundo y presets": se abre desde el panel de administrador (F1).
# Permite tocar la linterna, la hora, el clima, la velocidad del jugador, etc., y
# guardar el conjunto con un nombre para volver a cargarlo cuando quieras.
# La lógica y el archivo de presets están en scripts/ajustes_mundo.gd.
# -----------------------------------------------------------------------------
class_name VentanaAjustes
extends Ventana

var _mensaje: Label
var _lista: OptionButton
var _nombre: LineEdit
var _sliders: Dictionary = {}      # id -> HSlider
var _textos: Dictionary = {}       # id -> Label con el valor
var _color: ColorPickerButton
var _poli: CheckButton
var _pendiente: String = ""        # Acción que espera confirmación ("guardar:x" o "borrar:x").


func construir() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var caja: VBoxContainer = panel_centrado(Vector2(720, 700))
	cabecera(caja, "Ajustes del mundo y presets")
	_mensaje = Hud.crear_label(16, Color(1, 0.92, 0.6))
	_mensaje.text = "Los cambios se aplican al momento. Guárdalos como preset para recuperarlos."
	_mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_mensaje)

	# --- Presets ---
	subtitulo(caja, "Presets guardados")
	var fila: HBoxContainer = HBoxContainer.new()
	caja.add_child(fila)
	_lista = OptionButton.new()
	_lista.focus_mode = Control.FOCUS_NONE
	_lista.custom_minimum_size = Vector2(260, 0)
	fila.add_child(_lista)
	fila.add_child(Hud.crear_boton("Cargar", _cargar))
	fila.add_child(Hud.crear_boton("Borrar", _borrar))
	var fila2: HBoxContainer = HBoxContainer.new()
	caja.add_child(fila2)
	_nombre = LineEdit.new()
	_nombre.placeholder_text = "Nombre del preset nuevo"
	_nombre.custom_minimum_size = Vector2(300, 0)
	_nombre.max_length = 30
	_nombre.text_changed.connect(func(_t: String) -> void: _pendiente = "")
	fila2.add_child(_nombre)
	fila2.add_child(Hud.crear_boton("Guardar aquí los ajustes", _guardar))
	_rellenar_lista()

	# --- Ajustes ---
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(scroll)
	var lista: VBoxContainer = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 6)
	scroll.add_child(lista)

	subtitulo(lista, "Clima")
	var clima: HBoxContainer = HBoxContainer.new()
	lista.add_child(clima)
	for id in Clima.TIPOS:
		clima.add_child(Hud.crear_boton(String(Clima.TIPOS[id]["nombre"]), func() -> void:
			AjustesMundo.aplicar({"clima": id})))

	for e in AjustesMundo.DEFINICION:
		_crear_slider(lista, e)
		if e["id"] == "linterna_angulo":
			var f: HBoxContainer = HBoxContainer.new()
			lista.add_child(f)
			subtitulo(f, "Linterna: color   ")
			_color = ColorPickerButton.new()
			_color.custom_minimum_size = Vector2(90, 28)
			_color.edit_alpha = false
			_color.color = AjustesMundo.linterna_color
			_color.color_changed.connect(func(c: Color) -> void:
				AjustesMundo.aplicar({"linterna_color": c.to_html(false)}))
			f.add_child(_color)
			f.add_child(Hud.crear_boton("Encender / apagar linterna (F)", func() -> void:
				for j in get_tree().get_nodes_in_group("jugador"):
					if j.has_method("poner_linterna"):
						j.poner_linterna(not j.linterna_encendida())))

	_poli = CheckButton.new()
	_poli.text = "Policía activa"
	_poli.focus_mode = Control.FOCUS_NONE
	_poli.button_pressed = Juego.policia_activa
	_poli.toggled.connect(func(v: bool) -> void: AjustesMundo.aplicar({"policia": v}))
	lista.add_child(_poli)


func _crear_slider(caja: Container, e: Dictionary) -> void:
	var id: String = e["id"]
	var etiqueta: Label = subtitulo(caja, "")
	var s: HSlider = HSlider.new()
	s.min_value = e["min"]
	s.max_value = e["max"]
	s.step = e["paso"]
	s.custom_minimum_size = Vector2(0, 22)
	s.value = AjustesMundo.valor(id)
	_sliders[id] = s
	_textos[id] = etiqueta
	_poner_texto(id)
	s.value_changed.connect(func(v: float) -> void:
		AjustesMundo.aplicar({id: v})
		_poner_texto(id))
	caja.add_child(s)


func _poner_texto(id: String) -> void:
	var e: Dictionary = AjustesMundo.def(id)
	var v: float = _sliders[id].value
	_textos[id].text = "%s:  %s" % [e["nombre"], ("%.2f" % v) if float(e["paso"]) < 1.0 else str(int(v))]


func _process(_delta: float) -> void:
	# La hora y el reloj avanzan solos: que el slider los siga (si no lo estás tocando).
	if not _sliders["hora"].has_focus():
		_sliders["hora"].set_value_no_signal(Juego.hora)
		_poner_texto("hora")


# Vuelve a colocar los controles según los ajustes actuales (tras cargar un preset).
func _refrescar() -> void:
	var d: Dictionary = AjustesMundo.capturar()
	for id in _sliders:
		_sliders[id].set_value_no_signal(float(d[id]))
		_poner_texto(id)
	_color.color = AjustesMundo.linterna_color
	_poli.set_pressed_no_signal(Juego.policia_activa)


func _rellenar_lista(elegir: String = "") -> void:
	_lista.clear()
	for n in AjustesMundo.nombres():
		_lista.add_item(n)
		if n == elegir:
			_lista.select(_lista.item_count - 1)


func _elegido() -> String:
	return _lista.get_item_text(_lista.selected) if _lista.selected >= 0 else ""


func _decir(texto: String) -> void:
	_mensaje.text = texto


func _cargar() -> void:
	_pendiente = ""
	var n: String = _elegido()
	if AjustesMundo.cargar(n):
		_refrescar()
		_decir("Preset «%s» cargado." % n)
	else:
		_decir("No se pudo cargar «%s»." % n)


func _guardar() -> void:
	var n: String = _nombre.text.strip_edges()
	if n == "":
		n = _elegido()   # Sin nombre nuevo: sobrescribe el elegido en la lista.
	if AjustesMundo.existe(n) and n != AjustesMundo.PREDETERMINADO and _pendiente != "guardar:" + n:
		_pendiente = "guardar:" + n
		_decir("«%s» ya existe. Pulsa «Guardar» otra vez para sobrescribirlo." % n)
		return
	_pendiente = ""
	var error: String = AjustesMundo.guardar(n)
	if error != "":
		_decir(error)
		return
	_rellenar_lista(n)
	_nombre.text = ""
	_decir("Preset «%s» guardado." % n)


func _borrar() -> void:
	var n: String = _elegido()
	if n == AjustesMundo.PREDETERMINADO:
		_decir("«%s» es fijo y no se puede borrar." % n)
		return
	if _pendiente != "borrar:" + n:
		_pendiente = "borrar:" + n
		_decir("Pulsa «Borrar» otra vez para borrar «%s» para siempre." % n)
		return
	_pendiente = ""
	if AjustesMundo.borrar(n):
		_rellenar_lista()
		_decir("Preset «%s» borrado." % n)
