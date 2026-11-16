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
	Construir.luz(self, pos + Vector3(0, 3.2, 0), Color(1.0, 0.7, 0.4), 1.6, 11.0)
