# hud.gd
# -----------------------------------------------------------------------------
# Lo que se dibuja encima del mundo 3D: dinero, el texto de "[E] Usar...",
# la barra de vida, la barra rápida (teclas 1-9), la hora, los mensajes, el
# fundido a negro y las ventanas (tienda, inventario, estantería, panel de
# administrador y minijuego de plantar).
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
var _label_mano: Label
var _label_hora: Label
var _barra_vida: ProgressBar
var _label_alerta: Label
var _label_sigilo: Label
var _barra_alerta: ProgressBar
var _barra_rapida: HBoxContainer
var _panel_estado: PanelEstado
var _brujula: Brujula
var _minimapa: Minimapa
var _mira: ColorRect
var _negro: ColorRect
var _menu = null   # La ventana abierta ahora mismo (o null).
var _tiempo_mensaje: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # Sigue funcionando con el juego en pausa.
	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.theme = crear_tema()
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

	# Arriba a la derecha: hora y día.
	_label_hora = crear_label(20, Color(0.9, 0.9, 0.7))
	_label_hora.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_label_hora.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label_hora.offset_left = -300
	_label_hora.offset_right = -20
	_label_hora.offset_top = 16
	_raiz.add_child(_label_hora)

	# Barra de vida, debajo del dinero.
	_barra_vida = ProgressBar.new()
	_barra_vida.max_value = Juego.VIDA_MAX
	_barra_vida.show_percentage = false
	_barra_vida.custom_minimum_size = Vector2(220, 14)
	_barra_vida.size = Vector2(220, 14)
	_barra_vida.position = Vector2(20, 76)
	_barra_vida.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fondo_vida: StyleBoxFlat = StyleBoxFlat.new()
	fondo_vida.bg_color = Color(0.1, 0.05, 0.05, 0.85)
	var relleno_vida: StyleBoxFlat = StyleBoxFlat.new()
	relleno_vida.bg_color = Color(0.8, 0.15, 0.15)
	_barra_vida.add_theme_stylebox_override("background", fondo_vida)
	_barra_vida.add_theme_stylebox_override("fill", relleno_vida)
	_raiz.add_child(_barra_vida)

	# Arriba en el centro: aviso de los guardias (cuánto te buscan y por qué).
	_label_alerta = crear_label(22, Color(1.0, 0.35, 0.3))
	_label_alerta.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_label_alerta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_alerta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_alerta.offset_left = -380
	_label_alerta.offset_right = 380
	_label_alerta.offset_top = 70
	_label_alerta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label_alerta.visible = false
	_raiz.add_child(_label_alerta)
	_barra_alerta = ProgressBar.new()
	_barra_alerta.max_value = 100.0
	_barra_alerta.show_percentage = false
	_barra_alerta.size = Vector2(300, 10)
	_barra_alerta.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_barra_alerta.offset_left = -150
	_barra_alerta.offset_right = 150
	_barra_alerta.offset_top = 170
	_barra_alerta.offset_bottom = 180
	_barra_alerta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_alerta.visible = false
	var relleno_alerta: StyleBoxFlat = StyleBoxFlat.new()
	relleno_alerta.bg_color = Color(0.95, 0.3, 0.2)
	_barra_alerta.add_theme_stylebox_override("fill", relleno_alerta)
	_raiz.add_child(_barra_alerta)
	# Debajo de la vida: cómo de visible eres (sigilo).
	_label_sigilo = crear_label(14, Color(0.85, 0.85, 0.7))
	_label_sigilo.position = Vector2(20, 142)
	_raiz.add_child(_label_sigilo)

	# Interfaz nueva: panel de vida/dinero/nivel, brújula arriba y minimapa a la derecha.
	# Sustituyen a los textos y la barra de vida de antes (que quedan ocultos).
	_label_estado.visible = false
	_barra_vida.visible = false
	_label_hora.visible = false
	_panel_estado = PanelEstado.new()
	_panel_estado.position = Vector2(16, 12)
	_raiz.add_child(_panel_estado)
	_brujula = Brujula.new()
	_brujula.anchor_left = 0.5
	_brujula.anchor_right = 0.5
	_brujula.offset_left = -260.0
	_brujula.offset_right = 260.0
	_brujula.offset_top = 10.0
	_brujula.offset_bottom = 70.0
	_raiz.add_child(_brujula)
	_minimapa = Minimapa.new()
	_minimapa.anchor_left = 1.0
	_minimapa.anchor_right = 1.0
	_minimapa.offset_left = -(Minimapa.DIAMETRO + 16.0)
	_minimapa.offset_right = -16.0
	_minimapa.offset_top = 12.0
	_minimapa.offset_bottom = 12.0 + Minimapa.DIAMETRO + 40.0
	_raiz.add_child(_minimapa)

	# Abajo en el centro: mensajes, la acción disponible, lo que llevas en la mano y la barra rápida.
	_label_mensaje = crear_label(18, Color(0.85, 0.95, 0.8))
	_colocar_abajo(_label_mensaje, 190)
	_label_accion = crear_label(22, Color(1, 0.92, 0.6))
	_colocar_abajo(_label_accion, 150)
	_label_mano = crear_label(16, Color(0.9, 0.9, 0.85))
	_colocar_abajo(_label_mano, 100)

	_barra_rapida = HBoxContainer.new()
	_barra_rapida.add_theme_constant_override("separation", 4)
	_barra_rapida.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_rapida.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_barra_rapida.offset_left = -234
	_barra_rapida.offset_right = 234
	_barra_rapida.offset_top = -74
	_barra_rapida.offset_bottom = -26
	_barra_rapida.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_raiz.add_child(_barra_rapida)
	for i in Juego.TAM_BARRA:
		var casilla: CasillaUI = CasillaUI.new(Juego.inventario, i, 48.0)
		casilla.numero = str(i + 1)
		casilla.arrastrable = false
		casilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_barra_rapida.add_child(casilla)

	# Abajo: ayuda de controles.
	var ayuda: Label = crear_label(14, Color(0.7, 0.7, 0.7))
	ayuda.text = "WASD moverse · Ratón mirar · Shift correr · Espacio saltar · E usar · C agacharse · 1-9 barra · M zoom minimapa · N mapa grande · P móvil · TAB inventario · F1 admin · V cámara · Esc pausa"
	_colocar_abajo(ayuda, 22)

	# Rectángulo negro para el fundido (empieza transparente).
	_negro = ColorRect.new()
	_negro.color = Color(0, 0, 0, 0)
	_negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_negro)

	Juego.cambio.connect(_actualizar_estado)
	Juego.mensaje.connect(_mostrar_mensaje)
	_actualizar_estado()
	_mostrar_mensaje("Plaza del Ahorcado. Tienes 200 $. La herboristería (luz verde) vende de todo; " +
			"la casa con el cartel SE ALQUILA puede ser tu escondite. TAB abre el inventario.")
	# Al arrancar: menú de Continuar / Nueva partida.
	call_deferred("_abrir_inicio")


