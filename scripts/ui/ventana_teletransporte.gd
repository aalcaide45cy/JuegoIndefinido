# ventana_teletransporte.gd
# -----------------------------------------------------------------------------
# Teletransporte del panel de administrador: un mapa del mundo entero (10 km) en
# el que haces clic para ir a ese punto, más una lista de sitios (la plaza, los
# barrios de la ciudad original y todos los pueblos y ciudades del mundo) y dos
# casillas X / Z para ir a unas coordenadas exactas.
#
# Se abre desde Ventanas.Admin (botón "Teletransporte (mapa)"). SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name VentanaTeletransporte
extends Ventana

# Sitios de la ciudad original: [nombre, x, z].
const SITIOS_CIUDAD: Array = [
	["Plaza inicial", 0.0, 8.0],
	["Mercado (norte)", 0.0, -60.0],
	["Zona industrial (sur)", 0.0, 70.0],
	["Barrio residencial (este)", 150.0, -16.0],
	["Zona de campo (concesionario)", 232.0, -16.0],
]

static var _imagen_mapa: ImageTexture = null   # Se calcula una vez (tarda un poco).

var jugador: Node3D = null
var _px: float = 640.0
var _marcas: Control
var _vista: TextureRect
var _coords: Label
var _x: SpinBox
var _z: SpinBox
var _texto: String = ""
var _filtro: UI.Filtros
var _sitios: VBoxContainer


func construir() -> void:
	_px = 500.0
	var caja: VBoxContainer
	if incrustada:
		caja = VBoxContainer.new()
		caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(caja)
	else:
		caja = marco("Teletransporte", "Clic en el mapa para ir", Vector2(1060, 640))
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 16)
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(fila)

	# Mapa del mundo.
	if _imagen_mapa == null:
		_imagen_mapa = ImageTexture.create_from_image(GeneradorMundo.imagen_mapa(256))
	_vista = TextureRect.new()
	_vista.texture = _imagen_mapa
	_vista.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vista.stretch_mode = TextureRect.STRETCH_SCALE
	_vista.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vista.custom_minimum_size = Vector2(_px, _px)
	_vista.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_vista.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_vista.gui_input.connect(_clic_mapa)
	fila.add_child(_vista)
	_marcas = Control.new()
	_marcas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marcas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marcas.draw.connect(_dibujar)
	_vista.add_child(_marcas)

	# Lista de sitios y coordenadas.
	var lado: VBoxContainer = VBoxContainer.new()
	lado.custom_minimum_size = Vector2(340, 0)
	lado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lado.add_theme_constant_override("separation", 8)
	fila.add_child(lado)
	_coords = UI.etiqueta("Mueve el ratón por el mapa.", "Dinero", null, 16)
	lado.add_child(_coords)
	var fila_xz: HBoxContainer = HBoxContainer.new()
	fila_xz.add_theme_constant_override("separation", 6)
	lado.add_child(fila_xz)
	_x = _casilla("X")
	_z = _casilla("Z")
	fila_xz.add_child(UI.etiqueta("X", "Subtitulo"))
	fila_xz.add_child(_x)
	fila_xz.add_child(UI.etiqueta("Z", "Subtitulo"))
	fila_xz.add_child(_z)
	fila_xz.add_child(UI.boton("Ir", func() -> void: _ir(_x.value, _z.value), "BotonPrimario"))
	var pos: Vector3 = jugador.global_position if jugador != null else Vector3.ZERO
	_x.value = snappedf(pos.x, 1.0)
	_z.value = snappedf(pos.z, 1.0)

	lado.add_child(UI.buscador("Buscar un sitio…", func(t: String) -> void:
		_texto = t
		_rellenar_sitios()))
	_filtro = UI.Filtros.new()
	_filtro.anadir("todo", "Todo")
	_filtro.anadir("ciudad_original", "Ciudad original")
	for t in ["Ciudad", "Pueblo", "Aldea"]:
		_filtro.anadir(t, t + "s" if t != "Ciudad" else "Ciudades")
	_filtro.cambiado.connect(func(_c: String) -> void: _rellenar_sitios())
	lado.add_child(_filtro)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	lado.add_child(scroll)
	_sitios = VBoxContainer.new()
	_sitios.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sitios.add_theme_constant_override("separation", 3)
	scroll.add_child(_sitios)
	_rellenar_sitios()


