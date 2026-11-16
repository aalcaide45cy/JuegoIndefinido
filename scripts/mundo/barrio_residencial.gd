# barrio_residencial.gd
# -----------------------------------------------------------------------------
# El Barrio Residencial: una avenida de 8 m que sale de la plaza hacia el
# este, con cuatro casas en alquiler (cada una con su precio), una panadería
# y una botica. Se coloca en (64, 0, -16); la avenida va a lo largo de X
# (de x = -24 a x = 36 en coordenadas de dentro del barrio).
# -----------------------------------------------------------------------------
class_name BarrioResidencial
extends Barrio


func construir() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3030
	suelo(-24, 36, -20, 20)
	calle(Vector3(0, 0, 0), 8.0, 72.0, true)

	# Fila norte (fachadas en z = -4 mirando al sur; u = x).
	var casas_norte: Array = [
		{"x": 0.0, "id": "boticario", "precio": 250},
		{"x": 24.0, "id": "atico", "precio": 700},
	]
	var huecos_norte: Array = [Vector2(-21.0, -11.0)]   # Panadería en x = -16.
	for c in casas_norte:
		huecos_norte.append(Vector2(c["x"] - 5.0, c["x"] + 5.0))
	fila_con_huecos(Vector3(0, 0, -4), 0.0, -24.0, 36.0, huecos_norte, 8.0, rng)
	tienda_con_interior(Vector3(-16, 0, -4), 0.0, "PANADERÍA  El Horno Triste", "panaderia",
			"Panadería El Horno Triste", "Hablar con el panadero (comprar)", Color(1.0, 0.85, 0.5))
	for c in casas_norte:
		vivienda(c["id"], c["precio"], Vector3(c["x"], 0, -4), 0.0)

	# Fila sur (fachadas en z = 4 mirando al norte; u = -x).
	var casas_sur: Array = [
		{"x": 12.0, "id": "torcida", "precio": 400},
		{"x": -12.0, "id": "pozo", "precio": 160},
	]
	var huecos_sur: Array = [Vector2(-33.0, -23.0)]     # Botica en x = 28 (u = -28).
	for c in casas_sur:
		huecos_sur.append(Vector2(-c["x"] - 5.0, -c["x"] + 5.0))
	fila_con_huecos(Vector3(0, 0, 4), PI, -36.0, 24.0, huecos_sur, 8.0, rng)
	tienda_con_interior(Vector3(28, 0, 4), PI, "BOTICA  Aguas Turbias", "botica",
			"Botica Aguas Turbias", "Hablar con el boticario (comprar)", Color(0.6, 0.9, 0.7))
	for c in casas_sur:
		vivienda(c["id"], c["precio"], Vector3(c["x"], 0, 4), PI)

	tapon_de_calle(Vector3(38, 0, 0), 14.0, Color(0.2, 0.2, 0.23), true)
	farola(Vector3(-20, 0, -3.2))
	farola(Vector3(-8, 0, 3.2))
	farola(Vector3(6, 0, -3.2))
	farola(Vector3(18, 0, 3.2))
	farola(Vector3(30, 0, -3.2))
