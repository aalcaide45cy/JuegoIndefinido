# barrio_plaza.gd
# -----------------------------------------------------------------------------
# Primer barrio: la Plaza del Ahorcado. Una plaza cuadrada de 40 x 40 metros
# rodeada de casas, con una fuente seca en el centro y farolas.
#   - Norte: la herboristería, donde se compra todo (se entra andando).
#   - Este:  la casa con el cartel SE ALQUILA, que puede ser tu escondite.
#   - Oeste: la ferretería. Sur: la armería.
#   - Tres calles salen de la plaza: norte (Mercado), este (Barrio Residencial)
#     y sur (Zona Industrial).
#
# El centro de la plaza es el punto (0, 0, 0). El norte es -Z.
# -----------------------------------------------------------------------------
class_name BarrioPlaza
extends Barrio

const Propiedades = preload("res://scripts/datos/propiedades.gd")

const MITAD: float = 20.0   # La plaza va de -20 a 20 en X y en Z.
const FONDO_CASAS: float = 8.0
const ANCHO_HERBORISTERIA: float = 10.0
const ANCHO_VIVIENDA: float = 10.0
const ANCHO_TIENDA: float = 10.0


func construir() -> void:
	# Semilla fija: las casas salen siempre iguales (cámbiala para otra plaza).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1666

	_suelo()

	# Casas alrededor, con huecos para la herboristería (norte) y tu casa (este).
	var e: float = MITAD + FONDO_CASAS
	var h: float = ANCHO_HERBORISTERIA / 2.0
	var v: float = ANCHO_VIVIENDA / 2.0
	# Calles que salen de la plaza (de 8 m de ancho): al norte hacia el Mercado,
	# al este hacia el barrio residencial y al sur hacia la zona industrial.
	var calle_norte: Vector2 = Vector2(12.0, 20.0)      # En X (fila norte).
	var calle_sur: Vector2 = Vector2(12.0, 20.0)        # En -X (la fila sur está girada).
	var calle_este: Vector2 = Vector2(-20.0, -12.0)     # En Z (fila este).
	fila_con_huecos(Vector3(0, 0, -MITAD), 0.0, -e, e,
			[Vector2(-h, h), calle_norte], FONDO_CASAS, rng)
	var t: float = ANCHO_TIENDA / 2.0
	fila_con_huecos(Vector3(0, 0, MITAD), PI, -e, e,
			[Vector2(-t, t), calle_sur], FONDO_CASAS, rng)
	fila_con_huecos(Vector3(MITAD, 0, 0), -PI / 2.0, -MITAD, MITAD,
			[Vector2(-v, v), calle_este], FONDO_CASAS, rng)
	fila_con_huecos(Vector3(-MITAD, 0, 0), PI / 2.0, -MITAD, MITAD,
			[Vector2(-t, t)], FONDO_CASAS, rng)
	# Asfalto de las tres salidas.
	calle(Vector3(16, 0, -MITAD - 4), 8.0, 8.0, false)
	calle(Vector3(MITAD + 4, 0, -16), 8.0, 8.0, true)
	calle(Vector3(-16, 0, MITAD + 4), 8.0, 8.0, false)

	_herboristeria()
	vivienda("plaza", int(Propiedades.ficha("plaza")["alquiler"]), Vector3(MITAD, 0, 0), -PI / 2.0)
	tienda_con_interior(Vector3(-MITAD, 0, 0), PI / 2.0, "FERRETERÍA  Clavo y Martillo", "ferreteria",
			"Ferretería Clavo y Martillo", "Hablar con el ferretero (comprar)", Color(1.0, 0.8, 0.4))
	tienda_con_interior(Vector3(0, 0, MITAD), PI, "ARMERÍA  El Último Recurso", "armeria",
			"Armería El Último Recurso", "Hablar con el armero (comprar)", Color(1.0, 0.5, 0.4))
	_fuente()
	var inmo: InmobiliariaMostrador = InmobiliariaMostrador.new()
	inmo.position = Vector3(-7.5, 0, -9)   # (A (-10,-10) tapaba el camino de patrulla de los guardias por la plaza.)
	add_child(inmo)
	registrar_poi(inmo, "Inmobiliaria", Color(0.5, 0.75, 1.0))
	var bolsa: OficinaEmpleo = OficinaEmpleo.new()
	bolsa.position = Vector3(7.5, 0, -9)   # (A (-6.5,-12.5) tapaba el camino de patrulla de los guardias.)
	add_child(bolsa)
	registrar_poi(bolsa, "Bolsa de trabajo", Color(1.0, 0.9, 0.5))
	_decorar_plaza()
	_guardia([Vector3(-12, 0, -12), Vector3(12, 0, -12), Vector3(12, 0, 12), Vector3(-12, 0, 12)])

	farola(Vector3(-10, 0, -10))
	farola(Vector3(10, 0, -10))
	farola(Vector3(-10, 0, 10))
	farola(Vector3(10, 0, 12))

	# Cartel del Prefecto en la pared oeste: la magia está prohibida.
	var cartel: Label3D = Construir.texto(self, Vector3(-MITAD + 0.12, 2.2, 12),
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
	cartel_tienda(tienda, "HERBORISTERÍA  La Mandrágora Honrada", Color(0.6, 0.9, 0.6))
	registrar_poi(tienda, "Herboristería", Color(0.6, 0.9, 0.6))
	Construir.luz_noche(tienda, Vector3(0, 2.9, 1.2), Color(0.5, 1.0, 0.6), 1.0, 6.0)

	# Dentro: luz cálida, mostrador con el herbolario y estanterías de frascos.
	Construir.luz(tienda, Vector3(0, 3.0, -4.0), Color(1.0, 0.8, 0.5), 1.4, 8.0)
	Construir.caja(tienda, Vector3(0, 0.5, -5.2), Vector3(5.0, 1.0, 0.7), Color(0.3, 0.2, 0.13))
	var tendero: Tendero = Tendero.new()
	tendero.position = Vector3(0, 1.0, -5.2)
	tienda.add_child(tendero)
	Construir.texto(tienda, Vector3(0, 1.25, -4.78), "Pulsa E para comprar", 32, Color(1, 0.92, 0.6))

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
		Construir.cilindro(tienda, Vector3(-3 + i * 1.5, 2.9, -3.0), 0.12, 0.5,
				Color(0.3, 0.45, 0.25), false, 0.0, 0.02)
	decorar_tienda(tienda)


# Objetos sueltos por la plaza (del kit "Fantasy Props" y "Medieval Village"):
# bancos junto a la fuente, un carro, barriles, cajas y un puesto de mercado.
func _decorar_plaza() -> void:
	for p in [Vector3(5, 0, 5), Vector3(-5, 0, 5), Vector3(5, 0, -5), Vector3(-5, 0, -5)]:
		prop(self, "Bench", p, atan2(-p.x, -p.z), 1.0, true)
	Assets.colocar_solido(self, PUEBLO + "Prop_Wagon", Vector3(-14, 0, 13), 0.5)
	for i in 3:
		prop(self, "Barrel", Vector3(14 + i * 0.8, 0, 15), i, 1.0, true)
	prop(self, "Crate_Wooden", Vector3(-15, 0, -14), 0.2, 1.0, true)
	prop(self, "Crate_Wooden", Vector3(-15, 0, -12.7), 0.6, 1.0, true)
	prop(self, "Stall_Empty", Vector3(-14, 0, -3), PI / 2.0, 1.0, true)
	prop(self, "Stall_Empty", Vector3(14, 0, 4), -PI / 2.0, 1.0, true)
	prop(self, "Dummy", Vector3(10, 0, 8), -PI / 2.0, 1.0, true)


# Un guardia del Prefecto que patrulla la plaza de noche (puntos en coordenadas de la plaza).
func _guardia(puntos: Array) -> void:
	var guardia: Guardia = Guardia.new()
	var ruta: Array[Vector3] = []
	for p in puntos:
		ruta.append(to_global(p))
	guardia.ruta = ruta
	add_child(guardia)


func _fuente() -> void:
	# Fuente seca (el agua mágica también se prohibió).
	Construir.cilindro(self, Vector3(0, 0.35, 0), 2.6, 0.7, Color(0.3, 0.3, 0.32), true)
	Construir.cilindro(self, Vector3(0, 0.72, 0), 2.3, 0.05, Color(0.1, 0.1, 0.11))
	Construir.cilindro(self, Vector3(0, 1.5, 0), 0.35, 1.6, Color(0.32, 0.32, 0.34), true)
	# Una estatua decapitada: el último alquimista de la ciudad.
	Construir.caja(self, Vector3(0, 2.8, 0), Vector3(0.7, 1.0, 0.4), Color(0.36, 0.36, 0.38), false)
	Construir.texto(self, Vector3(0, 0.45, 2.68), "Aquí ardió el último alquimista. Que sirva de lección.",
			40, Color(0.7, 0.7, 0.7))
