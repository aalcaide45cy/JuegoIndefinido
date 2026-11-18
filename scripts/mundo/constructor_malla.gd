# constructor_malla.gd
# -----------------------------------------------------------------------------
# Va juntando cajas, techos y conos en listas de vértices (con color por
# vértice) para crear UNA malla grande sin crear nodos. Solo usa datos
# (PackedArrays), así que se puede usar desde un hilo en segundo plano.
# Las mismas caras sirven para el choque (ConcavePolygonShape3D.set_faces).
# SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name ConstructorMalla
extends RefCounted

var vertices: PackedVector3Array = PackedVector3Array()
var normales: PackedVector3Array = PackedVector3Array()
var colores: PackedColorArray = PackedColorArray()


func _tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	normales.append(n)
	normales.append(n)
	normales.append(n)
	colores.append(col)
	colores.append(col)
	colores.append(col)


# Cuadrilátero con los puntos en sentido antihorario visto desde fuera.
func cuadro(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col: Color) -> void:
	var n: Vector3 = (p1 - p0).cross(p3 - p0).normalized()
	_tri(p0, p3, p2, n, col)
	_tri(p0, p2, p1, n, col)


# Caja con centro "c" y tamaño "t" (sin giro).
func caja(c: Vector3, t: Vector3, col: Color) -> void:
	var h: Vector3 = t / 2.0
	var x0: float = c.x - h.x
	var x1: float = c.x + h.x
	var y0: float = c.y - h.y
	var y1: float = c.y + h.y
	var z0: float = c.z - h.z
	var z1: float = c.z + h.z
	var claro: Color = col.lightened(0.08)
	var oscuro: Color = col.darkened(0.12)
	# Arriba, abajo, y cuatro lados (cada lado un poco distinto para dar volumen).
	cuadro(Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0), claro)
	cuadro(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), oscuro)
	cuadro(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), col)
	cuadro(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), col)
	cuadro(Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), oscuro)
	cuadro(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), oscuro)


# Techo a cuatro aguas: base rectangular centrada en "c" (a altura de la base)
# y una cumbrera más estrecha a "alto" metros.
func techo(c: Vector3, ancho: float, fondo: float, alto: float, col: Color) -> void:
	var hx: float = ancho / 2.0
	var hz: float = fondo / 2.0
	var cx: float = minf(hx * 0.25, 0.8)
	var cz: float = minf(hz * 0.25, 0.8)
	var b00: Vector3 = Vector3(c.x - hx, c.y, c.z - hz)
	var b10: Vector3 = Vector3(c.x + hx, c.y, c.z - hz)
	var b11: Vector3 = Vector3(c.x + hx, c.y, c.z + hz)
	var b01: Vector3 = Vector3(c.x - hx, c.y, c.z + hz)
	var t00: Vector3 = Vector3(c.x - cx, c.y + alto, c.z - cz)
	var t10: Vector3 = Vector3(c.x + cx, c.y + alto, c.z - cz)
	var t11: Vector3 = Vector3(c.x + cx, c.y + alto, c.z + cz)
	var t01: Vector3 = Vector3(c.x - cx, c.y + alto, c.z + cz)
	cuadro(b01, b11, t11, t01, col)                       # +z
	cuadro(b10, b00, t00, t10, col.darkened(0.1))         # -z
	cuadro(b11, b10, t10, t11, col.darkened(0.15))        # +x
	cuadro(b00, b01, t01, t00, col.darkened(0.15))        # -x
	cuadro(t01, t11, t10, t00, col.lightened(0.05))       # tapa


# Cono (o pirámide de "lados" caras) de base a "c".
func cono(c: Vector3, radio: float, alto: float, lados: int, col: Color, radio_punta: float = 0.0) -> void:
	for i in lados:
		var a0: float = TAU * float(i) / float(lados)
		var a1: float = TAU * float(i + 1) / float(lados)
		var p0: Vector3 = c + Vector3(cos(a0) * radio, 0.0, sin(a0) * radio)
		var p1: Vector3 = c + Vector3(cos(a1) * radio, 0.0, sin(a1) * radio)
		var q0: Vector3 = c + Vector3(cos(a0) * radio_punta, alto, sin(a0) * radio_punta)
		var q1: Vector3 = c + Vector3(cos(a1) * radio_punta, alto, sin(a1) * radio_punta)
		var tono: Color = col.darkened(0.12 * float(i % 2))
		# p1 -> p0 -> q0 -> q1 visto desde fuera es antihorario.
		cuadro(p1, p0, q0, q1, tono)


# Tira de carretera plana entre dos puntos ya a su altura (normal hacia arriba).
func tira(a_izq: Vector3, a_der: Vector3, b_izq: Vector3, b_der: Vector3, col: Color) -> void:
	var n: Vector3 = Vector3.UP
	_tri(a_izq, a_der, b_der, n, col)
	_tri(a_izq, b_der, b_izq, n, col)


func superficie() -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_COLOR] = colores
	return arrays


func esta_vacio() -> bool:
	return vertices.is_empty()
