# telefono.gd
# -----------------------------------------------------------------------------
# El móvil del jugador (tecla P). Pantalla vertical con tres pestañas:
#   Encargos : ofertas de clientes (aceptar / rechazar) y encargos en curso
#              (dónde espera el comprador y cuánto tiempo le queda).
#   Pedidos  : comprar materiales y recibirlos en unos segundos.
#   Avisos   : historial de mensajes (ventas, pedidos que llegan, plantones).
# La lógica está en scripts/encargos.gd. SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name Telefono
extends Ventana

const DatosObjetos = preload("res://scripts/datos/objetos.gd")
const ACENTO: Color = Color(0.35, 0.8, 1.0)

var _gestor: Encargos
var _pestana: int = 0
var _contenido: VBoxContainer
var _cabecera_info: Label
var _firma: String = ""
var _temporizadores: Array = []   # [Label, id_encargo o -1, texto_base]
var _cantidades: Dictionary = {}  # id material -> cantidad elegida


func construir() -> void:
	_gestor = get_tree().get_first_node_in_group("gestor_encargos") as Encargos
	var marco: PanelContainer = PanelContainer.new()
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(0.05, 0.06, 0.09)
	estilo.border_color = Color(0.12, 0.13, 0.17)
	estilo.set_border_width_all(10)
	estilo.set_corner_radius_all(34)
	estilo.set_content_margin_all(16)
	marco.add_theme_stylebox_override("panel", estilo)
	Hud.centrar(marco, Vector2(400.0, 660.0))
	add_child(marco)
	var caja: VBoxContainer = VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	marco.add_child(caja)

	_cabecera_info = Hud.crear_label(15, ACENTO)
	caja.add_child(_cabecera_info)
	var pestanas: HBoxContainer = HBoxContainer.new()
	pestanas.add_theme_constant_override("separation", 6)
	caja.add_child(pestanas)
	for i in 3:
		var b: Button = Hud.crear_boton(["Encargos", "Pedidos", "Avisos"][i], _cambiar_pestana.bind(i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pestanas.add_child(b)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(scroll)
	_contenido = VBoxContainer.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.add_theme_constant_override("separation", 8)
	scroll.add_child(_contenido)
	caja.add_child(Hud.crear_boton("Guardar el móvil (P / Esc)", cerrar))
	_reconstruir()


func _cambiar_pestana(i: int) -> void:
	_pestana = i
	_reconstruir()


func _process(_delta: float) -> void:
	_cabecera_info.text = "%s    Dinero: %d $    Reputación: %d" % [Juego.texto_hora(), Juego.dinero, Juego.reputacion]
	# Solo se reconstruye si cambia la estructura (no cada vez que baja un contador).
	var firma: String = "%d|" % _pestana
	for e in Juego.encargos:
		firma += "%s%s," % [e["id"], e["estado"]]
	firma += "|%d|%d" % [Juego.pedidos_material.size(), Juego.avisos.size()]
	if firma != _firma:
		_reconstruir()
	for t in _temporizadores:
		var etiqueta: Label = t[0]
		if not is_instance_valid(etiqueta):
			continue
		if int(t[1]) >= 0:
			for e in Juego.encargos:
				if int(e["id"]) == int(t[1]):
					etiqueta.text = "%s%d s" % [t[2], int(e["t"])]
		else:
			etiqueta.text = t[2]


func _reconstruir() -> void:
	for h in _contenido.get_children():
		h.queue_free()
	_temporizadores.clear()
	_firma = "%d|" % _pestana
	for e in Juego.encargos:
		_firma += "%s%s," % [e["id"], e["estado"]]
	_firma += "|%d|%d" % [Juego.pedidos_material.size(), Juego.avisos.size()]
	match _pestana:
		0: _pintar_encargos()
		1: _pintar_pedidos()
		2: _pintar_avisos()


func _tarjeta() -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	var est: StyleBoxFlat = StyleBoxFlat.new()
	est.bg_color = Color(0.1, 0.12, 0.17)
	est.set_corner_radius_all(14)
	est.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", est)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.add_child(panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	return v


func _texto(v: Container, texto: String, tam: int = 15, color: Color = Color(0.9, 0.92, 0.95)) -> Label:
	var l: Label = Hud.crear_label(tam, color)
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 330.0
	v.add_child(l)
	return l


func _pintar_encargos() -> void:
	if _gestor == null:
		_texto(_contenido, "Sin cobertura.")
		return
	var hay: bool = false
	for e in Juego.encargos:
		hay = true
		var v: VBoxContainer = _tarjeta()
		var nombre_p: String = GameData.POCIONES[e["pocion"]]["nombre"]
		var pos: Array = e["pos"]
		_texto(v, "%s" % e["cliente"], 18, ACENTO)
		_texto(v, "Quiere: %d x %s" % [e["cantidad"], nombre_p])
		_texto(v, "Pago: %d $   (tienes %d)" % [e["pago"], Juego.cuenta("pocion_" + str(e["pocion"]))])
		if e["estado"] == "oferta":
			var t: Label = _texto(v, "", 14, Color(1.0, 0.8, 0.4))
			_temporizadores.append([t, int(e["id"]), "Responde en: "])
			var fila: HBoxContainer = HBoxContainer.new()
			v.add_child(fila)
			var acepta: Button = Hud.crear_boton("Aceptar", _aceptar.bind(int(e["id"])))
			acepta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fila.add_child(acepta)
			var rechaza: Button = Hud.crear_boton("Rechazar", _rechazar.bind(int(e["id"])))
			rechaza.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fila.add_child(rechaza)
		else:
			_texto(v, "Te espera en: %s" % e["lugar"], 15, Color(0.6, 1.0, 0.7))
			_texto(v, "Sale marcado en la brújula y el mapa (N).", 13, Color(0.7, 0.75, 0.8))
			var t2: Label = _texto(v, "", 14, Color(1.0, 0.8, 0.4))
			_temporizadores.append([t2, int(e["id"]), "Se va en: "])
			v.add_child(Hud.crear_boton("Cancelar (pierdes reputación)", _cancelar.bind(int(e["id"]))))
	if not hay:
		_texto(_contenido, "No hay encargos. Cuando alguien quiera comprar, te llegará un mensaje.", 15, Color(0.7, 0.75, 0.8))


func _aceptar(id: int) -> void:
	_gestor.aceptar(id)
	_reconstruir()


func _rechazar(id: int) -> void:
	_gestor.rechazar(id)
	_reconstruir()


func _cancelar(id: int) -> void:
	_gestor.cancelar(id)
	_reconstruir()


func _pintar_pedidos() -> void:
	if _gestor == null:
		return
	_texto(_contenido, "Envío: %d $ por pedido. Llega en %d s." % [Encargos.TASA_ENVIO, int(Encargos.ENTREGA_MATERIAL)], 13, Color(0.7, 0.75, 0.8))
	for p in Juego.pedidos_material:
		var v: VBoxContainer = _tarjeta()
		_texto(v, "En camino: %d x %s" % [p["cantidad"], DatosObjetos.nombre(str(p["id"]))], 14, Color(0.6, 1.0, 0.7))
	for id in DatosObjetos.LISTA:
		var d: Dictionary = DatosObjetos.LISTA[id]
		if d["tienda"] != "herbolario" and d["tienda"] != "ferreteria":
			continue
		if d["tipo"] != "semilla" and d["tipo"] != "material":
			continue
		var cant: int = int(_cantidades.get(id, 5))
		var v: VBoxContainer = _tarjeta()
		_texto(v, "%s  (%d $ c/u)" % [d["nombre"], d["precio"]], 15)
		var fila: HBoxContainer = HBoxContainer.new()
		v.add_child(fila)
		fila.add_child(Hud.crear_boton("-", _cambiar_cantidad.bind(id, -1)))
		var l: Label = Hud.crear_label(16)
		l.text = "  %d  " % cant
		fila.add_child(l)
		fila.add_child(Hud.crear_boton("+", _cambiar_cantidad.bind(id, 1)))
		var b: Button = Hud.crear_boton("Pedir %d (%d $)" % [cant, int(d["precio"]) * cant + Encargos.TASA_ENVIO], _pedir.bind(id))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(b)


func _cambiar_cantidad(id: String, delta: int) -> void:
	_cantidades[id] = clampi(int(_cantidades.get(id, 5)) + delta, 1, DatosObjetos.pila(id))
	_reconstruir()


func _pedir(id: String) -> void:
	var error: String = _gestor.pedir_material(id, int(_cantidades.get(id, 5)))
	if error != "":
		Juego.avisar(error)
	_reconstruir()


func _pintar_avisos() -> void:
	if Juego.avisos.is_empty():
		_texto(_contenido, "Sin avisos todavía.", 15, Color(0.7, 0.75, 0.8))
	for a in Juego.avisos:
		var v: VBoxContainer = _tarjeta()
		_texto(v, str(a), 14)
