# hud.gd
# -----------------------------------------------------------------------------
# Lo que se dibuja encima del mundo 3D: dinero, el texto de "[E] Usar...",
# los mensajes, el fundido a negro y las ventanas (tienda, inventario,
# estantería y minijuego de plantar).
#
# Todo está pensado para una pantalla de 1280x720 y se escala solo a la
# resolución real (por ejemplo, 4K), para que los textos no salgan diminutos.
# -----------------------------------------------------------------------------
class_name Hud
extends CanvasLayer

const ALTO_DISENO: float = 720.0

var jugador: Jugador   # Lo pone mundo.gd.

var _raiz: Control      # Todo cuelga de aquí; se escala según la pantalla.
var _label_estado: Label
var _label_accion: Label
var _label_mensaje: Label
var _mira: ColorRect
var _negro: ColorRect
var _menu: Control = null   # La ventana abierta ahora mismo (o null).
var _tiempo_mensaje: float = 0.0


func _ready() -> void:
	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	get_viewport().size_changed.connect(_ajustar_escala)
	_ajustar_escala()

	# Arriba a la izquierda: dinero y lo que llevas en la mano.
	_label_estado = crear_label(18)
	_label_estado.position = Vector2(20, 16)
	_raiz.add_child(_label_estado)

	# Punto de mira en el centro de la pantalla.
	_mira = ColorRect.new()
	_mira.color = Color(1, 1, 1, 0.7)
	_mira.size = Vector2(4, 4)
	_mira.set_anchors_preset(Control.PRESET_CENTER)
	_mira.position -= _mira.size / 2.0
	_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_mira)

	# Abajo en el centro: mensajes y la acción disponible.
	_label_mensaje = crear_label(18, Color(0.85, 0.95, 0.8))
	_colocar_abajo(_label_mensaje, 120)
	_label_accion = crear_label(22, Color(1, 0.92, 0.6))
	_colocar_abajo(_label_accion, 62)

	# Abajo: ayuda de controles.
	var ayuda: Label = crear_label(14, Color(0.7, 0.7, 0.7))
	ayuda.text = "WASD moverse · Ratón mirar · Shift correr · Espacio saltar · E usar · TAB inventario · Q hierba en la mano · V primera/tercera persona · Esc soltar ratón"
	_colocar_abajo(ayuda, 26)

	# Rectángulo negro para el fundido (empieza transparente).
	_negro = ColorRect.new()
	_negro.color = Color(0, 0, 0, 0)
	_negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_negro)

	Juego.cambio.connect(_actualizar_estado)
	Juego.mensaje.connect(_mostrar_mensaje)
	_actualizar_estado()
	_mostrar_mensaje("Medianoche en la Plaza del Ahorcado. Tienes 200 $. La herboristería (luz verde) vende de todo; " +
			"la casa con el cartel SE ALQUILA puede ser tu escondite.")


func _ajustar_escala() -> void:
	var tam: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = maxf(0.5, tam.y / ALTO_DISENO)
	_raiz.scale = Vector2(factor, factor)
	_raiz.size = tam / factor


# TAB y Esc se miran aquí, antes que nadie, para que funcionen con menús abiertos.
func _input(evento: InputEvent) -> void:
	if evento.is_action_pressed("inventario"):
		if _menu is Menus.Inventario:
			_menu.cerrar()
		elif _menu == null:
			_abrir_menu(Menus.Inventario.new())
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("liberar_raton") and _menu != null:
		_menu.cerrar()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Texto de la acción: se pregunta cada fotograma porque cambia (p. ej. el % de crecimiento).
	if _menu == null and jugador != null and jugador.objetivo != null:
		_label_accion.text = "[E] " + jugador.objetivo.texto_accion()
	else:
		_label_accion.text = ""
	_mira.visible = _menu == null
	# Los mensajes se desvanecen pasados unos segundos.
	_tiempo_mensaje -= delta
	_label_mensaje.modulate.a = clampf(_tiempo_mensaje, 0.0, 1.0)


func _actualizar_estado() -> void:
	var lineas: PackedStringArray = []
	lineas.append("%d $  (alquiler del Prefecto: %d $)" % [Juego.dinero, GameData.OBJETIVO_DINERO])
	var en_mano: String = Juego.hierba_seleccionada()
	lineas.append("En la mano [Q]: %s (%d)" % [GameData.HIERBAS[en_mano]["nombre"], Juego.hierbas[en_mano]])
	if Juego.tiene("jarra"):
		lineas.append("Jarra: %d/%d riegos" % [Juego.agua_jarra, GameData.CARGAS_JARRA])
	lineas.append("[TAB] Inventario")
	_label_estado.text = "\n".join(lineas)


func _mostrar_mensaje(texto: String) -> void:
	_label_mensaje.text = texto
	_tiempo_mensaje = 6.0


# ------------------------------- Ventanas -------------------------------------

func abrir_tienda() -> void:
	_abrir_menu(Menus.Tienda.new())


func abrir_almacen() -> void:
	_abrir_menu(Menus.Almacen.new())


func abrir_minijuego(maceta: Maceta3D) -> void:
	var minijuego: MinijuegoPlantar = MinijuegoPlantar.new()
	minijuego.maceta = maceta
	_abrir_menu(minijuego)


func hay_menu() -> bool:
	return _menu != null


# Muestra una ventana: suelta el ratón y para al jugador hasta que se cierre.
func _abrir_menu(menu: Control) -> void:
	if _menu != null:
		return
	_menu = menu
	Juego.menu_abierto = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.connect("terminado", _al_cerrar_menu)
	_raiz.add_child(menu)
	_raiz.move_child(_negro, -1)  # El fundido siempre por encima de todo.


func _al_cerrar_menu() -> void:
	_menu = null
	Juego.menu_abierto = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# Funde a negro, ejecuta "en_medio" (por ejemplo, mover al jugador) y vuelve.
# "pausa" son los segundos que se queda en negro.
func fundido(en_medio: Callable, pausa: float = 0.0) -> void:
	var animacion: Tween = create_tween()
	animacion.tween_property(_negro, "color:a", 1.0, 0.3)
	animacion.tween_callback(en_medio)
	animacion.tween_interval(pausa)
	animacion.tween_property(_negro, "color:a", 0.0, 0.4)


# ------------------- Ayudas (las usan también los menús) ----------------------

static func crear_label(tam: int, color: Color = Color(0.9, 0.9, 0.85)) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", tam)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func crear_boton(texto: String, al_pulsar: Callable) -> Button:
	var boton: Button = Button.new()
	boton.text = texto
	boton.add_theme_font_size_override("font_size", 16)
	boton.focus_mode = Control.FOCUS_NONE  # Así ESPACIO no pulsa botones sin querer.
	boton.pressed.connect(al_pulsar)
	return boton


# Panel oscuro con borde verde para las ventanas.
static func crear_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.08, 0.08, 0.96)
	estilo.border_color = Color(0.3, 0.55, 0.35)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", estilo)
	return panel


# Coloca un texto centrado a lo ancho, a "alto" píxeles del borde de abajo.
func _colocar_abajo(label: Label, alto: float) -> void:
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.offset_top = -alto
	label.offset_bottom = -alto + 30
	label.offset_left = 40
	label.offset_right = -40
	_raiz.add_child(label)


# Centra un panel en la pantalla con el tamaño indicado.
static func centrar(panel: Control, tam: Vector2) -> void:
	panel.custom_minimum_size = tam
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -tam.x / 2.0
	panel.offset_right = tam.x / 2.0
	panel.offset_top = -tam.y / 2.0
	panel.offset_bottom = tam.y / 2.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