func _ajustar_escala() -> void:
	var tam: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = maxf(0.5, tam.y / ALTO_DISENO)
	_raiz.scale = Vector2(factor, factor)
	_raiz.size = tam / factor


# TAB y Esc se miran aquí, antes que nadie, para que funcionen con menús abiertos.
func _input(evento: InputEvent) -> void:
	if evento.is_action_pressed("inventario"):
		if _menu is Ventanas.Inventario:
			_menu.cerrar()
		elif _menu == null:
			_abrir_menu(Ventanas.Inventario.new())
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("telefono"):
		if _menu is Telefono:
			_menu.cerrar()
		elif _menu == null:
			_abrir_menu(Telefono.new())
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("mapa_grande"):
		if _menu is MapaGrande:
			_menu.cerrar()
		elif _menu == null:
			var mapa: MapaGrande = MapaGrande.new()
			mapa.jugador = jugador
			_abrir_menu(mapa)
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("admin"):
		if _menu is Ventanas.Admin:
			_menu.cerrar()
		elif _menu == null:
			_abrir_menu(Ventanas.Admin.new())
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("liberar_raton"):
		if _menu == null:
			var pausa: Ventanas.Pausa = Ventanas.Pausa.new()
			pausa.jugador = jugador
			_abrir_menu(pausa)
		elif not _menu is Ventanas.Inicio:
			_menu.cerrar()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Texto de la acción: se pregunta cada fotograma porque cambia (p. ej. el % de crecimiento).
	if _menu == null and jugador != null and jugador.objetivo != null:
		_label_accion.text = "[E] " + jugador.objetivo.texto_accion()
	else:
		_label_accion.text = ""
	_mira.visible = _menu == null
	_barra_rapida.visible = _menu == null
	_panel_estado.visible = _menu == null
	_brujula.visible = _menu == null
	_minimapa.visible = _menu == null
	_label_hora.text = "Día %d   %s" % [Juego.dia, Juego.texto_hora()]
	_actualizar_alerta()
	# Los mensajes se desvanecen pasados unos segundos.
	_tiempo_mensaje -= delta
	_label_mensaje.modulate.a = clampf(_tiempo_mensaje, 0.0, 1.0)


