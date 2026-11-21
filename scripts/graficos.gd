# graficos.gd  (autoload "Graficos")
# -----------------------------------------------------------------------------
# Opciones gráficas del juego: guardado en user://ajustes.cfg y aplicado al
# arrancar. Se cambian desde el menú de pausa (Esc > Gráficos) o desde el menú
# de inicio. F3 enseña u oculta el contador de FPS.
#
# CÓMO ENGANCHA: casi todo se hace "por fuera". Este script escucha cada nodo
# que entra en el árbol (node_added) y, si es el entorno, el sol, un árbol
# instanciado (MultiMesh), el gestor de trozos... le aplica el ajuste. Así el
# resto del juego casi no necesita saber que existe.
#
# RENDERIZADORES: el juego va por defecto en "Compatibilidad" (ligero, vale
# para equipos modestos). Con "Forward+" se desbloquean SSAO, SSR, niebla
# volumétrica, SDFGI, TAA y FSR 2. El renderizador no se puede cambiar con el
# juego en marcha: el ajuste se guarda y el juego se relanza a sí mismo con
# --rendering-method (ver _relanzar_si_hace_falta).
# -----------------------------------------------------------------------------
extends Node

const ARCHIVO: String = "user://ajustes.cfg"

const SOMBRAS: Array = ["Sin sombras", "Baja", "Media", "Alta", "Ultra"]
const ATLAS_SOL: Array = [512, 1024, 2048, 4096, 8192]
const ATLAS_LUCES: Array = [1024, 1024, 2048, 4096, 4096]
const FILTRO_SOMBRA: Array = [0, 1, 2, 3, 5]   # RenderingServer.ShadowQuality
const DIST_SOMBRA: Array = [1.0, 0.55, 0.85, 1.0, 1.7]   # Multiplica la distancia de sombra de cada luz.
const DIST_DIBUJADO: Array = [0.35, 0.6, 1.0, 1.5, 2.0]
const NOM_DIST: Array = ["Muy corta", "Corta", "Normal", "Larga", "Máxima"]
const TROZOS_CERCA: Array = [2.5, 3.5, 4.5, 6.0]
const TROZOS_LEJOS: Array = [2.0, 3.0, 4.5, 6.0]
const NOM_TROZOS: Array = ["Mínima", "Media", "Normal", "Alta"]
const DENSIDAD_VEG: Array = [0.0, 0.25, 0.5, 0.75, 1.0]
const NOM_VEG: Array = ["Ninguna", "Poca", "Media", "Alta", "Máxima"]
const DENSIDAD_GENTE: Array = [0.0, 0.4, 0.7, 1.0, 1.6]
const NOM_GENTE: Array = ["Ninguna", "Poca", "Media", "Normal", "Mucha"]
const NOM_AA: Array = ["Sin antialiasing", "FXAA", "MSAA 2x", "MSAA 4x", "MSAA 8x", "TAA (Forward+)"]
const NOM_ESCALADO: Array = ["Bilineal", "FSR 1", "FSR 2 (Forward+)"]
const NOM_VSYNC: Array = ["Desactivada", "Activada", "Adaptativa", "Buzón (baja latencia)"]
const LIMITES_FPS: Array = [0, 30, 60, 90, 120, 144, 165, 240]
const NOM_MODO: Array = ["Ventana", "Pantalla completa (sin bordes)", "Pantalla completa (exclusiva)"]
const RESOLUCIONES: Array = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
		Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160)]

# Valores por defecto = lo que el juego ya hacía (así nada cambia al actualizar).
const BASE: Dictionary = {
	"preset": "Alto", "renderizador": "compat",
	"modo_ventana": 1, "resolucion": "1920x1080", "vsync": 1, "fps_max": 0,
	"sombras": 3, "dist_dibujado": 2, "trozos": 2, "vegetacion": 4, "peatones": 3, "trafico": 3,
	"aa": 1, "ssao": true, "ssr": false, "glow": true, "niebla_vol": false, "sdfgi": false,
	"escalado": 0, "escala": 1.0, "fov": 70.0, "brillo": 1.0, "contador_fps": false,
}

