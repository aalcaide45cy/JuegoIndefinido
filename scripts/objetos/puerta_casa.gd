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
	# La puerta es un cuerpo sólido que cuelga de la bisagra.
	_bisagra = Node3D.new()
	_bisagra.position = Vector3(-ANCHO / 2.0, -1.0, 0)
	add_child(_bisagra)
	Construir.caja(_bisagra, Vector3(ANCHO / 2.0, ALTO / 2.0, 0), Vector3(ANCHO, ALTO, 0.08),
			Color(0.25, 0.15, 0.1))
	Construir.esfera(_bisagra, Vector3(ANCHO - 0.15, 1.05, 0.08), 0.05, Color(0.7, 0.6, 0.3))


func _process(delta: float) -> void:
	_bisagra.rotation.y = lerp_angle(_bisagra.rotation.y, _giro_objetivo, minf(1.0, delta * 6.0))


func texto_accion() -> String:
	if not Juego.alquilada(id_casa):
		return "Alquilar la casa por %d $" % precio
	return "Cerrar la puerta" if abierta else "Abrir la puerta"


func usar(_jugador: Node) -> void:
	if not Juego.alquilada(id_casa):
		if not Juego.gastar(precio):
			Juego.avisar("El casero quiere %d $ por adelantado. Vuelve cuando los tengas." % precio)
			return
		Juego.viviendas[id_casa] = true
		if cartel != null:
			cartel.text = "OCUPADO"
		Juego.avisar("¡Casa alquilada! Dentro tienes cama, cocina, estantería y sitio para macetas.")
		Juego.cambio.emit()
	abierta = not abierta
	# Se abre hacia dentro (hacia -Z).
	_giro_objetivo = deg_to_rad(100.0) if abierta else 0.0
