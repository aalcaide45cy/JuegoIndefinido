# guardado.gd
# -----------------------------------------------------------------------------
# Guardar y cargar la partida en un archivo. Hay 5 ranuras (user://partida_1.json
# ... partida_5.json; en Windows quedan en %APPDATA%\Godot\app_userdata\Elixir Clandestino).
# Los logros NO van aquí: son de toda la cuenta (ver logros.gd).
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

const RUTA_ANTIGUA: String = "user://partida.json"   # Antes había una sola partida.
const RUTA_ULTIMA: String = "user://ultima_ranura.txt"
const NUM_RANURAS: int = 5
const VERSION: int = 1

# La ranura que se usa al guardar o cargar sin decir cuál (1 a NUM_RANURAS).
static var ranura: int = 1


static func ruta(n: int) -> String:
	return "user://partida_%d.json" % n


# La partida de la versión anterior (user://partida.json) pasa a la ranura 1,
# si esa ranura está vacía. Se llama sola al preguntar por las ranuras.
static func migrar() -> void:
	if FileAccess.file_exists(RUTA_ANTIGUA) and not FileAccess.file_exists(ruta(1)):
		if DirAccess.copy_absolute(RUTA_ANTIGUA, ruta(1)) == OK:
			DirAccess.remove_absolute(RUTA_ANTIGUA)


static func existe(n: int = 0) -> bool:
	migrar()
	return FileAccess.file_exists(ruta(_ranura(n)))


static func _ranura(n: int) -> int:
	return clampi(n if n > 0 else ranura, 1, NUM_RANURAS)


static func hay_alguna() -> bool:
	for n in range(1, NUM_RANURAS + 1):
		if existe(n):
			return true
	return false


# Primera ranura vacía, o 0 si están todas ocupadas.
static func ranura_libre() -> int:
	for n in range(1, NUM_RANURAS + 1):
		if not existe(n):
			return n
	return 0


# La ranura que se usó por última vez (y que "Continuar" abre), o 0 si no hay ninguna partida.
static func ultima_ranura() -> int:
	if FileAccess.file_exists(RUTA_ULTIMA):
		var n: int = int(FileAccess.get_file_as_string(RUTA_ULTIMA).strip_edges())
		if n >= 1 and n <= NUM_RANURAS and existe(n):
			return n
	for n in range(1, NUM_RANURAS + 1):
		if existe(n):
			return n
	return 0


static func _recordar_ultima(n: int) -> void:
	var f: FileAccess = FileAccess.open(RUTA_ULTIMA, FileAccess.WRITE)
	if f != null:
		f.store_string(str(n))
		f.close()


# Borra una ranura. Devuelve true si ya no existe.
static func borrar(n: int) -> bool:
	n = _ranura(n)
	if FileAccess.file_exists(ruta(n)):
		DirAccess.remove_absolute(ruta(n))
	return not FileAccess.file_exists(ruta(n))


# Datos para enseñar en la lista de partidas: {dia, nivel, dinero, fecha}. Vacío si no hay.
static func resumen(n: int) -> Dictionary:
	if not existe(n):
		return {}
	var json: JSON = JSON.new()   # Así un archivo roto no llena la consola de errores.
	if json.parse(FileAccess.get_file_as_string(ruta(_ranura(n)))) != OK or not json.data is Dictionary:
		return {"roto": true}
	var datos: Dictionary = json.data
	var meta = datos.get("meta", {})
	if not meta is Dictionary:
		meta = {}
	return {"dia": maxi(1, int(datos.get("dia", 1))), "nivel": maxi(1, int(datos.get("nivel", 1))),
			"dinero": int(datos.get("dinero", 0)), "fecha": str(meta.get("fecha", ""))}


