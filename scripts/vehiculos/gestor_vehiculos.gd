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
	["amb_2", "taxi", 84.0, -18.6, -PI / 2.0],
	["amb_3", "hatchback", 19.3, -52.0, 0.0],
	["amb_4", "furgoneta", -12.7, 52.0, PI],
	["amb_5", "suv", 150.0, -13.4, PI / 2.0],
	["amb_6", "tractor", 232.0, -18.6, -PI / 2.0],
	["amb_7", "camion", -12.7, 80.0, 0.0],
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
