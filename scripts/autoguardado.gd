# autoguardado.gd  (autocarga "Autoguardado")
# -----------------------------------------------------------------------------
# Guarda la partida sola cada "minutos" minutos (0 = apagado) en la ranura actual, y también
# al cerrar la ventana del juego. Solo cuando se está jugando de verdad: con la escena del
# mundo como escena principal (no en las pruebas automáticas), sin menús abiertos ni pausa,
# y después de haber elegido partida en el menú de inicio.
# La opción se guarda en user://opciones.cfg (sección "juego") y se cambia en Esc > Sonido y juego.
# -----------------------------------------------------------------------------
extends Node

const RUTA: String = "user://opciones.cfg"
const ESCENA_MUNDO: String = "res://scenes/mundo.tscn"

var minutos: int = 5
var partida_activa: bool = false   # Pasa a true la primera vez que se juega sin pausa.
var ultimo_guardado_ms: int = 0
var _t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(RUTA) == OK:
		minutos = clampi(int(cfg.get_value("juego", "autoguardado_min", 5)), 0, 120)


func poner_minutos(m: int) -> void:
	minutos = clampi(m, 0, 120)
	_t = 0.0
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(RUTA)   # Conserva lo que ya hubiera (volúmenes...).
	cfg.set_value("juego", "autoguardado_min", minutos)
	cfg.save(RUTA)


func _jugador() -> Node3D:
	return get_tree().get_first_node_in_group("jugador") as Node3D


func _jugando() -> bool:
	var escena: Node = get_tree().current_scene
	if escena == null or escena.scene_file_path != ESCENA_MUNDO:
		return false
	return _jugador() != null


func _process(delta: float) -> void:
	if not _jugando():
		return
	if not get_tree().paused and not Juego.menu_abierto:
		partida_activa = true
	if minutos <= 0 or not partida_activa or get_tree().paused or Juego.menu_abierto:
		return
	_t += delta
	if _t >= minutos * 60.0:
		_t = 0.0
		guardar_ahora("Autoguardado")


func guardar_ahora(motivo: String) -> bool:
	var j: Node3D = _jugador()
	if j == null:
		return false
	# No guardar en mitad de un viaje en coche raro o muerto: la carga te dejaría ahí.
	if "vida" in Juego and float(Juego.vida) <= 0.0:
		return false
	var ok: bool = Guardado.guardar(get_tree(), j)
	if ok:
		ultimo_guardado_ms = Time.get_ticks_msec()
		Juego.avisar("%s (ranura %d)." % [motivo, Guardado.ranura])
	return ok


func _notification(que: int) -> void:
	if que == NOTIFICATION_WM_CLOSE_REQUEST:
		_al_cerrar()


func _al_cerrar() -> void:
	if _jugando() and partida_activa and minutos > 0:
		guardar_ahora("Guardado al salir")
