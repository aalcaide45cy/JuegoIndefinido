# puerta_casa.gd
# -----------------------------------------------------------------------------
# La puerta de la vivienda en alquiler.
#   - Mientras no la alquilas, está cerrada con llave y pone "SE ALQUILA".
#     Pulsa E para pagar el alquiler (GameData.PRECIO_ALQUILER).
#   - Cuando ya es tuya, E la abre y la cierra.
# La puerta gira sobre una bisagra en su borde izquierdo.
# -----------------------------------------------------------------------------
class_name PuertaCasa
extends Interactuable

const ANCHO: float = 1.2
const ALTO: float = 2.3

var id_casa: String = "plaza"     # Identificador de la vivienda (para el alquiler y el guardado).
var precio: int = GameData.PRECIO_ALQUILER
var abierta: bool = false
var cartel: Label3D = null   # El cartel "SE ALQUILA" (lo pone quien crea la puerta).

var _bisagra: Node3D
var _giro_objetivo: float = 0.0


func _ready() -> void:
	distancia = 2.2
	add_to_group("puertas")
	# La puerta es un cuerpo sólido que cuelga de la bisagra.
	_bisagra = Node3D.new()
	_bisagra.position = Vector3(-ANCHO / 2.0, -1.0, 0)
	add_child(_bisagra)
	Construir.caja(_bisagra, Vector3(ANCHO / 2.0, ALTO / 2.0, 0), Vector3(ANCHO, ALTO, 0.08),
			Color(0.25, 0.15, 0.1))
	Construir.esfera(_bisagra, Vector3(ANCHO - 0.15, 1.05, 0.08), 0.05, Color(0.7, 0.6, 0.3))
	# El cartel y la puerta se ponen al día al cargar una partida o empezar otra.
	Juego.cambio.connect(_actualizar_cartel)
	_actualizar_cartel()


func _actualizar_cartel() -> void:
	var tuya: bool = Juego.alquilada(id_casa)
	if cartel != null:
		cartel.text = "OCUPADO" if tuya else "SE ALQUILA  %d $" % precio
	if not tuya and abierta:
		abierta = false
		_giro_objetivo = 0.0


func _process(delta: float) -> void:
	_bisagra.rotation.y = lerp_angle(_bisagra.rotation.y, _giro_objetivo, minf(1.0, delta * 6.0))


func texto_accion() -> String:
	if not Juego.alquilada(id_casa):
		return "Alquilar la casa por %d $" % precio
	return "Cerrar con llave" if abierta else "Abrir la puerta (sin llave)"


func usar(_jugador: Node) -> void:
	if not Juego.alquilada(id_casa):
		if not Juego.gastar(precio):
			Juego.avisar("El casero quiere %d $ por adelantado. Vuelve cuando los tengas." % precio)
			return
		Juego.viviendas[id_casa] = true
		Juego.avisar("¡Casa alquilada! Dentro tienes cama, cocina, estantería y sitio para macetas.")
		Juego.cambio.emit()
	abierta = not abierta
	# Se abre hacia dentro (hacia -Z).
	_giro_objetivo = deg_to_rad(100.0) if abierta else 0.0
