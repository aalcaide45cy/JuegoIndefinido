# barrio_plaza.gd
# -----------------------------------------------------------------------------
# Primer barrio: la Plaza del Ahorcado. Una plaza cuadrada de 40 x 40 metros
# rodeada de casas, con una fuente seca en el centro y farolas.
#   - Norte: la herboristería, donde se compra todo (se entra andando).
#   - Este:  la casa con el cartel SE ALQUILA, que puede ser tu escondite.
#
# El centro de la plaza es el punto (0, 0, 0). El norte es -Z.
# -----------------------------------------------------------------------------
class_name BarrioPlaza
extends Barrio

const MITAD: float = 20.0   # La plaza va de -20 a 20 en X y en Z.
const FONDO_CASAS: float = 8.0
const ANCHO_HERBORISTERIA: float = 10.0
const ANCHO_VIVIENDA: float = 10.0


func construir() -> void:
	# Semilla fija: las casas salen siempre iguales (cámbiala para otra plaza).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1666

	_suelo()

	# Casas alrededor, con huecos para la herboristería (norte) y tu casa (este).
	var e: float = MITAD + FONDO_CASAS
	var h: float = ANCHO_HERBORISTERIA / 2.0
	var v: float = ANCHO_VIVIENDA / 2.0
	fila_edificios(Vector3(0, 0, -MITAD), 0.0, -e, -h, FONDO_CASAS, rng)
	fila_edificios(Vector3(0, 0, -MITAD), 0.0, h, e, FONDO_CASAS, rng)
	fila_edificios(Vector3(0, 0, MITAD), PI, -e, e, FONDO_CASAS, rng)
	fila_edificios(Vector3(MITAD, 0, 0), -PI / 2.0, -MITAD, -v, FONDO_CASAS, rng)
	fila_edificios(Vector3(MITAD, 0, 0), -PI / 2.0, v, MITAD, FONDO_CASAS, rng)
	fila_edificios(Vector3(-MITAD, 0, 0), PI / 2.0, -MITAD, MITAD, FONDO_CASAS, rng)

	_herboristeria()
	_vivienda()
	_fuente()

	farola(Vector3(-10, 0, -10))
	farola(Vector3(10, 0, -10))
	farola(Vector3(-10, 0, 10))
	farola(Vector3(10, 0, 12))

	# Cartel del Prefecto en la pared oeste: la magia está prohibida.
	var cartel: Label3D = Construir.texto(self, Vector3(-MITAD + 0.12, 2.2, 4),
			"POR DECRETO DEL PREFECTO\nQueda prohibida toda magia,\nalquimia y brebaje.\nSe pagan 50 $ por cada bruja.",
			80, Color(0.85, 0.8, 0.65))
	cartel.rotation.y = PI / 2.0


# El suelo va en baldosas de 20 x 20 m: así cada trozo solo recibe la luz de
# las farolas cercanas (el renderizador Compatibilidad limita las luces por objeto).
func _suelo() -> void:
	for ix in range(-2, 2):
		for iz in range(-2, 2):
			Construir.caja(self, Vector3(ix * 20 + 10, -0.1, iz * 20 + 10), Vector3(20, 0.2, 20),
					Color(0.17, 0.17, 0.19))
	# Un "camino" algo más claro que cruza la plaza.
	Construir.caja(self, Vector3(0, 0.005, 0), Vector3(4, 0.01, 2 * MITAD), Color(0.22, 0.21, 0.21), false)
	Construir.caja(self, Vector3(10, 0.006, 0), Vector3(20, 0.01, 4), Color(0.22, 0.21, 0.21), false)


# ------------------------------ La herboristería ------------------------------

