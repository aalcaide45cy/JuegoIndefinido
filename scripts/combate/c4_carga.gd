# c4_carga.gd
# -----------------------------------------------------------------------------
# Una carga C4 pegada a una superficie. Explota cuando pulsas el detonador.
# -----------------------------------------------------------------------------
class_name CargaC4
extends Node3D

var radio: float = 7.0
var dano: float = 150.0


func _ready() -> void:
	add_to_group("c4")
	Construir.caja(self, Vector3.ZERO, Vector3(0.22, 0.12, 0.05), Color(0.85, 0.82, 0.7), false)
	Construir.esfera(self, Vector3(0, 0, 0.03), 0.02, Color(1, 0.15, 0.1), Vector3.ONE, 3.0)


func detonar() -> void:
	Combate.explosion(get_parent() as Node3D, global_position, radio, dano)
	queue_free()
