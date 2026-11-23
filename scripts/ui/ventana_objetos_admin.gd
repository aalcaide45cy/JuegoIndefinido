# ventana_objetos_admin.gd
# -----------------------------------------------------------------------------
# "Aparecer cualquier cosa" del panel de administrador: buscador, categorías,
# cantidad y destino (inventario o suelo delante de ti). El catálogo lo lee solo
# AdminCatalogo (ver scripts/admin/admin_catalogo.gd).
# Se abre desde Ventanas.Admin.
# -----------------------------------------------------------------------------
class_name VentanaObjetosAdmin
extends Ventana

var jugador: Node3D = null
var categoria_inicial: String = ""
var _categoria: String = ""
var _buscador: LineEdit
var _lista: ItemList
var _entradas: Array = []
var _detalle: Label
var _aviso: Label
var _cantidad: SpinBox
var _destino: OptionButton
var _botones_cat: Dictionary = {}


func construir() -> void:
	var caja: VBoxContainer = panel_centrado(Vector2(900, 760))
	cabecera(caja, "Aparecer cualquier cosa")
	_buscador = LineEdit.new()
	_buscador.placeholder_text = "Buscar por nombre…"
	_buscador.clear_button_enabled = true
	_buscador.text_changed.connect(func(_t: String) -> void: _rellenar())
	caja.add_child(_buscador)

	var cats: HFlowContainer = HFlowContainer.new()
	caja.add_child(cats)
	var todas: Button = Hud.crear_boton("Todo", _elegir_categoria.bind(""))
	todas.toggle_mode = true
	cats.add_child(todas)
	_botones_cat[""] = todas
	for c in AdminCatalogo.categorias():
		var b: Button = Hud.crear_boton(str(c), _elegir_categoria.bind(c))
		b.toggle_mode = true
		cats.add_child(b)
		_botones_cat[c] = b

	_lista = ItemList.new()
	_lista.custom_minimum_size = Vector2(0, 330)
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.add_theme_font_size_override("font_size", 17)
	_lista.item_selected.connect(func(_i: int) -> void: _mostrar_detalle())
	_lista.item_activated.connect(func(_i: int) -> void: _aparecer())
	caja.add_child(_lista)
	_detalle = Hud.crear_label(16, Color(0.8, 0.9, 1.0))
	_detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle.custom_minimum_size = Vector2(0, 44)
	caja.add_child(_detalle)

	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	caja.add_child(fila)
	var t: Label = Hud.crear_label(16)
	t.text = "Cantidad"
	fila.add_child(t)
	_cantidad = SpinBox.new()
	_cantidad.min_value = 1
	_cantidad.max_value = 999
	_cantidad.value = 1
	fila.add_child(_cantidad)
	_destino = OptionButton.new()
	_destino.focus_mode = Control.FOCUS_NONE
	_destino.add_item("A mi inventario")
	_destino.add_item("En el suelo, delante de mí")
	fila.add_child(_destino)
	fila.add_child(Hud.crear_boton("Aparecer", _aparecer))
	fila.add_child(Hud.crear_boton("Equipar arma ahora", _equipar))

	var fila2: HBoxContainer = HBoxContainer.new()
	fila2.add_theme_constant_override("separation", 8)
	caja.add_child(fila2)
	fila2.add_child(Hud.crear_boton("Munición (60 de cada)", func() -> void: _decir(AdminCatalogo.dar_municion(60))))
	fila2.add_child(Hud.crear_boton("Kit de armas y explosivos", _kit))
	for cantidad in [1000, 100000]:
		fila2.add_child(Hud.crear_boton("+%d $" % cantidad, func() -> void:
			Juego.dinero += cantidad
			Juego.cambio.emit()
			_decir("Te has dado %d $." % cantidad)))
	_aviso = Hud.crear_label(16, Color(1, 0.92, 0.6))
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_aviso)

	_elegir_categoria(categoria_inicial)
	_buscador.grab_focus.call_deferred()


func _elegir_categoria(c: String) -> void:
	_categoria = c
	for k in _botones_cat:
		(_botones_cat[k] as Button).set_pressed_no_signal(k == c)
	_rellenar()


func _rellenar() -> void:
	_entradas = AdminCatalogo.entradas(_categoria, _buscador.text)
	_lista.clear()
	for e in _entradas:
		_lista.add_item("%s   ·   %s" % [e["nombre"], e["categoria"]] if _categoria == "" else str(e["nombre"]))
	if not _entradas.is_empty():
		_lista.select(0)
	_mostrar_detalle()


func _actual() -> Dictionary:
	var sel: PackedInt32Array = _lista.get_selected_items()
	if sel.is_empty() or sel[0] >= _entradas.size():
		return {}
	return _entradas[sel[0]]


func _mostrar_detalle() -> void:
	var e: Dictionary = _actual()
	_detalle.text = "" if e.is_empty() else "%s — %s" % [e["nombre"], e["descripcion"]]


func _decir(texto: String) -> void:
	_aviso.text = texto
	Juego.avisar(texto)


func _aparecer() -> void:
	var e: Dictionary = _actual()
	if e.is_empty() or jugador == null:
		return
	_decir(AdminCatalogo.dar(e, int(_cantidad.value), _destino.selected == 1, jugador))


func _equipar() -> void:
	var e: Dictionary = _actual()
	if e.is_empty() or e["tipo"] != "objeto":
		_decir("Elige un arma de la lista.")
		return
	var tipo: String = str(AdminCatalogo.DatosObjetos.datos(str(e["id"]))["tipo"])
	if tipo != "arma_cc" and tipo != "arma_fuego" and tipo != "explosivo" and tipo != "herramienta":
		_decir("Eso no es un arma.")
		return
	_decir(AdminCatalogo.equipar(str(e["id"])))


func _kit() -> void:
	var n: int = 0
	for e in AdminCatalogo.entradas(AdminCatalogo.CAT_ARMAS):
		if e["tipo"] == "objeto":
			Juego.anadir(str(e["id"]), 1)
			n += 1
	for e in AdminCatalogo.entradas(AdminCatalogo.CAT_EXPLOSIVOS):
		if e["tipo"] == "objeto":
			Juego.anadir(str(e["id"]), 5)
			n += 1
	AdminCatalogo.dar_municion(60)
	_decir("Kit entregado: %d tipos de arma y explosivo, con munición." % n)
