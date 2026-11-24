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
var _filtros: UI.Filtros
var _lista: ItemList
var _entradas: Array = []
var _detalle: DetalleObjeto
var _ficha_otro: Label
var _aviso: Label
var _cantidad: SpinBox
var _destino: OptionButton
var _total: Label


func construir() -> void:
	var cuerpo: VBoxContainer
	if incrustada:
		cuerpo = VBoxContainer.new()
		cuerpo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cuerpo.add_theme_constant_override("separation", 8)
		add_child(cuerpo)
	else:
		cuerpo = marco("Aparecer cualquier cosa", "", Vector2(1080, 660))
	var columnas: HBoxContainer = HBoxContainer.new()
	columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columnas.add_theme_constant_override("separation", 16)
	cuerpo.add_child(columnas)

	# Izquierda: buscador, categorías y lista.
	var izq: VBoxContainer = VBoxContainer.new()
	izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izq.add_theme_constant_override("separation", 8)
	columnas.add_child(izq)
	_buscador = UI.buscador("Buscar por nombre…", func(_t: String) -> void: _rellenar())
	izq.add_child(_buscador)
	_filtros = UI.Filtros.new()
	_filtros.anadir("", "Todo")
	for c in AdminCatalogo.categorias():
		_filtros.anadir(str(c), str(c))
	_filtros.cambiado.connect(func(c: String) -> void:
		_categoria = c
		_rellenar())
	izq.add_child(_filtros)
	_total = UI.nota("", false)
	izq.add_child(_total)
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.add_theme_font_size_override("font_size", 16)
	_lista.item_selected.connect(func(_i: int) -> void: _mostrar_detalle())
	_lista.item_activated.connect(func(_i: int) -> void: _aparecer())
	izq.add_child(_lista)

	# Derecha: ficha, cantidad, destino y atajos.
	var der: VBoxContainer = VBoxContainer.new()
	der.custom_minimum_size.x = 340
	der.add_theme_constant_override("separation", 8)
	columnas.add_child(der)
	_detalle = DetalleObjeto.new(340.0)
	der.add_child(_detalle)
	_ficha_otro = UI.parrafo("", Tema.TEXTO_SUAVE, 15)
	der.add_child(_ficha_otro)
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	der.add_child(fila)
	fila.add_child(UI.etiqueta("Cantidad", "Subtitulo"))
	_cantidad = SpinBox.new()
	_cantidad.min_value = 1
	_cantidad.max_value = 999
	_cantidad.value = 1
	fila.add_child(_cantidad)
	_destino = OptionButton.new()
	_destino.add_item("A mi inventario")
	_destino.add_item("En el suelo, delante de mí")
	_destino.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(_destino)
	var fila_b: HBoxContainer = HBoxContainer.new()
	fila_b.add_theme_constant_override("separation", 8)
	der.add_child(fila_b)
	var ap: Button = UI.boton("Aparecer", _aparecer, "BotonPrimario")
	ap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_b.add_child(ap)
	fila_b.add_child(UI.boton("Equipar arma ahora", _equipar))
	var atajos: HFlowContainer = HFlowContainer.new()
	atajos.add_theme_constant_override("h_separation", 6)
	atajos.add_theme_constant_override("v_separation", 6)
	der.add_child(atajos)
	atajos.add_child(UI.boton("Munición (60 de cada)", func() -> void: _decir(AdminCatalogo.dar_municion(60))))
	atajos.add_child(UI.boton("Kit de armas y explosivos", _kit))
	for cantidad in [1000, 100000]:
		atajos.add_child(UI.boton("+%s" % UI.dinero(cantidad), func() -> void:
			Juego.dinero += cantidad
			Juego.cambio.emit()
			_decir("Te has dado %d $." % cantidad)))
	_aviso = UI.parrafo("", Tema.ACENTO, 15)
	der.add_child(_aviso)
	_filtros.elegir(categoria_inicial) if categoria_inicial != "" else _rellenar()


func _rellenar() -> void:
	_entradas = AdminCatalogo.entradas(_categoria, _buscador.text)
	_lista.clear()
	_total.text = "%d resultados" % _entradas.size()
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
	if not e.is_empty() and e["tipo"] == "objeto" and AdminCatalogo.DatosObjetos.existe(str(e["id"])):
		_detalle.visible = true
		_ficha_otro.text = ""
		_detalle.mostrar(str(e["id"]), Juego.cuenta(str(e["id"])))
	else:
		_detalle.visible = false
		_ficha_otro.text = "" if e.is_empty() else "%s\n%s" % [e["nombre"], e["descripcion"]]


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
