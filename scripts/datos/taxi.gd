# taxi.gd
# -----------------------------------------------------------------------------
# Taxi / viaje rápido: la lista de destinos (los barrios de la ciudad original y todas las
# aldeas, pueblos y ciudades del mundo grande), el precio según la distancia y las
# condiciones para pedirlo. Se usa desde la pestaña Taxi del móvil (ui/telefono.gd).
# Sin class_name: preload("res://scripts/datos/taxi.gd").
# -----------------------------------------------------------------------------
extends RefCounted

const Economia = preload("res://scripts/datos/economia.gd")

const DISTANCIA_MINIMA: float = 120.0   # Más cerca que esto, ve andando.

# Barrios de la ciudad original (sobre sus calles).
const BARRIOS: Array = [
	["Plaza del Ahorcado", Vector3(0, 0.3, 8)],
	["Mercado", Vector3(16, 0.3, -58)],
	["Barrio Residencial", Vector3(58, 0.3, -16)],
	["Zona Industrial", Vector3(-16, 0.3, 58)],
	["Zona de Campo (concesionario y gasolinera)", Vector3(140, 0.3, -16)],
]


# [{nombre, pos, dist, precio, horas}] ordenado de más cerca a más lejos de "desde".
static func destinos(desde: Vector3) -> Array:
	var lista: Array = []
	for b in BARRIOS:
		lista.append({"nombre": b[0], "pos": b[1]})
	if GeneradorMundo.listo:
		for s in GeneradorMundo.todos_asentamientos():
			var p: Vector2 = s["pos"]
			lista.append({"nombre": "%s %s" % [GeneradorMundo.nombre_tipo(int(s["tipo"])), s["nombre"]],
					"pos": Vector3(p.x, GeneradorMundo.altura(p.x, p.y) + 0.3, p.y)})
	for d in lista:
		var dist: float = Vector2(desde.x, desde.z).distance_to(Vector2(d["pos"].x, d["pos"].z))
		d["dist"] = dist
		d["precio"] = precio(dist)
		d["horas"] = dist / Economia.TAXI_VELOCIDAD_MS / 3600.0
	lista.sort_custom(func(a, b) -> bool: return float(a["dist"]) < float(b["dist"]))
	return lista


static func precio(dist: float) -> int:
	return Economia.TAXI_BAJADA + int(round(dist / 1000.0 * float(Economia.TAXI_POR_KM)))


# Texto con el motivo por el que no puedes pedir un taxi ahora, o "" si puedes.
static func motivo_no(jugador: Node) -> String:
	if jugador == null:
		return "No hay taxis por aquí."
	if Juego.estrellas > 0:
		return "Con la policía buscándote ningún taxista te recoge."
	if Juego.interiores > 0:
		return "Sal a la calle para que el taxi te recoja."
	if jugador.get("vehiculo") != null:
		return "Ya vas en un vehículo."
	return ""


# Pide el taxi: cobra, pasa el tiempo del trayecto y te lleva. Devuelve un texto de error o "".
static func pedir(jugador: Node, destino: Dictionary) -> String:
	var motivo: String = motivo_no(jugador)
	if motivo != "":
		return motivo
	if float(destino["dist"]) < DISTANCIA_MINIMA:
		return "Está ahí al lado: ve andando."
	if not Juego.gastar(int(destino["precio"])):
		return "El trayecto cuesta %d $." % int(destino["precio"])
	jugador.viajar_a(destino["pos"], float(destino["horas"]))
	Juego.avisar("El taxi te lleva a %s (%d $)." % [destino["nombre"], int(destino["precio"])])
	return ""
