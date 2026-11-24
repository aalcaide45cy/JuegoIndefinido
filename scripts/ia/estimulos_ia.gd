# estimulos_ia.gd
# -----------------------------------------------------------------------------
# "Lo que pasa en el mundo y los personajes pueden notar": disparos, explosiones, peleas,
# gritos, cadáveres... Quien provoca algo llama a:
#     EstimulosIA.emitir(get_tree(), "disparo", posicion, radio, autor)
# y TODOS los personajes con IA del grupo "oyentes_ia" que estén dentro del radio lo reciben en
# su función percibir(tipo, pos, intensidad, autor). La intensidad baja con la distancia
# (1 en el centro, 0 en el borde del radio).
#
# Tipos que entienden los cerebros (PersonaIA): "disparo", "explosion", "violencia" (alguien
# pega o hiere a alguien), "grito", "muerte" (alguien cae muerto), "atropello", "arma_vista"
# (alguien saca un arma), "empujon" (te chocan). Se pueden añadir más sin romper nada.
# -----------------------------------------------------------------------------
class_name EstimulosIA
extends RefCounted

# Radio típico de cada tipo (si quien emite pasa radio <= 0).
const RADIOS: Dictionary = {"disparo": 60.0, "explosion": 90.0, "violencia": 18.0, "grito": 22.0,
		"muerte": 20.0, "atropello": 25.0, "arma_vista": 14.0, "empujon": 3.0}

static var _ultimo: Dictionary = {}   # tipo -> ms (para no saturar con ráfagas: máx. 6 por segundo)


static func emitir(arbol: SceneTree, tipo: String, pos: Vector3, radio: float = -1.0, autor: Object = null) -> void:
	if arbol == null:
		return
	var ahora: int = Time.get_ticks_msec()
	var clave: String = tipo + str(roundi(pos.x / 4.0)) + "_" + str(roundi(pos.z / 4.0))
	if ahora - int(_ultimo.get(clave, -1000)) < 160:
		return
	_ultimo[clave] = ahora
	if _ultimo.size() > 256:
		_ultimo.clear()
	if radio <= 0.0:
		radio = float(RADIOS.get(tipo, 20.0))
	for n in arbol.get_nodes_in_group("oyentes_ia"):
		if n == autor or not is_instance_valid(n) or not (n is Node3D):
			continue
		var d: float = (n as Node3D).global_position.distance_to(pos)
		if d > radio:
			continue
		if n.has_method("percibir"):
			n.percibir(tipo, pos, clampf(1.0 - d / radio, 0.05, 1.0), autor)


# ¿Este autor es el jugador (o su vehículo)?
static func es_jugador(autor: Object) -> bool:
	if autor == null or not is_instance_valid(autor) or not (autor is Node):
		return false
	var n: Node = autor as Node
	return n.is_in_group("jugador") or (n.get("conductor") != null and (n.get("conductor") as Object) is Node
			and (n.get("conductor") as Node).is_in_group("jugador"))
