# puerta.gd
# -----------------------------------------------------------------------------
# Una puerta (o trampilla, o escalera) que te lleva a otro sitio.
# En realidad no se abre: la pantalla funde a negro y el jugador aparece en el
# "destino". Es el truco clásico para tener interiores sin complicarse.
# -----------------------------------------------------------------------------
class_name Puerta
extends Interactuable

var texto: String = "Entrar"
var destino: Vector3 = Vector3.ZERO
# Hacia dónde mira el jugador al llegar (en radianes): 0 = norte, PI = sur.
var angulo_llegada: float = 0.0


# Atajo para crear una puerta en una sola línea.
static func crear(padre: Node3D, pos: Vector3, texto_puerta: String,
		destino_puerta: Vector3, angulo: float) -> Puerta:
	var puerta: Puerta = Puerta.new()
	puerta.position = pos
	puerta.texto = texto_puerta
	puerta.destino = destino_puerta
	puerta.angulo_llegada = angulo
	padre.add_child(puerta)
	return puerta


func _ready() -> void:
	distancia = 2.5


func texto_accion() -> String:
	return texto


func usar(jugador: Node) -> void:
	jugador.teletransportar(destino, angulo_llegada)