# Las opciones de calidad que fija cada preset (las demás —ventana, vsync, FOV...— no se tocan).
const PRESETS: Dictionary = {
	"Bajo": {"sombras": 0, "dist_dibujado": 0, "trozos": 0, "vegetacion": 1, "peatones": 1, "trafico": 1,
			"aa": 0, "ssao": false, "ssr": false, "glow": false, "niebla_vol": false, "sdfgi": false,
			"escalado": 0, "escala": 0.75},
	"Medio": {"sombras": 2, "dist_dibujado": 1, "trozos": 1, "vegetacion": 2, "peatones": 2, "trafico": 2,
			"aa": 1, "ssao": false, "ssr": false, "glow": true, "niebla_vol": false, "sdfgi": false,
			"escalado": 0, "escala": 1.0},
	"Alto": {"sombras": 3, "dist_dibujado": 2, "trozos": 2, "vegetacion": 4, "peatones": 3, "trafico": 3,
			"aa": 1, "ssao": true, "ssr": false, "glow": true, "niebla_vol": false, "sdfgi": false,
			"escalado": 0, "escala": 1.0},
	"Ultra": {"sombras": 4, "dist_dibujado": 3, "trozos": 3, "vegetacion": 4, "peatones": 4, "trafico": 4,
			"aa": 3, "ssao": true, "ssr": true, "glow": true, "niebla_vol": true, "sdfgi": true,
			"escalado": 0, "escala": 1.0},
}

var v: Dictionary = BASE.duplicate()
var forward: bool = false          # ¿Se está usando Forward+ ahora mismo?
var primera_vez: bool = false
var _entornos: Array = []          # WorldEnvironment del juego (no los de miniaturas).
var _luces: Array = []
var _gestores: Array = []
var _capa_fps: CanvasLayer
var _etiqueta_fps: Label
var _t_fps: float = 0.0
var _guardado_pendiente: bool = false
var _sin_ventana: bool = false      # Pruebas con --windowed/--position: no tocar la ventana.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	forward = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	var args: PackedStringArray = OS.get_cmdline_args()
	# Las pruebas automáticas pasan --sin-ventana (después de "--") para que no se toque la ventana.
	_sin_ventana = OS.get_cmdline_user_args().has("--sin-ventana") or DisplayServer.get_name() == "headless"
	_cargar()
	if _relanzar_si_hace_falta():
		return
	get_tree().node_added.connect(_nodo_nuevo)
	aplicar_todo()
	_crear_contador()


# ----------------------------------------------------------------- lectura / guardado

func _cargar() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(ARCHIVO) != OK:
		primera_vez = true
		_por_hardware()
		return
	for k in BASE:
		if cfg.has_section_key("graficos", k):
			var x: Variant = cfg.get_value("graficos", k)
			if typeof(x) == typeof(BASE[k]) or (typeof(BASE[k]) == TYPE_FLOAT and typeof(x) == TYPE_INT):
				v[k] = x


# La primera vez, un equipo con gráfica integrada o muy antigua arranca en "Bajo".
func _por_hardware() -> void:
	var nombre: String = RenderingServer.get_video_adapter_name().to_lower()
	for s in ["intel", "uhd", "iris", "vega", "radeon graphics", "llvmpipe", "swiftshader", "microsoft basic"]:
		if nombre.contains(s):
			aplicar_preset("Bajo", false)
			return


func guardar() -> void:
	if _guardado_pendiente:
		return
	_guardado_pendiente = true
	get_tree().create_timer(0.4).timeout.connect(_guardar_ya)


func _guardar_ya() -> void:
	_guardado_pendiente = false
	var cfg: ConfigFile = ConfigFile.new()
	for k in v:
		cfg.set_value("graficos", k, v[k])
	cfg.save(ARCHIVO)


# ------------------------------------------------------------------- cambiar ajustes

func poner(clave: String, valor: Variant, marcar_personalizado: bool = true) -> void:
	v[clave] = valor
	if marcar_personalizado and clave in PRESETS["Bajo"]:
		v["preset"] = "Personalizado"
	aplicar_todo()
	guardar()


func aplicar_preset(nombre: String, aplicar: bool = true) -> void:
	if not PRESETS.has(nombre):
		return
	for k in PRESETS[nombre]:
		v[k] = PRESETS[nombre][k]
	v["preset"] = nombre
	if aplicar:
		aplicar_todo()
		guardar()


# Lo que cada preset pide pero este equipo/renderizador no puede dar (para avisar en el menú).
func disponible(clave: String) -> bool:
	if clave in ["ssao", "ssr", "niebla_vol", "sdfgi"]:
		return forward
	return true


func quiere_forward() -> bool:
	return String(v["renderizador"]) == "forward"


func _relanzar_si_hace_falta() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--sin-ventana") or args.has("--ajustes-sin-relanzar"):
		return false   # Pruebas, o ya se relanzó una vez: nunca en bucle.
	if quiere_forward() == forward:
		return false
	reiniciar()
	return true


