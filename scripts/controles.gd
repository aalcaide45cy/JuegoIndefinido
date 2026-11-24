# controles.gd  (autocarga "Controles")
# -----------------------------------------------------------------------------
# Opciones de control del jugador:
#   - Reasignar teclas: cambiar_tecla("usar", KEY_F). Se guardan en user://controles.cfg.
#   - Sensibilidad del ratón y del mando, e invertir el eje vertical (las lee jugador.gd).
#   - Mando (Xbox, PlayStation, Steam Deck): se añade a las mismas acciones que el teclado,
#     así que todo lo que funciona con teclas funciona con el mando sin tocar cada script.
#     El stick derecho y los gatillos se convierten en movimiento y clics de ratón "de mentira",
#     porque mirar, disparar y apuntar se leen del ratón en jugador.gd.
#
# Mando:
#   Stick izquierdo   andar / conducir         Stick derecho    mirar
#   Gatillo derecho   disparar / golpear       Gatillo izq.     apuntar (zoom)
#   A / Cruz          saltar                   B / Círculo      agacharse
#   X / Cuadrado      usar                     Y / Triángulo    recargar
#   LB / RB           objeto anterior/siguiente
#   Pulsar stick izq. correr                   Pulsar stick der. cambiar cámara
#   Select / Share    móvil                    Start / Options  pausa (y cerrar ventanas)
#   Cruceta: arriba mapa grande, abajo inventario, izquierda montar objeto, derecha esquivar
# -----------------------------------------------------------------------------
extends Node

const RUTA: String = "user://controles.cfg"

signal escala_cambiada   # El Hud la escucha para reajustar el tamaño de la interfaz.

# Las acciones que se pueden reasignar, con su nombre para el menú (en orden de aparición).
const ACCIONES: Array = [
	["adelante", "Adelante"], ["atras", "Atrás"], ["izquierda", "Izquierda"], ["derecha", "Derecha"],
	["correr", "Correr"], ["saltar", "Saltar"], ["agacharse", "Agacharse"], ["esquivar", "Esquivar"],
	["usar", "Usar / hablar / subir al coche"], ["recargar", "Recargar"], ["colocar", "Montar objeto"],
	["enganchar", "Enganchar remolque"], ["cambiar_camara", "Cambiar cámara"],
	["inventario", "Inventario"], ["telefono", "Móvil"], ["mapa_grande", "Mapa grande"],
	["mapa", "Zoom del minimapa"], ["aspecto", "Aspecto (ropa y peinado)"], ["logros", "Logros"],
	["lanzar_hechizo", "Lanzar hechizo"], ["siguiente_hechizo", "Cambiar de hechizo"], ["grimorio", "Grimorio (magia)"],
]

const ZONA_MUERTA: float = 0.18
const VELOCIDAD_MIRAR: float = 1100.0   # Píxeles de ratón por segundo con el stick a tope.

var sensibilidad_raton: float = 1.0     # Multiplica la sensibilidad base (0,2 a 3).
var sensibilidad_mando: float = 1.0
var invertir_y: bool = false
var mando_activo: bool = true
var mostrar_ayuda: bool = true          # La línea de teclas de abajo del HUD.
var escala_interfaz: float = 1.0        # 0,8 a 1,4: tamaño de menús y HUD (lo aplica Hud).

var _por_defecto: Dictionary = {}       # acción -> Array de physical_keycode
var _gatillo_der: bool = false
var _gatillo_izq: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Juego (autocarga anterior) ya creó las acciones con sus teclas: se apuntan como "por defecto".
	for a in ACCIONES:
		_por_defecto[a[0]] = teclas_de(str(a[0]))
	_anadir_mando()
	cargar()


# ------------------------------- Teclas ---------------------------------------

func teclas_de(accion: String) -> Array:
	var out: Array = []
	if not InputMap.has_action(accion):
		return out
	for ev in InputMap.action_get_events(accion):
		if ev is InputEventKey:
			out.append(int((ev as InputEventKey).physical_keycode))
	return out


