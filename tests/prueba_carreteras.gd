# Continuidad de las carreteras entre trozos: en cada borde de trozo que cruza una carretera
# (llana o de montaña) comprueba que la calzada no tiene huecos y que sigue al terreno.
#   godot --headless --path . res://tests/prueba_carreteras.tscn
extends Node

var _tris: Dictionary = {}   # Vector2i -> PackedVector3Array
var fallos: int = 0


func _trozo(c: Vector2i) -> PackedVector3Array:
	if not _tris.has(c):
		_tris[c] = GeneradorMundo.triangulos_carreteras(c)
	return _tris[c]


# Altura de la calzada en (x, z) o NAN si ningún triángulo de los trozos vecinos la cubre.
func _altura_calzada(x: float, z: float) -> float:
	var t: float = GeneradorMundo.TROZO
	var c0: Vector2i = Vector2i(floori(x / t), floori(z / t))
	var p: Vector2 = Vector2(x, z)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var v: PackedVector3Array = _trozo(c0 + Vector2i(dx, dz))
			for i in range(0, v.size(), 3):
				var a: Vector3 = v[i]
				var b: Vector3 = v[i + 1]
				var c: Vector3 = v[i + 2]
				if p.x < minf(a.x, minf(b.x, c.x)) - 0.01 or p.x > maxf(a.x, maxf(b.x, c.x)) + 0.01:
					continue
				var bar: Vector3 = _bari(p, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z))
				if bar.x >= -0.001 and bar.y >= -0.001 and bar.z >= -0.001:
					return a.y * bar.x + b.y * bar.y + c.y * bar.z
	return NAN


func _bari(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0: Vector2 = b - a
	var v1: Vector2 = c - a
	var v2: Vector2 = p - a
	var den: float = v0.x * v1.y - v1.x * v0.y
	if absf(den) < 0.000001:
		return Vector3(-1, -1, -1)
	var y: float = (v2.x * v1.y - v1.x * v2.y) / den
	var z: float = (v0.x * v2.y - v2.x * v0.y) / den
	return Vector3(1.0 - y - z, y, z)


func _ready() -> void:
	GeneradorMundo.iniciar(1847, Rect2(-110.0, -120.0, 440.0, 240.0))
	var t: float = GeneradorMundo.TROZO
	var cruces: Array = []   # [punto, dirección]
	var lineas: Array = []   # [puntos, tipo]
	for c in GeneradorMundo._caminos:
		lineas.append([GeneradorMundo._suavizar(Array(c["pts"])), 2])
	for sg in GeneradorMundo.todas_las_carreteras():
		if int(sg[3]) == 1:
			lineas.append([[sg[0], sg[1]], 1])
	seed(7)
	var cuenta_t2: int = 0
	var cuenta_t1: int = 0
	for ln in lineas:
		var pts: Array = ln[0]
		var tipo: int = int(ln[1])
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var d: Vector2 = (b - a).normalized()
			var largo: float = a.distance_to(b)
			var s: float = 0.0
			var prev: Vector2i = Vector2i(floori(a.x / t), floori(a.y / t))
			while s < largo:
				s += 0.25
				var q: Vector2 = a + d * minf(s, largo)
				var cu: Vector2i = Vector2i(floori(q.x / t), floori(q.y / t))
				if cu != prev:
					prev = cu
					if (tipo == 2 and cuenta_t2 < 25 and randi() % 3 == 0) or (tipo == 1 and cuenta_t1 < 25 and randi() % 40 == 0):
						cruces.append([q, d])
						if tipo == 2:
							cuenta_t2 += 1
						else:
							cuenta_t1 += 1
	print("Cruces de borde a comprobar: ", cruces.size(), " (montaña ", cuenta_t2, ", llanas ", cuenta_t1, ")")
	var puntos: int = 0
	for cr in cruces:
		var q: Vector2 = cr[0]
		var d: Vector2 = cr[1]
		var n: Vector2 = Vector2(-d.y, d.x)
		for k in range(-12, 13):
			for lat in [-3.0, 0.0, 3.0]:
				var p: Vector2 = q + d * float(k) * 0.5 + n * lat
				var h: float = _altura_calzada(p.x, p.y)
				puntos += 1
				if is_nan(h):
					# Las curvas de montaña pueden desviar el eje unos metros del tramo recto: se ignora el punto si queda fuera de toda calzada a más de 4 m del tramo.
					fallos += 1
					print("FALLO: hueco en la calzada en ", p)
				else:
					var r: Rect2 = Rect2(p.x - 12.0, p.y - 12.0, 24.0, 24.0)
					var lista: Array = GeneradorMundo.asentamientos_cerca(r)
					lista.append_array(GeneradorMundo.caminos_cerca(r.grow(40.0)))
					var malla: float = GeneradorMundo._altura_malla(p.x, p.y, 4.0, lista, {}) + 0.15
					if absf(h - malla) > 0.4:
						fallos += 1
						print("FALLO: calzada despegada del terreno en ", p, " (", h, " vs ", malla, ")")
	print("Puntos comprobados: ", puntos)
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
