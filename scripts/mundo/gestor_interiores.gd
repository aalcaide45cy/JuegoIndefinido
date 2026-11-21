# gestor_interiores.gd
# -----------------------------------------------------------------------------
# Interiores de las casas del mundo grande, bajo demanda.
#
# Las casas ya son huecas desde el propio trozo del mundo (muros con puerta y ventanas,
# suelo y techo: ver GeneradorMundo._paredes_con_interior). Esto pone lo que cambia:
#   - A menos de RADIO_PUERTA m: la puerta (una hoja que se abre con E).
#   - A menos de RADIO_INTERIOR m: muebles, paredes interiores, choques y luz
#     (reparto de InteriorCasa, todo en UNA malla y UN cuerpo por casa).
# Se quita todo al alejarse (con margen para que no parpadee). Los edificios con
# servicio (banco, hospital...) no pasan por aquí: tienen su propio interior.
# -----------------------------------------------------------------------------
class_name GestorInteriores
extends Node3D

const RADIO_PUERTA: float = 170.0
const RADIO_INTERIOR: float = 55.0
const MARGEN: float = 15.0              # Histéresis para quitar.
const RADIO_LISTA: float = 260.0        # Casas candidatas (se recalcula al moverte 40 m).
const MAX_NUEVOS: int = 2               # Interiores montados por pasada.
const PERIODO: float = 0.3
const PUERTAS: Array = [Color(0.25, 0.15, 0.1), Color(0.15, 0.25, 0.2), Color(0.4, 0.12, 0.1), Color(0.18, 0.2, 0.3)]

var jugador: Node3D = null
var _lista: Array = []                  # Casas cerca (diccionarios de GeneradorMundo.casa).
var _centro_lista: Vector2 = Vector2(1.0e9, 1.0e9)
var _puertas: Dictionary = {}           # clave -> PuertaMundo
var _interiores: Dictionary = {}        # clave -> Node3D
var _t: float = 0.0
var _material: StandardMaterial3D
var _forma_cache: Dictionary = {}


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.roughness = 1.0


static func _clave(c: Dictionary) -> Vector2i:
	return Vector2i(roundi(float(c["x"]) * 4.0), roundi(float(c["z"]) * 4.0))


func _process(delta: float) -> void:
	_t += delta
	if _t < PERIODO:
		return
	_t = 0.0
	if jugador == null or not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("jugador") as Node3D
		return
	actualizar(jugador.global_position)


# Una pasada: recalcula candidatas si hace falta, monta lo que falta y quita lo que sobra.
func actualizar(pos: Vector3, max_nuevos: int = MAX_NUEVOS) -> void:
	var p2: Vector2 = Vector2(pos.x, pos.z)
	if p2.distance_to(_centro_lista) > 40.0:
		_recalcular_lista(p2)
	var nuevos: int = 0
	var quedan_p: Dictionary = {}
	var quedan_i: Dictionary = {}
	# Las más cercanas primero para montar antes lo que se va a pisar.
	var ordenadas: Array = []
	for c in _lista:
		var d: float = p2.distance_to(Vector2(c["x"], c["z"]))
		if d < RADIO_PUERTA + MARGEN:
			ordenadas.append([d, c])
	ordenadas.sort_custom(func(a, b): return a[0] < b[0])
	for par in ordenadas:
		var d: float = par[0]
		var c: Dictionary = par[1]
		var k: Vector2i = _clave(c)
		if d < RADIO_PUERTA or _puertas.has(k):
			quedan_p[k] = true
			if not _puertas.has(k):
				_montar_puerta(k, c)
		var dentro: bool = d < RADIO_INTERIOR or (_interiores.has(k) and d < RADIO_INTERIOR + MARGEN)
		if dentro:
			quedan_i[k] = true
			if not _interiores.has(k) and nuevos < max_nuevos:
				_montar_interior(k, c)
				nuevos += 1
	for k in _interiores.keys():
		if not quedan_i.has(k):
			_quitar_interior(k)
	for k in _puertas.keys():
		if not quedan_p.has(k):
			_quitar_puerta(k)