func nombre_teclas(accion: String) -> String:
	var nombres: PackedStringArray = []
	for k in teclas_de(accion):
		nombres.append(OS.get_keycode_string(k))
	return " / ".join(nombres) if nombres.size() > 0 else "(sin tecla)"


# La tecla nueva sustituye a todas las de esa acción. Si otra acción la usaba, se la quita
# (para que una tecla no haga dos cosas). Devuelve el nombre de la acción que la perdió, o "".
func cambiar_tecla(accion: String, tecla: int, guardar_ya: bool = true) -> String:
	if not InputMap.has_action(accion):
		return ""
	var quitada: String = ""
	for a in ACCIONES:
		var otra: String = str(a[0])
		if otra != accion and tecla in teclas_de(otra):
			_quitar_teclas(otra, [tecla])
			quitada = str(a[1])
	_quitar_teclas(accion, teclas_de(accion))
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = tecla as Key
	InputMap.action_add_event(accion, ev)
	if guardar_ya:
		guardar()
	return quitada


func restablecer() -> void:
	for a in ACCIONES:
		var accion: String = str(a[0])
		_quitar_teclas(accion, teclas_de(accion))
		for k in _por_defecto.get(accion, []):
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = int(k) as Key
			InputMap.action_add_event(accion, ev)
	sensibilidad_raton = 1.0
	sensibilidad_mando = 1.0
	invertir_y = false
	mando_activo = true
	mostrar_ayuda = true
	escala_interfaz = 1.0
	guardar()


func _quitar_teclas(accion: String, teclas: Array) -> void:
	for ev in InputMap.action_get_events(accion):
		if ev is InputEventKey and int((ev as InputEventKey).physical_keycode) in teclas:
			InputMap.action_erase_event(accion, ev)


# ------------------------------- Guardar --------------------------------------

func guardar() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("opciones", "sensibilidad_raton", sensibilidad_raton)
	cfg.set_value("opciones", "sensibilidad_mando", sensibilidad_mando)
	cfg.set_value("opciones", "invertir_y", invertir_y)
	cfg.set_value("opciones", "mando_activo", mando_activo)
	cfg.set_value("opciones", "mostrar_ayuda", mostrar_ayuda)
	cfg.set_value("opciones", "escala_interfaz", escala_interfaz)
	for a in ACCIONES:
		var accion: String = str(a[0])
		var actuales: Array = teclas_de(accion)
		if actuales != _por_defecto.get(accion, []):
			cfg.set_value("teclas", accion, actuales)
	cfg.save(RUTA)


func cargar() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(RUTA) != OK:
		return
	sensibilidad_raton = clampf(float(cfg.get_value("opciones", "sensibilidad_raton", 1.0)), 0.2, 3.0)
	sensibilidad_mando = clampf(float(cfg.get_value("opciones", "sensibilidad_mando", 1.0)), 0.2, 3.0)
	invertir_y = bool(cfg.get_value("opciones", "invertir_y", false))
	mando_activo = bool(cfg.get_value("opciones", "mando_activo", true))
	mostrar_ayuda = bool(cfg.get_value("opciones", "mostrar_ayuda", true))
	escala_interfaz = clampf(float(cfg.get_value("opciones", "escala_interfaz", 1.0)), 0.8, 1.4)
	if cfg.has_section("teclas"):
		for accion in cfg.get_section_keys("teclas"):
			var lista = cfg.get_value("teclas", accion, [])
			if not InputMap.has_action(accion) or not lista is Array:
				continue
			_quitar_teclas(accion, teclas_de(accion))
			for k in lista:
				var ev: InputEventKey = InputEventKey.new()
				ev.physical_keycode = int(k) as Key
				InputMap.action_add_event(accion, ev)


# -------------------------------- Mando ---------------------------------------

