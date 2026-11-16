# main.gd
# -----------------------------------------------------------------------------
# El "cerebro" del prototipo. Guarda el estado de la partida (dinero,
# inventario...) y conecta las tres zonas de la tienda:
#
#   1. HUERTO     -> eliges semilla, plantas en una maceta y cosechas.
#   2. CALDERO    -> echas 2 hierbas y pulsas "Mezclar" para hacer una poción.
#   3. MOSTRADOR  -> un cliente pide una poción; si la tienes, se la vendes.
#
# Para que sea fácil de leer, toda la interfaz se crea desde código en
# _construir_interfaz(). Más adelante la pasaremos a escenas del editor.
# -----------------------------------------------------------------------------
extends Control

# Maceta, Caldero y Cliente son las otras piezas del juego. Como sus scripts
# empiezan con "class_name", podemos crearlas aquí con Maceta.new(), etc.

const NUMERO_MACETAS: int = 3

# ------------------------- ESTADO DE LA PARTIDA ------------------------------
var dinero: int = GameData.DINERO_INICIAL
var hierbas: Dictionary = {}     # id_hierba -> cantidad en el almacén
var pociones: Dictionary = {}    # id_pocion -> cantidad lista para vender
var semilla_elegida: String = "bruma"
var ha_ganado: bool = false

# ------------------- REFERENCIAS A NODOS DE LA INTERFAZ ----------------------
var _label_dinero: Label
var _label_almacen: Label
var _label_pociones: Label
var _label_pedido: Label
var _label_mensaje: Label
var _botones_semilla: Dictionary = {}   # id_hierba -> Button
var _botones_echar: Dictionary = {}     # id_hierba -> Button
var _boton_mezclar: Button
var _boton_vender: Button
var _caldero: Caldero
var _cliente: Cliente
var _timer_cliente: Timer


# _ready se ejecuta una vez, cuando la escena aparece en pantalla.
func _ready() -> void:
	randomize()  # Para que los números aleatorios cambien en cada partida.
	for id_hierba in GameData.HIERBAS:
		hierbas[id_hierba] = 0
	for id_pocion in GameData.POCIONES:
		pociones[id_pocion] = 0

	_construir_interfaz()

	# El primer cliente llega a los pocos segundos.
	_timer_cliente.start(4.0)
	_mensaje("Medianoche. La guardia de la Corona patrulla arriba. "
			+ "Planta Hoja de Bruma en el huerto para empezar.")
	_actualizar_interfaz()


# =============================================================================
#  ACCIONES DEL JUGADOR
# =============================================================================

# El jugador ha hecho clic en una maceta.
func _al_pulsar_maceta(maceta: Maceta) -> void:
	if maceta.estado == Maceta.Estado.VACIA:
		# Maceta vacía: plantamos la semilla elegida (si hay dinero).
		var precio: int = GameData.HIERBAS[semilla_elegida]["precio_semilla"]
		if dinero < precio:
			_mensaje("No tienes dinero para esa semilla (cuesta %d)." % precio)
			return
		dinero -= precio
		maceta.plantar(semilla_elegida)
		_mensaje("Has plantado %s." % GameData.HIERBAS[semilla_elegida]["nombre"])
	elif maceta.estado == Maceta.Estado.CRECIENDO:
		_mensaje("Todavía está creciendo. Paciencia...")
	else:
		# Planta lista: la cosechamos y va al almacén.
		var id_hierba: String = maceta.cosechar()
		hierbas[id_hierba] += 1
		_mensaje("Has cosechado 1 %s." % GameData.HIERBAS[id_hierba]["nombre"])
	_actualizar_interfaz()


func _elegir_semilla(id_hierba: String) -> void:
	semilla_elegida = id_hierba
	_actualizar_interfaz()


func _echar_hierba(id_hierba: String) -> void:
	if _caldero.esta_lleno():
		_mensaje("El caldero ya está lleno. Pulsa Mezclar.")
		return
	if hierbas[id_hierba] <= 0:
		return
	hierbas[id_hierba] -= 1
	_caldero.echar(id_hierba)
	_actualizar_interfaz()


func _mezclar() -> void:
	if not _caldero.esta_lleno():
		_mensaje("Necesitas %d ingredientes para mezclar." % GameData.INGREDIENTES_POR_POCION)
		return
	var id_pocion: String = GameData.buscar_pocion(_caldero.ingredientes)
	_caldero.sacudir()
	_caldero.vaciar()
	if id_pocion == "":
		_mensaje("El caldero escupe un lodo negro que huele a tumba. No sirve para nada.")
	else:
		pociones[id_pocion] += 1
		_mensaje("¡Has preparado %s!" % GameData.POCIONES[id_pocion]["nombre"])
	_actualizar_interfaz()


# Devuelve las hierbas del caldero al almacén.
func _vaciar_caldero() -> void:
	for id_hierba in _caldero.ingredientes:
		hierbas[id_hierba] += 1
	_caldero.vaciar()
	_actualizar_interfaz()


