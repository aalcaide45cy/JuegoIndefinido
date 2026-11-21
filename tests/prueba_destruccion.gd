# Prueba: una explosion grande revienta un coche y deja un crater.
# godot --headless --path . res://tests/prueba_destruccion.tscn
extends Node3D

func _ready() -> void:
	await get_tree().process_frame
	var suelo: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var caja: BoxShape3D = BoxShape3D.new()
	caja.size = Vector3(100, 1, 100)
	cs.shape = caja
	suelo.add_child(cs)
	suelo.position = Vector3(0, -0.5, 0)
	add_child(suelo)
	var coche: Vehiculo = Vehiculo.new()
	coche.tipo = "sedan"
	add_child(coche)
	coche.position = Vector3(2, 0.5, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var fallos: int = 0
	Combate.explosion(self, Vector3(0, 0.5, 0), 7.0, 150.0)
	await get_tree().process_frame
	if not coche.destruido:
		fallos += 1
		print("FALLO: el coche no ha reventado, salud=", coche.salud)
	if Destruccion._crateres.size() != 1:
		fallos += 1
		print("FALLO: no hay crater")
	print("TODO BIEN" if fallos == 0 else "HAY FALLOS: %d" % fallos)
	get_tree().quit()
