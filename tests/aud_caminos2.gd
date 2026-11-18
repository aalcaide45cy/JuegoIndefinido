extends Node
func _ready() -> void:
	GeneradorMundo.iniciar(int(OS.get_cmdline_user_args()[1]) if OS.get_cmdline_user_args().size() > 1 else 1847, Rect2(-110.0, -120.0, 440.0, 240.0))
	for c in GeneradorMundo._caminos:
		var pts: PackedVector2Array = c["pts"]
		var hs: PackedFloat32Array = c["hs"]
		var pm: float = 0.0
		var im: int = 0
		for i in range(1, pts.size()):
			var g: float = absf(hs[i] - hs[i - 1]) / maxf(0.1, pts[i].distance_to(pts[i - 1]))
			if g > pm:
				pm = g
				im = i
		var largo_total: float = 0.0
		for i in range(1, pts.size()):
			largo_total += pts[i].distance_to(pts[i - 1])
		var dh: float = hs[hs.size() - 1] - hs[0]
		print("n=%d recta=%.0f arco=%.0f dh=%.0f media=%.1f%% max=%.0f%% en i=%d (d=%.1f dh=%.1f)" % [pts.size(), pts[0].distance_to(pts[pts.size() - 1]), largo_total, dh, absf(dh) / largo_total * 100.0, pm * 100.0, im, pts[im].distance_to(pts[im - 1]), hs[im] - hs[im - 1]])
	get_tree().quit(0)
