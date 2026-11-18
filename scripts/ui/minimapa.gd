# minimapa.gd
# -----------------------------------------------------------------------------
# El minimapa redondo de arriba a la derecha, como en los juegos de ciudad.
#
# Cómo funciona: una segunda cámara mira la ciudad desde arriba (vista
# ortogonal, sin perspectiva) y dibuja en un cuadrito pequeño (un SubViewport).
# Ese cuadrito se recorta en círculo con un shader. Encima se pintan la flecha
# del jugador, la "N" del norte y los puntos de interés (tiendas y casas, los
# nodos del grupo "poi", mira Barrio.registrar_poi).
#
# El mapa gira con el jugador: lo que tienes delante está siempre arriba.
# La tecla M cambia el zoom (3 niveles). Debajo del círculo va la hora.
#
# Para no dibujar la ciudad dos veces en cada fotograma, la cámara de arriba
# mira siempre al norte y abarca un poco más de lo que se ve; el giro y los
# pasos pequeños del jugador los hace el shader moviendo la imagen. Solo se
# vuelve a sacar la "foto" cuando te alejas bastante o cada medio segundo.
# -----------------------------------------------------------------------------
class_name Minimapa
extends Control

const DIAMETRO: float = 190.0
const ZOOMS: Array[float] = [70.0, 140.0, 280.0]   # Metros que abarca el círculo.
const ALTURA_CAMARA: float = 90.0
const MARGEN: float = 1.25            # La foto abarca un 25 % más que el círculo.
const DESVIO_MAXIMO: float = 0.07     # Cuánto puede moverse la imagen antes de otra foto.
const INTERVALO_FOTO: float = 0.5     # Segundos máximos entre fotos (luces, guardias...).

const SOMBRA_CIRCULO: String = """
shader_type canvas_item;
uniform float giro = 0.0;
uniform vec2 desplazamiento = vec2(0.0);
uniform float escala = 0.8;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p);
	float s = sin(giro);
	float c = cos(giro);
	vec2 q = vec2(c * p.x + s * p.y, -s * p.x + c * p.y) * escala + vec2(0.5) + desplazamiento;
	vec4 col = texture(TEXTURE, q);
	COLOR = vec4(col.rgb, col.a * (1.0 - smoothstep(0.495, 0.5, d)));
}
"""

var _zoom: int = 0
var _vp: SubViewport
var _camara: Camera3D
var _jugador: Jugador
var _marcas: Control
var _material: ShaderMaterial
var _t_foto: float = 0.0
var _forzar_foto: bool = true


