# Prueba de los trazados de ciudad (generador_mundo.gd). Sin ventana:
#   godot --headless --path . res://tests/prueba_trazados.tscn
# Comprueba: reparto de trazados, que la red de calles de cada asentamiento esté conectada,
# que ninguna casa pise la acera ni la calzada y que casco antiguo deje 3 m de callejón.
extends Node


func _ready() -> void:
	await get_tree().process_frame
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	get_tree().root.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	var fallos: Array = []
	var cuenta: Dictionary = {}
	for s in GeneradorMundo.todos_asentamientos():
		var tz: int = int(s.get("trazado", 0))
		var clave: String = "tipo%d_trazado%d" % [int(s["tipo"]), tz]
		cuenta[clave] = int(cuenta.get(clave, 0)) + 1
		var n: int = int(s["n"])
		var p: Vector2 = s["pos"]
		var ac: float = GeneradorMundo.acera_de(s)
		# Conectividad de la red de calles por inundación.
		var nodos: Array = []
		for k in range(-n, n + 1):
			for l in range(-n, n + 1):
				nodos.append(Vector2i(k, l))
		var visto: Dictionary = {Vector2i(-n, -n): true}
		var cola: Array = [Vector2i(-n, -n)]
		while not cola.is_empty():
			var c: Vector2i = cola.pop_back()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var o: Vector2i = c + d
				if absi(o.x) > n or absi(o.y) > n or visto.has(o):
					continue
				if GeneradorMundo.arista_existe(s, mini(c.x, o.x), mini(c.y, o.y), d.y == 0):
					visto[o] = true
					cola.append(o)
		if visto.size() != nodos.size():
			fallos.append("%s: red desconectada (%d de %d cruces)" % [s["nombre"], visto.size(), nodos.size()])
		# Casas: a >= 6,5 m del eje de cualquier calle que exista (o 4 en aldeas); callejón de 3 m en el casco.
		for k in range(-n, n):
			for l in range(-n, n):
				var casas: Array = []
				for sub in 4:
					var cd: Dictionary = GeneradorMundo.casa(s, k, l, sub)
					if cd.is_empty() or cd.has("servicio"):
						continue
					casas.append(cd)
					var x0: float = float(cd["x"]) - float(cd["w"]) / 2.0 - (p.x + k * GeneradorMundo.BLOQUE)
					var z0: float = float(cd["z"]) - float(cd["d"]) / 2.0 - (p.y + l * GeneradorMundo.BLOQUE)
					var x1: float = float(cd["x"]) + float(cd["w"]) / 2.0 - (p.x + k * GeneradorMundo.BLOQUE)
					var z1: float = float(cd["z"]) + float(cd["d"]) / 2.0 - (p.y + l * GeneradorMundo.BLOQUE)
					var minimo: float = 4.0 + ac - 0.01
					if x0 < minimo or z0 < minimo or x1 > 44.0 - minimo or z1 > 44.0 - minimo:
						fallos.append("%s bloque %d,%d sub %d: casa fuera del solar (%.1f %.1f %.1f %.1f)" % [s["nombre"], k, l, sub, x0, z0, x1, z1])
				if GeneradorMundo.bloque_casco(s, k, l) and casas.size() == 4:
					var a0: Dictionary = casas[0]
					var a1: Dictionary = casas[1]
					var hueco: float = (float(a1["x"]) - float(a1["w"]) / 2.0) - (float(a0["x"]) + float(a0["w"]) / 2.0)
					if absf(hueco - 3.0) > 0.01:
						fallos.append("%s casco %d,%d: callejon de %.2f m" % [s["nombre"], k, l, hueco])
	print("Trazados: ", cuenta)
	if fallos.is_empty():
		print("TODO BIEN")
	else:
		for f in fallos.slice(0, 20):
			print("FALLO ", f)
		print("FALLOS: ", fallos.size())
	get_tree().quit()
