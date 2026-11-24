# mapa_grande.gd
# -----------------------------------------------------------------------------
# El mapa de la ciudad a pantalla completa (tecla N). Norte siempre arriba.
# Usa una cámara cenital propia (como el minimapa), pone los nombres de las
# tiendas y casas (grupo "poi") y la flecha del jugador. Se cierra con N, M o Esc.
# El jugador se ve con halo que late, flecha amarilla y etiqueta TÚ (también fuera de la ciudad).
# -----------------------------------------------------------------------------
class_name MapaGrande
extends Ventana

const LADO_VISTA: int = 1024

var jugador: Jugador
var _vp: SubViewport
var _marcas: Control
var _centro: Vector3 = Vector3.ZERO
var _lado_m: float = 300.0
var _px: float = 700.0   # Lado del mapa en pantalla.
var _vista: TextureRect
var _modo_mundo: bool = false   # Z: cambia entre la ciudad y el mundo entero (10 km).
var _tex_mundo: ImageTexture
var _modos: UI.Filtros
var _categorias: UI.Filtros
var _lista: VBoxContainer
var _cuenta: Label
var _texto: String = ""
var _firma_cats: String = ""
var _destacado: Vector3 = Vector3.ZERO
var _destacado_hasta: int = 0   # Hasta cuándo (ms) late el aro del lugar elegido.


func construir() -> void:
	# Límites: todos los puntos de interés más un margen.
	var minimo: Vector2 = Vector2(INF, INF)
	var maximo: Vector2 = Vector2(-INF, -INF)
	for nodo in get_tree().get_nodes_in_group("poi"):
		var p: Vector3 = (nodo as Node3D).global_position
		minimo = Vector2(minf(minimo.x, p.x), minf(minimo.y, p.z))
		maximo = Vector2(maxf(maximo.x, p.x), maxf(maximo.y, p.z))
	if minimo.x == INF:
		minimo = Vector2(-60, -60)
		maximo = Vector2(60, 60)
	_centro = Vector3((minimo.x + maximo.x) / 2.0, 0.0, (minimo.y + maximo.y) / 2.0)
	_lado_m = maxf(maximo.x - minimo.x, maximo.y - minimo.y) + 70.0

	_vp = SubViewport.new()
	_vp.size = Vector2i(LADO_VISTA, LADO_VISTA)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_vp)
	var camara: Camera3D = Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = _lado_m
	camara.near = 1.0
	camara.far = 300.0
	var entorno: Environment = Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color(0.06, 0.07, 0.09)
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(1, 1, 1)
	entorno.ambient_light_energy = 1.1
	entorno.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	camara.environment = entorno
	_vp.add_child(camara)
	camara.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0),
			Vector3(_centro.x, 90.0, _centro.z))

	_px = 520.0
	pistas_extra = [["z", "Ciudad / mundo entero"]]
	var cuerpo: VBoxContainer = marco("Mapa", "Norte siempre arriba", Vector2(1080, 660))
	var columnas: HBoxContainer = HBoxContainer.new()
	columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columnas.add_theme_constant_override("separation", 18)
	cuerpo.add_child(columnas)
	var vista: TextureRect = TextureRect.new()
	vista.texture = _vp.get_texture()
	vista.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vista.stretch_mode = TextureRect.STRETCH_SCALE
	vista.custom_minimum_size = Vector2(_px, _px)
	vista.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vista.clip_contents = true
	columnas.add_child(vista)
	_vista = vista
	_marcas = Control.new()
	_marcas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marcas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marcas.draw.connect(_dibujar.bind(vista))
	vista.add_child(_marcas)
	_montar_lateral(columnas)
	# Si el jugador está lejos de la ciudad no saldría en este mapa: se abre directamente
	# el mapa del mundo entero, donde siempre se le ve.
	if jugador != null and is_instance_valid(jugador) and not _dentro_vista(_a_pantalla(jugador.global_position)):
		_cambiar_modo()
	else:
		_rellenar_lista()


