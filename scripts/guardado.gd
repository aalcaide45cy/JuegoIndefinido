# guardado.gd
# -----------------------------------------------------------------------------
# Guardar y cargar la partida en un archivo (user://partida.json, que en
# Windows queda en %APPDATA%\Godot\app_userdata\Elixir Clandestino).
#
# Se guarda: dinero, vida, nivel, habilidades, hora y día, inventario,
# estantería, objeto en la mano, si la casa está alquilada, tus macetas
# (plantas incluidas) y dónde estás.
# Si quieres guardar algo más, añádelo en guardar() y en cargar().
# -----------------------------------------------------------------------------
class_name Guardado
extends RefCounted

const DatosObjetos = preload("res://scripts/datos/objetos.gd")

const RUTA: String = "user://partida.json"
const VERSION: int = 1


static func existe() -> bool:
	return FileAccess.file_exists(RUTA)


# Guarda la partida. Devuelve true si salió bien.
static func guardar(arbol: SceneTree, jugador: Node3D) -> bool:
	var macetas: Array = []
	for nodo in arbol.get_nodes_in_group("macetas"):
		var maceta: Maceta3D = nodo as Maceta3D
		if maceta == null:
			continue
		var d: Dictionary = maceta.exportar()
		var p: Vector3 = maceta.global_position
		d["pos"] = [p.x, p.y, p.z]
		macetas.append(d)
	var pos: Vector3 = jugador.global_position
	var datos: Dictionary = {
		"version": VERSION,
		"dinero": Juego.dinero,
		"vida": Juego.vida,
		"hora": Juego.hora,
		"dia": Juego.dia,
		"nivel": Juego.nivel,
		"habilidades": Juego.habilidades.keys(),
		"casa_alquilada": Juego.casa_alquilada,
		"ha_ganado": Juego.ha_ganado,
		"seleccion": Juego.seleccion,
		"inventario": Juego.inventario,
		"estanteria": Juego.estanteria,
		"macetas": macetas,
		"jugador": [pos.x, pos.y, pos.z],
	}
	var archivo: FileAccess = FileAccess.open(RUTA, FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(JSON.stringify(datos, "\t"))
	archivo.close()
	return true


# Carga la partida. Devuelve true si salió bien.
static func cargar(arbol: SceneTree, jugador: Node3D) -> bool:
	if not existe():
		return false
	var archivo: FileAccess = FileAccess.open(RUTA, FileAccess.READ)
	if archivo == null:
		return false
	var datos = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if not datos is Dictionary:
		return false

	Juego.reiniciar()
	Juego.dinero = int(datos.get("dinero", Juego.dinero))
	Juego.vida = float(datos.get("vida", Juego.vida))
	Juego.hora = float(datos.get("hora", Juego.hora))
	Juego.dia = int(datos.get("dia", 1))
	Juego.nivel = int(datos.get("nivel", 1))
	Juego.casa_alquilada = bool(datos.get("casa_alquilada", false))
	Juego.ha_ganado = bool(datos.get("ha_ganado", false))
	for id_hab in datos.get("habilidades", []):
		Juego.habilidades[str(id_hab)] = true
	_leer_lista(datos.get("inventario", []), Juego.inventario)
	_leer_lista(datos.get("estanteria", []), Juego.estanteria)
	Juego.seleccion = clampi(int(datos.get("seleccion", 0)), 0, Juego.TAM_BARRA - 1)

	for d in datos.get("macetas", []):
		_restaurar_maceta(arbol, d)

	var p: Array = datos.get("jugador", [])
	if p.size() == 3:
		jugador.global_position = Vector3(p[0], p[1], p[2])
		if jugador is CharacterBody3D:
			(jugador as CharacterBody3D).velocity = Vector3.ZERO
	Juego.cambio.emit()
	return true


# Copia las casillas guardadas a la lista del juego (convirtiendo los números).
static func _leer_lista(guardada: Array, destino: Array) -> void:
	for i in mini(guardada.size(), destino.size()):
		var c = guardada[i]
		if not c is Dictionary or not c.has("id") or not DatosObjetos.LISTA.has(str(c["id"])):
			destino[i] = null
			continue
		var casilla: Dictionary = {"id": str(c["id"]), "cantidad": maxi(1, int(c.get("cantidad", 1)))}
		if c.has("agua"):
			casilla["agua"] = int(c["agua"])
		destino[i] = casilla


static func _restaurar_maceta(arbol: SceneTree, d: Dictionary) -> void:
	var pa: Array = d.get("pos", [])
	if pa.size() != 3:
		return
	var pos: Vector3 = Vector3(pa[0], pa[1], pa[2])
	for nodo in arbol.get_nodes_in_group("macetas"):
		var maceta: Maceta3D = nodo as Maceta3D
		if maceta != null and maceta.global_position.distance_to(pos) < 0.1:
			maceta.importar(d)
			return
	# No había maceta ahí: la ponemos en el hueco que corresponda.
	for nodo in arbol.get_nodes_in_group("huecos_maceta"):
		var hueco: Muebles.HuecoMaceta = nodo as Muebles.HuecoMaceta
		if hueco != null and hueco.global_position.distance_to(pos) < 0.1:
			var nueva: Maceta3D = hueco.poner_maceta()
			nueva.importar(d)
			return
