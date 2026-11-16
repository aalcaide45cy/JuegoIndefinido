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
	Construir.cilindro(self, pos + Vector3(0, 1.6, 0), 0.08, 3.2, Color(0.1, 0.1, 0.1), true)
	Construir.caja(self, pos + Vector3(0, 3.3, 0), Vector3(0.35, 0.45, 0.35), Color(1.0, 0.75, 0.4), false, 3.0)
	Construir.luz_noche(self, pos + Vector3(0, 3.2, 0), Color(1.0, 0.7, 0.4), 1.6, 11.0)