func _anadir_mando() -> void:
	_eje("adelante", JOY_AXIS_LEFT_Y, -1.0)
	_eje("atras", JOY_AXIS_LEFT_Y, 1.0)
	_eje("izquierda", JOY_AXIS_LEFT_X, -1.0)
	_eje("derecha", JOY_AXIS_LEFT_X, 1.0)
	_boton("saltar", JOY_BUTTON_A)
	_boton("agacharse", JOY_BUTTON_B)
	_boton("usar", JOY_BUTTON_X)
	_boton("recargar", JOY_BUTTON_Y)
	_boton("correr", JOY_BUTTON_LEFT_STICK)
	_boton("cambiar_camara", JOY_BUTTON_RIGHT_STICK)
	_boton("telefono", JOY_BUTTON_BACK)
	_boton("liberar_raton", JOY_BUTTON_START)
	_boton("mapa_grande", JOY_BUTTON_DPAD_UP)
	_boton("inventario", JOY_BUTTON_DPAD_DOWN)
	_boton("colocar", JOY_BUTTON_DPAD_LEFT)
	_boton("esquivar", JOY_BUTTON_DPAD_RIGHT)


func _eje(accion: String, eje: JoyAxis, signo: float) -> void:
	if not InputMap.has_action(accion):
		return
	InputMap.action_set_deadzone(accion, ZONA_MUERTA)
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.device = -1
	ev.axis = eje
	ev.axis_value = signo
	InputMap.action_add_event(accion, ev)


func _boton(accion: String, boton: JoyButton) -> void:
	if not InputMap.has_action(accion):
		return
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.device = -1
	ev.button_index = boton
	InputMap.action_add_event(accion, ev)


# Stick derecho -> movimiento de ratón; gatillos -> clic izquierdo y derecho; LB/RB -> rueda.
func _process(delta: float) -> void:
	if not mando_activo or Input.get_connected_joypads().is_empty():
		return
	var dispositivo: int = Input.get_connected_joypads()[0]
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var v: Vector2 = Vector2(Input.get_joy_axis(dispositivo, JOY_AXIS_RIGHT_X), Input.get_joy_axis(dispositivo, JOY_AXIS_RIGHT_Y))
		if v.length() > ZONA_MUERTA:
			# Respuesta curva: fino cerca del centro, rápido a tope.
			var fuerza: float = (v.length() - ZONA_MUERTA) / (1.0 - ZONA_MUERTA)
			v = v.normalized() * fuerza * fuerza
			var mov: InputEventMouseMotion = InputEventMouseMotion.new()
			# jugador.gd multiplica por sensibilidad_raton: aquí se compensa para que mande la del mando.
			mov.relative = v * VELOCIDAD_MIRAR * delta * sensibilidad_mando / maxf(0.01, sensibilidad_raton)
			Input.parse_input_event(mov)
	var der: bool = Input.get_joy_axis(dispositivo, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	if der != _gatillo_der:
		_gatillo_der = der
		_clic(MOUSE_BUTTON_LEFT, der)
	var izq: bool = Input.get_joy_axis(dispositivo, JOY_AXIS_TRIGGER_LEFT) > 0.5
	if izq != _gatillo_izq:
		_gatillo_izq = izq
		_clic(MOUSE_BUTTON_RIGHT, izq)


func _input(evento: InputEvent) -> void:
	if not mando_activo or not evento is InputEventJoypadButton or not evento.pressed:
		return
	var b: int = (evento as InputEventJoypadButton).button_index
	if b == JOY_BUTTON_LEFT_SHOULDER:
		_clic(MOUSE_BUTTON_WHEEL_UP, true)
		_clic(MOUSE_BUTTON_WHEEL_UP, false)
	elif b == JOY_BUTTON_RIGHT_SHOULDER:
		_clic(MOUSE_BUTTON_WHEEL_DOWN, true)
		_clic(MOUSE_BUTTON_WHEEL_DOWN, false)


func _clic(boton: MouseButton, pulsado: bool) -> void:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = boton
	ev.pressed = pulsado
	ev.position = get_viewport().get_visible_rect().size / 2.0
	ev.global_position = ev.position
	Input.parse_input_event(ev)
