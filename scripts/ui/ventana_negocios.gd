# ventana_negocios.gd
# -----------------------------------------------------------------------------
# La gestión de tus negocios en una ventana grande (la misma pantalla que la
# pestaña Negocios del móvil). Se abre desde el quiosco de la inmobiliaria y
# desde el concesionario. Si se abre desde el concesionario, "punto" y "giro"
# son la plaza de entrega: así se pueden sacar a la calle los vehículos de tu
# cartera y aportar los tuyos al negocio. SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name VentanaNegocios
extends Ventana

var titulo: String = "Mis negocios"
var cat_inicial: String = ""      # "piso", "coche", "pesado" o "aire".
var punto = null                  # Vector3 o null.
var giro: float = 0.0


func construir() -> void:
	var caja: VBoxContainer = panel_centrado(Vector2(860, 680))
	cabecera(caja, titulo)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(scroll)
	var panel: PanelNegocios = PanelNegocios.new()
	panel.ancho = 800.0
	panel.cat_inicial = cat_inicial
	panel.punto = punto
	panel.giro = giro
	scroll.add_child(panel)
