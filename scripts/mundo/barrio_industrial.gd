# barrio_industrial.gd
# -----------------------------------------------------------------------------
# La Zona Industrial: una avenida de 8 m que sale de la plaza hacia el sur,
# con almacenes oscuros, contenedores, una ferretería y una armería. Se
# coloca en (-16, 0, 64); la avenida va a lo largo de Z (de z = -24 a z = 36).
# -----------------------------------------------------------------------------
class_name BarrioIndustrial
extends Barrio


func construir() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4040
	# (Las filas empiezan en z = -36, pegadas a la plaza, para no dejar pasillos a los solares.)
	suelo(-20, 20, -44, 36, Color(0.15, 0.15, 0.16))
	calle(Vector3(0, 0, 0), 8.0, 72.0, false)

	# Oeste (fachadas en x = -4 mirando al este; u = -z): ferretería en z = 0.
	fila_con_huecos(Vector3(-4, 0, 0), PI / 2.0, -36.0, 36.0, [Vector2(-5.0, 5.0)], 8.0, rng)
	tienda_con_interior(Vector3(-4, 0, 0), PI / 2.0, "FERRETERÍA  Hierros del Puerto", "ferreteria",
			"Ferretería Hierros del Puerto", "Hablar con el ferretero (comprar)", Color(1.0, 0.8, 0.4),
			Color(0.2, 0.2, 0.22), Color(0.32, 0.3, 0.27))

	# Este (fachadas en x = 4 mirando al oeste; u = z): armería en z = 20.
	fila_con_huecos(Vector3(4, 0, 0), -PI / 2.0, -36.0, 36.0, [Vector2(15.0, 25.0), Vector2(-15.0, -5.0)], 8.0, rng)
	tienda_con_interior(Vector3(4, 0, 20), -PI / 2.0, "ARMERÍA  Acero y Pólvora", "armeria",
			"Armería Acero y Pólvora", "Hablar con la armera (comprar)", Color(1.0, 0.5, 0.4),
			Color(0.2, 0.19, 0.2), Color(0.3, 0.27, 0.27))

	# Este, z = -10: la academia donde se aprenden habilidades (nivel y dinero).
	tienda_con_interior(Vector3(4, 0, -10), -PI / 2.0, "ACADEMIA  Plomo y Pericia", "",
			"Academia Plomo y Pericia", "Hablar con el instructor (aprender habilidades)",
			Color(0.6, 0.8, 1.0), Color(0.22, 0.22, 0.26), Color(0.32, 0.3, 0.3), true)

	# Contenedores apilados en la calle (decoración con choque).
	var colores: Array[Color] = [Color(0.45, 0.2, 0.15), Color(0.2, 0.3, 0.4), Color(0.35, 0.35, 0.2)]
	for i in 3:
		Construir.caja(self, Vector3(-2.2, 1.3, 18.0 + i * 5.0), Vector3(2.4, 2.6, 4.4), colores[i])
	Construir.caja(self, Vector3(-2.2, 3.9, 23.0), Vector3(2.4, 2.6, 4.4), colores[0])

	# Galería de tiro al final de la calle: tres dianas para practicar.
	for i in 3:
		var diana: Diana = Diana.new()
		diana.position = Vector3(0.6 + i * 1.3, 0, 33.5)
		diana.rotation.y = PI
		add_child(diana)
	var letrero: Label3D = Construir.texto(self, Vector3(1.9, 2.6, 33.0), "GALERÍA DE TIRO", 50,
			Color(1.0, 0.8, 0.6))
	letrero.rotation.y = PI

	tapon_de_calle(Vector3(0, 0, 38), 14.0)
	var cartel: Label3D = Construir.texto(self, Vector3(0, 3.5, 35.8), "ZONA INDUSTRIAL", 100,
			Color(0.8, 0.8, 0.75))
	cartel.rotation.y = PI

	farola(Vector3(3.2, 0, -16))
	farola(Vector3(-3.2, 0, -2))
	farola(Vector3(3.2, 0, 10))
	farola(Vector3(3.2, 0, 30))
