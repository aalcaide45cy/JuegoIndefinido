# barrio.gd
# -----------------------------------------------------------------------------
# Base para un "barrio": un trozo de ciudad que se construye en su propio
# script. La ciudad crece añadiendo barrios uno a uno en mundo.gd, en vez de
# hacer una ciudad enorme de golpe.
#
# Para crear un barrio nuevo:
#   1. Copia barrio_plaza.gd con otro nombre (p. ej. barrio_mercado.gd) y
#      cambia su class_name (p. ej. BarrioMercado).
#   2. Escribe lo que quieras dentro de construir().
#   3. En mundo.gd, añádelo con su posición, por ejemplo:
#        _anadir_barrio(BarrioMercado.new(), Vector3(0, 0, -60))
# -----------------------------------------------------------------------------
class_name Barrio
extends Node3D


func _ready() -> void:
	construir()


# Cada barrio escribe aquí sus edificios, farolas, puertas...
func construir() -> void:
	pass


# Un edificio genérico de cajas: fachada con ventanas, puerta y cornisa.
# Se coloca con la fachada en "pos" mirando hacia "angulo"
# (0 = la fachada mira al sur, +Z; PI = mira al norte; PI/2 = al este; -PI/2 = al oeste).
func edificio(pos: Vector3, angulo: float, ancho: float, fondo: float, alto: float,
		color: Color, rng: RandomNumberGenerator) -> Node3D:
	var casa: Node3D = Node3D.new()
	casa.position = pos
	casa.rotation.y = angulo
	add_child(casa)
	# El bloque principal ocupa de z = -fondo a z = 0 (la fachada está en z = 0).
	Construir.caja(casa, Vector3(0, alto / 2.0, -fondo / 2.0), Vector3(ancho, alto, fondo), color)
	# Cornisa (borde del tejado) un poco más oscura y saliente.
	Construir.caja(casa, Vector3(0, alto + 0.15, -fondo / 2.0 + 0.15),
			Vector3(ancho + 0.3, 0.3, fondo + 0.3), color.darkened(0.4), false)
	# Ventanas: una fila por piso; algunas encendidas (luz cálida), otras a oscuras.
	var pisos: int = int(alto / 3.0)
	var columnas: int = maxi(1, int(ancho / 2.2))
	for piso in range(1, pisos):
		for col in columnas:
			var x: float = (col - (columnas - 1) / 2.0) * (ancho / columnas)
			var encendida: bool = rng.randf() < 0.3
			var color_ventana: Color = Color(1.0, 0.7, 0.35) if encendida else Color(0.05, 0.06, 0.09)
			Construir.caja(casa, Vector3(x, piso * 3.0 + 1.2, 0.05), Vector3(0.9, 1.3, 0.1),
					color_ventana, false, 1.2 if encendida else 0.0)
	# Puerta de madera en la planta baja.
	Construir.caja(casa, Vector3(rng.randf_range(-ancho / 4.0, ancho / 4.0), 1.1, 0.05),
			Vector3(1.1, 2.2, 0.1), Color(0.2, 0.13, 0.09), false)
	return casa


# Un edificio en el que se puede entrar: la planta baja es una habitación de
# verdad (suelo, paredes, techo) y la fachada tiene huecos para la puerta y
# los escaparates. Los pisos de arriba son un bloque macizo.
# Devuelve el nodo del edificio: lo que pongas dentro va en sus coordenadas
# locales (la fachada está en z = 0 y el interior va de z = -fondo a z = 0;
# x va de -ancho/2 a ancho/2).
const ALTO_PLANTA_BAJA: float = 3.5

