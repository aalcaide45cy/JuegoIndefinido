# logros.gd (autoload "Logros")
# -----------------------------------------------------------------------------
# Controla los logros: comprueba cada segundo si se ha cumplido alguno, lo
# guarda en user://logros.json, avisa en pantalla (señal "desbloqueado", la
# recoge el HUD) y, si el juego se ejecuta con Steam, lo marca en Steam.
#
# Los logros son de toda la cuenta: no cambian al cambiar de partida guardada.
#
# Para dar un logro desde otro script:   Logros.desbloquear("id")
# Para añadir uno nuevo: scripts/datos/logros.gd.
#
# STEAM: cuando haya complemento GodotSteam, el singleton "Steam" existirá y
# _enviar_a_steam() llamará a setAchievement(). Cada logro tiene su "steam"
# (el nombre de API que se crea en Steamworks).
# -----------------------------------------------------------------------------
extends Node

const Datos = preload("res://scripts/datos/logros.gd")
const RUTA: String = "user://logros.json"

signal desbloqueado(id: String)

var conseguidos: Dictionary = {}   # id -> fecha (texto)
var _t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cargar()
	for id in conseguidos:
		_enviar_a_steam(id)


func _process(delta: float) -> void:
	_t += delta
	if _t >= 1.0:
		_t = 0.0
		comprobar()


func tiene(id: String) -> bool:
	return conseguidos.has(id)


func total() -> int:
	return Datos.LISTA.size()


# Cuenta actual de un tipo de condición, sacada del estado del juego.
func cuenta(tipo: String) -> int:
	match tipo:
		"dia": return Juego.dia
		"dinero": return Juego.dinero
		"nivel": return Juego.nivel
		"recetas": return Juego.recetario.size()
		"habilidades": return Juego.habilidades.size()
		"viviendas": return Juego.viviendas.size()
		# Huertos y viviendas son listas distintas (lo comprado está también en en_propiedad: no se suma).
		"propiedades": return _propiedades_distintas()
		"granja": return _animales_y_frutas()
		"vehiculos": return Juego.vehiculos.size()
		"personal": return Juego.personal.size()
		"licencias": return Negocios.estado()["licencias"].size()
		"reputacion": return Juego.reputacion
	return 0


# Casas y huertos distintos que tienes (si un id estuviera en las dos listas, cuenta una sola vez).
func _propiedades_distintas() -> int:
	var ids: Dictionary = {}
	for id in Juego.huertos:
		ids[id] = true
	for id in Juego.viviendas:
		ids[id] = true
	return ids.size()


# Animales que tienes en los corrales. Los árboles NO cuentan: dan fruta solos desde el principio
# y el logro "Granjero" saltaba nada más empezar.
func _animales_y_frutas() -> int:
	var n: int = 0
	for id in Juego.granja:
		var g = Juego.granja[id]
		if g is Dictionary:
			n += int(g.get("n", 0))
	return n


# Mira todos los logros pendientes y da los que ya se cumplen.
func comprobar() -> void:
	for id in Datos.LISTA:
		if conseguidos.has(id):
			continue
		var d: Dictionary = Datos.LISTA[id]
		if d.has("tipo") and cuenta(str(d["tipo"])) >= int(d["valor"]):
			desbloquear(id)


# Da un logro (si no lo tenía). Devuelve true si es nuevo.
func desbloquear(id: String) -> bool:
	if not Datos.LISTA.has(id) or conseguidos.has(id):
		return false
	conseguidos[id] = Time.get_datetime_string_from_system(false, true)
	guardar()
	_enviar_a_steam(id)
	desbloqueado.emit(id)
	return true


func _enviar_a_steam(id: String) -> void:
	if not Engine.has_singleton("Steam"):
		return
	var steam: Object = Engine.get_singleton("Steam")
	steam.setAchievement(str(Datos.LISTA[id].get("steam", id)))
	steam.storeStats()


func guardar() -> void:
	var f: FileAccess = FileAccess.open(RUTA, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"version": 1, "conseguidos": conseguidos}, "\t"))
		f.close()


func cargar() -> void:
	conseguidos.clear()
	if not FileAccess.file_exists(RUTA):
		return
	var datos = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
	if datos is Dictionary and datos.get("conseguidos", {}) is Dictionary:
		for id in datos["conseguidos"]:
			if Datos.LISTA.has(str(id)):
				conseguidos[str(id)] = str(datos["conseguidos"][id])


# Borra todos los logros (para pruebas).
func reiniciar() -> void:
	conseguidos.clear()
	guardar()
