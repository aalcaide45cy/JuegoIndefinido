# mapa_grande.gd
# -----------------------------------------------------------------------------
# El mapa de la ciudad a pantalla completa (tecla N). Norte siempre arriba.
# Usa una cámara cenital propia (como el minimapa), pone los nombres de las
# tiendas y casas (grupo "poi") y la flecha del jugador. Se cierra con N, M o Esc.
# SIN PROBAR en Godot.
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

	var tam: Vector2 = get_viewport_rect().size
	_px = minf(tam.x - 80.0, tam.y - 110.0)
	var marco: PanelContainer = Hud.crear_panel()
	Hud.centrar(marco, Vector2(_px + 40.0, _px + 80.0))
	add_child(marco)
	var caja: VBoxContainer = VBoxContainer.new()
	marco.add_child(caja)
	cabecera(caja, "Mapa de la ciudad  (N o Esc para cerrar)")
	var vista: TextureRect = TextureRect.new()
	vista.texture = _vp.get_texture()
	vista.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vista.stretch_mode = TextureRect.STRETCH_SCALE
	vista.custom_minimum_size = Vector2(_px, _px)
	caja.add_child(vista)
	_marcas = Control.new()
	_marcas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marcas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marcas.draw.connect(_dibujar.bind(vista))
	vista.add_child(_marcas)


func _process(_delta: float) -> void:
	if _marcas != null:
		_marcas.queue_redraw()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("mapa_grande") or evento.is_action_pressed("mapa"):
		cerrar()
		get_viewport().set_input_as_handled()


func _a_pantalla(p: Vector3) -> Vector2:
	return Vector2((p.x - _centro.x) / _lado_m + 0.5, (p.z - _centro.z) / _lado_m + 0.5) * _px


func _dibujar(vista: Control) -> void:
	var fuente: Font = ThemeDB.fallback_font
	for nodo in get_tree().get_nodes_in_group("poi"):
		var poi: Node3D = nodo as Node3D
		var c: Vector2 = _a_pantalla(poi.global_position)
		var color: Color = poi.get_meta("poi_color", Color.WHITE)
		_marcas.draw_circle(c, 7.0, Color(0, 0, 0, 0.85))
		_marcas.draw_circle(c, 5.0, color)
		var nombre: String = str(poi.get_meta("poi_nombre", ""))
		_marcas.draw_string_outline(fuente, c + Vector2(9, 5), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.9))
		_marcas.draw_string(fuente, c + Vector2(9, 5), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1))
	if jugador != null and is_instance_valid(jugador):
		var c: Vector2 = _a_pantalla(jugador.global_position)
		var giro: float = jugador._giro
		var avance: Vector2 = Vector2(-sin(giro), -cos(giro))
		var lado: Vector2 = Vector2(-avance.y, avance.x)
		var flecha: PackedVector2Array = PackedVector2Array([c + avance * 12.0,
				c - avance * 8.0 + lado * 8.0, c - avance * 3.0, c - avance * 8.0 - lado * 8.0])
		_marcas.draw_colored_polygon(flecha, Color(1, 1, 1))
		_marcas.draw_polyline(PackedVector2Array([flecha[0], flecha[1], flecha[2], flecha[3], flecha[0]]),
				Color(0, 0, 0, 0.9), 2.0, true)
	_marcas.draw_string(fuente, Vector2(_px / 2.0 - 6.0, 18.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.45, 0.4))
