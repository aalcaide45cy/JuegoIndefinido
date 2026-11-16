# menu_base.gd
# -----------------------------------------------------------------------------
# Base para las ventanas que se abren encima del juego (tienda, inventario,
# estantería). Pone un fondo oscuro, un panel centrado con título y un botón
# de cerrar, y vuelve a dibujar el contenido cada vez que cambia el inventario.
#
# Cada menú hereda de este y escribe su contenido en rellenar(caja).
# -----------------------------------------------------------------------------
class_name MenuBase
extends Control

signal terminado

var titulo: String = "Menú"
var tamano: Vector2 = Vector2(640, 520)

var _contenido: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fondo: ColorRect = ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.5)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var panel: PanelContainer = Hud.crear_panel()
	Hud.centrar(panel, tamano)
	add_child(panel)
	var caja: VBoxContainer = VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	panel.add_child(caja)

	var cabecera: HBoxContainer = HBoxContainer.new()
	caja.add_child(cabecera)
	cabecera.add_child(Hud.crear_label(26, Color(0.6, 0.9, 0.6)))
	(cabecera.get_child(0) as Label).text = titulo
	var hueco: Control = Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(hueco)
	cabecera.add_child(Hud.crear_boton("Cerrar (Esc)", cerrar))

	var desplazable: ScrollContainer = ScrollContainer.new()
	desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(desplazable)
	_contenido = VBoxContainer.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.add_theme_constant_override("separation", 6)
	desplazable.add_child(_contenido)

	Juego.cambio.connect(_refrescar)
	_refrescar()


func _refrescar() -> void:
	for hijo in _contenido.get_children():
		hijo.queue_free()
	rellenar(_contenido)


# Cada menú escribe aquí lo que muestra.
func rellenar(_caja: VBoxContainer) -> void:
	pass


func cerrar() -> void:
	terminado.emit()
	queue_free()


# Una fila: texto a la izquierda y botones a la derecha.
func fila(caja: VBoxContainer, texto: String, botones: Array = [], tam: int = 17) -> void:
	var linea: HBoxContainer = HBoxContainer.new()
	caja.add_child(linea)
	var etiqueta: Label = Hud.crear_label(tam)
	etiqueta.text = texto
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	linea.add_child(etiqueta)
	for b in botones:
		linea.add_child(b)
