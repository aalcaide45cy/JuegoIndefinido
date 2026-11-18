# ¿Dónde cabe cada coche aparcado sin meterse en una pared? Prueba posiciones laterales.
extends Node
func _ready() -> void:
	await get_tree().process_frame
	var escena = load("res://scenes/mundo.tscn").instantiate()
	get_tree().root.add_child(escena)
	for i in 5: await get_tree().physics_frame
	var esp: PhysicsDirectSpaceState3D = escena.get_world_3d().direct_space_state
	# [id, tipo, x, z, giro, eje]  eje: "z" = la avenida va por X (se varía z), "x" = va por Z (se varía x). axis: valor del eje.
	var lista: Array = [["amb_1", "sedan", 40.0, -16.0, PI/2, "z"], ["amb_2", "taxi", 99.0, -16.0, -PI/2, "z"],
		["amb_3", "hatchback", 17.6, -52.0, 0.0, "x", 16.0], ["amb_4", "furgoneta", -13.9, 52.0, PI, "x", -16.0],
		["amb_5", "suv", 150.0, -16.0, PI/2, "z"], ["amb_6", "tractor", 232.0, -16.0, -PI/2, "z"]]
	for p in lista:
		var largo: float = float(Vehiculo.TIPOS[p[1]]["largo"])
		var ancho: float = 2.0
		var linea: String = "%s %s:" % [p[0], p[1]]
		for lado in [-1.0, 1.0]:
			for d in [2.0, 2.6, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0]:
				var pos: Vector3
				if p[5] == "z":
					pos = Vector3(float(p[2]), 0.9, -16.0 + lado * d)
				else:
					pos = Vector3(float(p[6]) + lado * d, 0.9, float(p[3]))
				var caja: BoxShape3D = BoxShape3D.new()
				caja.size = Vector3(ancho, 1.2, largo)
				var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
				q.shape = caja
				q.transform = Transform3D(Basis(Vector3.UP, float(p[4])), pos)
				var n: int = 0
				for c in esp.intersect_shape(q, 8):
					var col = c["collider"]
					if col is Vehiculo or col.get_parent() is Vehiculo: continue
					n += 1
				linea += "  %s%.1f=%s" % ["+" if lado > 0 else "-", d, "ok" if n == 0 else "X"]
		print(linea)
	get_tree().quit(0)
