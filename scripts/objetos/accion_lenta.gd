# accion_lenta.gd
# -----------------------------------------------------------------------------
# Base de lo que lleva un rato con la tecla E: forzar una puerta, registrar un cajón...
# Al pulsar E se llama a empezar(); luego la acción avanza sola mientras sigas cerca,
# sin recibir daño y sin abrir ningún menú. Muestra una barrita de progreso sobre el objeto.
# Las hijas cambian: texto_accion(), usar(), cada_segundo() y terminar().
# -----------------------------------------------------------------------------
class_name AccionLenta
extends Interactuable

var activa: bool = false
var progreso: float = 0.0       # Segundos hechos.
var duracion: float = 1.0       # Segundos que hacen falta.
var verbo: String = "Trabajando"

var _jugador: Node3D = null
var _vida_inicial: float = 0.0
var _etiqueta: Label3D = null
var _t_pulso: float = 0.0


func _ready() -> void:
	set_process(false)   # Solo trabaja mientras hay una acción en marcha.


func empezar(jugador: Node3D, segundos: float, texto: String) -> void:
	set_process(true)
	activa = true
	progreso = 0.0
	duracion = maxf(segundos, 0.05)
	verbo = texto
	_jugador = jugador
	_vida_inicial = Juego.vida
	_t_pulso = 0.0
	if _etiqueta == null:
		_etiqueta = Label3D.new()
		_etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_etiqueta.font_size = 44
		_etiqueta.pixel_size = 0.004
		_etiqueta.no_depth_test = true
		_etiqueta.outline_size = 10
		_etiqueta.position = Vector3(0, 0.9, 0)
		add_child(_etiqueta)
	_etiqueta.visible = true
	_actualizar_etiqueta()
	cada_segundo()


func cancelar(motivo: String = "") -> void:
	if not activa:
		return
	activa = false
	set_process(false)
	if _etiqueta != null:
		_etiqueta.visible = false
	if motivo != "":
		Juego.avisar(motivo)


func _process(delta: float) -> void:
	avanzar(delta)


# Separado de _process para poder probarlo sin esperar de verdad.
func avanzar(delta: float) -> void:
	if not activa:
		return
	if Juego.menu_abierto:
		cancelar()
		return
	if _jugador == null or not is_instance_valid(_jugador) \
			or _jugador.global_position.distance_to(global_position) > distancia + 1.2:
		cancelar("Te has alejado: lo dejas.")
		return
	if Juego.vida < _vida_inicial - 0.5:
		cancelar("Te han hecho daño: lo dejas.")
		return
	progreso += delta
	_t_pulso += delta
	if _t_pulso >= 1.0:
		_t_pulso -= 1.0
		cada_segundo()
	_actualizar_etiqueta()
	if progreso >= duracion:
		activa = false
		set_process(false)
		if _etiqueta != null:
			_etiqueta.visible = false
		terminar()


func _actualizar_etiqueta() -> void:
	if _etiqueta == null:
		return
	var p: float = clampf(progreso / duracion, 0.0, 1.0)
	var llenas: int = int(round(p * 10.0))
	_etiqueta.text = "%s\n%s%s %d%%" % [verbo, "█".repeat(llenas), "░".repeat(10 - llenas), int(p * 100.0)]
	_etiqueta.modulate = Color(1.0, 0.85, 0.4)


# Se llama al empezar y luego una vez por segundo (aquí va el ruido).
func cada_segundo() -> void:
	pass


# Se llama al llegar al 100 %.
func terminar() -> void:
	pass