# Se vuelve a abrir el juego con el renderizador elegido y se cierra este.
func reiniciar() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	var nuevos: PackedStringArray = PackedStringArray()
	var ya_hay_guiones: bool = false
	if not OS.has_feature("template"):   # Desde el editor o con --path: el juego se abre con la misma carpeta.
		nuevos.append("--path")
		nuevos.append(ProjectSettings.globalize_path("res://"))
	for a in args:
		if a == "--":
			ya_hay_guiones = true
		nuevos.append(a)
	nuevos.append("--rendering-method")
	nuevos.append("forward_plus" if quiere_forward() else "gl_compatibility")
	if not ya_hay_guiones:
		nuevos.append("--")
	nuevos.append("--ajustes-sin-relanzar")
	_guardar_ya()
	OS.create_process(OS.get_executable_path(), nuevos)
	get_tree().quit()


# ---------------------------------------------------------------------- aplicar todo

func aplicar_todo() -> void:
	_aplicar_ventana()
	_aplicar_viewport()
	_aplicar_sombras_globales()
	for e in _entornos.duplicate():
		if is_instance_valid(e):
			_aplicar_entorno(e)
		else:
			_entornos.erase(e)
	for l in _luces.duplicate():
		if is_instance_valid(l):
			_aplicar_luz(l)
		else:
			_luces.erase(l)
	for g in _gestores.duplicate():
		if is_instance_valid(g):
			_aplicar_gestor(g)
		else:
			_gestores.erase(g)
	_aplicar_distancia_a_todos()
	_aplicar_camara()
	if _etiqueta_fps != null:
		_capa_fps.visible = bool(v["contador_fps"])


func _aplicar_ventana() -> void:
	var modos: Array = [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN,
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	DisplayServer.window_set_vsync_mode([DisplayServer.VSYNC_DISABLED, DisplayServer.VSYNC_ENABLED,
			DisplayServer.VSYNC_ADAPTIVE, DisplayServer.VSYNC_MAILBOX][int(v["vsync"])])
	Engine.max_fps = int(v["fps_max"])
	if _sin_ventana:
		return
	if primera_vez and v["preset"] == BASE["preset"] and int(v["modo_ventana"]) == int(BASE["modo_ventana"]):
		return   # Primer arranque: se deja la ventana como la pone project.godot.
	var modo: int = int(v["modo_ventana"])
	if modo == 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var r: Vector2i = resolucion()
		var pantalla: Vector2i = DisplayServer.screen_get_size()
		DisplayServer.window_set_size(Vector2i(mini(r.x, pantalla.x), mini(r.y, pantalla.y)))
		DisplayServer.window_set_position(DisplayServer.screen_get_position()
				+ (pantalla - DisplayServer.window_get_size()) / 2)
	else:
		DisplayServer.window_set_mode(modos[modo])


func resolucion() -> Vector2i:
	var partes: PackedStringArray = String(v["resolucion"]).split("x")
	if partes.size() == 2:
		return Vector2i(int(partes[0]), int(partes[1]))
	return Vector2i(1920, 1080)


func _aplicar_viewport() -> void:
	var vp: Viewport = get_tree().root
	var aa: int = int(v["aa"])
	if not forward:
		if aa == 1:
			aa = 2   # FXAA y TAA no existen en Compatibilidad: se usa MSAA 2x en su lugar.
		elif aa == 5:
			aa = 3
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if (aa == 1 and forward) else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X,
			Viewport.MSAA_8X, Viewport.MSAA_DISABLED][aa]
	vp.use_taa = aa == 5 and forward
	var esc: int = int(v["escalado"])
	if esc == 2 and not forward:
		esc = 1
	var escala: float = float(v["escala"])
	if absf(escala - 1.0) < 0.01 and esc == 0:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
	else:
		vp.scaling_3d_mode = [Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR,
				Viewport.SCALING_3D_MODE_FSR2][esc]
		vp.scaling_3d_scale = clampf(escala, 0.25, 2.0)
	vp.fsr_sharpness = 0.5


func _aplicar_sombras_globales() -> void:
	var n: int = int(v["sombras"])
	var vp: Viewport = get_tree().root
	RenderingServer.directional_shadow_atlas_set_size(ATLAS_SOL[n], true)
	vp.positional_shadow_atlas_size = ATLAS_LUCES[n]
	RenderingServer.directional_soft_shadow_filter_set_quality(FILTRO_SOMBRA[n])
	RenderingServer.positional_soft_shadow_filter_set_quality(FILTRO_SOMBRA[n])


func _aplicar_entorno(we: WorldEnvironment) -> void:
	var e: Environment = we.environment
	if e == null:
		return
	e.glow_enabled = bool(v["glow"])
	e.ssao_enabled = bool(v["ssao"]) and forward
	e.ssr_enabled = bool(v["ssr"]) and forward
	e.sdfgi_enabled = bool(v["sdfgi"]) and forward
	e.volumetric_fog_enabled = bool(v["niebla_vol"]) and forward
	if e.volumetric_fog_enabled:
		e.volumetric_fog_density = 0.004
		e.volumetric_fog_length = 100.0
		e.volumetric_fog_albedo = Color(0.85, 0.88, 0.95)
	e.adjustment_enabled = true
	e.adjustment_brightness = float(v["brillo"]) * (0.9 if forward else 1.0)
	if forward:
		# Forward+ pinta la misma escena más clara y desvaída que Compatibilidad: se compensa con contraste y color.
		e.adjustment_contrast = 1.2
		e.adjustment_saturation = 1.3