func _herboristeria() -> void:
	# Fachada en z = -20 mirando al sur (ángulo 0). Puerta en medio y dos escaparates.
	var huecos: Array = [
		{"x": 0.0, "ancho": 1.6, "abajo": 0.0, "arriba": 2.5},
		{"x": -3.0, "ancho": 2.8, "abajo": 0.6, "arriba": 2.6, "cristal": true},
		{"x": 3.0, "ancho": 2.8, "abajo": 0.6, "arriba": 2.6, "cristal": true},
	]
	var tienda: Node3D = edificio_visitable(Vector3(0, 0, -MITAD), 0.0, ANCHO_HERBORISTERIA, FONDO_CASAS, 9.0,
			Color(0.2, 0.24, 0.2), Color(0.35, 0.3, 0.22), huecos)
	Construir.texto(tienda, Vector3(0, 3.05, 0.12), "HERBORISTERÍA  La Mandrágora Honrada", 90,
			Color(0.6, 0.9, 0.6))
	Construir.luz(tienda, Vector3(0, 2.9, 1.2), Color(0.5, 1.0, 0.6), 1.0, 6.0)

	# Dentro: luz cálida, mostrador con el herbolario y estanterías de frascos.
	Construir.luz(tienda, Vector3(0, 3.0, -4.0), Color(1.0, 0.8, 0.5), 1.4, 8.0)
	Construir.caja(tienda, Vector3(0, 0.5, -5.2), Vector3(5.0, 1.0, 0.7), Color(0.3, 0.2, 0.13))
	var tendero: Tendero = Tendero.new()
	tendero.position = Vector3(0, 1.0, -5.2)
	tienda.add_child(tendero)
	Construir.texto(tienda, Vector3(0, 1.25, -4.84), "Pulsa E para comprar", 32, Color(1, 0.92, 0.6))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for fila in 4:
		var y: float = 0.6 + fila * 0.55
		Construir.caja(tienda, Vector3(0, y, -7.6), Vector3(8.0, 0.05, 0.45), Color(0.25, 0.17, 0.11), false)
		for i in 12:
			var color: Color = Color.from_hsv(rng.randf(), 0.5, 0.6)
			Construir.cilindro(tienda, Vector3(-3.6 + i * 0.65, y + 0.15, -7.6), 0.08, 0.25, color, false, 0.6)
	# Sacos de tierra y abono junto a la pared (decoración).
	for i in 3:
		Construir.caja(tienda, Vector3(-4.2, 0.3, -1.5 - i * 0.8), Vector3(0.7, 0.6, 0.5), Color(0.4, 0.32, 0.2))
		Construir.caja(tienda, Vector3(4.2, 0.3, -1.5 - i * 0.8), Vector3(0.7, 0.6, 0.5), Color(0.3, 0.25, 0.2))
	# Ramos de hierbas colgando del techo.
	for i in 5:
		Construir.cilindro(tienda, Vector3(-3 + i * 1.5, 3.1, -3.0), 0.12, 0.5,
				Color(0.3, 0.45, 0.25), false, 0.0, 0.02)


# ------------------------------- Tu casa --------------------------------------