func edificio_visitable(pos: Vector3, angulo: float, ancho: float, fondo: float, alto: float,
		color: Color, color_interior: Color, huecos: Array) -> Node3D:
	var casa: Node3D = Node3D.new()
	casa.position = pos
	casa.rotation.y = angulo
	add_child(casa)
	var g: float = 0.2   # Grosor de las paredes.
	var h: float = ALTO_PLANTA_BAJA
	# Suelo de madera (un pelín por encima de la calle para que no parpadee).
	# (Los bloques de dentro se encogen para no compartir plano con la fachada
	# ni con las paredes: si dos caras están en el mismo sitio, parpadean.)
	Construir.caja(casa, Vector3(0, 0.015, -fondo / 2.0), Vector3(ancho - 2.0 * g, 0.03, fondo - 2.0 * g), Color(0.24, 0.17, 0.11))
	# Paredes de dentro: fondo y laterales.
	Construir.caja(casa, Vector3(0, h / 2.0, -fondo + g / 2.0), Vector3(ancho, h, g), color_interior)
	Construir.caja(casa, Vector3(-ancho / 2.0 + g / 2.0, h / 2.0, -fondo / 2.0), Vector3(g, h, fondo - 2.0 * g), color_interior)
	Construir.caja(casa, Vector3(ancho / 2.0 - g / 2.0, h / 2.0, -fondo / 2.0), Vector3(g, h, fondo - 2.0 * g), color_interior)
	# Fachada con huecos.
	Construir.pared_con_huecos(casa, -g / 2.0, ancho, h, g, huecos, color)
	# Techo de la planta baja y pisos de arriba (macizos).
	Construir.caja(casa, Vector3(0, h + (alto - h) / 2.0, -fondo / 2.0), Vector3(ancho, alto - h, fondo), color)
	Construir.caja(casa, Vector3(0, h - 0.06, -fondo / 2.0), Vector3(ancho - 2.0 * g, 0.1, fondo - 2.0 * g), color_interior.darkened(0.5), false)
	Construir.caja(casa, Vector3(0, alto + 0.15, -fondo / 2.0 + 0.15),
			Vector3(ancho + 0.3, 0.3, fondo + 0.3), color.darkened(0.4), false)
	# Ventanas de los pisos de arriba, a oscuras.
	var pisos: int = int(alto / 3.0)
	var columnas: int = maxi(1, int(ancho / 2.2))
	for piso in range(1, pisos):
		for col in columnas:
			var x: float = (col - (columnas - 1) / 2.0) * (ancho / columnas)
			Construir.caja(casa, Vector3(x, piso * 3.0 + 1.5, 0.05), Vector3(0.9, 1.3, 0.1),
					Color(0.05, 0.06, 0.09), false)
	return casa


# Una fila de edificios de "desde" a "hasta" (en el eje local X de la fila).
func fila_edificios(origen: Vector3, angulo: float, desde: float, hasta: float,
		fondo: float, rng: RandomNumberGenerator) -> void:
	var colores: Array[Color] = [Color(0.33, 0.29, 0.26), Color(0.24, 0.26, 0.29),
			Color(0.29, 0.24, 0.24), Color(0.22, 0.22, 0.24), Color(0.27, 0.27, 0.22)]
	var x: float = desde
	var direccion: Vector3 = Basis(Vector3.UP, angulo) * Vector3.RIGHT
	while x < hasta - 0.01:
		var ancho: float = minf(rng.randf_range(5.0, 8.0), hasta - x)
		if hasta - x - ancho < 3.0:
			ancho = hasta - x  # Evita un edificio final demasiado estrecho.
		var alto: float = 3.0 * rng.randi_range(2, 4) + rng.randf_range(0.0, 1.0)
		var centro: Vector3 = origen + direccion * (x + ancho / 2.0)
		edificio(centro, angulo, ancho, fondo, alto, colores[rng.randi() % colores.size()], rng)
		x += ancho


# Una farola: poste, farol que brilla y luz cálida.
func farola(pos: Vector3) -> void:
	# Si hay un modelo descargado (assets/modelos/farola.glb), se usa ese.
	var modelo_farola: bool = Assets.colocar(self, "farola", pos)
	if not modelo_farola:
		Construir.cilindro(self, pos + Vector3(0, 1.6, 0), 0.08, 3.2, Color(0.1, 0.1, 0.1), true)
		Construir.caja(self, pos + Vector3(0, 3.3, 0), Vector3(0.35, 0.45, 0.35), Color(1.0, 0.75, 0.4), false, 3.0)
	Construir.luz_noche(self, pos + Vector3(0, 3.2, 0), Color(1.0, 0.7, 0.4), 1.6, 11.0)


# ------------------------------ Suelo y calles --------------------------------

const ASFALTO: Color = Color(0.13, 0.13, 0.15)

