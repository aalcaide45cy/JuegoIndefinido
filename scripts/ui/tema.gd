# tema.gd
# -----------------------------------------------------------------------------
# El estilo ÚNICO de toda la interfaz de Juego Indefinido: colores, tipografía y
# el Theme de Godot que usan HUD, móvil, tiendas, menús, mapa, admin, etc.
#
# Línea visual: "tinta y bruma". Fondos casi negros con un punto azulado, bordes
# finos, un acento dorado para lo seleccionado y los títulos, y verde bruma para
# lo bueno (dinero, vida, comprar). Rojo para peligro. Todo con esquinas suaves.
#
# Para usarlo no hay que hacer nada: Hud.crear_tema() devuelve Tema.crear() y se
# aplica a toda la interfaz. Los botones especiales se piden con "variaciones":
#   boton.theme_type_variation = "BotonPrimario" / "BotonPeligro" / "BotonSuave" / "Chip"
#   panel.theme_type_variation = "Tarjeta" / "TarjetaSeleccion" / "PanelHondo"
#   label.theme_type_variation = "Titulo" / "Subtitulo" / "Nota" / "Dinero"
# -----------------------------------------------------------------------------
class_name Tema
extends RefCounted

# ----------------------------- Colores ---------------------------------------
const FONDO: Color = Color(0.045, 0.05, 0.062)
const PANEL: Color = Color(0.082, 0.092, 0.108, 0.97)
const PANEL_HONDO: Color = Color(0.058, 0.066, 0.08, 0.95)
const TARJETA: Color = Color(0.118, 0.132, 0.152)
const TARJETA_HOVER: Color = Color(0.15, 0.17, 0.19)
const BORDE: Color = Color(0.215, 0.25, 0.27)
const BORDE_SUAVE: Color = Color(0.16, 0.185, 0.2)
const ACENTO: Color = Color(0.96, 0.78, 0.38)         # Dorado: selección y títulos.
const ACENTO_OSCURO: Color = Color(0.36, 0.28, 0.1)
const BRUMA: Color = Color(0.42, 0.86, 0.68)          # Verde bruma: bueno, comprar.
const BRUMA_OSCURO: Color = Color(0.1, 0.26, 0.2)
const AZUL: Color = Color(0.45, 0.76, 1.0)            # Información, móvil.
const PELIGRO: Color = Color(0.95, 0.4, 0.36)
const PELIGRO_OSCURO: Color = Color(0.3, 0.1, 0.1)
const TEXTO: Color = Color(0.92, 0.93, 0.9)
const TEXTO_SUAVE: Color = Color(0.66, 0.7, 0.7)
const TEXTO_TENUE: Color = Color(0.46, 0.5, 0.52)
const DINERO: Color = Color(0.66, 0.92, 0.52)
const MAGIA: Color = Color(0.74, 0.55, 1.0)

const RUTA_ICONOS: String = "res://assets/kenney/game-icons/PNG/White/2x/"
const RUTA_FUENTES: String = "res://assets/fuentes/"

static var _tema: Theme = null
static var _fuentes: Dictionary = {}
static var _iconos: Dictionary = {}


# ----------------------------- Tipografía ------------------------------------
# peso: "regular", "medium", "semibold" o "bold". Si el archivo no está, usa la de Godot.
static func fuente(peso: String = "regular") -> Font:
	if _fuentes.has(peso):
		return _fuentes[peso]
	var nombre: String = {"regular": "Inter-Regular", "medium": "Inter-Medium",
			"semibold": "Inter-SemiBold", "bold": "Inter-Bold"}.get(peso, "Inter-Regular")
	var ruta: String = RUTA_FUENTES + nombre + ".otf"
	var f: Font = null
	if ResourceLoader.exists(ruta):
		f = load(ruta) as Font
	_fuentes[peso] = f
	return f


# Un icono blanco de Kenney por su nombre (p. ej. "gear"). Null si no existe.
static func icono(nombre: String) -> Texture2D:
	if _iconos.has(nombre):
		return _iconos[nombre]
	var ruta: String = RUTA_ICONOS + nombre + ".png"
	var t: Texture2D = load(ruta) as Texture2D if ResourceLoader.exists(ruta) else null
	_iconos[nombre] = t
	return t


