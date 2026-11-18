extends Node
func _ready() -> void:
	GeneradorMundo.iniciar(1847, Rect2(-110.0, -120.0, 440.0, 240.0))
	var s: Dictionary = GeneradorMundo.asentamiento(0, -3)
	print("aldea a_0_-3: ", s)
	var p: Vector2 = s["pos"]
	for dx in [-120, -60, 0, 60, 120]:
		var linea: String = ""
		for dz in [-120, -60, 0, 60, 120]:
			linea += " %7.1f" % GeneradorMundo.altura(p.x + dx, p.y + dz)
		print(linea)
	print("en (197,-1587): ", GeneradorMundo.altura(197, -1587), " base ", GeneradorMundo.altura_base(197, -1587))
	get_tree().quit(0)