# Muestra si los guardias te buscan, por qué y cómo esconderte; y cómo de visible eres.
func _actualizar_alerta() -> void:
	var alerta: float = Juego.alerta
	_label_alerta.visible = alerta > 0.0
	_barra_alerta.visible = alerta > 0.0
	if alerta > 0.0:
		_barra_alerta.value = alerta
		var estado: String = "¡DETECTADO!" if alerta >= 99.0 else "BUSCÁNDOTE…"
		_label_alerta.text = "%s\n%s\nEscóndete: sal de su vista, entra en un edificio, agáchate (C) en la sombra o guarda lo ilegal en tu estantería." % [
				estado, Juego.motivo_alerta]
	# Aviso de sigilo.
	var lineas: PackedStringArray = []
	var ilegal: PackedStringArray = Juego.motivos_ilegales()
	if Juego.es_de_noche() and not ilegal.is_empty():
		lineas.append("⚠ Llevas: " + ", ".join(ilegal) + ". Los guardias te perseguirán.")
	if jugador != null:
		if Juego.interiores > 0:
			lineas.append("A cubierto (dentro de un edificio)")
		elif jugador.agachado:
			lineas.append("Agachado: te ven menos")
		if jugador.en_sombra and Juego.interiores == 0:
			lineas.append("En la sombra: te ven menos")
	_label_sigilo.text = "\n".join(lineas)


func _actualizar_estado() -> void:
	var lineas: PackedStringArray = []
	lineas.append("%d $   ·   Nivel %d  (%d/%d XP)" % [Juego.dinero, Juego.nivel, Juego.xp, Juego.xp_necesaria()])
	lineas.append("Vida")
	_label_estado.text = "\n".join(lineas)
	_barra_vida.value = Juego.vida
	var mano = Juego.en_mano()
	if mano == null:
		_label_mano.text = ""
	else:
		_label_mano.text = Juego.DatosObjetos.nombre(mano["id"])
		if mano.has("agua"):
			_label_mano.text += "  (agua %d)" % mano["agua"]
		var datos_mano: Dictionary = Juego.DatosObjetos.datos(mano["id"])
		if datos_mano.has("cargador"):
			_label_mano.text += "  [%d/%d]  reserva: %d  (R recarga)" % [mano.get("balas", 0),
					datos_mano["cargador"], Juego.cuenta(datos_mano["municion"])]


func _mostrar_mensaje(texto: String) -> void:
	_label_mensaje.text = texto
	_tiempo_mensaje = 6.0


