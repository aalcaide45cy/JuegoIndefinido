# mostrador.gd
# -----------------------------------------------------------------------------
# La ventanilla de venta de tu casa. Cuando ya tienes la casa alquilada, de vez
# en cuando llega un cliente que pide una poción (prohibida, claro) y espera
# con una paciencia limitada.
# Pulsa E en el mostrador para venderle si tienes lo que pide.
# -----------------------------------------------------------------------------
class_name Mostrador
extends Interactuable

const NOMBRES: Array[String] = [
	"La Viuda Remedios", "El Enterrador Tito", "Fray Anselmo (sin hábito)",
	"La Baronesa Pálida", "Un bardo con ojeras", "Sir Gualterio el Tuerto",
	"La Vieja del Pozo", "Un guardia (fuera de turno)",
]
const PACIENCIA_MAX: float = 45.0

var id_casa: String = "plaza"   # A qué vivienda pertenece esta ventanilla.
var presente: bool = false
var nombre: String = ""
var pedido: String = ""
var paciencia: float = 0.0
# Dónde espera el cliente respecto al mostrador y hacia dónde mira.
# (Quien crea el mostrador puede cambiarlo antes de añadirlo a la escena.)
var posicion_cliente: Vector3 = Vector3(1.1, -1.05, 0)
var giro_cliente: float = PI / 2.0

var _espera_siguiente: float = 6.0   # Segundos hasta que llegue alguien.
var _cliente: Node3D                 # El muñeco del cliente.
var _material_ropa: StandardMaterial3D
var _cartel: Label3D                 # Nombre, pedido y paciencia sobre su cabeza.


func _ready() -> void:
	distancia = 2.0
	# El cliente espera al otro lado del mostrador (1,1 m a la derecha, +X).
	_cliente = Node3D.new()
	_cliente.position = posicion_cliente
	_cliente.rotation.y = giro_cliente
	add_child(_cliente)
	var ropa: Node3D = Construir.cilindro(_cliente, Vector3(0, 0.65, 0), 0.32, 1.3, Color.GRAY, false, 0.0, 0.22)
	_material_ropa = (ropa as MeshInstance3D).mesh.material
	Construir.esfera(_cliente, Vector3(0, 1.5, 0), 0.19, Color(0.7, 0.66, 0.6))
	Construir.cilindro(_cliente, Vector3(0, 1.62, 0), 0.22, 0.25, Color(0.1, 0.1, 0.12), false, 0.0, 0.05)
	_cartel = Construir.texto(self, posicion_cliente + Vector3(0, 2.1, 0), "", 32)
	_cartel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cliente.visible = false
	_cartel.visible = false


func _process(delta: float) -> void:
	if not presente:
		if not Juego.alquilada(id_casa):
			return  # Nadie viene a comprar hasta que tengas tu escondite.
		_espera_siguiente -= delta
		if _espera_siguiente <= 0.0:
			_llega_cliente()
		return
	paciencia -= delta
	if paciencia <= 0.0:
		Juego.avisar("%s se ha cansado de esperar y se pierde en la niebla." % nombre)
		_se_marcha()
		return
	# Barra de paciencia hecha con texto: #### = le queda paciencia.
	var llenos: int = ceili(paciencia / PACIENCIA_MAX * 10.0)
	_cartel.text = "%s\nQuiere: %s\n[%s%s]" % [nombre, GameData.POCIONES[pedido]["nombre"],
			"#".repeat(llenos), ".".repeat(10 - llenos)]


func texto_accion() -> String:
	if not presente:
		return "No hay nadie en el mostrador"
	var datos: Dictionary = GameData.POCIONES[pedido]
	if Juego.tiene("pocion_" + pedido):
		return "Vender %s (%d $)" % [datos["nombre"], datos["precio"]]
	return "Te pide %s (prepárala en el caldero)" % datos["nombre"]


func usar(_jugador: Node) -> void:
	if not presente:
		return
	if not Juego.tiene("pocion_" + pedido):
		Juego.avisar("No tienes %s. Receta: %s." % [GameData.POCIONES[pedido]["nombre"],
				GameData.texto_receta(pedido)])
		return
	Juego.quitar("pocion_" + pedido)
	var precio: int = GameData.POCIONES[pedido]["precio"]
	Juego.avisar("Vendido por %d $. %s" % [precio, GameData.POCIONES[pedido]["efecto"]])
	Juego.cobrar(precio)
	_se_marcha()


func _llega_cliente() -> void:
	presente = true
	nombre = NOMBRES.pick_random()
	pedido = GameData.POCIONES.keys().pick_random()
	paciencia = PACIENCIA_MAX
	_material_ropa.albedo_color = Color.from_hsv(randf(), 0.35, 0.35)
	_cliente.visible = true
	_cartel.visible = true
	Juego.avisar("Alguien golpea la ventanilla de tu casa: es %s." % nombre)


func _se_marcha() -> void:
	presente = false
	_cliente.visible = false
	_cartel.visible = false
	_espera_siguiente = randf_range(5.0, 10.0)
