# Auditoría: cuenta TODOS los edificios del mundo grande por tipo de asentamiento y dice cuáles
# tienen interior y cuáles no. Sin ventana:
#   godot --headless --path . res://tests/auditoria_interiores.tscn
extends Node


func _ready() -> void:
	await get_tree().process_frame
	GeneradorMundo.iniciar(1847, Rect2(-110.0, -120.0, 440.0, 240.0))
	var por_tipo: Dictionary = {0: {}, 1: {}, 2: {}}
	var asent: Array = GeneradorMundo.todos_asentamientos()
	print("Asentamientos: %d" % asent.size())
	var total: int = 0
	var servicios: Dictionary = {}
	var pisos_hist: Dictionary = {}
	var por_asent: Array = []
	for s in asent:
		var p: Vector2 = s["pos"]
		var m: float = float(s["mitad"]) + 60.0
		var rect: Rect2 = Rect2(p.x - m, p.y - m, m * 2.0, m * 2.0)
		var casas: Array = GeneradorMundo._casas_en(s, rect)
		var n_serv: int = 0
		var n_casas: int = 0
		var n_altas: int = 0
		for c in casas:
			total += 1
			var t: int = int(s["tipo"])
			var d: Dictionary = por_tipo[t]
			if c.has("servicio"):
				n_serv += 1
				servicios[c["servicio"]] = int(servicios.get(c["servicio"], 0)) + 1
				d["servicio"] = int(d.get("servicio", 0)) + 1
			else:
				n_casas += 1
				var k: String = str(c.get("distrito", "?"))
				d[k] = int(d.get(k, 0)) + 1
				if int(c["pisos"]) > 1:
					n_altas += 1
			pisos_hist[int(c["pisos"])] = int(pisos_hist.get(int(c["pisos"]), 0)) + 1
		por_asent.append("%s %s (tipo %d): %d casas, %d servicios, %d con pisos altos" % [
				GeneradorMundo.nombre_tipo(int(s["tipo"])), s["nombre"], int(s["tipo"]), n_casas, n_serv, n_altas])
	var nombres: Array = ["aldeas", "pueblos", "ciudades"]
	for t in 3:
		print("%s: %s" % [nombres[t], por_tipo[t]])
	print("Edificios en asentamientos: %d" % total)
	print("Servicios por clase: %s" % servicios)
	print("Edificios por número de pisos: %s" % pisos_hist)
	var segs: Array = GeneradorMundo.segmentos_para(Rect2(-5000, -5000, 10000, 10000))
	var gas: Array = GeneradorMundo._gasolineras_de_carretera(Rect2(-5000, -5000, 10000, 10000), segs)
	print("Gasolineras sueltas de carretera: %d" % gas.size())
	for i in mini(8, por_asent.size()):
		print("  ", por_asent[i])
	get_tree().quit(0)