func _ready() -> void:
	custom_minimum_size = Vector2(DIAMETRO, DIAMETRO + 40.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_vp = SubViewport.new()
	_vp.size = Vector2i(256, 256)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.gui_disable_input = true
	add_child(_vp)

	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.size = ZOOMS[0] * MARGEN
	# Siempre mirando hacia abajo con el norte arriba (el giro lo hace el shader).
	_camara.basis = Basis(Vector3.RIGHT, -PI / 2.0)
	_camara.near = 1.0
	_camara.far = 300.0
	# Un entorno propio: luz pareja y clara (de noche también se ve el mapa),
	# sin niebla ni brillo, y un fondo oscuro fuera de la ciudad.
	var entorno: Environment = Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color(0.06, 0.07, 0.09)
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(1, 1, 1)
	entorno.ambient_light_energy = 1.1
	entorno.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_camara.environment = entorno
	_vp.add_child(_camara)

	var vista: TextureRect = TextureRect.new()
	vista.texture = _vp.get_texture()
	# (Primero "expand_mode": si no, el cuadro se queda con el tamaño de la textura,
	# 256, y el mapa se sale del aro.)
	vista.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vista.stretch_mode = TextureRect.STRETCH_SCALE
	vista.custom_minimum_size = Vector2(DIAMETRO, DIAMETRO)
	vista.size = Vector2(DIAMETRO, DIAMETRO)
	vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sombreado: Shader = Shader.new()
	sombreado.code = SOMBRA_CIRCULO
	_material = ShaderMaterial.new()
	_material.shader = sombreado
	_material.set_shader_parameter("escala", 1.0 / MARGEN)
	vista.material = _material
	add_child(vista)

	# Capa de encima: aro, flecha, norte, puntos de interés y la hora.
	_marcas = Control.new()
	_marcas.size = Vector2(DIAMETRO, DIAMETRO + 40.0)
	_marcas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marcas.draw.connect(_dibujar_marcas)
	add_child(_marcas)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("mapa") and not Juego.menu_abierto:
		_zoom = (_zoom + 1) % ZOOMS.size()
		_camara.size = ZOOMS[_zoom] * MARGEN
		_forzar_foto = true


func _process(delta: float) -> void:
	if _jugador == null:
		_jugador = get_tree().get_first_node_in_group("jugador") as Jugador
		if _jugador == null:
			return
	# Si el mapa no se ve (hay una ventana abierta), no gastamos en dibujarlo.
	if not is_visible_in_tree():
		_forzar_foto = true
		return
	var p: Vector3 = _jugador.global_position
	var metros_foto: float = ZOOMS[_zoom] * MARGEN
	# Cuánto se ha movido el jugador desde la última foto (en tamaño de la foto).
	var desvio: Vector2 = Vector2(p.x - _camara.position.x, p.z - _camara.position.z) / metros_foto
	_t_foto -= delta
	if _forzar_foto or _t_foto <= 0.0 or desvio.length() > DESVIO_MAXIMO:
		_forzar_foto = false
		_t_foto = INTERVALO_FOTO
		_camara.position = Vector3(p.x, p.y + ALTURA_CAMARA, p.z)
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		desvio = Vector2.ZERO
	_material.set_shader_parameter("giro", _jugador._giro)
	_material.set_shader_parameter("desplazamiento", desvio)
	_marcas.queue_redraw()


func _dibujar_marcas() -> void:
	if _jugador == null:
		return
	var centro: Vector2 = Vector2(DIAMETRO, DIAMETRO) / 2.0
	var radio: float = DIAMETRO / 2.0
	var radio_m: float = ZOOMS[_zoom] / 2.0
	var giro: float = _jugador._giro
	var derecha: Vector3 = Vector3(cos(giro), 0.0, -sin(giro))
	var delante: Vector3 = Vector3(-sin(giro), 0.0, -cos(giro))
	var fuente: Font = ThemeDB.fallback_font

	# Aro dorado con borde oscuro.
	_marcas.draw_arc(centro, radio + 1.5, 0.0, TAU, 72, Color(0, 0, 0, 0.75), 3.0, true)
	_marcas.draw_arc(centro, radio - 1.5, 0.0, TAU, 72, Color(0.88, 0.74, 0.38), 3.0, true)

	# Puntos de interés: tiendas y casas. Los que quedan lejos se pegan al aro.
	for nodo in get_tree().get_nodes_in_group("poi"):
		var poi: Node3D = nodo as Node3D
		var rel: Vector3 = poi.global_position - _jugador.global_position
		var pos: Vector2 = Vector2(rel.dot(derecha), -rel.dot(delante)) / radio_m * radio
		var color: Color = poi.get_meta("poi_color", Color.WHITE)
		var lejos: bool = pos.length() > radio - 9.0
		if lejos:
			pos = pos.normalized() * (radio - 9.0)
		var grande: bool = bool(poi.get_meta("poi_grande", false))
		var tam: float = 4.0 if lejos else 6.0
		var c: Vector2 = centro + pos
		if grande:
			# Comprador de un encargo: círculo naranja grande que late, con su distancia.
			var latido: float = 1.0 + 0.2 * sin(Time.get_ticks_msec() / 160.0)
			var r: float = 10.0 * latido
			_marcas.draw_circle(c, r + 2.0, Color(0, 0, 0, 0.9))
			_marcas.draw_circle(c, r, Color(1.0, 0.55, 0.1))
			_marcas.draw_circle(c, r * 0.4, Color(1, 1, 1))
			var texto_d: String = "%d m" % int(Vector2(rel.x, rel.z).length())
			_marcas.draw_string_outline(fuente, c + Vector2(-14, -r - 4), texto_d, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
			_marcas.draw_string(fuente, c + Vector2(-14, -r - 4), texto_d, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.85, 0.5))
			continue
		_marcas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -tam - 1), c + Vector2(tam + 1, 0),
				c + Vector2(0, tam + 1), c + Vector2(-tam - 1, 0)]), Color(0, 0, 0, 0.85))
		_marcas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -tam), c + Vector2(tam, 0),
				c + Vector2(0, tam), c + Vector2(-tam, 0)]), color)

	# El norte.
	var dir_norte: Vector2 = Vector2(sin(giro), -cos(giro))
	var pos_n: Vector2 = centro + dir_norte * (radio - 15.0)
	_marcas.draw_circle(pos_n, 9.0, Color(0, 0, 0, 0.7))
	_marcas.draw_string(fuente, pos_n + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(1.0, 0.45, 0.4))

	# La flecha del jugador, siempre apuntando hacia arriba.
	var flecha: PackedVector2Array = PackedVector2Array([centro + Vector2(0, -9), centro + Vector2(7, 8),
			centro + Vector2(0, 4), centro + Vector2(-7, 8)])
	_marcas.draw_colored_polygon(flecha, Color(1, 1, 1))
	_marcas.draw_polyline(PackedVector2Array([flecha[0], flecha[1], flecha[2], flecha[3], flecha[0]]),
			Color(0, 0, 0, 0.9), 1.5, true)

	# La hora, en una pastilla bajo el círculo, con un sol o una luna.
	var pastilla: Rect2 = Rect2(Vector2(DIAMETRO / 2.0 - 75.0, DIAMETRO + 8.0), Vector2(150.0, 28.0))
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(0.05, 0.06, 0.07, 0.8)
	estilo.border_color = Color(0.88, 0.74, 0.38, 0.8)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(14)
	estilo.corner_detail = 1   # Esquina cortada: estilo low poly
	_marcas.draw_style_box(estilo, pastilla)
	var icono: Vector2 = pastilla.position + Vector2(20.0, 14.0)
	if Juego.es_de_noche():
		_marcas.draw_circle(icono, 7.0, Color(0.85, 0.88, 1.0))
		_marcas.draw_circle(icono + Vector2(3.5, -2.5), 6.0, Color(0.05, 0.06, 0.07))
	else:
		_marcas.draw_circle(icono, 5.0, Color(1.0, 0.85, 0.3))
		for k in 8:
			var a: float = k * TAU / 8.0
			_marcas.draw_line(icono + Vector2(cos(a), sin(a)) * 7.0, icono + Vector2(cos(a), sin(a)) * 10.0,
					Color(1.0, 0.85, 0.3), 1.5)
	_marcas.draw_string(fuente, pastilla.position + Vector2(40.0, 19.0), "Día %d  %s" % [Juego.dia, Juego.texto_hora()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.93, 0.8))
