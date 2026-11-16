# diana.gd
# -----------------------------------------------------------------------------
# Una diana de la galería de tiro: se pone roja un momento cuando le das y
# cuenta el daño. Sirve para practicar con armas y explosivos.
# -----------------------------------------------------------------------------
class_name Diana
extends StaticBody3D

var _anillos: Array[StandardMaterial3D] = []


func _ready() -> void:
	add_to_group("danable")
	var forma: CollisionShape3D = CollisionShape3D.new()
	var cilindro: CylinderShape3D = CylinderShape3D.new()
	cilindro.radius = 0.5
	cilindro.height = 0.1
	forma.shape = cilindro
	forma.rotation.x = PI / 2.0
	forma.position.y = 1.4
	add_child(forma)
	Construir.cilindro(self, Vector3(0, 0.7, 0), 0.04, 1.4, Color(0.3, 0.2, 0.12))
	var colores: Array[Color] = [Color(0.9, 0.9, 0.85), Color(0.15, 0.15, 0.15), Color(0.8, 0.15, 0.12)]
	var radios: Array[float] = [0.5, 0.33, 0.16]
	for i in 3:
		var disco: Node3D = Construir.cilindro(self, Vector3(0, 1.4, 0.03 + i * 0.004), radios[i], 0.04, colores[i])
		disco.rotation.x = PI / 2.0
		_anillos.append((disco as MeshInstance3D).mesh.material)


func recibir_dano(cantidad: float) -> void:
	Juego.avisar("¡Diana! %d de daño." % int(cantidad))
	Juego.ganar_xp(1)
	for mat in _anillos:
		mat.emission_enabled = true
		mat.emission = Color(1, 0.2, 0.1)
		mat.emission_energy_multiplier = 2.0
	await get_tree().create_timer(0.25).timeout
	for mat in _anillos:
		mat.emission_enabled = false
