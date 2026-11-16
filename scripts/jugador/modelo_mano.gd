# modelo_mano.gd
# -----------------------------------------------------------------------------
# Dibuja en 3D, con formas simples, el objeto que llevas en la mano. Cada
# "forma" (ver scripts/datos/objetos.gd) tiene su modelo. Todo apunta hacia
# delante, que en Godot es -Z. Cuando haya modelos de verdad, se cambia aquí.
# -----------------------------------------------------------------------------
class_name ModeloMano
extends RefCounted

const DatosObjetos = preload("res://scripts/datos/objetos.gd")


# Crea un nodo con el modelo del objeto "id" (o null si no hay nada).
static func crear(id: String) -> Node3D:
	if id == "":
		return null
	var datos: Dictionary = DatosObjetos.datos(id)
	var c: Color = datos["color"]
	var raiz: Node3D = Node3D.new()
	var oscuro: Color = c.darkened(0.45)
	match datos["forma"]:
		"bolsita":
			Construir.caja(raiz, Vector3(0, 0, 0), Vector3(0.12, 0.16, 0.05), Color(0.75, 0.65, 0.45), false)
			Construir.caja(raiz, Vector3(0, 0.1, 0), Vector3(0.08, 0.04, 0.04), c, false)
		"saco":
			Construir.caja(raiz, Vector3(0, 0, 0), Vector3(0.22, 0.28, 0.12), c, false)
			Construir.caja(raiz, Vector3(0, 0.16, 0), Vector3(0.1, 0.05, 0.08), oscuro, false)
		"maceta":
			Construir.cilindro(raiz, Vector3(0, 0, 0), 0.09, 0.14, c, false, 0.0, 0.12)
		"jarra", "regadera":
			Construir.cilindro(raiz, Vector3(0, 0, 0), 0.07, 0.18, c, false)
			Construir.cilindro(raiz, Vector3(0, 0.091, 0), 0.058, 0.01, Color(0.35, 0.55, 0.9), false)
			if datos["forma"] == "regadera":
				var pico: Node3D = Construir.cilindro(raiz, Vector3(0, 0.02, -0.14), 0.015, 0.2, c, false)
				pico.rotation.x = deg_to_rad(70.0)
		"hoja":
			for i in 3:
				var hoja: Node3D = Construir.caja(raiz, Vector3(0, 0.05, 0), Vector3(0.03, 0.18, 0.005), c, false)
				hoja.rotation.z = (i - 1) * 0.5
		"seta":
			Construir.cilindro(raiz, Vector3(0, -0.03, 0), 0.015, 0.1, Color(0.85, 0.82, 0.75), false)
			Construir.esfera(raiz, Vector3(0, 0.04, 0), 0.06, c, Vector3(1, 0.55, 1))
		"frasco":
			Construir.esfera(raiz, Vector3(0, 0, 0), 0.06, c, Vector3.ONE, 0.5)
			Construir.cilindro(raiz, Vector3(0, 0.08, 0), 0.02, 0.07, Color(0.7, 0.75, 0.8), false)
		"palo", "bate", "barra":
			var largo: float = 0.55 if datos["forma"] != "bate" else 0.7
			var grosor: float = 0.025 if datos["forma"] != "bate" else 0.035
			var arma: Node3D = Construir.cilindro(raiz, Vector3(0, 0, -largo / 2.0 + 0.1), grosor, largo, c, false)
			arma.rotation.x = deg_to_rad(90.0)
		"cuchillo", "katana":
			var l: float = 0.5 if datos["forma"] == "katana" else 0.22
			Construir.caja(raiz, Vector3(0, 0, 0.04), Vector3(0.03, 0.03, 0.12), Color(0.2, 0.15, 0.1), false)
			Construir.caja(raiz, Vector3(0, 0, -0.02 - l / 2.0), Vector3(0.012, 0.04, l), c, false)
		"pistola":
			Construir.caja(raiz, Vector3(0, 0.03, -0.1), Vector3(0.05, 0.06, 0.24), c, false)
			Construir.caja(raiz, Vector3(0, -0.05, -0.02), Vector3(0.045, 0.12, 0.06), c.lightened(0.1), false)
		"escopeta", "rifle", "francotirador", "lanzagranadas":
			var largo2: float = 0.8
			Construir.caja(raiz, Vector3(0, 0.03, -largo2 / 2.0), Vector3(0.05, 0.06, largo2), c, false)
			Construir.caja(raiz, Vector3(0, -0.03, 0.05), Vector3(0.06, 0.14, 0.2), Color(0.35, 0.22, 0.12), false)
			if datos["forma"] == "francotirador":
				var mira: Node3D = Construir.cilindro(raiz, Vector3(0, 0.09, -0.3), 0.025, 0.25, Color(0.08, 0.08, 0.08), false)
				mira.rotation.x = deg_to_rad(90.0)
			if datos["forma"] == "lanzagranadas":
				var tubo: Node3D = Construir.cilindro(raiz, Vector3(0, 0.03, -0.55), 0.06, 0.4, c.darkened(0.2), false)
				tubo.rotation.x = deg_to_rad(90.0)
		"granada":
			Construir.esfera(raiz, Vector3(0, 0, 0), 0.055, c)
			Construir.cilindro(raiz, Vector3(0, 0.07, 0), 0.015, 0.04, Color(0.5, 0.5, 0.5), false)
		"c4":
			Construir.caja(raiz, Vector3(0, 0, 0), Vector3(0.18, 0.05, 0.1), c, false)
			Construir.caja(raiz, Vector3(0, 0.03, 0), Vector3(0.06, 0.02, 0.04), Color(0.15, 0.15, 0.15), false)
		"detonador":
			Construir.caja(raiz, Vector3(0, 0, 0), Vector3(0.07, 0.12, 0.05), c.lightened(0.2), false)
			Construir.esfera(raiz, Vector3(0, 0.07, 0), 0.02, Color(1, 0.2, 0.2), Vector3.ONE, 1.0)
		_:  # "caja" y cualquier otra.
			Construir.caja(raiz, Vector3(0, 0, 0), Vector3(0.16, 0.1, 0.12), c, false)
			Construir.caja(raiz, Vector3(0, 0.045, 0), Vector3(0.16, 0.02, 0.12), oscuro, false)
	return raiz
