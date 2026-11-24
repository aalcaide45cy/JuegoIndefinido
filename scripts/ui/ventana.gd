# ventana.gd
# -----------------------------------------------------------------------------
# Base de TODAS las ventanas que se abren encima del juego (inventario, tiendas,
# móvil, mapa, ajustes, admin...). Pone el fondo oscurecido, el marco común con
# cabecera (título + cerrar) y pie con las ayudas de teclado/mando, y se
# encarga de que se pueda manejar sin ratón: el foco empieza en el primer botón
# y B / Esc cierran la ventana de más arriba.
#
# Cada ventana hereda de esta y monta su contenido en construir(). Dos formas:
#   - panel_centrado(tam)  : marco con scroll, el contenido crece hacia abajo.
#   - marco(titulo, ...)   : marco SIN scroll (el cuerpo se reparte con
#                            columnas, pestañas y listas que se desplazan solas).
# -----------------------------------------------------------------------------
class_name Ventana
extends Control

signal terminado

# Márgenes mínimos entre el marco y el borde de la pantalla (unidades de interfaz).
const MARGEN_PANTALLA: float = 14.0

# Ayudas del pie: [["Q","teclado","B","mando"], ...] no; se pasan a pie() como pares [accion, texto].
var _marco_raiz: VBoxContainer = null   # Contiene la cabecera, el cuerpo y el pie.
var _marco_scroll: ScrollContainer = null     # Solo con panel_centrado.
var _marco_cabecera: HBoxContainer = null
var _marco_pie: HBoxContainer = null
var pistas_extra: Array = []            # [["mover", "Elegir"], ...] se añaden al pie antes de construir().
var incrustada: bool = false            # true = va dentro de otra ventana (sin fondo ni pie propios).
var se_cierra_con_atras: bool = true    # B del mando cierra la ventana (el menú de inicio no).


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not incrustada:
		var fondo: ColorRect = ColorRect.new()
		fondo.color = Color(0.01, 0.015, 0.025, 0.66)
		fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fondo)
	else:
		mouse_filter = Control.MOUSE_FILTER_PASS
	construir()
	_pie_estandar()
	call_deferred("_enfocar")


func construir() -> void:
	pass


func cerrar() -> void:
	terminado.emit()
	queue_free()


# B del mando, Esc y la tecla de "liberar ratón" cierran la ventana más "profunda".
# (El HUD llama a cerrar_superior() sobre la ventana principal.)
func cerrar_superior() -> void:
	var hija: Ventana = _ventana_hija()
	if hija != null:
		hija.cerrar_superior()
	else:
		cerrar()


# Cierra la ventana de más arriba de todas (la que abrió el HUD), aunque esta vaya dentro de otra.
func cerrar_raiz() -> void:
	var v: Ventana = self
	while v.get_parent() is Ventana:
		v = v.get_parent() as Ventana
	v.cerrar()


func _ventana_hija() -> Ventana:
	for i in range(get_child_count() - 1, -1, -1):
		var h: Node = get_child(i)
		if h is Ventana and not h.is_queued_for_deletion():
			return h
	return null


# El espacio que hay en pantalla para esta ventana, en unidades de la interfaz
# (el HUD escala su raíz según la altura de la pantalla).
func espacio_visible() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	var padre: Control = get_parent() as Control
	if padre != null and padre.size.y > 0.0:
		return padre.size
	return get_viewport_rect().size


# Reduce un tamaño deseado a lo que cabe en pantalla.
func tam_ajustado(tam: Vector2) -> Vector2:
	var libre: Vector2 = (espacio_visible() - Vector2.ONE * MARGEN_PANTALLA * 2.0).max(Vector2(320, 280))
	return Vector2(minf(tam.x, libre.x), minf(tam.y, libre.y))


# ------------------------------- Marcos ---------------------------------------

# Marco común: devuelve el VBox del CUERPO (ocupa todo el hueco entre la cabecera y el pie).
func marco(titulo: String, subtitulo_texto: String = "", tam: Vector2 = Vector2(1100, 640)) -> VBoxContainer:
	var panel: PanelContainer = _panel_base(tam)
	_marco_raiz = VBoxContainer.new()
	_marco_raiz.add_theme_constant_override("separation", 10)
	panel.add_child(_marco_raiz)
	cabecera(_marco_raiz, titulo, subtitulo_texto)
	var cuerpo: VBoxContainer = VBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 10)
	_marco_raiz.add_child(cuerpo)
	return cuerpo


# Un panel centrado en la pantalla, con su caja vertical dentro.
# Si el contenido no cabe en el tamaño pedido (o en la pantalla), el panel se queda del tamaño
# que cabe y el contenido se desplaza con la rueda del ratón o el stick.
func panel_centrado(tam: Vector2) -> VBoxContainer:
	var panel: PanelContainer = _panel_base(tam)
	_marco_raiz = VBoxContainer.new()
	_marco_raiz.add_theme_constant_override("separation", 8)
	panel.add_child(_marco_raiz)
	_marco_scroll = ScrollContainer.new()
	_marco_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_marco_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_marco_scroll.follow_focus = true
	_marco_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_marco_raiz.add_child(_marco_scroll)
	var caja: VBoxContainer = VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_marco_scroll.add_child(caja)
	return caja


