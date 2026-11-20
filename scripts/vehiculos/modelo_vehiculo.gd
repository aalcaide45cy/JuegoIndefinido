# modelo_vehiculo.gd
# -----------------------------------------------------------------------------
# Monta un vehículo a partir de su carrocería 3D (assets/vehiculos/<tipo>.glb,
# generada con IA sin ruedas) y le pone las ruedas como nodos SEPARADOS
# (modelos CC0 de Kenney), para que puedan girar y virar:
#
#   raiz
#   ├─ escala/giro/<carrocería>            (el GLB, ya orientado: frente a -Z)
#   └─ pivote_rueda (vira, gira Y)
#        └─ giro_rueda (rueda al rodar, gira X)
#             └─ <rueda>
#
# Todo está medido sobre cada GLB (frente en -X del modelo, sin girar). Los datos
# de abajo se calibraron con vistas de prueba (tools/): "lat" = separación de las
# ruedas respecto al centro, en fracción del ancho; "suelo" = dónde queda el suelo
# respecto a la base de la carrocería (en fracción de su alto; negativo = las
# ruedas sobresalen por debajo); cada eje = [posición (0 = morro, 1 = cola, en
# fracción del largo), radio (en fracción del largo), modelo de rueda].
#
# Si falta el GLB (o Godot aún no lo ha importado) crear() devuelve {} y el juego
# usa los modelos de Kenney / cajas de siempre.  SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name ModeloVehiculo
extends RefCounted

const CARPETA: String = "vehiculos/"
const CARPETA_RUEDAS: String = "kenney/car-kit/"
const COLOR_ROTOR: Color = Color(0.08, 0.08, 0.08)

const DATOS: Dictionary = {
	"sedan": {"lat": 0.4, "suelo": -0.094, "ejes": [[0.23, 0.075, "wheel-default"], [0.755, 0.075, "wheel-default"]]},
	"hatchback": {"lat": 0.4, "suelo": -0.02, "ejes": [[0.2, 0.075, "wheel-default"], [0.785, 0.075, "wheel-default"]]},
	"taxi": {"lat": 0.39, "suelo": -0.075, "ejes": [[0.19, 0.075, "wheel-default"], [0.76, 0.075, "wheel-default"]]},
	"suv": {"lat": 0.39, "suelo": -0.134, "ejes": [[0.245, 0.095, "wheel-default"], [0.72, 0.095, "wheel-default"]]},
	"furgoneta": {"lat": 0.42, "suelo": -0.108, "ejes": [[0.19, 0.085, "wheel-truck"], [0.8, 0.085, "wheel-truck"]]},
	"camion": {"lat": 0.42, "suelo": -0.124, "ejes": [[0.17, 0.08, "wheel-truck"], [0.72, 0.08, "wheel-truck"]]},
	"tractor": {"lat": 0.42, "suelo": -0.124, "ejes": [[0.215, 0.12, "wheel-tractor-front"], [0.747, 0.189, "wheel-tractor-back"]]},
	"excavadora": {"lat": 0.34, "suelo": 0.057, "ejes": [[0.357, 0.108, "wheel-tractor-back"], [0.741, 0.108, "wheel-tractor-back"]]},
	"trailer": {"lat": 0.43, "suelo": -0.06, "ejes": [[0.15, 0.085, "wheel-truck"], [0.72, 0.085, "wheel-truck"], [0.84, 0.085, "wheel-truck"]]},
	"remolque_carga": {"lat": 0.6, "suelo": 0.0, "ejes": [[0.36, 0.055, "wheel-truck"]]},
	"remolque_grande": {"lat": 0.56, "suelo": 0.0, "ejes": [[0.58, 0.045, "wheel-truck"], [0.69, 0.045, "wheel-truck"], [0.8, 0.045, "wheel-truck"]]},
	"portacoches": {"lat": 0.58, "suelo": 0.0, "ejes": [[0.49, 0.055, "wheel-truck"], [0.64, 0.055, "wheel-truck"], [0.765, 0.055, "wheel-truck"]]},
	"deportivo": {"lat": 0.38, "suelo": -0.12, "ejes": [[0.255, 0.095, "wheel-dark"], [0.765, 0.095, "wheel-dark"]]},
	# Aire: sin ruedas, con hélices que giran. Cada rotor = [x (fracción del largo desde el
	# morro), y (fracción del alto), lateral (m), largo de pala (m), eje de giro].
	"helicoptero": {"suelo": 0.0, "rotores": [[0.32, 0.93, 0.0, 7.4, "y"], [0.918, 0.53, -0.32, 1.3, "x"]]},
	"avion": {"suelo": 0.0, "rotores": [[0.0, 0.47, 0.0, 2.1, "z"]]},
}


# Claves de las que hay datos (para pruebas).
static func claves() -> Array:
	return DATOS.keys()


