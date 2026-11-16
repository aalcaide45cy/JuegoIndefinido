# barrio_mercado.gd
# -----------------------------------------------------------------------------
# El Mercado: una avenida de 8 m que sale de la plaza hacia el norte, con
# tiendas a los dos lados (botica, herbolario, ferretería, armería, panadería).
# El barrio se coloca en (16, 0, -64): su centro queda en medio de la avenida y
# va de z = -100 (final de la calle) a z = -28 (donde acaba la plaza), en mundo.
# Coordenadas de dentro del barrio: la avenida va a lo largo de Z.
# -----------------------------------------------------------------------------
class_name BarrioMercado
extends Barrio

const LARGO: float = 36.0   # La avenida va de z = -36 a z = 36 (local).


func construir() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2024
	suelo(-20, 20, -36, 24)
	calle(Vector3(0, 0, 0), 8.0, 72.0, false)

	# Fila oeste (fachadas en x = -4 mirando al este; u = -z).
	var oeste: Array = [
		{"z": -26.0, "id": "botica", "titulo": "BOTICA  La Sanguijuela Feliz",
				"nombre": "Botica La Sanguijuela Feliz", "habla": "Hablar con el boticario (comprar)",
				"color": Color(0.6, 0.9, 0.7)},
		{"z": -6.0, "id": "herbolario", "titulo": "HIERBAS  Doña Nabo",
				"nombre": "Puesto de Hierbas Doña Nabo", "habla": "Hablar con Doña Nabo (comprar)",
				"color": Color(0.6, 0.9, 0.6)},
		{"z": 18.0, "id": "ferreteria", "titulo": "FERRETERÍA  Hierros y Clavos",
				"nombre": "Ferretería Hierros y Clavos", "habla": "Hablar con el ferretero (comprar)",
				"color": Color(1.0, 0.8, 0.4)},
	]
	var huecos_oeste: Array = []
	for t in oeste:
		huecos_oeste.append(Vector2(-t["z"] - 5.0, -t["z"] + 5.0))
	fila_con_huecos(Vector3(-4, 0, 0), PI / 2.0, -LARGO, LARGO, huecos_oeste, 8.0, rng)
	for t in oeste:
		tienda_con_interior(Vector3(-4, 0, t["z"]), PI / 2.0, t["titulo"], t["id"], t["nombre"],
				t["habla"], t["color"])

	# Fila este (fachadas en x = 4 mirando al oeste; u = z).
	var este: Array = [
		{"z": -26.0, "id": "armeria", "titulo": "ARMERÍA  Pólvora y Plomo",
				"nombre": "Armería Pólvora y Plomo", "habla": "Hablar con el armero (comprar)",
				"color": Color(1.0, 0.5, 0.4)},
		{"z": -6.0, "id": "panaderia", "titulo": "PANADERÍA  Migas Negras",
				"nombre": "Panadería Migas Negras", "habla": "Hablar con el panadero (comprar)",
				"color": Color(1.0, 0.85, 0.5)},
		{"z": 18.0, "id": "botica", "titulo": "BOTICA  El Frasco Roto",
				"nombre": "Botica El Frasco Roto", "habla": "Hablar con la boticaria (comprar)",
				"color": Color(0.6, 0.9, 0.7)},
	]
	var huecos_este: Array = []
	for t in este:
		huecos_este.append(Vector2(t["z"] - 5.0, t["z"] + 5.0))
	fila_con_huecos(Vector3(4, 0, 0), -PI / 2.0, -LARGO, LARGO, huecos_este, 8.0, rng)
	for t in este:
		tienda_con_interior(Vector3(4, 0, t["z"]), -PI / 2.0, t["titulo"], t["id"], t["nombre"],
				t["habla"], t["color"])

	var guardia: Guardia = Guardia.new()
	var ruta: Array[Vector3] = [to_global(Vector3(0, 0, -30)), to_global(Vector3(0, 0, 30))]
	guardia.ruta = ruta
	add_child(guardia)

	# Puestos de mercado en la calle (si está el paquete de modelos).
	Assets.colocar(self, Assets.FANTASIA + "Stall_Empty", Vector3(-2.3, 0, -16.0), 1.0, PI / 2.0)
	Assets.colocar(self, Assets.FANTASIA + "Stall_Cart_Empty", Vector3(2.3, 0, 8.0), 1.0, -PI / 2.0)
	Assets.colocar(self, Assets.MEDIEVAL + "Prop_Wagon", Vector3(-2.4, 0, 26.0))

	tapon_de_calle(Vector3(0, 0, -38), 14.0)
	Construir.texto(self, Vector3(0, 3.5, -35.8), "MERCADO DE LAS ÁNIMAS", 100, Color(0.9, 0.85, 0.65))

	farola(Vector3(-3.2, 0, -30))
	farola(Vector3(3.2, 0, -14))
	farola(Vector3(-3.2, 0, 2))
	farola(Vector3(3.2, 0, 18))
	farola(Vector3(-3.2, 0, 32))
