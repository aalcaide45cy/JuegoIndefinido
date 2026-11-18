# telefono.gd
# -----------------------------------------------------------------------------
# El móvil del jugador (tecla P). Pantalla vertical con tres pestañas:
#   Encargos : ofertas de clientes (aceptar / rechazar) y encargos en curso
#              (dónde espera el comprador y cuánto tiempo le queda).
#   Pedidos  : comprar materiales y recibirlos en unos segundos.
#   Avisos   : historial de mensajes (ventas, pedidos que llegan, plantones).
#   Negocios : inmobiliaria, concesionario, alquileres... (ui/panel_negocios.gd).
# La lógica está en scripts/encargos.gd. SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name Telefono
extends Ventana

const DatosObjetos = preload("res://scripts/datos/objetos.gd")
const Economia = preload("res://scripts/datos/economia.gd")
const Taxi = preload("res://scripts/datos/taxi.gd")
const ACENTO: Color = Color(0.35, 0.8, 1.0)

var _gestor: Encargos
var _pestana: int = 0
var _contenido: VBoxContainer
var _cabecera_info: Label
var _firma: String = ""
var _temporizadores: Array = []   # [Label, id_encargo o -1, texto_base]
var _cantidades: Dictionary = {}  # id material -> cantidad elegida


const ICONOS: String = "res://assets/kenney/game-icons/PNG/White/2x/"
const FONDO_APP: Color = Color(0.05, 0.07, 0.11)


func _icono(nombre: String, tam: float = 26.0) -> Texture2D:
	var ruta: String = ICONOS + nombre + ".png"
	return load(ruta) as Texture2D if ResourceLoader.exists(ruta) else null


func construir() -> void:
	_gestor = get_tree().get_first_node_in_group("gestor_encargos") as Encargos
	# Carcasa: marco negro redondeado con pantalla oscura dentro y una muesca arriba.
	var marco: PanelContainer = PanelContainer.new()
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(0.02, 0.02, 0.03)
	estilo.border_color = Color(0.28, 0.3, 0.36)
	estilo.set_border_width_all(4)
	estilo.set_corner_radius_all(44)
	estilo.set_content_margin_all(14)
	marco.add_theme_stylebox_override("panel", estilo)
	Hud.centrar(marco, Vector2(410.0, 700.0))
	add_child(marco)
	var pantalla: PanelContainer = PanelContainer.new()
	var est2: StyleBoxFlat = StyleBoxFlat.new()
	est2.bg_color = FONDO_APP
	est2.set_corner_radius_all(32)
	est2.set_content_margin_all(14)
	pantalla.add_theme_stylebox_override("panel", est2)
	marco.add_child(pantalla)
	var caja: VBoxContainer = VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	pantalla.add_child(caja)

	# Barra de estado: hora a la izquierda, dinero y reputación a la derecha.
	_cabecera_info = Hud.crear_label(15, Color(0.85, 0.92, 1.0))
	caja.add_child(_cabecera_info)
	_titulo = Hud.crear_label(26, Color(1, 1, 1))
	caja.add_child(_titulo)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(scroll)
	_contenido = VBoxContainer.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.add_theme_constant_override("separation", 10)
	scroll.add_child(_contenido)

	# Barra de aplicaciones abajo, con iconos.
	var apps: HBoxContainer = HBoxContainer.new()
	apps.add_theme_constant_override("separation", 6)
	caja.add_child(apps)
	var datos: Array = [["Encargos", "phone"], ["Pedidos", "shoppingCart"], ["Avisos", "exclamation"], ["Negocios", "home"], ["Metas", "trophy"], ["Taxi", "fastForward"]]
	for i in 6:
		var b: Button = Hud.crear_boton(datos[i][0], _cambiar_pestana.bind(i))
		b.icon = _icono(datos[i][1])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(0, 62)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		apps.add_child(b)
	var cerrar_b: Button = Hud.crear_boton("Guardar el móvil (P / Esc)", cerrar)
	caja.add_child(cerrar_b)
	_reconstruir()


var _titulo: Label


func _cambiar_pestana(i: int) -> void:
	_pestana = i
	_reconstruir()


func _process(_delta: float) -> void:
	_cabecera_info.text = ("%s     %d $     Rep. %d" % [Juego.texto_hora(), Juego.dinero, Juego.reputacion]) + (("     Negro %d $" % Juego.dinero_negro) if Juego.dinero_negro > 0 else "")
	_titulo.text = ["Encargos", "Pedidos", "Avisos", "Negocios", "Metas", "Taxi"][_pestana]
	# Solo se reconstruye si cambia la estructura (no cada vez que baja un contador).
	var firma: String = _calcular_firma()
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
	_firma = _calcular_firma()
	match _pestana:
		0: _pintar_encargos()
		1: _pintar_pedidos()
		2: _pintar_avisos()
		3: _pintar_negocios()
		4: _pintar_metas()
		5: _pintar_taxi()