# ------------------------------- Ventanas -------------------------------------

func _abrir_inicio() -> void:
	var inicio: Ventanas.Inicio = Ventanas.Inicio.new()
	inicio.jugador = jugador
	_abrir_menu(inicio)


func abrir_tienda(id_tienda: String, nombre: String) -> void:
	var tienda: Ventanas.Tienda = Ventanas.Tienda.new()
	tienda.tienda = id_tienda
	tienda.nombre_tienda = nombre
	_abrir_menu(tienda)


func abrir_instructor() -> void:
	_abrir_menu(Ventanas.Instructor.new())


func abrir_caldero() -> void:
	_abrir_menu(Ventanas.VentanaCaldero.new())


func abrir_estanteria() -> void:
	_abrir_menu(Ventanas.Estanteria.new())


func abrir_negociacion(mostrador: Mostrador) -> void:
	var n: Negociacion = Negociacion.new()
	n.mostrador = mostrador
	_abrir_menu(n)


func abrir_cacheo() -> void:
	_abrir_menu(Cacheo.new())


func abrir_mortero(id_hierba: String) -> void:
	var m: MinijuegoMachacar = MinijuegoMachacar.new()
	m.hierba = id_hierba
	_abrir_menu(m)


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


# El estilo común de toda la interfaz: botones, pestañas y deslizadores con el
# mismo aspecto oscuro con borde verde que los paneles.
static func crear_tema() -> Theme:
	var tema: Theme = Theme.new()
	var estados: Dictionary = {
		"normal": Color(0.12, 0.16, 0.13), "hover": Color(0.18, 0.28, 0.2),
		"pressed": Color(0.1, 0.35, 0.2), "disabled": Color(0.1, 0.1, 0.1),
		"focus": Color(0.12, 0.16, 0.13),
	}
	for estado in estados:
		var caja: StyleBoxFlat = StyleBoxFlat.new()
		caja.bg_color = estados[estado]
		caja.border_color = Color(0.3, 0.55, 0.35) if estado != "disabled" else Color(0.22, 0.25, 0.22)
		caja.set_border_width_all(2)
		caja.set_corner_radius_all(6)
		caja.content_margin_left = 12
		caja.content_margin_right = 12
		caja.content_margin_top = 6
		caja.content_margin_bottom = 6
		tema.set_stylebox(estado, "Button", caja)
	tema.set_color("font_color", "Button", Color(0.9, 0.95, 0.88))
	tema.set_color("font_hover_color", "Button", Color(1, 1, 0.9))
	tema.set_color("font_pressed_color", "Button", Color(0.7, 1, 0.75))
	tema.set_color("font_disabled_color", "Button", Color(0.45, 0.47, 0.45))
	# Pestañas de la tienda.
	for estado in ["tab_selected", "tab_unselected", "tab_hovered"]:
		var pestana: StyleBoxFlat = StyleBoxFlat.new()
		pestana.bg_color = {"tab_selected": Color(0.15, 0.3, 0.2), "tab_unselected": Color(0.09, 0.11, 0.1),
				"tab_hovered": Color(0.14, 0.2, 0.15)}[estado]
		pestana.border_color = Color(0.3, 0.55, 0.35)
		pestana.set_border_width_all(1)
		pestana.corner_radius_top_left = 6
		pestana.corner_radius_top_right = 6
		pestana.content_margin_left = 12
		pestana.content_margin_right = 12
		pestana.content_margin_top = 5
		pestana.content_margin_bottom = 5
		tema.set_stylebox(estado, "TabContainer", pestana)
	tema.set_color("font_selected_color", "TabContainer", Color(0.75, 1, 0.8))
	tema.set_color("font_unselected_color", "TabContainer", Color(0.65, 0.7, 0.65))
	tema.set_color("font_hovered_color", "TabContainer", Color(0.9, 1, 0.9))
	return tema


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
