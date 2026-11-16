# hud.gd
# -----------------------------------------------------------------------------
# Lo que se dibuja encima del mundo 3D: dinero, inventario, el texto de
# "[E] Usar...", los mensajes y el fundido a negro de las puertas.
# -----------------------------------------------------------------------------
class_name Hud
extends CanvasLayer

var jugador: Jugador   # Lo pone mundo.gd.

var _label_estado: Label
var _label_accion: Label
var _label_mensaje: Label
var _negro: ColorRect
var _tiempo_mensaje: float = 0.0


func _ready() -> void:
	# Arriba a la izquierda: dinero e inventario.
	_label_estado = _crear_label(18)
	_label_estado.position = Vector2(20, 16)
	add_child(_label_estado)

	# Punto de mira en el centro de la pantalla.
	var mira: ColorRect = ColorRect.new()
	mira.color = Color(1, 1, 1, 0.6)
	mira.size = Vector2(4, 4)
	mira.set_anchors_preset(Control.PRESET_CENTER)
	mira.position -= mira.size / 2.0
	mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mira)

	# Abajo en el centro: mensajes y la acción disponible.
	_label_mensaje = _crear_label(18, Color(0.85, 0.95, 0.8))
	_colocar_abajo(_label_mensaje, 110)
	_label_accion = _crear_label(22, Color(1, 0.92, 0.6))
	_colocar_abajo(_label_accion, 60)

	# Abajo a la izquierda: ayuda de controles.
	var ayuda: Label = _crear_label(14, Color(0.7, 0.7, 0.7))
	ayuda.text = "WASD moverse · Ratón mirar · Shift correr · Espacio saltar · E usar · Q cambiar hierba · V cámara · Esc soltar ratón"
	_colocar_abajo(ayuda, 26)

	# Rectángulo negro para el fundido (empieza transparente).
	_negro = ColorRect.new()
	_negro.color = Color(0, 0, 0, 0)
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_negro)

	Juego.cambio.connect(_actualizar_estado)
	Juego.mensaje.connect(_mostrar_mensaje)
	_actualizar_estado()
	_mostrar_mensaje("Medianoche en la Plaza del Ahorcado. La magia está prohibida... " +
			"Entra en tu herboristería (la puerta verde) y pulsa E.")


func _process(delta: float) -> void:
	# Texto de la acción: se pregunta cada fotograma porque cambia (p. ej. el % de crecimiento).
	if jugador != null and jugador.objetivo != null:
		_label_accion.text = "[E] " + jugador.objetivo.texto_accion()
	else:
		_label_accion.text = ""
	# Los mensajes se desvanecen pasados unos segundos.
	_tiempo_mensaje -= delta
	_label_mensaje.modulate.a = clampf(_tiempo_mensaje, 0.0, 1.0)


func _actualizar_estado() -> void:
	var lineas: PackedStringArray = []
	lineas.append("Monedas: %d / %d para el alquiler" % [Juego.dinero, GameData.OBJETIVO_DINERO])
	var en_mano: String = Juego.hierba_seleccionada()
	for id_hierba in GameData.HIERBAS:
		var marca: String = "> " if id_hierba == en_mano else "   "
		lineas.append("%s%s: %d" % [marca, GameData.HIERBAS[id_hierba]["nombre"], Juego.hierbas[id_hierba]])
	for id_pocion in GameData.POCIONES:
		if Juego.pociones[id_pocion] > 0:
			lineas.append("Poción %s: %d" % [GameData.POCIONES[id_pocion]["nombre"], Juego.pociones[id_pocion]])
	lineas.append("(Q cambia la hierba en la mano: >)")
	_label_estado.text = "\n".join(lineas)


func _mostrar_mensaje(texto: String) -> void:
	_label_mensaje.text = texto
	_tiempo_mensaje = 6.0


# Funde a negro, ejecuta "en_medio" (por ejemplo, mover al jugador) y vuelve.
func fundido(en_medio: Callable) -> void:
	var animacion: Tween = create_tween()
	animacion.tween_property(_negro, "color:a", 1.0, 0.25)
	animacion.tween_callback(en_medio)
	animacion.tween_property(_negro, "color:a", 0.0, 0.35)


# ------------------------------ Ayudas ----------------------------------------

func _crear_label(tam: int, color: Color = Color(0.9, 0.9, 0.85)) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", tam)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# Coloca un texto centrado a lo ancho, a "alto" píxeles del borde de abajo.
func _colocar_abajo(label: Label, alto: float) -> void:
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.offset_top = -alto
	label.offset_bottom = -alto + 30
	label.offset_left = 40
	label.offset_right = -40
	add_child(label)