# Columna de la derecha: modo (ciudad / mundo), buscador, categorías y lista de lugares.
func _montar_lateral(columnas: HBoxContainer) -> void:
	var lado: VBoxContainer = VBoxContainer.new()
	lado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lado.add_theme_constant_override("separation", 8)
	columnas.add_child(lado)
	_modos = UI.Filtros.new()
	_modos.anadir("ciudad", "Ciudad")
	_modos.anadir("mundo", "Mundo entero (10 km)")
	_modos.cambiado.connect(func(c: String) -> void:
		if (c == "mundo") != _modo_mundo:
			_cambiar_modo())
	lado.add_child(_modos)
	lado.add_child(UI.buscador("Buscar un lugar…", func(t: String) -> void:
		_texto = t
		_rellenar_lista()))
	_categorias = UI.Filtros.new()
	lado.add_child(_categorias)
	_categorias.cambiado.connect(func(_c: String) -> void: _rellenar_lista())
	var cab: HBoxContainer = HBoxContainer.new()
	cab.add_child(UI.seccion("Lugares"))
	cab.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cuenta = UI.etiqueta("", "Nota")
	cab.add_child(_cuenta)
	lado.add_child(cab)
	var desplazable: ScrollContainer = ScrollContainer.new()
	desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desplazable.follow_focus = true
	lado.add_child(desplazable)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 3)
	desplazable.add_child(_lista)
	lado.add_child(UI.nota("Elige un lugar para marcarlo en el mapa. Tú eres la flecha amarilla."))


# Categoría de un lugar de la ciudad (por su nombre).
static func categoria_poi(nombre: String) -> String:
	var n: String = nombre.to_lower()
	if n.begins_with("comprador"):
		return "Encargos"
	for k in ["banco", "médico", "medico", "hospital", "comisar", "gasoliner", "taller", "academia", "bolsa", "concesion", "taxi", "peluquer", "barber", "casino"]:
		if n.contains(k):
			return "Servicios"
	for k in ["casa", "alquiler", "inmobil", "huerto", "granja", "corral", "piso"]:
		if n.contains(k):
			return "Propiedades"
	return "Tiendas y locales"


# Todos los sitios del modo actual: [{"nombre", "pos" (Vector3), "cat", "color", "dist"}].
func _lugares() -> Array:
	var origen: Vector3 = jugador.global_position if jugador != null and is_instance_valid(jugador) else _centro
	var res: Array = []
	if _modo_mundo:
		for a in GeneradorMundo.todos_asentamientos():
			if int(a["tipo"]) <= 0:
				continue
			var pos: Vector3 = Vector3(a["pos"].x, 0.0, a["pos"].y)
			res.append({"nombre": "%s %s" % [GeneradorMundo.nombre_tipo(int(a["tipo"])), a["nombre"]], "pos": pos,
					"cat": GeneradorMundo.nombre_tipo(int(a["tipo"])), "color": Color(1, 0.85, 0.4), "dist": origen.distance_to(pos)})
	else:
		for nodo in get_tree().get_nodes_in_group("poi"):
			var poi: Node3D = nodo as Node3D
			var nombre: String = str(poi.get_meta("poi_nombre", ""))
			if nombre == "":
				continue
			res.append({"nombre": nombre, "pos": poi.global_position, "cat": categoria_poi(nombre),
					"color": poi.get_meta("poi_color", Color.WHITE), "dist": origen.distance_to(poi.global_position)})
	res.sort_custom(func(a, b) -> bool: return float(a["dist"]) < float(b["dist"]))
	return res


func _rellenar_lista() -> void:
	var todos: Array = _lugares()
	# Las categorías se rehacen si cambia el modo (o la primera vez).
	var cats: Array = []
	for l in todos:
		if not cats.has(l["cat"]):
			cats.append(l["cat"])
	cats.sort()
	var firma: String = ",".join(PackedStringArray(cats))
	if firma != _firma_cats:
		_firma_cats = firma
		for h in _categorias.get_children():
			_categorias.remove_child(h)
			h.queue_free()
		_categorias._chips.clear()
		_categorias.clave = ""
		_categorias.anadir("todo", "Todo")
		for c in cats:
			_categorias.anadir(str(c), str(c))
	for h in _lista.get_children():
		_lista.remove_child(h)
		h.queue_free()
	var n: int = 0
	for l in todos:
		if _categorias.clave != "todo" and l["cat"] != _categorias.clave:
			continue
		if _texto != "" and not str(l["nombre"]).to_lower().contains(_texto):
			continue
		_lista.add_child(_fila_lugar(l))
		n += 1
	_cuenta.text = "%d de %d" % [n, todos.size()]
	if n == 0:
		_lista.add_child(UI.nota("Ningún lugar coincide."))