func _panel_base(tam: Vector2) -> PanelContainer:
	var centro: CenterContainer = CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = tam_ajustado(tam)
	centro.add_child(panel)
	return panel


# Cabecera con título a la izquierda y botón de cerrar a la derecha.
# Con panel_centrado, la cabecera se queda fija arriba aunque el contenido se desplace.
func cabecera(caja: Container, titulo: String, subtitulo_texto: String = "") -> HBoxContainer:
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	var etiqueta: Label = UI.titulo(titulo)
	fila.add_child(etiqueta)
	if subtitulo_texto != "":
		var sub: Label = UI.subtitulo(subtitulo_texto)
		sub.size_flags_vertical = Control.SIZE_SHRINK_END
		fila.add_child(sub)
	var hueco: Control = Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(hueco)
	var cerrar_boton: Button = UI.boton("Cerrar", cerrar, "BotonSuave", "cross")
	fila.add_child(cerrar_boton)
	if _marco_scroll != null and caja == _marco_scroll.get_child(0) and _marco_raiz != null:
		_marco_raiz.add_child(fila)
		_marco_raiz.move_child(fila, 0)
		_marco_raiz.add_child(UI.separador())
		_marco_raiz.move_child(_marco_raiz.get_child(_marco_raiz.get_child_count() - 1), 1)
	else:
		caja.add_child(fila)
		if caja == _marco_raiz:
			caja.add_child(UI.separador())
	_marco_cabecera = fila
	return fila


# Un subtítulo pequeño.
func subtitulo(caja: Container, texto: String) -> Label:
	var label: Label = UI.subtitulo(texto)
	caja.add_child(label)
	return label


# Una rejilla de casillas de "lista" (desde..hasta-1). "al_enviar" se llama
# con Mayúsculas + clic sobre una casilla.
func rejilla(caja: Container, lista: Array, desde: int, hasta: int, columnas: int,
		tam: float, al_enviar: Callable = Callable(), numeros: bool = false) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = columnas
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	caja.add_child(grid)
	for i in range(desde, hasta):
		var casilla: CasillaUI = CasillaUI.new(lista, i, tam)
		if numeros:
			casilla.numero = str(i + 1)
		if al_enviar.is_valid():
			casilla.envio_rapido.connect(al_enviar)
		grid.add_child(casilla)
	return grid


# ------------------------------ Pie de ayudas ---------------------------------

# Pone (o rehace) el pie con las ayudas. "extra": pares [accion, texto], donde accion
# es "mover", "aceptar", "pestanas", "buscar"... (ver UI.pista).
func _pie_estandar() -> void:
	if _marco_raiz == null or _marco_pie != null:
		return
	_marco_pie = HBoxContainer.new()
	_marco_pie.add_theme_constant_override("separation", 20)
	_marco_raiz.add_child(UI.separador())
	_marco_raiz.add_child(_marco_pie)
	for p in pistas_extra:
		UI.pista(_marco_pie, str(p[0]), str(p[1]))
	UI.pista(_marco_pie, "mover", "Navegar")
	UI.pista(_marco_pie, "aceptar", "Elegir")
	UI.pista(_marco_pie, "atras", "Cerrar")


# Con mando: B cierra. Con teclado o mando: la primera vez que se pulsa una dirección sin
# foco, el foco salta al primer botón (así no se ve un recuadro dorado si solo usas el ratón).
func _unhandled_input(evento: InputEvent) -> void:
	var boton: InputEventJoypadButton = evento as InputEventJoypadButton
	if boton != null and boton.pressed and boton.button_index == JOY_BUTTON_B and se_cierra_con_atras:
		if _ventana_hija() == null:
			cerrar()
		get_viewport().set_input_as_handled()
		return
	if get_viewport() == null or _ventana_hija() != null:
		return
	if evento.is_action_pressed("ui_down") or evento.is_action_pressed("ui_up") \
			or evento.is_action_pressed("ui_left") or evento.is_action_pressed("ui_right") \
			or evento.is_action_pressed("ui_accept"):
		if get_viewport().gui_get_focus_owner() == null:
			var primero: Control = UI.primer_enfocable(self)
			if primero != null:
				primero.grab_focus()
				get_viewport().set_input_as_handled()


# Con mando conectado el foco empieza en el primer botón.
func _enfocar() -> void:
	if not is_inside_tree() or get_viewport() == null or Input.get_connected_joypads().is_empty():
		return
	if get_viewport().gui_get_focus_owner() != null and is_ancestor_of(get_viewport().gui_get_focus_owner()):
		return
	var primero: Control = UI.primer_enfocable(self)
	if primero != null:
		primero.grab_focus()