func _vivienda() -> void:
	# En el lado este (x = 20), con la fachada mirando al oeste (ángulo -PI/2).
	# En coordenadas de la casa: x va de -5 a 5 a lo largo de la fachada, y el
	# interior va de z = 0 (fachada) a z = -8 (pared del fondo).
	var huecos: Array = [
		{"x": -3.0, "ancho": PuertaCasa.ANCHO, "abajo": 0.0, "arriba": PuertaCasa.ALTO},
		{"x": 1.5, "ancho": 2.0, "abajo": 1.0, "arriba": 2.3, "cristal": true},
	]
	var casa: Node3D = edificio_visitable(Vector3(MITAD, 0, 0), -PI / 2.0, ANCHO_VIVIENDA, FONDO_CASAS, 7.0,
			Color(0.3, 0.26, 0.24), Color(0.42, 0.36, 0.3), huecos)

	# Cartel de alquiler encima de la puerta.
	var cartel: Label3D = Construir.texto(casa, Vector3(-3.0, 2.75, 0.12),
			"SE ALQUILA  %d $" % GameData.PRECIO_ALQUILER, 56, Color(1.0, 0.85, 0.5))
	# Farolillo junto a la puerta.
	Construir.caja(casa, Vector3(-4.0, 2.4, 0.15), Vector3(0.2, 0.3, 0.2), Color(1.0, 0.75, 0.4), false, 3.0)
	Construir.luz(casa, Vector3(-4.0, 2.4, 0.6), Color(1.0, 0.7, 0.4), 0.9, 5.0)
	var puerta: PuertaCasa = PuertaCasa.new()
	puerta.position = Vector3(-3.0, 1.0, -0.1)
	puerta.cartel = cartel
	casa.add_child(puerta)

	# Luz de dentro (una lámpara de aceite) y una alfombra.
	Construir.luz(casa, Vector3(0, 3.0, -4.0), Color(1.0, 0.75, 0.45), 1.2, 8.0)
	Construir.caja(casa, Vector3(0, 0.035, -4.0), Vector3(3.0, 0.01, 2.0), Color(0.35, 0.12, 0.12), false)

	# Ventanilla de venta: el mostrador está detrás del cristal y el cliente fuera.
	Construir.caja(casa, Vector3(1.5, 0.5, -0.55), Vector3(2.0, 1.0, 0.6), Color(0.3, 0.2, 0.13))
	var mostrador: Mostrador = Mostrador.new()
	mostrador.position = Vector3(1.5, 1.0, -0.55)
	mostrador.posicion_cliente = Vector3(0, -1.0, 1.5)
	mostrador.giro_cliente = 0.0   # Mira hacia dentro de la casa.
	casa.add_child(mostrador)

	# Cocina con grifo (rellena la jarra) contra la pared del fondo.
	var cocina: Muebles.Grifo = Muebles.Grifo.new()
	cocina.position = Vector3(3.2, 0, -7.45)
	casa.add_child(cocina)

	# Estantería para guardar cosas.
	var estanteria: Muebles.Estanteria = Muebles.Estanteria.new()
	estanteria.position = Vector3(0.2, 0, -7.6)
	casa.add_child(estanteria)

	# Cama en la esquina.
	var cama: Muebles.Cama = Muebles.Cama.new()
	cama.position = Vector3(-4.1, 0, -6.6)
	casa.add_child(cama)

	# Caldero y recetario en la pared.
	var caldero: Caldero3D = Caldero3D.new()
	caldero.position = Vector3(3.3, 0, -4.2)
	casa.add_child(caldero)
	var recetas: PackedStringArray = ["RECETARIO (no enseñar a la guardia)"]
	for id_pocion in GameData.POCIONES:
		recetas.append("%s = %s" % [GameData.POCIONES[id_pocion]["nombre"], GameData.texto_receta(id_pocion)])
	var recetario: Label3D = Construir.texto(casa, Vector3(4.88, 1.9, -4.2), "\n".join(recetas), 40,
			Color(0.75, 0.9, 0.7))
	recetario.rotation.y = -PI / 2.0

	# Cinco huecos para macetas junto a la pared izquierda; las dos primeras ya vienen puestas.
	for i in 5:
		var hueco: Muebles.HuecoMaceta = Muebles.HuecoMaceta.new()
		hueco.position = Vector3(-4.4, 0.03, -1.9 - i * 0.8)
		casa.add_child(hueco)
		if i < 2:
			hueco.poner_maceta()


func _fuente() -> void:
	# Fuente seca (el agua mágica también se prohibió).
	Construir.cilindro(self, Vector3(0, 0.35, 0), 2.6, 0.7, Color(0.3, 0.3, 0.32), true)
	Construir.cilindro(self, Vector3(0, 0.72, 0), 2.3, 0.05, Color(0.1, 0.1, 0.11))
	Construir.cilindro(self, Vector3(0, 1.5, 0), 0.35, 1.6, Color(0.32, 0.32, 0.34), true)
	# Una estatua decapitada: el último alquimista de la ciudad.
	Construir.caja(self, Vector3(0, 2.8, 0), Vector3(0.7, 1.0, 0.4), Color(0.36, 0.36, 0.38), false)
	Construir.texto(self, Vector3(0, 0.45, 2.62), "Aquí ardió el último alquimista. Que sirva de lección.",
			40, Color(0.7, 0.7, 0.7))
