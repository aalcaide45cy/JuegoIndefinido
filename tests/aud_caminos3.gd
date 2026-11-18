# ¿Pasan las carreteras de montaña por dentro de pueblos (que no sean sus extremos)? Cuenta puntos.
extends Node
func _ready() -> void:
	for sem in [1847, 1, 2, 3, 7, 42, 99, 123, 555, 2024]:
		GeneradorMundo.iniciar(sem, Rect2(-110.0, -120.0, 440.0, 240.0))
		var total: int = 0
		var en_zona: int = 0
		var en_casas: int = 0
		var caminos_malos: int = 0
		var todos: Array = GeneradorMundo.todos_asentamientos()
		for c in GeneradorMundo._caminos:
			var pts: PackedVector2Array = c["pts"]
			var malo: bool = false
			for i in range(1, pts.size() - 1):
				total += 1
				for s in todos:
					var p: Vector2 = s["pos"]
					var d: float = maxf(absf(pts[i].x - p.x), absf(pts[i].y - p.y))
					# Los puntos de la propia puerta (a unos 110 m fuera del pueblo) no cuentan: están justo en el borde.
					if d < float(s["mitad"]) + 40.0:
						en_casas += 1
						malo = true
					elif d < float(s["plano"]) - 50.0:
						en_zona += 1
			if malo:
				caminos_malos += 1
		print("semilla %d: %d puntos, %d a menos de mitad+40 m de un pueblo (en casas), %d en la zona de huertos/aplanado; %d carreteras tocan casas" % [sem, total, en_casas, en_zona, caminos_malos])
	get_tree().quit(0)
