# Mide las carreteras de montaña: radio mínimo de curva y tramos que se cruzan consigo mismos.
extends Node
func _ready() -> void:
	for sem in [1847, 1, 2, 3, 7, 42, 99, 123]:
		GeneradorMundo.iniciar(sem, Rect2(-110.0, -120.0, 440.0, 240.0))
		var n: int = 0
		var pend_max: float = 0.0
		var empinadas: int = 0
		var peor_r: float = 1e9
		var cruces: int = 0
		var radios_malos: int = 0
		for c in GeneradorMundo._caminos:
			n += 1
			var pts: PackedVector2Array = c["pts"]
			var hs: PackedFloat32Array = c["hs"]
			var rmin: float = 1e9
			for i in range(1, pts.size() - 1):
				var a: Vector2 = pts[i] - pts[i - 1]
				var b: Vector2 = pts[i + 1] - pts[i]
				var ang: float = absf(a.angle_to(b))
				if ang > 0.001:
					var r: float = (a.length() + b.length()) * 0.5 / ang
					rmin = minf(rmin, r)
			var pm: float = 0.0
			for i in range(1, pts.size()):
				pm = maxf(pm, absf(hs[i] - hs[i - 1]) / maxf(0.1, pts[i].distance_to(pts[i - 1])))
			pend_max = maxf(pend_max, pm)
			if pm > 0.12:
				empinadas += 1
			peor_r = minf(peor_r, rmin)
			if rmin < 12.0:
				radios_malos += 1
			var prox: int = 0
			for i in range(0, pts.size(), 1):
				for j in range(i + 4, pts.size()):
					if pts[i].distance_to(pts[j]) < 16.0 and absf(hs[i] - hs[j]) > 1.5:
						prox += 1
			if prox > 0:
				cruces += 1
		print("semilla %d: %d carreteras de montaña, radio mínimo %.1f m, %d con curvas < 12 m, %d con tramos a < 16 m a otra altura, pendiente máx %.0f %% (%d > 12 %%)" % [sem, n, peor_r, radios_malos, cruces, pend_max * 100.0, empinadas])
	get_tree().quit(0)
