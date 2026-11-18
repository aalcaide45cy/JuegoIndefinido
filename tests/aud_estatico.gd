# Auditoría estática (sin escena): terreno, asentamientos y carreteras con varias semillas.
extends Node
func _ready() -> void:
	var sems: Array = [1847, 1, 2, 3, 7, 42, 99, 123, 555, 2024]
	for s in sems:
		GeneradorMundo.iniciar(s, Rect2(-110.0, -120.0, 440.0, 240.0))
		var asent: Array = GeneradorMundo.todos_asentamientos()
		var hmax: float = -1e9
		var altas: int = 0
		for a in asent:
			if float(a["base"]) > 45.0: altas += 1
			hmax = maxf(hmax, float(a["base"]))
		var segs: Array = GeneradorMundo.todas_las_carreteras()
		var hs_max: float = 0.0
		var nan: int = 0
		for sg in segs:
			var m: Vector2 = (sg[0] + sg[1]) * 0.5
			var h: float = GeneradorMundo.altura(m.x, m.y)
			if is_nan(h): nan += 1
			hs_max = maxf(hs_max, h)
		print("semilla %d: %d asentamientos, %d sobre 45 m (max base %.0f), %d tramos, altura max en carreteras %.0f, NaN %d" % [s, asent.size(), altas, hmax, segs.size(), hs_max, nan])
	get_tree().quit(0)