# ----------------------------- Cajas de estilo -------------------------------
static func caja(fondo: Color, borde: Color = Color(0, 0, 0, 0), ancho_borde: int = 0, radio: int = 8,
		margen_x: float = 12.0, margen_y: float = 8.0) -> StyleBoxFlat:
	var c: StyleBoxFlat = StyleBoxFlat.new()
	c.bg_color = fondo
	c.border_color = borde
	c.set_border_width_all(ancho_borde)
	c.set_corner_radius_all(radio)
	c.content_margin_left = margen_x
	c.content_margin_right = margen_x
	c.content_margin_top = margen_y
	c.content_margin_bottom = margen_y
	c.anti_aliasing = true
	return c


static func caja_con_sombra(fondo: Color, borde: Color, radio: int, margen: float) -> StyleBoxFlat:
	var c: StyleBoxFlat = caja(fondo, borde, 1, radio, margen, margen)
	c.shadow_color = Color(0, 0, 0, 0.55)
	c.shadow_size = 18
	c.shadow_offset = Vector2(0, 6)
	return c


# ----------------------------- El Theme --------------------------------------
static func crear() -> Theme:
	if _tema != null:
		return _tema
	var t: Theme = Theme.new()
	var f: Font = fuente("regular")
	if f != null:
		t.default_font = f
	t.default_font_size = 17

	# --- Etiquetas -----------------------------------------------------------
	t.set_color("font_color", "Label", TEXTO)
	_variacion_label(t, "Titulo", "bold", 26, ACENTO)
	_variacion_label(t, "Subtitulo", "semibold", 15, TEXTO_SUAVE)
	_variacion_label(t, "Nota", "regular", 14, TEXTO_TENUE)
	_variacion_label(t, "Dinero", "semibold", 18, DINERO)
	_variacion_label(t, "Peligro", "semibold", 15, PELIGRO)

	# --- Botones -------------------------------------------------------------
	_botones(t, "Button", TARJETA, TARJETA_HOVER, Color(0.2, 0.23, 0.25), BORDE, TEXTO)
	_botones(t, "BotonPrimario", BRUMA_OSCURO, Color(0.14, 0.36, 0.28), Color(0.18, 0.46, 0.35), BRUMA.darkened(0.25), Color(0.85, 1.0, 0.92))
	_botones(t, "BotonPeligro", PELIGRO_OSCURO, Color(0.42, 0.14, 0.13), Color(0.55, 0.18, 0.16), PELIGRO.darkened(0.3), Color(1, 0.88, 0.85))
	_botones(t, "BotonSuave", Color(0, 0, 0, 0), Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), TEXTO_SUAVE)
	_botones(t, "BotonAcento", ACENTO_OSCURO, Color(0.5, 0.38, 0.12), Color(0.62, 0.48, 0.16), ACENTO.darkened(0.2), Color(1, 0.94, 0.78))
	_chips(t)
	_pestana_boton(t)
	for tipo in ["BotonPrimario", "BotonPeligro", "BotonSuave", "BotonAcento", "Chip", "Pestana"]:
		t.set_type_variation(tipo, "Button")
	t.set_font_size("font_size", "Button", 16)
	if fuente("semibold") != null:
		t.set_font("font", "Button", fuente("semibold"))

	# OptionButton y CheckBox heredan el aspecto de los botones.
	for tipo in ["OptionButton", "MenuButton"]:
		for estado in ["normal", "hover", "pressed", "disabled", "focus"]:
			t.set_stylebox(estado, tipo, t.get_stylebox(estado, "Button"))
		t.set_color("font_color", tipo, TEXTO)
		t.set_color("font_hover_color", tipo, Color(1, 1, 0.92))
		if fuente("medium") != null:
			t.set_font("font", tipo, fuente("medium"))
	t.set_color("font_color", "CheckBox", TEXTO)
	t.set_color("font_color", "CheckButton", TEXTO)
	t.set_color("font_hover_color", "CheckBox", Color(1, 1, 0.92))
	t.set_stylebox("focus", "CheckBox", caja(Color(0, 0, 0, 0), ACENTO, 2, 6, 4, 4))
	t.set_stylebox("focus", "CheckButton", caja(Color(0, 0, 0, 0), ACENTO, 2, 6, 4, 4))

	# --- Paneles -------------------------------------------------------------
	t.set_stylebox("panel", "PanelContainer", caja_con_sombra(PANEL, BORDE, 14, 20))
	t.set_stylebox("panel", "Panel", caja(PANEL, BORDE, 1, 12))
	t.set_stylebox("panel", "Tarjeta", caja(TARJETA, BORDE_SUAVE, 1, 10, 12, 10))
	t.set_stylebox("panel", "TarjetaSeleccion", caja(Color(0.2, 0.17, 0.1), ACENTO, 2, 10, 12, 10))
	t.set_stylebox("panel", "PanelHondo", caja(PANEL_HONDO, BORDE_SUAVE, 1, 10, 12, 10))
	t.set_stylebox("panel", "Cabecera", caja(Color(0.1, 0.115, 0.135), Color(0, 0, 0, 0), 0, 10, 14, 8))
	for tipo in ["Tarjeta", "TarjetaSeleccion", "PanelHondo", "Cabecera"]:
		t.set_type_variation(tipo, "PanelContainer")

	# --- Pestañas (TabContainer / TabBar) -------------------------------------
	for tipo in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_selected", tipo, _pestana(Color(0.16, 0.14, 0.09), ACENTO))
		t.set_stylebox("tab_unselected", tipo, _pestana(Color(0.09, 0.1, 0.115), BORDE_SUAVE))
		t.set_stylebox("tab_hovered", tipo, _pestana(Color(0.14, 0.155, 0.175), BORDE))
		t.set_stylebox("tab_focus", tipo, _pestana(Color(0.16, 0.14, 0.09), ACENTO))
		t.set_color("font_selected_color", tipo, ACENTO)
		t.set_color("font_unselected_color", tipo, TEXTO_SUAVE)
		t.set_color("font_hovered_color", tipo, TEXTO)
		if fuente("semibold") != null:
			t.set_font("font", tipo, fuente("semibold"))
		t.set_font_size("font_size", tipo, 16)
	t.set_stylebox("panel", "TabContainer", caja(Color(0, 0, 0, 0), BORDE_SUAVE, 0, 0, 4, 8))

	# --- Campos de texto -------------------------------------------------------
	var campo: StyleBoxFlat = caja(Color(0.06, 0.07, 0.085), BORDE, 1, 8, 12, 8)
	t.set_stylebox("normal", "LineEdit", campo)
	t.set_stylebox("focus", "LineEdit", caja(Color(0.07, 0.08, 0.1), ACENTO, 2, 8, 12, 8))
	t.set_stylebox("read_only", "LineEdit", campo)
	t.set_color("font_color", "LineEdit", TEXTO)
	t.set_color("font_placeholder_color", "LineEdit", TEXTO_TENUE)
	t.set_color("caret_color", "LineEdit", ACENTO)
	t.set_color("selection_color", "LineEdit", Color(ACENTO.r, ACENTO.g, ACENTO.b, 0.35))
	t.set_stylebox("normal", "TextEdit", campo)
	t.set_stylebox("focus", "TextEdit", caja(Color(0.07, 0.08, 0.1), ACENTO, 2, 8, 12, 8))
	t.set_color("font_color", "TextEdit", TEXTO)

	# --- Listas ----------------------------------------------------------------
	t.set_stylebox("panel", "ItemList", caja(PANEL_HONDO, BORDE_SUAVE, 1, 8, 6, 6))
	t.set_stylebox("focus", "ItemList", caja(Color(0, 0, 0, 0), ACENTO, 1, 8, 6, 6))
	t.set_stylebox("selected", "ItemList", caja(Color(0.2, 0.17, 0.1), ACENTO.darkened(0.3), 1, 6, 6, 4))
	t.set_stylebox("selected_focus", "ItemList", caja(Color(0.24, 0.2, 0.11), ACENTO, 1, 6, 6, 4))
	t.set_stylebox("hovered", "ItemList", caja(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 6, 6, 4))
	t.set_color("font_color", "ItemList", TEXTO_SUAVE)
	t.set_color("font_selected_color", "ItemList", ACENTO)
	t.set_color("font_hovered_color", "ItemList", TEXTO)
	t.set_constant("v_separation", "ItemList", 4)
	t.set_constant("h_separation", "ItemList", 6)

	# --- Barras de progreso y deslizadores ------------------------------------
	t.set_stylebox("background", "ProgressBar", caja(Color(0.04, 0.045, 0.055, 0.95), BORDE_SUAVE, 1, 6, 0, 0))
	t.set_stylebox("fill", "ProgressBar", caja(BRUMA, Color(0, 0, 0, 0), 0, 6, 0, 0))
	t.set_color("font_color", "ProgressBar", TEXTO)
	t.set_font_size("font_size", "ProgressBar", 12)
	for tipo in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", tipo, caja(Color(0.04, 0.045, 0.055), BORDE_SUAVE, 1, 4, 0, 3))
		t.set_stylebox("grabber_area", tipo, caja(ACENTO.darkened(0.15), Color(0, 0, 0, 0), 0, 4, 0, 3))
		t.set_stylebox("grabber_area_highlight", tipo, caja(ACENTO, Color(0, 0, 0, 0), 0, 4, 0, 3))
	for tipo in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", tipo, caja(Color(0.04, 0.045, 0.055, 0.7), Color(0, 0, 0, 0), 0, 5, 2, 2))
		t.set_stylebox("grabber", tipo, caja(Color(0.3, 0.34, 0.36), Color(0, 0, 0, 0), 0, 5, 2, 2))
		t.set_stylebox("grabber_highlight", tipo, caja(ACENTO.darkened(0.2), Color(0, 0, 0, 0), 0, 5, 2, 2))
		t.set_stylebox("grabber_pressed", tipo, caja(ACENTO, Color(0, 0, 0, 0), 0, 5, 2, 2))

	# --- Menús desplegables ----------------------------------------------------
	t.set_stylebox("panel", "PopupMenu", caja_con_sombra(Color(0.075, 0.085, 0.1, 0.98), BORDE, 8, 6))
	t.set_stylebox("hover", "PopupMenu", caja(Color(0.2, 0.17, 0.1), ACENTO.darkened(0.3), 1, 6, 6, 4))
	t.set_color("font_color", "PopupMenu", TEXTO)
	t.set_color("font_hover_color", "PopupMenu", ACENTO)
	t.set_constant("v_separation", "PopupMenu", 6)

	# --- Ayuda emergente -------------------------------------------------------
	t.set_stylebox("panel", "TooltipPanel", caja(Color(0.07, 0.08, 0.1, 0.98), ACENTO.darkened(0.3), 1, 8, 10, 8))
	t.set_color("font_color", "TooltipLabel", TEXTO)
	t.set_font_size("font_size", "TooltipLabel", 15)

	# --- Separadores -----------------------------------------------------------
	var linea: StyleBoxLine = StyleBoxLine.new()
	linea.color = BORDE_SUAVE
	linea.thickness = 1
	t.set_stylebox("separator", "HSeparator", linea)
	var linea_v: StyleBoxLine = StyleBoxLine.new()
	linea_v.color = BORDE_SUAVE
	linea_v.thickness = 1
	linea_v.vertical = true
	t.set_stylebox("separator", "VSeparator", linea_v)
	t.set_constant("separation", "HSeparator", 10)

	_tema = t
	return t