func _recalcular_lista(p2: Vector2) -> void:
	_centro_lista = p2
	_lista.clear()
	var rect: Rect2 = Rect2(p2.x - RADIO_LISTA, p2.y - RADIO_LISTA, RADIO_LISTA * 2.0, RADIO_LISTA * 2.0)
	for s in GeneradorMundo.asentamientos_cerca(rect):
		for c in GeneradorMundo._casas_en(s, rect):
			_lista.append(c)   # También los servicios (banco, hospital, taberna...): todo edificio se visita.
	for g in GeneradorMundo._gasolineras_de_carretera(rect, GeneradorMundo.segmentos_para(rect)):
		_lista.append(g)


func _montar_puerta(k: Vector2i, c: Dictionary) -> void:
	var cara: float = float(c["puerta"])
	var pu: PuertaMundo = PuertaMundo.new()
	pu.cara = cara
	pu.id_casa = str(c["id"])
	pu.position = Vector3(c["x"], float(c["y"]), float(c["z"]) + cara * (float(c["d"]) / 2.0 - GeneradorMundo.GROSOR_MURO / 2.0))
	add_child(pu)
	pu.montar(PUERTAS[(int(c.get("var", 0)) / 7) % 4])
	_puertas[k] = pu
	# Asaltos (casa_asaltable.gd): las casas normales vienen con la puerta cerrada con llave.
	if Asaltos.es_asaltable(c) and not Asaltos.forzada_reciente(Asaltos.id_de_casa(c)):
		pu.bloquear_asalto(true)


func _quitar_puerta(k: Vector2i) -> void:
	var pu: PuertaMundo = _puertas[k]
	_puertas.erase(k)
	if is_instance_valid(pu):
		pu.queue_free()


func _montar_interior(k: Vector2i, c: Dictionary) -> void:
	var datos: Dictionary = InteriorCasa.generar(c)
	var raiz: Node3D = Node3D.new()
	raiz.name = "Interior_%d_%d" % [k.x, k.y]
	add_child(raiz)
	var mb: ConstructorMalla = ConstructorMalla.new()
	var cuerpo: StaticBody3D = StaticBody3D.new()
	raiz.add_child(cuerpo)
	for cj in datos["cajas"]:
		var pos: Vector3 = cj[0]
		var tam: Vector3 = cj[1]
		mb.caja(pos, tam, cj[2])
		if bool(cj[3]):
			var cs: CollisionShape3D = CollisionShape3D.new()
			cs.shape = _forma(tam)
			cs.position = pos
			cuerpo.add_child(cs)
	var malla: ArrayMesh = ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mb.superficie())
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(mi)
	for lp in datos["luces"]:
		var l: OmniLight3D = Construir.luz(raiz, lp, Color(1.0, 0.86, 0.6), 0.9, 7.0)
		l.shadow_enabled = false
	raiz.set_meta("tipo", datos["tipo"])
	# Asaltos: gente durmiendo, botín y entradas que se fuerzan (usa las camas y muebles de este reparto).
	if datos["tipo"] == "vivienda" and Asaltos.es_asaltable(c):
		raiz.add_child(CasaAsaltable.desde_interior(c, datos, _puertas.get(k) as PuertaMundo))
	_interiores[k] = raiz
	if _puertas.has(k):
		(_puertas[k] as PuertaMundo).con_choque(true)


func _quitar_interior(k: Vector2i) -> void:
	var raiz: Node3D = _interiores[k]
	_interiores.erase(k)
	if is_instance_valid(raiz):
		raiz.queue_free()
	if _puertas.has(k):
		var pu: PuertaMundo = _puertas[k]
		pu.poner_abierta(false, false)
		pu.con_choque(false)


func _forma(tam: Vector3) -> BoxShape3D:
	var clave: String = "%.2f_%.2f_%.2f" % [tam.x, tam.y, tam.z]
	if not _forma_cache.has(clave):
		var f: BoxShape3D = BoxShape3D.new()
		f.size = tam
		_forma_cache[clave] = f
	return _forma_cache[clave]


# Para pruebas: cuántos hay montados.
func cuenta() -> Dictionary:
	return {"puertas": _puertas.size(), "interiores": _interiores.size(), "candidatas": _lista.size()}