# true si hay datos Y el GLB está importado.
static func existe(clave: String) -> bool:
	return DATOS.has(clave) and Assets.existe(CARPETA + clave)


# Devuelve {} si no se puede, o un diccionario con:
#   nodo      Node3D listo para añadir (origen en el centro, ruedas apoyadas en y = 0)
#   ancho     ancho de la carrocería (m)
#   alto      alto (m)
#   giros     Array[Node3D]  ruedas que ruedan (rotar en X)
#   radios    Array[float]   radio de cada una (m)
#   pivotes   Array[Node3D]  ruedas del primer eje, que viran (rotar en Y) — vacío si
#             con_direccion es false
#   rotores   Array[Dictionary]  {"nodo": Node3D, "eje": Vector3} (hélices)
static func crear(clave: String, largo: float, con_direccion: bool = true) -> Dictionary:
	if not existe(clave):
		return {}
	var m: Node3D = Assets.modelo(CARPETA + clave)
	if m == null:
		return {}
	var d: Dictionary = DATOS[clave]
	var caja: AABB = Assets.caja_de(m)
	var esc: float = largo / maxf(0.01, caja.size.x)
	var ancho: float = caja.size.z * esc
	var alto: float = caja.size.y * esc
	# Centrado en X/Z y con la base en y = 0 (en las coordenadas del propio GLB).
	m.position = Vector3(-caja.get_center().x, -caja.position.y, -caja.get_center().z)
	var giro: Node3D = Node3D.new()
	giro.rotation.y = -PI / 2.0   # el frente del GLB está en -X: lo ponemos en -Z
	giro.add_child(m)
	var escala: Node3D = Node3D.new()
	escala.scale = Vector3.ONE * esc
	escala.position.y = -float(d["suelo"]) * alto
	escala.add_child(giro)
	var raiz: Node3D = Node3D.new()
	raiz.add_child(escala)
	var giros: Array = []
	var radios: Array = []
	var pivotes: Array = []
	var rotores: Array = []
	var primero: bool = true
	for eje in d.get("ejes", []):
		var radio: float = float(eje[1]) * largo
		var z: float = -largo / 2.0 + float(eje[0]) * largo
		var lat: float = float(d["lat"]) * ancho
		for lado in [-1.0, 1.0]:
			var rueda: Node3D = Assets.modelo(CARPETA_RUEDAS + str(eje[2]))
			if rueda == null:
				continue
			var caja_r: AABB = Assets.caja_de(rueda)
			rueda.scale = Vector3.ONE * (radio / maxf(0.01, caja_r.size.y / 2.0))
			if lado < 0.0:
				rueda.rotation.y = PI   # el buje mira hacia fuera
			var spin: Node3D = Node3D.new()
			spin.add_child(rueda)
			var pivote: Node3D = Node3D.new()
			pivote.position = Vector3(lado * lat, radio, z)
			pivote.add_child(spin)
			raiz.add_child(pivote)
			giros.append(spin)
			radios.append(radio)
			if primero and con_direccion:
				pivotes.append(pivote)
		primero = false
	for r in d.get("rotores", []):
		rotores.append(_rotor(raiz, largo, alto, float(d["suelo"]), r))
	return {"nodo": raiz, "ancho": ancho, "alto": alto, "giros": giros, "radios": radios,
			"pivotes": pivotes, "rotores": rotores}


# Una hélice: dos palas en cruz (o una sola en el morro del avión), colgada de un nodo que gira.
static func _rotor(raiz: Node3D, largo: float, alto: float, suelo: float, r: Array) -> Dictionary:
	var nodo: Node3D = Node3D.new()
	var y: float = (float(r[1]) - suelo) * alto
	nodo.position = Vector3(float(r[2]), y, -largo / 2.0 + float(r[0]) * largo)
	raiz.add_child(nodo)
	var pala: float = float(r[3])
	var eje: Vector3 = Vector3.UP
	match str(r[4]):
		"y":
			Construir.caja(nodo, Vector3.ZERO, Vector3(pala, 0.05, 0.3), COLOR_ROTOR, false)
			Construir.caja(nodo, Vector3.ZERO, Vector3(0.3, 0.05, pala), COLOR_ROTOR, false)
		"x":
			eje = Vector3.RIGHT
			Construir.caja(nodo, Vector3.ZERO, Vector3(0.05, pala, 0.15), COLOR_ROTOR, false)
			Construir.caja(nodo, Vector3.ZERO, Vector3(0.05, 0.15, pala), COLOR_ROTOR, false)
		_:
			eje = Vector3.BACK
			Construir.caja(nodo, Vector3.ZERO, Vector3(0.16, pala, 0.05), COLOR_ROTOR, false)
	return {"nodo": nodo, "eje": eje}