func _rellenar_sitios() -> void:
	for h in _sitios.get_children():
		_sitios.remove_child(h)
		h.queue_free()
	var todos: Array = []
	for s in SITIOS_CIUDAD:
		todos.append({"nombre": str(s[0]), "x": float(s[1]), "z": float(s[2]), "cat": "ciudad_original"})
	var asent: Array = GeneradorMundo.todos_asentamientos()
	asent.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["tipo"]) != int(b["tipo"]):
			return int(a["tipo"]) > int(b["tipo"])
		return str(a["nombre"]) < str(b["nombre"]))
	for s in asent:
		var p: Vector2 = s["pos"]
		var tipo: String = GeneradorMundo.nombre_tipo(int(s["tipo"]))
		todos.append({"nombre": "%s %s" % [tipo, s["nombre"]], "x": p.x, "z": p.y, "cat": tipo})
	var n: int = 0
	for l in todos:
		if _filtro.clave != "todo" and not (str(l["cat"]) == _filtro.clave or str(l["cat"]).begins_with(_filtro.clave)):
			continue
		if _texto != "" and not str(l["nombre"]).to_lower().contains(_texto):
			continue
		_sitios.add_child(_boton_sitio(str(l["nombre"]), float(l["x"]), float(l["z"])))
		n += 1
	if n == 0:
		_sitios.add_child(UI.nota("Ningún sitio coincide."))


func _process(_delta: float) -> void:
	if _marcas != null:
		_marcas.queue_redraw()


func _etiqueta(texto: String) -> Label:
	var l: Label = Hud.crear_label(16)
	l.text = texto
	return l


func _casilla(_nombre: String) -> SpinBox:
	var c: SpinBox = SpinBox.new()
	c.min_value = -GeneradorMundo.MITAD
	c.max_value = GeneradorMundo.MITAD
	c.step = 1.0
	c.custom_minimum_size = Vector2(110, 0)
	return c


func _boton_sitio(texto: String, x: float, z: float) -> Button:
	var b: Button = UI.boton(texto, func() -> void: _ir(x, z), "BotonSuave")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	return b


# Del clic en el mapa (0..1) a metros del mundo.
func _a_mundo(local: Vector2) -> Vector2:
	var f: Vector2 = (local / _px).clamp(Vector2.ZERO, Vector2.ONE)
	var lado_w: float = GeneradorMundo.MITAD * 2.0
	return Vector2(f.x * lado_w - GeneradorMundo.MITAD, f.y * lado_w - GeneradorMundo.MITAD)


func _a_pantalla(p: Vector3) -> Vector2:
	var lado_w: float = GeneradorMundo.MITAD * 2.0
	return Vector2((p.x + GeneradorMundo.MITAD) / lado_w, (p.z + GeneradorMundo.MITAD) / lado_w) * _px


func _clic_mapa(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion:
		var m: Vector2 = _a_mundo((evento as InputEventMouseMotion).position)
		_coords.text = "X %d   Z %d   (clic para ir)" % [int(m.x), int(m.y)]
	elif evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		var m2: Vector2 = _a_mundo((evento as InputEventMouseButton).position)
		_x.value = snappedf(m2.x, 1.0)
		_z.value = snappedf(m2.y, 1.0)
		_ir(m2.x, m2.y)


func _dibujar() -> void:
	if jugador == null:
		return
	var p: Vector2 = _a_pantalla(jugador.global_position)
	_marcas.draw_circle(p, 7.0, Color(0, 0, 0))
	_marcas.draw_circle(p, 5.0, Color(0.3, 0.8, 1.0))


# Lleva al jugador a (x, z). El suelo del trozo de destino puede tardar un instante en cargar:
# GestorTrozos._vigilar_suelo rescata al jugador si cae por debajo del terreno.
func _ir(x: float, z: float) -> void:
	if jugador == null:
		return
	var lim: float = GeneradorMundo.MITAD - 3.0
	x = clampf(x, -lim, lim)
	z = clampf(z, -lim, lim)
	if "vehiculo" in jugador and jugador.vehiculo != null:
		Juego.avisar("Baja del vehículo antes de teletransportarte.")
		return
	var y: float = 1.5
	if not GeneradorMundo.nucleo.has_point(Vector2(x, z)):
		y = maxf(GeneradorMundo.altura(x, z), 0.0) + 2.0
	jugador.global_position = Vector3(x, y, z)
	if "velocity" in jugador:
		jugador.set("velocity", Vector3.ZERO)
	Juego.avisar("Teletransportado a X %d, Z %d." % [int(x), int(z)])
	# Cierra también el panel de administrador que la abrió, para volver al juego.
	cerrar_raiz()