# Suelo en baldosas de 20 x 20 m, de (x0, z0) a (x1, z1) (múltiplos de 20 de
# ancho). Van en baldosas para que cada trozo reciba pocas luces a la vez (el
# renderizador Compatibilidad limita las luces por objeto).
func suelo(x0: float, x1: float, z0: float, z1: float, color: Color = Color(0.17, 0.17, 0.19)) -> void:
	var x: float = x0
	while x < x1 - 0.01:
		var z: float = z0
		while z < z1 - 0.01:
			Construir.caja(self, Vector3(x + 10.0, -0.1, z + 10.0), Vector3(20, 0.2, 20), color)
			z += 20.0
		x += 20.0


# Una calle de asfalto: franja fina y oscura sobre el suelo.
func calle(centro: Vector3, ancho: float, largo: float, a_lo_largo_de_x: bool) -> void:
	var tam: Vector3 = Vector3(largo, 0.01, ancho) if a_lo_largo_de_x else Vector3(ancho, 0.01, largo)
	Construir.caja(self, Vector3(centro.x, 0.006, centro.z), tam, ASFALTO, false)


# Una fila de edificios con huecos: "huecos" es una lista de Vector2(desde, hasta)
# en la coordenada local de la fila (donde van tiendas, casas o calles).
func fila_con_huecos(origen: Vector3, angulo: float, desde: float, hasta: float,
		huecos: Array, fondo: float, rng: RandomNumberGenerator) -> void:
	var ordenados: Array = huecos.duplicate()
	ordenados.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor: float = desde
	for hueco in ordenados:
		if hueco.x > cursor + 0.5:
			fila_edificios(origen, angulo, cursor, hueco.x, fondo, rng)
		cursor = maxf(cursor, hueco.y)
	if hasta > cursor + 0.5:
		fila_edificios(origen, angulo, cursor, hasta, fondo, rng)


# Un edificio grande que cierra el final de una calle.
func tapon_de_calle(centro: Vector3, ancho: float, color: Color = Color(0.2, 0.2, 0.23)) -> void:
	Construir.caja(self, Vector3(centro.x, 5.0, centro.z), Vector3(ancho, 10.0, 4.0), color)


# ---------------------------------- Tiendas -----------------------------------
# Una tienda con interior: mostrador con vendedor al fondo y estantes con
# género. "id_tienda" es el campo "tienda" de scripts/datos/objetos.gd, así
# que lo que se vende sale de ese archivo. La fachada va en "pos" mirando
# hacia "angulo" (igual que edificio_visitable).
func tienda_con_interior(pos: Vector3, angulo: float, titulo: String, id_tienda: String,
		nombre: String, texto_hablar: String, color_cartel: Color,
		color: Color = Color(0.24, 0.22, 0.2), color_interior: Color = Color(0.36, 0.3, 0.26),
		es_instructor: bool = false) -> void:
	var huecos: Array = [
		{"x": 0.0, "ancho": 1.6, "abajo": 0.0, "arriba": 2.5},
		{"x": -3.0, "ancho": 2.8, "abajo": 0.6, "arriba": 2.6, "cristal": true},
		{"x": 3.0, "ancho": 2.8, "abajo": 0.6, "arriba": 2.6, "cristal": true},
	]
	var tienda: Node3D = edificio_visitable(pos, angulo, 10.0, 8.0, 9.0, color, color_interior, huecos)
	Construir.texto(tienda, Vector3(0, 3.05, 0.12), titulo, 90, color_cartel)
	Construir.luz_noche(tienda, Vector3(0, 2.9, 1.2), color_cartel, 1.0, 6.0)
	Construir.luz(tienda, Vector3(0, 3.0, -4.0), Color(1.0, 0.85, 0.6), 1.4, 8.0)
	Construir.caja(tienda, Vector3(0, 0.5, -5.2), Vector3(5.0, 1.0, 0.7), Color(0.3, 0.2, 0.13))
	var vendedor: Tendero = Tendero.new()
	vendedor.tienda = id_tienda
	vendedor.nombre_tienda = nombre
	vendedor.texto_hablar = texto_hablar
	vendedor.es_instructor = es_instructor
	vendedor.position = Vector3(0, 1.0, -5.2)
	tienda.add_child(vendedor)
	Construir.texto(tienda, Vector3(0, 1.25, -4.78), "Pulsa E para comprar", 32, Color(1, 0.92, 0.6))
	# Estantes con el género: una cajita de color por cada objeto que vende.
	var ids: Array = Juego.DatosObjetos.de_tienda(id_tienda)
	for fila in 3:
		var y: float = 0.6 + fila * 0.65
		Construir.caja(tienda, Vector3(0, y, -7.6), Vector3(8.0, 0.05, 0.45), Color(0.25, 0.17, 0.11), false)
		for i in 10:
			var color_obj: Color = Color(0.4, 0.4, 0.4)
			if not ids.is_empty():
				color_obj = Juego.DatosObjetos.datos(ids[(fila * 10 + i) % ids.size()])["color"]
			Construir.caja(tienda, Vector3(-3.6 + i * 0.8, y + 0.15, -7.6), Vector3(0.3, 0.25, 0.25), color_obj, false)


