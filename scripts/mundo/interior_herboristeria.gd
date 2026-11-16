# interior_herboristeria.gd
# -----------------------------------------------------------------------------
# El interior de tu herboristería y el sótano secreto.
#
# Truco: los interiores están lejos de la plaza (en X = 200), escondidos dentro
# de cajas cerradas. Las puertas te "teletransportan" con un fundido a negro.
#
#   TIENDA (planta baja): macetas, mostrador con clientes y una trampilla.
#   SÓTANO (secreto):     el caldero y el recetario.
# -----------------------------------------------------------------------------
class_name InteriorHerboristeria
extends Barrio

const ORIGEN_TIENDA: Vector3 = Vector3(200, 0, 0)
const ORIGEN_SOTANO: Vector3 = Vector3(200, 0, 40)
# Dónde aparece el jugador al entrar desde la plaza.
const ENTRADA_TIENDA: Vector3 = ORIGEN_TIENDA + Vector3(0, 0, 2.6)
# Dónde aparece al salir a la plaza (delante de la puerta verde).
const SALIDA_PLAZA: Vector3 = Vector3(0, 0, -18.3)


func construir() -> void:
	_tienda()
	_sotano()


func _tienda() -> void:
	var o: Vector3 = ORIGEN_TIENDA
	_habitacion(o, Vector3(10, 3.5, 8), Color(0.32, 0.25, 0.18), Color(0.25, 0.2, 0.15))
	# Luz cálida de velas.
	Construir.luz(self, o + Vector3(0, 3.0, 0), Color(1.0, 0.75, 0.45), 1.3, 10.0)
	Construir.luz(self, o + Vector3(-3.5, 2.5, 0.5), Color(1.0, 0.7, 0.4), 0.7, 5.0)

	# Puerta para volver a la plaza (pared sur).
	Construir.caja(self, o + Vector3(0, 1.1, 3.94), Vector3(1.2, 2.2, 0.1), Color(0.1, 0.35, 0.18), false, 0.3)
	Puerta.crear(self, o + Vector3(0, 1.0, 3.6), "Salir a la plaza", SALIDA_PLAZA, PI)

	# Banco con tres macetas (pared oeste).
	Construir.caja(self, o + Vector3(-4.4, 0.4, 0.5), Vector3(0.9, 0.8, 4.2), Color(0.28, 0.18, 0.12))
	for z in [-0.9, 0.5, 1.9]:
		var maceta: Maceta3D = Maceta3D.new()
		maceta.position = o + Vector3(-4.4, 0.8, z)
		add_child(maceta)
	var cartel_macetas: Label3D = Construir.texto(self, o + Vector3(-4.94, 2.2, 0.5),
			"Hierbas medicinales\n(y alguna que otra no tanto)", 36)
	cartel_macetas.rotation.y = PI / 2.0

	# Mostrador (pared este). Los clientes esperan detrás, junto a la pared.
	Construir.caja(self, o + Vector3(3.0, 0.525, 0.5), Vector3(0.8, 1.05, 3.5), Color(0.3, 0.2, 0.13))
	var mostrador: Mostrador = Mostrador.new()
	mostrador.position = o + Vector3(3.0, 1.05, 0.5)
	add_child(mostrador)

	# Estanterías con frascos en la pared norte (solo decoración).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for fila in 3:
		var y: float = 0.9 + fila * 0.7
		Construir.caja(self, o + Vector3(1.5, y, -3.75), Vector3(4.5, 0.06, 0.4), Color(0.25, 0.17, 0.11), false)
		for i in 7:
			var color: Color = Color.from_hsv(rng.randf(), 0.5, 0.6)
			Construir.cilindro(self, o + Vector3(-0.3 + i * 0.6, y + 0.15, -3.75), 0.08, 0.25,
					color, false, 0.6)

	# Trampilla al sótano (esquina noroeste), bajo una alfombra raída.
	Construir.caja(self, o + Vector3(-3.5, 0.02, -2.8), Vector3(1.2, 0.04, 1.2), Color(0.15, 0.1, 0.07), false)
	Construir.caja(self, o + Vector3(-3.5, 0.045, -2.3), Vector3(0.4, 0.02, 0.06), Color(0.5, 0.45, 0.3), false, 0.3)
	Puerta.crear(self, o + Vector3(-3.5, 0.3, -2.8), "Bajar por la trampilla al sótano",
			ORIGEN_SOTANO + Vector3(0, 0, 2.4), 0.0)


func _sotano() -> void:
	var o: Vector3 = ORIGEN_SOTANO
	_habitacion(o, Vector3(8, 3.0, 8), Color(0.2, 0.2, 0.22), Color(0.15, 0.15, 0.16))
	Construir.luz(self, o + Vector3(2.5, 2.4, 2.5), Color(0.9, 0.6, 0.35), 0.4, 5.0)

	var caldero: Caldero3D = Caldero3D.new()
	caldero.position = o + Vector3(0, 0, -1.3)
	add_child(caldero)

	# Recetario escrito en la pared norte.
	var recetas: PackedStringArray = ["RECETARIO (no enseñar a la guardia)", ""]
	for id_pocion in GameData.POCIONES:
		recetas.append("%s = %s" % [GameData.POCIONES[id_pocion]["nombre"], GameData.texto_receta(id_pocion)])
	Construir.texto(self, o + Vector3(0, 1.9, -3.93), "\n".join(recetas), 60, Color(0.75, 0.9, 0.7))

	# Escalera de mano para volver a la tienda (pared sur).
	for i in 6:
		Construir.caja(self, o + Vector3(0, 0.3 + i * 0.45, 3.9), Vector3(0.8, 0.05, 0.05), Color(0.35, 0.25, 0.15), false)
	Construir.caja(self, o + Vector3(-0.4, 1.5, 3.9), Vector3(0.06, 3.0, 0.06), Color(0.35, 0.25, 0.15), false)
	Construir.caja(self, o + Vector3(0.4, 1.5, 3.9), Vector3(0.06, 3.0, 0.06), Color(0.35, 0.25, 0.15), false)
	Puerta.crear(self, o + Vector3(0, 1.0, 3.5), "Subir a la tienda",
			ORIGEN_TIENDA + Vector3(-3.5, 0, -1.4), PI)


# Una habitación cerrada: suelo, techo y cuatro paredes sólidas.
func _habitacion(centro: Vector3, tam: Vector3, color_paredes: Color, color_suelo: Color) -> void:
	var g: float = 0.2  # Grosor de paredes.
	Construir.caja(self, centro + Vector3(0, -g / 2.0, 0), Vector3(tam.x, g, tam.z), color_suelo)
	Construir.caja(self, centro + Vector3(0, tam.y + g / 2.0, 0), Vector3(tam.x, g, tam.z), color_paredes.darkened(0.5))
	Construir.caja(self, centro + Vector3(0, tam.y / 2.0, -tam.z / 2.0 - g / 2.0), Vector3(tam.x, tam.y, g), color_paredes)
	Construir.caja(self, centro + Vector3(0, tam.y / 2.0, tam.z / 2.0 + g / 2.0), Vector3(tam.x, tam.y, g), color_paredes)
	Construir.caja(self, centro + Vector3(-tam.x / 2.0 - g / 2.0, tam.y / 2.0, 0), Vector3(g, tam.y, tam.z), color_paredes)
	Construir.caja(self, centro + Vector3(tam.x / 2.0 + g / 2.0, tam.y / 2.0, 0), Vector3(g, tam.y, tam.z), color_paredes)
