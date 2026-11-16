# ventana.gd
# -----------------------------------------------------------------------------
# Base para las ventanas que se abren encima del juego (inventario, tienda,
# estantería, panel de administrador). Pone un fondo oscuro y ofrece ayudas
# para crear paneles, títulos y rejillas de casillas.
#
# Cada ventana hereda de esta y monta su contenido en construir().
# -----------------------------------------------------------------------------
class_name Ventana
extends Control

signal terminado


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fondo: ColorRect = ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	construir()


func construir() -> void:
	pass


func cerrar() -> void:
	terminado.emit()
	queue_free()


# Un panel centrado en la pantalla, con su caja vertical dentro.
func panel_centrado(tam: Vector2) -> VBoxContainer:
	var panel: PanelContainer = Hud.crear_panel()
	Hud.centrar(panel, tam)
	add_child(panel)
	var caja: VBoxContainer = VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	panel.add_child(caja)
	return caja


# Cabecera con título a la izquierda y botón de cerrar a la derecha.
func cabecera(caja: Container, titulo: String) -> HBoxContainer:
	var fila: HBoxContainer = HBoxContainer.new()
	caja.add_child(fila)
	var label: Label = Hud.crear_label(26, Color(0.6, 0.9, 0.6))
	label.text = titulo
	fila.add_child(label)
	var hueco: Control = Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(hueco)
	fila.add_child(Hud.crear_boton("Cerrar (Esc)", cerrar))
	return fila


# Un subtítulo pequeño.
func subtitulo(caja: Container, texto: String) -> Label:
	var label: Label = Hud.crear_label(16, Color(0.75, 0.8, 0.72))
	label.text = texto
	caja.add_child(label)
	return label


# Una rejilla de casillas de "lista" (desde..hasta-1). "al_enviar" se llama
# con Mayúsculas + clic sobre una casilla.
func rejilla(caja: Container, lista: Array, desde: int, hasta: int, columnas: int,
		tam: float, al_enviar: Callable = Callable(), numeros: bool = false) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = columnas
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	caja.add_child(grid)
	for i in range(desde, hasta):
		var casilla: CasillaUI = CasillaUI.new(lista, i, tam)
		if numeros:
			casilla.numero = str(i + 1)
		if al_enviar.is_valid():
			casilla.envio_rapido.connect(al_enviar)
		grid.add_child(casilla)
	return grid