# --------------------------- Viviendas en alquiler ----------------------------
# Una casa con puerta, cartel de alquiler, cama, cocina con grifo, estantería,
# caldero, ventanilla de venta y huecos para macetas. Cada casa tiene su
# "id_casa" (para saber si la tienes alquilada) y su precio.
func vivienda(id_casa: String, precio: int, pos: Vector3, angulo: float,
		color: Color = Color(0.3, 0.26, 0.24), color_interior: Color = Color(0.42, 0.36, 0.3)) -> void:
	# En coordenadas de la casa: x va de -5 a 5 a lo largo de la fachada, y el
	# interior va de z = 0 (fachada) a z = -8 (pared del fondo).
	var huecos: Array = [
		{"x": -3.0, "ancho": PuertaCasa.ANCHO, "abajo": 0.0, "arriba": PuertaCasa.ALTO},
		{"x": 1.5, "ancho": 2.0, "abajo": 1.0, "arriba": 2.3, "cristal": true},
	]
	var casa: Node3D = edificio_visitable(pos, angulo, 10.0, 8.0, 7.0, color, color_interior, huecos)

	# Cartel de alquiler encima de la puerta.
	var cartel: Label3D = Construir.texto(casa, Vector3(-3.0, 2.75, 0.12),
			"SE ALQUILA  %d $" % precio, 56, Color(1.0, 0.85, 0.5))
	# Farolillo junto a la puerta.
	Construir.caja(casa, Vector3(-4.0, 2.4, 0.15), Vector3(0.2, 0.3, 0.2), Color(1.0, 0.75, 0.4), false, 3.0)
	Construir.luz_noche(casa, Vector3(-4.0, 2.4, 0.6), Color(1.0, 0.7, 0.4), 0.9, 5.0)
	var puerta: PuertaCasa = PuertaCasa.new()
	puerta.id_casa = id_casa
	puerta.precio = precio
	puerta.position = Vector3(-3.0, 1.0, -0.1)
	puerta.cartel = cartel
	casa.add_child(puerta)

	# Luz de dentro (una lámpara de aceite) y una alfombra.
	Construir.luz(casa, Vector3(0, 3.0, -4.0), Color(1.0, 0.75, 0.45), 1.2, 8.0)
	Construir.caja(casa, Vector3(0, 0.035, -4.0), Vector3(3.0, 0.01, 2.0), Color(0.35, 0.12, 0.12), false)

	# Ventanilla de venta: el mostrador está detrás del cristal y el cliente fuera.
	Construir.caja(casa, Vector3(1.5, 0.5, -0.55), Vector3(2.0, 1.0, 0.6), Color(0.3, 0.2, 0.13))
	var mostrador: Mostrador = Mostrador.new()
	mostrador.id_casa = id_casa
	mostrador.position = Vector3(1.5, 1.0, -0.55)
	mostrador.posicion_cliente = Vector3(0, -1.0, 1.5)
	mostrador.giro_cliente = 0.0   # Mira hacia dentro de la casa.
	casa.add_child(mostrador)

	var cocina: Muebles.Grifo = Muebles.Grifo.new()
	cocina.position = Vector3(3.2, 0, -7.45)
	casa.add_child(cocina)

	var estanteria: Muebles.Estanteria = Muebles.Estanteria.new()
	estanteria.position = Vector3(0.2, 0, -7.6)
	casa.add_child(estanteria)

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