func _vender() -> void:
	if not _cliente.presente:
		return
	var pedido: String = _cliente.pedido
	if pociones[pedido] <= 0:
		_mensaje("No tienes %s." % GameData.POCIONES[pedido]["nombre"])
		return
	pociones[pedido] -= 1
	var precio: int = GameData.POCIONES[pedido]["precio"]
	dinero += precio
	_mensaje("Vendido por %d monedas. %s" % [precio, GameData.POCIONES[pedido]["efecto"]])
	_cliente.marcharse()
	_programar_siguiente_cliente()
	_comprobar_victoria()
	_actualizar_interfaz()


# =============================================================================
#  CLIENTES
# =============================================================================

func _llega_cliente() -> void:
	_cliente.llegar()
	_mensaje("Ha entrado %s. Quiere: %s." % [_cliente.nombre,
			GameData.POCIONES[_cliente.pedido]["nombre"]])
	_actualizar_interfaz()


func _cliente_se_cansa() -> void:
	_mensaje("%s se ha cansado de esperar y se ha perdido en la niebla." % _cliente.nombre)
	_cliente.marcharse()
	_programar_siguiente_cliente()
	_actualizar_interfaz()


func _programar_siguiente_cliente() -> void:
	_timer_cliente.start(randf_range(3.0, 6.0))


func _comprobar_victoria() -> void:
	if not ha_ganado and dinero >= GameData.OBJETIVO_DINERO:
		ha_ganado = true
		_mensaje("¡Has reunido %d monedas y pagado el alquiler! Prototipo superado. "
				% GameData.OBJETIVO_DINERO + "Puedes seguir jugando.")


# =============================================================================
#  INTERFAZ: refrescar textos y botones
# =============================================================================

func _actualizar_interfaz() -> void:
	_label_dinero.text = "Monedas: %d   (objetivo: %d para el alquiler)" % [
			dinero, GameData.OBJETIVO_DINERO]

	# Almacén de hierbas.
	var lineas: PackedStringArray = []
	for id_hierba in GameData.HIERBAS:
		lineas.append("%s: %d" % [GameData.HIERBAS[id_hierba]["nombre"], hierbas[id_hierba]])
	_label_almacen.text = "Almacén  ·  " + "   ".join(lineas)

	# Botones de semilla: el elegido se marca como pulsado.
	for id_hierba in _botones_semilla:
		var boton: Button = _botones_semilla[id_hierba]
		boton.button_pressed = (id_hierba == semilla_elegida)

	# Botones de echar al caldero: desactivados si no tienes esa hierba.
	for id_hierba in _botones_echar:
		var boton: Button = _botones_echar[id_hierba]
		boton.text = "Echar %s (%d)" % [GameData.HIERBAS[id_hierba]["nombre"], hierbas[id_hierba]]
		boton.disabled = hierbas[id_hierba] <= 0 or _caldero.esta_lleno()
	_boton_mezclar.disabled = not _caldero.esta_lleno()

	# Pociones listas para vender.
	lineas = []
	for id_pocion in GameData.POCIONES:
		lineas.append("%s: %d" % [GameData.POCIONES[id_pocion]["nombre"], pociones[id_pocion]])
	_label_pociones.text = "Estantería:\n" + "\n".join(lineas)

	# Pedido del cliente y botón de vender.
	if _cliente.presente:
		var id_pedido: String = _cliente.pedido
		_label_pedido.text = "Pide: %s\nPaga: %d monedas" % [GameData.POCIONES[id_pedido]["nombre"],
				GameData.POCIONES[id_pedido]["precio"]]
		_boton_vender.disabled = pociones[id_pedido] <= 0
	else:
		_label_pedido.text = ""
		_boton_vender.disabled = true


func _mensaje(texto: String) -> void:
	_label_mensaje.text = texto


func _reiniciar() -> void:
	get_tree().reload_current_scene()


# =============================================================================
#  INTERFAZ: construcción (se ejecuta una vez al empezar)
# =============================================================================

func _construir_interfaz() -> void:
	# Fondo casi negro: es de noche y esto es ilegal.
	var fondo: ColorRect = ColorRect.new()
	fondo.color = Color(0.05, 0.05, 0.07)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	# Margen alrededor de todo.
	var margen: MarginContainer = MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margen.add_theme_constant_override(lado, 16)
	add_child(margen)

	var columna_principal: VBoxContainer = VBoxContainer.new()
	columna_principal.add_theme_constant_override("separation", 12)
	margen.add_child(columna_principal)

	# --- Barra superior ---
	var barra: HBoxContainer = HBoxContainer.new()
	columna_principal.add_child(barra)
	barra.add_child(_crear_label("Elixir Clandestino", 26, Color(0.6, 0.85, 0.55)))
	var hueco: Control = Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(hueco)
	_label_dinero = _crear_label("", 20, Color(1, 0.9, 0.4))
	barra.add_child(_label_dinero)
	var boton_reiniciar: Button = _crear_boton("Reiniciar", _reiniciar)
	barra.add_child(boton_reiniciar)

	# --- Las tres zonas ---
	var zonas: HBoxContainer = HBoxContainer.new()
	zonas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zonas.add_theme_constant_override("separation", 12)
	columna_principal.add_child(zonas)
	zonas.add_child(_crear_zona_huerto())
	zonas.add_child(_crear_zona_caldero())
	zonas.add_child(_crear_zona_mostrador())

	# --- Mensajes abajo ---
	_label_mensaje = _crear_label("", 18, Color(0.9, 0.9, 0.85))
	_label_mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_mensaje.custom_minimum_size = Vector2(0, 50)
	columna_principal.add_child(_label_mensaje)

	# --- Temporizador que hace entrar a los clientes ---
	_timer_cliente = Timer.new()
	_timer_cliente.one_shot = true
	_timer_cliente.timeout.connect(_llega_cliente)
	add_child(_timer_cliente)