static func _variacion_label(t: Theme, nombre: String, peso: String, tam: int, color: Color) -> void:
	t.set_type_variation(nombre, "Label")
	t.set_font_size("font_size", nombre, tam)
	t.set_color("font_color", nombre, color)
	var f: Font = fuente(peso)
	if f != null:
		t.set_font("font", nombre, f)


# Los estados de un botón (normal, encima, pulsado, desactivado, enfocado) para un tipo.
static func _botones(t: Theme, tipo: String, normal: Color, encima: Color, pulsado: Color, borde: Color, texto: Color) -> void:
	var ancho: int = 1 if borde.a > 0.0 else 0
	var estados: Dictionary = {"normal": normal, "hover": encima, "pressed": pulsado}
	for estado in estados:
		t.set_stylebox(estado, tipo, caja(estados[estado], borde if estado == "normal" else borde.lightened(0.15), ancho, 8, 14, 8))
	t.set_stylebox("disabled", tipo, caja(Color(0.075, 0.085, 0.1, 0.7), BORDE_SUAVE, ancho, 8, 14, 8))
	# El foco (teclado y mando) se ve claro: borde dorado grueso.
	t.set_stylebox("focus", tipo, caja(Color(0, 0, 0, 0), ACENTO, 2, 8, 14, 8))
	t.set_color("font_color", tipo, texto)
	t.set_color("font_hover_color", tipo, texto.lightened(0.2))
	t.set_color("font_pressed_color", tipo, texto.lightened(0.3))
	t.set_color("font_focus_color", tipo, texto.lightened(0.2))
	t.set_color("font_disabled_color", tipo, TEXTO_TENUE)
	t.set_color("icon_normal_color", tipo, texto)
	t.set_color("icon_hover_color", tipo, texto.lightened(0.2))
	t.set_color("icon_pressed_color", tipo, texto.lightened(0.3))
	t.set_color("icon_disabled_color", tipo, TEXTO_TENUE)
	t.set_constant("h_separation", tipo, 8)