# Resume lo que obliga a redibujar la pestaña. La de Negocios se cuida sola (el
# panel se redibuja cuando hace falta), así que aquí no se reconstruye nunca.
func _calcular_firma() -> String:
	var firma: String = "%d|" % _pestana
	if _pestana == 3:
		return firma
	for e in Juego.encargos:
		firma += "%s%s," % [e["id"], e["estado"]]
	if _pestana == 5:
		firma += "d%d|n%d|" % [Juego.dinero, Juego.dinero_negro]
	firma += "|%d|%d|%d|%d" % [Juego.pedidos_material.size(), Juego.avisos.size(), Juego.nivel, Juego.metas_cobradas.size()]
	return firma


func _pintar_metas() -> void:
	for m in Juego.DatosMetas.LISTA:
		var v: VBoxContainer = _tarjeta()
		var hecha: bool = Juego.metas_cobradas.has(m["id"])
		_texto(v, ("✔ " if hecha else "○ ") + str(m["texto"]), 15,
				Color(0.55, 0.9, 0.55) if hecha else Color(0.9, 0.92, 0.95))
		_texto(v, "Premio: %d $" % int(m["premio"]), 13, Color(1.0, 0.85, 0.4))


func _pintar_taxi() -> void:
	var jugador: Node3D = get_tree().get_first_node_in_group("jugador") as Node3D
	var v0: VBoxContainer = _tarjeta()
	_texto(v0, "Taxi: te lleva a cualquier barrio, aldea, pueblo o ciudad. Pasa el tiempo del trayecto (unos %d km/h)." % int(Economia.TAXI_VELOCIDAD_MS * 3.6), 14)
	var motivo: String = Taxi.motivo_no(jugador)
	if motivo != "":
		_texto(v0, motivo, 14, Color(1.0, 0.6, 0.4))
	if jugador == null:
		return
	for d in Taxi.destinos(jugador.global_position):
		var v: VBoxContainer = _tarjeta()
		_texto(v, str(d["nombre"]), 15)
		_texto(v, "%.1f km  ·  %d $  ·  %s" % [float(d["dist"]) / 1000.0, int(d["precio"]), _texto_duracion(float(d["horas"]))], 13,
				Color(1.0, 0.85, 0.4))
		var b: Button = Hud.crear_boton("Ir en taxi", _pedir_taxi.bind(d))
		b.disabled = motivo != "" or Juego.dinero_total() < int(d["precio"]) or float(d["dist"]) < Taxi.DISTANCIA_MINIMA
		v.add_child(b)


func _texto_duracion(horas: float) -> String:
	var minutos: int = int(round(horas * 60.0))
	return "%d min" % minutos if minutos < 60 else "%d h %d min" % [minutos / 60, minutos % 60]


func _pedir_taxi(d: Dictionary) -> void:
	var jugador: Node = get_tree().get_first_node_in_group("jugador")
	var error: String = Taxi.pedir(jugador, d)
	if error != "":
		Juego.avisar(error)
		return
	cerrar()


func _pintar_negocios() -> void:
	var panel: PanelNegocios = PanelNegocios.new()
	panel.ancho = 340.0
	panel.compacto = true
	_contenido.add_child(panel)


func _tarjeta() -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	var est: StyleBoxFlat = StyleBoxFlat.new()
	est.bg_color = Color(0.1, 0.13, 0.19)
	est.border_color = ACENTO
	est.border_width_left = 5
	est.set_corner_radius_all(16)
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
		var nombre_p: String = GameData.pocion(e["pocion"])["nombre"]
		var pos: Array = e["pos"]
		_texto(v, "%s" % e["cliente"], 18, ACENTO)
		_texto(v, "Quiere: %d x %s" % [e["cantidad"], nombre_p])
		_texto(v, "Pago: %d $   (tienes %d)" % [e["pago"], Juego.cuenta("pocion_" + str(e["pocion"])) + Juego.cuenta("paquete_" + str(e["pocion"]))])
		if e["estado"] == "oferta":
			var t: Label = _texto(v, "", 14, Color(1.0, 0.8, 0.4))
			_temporizadores.append([t, int(e["id"]), "Responde en: "])
			var fila: HBoxContainer = HBoxContainer.new()
			v.add_child(fila)
			var acepta: Button = Hud.crear_boton("Aceptar", _aceptar.bind(int(e["id"])))
			acepta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fila.add_child(acepta)
			for pct in [15, 30]:
				var neg: Button = Hud.crear_boton("+%d%%" % pct, _negociar.bind(int(e["id"]), pct))
				neg.tooltip_text = "Contraoferta: éxito ~%d%%" % int(Encargos.prob_contraoferta(pct) * 100.0)
				fila.add_child(neg)
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


func _negociar(id: int, pct: int) -> void:
	_gestor.negociar(id, pct)
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
		# Bloqueado por nivel o habilidad, igual que en la tienda.
		var motivo: String = Juego.motivo_no_compra(id)
		if motivo != "":
			b.disabled = true
			_texto(v, "🔒 " + motivo, 13, Color(1, 0.45, 0.4))


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
