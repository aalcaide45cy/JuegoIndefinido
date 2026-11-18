# gestor_vehiculos.gd
# -----------------------------------------------------------------------------
# Crea y mantiene los vehículos del mundo:
#   - los TUYOS (Juego.vehiculos: comprados o robados) aparecen donde los dejaste;
#   - algunos coches aparcados por la ciudad (PLAZAS) que se pueden robar. Si te
#     llevas uno, deja de aparecer en su plaza (su id queda en Juego.vehiculos).
# Al cargar una partida, Guardado llama a sincronizar().  SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name GestorVehiculos
extends Node3D

# [id, tipo, x, z, giro]  (en el borde de las calles; giro 0 = mira al norte, -Z)
const PLAZAS: Array = [
	["amb_1", "sedan", 40.0, -13.4, PI / 2.0],
	["amb_2", "taxi", 99.0, -18.6, -PI / 2.0],   # (A 84 m tapaba el paso al cliente de la ventanilla del ático.)
	["amb_3", "hatchback", 17.6, -52.0, 0.0],   # (A 19,3 m atravesaba los escaparates.)
	["amb_4", "furgoneta", -13.9, 52.0, PI],   # (A -14,4 m cortaba el camino de patrulla de la calle.)
	["amb_5", "suv", 150.0, -13.4, PI / 2.0],
	["amb_6", "tractor", 232.0, -18.6, -PI / 2.0],
	["amb_7", "camion", 212.0, -21.8, -PI / 2.0],   # (En el campo, entre huertos: en la calle industrial no cabe sin cortar la patrulla.)
]


func _ready() -> void:
	add_to_group("gestor_vehiculos")
	sincronizar()


# Rehace todos los vehículos que no estás conduciendo según los datos guardados.
func sincronizar() -> void:
	for v in get_children():
		if v is Vehiculo and (v as Vehiculo).conductor == null:
			v.queue_free()
	for id_v in Juego.vehiculos:
		_crear(str(id_v), Juego.vehiculos[id_v])
	for p in PLAZAS:
		if not Juego.vehiculos.has(p[0]):
			_crear(p[0], {"tipo": p[1], "pos": [p[2], 0.05, p[3]], "giro": p[4], "gas": 60.0, "salud": 100.0})


func _crear(id_v: String, d: Dictionary) -> Vehiculo:
	for v in get_children():
		if v is Vehiculo and (v as Vehiculo).id == id_v and (v as Vehiculo).conductor != null:
			return v as Vehiculo   # Ese lo estás conduciendo ahora.
	var v: Vehiculo = Vehiculo.new()
	v.tipo = str(d["tipo"])
	v.id = id_v
	v.gasolina = float(d.get("gas", 100.0))
	v.salud = float(d.get("salud", 100.0))
	add_child(v)
	var p: Array = d["pos"]
	v.global_position = Vector3(p[0], p[1], p[2])
	v.chasis.rotation.y = float(d.get("giro", 0.0))
	return v


# Compra un vehículo nuevo: aparece en "pos" mirando a "giro". Devuelve su id.
func entregar(tipo: String, pos: Vector3, giro: float) -> String:
	var id_v: String = "mio_%d" % Juego.siguiente_vehiculo()
	pos = _hueco_libre(tipo, pos, giro)
	Juego.vehiculos[id_v] = {"tipo": tipo, "pos": [pos.x, pos.y, pos.z], "giro": giro, "gas": 60.0, "salud": 100.0}
	_crear(id_v, Juego.vehiculos[id_v])
	return id_v


# Quita un vehículo tuyo del juego (venta). Devuelve false si lo estás conduciendo.
func retirar(id_v: String) -> bool:
	for v in get_tree().get_nodes_in_group("vehiculos"):
		if v is Vehiculo and (v as Vehiculo).id == id_v:
			if (v as Vehiculo).conductor != null:
				return false
			(v as Vehiculo).queue_free()
	Juego.vehiculos.erase(id_v)
	return true


# Si ya hay un vehículo en el punto de entrega, busca el siguiente hueco de la plaza
# (dos columnas y varias filas, en el sentido del vehículo). Antes todo lo que
# comprabas aparecía en el mismo sitio, uno dentro de otro.
func _hueco_libre(tipo: String, pos: Vector3, giro: float) -> Vector3:
	var largo: float = float(Vehiculo.TIPOS[tipo]["largo"])
	var base: Basis = Basis(Vector3.UP, giro)
	# Filas hacia delante y hacia atrás desde el punto (0, -5,5, +5,5, -11, +11...), en cada una
	# el centro y los dos lados.
	for k in 12:
		var z: float = 0.0 if k == 0 else (5.5 * float((k + 1) / 2)) * (-1.0 if k % 2 == 1 else 1.0)
		for x in [0.0, -1.6, 1.6]:
			var candidato: Vector3 = pos + base * Vector3(x, 0.0, z)
			var libre: bool = true
			for nodo in get_tree().get_nodes_in_group("vehiculos"):
				var otro: Vehiculo = nodo as Vehiculo
				if otro == null or otro.is_queued_for_deletion():
					continue
				var minimo: float = (largo + float(Vehiculo.TIPOS[otro.tipo]["largo"])) / 2.0 + 0.6
				if otro.chasis.global_position.distance_to(candidato) < minimo:
					libre = false
					break
			if libre:
				return candidato
	return pos