# "Chip": botón pequeño y redondeado que se enciende (filtros y categorías).
static func _chips(t: Theme) -> void:
	var tipo: String = "Chip"
	t.set_stylebox("normal", tipo, caja(Color(0.1, 0.115, 0.135), BORDE_SUAVE, 1, 15, 12, 4))
	t.set_stylebox("hover", tipo, caja(Color(0.15, 0.17, 0.19), BORDE, 1, 15, 12, 4))
	t.set_stylebox("pressed", tipo, caja(Color(0.22, 0.18, 0.09), ACENTO, 1, 15, 12, 4))
	t.set_stylebox("hover_pressed", tipo, caja(Color(0.26, 0.21, 0.1), ACENTO, 1, 15, 12, 4))
	t.set_stylebox("disabled", tipo, caja(Color(0.075, 0.085, 0.1, 0.7), BORDE_SUAVE, 1, 15, 12, 4))
	t.set_stylebox("focus", tipo, caja(Color(0, 0, 0, 0), ACENTO, 2, 15, 12, 4))
	t.set_color("font_color", tipo, TEXTO_SUAVE)
	t.set_color("font_hover_color", tipo, TEXTO)
	t.set_color("font_pressed_color", tipo, ACENTO)
	t.set_color("font_hover_pressed_color", tipo, ACENTO)
	t.set_color("font_focus_color", tipo, TEXTO)
	t.set_font_size("font_size", tipo, 14)