# Guarda la partida. Devuelve true si salió bien.
static func guardar(arbol: SceneTree, jugador: Node3D, n: int = 0) -> bool:
	n = _ranura(n)
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
		"mundo": GeneradorMundo.VERSION_MUNDO,
		"meta": {"fecha": Time.get_datetime_string_from_system(false, true)},
		"dinero": Juego.dinero,
		"vida": Juego.vida,
		"resistencia": Juego.resistencia,
		"rep_hampa": Juego.rep_hampa,
		"territorios": Juego.territorios,
		"reclutas": Juego.reclutas,
		"deuda": Juego.deuda,
		"dias_deuda": Juego.dias_deuda,
		"rep_ley": Juego.rep_ley,
		"proteccion_hasta_dia": Juego.proteccion_hasta_dia,
		"hambre": Juego.hambre,
		"sed": Juego.sed,
		"atributos": Juego.atributos,
		"hora": Juego.hora,
		"dia": Juego.dia,
		"duracion_dia_min": Juego.duracion_dia_min,
		"nivel": Juego.nivel,
		"xp": Juego.xp,
		"habilidades": Juego.habilidades.keys(),
		"aspecto": Juego.aspecto,
		"vehiculos": _vehiculos_para_guardar(arbol),
		"personal": Juego.personal,
		"almacen": Juego.almacen,
		"almacen_ultima_semilla": Juego.almacen_ultima_semilla,
		"dia_pago": Juego.dia_pago,
		"negocio": Juego.negocio,
		"contador_vehiculos": Juego._contador_vehiculos,
		"plazas_tomadas": Juego.plazas_tomadas.keys(),
		"viviendas": Juego.viviendas.keys(),
		"ha_ganado": Juego.ha_ganado,
		"reputacion": Juego.reputacion,
		"banco": Juego.banco,
		"huertos": Juego.huertos.keys(),
		"en_propiedad": Juego.en_propiedad.keys(),
		"clima": Clima.exportar(),
		"parcelas": Juego.parcelas,
		"granja": Juego.granja,
		"reloj": Juego.reloj,
		"impagos": Juego.impagos,
		"metas": Juego.metas_cobradas,
		"oficio": Juego.oficio,
		"oficios_xp": Juego.oficios_xp,
		"encargos": Juego.encargos,
		"pedidos_material": Juego.pedidos_material,
		"avisos": Juego.avisos,
		"recetario": Juego.recetario,
		"efectos": Juego.efectos_activos,
		"seleccion": Juego.seleccion,
		"inventario": Juego.inventario,
		"estanteria": Juego.estanteria,
		"macetas": macetas,
		"colocables": _exportar_colocables(arbol),
		"jugador": [pos.x, pos.y, pos.z],
	}
	# Se escribe primero en un archivo temporal: si algo falla a medias, la partida buena sigue ahí.
	var temporal: String = ruta(n) + ".tmp"
	var archivo: FileAccess = FileAccess.open(temporal, FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(JSON.stringify(datos, "\t"))
	archivo.close()
	if DirAccess.rename_absolute(temporal, ruta(n)) != OK:
		DirAccess.remove_absolute(temporal)
		return false
	ranura = n
	_recordar_ultima(n)
	return true


# Las partidas de antes de las ciudades vivas (sin "mundo") guardan ids de casas y huertos de la
# distribución antigua de pueblos. Se traducen a casas y huertos equivalentes del mundo actual
# (en todo lo que lleve el id: viviendas, huertos, compras, cultivos, impagos, granja, personal).
static func _migrar_mundo(datos: Dictionary) -> void:
	if int(datos.get("mundo", 1)) >= GeneradorMundo.VERSION_MUNDO or not GeneradorMundo.listo:
		return
	var mapa: Dictionary = {}
	var usados: Dictionary = {}
	for clave in ["viviendas", "huertos", "en_propiedad"]:
		for id in datos.get(clave, []):
			var sid: String = str(id)
			if sid.begins_with("w_") and not mapa.has(sid):
				var nuevo: String = GeneradorMundo.migrar_id(sid, usados)
				if nuevo != "":
					usados[nuevo] = true
					mapa[sid] = nuevo
	if not mapa.is_empty():
		for clave in ["viviendas", "huertos", "en_propiedad"]:
			var nueva: Array = []
			for id in datos.get(clave, []):
				nueva.append(mapa.get(str(id), str(id)))
			datos[clave] = nueva
		for clave in ["parcelas", "impagos", "granja", "almacen_ultima_semilla"]:
			var d = datos.get(clave, {})
			if d is Dictionary:
				var nd: Dictionary = {}
				for id in d:
					nd[mapa.get(str(id), str(id))] = d[id]
				datos[clave] = nd
		for e in datos.get("personal", []):
			if e is Dictionary and mapa.has(str(e.get("destino", ""))):
				e["destino"] = mapa[str(e["destino"])]
		var avisos: Array = datos.get("avisos", [])
		avisos.append("Los pueblos cambiaron de sitio: tus %d casas y huertos se han trasladado a pueblos cercanos." % mapa.size())
		datos["avisos"] = avisos
	datos["mundo"] = GeneradorMundo.VERSION_MUNDO


# Carga la partida. Devuelve true si salió bien.
static func cargar(arbol: SceneTree, jugador: Node3D, n: int = 0) -> bool:
	n = _ranura(n)
	if not existe(n):
		return false
	var archivo: FileAccess = FileAccess.open(ruta(n), FileAccess.READ)
	if archivo == null:
		return false
	var datos = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if not datos is Dictionary:
		return false

	_migrar_mundo(datos)
	Juego.reiniciar()
	ranura = n
	_recordar_ultima(n)
	# Todo se comprueba al leer: un archivo tocado a mano o roto no debe dejar
	# dinero negativo, vida a cero o montones más grandes de lo permitido.
	Juego.dinero = maxi(0, int(datos.get("dinero", Juego.dinero)))
	Juego.banco = maxi(0, int(datos.get("banco", 0)))
	var attrs = datos.get("atributos")
	if attrs is Dictionary:
		for id in Juego.Estadisticas.ORDEN:
			Juego.atributos[id] = clampi(int(attrs.get(id, Juego.Estadisticas.ATRIBUTO_INICIAL)), 1, Juego.Estadisticas.ATRIBUTO_MAX)
	var terr = datos.get("territorios")
	if terr is Dictionary:
		for k in terr:
			Juego.territorios[str(k)] = "jugador"
	Juego.reclutas = clampi(int(datos.get("reclutas", 0)), 0, 4)
	Juego.deuda = maxi(0, int(datos.get("deuda", 0)))
	Juego.dias_deuda = maxi(0, int(datos.get("dias_deuda", 0)))
	Juego.rep_hampa = clampi(int(datos.get("rep_hampa", 0)), -100, 100)
	Juego.rep_ley = clampi(int(datos.get("rep_ley", 0)), -100, 100)
	Juego.proteccion_hasta_dia = maxi(0, int(datos.get("proteccion_hasta_dia", 0)))
	Juego.hambre = clampf(float(datos.get("hambre", 0.0)), 0.0, 100.0)
	Juego.sed = clampf(float(datos.get("sed", 0.0)), 0.0, 100.0)
	Juego.resistencia = clampf(float(datos.get("resistencia", 100.0)), 0.0, 100.0)
	Juego.vida = clampf(float(datos.get("vida", Juego.vida)), 1.0, Juego.vida_max())
	Juego.hora = fposmod(float(datos.get("hora", Juego.hora)), 24.0)
	Clima.importar(datos.get("clima"))
	Juego.dia = maxi(1, int(datos.get("dia", 1)))
	Juego.duracion_dia_min = clampf(float(datos.get("duracion_dia_min", Juego.DURACION_DIA_POR_DEFECTO)), 1.0, 1000.0)
	Juego.nivel = maxi(1, int(datos.get("nivel", 1)))
	Juego.xp = clampi(int(datos.get("xp", 0)), 0, Juego.xp_necesaria() - 1)
	for id_casa in datos.get("viviendas", []):
		Juego.viviendas[str(id_casa)] = true
	if bool(datos.get("casa_alquilada", false)):   # Partidas de la versión anterior.
		Juego.viviendas["plaza"] = true
	Juego.ha_ganado = bool(datos.get("ha_ganado", false))
	for id_h in datos.get("huertos", []):
		Juego.huertos[str(id_h)] = true
	for id_p in datos.get("en_propiedad", []):
		Juego.en_propiedad[str(id_p)] = true
	var parcelas_g = datos.get("parcelas", {})
	if parcelas_g is Dictionary:
		for id_h in parcelas_g:
			var pg = parcelas_g[id_h]
			if pg is Dictionary and Parcela.CULTIVOS.has(str(pg.get("semilla", ""))):
				Juego.parcelas[str(id_h)] = {"semilla": str(pg["semilla"]), "t": maxf(0.0, float(pg.get("t", 0.0))),
						"total": maxf(1.0, float(pg.get("total", 100.0)))}
	Juego.metas_cobradas.clear()
	var of: String = str(datos.get("oficio", ""))
	Juego.oficio = of if Juego.DatosOficios.existe(of) else ""
	var oxp = datos.get("oficios_xp", {})
	if oxp is Dictionary:
		for k in oxp:
			if Juego.DatosOficios.existe(str(k)):
				Juego.oficios_xp[str(k)] = maxi(0, int(oxp[k]))
	var mt = datos.get("metas", {})
	if mt is Dictionary:
		for k in mt:
			Juego.metas_cobradas[str(k)] = true
	Juego.impagos.clear()
	var imp = datos.get("impagos", {})
	if imp is Dictionary:
		for k in imp:
			Juego.impagos[str(k)] = clampi(int(imp[k]), 1, 3)
	Juego.reloj = maxf(0.0, float(datos.get("reloj", 0.0)))
	var granja_g = datos.get("granja", {})
	if granja_g is Dictionary:
		for id_g in granja_g:
			var gg = granja_g[id_g]
			if gg is Dictionary:
				Juego.granja[str(id_g)] = {"n": clampi(int(gg.get("n", 0)), 0, 12), "prod": clampi(int(gg.get("prod", 0)), 0, 20),
						"t": maxf(0.0, float(gg.get("t", 0.0))), "nivel": clampi(int(gg.get("nivel", 1)), 1, 3),
						"u": minf(Juego.reloj, float(gg.get("u", Juego.reloj)))}
	Juego.reputacion = clampi(int(datos.get("reputacion", 0)), -50, 100)
	for e in datos.get("encargos", []):
		if e is Dictionary and GameData.existe_pocion(str(e.get("pocion", ""))) and e.get("pos", []) is Array \
				and e["pos"].size() == 3 and str(e.get("estado", "")) in ["oferta", "aceptado"]:
			Juego.encargos.append({"id": int(e.get("id", 0)), "cliente": str(e.get("cliente", "Cliente")),
					"pocion": str(e["pocion"]), "cantidad": clampi(int(e.get("cantidad", 1)), 1, 20),
					"pago": maxi(0, int(e.get("pago", 0))), "estado": str(e["estado"]),
					"t": maxf(1.0, float(e.get("t", 60.0))), "lugar": str(e.get("lugar", "")),
					"pos": [float(e["pos"][0]), float(e["pos"][1]), float(e["pos"][2])]})
	for pm in datos.get("pedidos_material", []):
		if pm is Dictionary and DatosObjetos.existe(str(pm.get("id", ""))):
			Juego.pedidos_material.append({"id": str(pm["id"]), "cantidad": clampi(int(pm.get("cantidad", 1)), 1, 20),
					"t": maxf(1.0, float(pm.get("t", 10.0)))})
	var recetario_g = datos.get("recetario", {})
	if recetario_g is Dictionary:
		for id_r in recetario_g:
			if GameData.existe_pocion(str(id_r)):
				Juego.recetario[str(id_r)] = maxi(1, int(recetario_g[id_r]))
	var efectos_g = datos.get("efectos", {})
	if efectos_g is Dictionary:
		for id_e in efectos_g:
			var eg = efectos_g[id_e]
			if eg is Dictionary and Juego.DatosEfectos.existe(str(id_e)) and float(eg.get("t", 0.0)) > 0.0:
				var total: float = clampf(float(eg.get("total", eg["t"])), 1.0, 3600.0)
				Juego.efectos_activos[str(id_e)] = {"t": clampf(float(eg["t"]), 0.1, total), "total": total,
						"f": clampf(float(eg.get("f", 1.0)), 0.1, 3.0)}
	for a in datos.get("avisos", []):
		Juego.avisos.append(str(a))
	Juego.aspecto = Juego.DatosAspecto.valido(datos.get("aspecto", {}))
	_leer_vehiculos(datos.get("vehiculos", {}))
	_leer_personal(datos)
	Negocios.importar(datos.get("negocio", {}))
	Juego._contador_vehiculos = maxi(0, int(datos.get("contador_vehiculos", Juego.vehiculos.size())))
	for id_pl in datos.get("plazas_tomadas", []):
		Juego.plazas_tomadas[str(id_pl)] = true
	# Partidas guardadas con el fallo antiguo traen los 7 coches aparcados como si fueran tuyos:
	# solo valen los que están en plazas_tomadas (robados de verdad).
	for id_v in Juego.vehiculos.keys():
		if str(id_v).begins_with("amb_") and not Juego.plazas_tomadas.has(str(id_v)):
			Juego.vehiculos.erase(id_v)
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
	var jug: Jugador = jugador as Jugador
	if jug != null:
		jug.vestir()
	arbol.call_group("gestor_vehiculos", "sincronizar")
	Negocios.ponerse_al_dia()
	Juego.cambio.emit()
	return true


# Pone al día la posición de los vehículos que hay en el mundo y devuelve los datos.
static func _vehiculos_para_guardar(arbol: SceneTree) -> Dictionary:
	for nodo in arbol.get_nodes_in_group("vehiculos"):
		if nodo.has_method("guardar_estado"):
			nodo.guardar_estado()
	return Juego.vehiculos


static func _leer_personal(datos: Dictionary) -> void:
	const DatosPersonal = preload("res://scripts/datos/personal.gd")
	for e in datos.get("personal", []):
		if e is Dictionary and DatosPersonal.OFICIOS.has(str(e.get("oficio", ""))) \
				and Juego.personal.size() < DatosPersonal.MAX_PERSONAL:
			var nivel: int = clampi(int(e.get("nivel", 1)), 1, 3)
			Juego.personal.append({"id": str(e.get("id", "")), "nombre": str(e.get("nombre", "Empleado")),
					"oficio": str(e["oficio"]), "nivel": nivel, "sueldo": maxi(0, int(e.get("sueldo", 30))),
					"destino": str(e.get("destino", ""))})
	var alm = datos.get("almacen", {})
	if alm is Dictionary:
		for id_o in alm:
			if DatosObjetos.LISTA.has(str(id_o)):
				Juego.almacen[str(id_o)] = maxi(0, int(alm[id_o]))
	var ult = datos.get("almacen_ultima_semilla", {})
	if ult is Dictionary:
		for id_h in ult:
			Juego.almacen_ultima_semilla[str(id_h)] = str(ult[id_h])
	Juego.dia_pago = clampi(int(datos.get("dia_pago", Juego.dia)), 1, maxi(1, Juego.dia))


static func _leer_vehiculos(guardados) -> void:
	if not guardados is Dictionary:
		return
	for id_v in guardados:
		var v = guardados[id_v]
		if v is Dictionary and Vehiculo.TIPOS.has(str(v.get("tipo", ""))) and v.get("pos", []) is Array and v["pos"].size() == 3:
			Juego.vehiculos[str(id_v)] = {"tipo": str(v["tipo"]),
					"pos": [float(v["pos"][0]), float(v["pos"][1]), float(v["pos"][2])],
					"giro": float(v.get("giro", 0.0)), "gas": clampf(float(v.get("gas", 100.0)), 0.0, 100.0),
					"salud": clampf(float(v.get("salud", 100.0)), 0.0, 100.0)}


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
		if not c is Dictionary or not c.has("id") or not DatosObjetos.existe(str(c["id"])):
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
