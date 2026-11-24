# carpeta_datos.gd  (autocarga "CarpetaDatos", la primera de todas)
# -----------------------------------------------------------------------------
# El juego se llamaba "Elixir Clandestino" y ahora se llama "Juego Indefinido". Godot guarda las
# partidas y opciones en una carpeta con el nombre del juego (en Windows:
# %APPDATA%\Godot\app_userdata\<nombre>), así que al cambiar el nombre la carpeta cambia.
# Al arrancar, si la carpeta nueva no tiene partidas y la vieja sí, se copian (partidas, copias
# .bak, opciones, controles, logros...). La carpeta vieja no se toca.
# Va en _init para hacerlo antes de que cualquier otra autocarga lea sus archivos.
# -----------------------------------------------------------------------------
extends Node

const NOMBRE_ANTIGUO: String = "Elixir Clandestino"


func _init() -> void:
	copiar_de_carpeta_antigua()


static func carpeta_antigua() -> String:
	return OS.get_user_data_dir().get_base_dir().path_join(NOMBRE_ANTIGUO)


# Devuelve cuántos archivos copió (0 si no hacía falta).
static func copiar_de_carpeta_antigua(origen: String = "", destino: String = "") -> int:
	if origen == "":
		origen = carpeta_antigua()
	if destino == "":
		destino = OS.get_user_data_dir()
	if origen == destino or not DirAccess.dir_exists_absolute(origen):
		return 0
	# Si ya hay alguna partida en la carpeta nueva, no se pisa nada.
	var nueva: DirAccess = DirAccess.open(destino)
	if nueva != null:
		for f in nueva.get_files():
			if f.begins_with("partida") and f.ends_with(".json"):
				return 0
	var vieja: DirAccess = DirAccess.open(origen)
	if vieja == null:
		return 0
	DirAccess.make_dir_recursive_absolute(destino)
	var copiados: int = 0
	for f in vieja.get_files():
		var ext: String = f.get_extension()
		if ext in ["json", "bak", "cfg", "txt", "save", "dat"] and not FileAccess.file_exists(destino.path_join(f)):
			if DirAccess.copy_absolute(origen.path_join(f), destino.path_join(f)) == OK:
				copiados += 1
	if copiados > 0:
		print("Copiados %d archivos de la carpeta de \"%s\"." % [copiados, NOMBRE_ANTIGUO])
	return copiados
