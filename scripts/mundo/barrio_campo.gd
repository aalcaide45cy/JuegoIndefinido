# barrio_campo.gd
# -----------------------------------------------------------------------------
# La Zona de Campo: una carretera larga que sale del Barrio Residencial hacia el
# este, con huertos de distintos tamaños a los lados (más grandes = más caros),
# una granja y un cartel de la zona. Se coloca en (200, 0, -16); la carretera va
# a lo largo de X, de x = -100 a x = 100 dentro del barrio (mundo 100 a 300).
# Alquilar/comprar los huertos llegará con la inmobiliaria. SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name BarrioCampo
extends Barrio

const HUERTOS: Array = [
	# x (a lo largo de la carretera), lado (-1 norte, +1 sur), ancho, fondo, precio de alquiler
	{"x": -70.0, "lado": -1, "ancho": 12.0, "fondo": 12.0, "precio": 80, "id": "huerto_a"},
	{"x": -70.0, "lado": 1, "ancho": 12.0, "fondo": 12.0, "precio": 80, "id": "huerto_b"},
	{"x": -42.0, "lado": -1, "ancho": 18.0, "fondo": 16.0, "precio": 180, "id": "huerto_c"},
	{"x": -42.0, "lado": 1, "ancho": 18.0, "fondo": 16.0, "precio": 180, "id": "huerto_d"},
	{"x": -8.0, "lado": -1, "ancho": 26.0, "fondo": 22.0, "precio": 400, "id": "huerto_e"},
	{"x": -8.0, "lado": 1, "ancho": 26.0, "fondo": 22.0, "precio": 400, "id": "huerto_f"},
	{"x": 36.0, "lado": -1, "ancho": 34.0, "fondo": 30.0, "precio": 900, "id": "huerto_g"},
	{"x": 36.0, "lado": 1, "ancho": 34.0, "fondo": 30.0, "precio": 900, "id": "huerto_h"},
]
const COLOR_HIERBA: Color = Color(0.2, 0.32, 0.16)
const COLOR_TIERRA: Color = Color(0.22, 0.14, 0.09)
const COLOR_VALLA: Color = Color(0.4, 0.28, 0.17)


func construir() -> void:
	suelo(-100, 100, -60, 60, COLOR_HIERBA)
	calle(Vector3(0, 0, 0), 8.0, 200.0, true)
	for h in HUERTOS:
		_huerto(h)
	_granja(Vector3(78, 0, -22))
	tapon_de_calle(Vector3(98, 0, 0), 14.0, Color(0.2, 0.2, 0.23), true)
	var cartel: Label3D = Construir.texto(self, Vector3(95.9, 6.0, 0), "ZONA DE CAMPO", 160, Color(0.7, 0.85, 0.6))
	cartel.rotation.y = -PI / 2.0
	for i in 9:
		farola(Vector3(-90.0 + i * 22.0, 0, -4.4))


# Un huerto: tierra con surcos, valla con una entrada hacia la carretera y un cartel con su precio.
func _huerto(h: Dictionary) -> void:
	var lado: float = float(h["lado"])
	var ancho: float = h["ancho"]
	var fondo: float = h["fondo"]
	var cx: float = h["x"]
	var cz: float = lado * (6.0 + fondo / 2.0)
	Construir.caja(self, Vector3(cx, 0.02, cz), Vector3(ancho - 1.0, 0.04, fondo - 1.0), COLOR_TIERRA, false)
	# Surcos.
	var n: int = int((fondo - 3.0) / 1.5)
	for i in n:
		var z: float = cz - (fondo - 3.0) / 2.0 + i * 1.5
		Construir.caja(self, Vector3(cx, 0.07, z), Vector3(ancho - 3.0, 0.08, 0.5), COLOR_TIERRA.lightened(0.12), false)
	# Valla: tres lados enteros y el lado de la carretera con una entrada de 3 m.
	var z_lejos: float = cz + lado * fondo / 2.0
	var z_cerca: float = cz - lado * fondo / 2.0
	_valla(Vector3(cx - ancho / 2.0, 0.5, cz), Vector3(0.12, 1.0, fondo))
	_valla(Vector3(cx + ancho / 2.0, 0.5, cz), Vector3(0.12, 1.0, fondo))
	_valla(Vector3(cx, 0.5, z_lejos), Vector3(ancho, 1.0, 0.12))
	var lado_largo: float = (ancho - 3.0) / 2.0
	_valla(Vector3(cx - 1.5 - lado_largo / 2.0, 0.5, z_cerca), Vector3(lado_largo, 1.0, 0.12))
	_valla(Vector3(cx + 1.5 + lado_largo / 2.0, 0.5, z_cerca), Vector3(lado_largo, 1.0, 0.12))
	# Cartel junto a la entrada, mirando a la carretera.
	var pos_cartel: Vector3 = Vector3(cx + 2.4, 1.6, z_cerca)
	Construir.cilindro(self, Vector3(pos_cartel.x, 0.8, z_cerca), 0.05, 1.6, COLOR_VALLA, false)
	var t: Label3D = Construir.texto(self, pos_cartel + Vector3(0, 0.2, 0),
			"HUERTO %d m²\n%d $ al mes" % [int(ancho * fondo), h["precio"]], 44, Color(0.85, 1.0, 0.7))
	t.rotation.y = 0.0 if lado < 0.0 else PI
	var puerta: Node3D = Node3D.new()
	puerta.position = Vector3(cx, 0, z_cerca)
	add_child(puerta)
	registrar_poi(puerta, "Huerto %d m² (%d $)" % [int(ancho * fondo), h["precio"]], Color(0.6, 0.9, 0.4))


func _valla(pos: Vector3, tam: Vector3) -> void:
	Construir.caja(self, pos, tam, COLOR_VALLA, true)


# Una granja sencilla: establo rojo con tejado y un silo.
func _granja(pos: Vector3) -> void:
	Construir.caja(self, pos + Vector3(0, 2.0, 0), Vector3(12.0, 4.0, 9.0), Color(0.5, 0.15, 0.12), true)
	Construir.caja(self, pos + Vector3(0, 4.4, 0), Vector3(12.6, 0.8, 9.6), Color(0.28, 0.2, 0.15), false)
	Construir.caja(self, pos + Vector3(0, 1.3, 4.55), Vector3(3.0, 2.6, 0.12), Color(0.25, 0.16, 0.1), false)
	Construir.cilindro(self, pos + Vector3(10.0, 3.5, 0), 2.0, 7.0, Color(0.55, 0.55, 0.58), true)
	Construir.texto(self, pos + Vector3(0, 5.5, 4.7), "GRANJA", 80, Color(0.95, 0.9, 0.8))
	var g: Node3D = Node3D.new()
	g.position = pos
	add_child(g)
	registrar_poi(g, "Granja", Color(0.9, 0.5, 0.3))
