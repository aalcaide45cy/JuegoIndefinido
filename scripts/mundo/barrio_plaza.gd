# barrio_plaza.gd
# -----------------------------------------------------------------------------
# Primer barrio: la Plaza del Ahorcado. Una plaza cuadrada de 40 x 40 metros
# rodeada de casas, con una fuente seca en el centro, farolas y, en el lado
# norte, tu herboristería (la de la puerta verde).
#
# El centro de la plaza es el punto (0, 0, 0). El norte es -Z.
# -----------------------------------------------------------------------------
class_name BarrioPlaza
extends Barrio

const MITAD: float = 20.0   # La plaza va de -20 a 20 en X y en Z.
const FONDO_CASAS: float = 8.0


func construir() -> void:
	# Semilla fija: las casas salen siempre iguales (cámbiala para otra plaza).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1666

	# Suelo de adoquines oscuros.
	Construir.caja(self, Vector3(0, -0.1, 0), Vector3(80, 0.2, 80), Color(0.17, 0.17, 0.19))
	# Un "camino" algo más claro que cruza la plaza.
	Construir.caja(self, Vector3(0, 0.005, 0), Vector3(4, 0.01, 2 * MITAD), Color(0.22, 0.21, 0.21), false)

	# Casas alrededor. Norte con un hueco en el centro para la herboristería.
	var e: float = MITAD + FONDO_CASAS
	fila_edificios(Vector3(0, 0, -MITAD), 0.0, -e, -4.0, FONDO_CASAS, rng)
	fila_edificios(Vector3(0, 0, -MITAD), 0.0, 4.0, e, FONDO_CASAS, rng)
	fila_edificios(Vector3(0, 0, MITAD), PI, -e, e, FONDO_CASAS, rng)
	fila_edificios(Vector3(MITAD, 0, 0), -PI / 2.0, -MITAD, MITAD, FONDO_CASAS, rng)
	fila_edificios(Vector3(-MITAD, 0, 0), PI / 2.0, -MITAD, MITAD, FONDO_CASAS, rng)

	_herboristeria()
	_fuente()

	farola(Vector3(-10, 0, -10))
	farola(Vector3(10, 0, -10))
	farola(Vector3(-10, 0, 10))
	farola(Vector3(10, 0, 10))

	# Carteles del Prefecto en la pared este: la magia está prohibida.
	var cartel: Label3D = Construir.texto(self, Vector3(MITAD - 0.1, 2.2, -5),
			"POR DECRETO DEL PREFECTO\nQueda prohibida toda magia,\nalquimia y brebaje.\nSe pagan 50 monedas por cada bruja.",
			80, Color(0.85, 0.8, 0.65))
	cartel.rotation.y = -PI / 2.0


func _herboristeria() -> void:
	# Edificio de 8 m de ancho en el hueco norte, con la fachada en z = -20.
	var z: float = -MITAD
	var color: Color = Color(0.2, 0.24, 0.2)
	Construir.caja(self, Vector3(0, 4.5, z - FONDO_CASAS / 2.0), Vector3(8, 9, FONDO_CASAS), color)
	Construir.caja(self, Vector3(0, 9.15, z - FONDO_CASAS / 2.0 + 0.15), Vector3(8.3, 0.3, FONDO_CASAS + 0.3),
			color.darkened(0.4), false)
	# Escaparate con frascos que brillan y la puerta verde.
	Construir.caja(self, Vector3(-2.3, 1.5, z + 0.05), Vector3(2.4, 1.6, 0.1), Color(0.3, 0.55, 0.35), false, 0.8)
	Construir.caja(self, Vector3(2.3, 1.5, z + 0.05), Vector3(2.4, 1.6, 0.1), Color(0.3, 0.55, 0.35), false, 0.8)
	Construir.caja(self, Vector3(0, 1.15, z + 0.05), Vector3(1.3, 2.3, 0.12), Color(0.1, 0.35, 0.18), false, 0.4)
	# Ventanas de arriba (tu casa).
	for x in [-2.3, 0.0, 2.3]:
		Construir.caja(self, Vector3(x, 4.5, z + 0.05), Vector3(0.9, 1.3, 0.1), Color(0.05, 0.06, 0.09), false)
		Construir.caja(self, Vector3(x, 7.5, z + 0.05), Vector3(0.9, 1.3, 0.1), Color(0.05, 0.06, 0.09), false)
	Construir.texto(self, Vector3(0, 3.0, z + 0.12), "HERBORISTERÍA\nLa Mandrágora Honrada", 120,
			Color(0.6, 0.9, 0.6))
	Construir.luz(self, Vector3(0, 2.8, z + 1.2), Color(0.5, 1.0, 0.6), 1.2, 6.0)

	# La puerta de verdad: te lleva al interior.
	Puerta.crear(self, Vector3(0, 1.0, z + 0.3), "Entrar en la herboristería",
			InteriorHerboristeria.ENTRADA_TIENDA, 0.0)


func _fuente() -> void:
	# Fuente seca (el agua mágica también se prohibió).
	Construir.cilindro(self, Vector3(0, 0.35, 0), 2.6, 0.7, Color(0.3, 0.3, 0.32), true)
	Construir.cilindro(self, Vector3(0, 0.72, 0), 2.3, 0.05, Color(0.1, 0.1, 0.11))
	Construir.cilindro(self, Vector3(0, 1.5, 0), 0.35, 1.6, Color(0.32, 0.32, 0.34), true)
	# Una estatua decapitada: el último alquimista de la ciudad.
	Construir.caja(self, Vector3(0, 2.8, 0), Vector3(0.7, 1.0, 0.4), Color(0.36, 0.36, 0.38), false)
	Construir.texto(self, Vector3(0, 0.45, 2.62), "Aquí ardió el último alquimista. Que sirva de lección.",
			40, Color(0.7, 0.7, 0.7))