func _fila_lugar(l: Dictionary) -> Control:
	var d: float = float(l["dist"])
	var texto: String = "%.1f km" % (d / 1000.0) if d >= 1000.0 else "%d m" % int(d)
	var b: Button = UI.boton("", func() -> void:
		_destacado = Vector3(l["pos"])
		_destacado_hasta = Time.get_ticks_msec() + 6000, "BotonSuave")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var fila: HBoxContainer = HBoxContainer.new()
	fila.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fila.offset_left = 10
	fila.offset_right = -10
	fila.add_theme_constant_override("separation", 8)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(fila)
	b.custom_minimum_size.y = 34
	var punto: ColorRect = ColorRect.new()
	punto.color = Color(l["color"])
	punto.custom_minimum_size = Vector2(10, 10)
	punto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(punto)
	var nombre: Label = UI.etiqueta(str(l["nombre"]), "", Tema.TEXTO, 15)
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre.clip_text = true
	fila.add_child(nombre)
	fila.add_child(UI.etiqueta(texto, "Nota"))
	return b


func _process(_delta: float) -> void:
	if _marcas != null:
		_marcas.queue_redraw()


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_Z:
		_cambiar_modo()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("mapa_grande") or evento.is_action_pressed("mapa"):
		cerrar()
		get_viewport().set_input_as_handled()


# Cambia entre la vista de la ciudad (cámara cenital) y el dibujo del mundo entero.
func _cambiar_modo() -> void:
	_modo_mundo = not _modo_mundo
	_modos.elegir("mundo" if _modo_mundo else "ciudad")
	_destacado_hasta = 0
	_rellenar_lista()
	if _modo_mundo:
		if _tex_mundo == null:
			_tex_mundo = ImageTexture.create_from_image(GeneradorMundo.imagen_mapa(256))
		_vista.texture = _tex_mundo
	else:
		_vista.texture = _vp.get_texture()


func _a_pantalla(p: Vector3) -> Vector2:
	if _modo_mundo:
		var lado_w: float = GeneradorMundo.MITAD * 2.0
		return Vector2((p.x + GeneradorMundo.MITAD) / lado_w, (p.z + GeneradorMundo.MITAD) / lado_w) * _px
	return Vector2((p.x - _centro.x) / _lado_m + 0.5, (p.z - _centro.z) / _lado_m + 0.5) * _px


func _dibujar_mundo() -> void:
	var fuente: Font = Tema.fuente("semibold")
	for a in GeneradorMundo.todos_asentamientos():
		var c: Vector2 = _a_pantalla(Vector3(a["pos"].x, 0.0, a["pos"].y))
		var nombre: String = "%s %s" % [GeneradorMundo.nombre_tipo(int(a["tipo"])), a["nombre"]]
		if int(a["tipo"]) > 0:
			_marcas.draw_string_outline(fuente, c + Vector2(8, 4), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
			_marcas.draw_string(fuente, c + Vector2(8, 4), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1))
	var ciudad: Vector2 = _a_pantalla(Vector3(100.0, 0.0, 0.0))
	_marcas.draw_string_outline(fuente, ciudad + Vector2(-70, -12), "Ciudad original", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.9))
	_marcas.draw_string(fuente, ciudad + Vector2(-70, -12), "Ciudad original", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.85, 0.4))
	_dibujar_destacado()
	_dibujar_jugador()
	_marcas.draw_string(fuente, Vector2(_px / 2.0 - 6.0, 18.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.45, 0.4))


func _dibujar(vista: Control) -> void:
	if _modo_mundo:
		_dibujar_mundo()
		return
	var fuente: Font = Tema.fuente("semibold")
	for nodo in get_tree().get_nodes_in_group("poi"):
		var poi: Node3D = nodo as Node3D
		var c: Vector2 = _a_pantalla(poi.global_position)
		var color: Color = poi.get_meta("poi_color", Color.WHITE)
		if bool(poi.get_meta("poi_grande", false)):
			var r: float = 13.0 + 3.0 * sin(Time.get_ticks_msec() / 160.0)
			_marcas.draw_circle(c, r + 3.0, Color(0, 0, 0, 0.9))
			_marcas.draw_circle(c, r, Color(1.0, 0.55, 0.1))
			_marcas.draw_circle(c, r * 0.4, Color(1, 1, 1))
			color = Color(1.0, 0.85, 0.5)
		else:
			_marcas.draw_circle(c, 7.0, Color(0, 0, 0, 0.85))
			_marcas.draw_circle(c, 5.0, color)
		var nombre: String = str(poi.get_meta("poi_nombre", ""))
		_marcas.draw_string_outline(fuente, c + Vector2(9, 5), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
		_marcas.draw_string(fuente, c + Vector2(9, 5), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1))
	_dibujar_destacado()
	_dibujar_jugador()
	_marcas.draw_string(fuente, Vector2(_px / 2.0 - 6.0, 18.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.45, 0.4))