static func _pestana(fondo: Color, borde: Color) -> StyleBoxFlat:
	var c: StyleBoxFlat = caja(fondo, borde, 0, 8, 16, 8)
	c.border_width_bottom = 3
	c.corner_radius_bottom_left = 0
	c.corner_radius_bottom_right = 0
	return c


# "Pestana": botón plano con subrayado dorado cuando está activo (UI.Pestanas).
static func _pestana_boton(t: Theme) -> void:
	var tipo: String = "Pestana"
	var normal: StyleBoxFlat = caja(Color(0, 0, 0, 0), BORDE_SUAVE, 0, 0, 16, 9)
	normal.border_width_bottom = 3
	var hover: StyleBoxFlat = caja(Color(1, 1, 1, 0.05), BORDE, 0, 0, 16, 9)
	hover.border_width_bottom = 3
	var activa: StyleBoxFlat = caja(Color(ACENTO.r, ACENTO.g, ACENTO.b, 0.1), ACENTO, 0, 0, 16, 9)
	activa.border_width_bottom = 3
	t.set_stylebox("normal", tipo, normal)
	t.set_stylebox("hover", tipo, hover)
	t.set_stylebox("pressed", tipo, activa)
	t.set_stylebox("hover_pressed", tipo, activa)
	t.set_stylebox("disabled", tipo, normal)
	var foco: StyleBoxFlat = caja(Color(0, 0, 0, 0), ACENTO, 2, 4, 16, 9)
	t.set_stylebox("focus", tipo, foco)
	t.set_color("font_color", tipo, TEXTO_SUAVE)
	t.set_color("font_hover_color", tipo, TEXTO)
	t.set_color("font_pressed_color", tipo, ACENTO)
	t.set_color("font_hover_pressed_color", tipo, ACENTO)
	t.set_color("font_focus_color", tipo, TEXTO)
	t.set_font_size("font_size", tipo, 16)
