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
const DatosHabilidades = preload("res://scripts/datos/habilidades.gd")

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
		"duracion_dia_min": Juego.duracion_dia_min,
		"nivel": Juego.nivel,
		"xp": Juego.xp,
		"habilidades": Juego.habilidades.keys(),
		"viviendas": Juego.viviendas.keys(),
		"ha_ganado": Juego.ha_ganado,
		"reputacion": Juego.reputacion,
		"encargos": Juego.encargos,
		"pedidos_material": Juego.pedidos_material,
		"avisos": Juego.avisos,
		"seleccion": Juego.seleccion,
		"inventario": Juego.inventario,
		"estanteria": Juego.estanteria,
		"macetas": macetas,
		"colocables": _exportar_colocables(arbol),
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
	# Todo se comprueba al leer: un archivo tocado a mano o roto no debe dejar
	# dinero negativo, vida a cero o montones más grandes de lo permitido.
	Juego.dinero = maxi(0, int(datos.get("dinero", Juego.dinero)))
	Juego.vida = clampf(float(datos.get("vida", Juego.vida)), 1.0, Juego.VIDA_MAX)
	Juego.hora = fposmod(float(datos.get("hora", Juego.hora)), 24.0)
	Juego.dia = maxi(1, int(datos.get("dia", 1)))
	Juego.duracion_dia_min = clampf(float(datos.get("duracion_dia_min", Juego.DURACION_DIA_POR_DEFECTO)), 1.0, 1000.0)
	Juego.nivel = maxi(1, int(datos.get("nivel", 1)))
	Juego.xp = clampi(int(datos.get("xp", 0)), 0, Juego.xp_necesaria() - 1)
	for id_casa in datos.get("viviendas", []):
		Juego.viviendas[str(id_casa)] = true
	if bool(datos.get("casa_alquilada", false)):   # Partidas de la versión anterior.
		Juego.viviendas["plaza"] = true
	Juego.ha_ganado = bool(datos.get("ha_ganado", false))
	Juego.reputacion = clampi(int(datos.get("reputacion", 0)), -50, 100)
	for e in datos.get("encargos", []):
		if e is Dictionary and GameData.POCIONES.has(str(e.get("pocion", ""))) and e.get("pos", []) is Array \
				and e["pos"].size() == 3 and str(e.get("estado", "")) in ["oferta", "aceptado"]:
			Juego.encargos.append({"id": int(e.get("id", 0)), "cliente": str(e.get("cliente", "Cliente")),
					"pocion": str(e["pocion"]), "cantidad": clampi(int(e.get("cantidad", 1)), 1, 20),
					"pago": maxi(0, int(e.get("pago", 0))), "estado": str(e["estado"]),
					"t": maxf(1.0, float(e.get("t", 60.0))), "lugar": str(e.get("lugar", "")),
					"pos": [float(e["pos"][0]), float(e["pos"][1]), float(e["pos"][2])]})
	for pm in datos.get("pedidos_material", []):
		if pm is Dictionary and DatosObjetos.LISTA.has(str(pm.get("id", ""))):
			Juego.pedidos_material.append({"id": str(pm["id"]), "cantidad": clampi(int(pm.get("cantidad", 1)), 1, 20),
					"t": maxf(1.0, float(pm.get("t", 10.0)))})
	for a in datos.get("avisos", []):
		Juego.avisos.append(str(a))
	for id_hab in datos.get("habilidades", []):
		if DatosHabilidades.LISTA.has(str(id_hab)):
			Juego.habilidades[str(id_hab)] = true
	_leer_lista(datos.get("inventario", []), Juego.inventario)
	_leer_lista(datos.get("estanteria", []), Juego.estanteria)
	Juego.seleccion = clampi(int(datos.get("seleccion", 0)), 0, Juego.TAM_BARRA - 1)

	# Las macetas que hay ahora se vacían antes: si no, al cargar una partida
	# antigua se quedarían las plantas de la partida actual.
	for nodo in arbol.get_nodes_in_group("macetas"):
		var actual: Maceta3D = nodo as Maceta3D
		if actual != null:
			actual.importar({})
	for d in datos.get("macetas", []):
		if d is Dictionary:
			_restaurar_maceta(arbol, d)

	for nodo in arbol.get_nodes_in_group("colocables"):
		nodo.queue_free()
	for c in datos.get("colocables", []):
		var pc: Array = c.get("pos", []) if c is Dictionary else []
		if pc.size() == 3 and Colocable.TIPOS.has(str(c.get("tipo", ""))):
			Colocable.crear(arbol.current_scene, str(c["tipo"]), int(c.get("nivel", 1)), Vector3(pc[0], pc[1], pc[2]))

	var p: Array = datos.get("jugador", [])
	if p.size() == 3:
		jugador.global_position = Vector3(p[0], p[1], p[2])
		if jugador is CharacterBody3D:
			(jugador as CharacterBody3D).velocity = Vector3.ZERO
	Juego.cambio.emit()
	return true


static func _exportar_colocables(arbol: SceneTree) -> Array:
	var r: Array = []
	for nodo in arbol.get_nodes_in_group("colocables"):
		var c: Colocable = nodo as Colocable
		if c != null:
			var p: Vector3 = c.global_position
			r.append({"tipo": c.tipo, "nivel": c.nivel, "pos": [p.x, p.y, p.z]})
	return r


# Copia las casillas guardadas a la lista del juego (convirtiendo los números).
static func _leer_lista(guardada: Array, destino: Array) -> void:
	for i in mini(guardada.size(), destino.size()):
		var c = guardada[i]
		if not c is Dictionary or not c.has("id") or not DatosObjetos.LISTA.has(str(c["id"])):
			destino[i] = null
			continue
		var id: String = str(c["id"])
		var datos_obj: Dictionary = DatosObjetos.datos(id)
		var casilla: Dictionary = {"id": id, "cantidad": clampi(int(c.get("cantidad", 1)), 1, DatosObjetos.pila(id))}
		if datos_obj.has("agua_max"):
			casilla["agua"] = clampi(int(c.get("agua", datos_obj["agua_max"])), 0, int(datos_obj["agua_max"]))
		if c.has("balas") and datos_obj.has("cargador"):
			casilla["balas"] = clampi(int(c["balas"]), 0, int(datos_obj["cargador"]))
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