# Un aro que late alrededor del lugar elegido en la lista.
func _dibujar_destacado() -> void:
	if Time.get_ticks_msec() > _destacado_hasta:
		return
	var c: Vector2 = _a_pantalla(_destacado)
	var pulso: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 140.0)
	_marcas.draw_arc(c, 16.0 + 8.0 * pulso, 0.0, TAU, 40, Color(0, 0, 0, 0.9), 5.0, true)
	_marcas.draw_arc(c, 16.0 + 8.0 * pulso, 0.0, TAU, 40, Tema.ACENTO, 3.0, true)


func _dentro_vista(c: Vector2) -> bool:
	return c.x >= 0.0 and c.y >= 0.0 and c.x <= _px and c.y <= _px


# El jugador: un halo que late, una flecha grande amarilla que gira hacia donde mira
# y la etiqueta "TÚ". Si cae fuera del mapa se pega al borde con la distancia.
func _dibujar_jugador() -> void:
	if jugador == null or not is_instance_valid(jugador):
		return
	var fuente: Font = Tema.fuente("semibold")
	var c: Vector2 = _a_pantalla(jugador.global_position)
	var giro: float = jugador._giro
	var avance: Vector2 = Vector2(-sin(giro), -cos(giro))
	var fuera: bool = not _dentro_vista(c)
	var etiqueta: String = "TÚ"
	if fuera:
		var centro: Vector2 = Vector2(_px, _px) / 2.0
		var dir: Vector2 = (c - centro).normalized()
		var m: float = _px / 2.0 - 26.0
		var k: float = m / maxf(absf(dir.x), absf(dir.y))
		var dist: float = jugador.global_position.distance_to(_centro)
		c = centro + dir * k
		avance = dir
		etiqueta = "TÚ (a %.1f km)" % (dist / 1000.0) if dist >= 1000.0 else "TÚ (a %d m)" % int(dist)
	var pulso: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)
	var tam: float = 1.0 if not _modo_mundo else 0.85
	# Halo que late (así se ve aunque la flecha sea pequeña frente al mapa).
	_marcas.draw_circle(c, (24.0 + 8.0 * pulso) * tam, Color(1.0, 0.9, 0.2, 0.18 + 0.12 * pulso))
	_marcas.draw_arc(c, (24.0 + 8.0 * pulso) * tam, 0.0, TAU, 40, Color(0, 0, 0, 0.9), 4.0, true)
	_marcas.draw_arc(c, (24.0 + 8.0 * pulso) * tam, 0.0, TAU, 40, Color(1.0, 0.9, 0.2), 2.0, true)
	var lado: Vector2 = Vector2(-avance.y, avance.x)
	var l: float = 22.0 * tam
	var flecha: PackedVector2Array = PackedVector2Array([c + avance * l,
			c - avance * l * 0.7 + lado * l * 0.7, c - avance * l * 0.25, c - avance * l * 0.7 - lado * l * 0.7])
	_marcas.draw_colored_polygon(flecha, Color(1.0, 0.9, 0.2))
	_marcas.draw_polyline(PackedVector2Array([flecha[0], flecha[1], flecha[2], flecha[3], flecha[0]]),
			Color(0, 0, 0, 0.95), 3.0, true)
	var ancho: float = fuente.get_string_size(etiqueta, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var pos: Vector2 = c + Vector2(-ancho / 2.0, -34.0 * tam)
	pos.x = clampf(pos.x, 4.0, _px - ancho - 4.0)
	pos.y = maxf(pos.y, 20.0)
	_marcas.draw_string_outline(fuente, pos, etiqueta, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Color(0, 0, 0, 1))
	_marcas.draw_string(fuente, pos, etiqueta, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.95, 0.4))