func _crear_zona_huerto() -> Control:
	var panel: PanelContainer = _crear_panel()
	var caja: VBoxContainer = _caja_de_panel(panel, "1. Huerto (bajo la trampilla)")

	caja.add_child(_crear_label("Elige semilla y haz clic en una maceta vacía:", 15))
	var fila_semillas: HBoxContainer = HBoxContainer.new()
	caja.add_child(fila_semillas)
	for id_hierba in GameData.HIERBAS:
		var datos: Dictionary = GameData.HIERBAS[id_hierba]
		var texto: String = "%s (%d mon.)" % [datos["nombre"], datos["precio_semilla"]]
		var boton: Button = _crear_boton(texto, _elegir_semilla.bind(id_hierba))
		boton.toggle_mode = true
		fila_semillas.add_child(boton)
		_botones_semilla[id_hierba] = boton

	var fila_macetas: HBoxContainer = HBoxContainer.new()
	fila_macetas.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_child(fila_macetas)
	for i in NUMERO_MACETAS:
		var maceta: Maceta = Maceta.new()
		maceta.pulsada.connect(_al_pulsar_maceta)
		fila_macetas.add_child(maceta)

	_label_almacen = _crear_label("", 15)
	_label_almacen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_label_almacen)
	return panel


func _crear_zona_caldero() -> Control:
	var panel: PanelContainer = _crear_panel()
	var caja: VBoxContainer = _caja_de_panel(panel, "2. Caldero (sótano secreto)")

	_caldero = Caldero.new()
	_caldero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(_caldero)

	for id_hierba in GameData.HIERBAS:
		var boton: Button = _crear_boton("", _echar_hierba.bind(id_hierba))
		caja.add_child(boton)
		_botones_echar[id_hierba] = boton

	var fila: HBoxContainer = HBoxContainer.new()
	caja.add_child(fila)
	_boton_mezclar = _crear_boton("¡Mezclar!", _mezclar)
	_boton_mezclar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(_boton_mezclar)
	fila.add_child(_crear_boton("Vaciar", _vaciar_caldero))

	# Recetario: así el jugador sabe qué mezclar.
	var recetas: PackedStringArray = ["Recetario:"]
	for id_pocion in GameData.POCIONES:
		recetas.append("· %s = %s" % [GameData.POCIONES[id_pocion]["nombre"],
				GameData.texto_receta(id_pocion)])
	var label_recetas: Label = _crear_label("\n".join(recetas), 13, Color(0.75, 0.75, 0.7))
	label_recetas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(label_recetas)
	return panel


func _crear_zona_mostrador() -> Control:
	var panel: PanelContainer = _crear_panel()
	var caja: VBoxContainer = _caja_de_panel(panel, "3. Mostrador (puerta trasera)")

	_cliente = Cliente.new()
	_cliente.se_cansa.connect(_cliente_se_cansa)
	caja.add_child(_cliente)

	_label_pedido = _crear_label("", 16, Color(1, 0.95, 0.75))
	_label_pedido.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_label_pedido)

	_boton_vender = _crear_boton("Vender poción", _vender)
	caja.add_child(_boton_vender)

	_label_pociones = _crear_label("", 14)
	caja.add_child(_label_pociones)
	return panel


# ------------------------- Pequeñas ayudas -----------------------------------

func _crear_label(texto: String, tam: int, color: Color = Color(0.85, 0.85, 0.8)) -> Label:
	var label: Label = Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", tam)
	label.add_theme_color_override("font_color", color)
	return label


func _crear_boton(texto: String, al_pulsar: Callable) -> Button:
	var boton: Button = Button.new()
	boton.text = texto
	boton.add_theme_font_size_override("font_size", 15)
	boton.pressed.connect(al_pulsar)
	return boton


# Un panel con fondo marrón y bordes redondeados para cada zona.
func _crear_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(0.09, 0.09, 0.11)
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(12)
	estilo.border_color = Color(0.25, 0.32, 0.25)
	estilo.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", estilo)
	return panel


# Crea la caja vertical de dentro de un panel, con su título.
func _caja_de_panel(panel: PanelContainer, titulo: String) -> VBoxContainer:
	var caja: VBoxContainer = VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	panel.add_child(caja)
	caja.add_child(_crear_label(titulo, 20, Color(0.6, 0.85, 0.55)))
	return caja
