# bolsa_trabajo.gd
# -----------------------------------------------------------------------------
# Ventana de la Bolsa de trabajo: candidatos del día (contratar), tu personal
# (asignar destino, despedir) y el almacén donde dejan lo que producen.
# SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name BolsaTrabajo
extends Ventana

const DatosPersonal = preload("res://scripts/datos/personal.gd")
const DatosObjetos = preload("res://scripts/datos/objetos.gd")

var _lista: VBoxContainer
var _texto: Label


func construir() -> void:
	var caja: VBoxContainer = marco("Bolsa de trabajo", "", Vector2(860, 620))
	caja.add_child(UI.nota("Los sueldos se pagan cada día del juego. Sin dinero ese día, se van."))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lista)
	_texto = Hud.crear_label(17, Color(1, 0.9, 0.6))
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_texto)
	_pintar()


func _titulo(t: String) -> void:
	var l: Label = UI.etiqueta("", "Titulo", Tema.BRUMA, 18)
	l.text = t
	_lista.add_child(l)


func _fila() -> HBoxContainer:
	var f: HBoxContainer = HBoxContainer.new()
	f.add_theme_constant_override("separation", 8)
	_lista.add_child(f)
	return f


func _etiqueta(f: Container, texto: String, ancho: float) -> void:
	var l: Label = Hud.crear_label(16)
	l.text = texto
	l.custom_minimum_size.x = ancho
	f.add_child(l)


func _pintar() -> void:
	for h in _lista.get_children():
		h.queue_free()
	_titulo("TU PERSONAL (%d/%d)" % [Juego.personal.size(), DatosPersonal.MAX_PERSONAL])
	if Juego.personal.is_empty():
		_etiqueta(_fila(), "Todavía no has contratado a nadie.", 400.0)
	for e in Juego.personal:
		var f: HBoxContainer = _fila()
		_etiqueta(f, "%s · %s niv. %d · %d $/día" % [e["nombre"], DatosPersonal.OFICIOS[e["oficio"]]["nombre"],
				e["nivel"], e["sueldo"]], 380.0)
		var destinos: Array = _destinos(str(e["oficio"]))
		if destinos.is_empty():
			_etiqueta(f, "(sin destino)", 150.0)
		else:
			var opc: OptionButton = OptionButton.new()
			opc.focus_mode = Control.FOCUS_NONE
			opc.add_item("Sin asignar", 0)
			var elegido: int = 0
			for i in destinos.size():
				opc.add_item(str(destinos[i][1]), i + 1)
				if destinos[i][0] == e["destino"]:
					elegido = i + 1
			opc.select(elegido)
			opc.item_selected.connect(_asignar.bind(e, destinos))
			f.add_child(opc)
		f.add_child(Hud.crear_boton("Despedir", _despedir.bind(e)))
	_titulo("ALMACÉN (lo que produce tu personal)")
	var hay: bool = false
	for id_obj in Juego.almacen:
		if int(Juego.almacen[id_obj]) > 0:
			hay = true
			_etiqueta(_fila(), "%d x %s" % [Juego.almacen[id_obj], DatosObjetos.nombre(id_obj)], 400.0)
	if hay:
		_fila().add_child(Hud.crear_boton("Recoger todo al inventario", _recoger))
	else:
		_etiqueta(_fila(), "Vacío.", 200.0)
	_titulo("CANDIDATOS DE HOY (cambian cada día)")
	for c in DatosPersonal.candidatos(Juego.dia):
		if _contratado(str(c["id"])):
			continue
		var f2: HBoxContainer = _fila()
		_etiqueta(f2, "%s · %s niv. %d" % [c["nombre"], DatosPersonal.OFICIOS[c["oficio"]]["nombre"], c["nivel"]], 300.0)
		_etiqueta(f2, "%d $/día" % c["sueldo"], 100.0)
		f2.add_child(Hud.crear_boton("Contratar", _contratar.bind(c)))
		_etiqueta(_fila(), "    " + str(DatosPersonal.OFICIOS[c["oficio"]]["descripcion"]), 600.0)


func _contratado(id_c: String) -> bool:
	for e in Juego.personal:
		if e["id"] == id_c:
			return true
	return false


# Posibles destinos de un oficio: lista de [id, nombre].
func _destinos(oficio: String) -> Array:
	var r: Array = []
	if oficio == "agricultor":
		for id_h in Juego.huertos:
			r.append([str(id_h), "Huerto " + str(id_h).trim_prefix("huerto_").to_upper()])
	elif oficio == "ganadero":
		r = [["gallinero", "Gallinero"], ["establo", "Establo"]]
	return r


func _contratar(c: Dictionary) -> void:
	if Juego.personal.size() >= DatosPersonal.MAX_PERSONAL:
		_texto.text = "No caben más empleados (máximo %d)." % DatosPersonal.MAX_PERSONAL
		return
	if not Juego.gastar(int(c["sueldo"])):   # El primer día se paga al contratar.
		_texto.text = "No te llega para pagar el primer día (%d $)." % c["sueldo"]
		return
	Juego.personal.append(c.duplicate())
	_texto.text = "Has contratado a %s. Asígnale un destino." % c["nombre"]
	_pintar()


func _despedir(e: Dictionary) -> void:
	Juego.personal.erase(e)
	_texto.text = "Has despedido a %s." % e["nombre"]
	_pintar()


func _asignar(indice: int, e: Dictionary, destinos: Array) -> void:
	if indice == 0:
		e["destino"] = ""
	else:
		var id_d: String = str(destinos[indice - 1][0])
		for otro in Juego.personal:   # Un destino, un solo empleado.
			if otro["oficio"] == e["oficio"] and otro["destino"] == id_d:
				otro["destino"] = ""
		e["destino"] = id_d
	_pintar()


func _recoger() -> void:
	for id_obj in Juego.almacen.keys():
		var n: int = int(Juego.almacen[id_obj])
		if n > 0:
			var sobra: int = Juego.anadir(str(id_obj), n)
			Juego.almacen[id_obj] = sobra
	_texto.text = "Recogido lo que cabía en tu inventario."
	_pintar()