func _aplicar_luz(l: DirectionalLight3D) -> void:
	if not l.has_meta("g_sombra"):
		l.set_meta("g_sombra", l.shadow_enabled)
		l.set_meta("g_dist", l.directional_shadow_max_distance)
	var n: int = int(v["sombras"])
	l.shadow_enabled = bool(l.get_meta("g_sombra")) and n > 0
	l.directional_shadow_max_distance = float(l.get_meta("g_dist")) * float(DIST_SOMBRA[n])


func _aplicar_gestor(g: Node) -> void:
	g.RADIO_CERCA = TROZOS_CERCA[int(v["trozos"])]
	g.RADIO_LEJOS = TROZOS_LEJOS[int(v["trozos"])]


# Distancia de dibujado: cuánto se ven los árboles y objetos con alcance propio.
func _aplicar_distancia(g: GeometryInstance3D) -> void:
	if not g.has_meta("g_vr"):
		if g.visibility_range_end < 60.0:
			return
		g.set_meta("g_vr", g.visibility_range_end)
	g.visibility_range_end = float(g.get_meta("g_vr")) * float(DIST_DIBUJADO[int(v["dist_dibujado"])])


func _aplicar_distancia_a_todos() -> void:
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		_aplicar_distancia(n as GeometryInstance3D)


# FOV y distancia máxima de la cámara del jugador. El juego pone 70 (y 22 con el zoom del
# francotirador): solo se toca la cámara si no está en zoom.
func _aplicar_camara() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	cam.far = maxf(400.0, 4000.0 * float(DIST_DIBUJADO[int(v["dist_dibujado"])]))
	if cam.fov > 40.0:
		cam.fov = float(v["fov"])


func _nodo_nuevo(n: Node) -> void:
	if n is GeometryInstance3D:
		_aplicar_distancia(n)
	elif n is WorldEnvironment:
		if n.get_viewport() == get_tree().root:
			_entornos.append(n)
			_aplicar_entorno(n)
	elif n is DirectionalLight3D:
		if n.get_viewport() == get_tree().root:
			_luces.append(n)
			_aplicar_luz(n)
	elif n is GestorTrozos:
		_gestores.append(n)
		_aplicar_gestor(n)


# ------------------------------------------------------------------------- utilidades

func factor_peatones() -> float:
	return float(DENSIDAD_GENTE[int(v["peatones"])])


func factor_trafico() -> float:
	return float(DENSIDAD_GENTE[int(v["trafico"])])


func factor_vegetacion() -> float:
	return float(DENSIDAD_VEG[int(v["vegetacion"])])


# Vuelve a generar los trozos cercanos (para que se noten los cambios de vegetación).
func recargar_mundo() -> void:
	for g in _gestores:
		if is_instance_valid(g):
			g.recargar()


func nombre_renderizador() -> String:
	return "Forward+" if forward else "Compatibilidad"


# ---------------------------------------------------------------------- contador FPS

func _crear_contador() -> void:
	_capa_fps = CanvasLayer.new()
	_capa_fps.layer = 128
	_capa_fps.visible = bool(v["contador_fps"])
	add_child(_capa_fps)
	_etiqueta_fps = Label.new()
	_etiqueta_fps.position = Vector2(12, 8)
	_etiqueta_fps.add_theme_font_size_override("font_size", 18)
	_etiqueta_fps.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	_etiqueta_fps.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_etiqueta_fps.add_theme_constant_override("outline_size", 5)
	_capa_fps.add_child(_etiqueta_fps)


func _process(delta: float) -> void:
	_t_fps -= delta
	if _t_fps > 0.0 or _etiqueta_fps == null:
		return
	_t_fps = 0.25
	_aplicar_camara()   # Por si el jugador cambió de cámara (coche, aspecto...).
	if _capa_fps.visible:
		_etiqueta_fps.text = "%d FPS  ·  %.1f ms  ·  %d llamadas  ·  %s" % [Engine.get_frames_per_second(),
				1000.0 / maxf(1.0, Engine.get_frames_per_second()),
				int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
				nombre_renderizador()]


func _unhandled_key_input(evento: InputEvent) -> void:
	var k: InputEventKey = evento as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F3:
		poner("contador_fps", not bool(v["contador_fps"]), false)
		get_viewport().set_input_as_handled()
