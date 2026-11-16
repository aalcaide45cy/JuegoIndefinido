# tendero.gd
# -----------------------------------------------------------------------------
# El herbolario de la tienda. Al hablar con él (E) se abre la tienda para
# comprar semillas, tierra, abono, macetas y la jarra de agua.
#
# El nodo se coloca encima del mostrador (para que el jugador lo "vea" por
# encima de la madera) y el muñeco queda detrás, mirando hacia +Z.
# -----------------------------------------------------------------------------
class_name Tendero
extends Interactuable

# Dónde está el muñeco respecto al nodo (detrás del mostrador y en el suelo).
const POS_MUNECO: Vector3 = Vector3(0, -1.0, -0.9)

# Qué vende (campo "tienda" en scripts/datos/objetos.gd) y cómo se llama el negocio.
var tienda: String = "herbolario"
var nombre_tienda: String = "Herboristería La Mandrágora Honrada"
var texto_hablar: String = "Hablar con el herbolario (comprar)"


func _ready() -> void:
	distancia = 2.4
	# Un señor mayor con delantal verde, gafas y pelo blanco.
	var m: Vector3 = POS_MUNECO
	Construir.cilindro(self, m + Vector3(0, 0.65, 0), 0.3, 1.3, Color(0.2, 0.2, 0.22), false, 0.0, 0.24)
	Construir.caja(self, m + Vector3(0, 0.75, 0.25), Vector3(0.4, 0.8, 0.05), Color(0.2, 0.4, 0.25), false)
	Construir.esfera(self, m + Vector3(0, 1.48, 0), 0.19, Color(0.8, 0.68, 0.58))
	Construir.caja(self, m + Vector3(0, 1.52, 0.18), Vector3(0.24, 0.05, 0.03), Color(0.1, 0.1, 0.1), false)
	Construir.esfera(self, m + Vector3(0, 1.62, -0.02), 0.17, Color(0.85, 0.85, 0.85), Vector3(1, 0.5, 1))


func texto_accion() -> String:
	return texto_hablar


func usar(jugador: Node) -> void:
	jugador.hud.abrir_tienda(tienda, nombre_tienda)
