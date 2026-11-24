# Prueba de la magia: escuelas, niveles, maná, esperas, efectos, riesgo legal, guardado y grimorio.
#   godot --headless --path . res://tests/prueba_magia.tscn
extends Node

const DatosMagia = preload("res://scripts/datos/magia.gd")

var fallos: Array = []


func comprobar(c: bool, t: String) -> void:
	if c:
		print("  ok: ", t)
	else:
		fallos.append(t)
		print("FALLO: ", t)


func _ready() -> void:
	await get_tree().process_frame
	var copia = FileAccess.get_file_as_bytes(Guardado.ruta(5)) if FileAccess.file_exists(Guardado.ruta(5)) else null
	var ultima = FileAccess.get_file_as_bytes(Guardado.RUTA_ULTIMA) if FileAccess.file_exists(Guardado.RUTA_ULTIMA) else null
	var ranura_antes: int = Guardado.ranura
	await _probar()
	Guardado.borrar(5)
	if copia != null:
		var f: FileAccess = FileAccess.open(Guardado.ruta(5), FileAccess.WRITE)
		f.store_buffer(copia)
		f.close()
	if ultima != null:
		var f2: FileAccess = FileAccess.open(Guardado.RUTA_ULTIMA, FileAccess.WRITE)
		f2.store_buffer(ultima)
		f2.close()
	Guardado.ranura = ranura_antes
	print("RESULTADO: ", "TODO BIEN" if fallos.is_empty() else "FALLO " + str(fallos))
	get_tree().quit()


func _probar() -> void:
	# Datos: 4 escuelas x 3 hechizos, todos con sus campos y efectos que existen.
	comprobar(DatosMagia.ESCUELAS.size() == 4 and DatosMagia.todos().size() == 12, "4 escuelas y 12 hechizos")
	var DatosEfectos = load("res://scripts/datos/efectos.gd")
	for id in DatosMagia.todos():
		var h: Dictionary = DatosMagia.HECHIZOS[id]
		for campo in ["nombre", "descripcion", "coste", "espera", "riesgo", "tipo", "escuela"]:
			if not h.has(campo):
				comprobar(false, "%s tiene %s" % [id, campo])
		if h.has("efecto"):
			comprobar(DatosEfectos.existe(str(h["efecto"])), "el efecto de %s existe" % id)
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	Juego.reiniciar()
	Juego.hora = 3.0   # De noche: menos riesgo.
	var M: Node = raiz.get_node("Magia")
	var jugador: Node3D = hud.jugador
	jugador.global_position = Vector3(400.0, GeneradorMundo.altura(400.0, 400.0) + 1.0, 400.0)   # En el campo, sin testigos.
	await get_tree().create_timer(0.5).timeout
	comprobar(M.mana == DatosMagia.MANA_MAX, "se empieza con el maná lleno")
	comprobar(M.sabe("brote") and M.sabe("velo") and M.sabe("empujon") and M.sabe("ganzua_sombria"), "se sabe el primer hechizo de cada escuela")
	comprobar(not M.sabe("sanar") and not M.sabe("pavor"), "los hechizos 2 y 3 piden nivel")
	# Efecto: Velo da sigilo.
	var texto: String = M.lanzar("velo")
	comprobar(Juego.efectos_activos.has("sigilo"), "Velo pone el efecto Sigilo (%s)" % texto)
	comprobar(M.mana < DatosMagia.MANA_MAX, "lanzar gasta maná")
	comprobar(M.lanzar("velo").contains("espera"), "hay tiempo de espera entre lanzamientos")
	# Sin plantas cerca, Brote no gasta.
	var antes: float = M.mana
	M.lanzar("brote")
	comprobar(M.mana == antes, "Brote sin plantas no gasta maná")
	# Sin maná no se lanza.
	M.mana = 1.0
	comprobar(M.lanzar("empujon").contains("maná"), "sin maná no se lanza")
	M.mana = DatosMagia.MANA_MAX
	# Subir de nivel: con XP de escuela se aprende Sanar.
	M.xp["naturaleza"] = float(DatosMagia.XP_NIVEL[1])
	comprobar(M.nivel("naturaleza") == 2 and M.sabe("sanar"), "a nivel 2 se aprende Sanar")
	comprobar(M.coste("sanar") < float(DatosMagia.HECHIZOS["sanar"]["coste"]), "con nivel cuesta menos")
	Juego.vida = 20.0
	M.lanzar("sanar")
	comprobar(Juego.vida > 20.0, "Sanar cura (vida %d)" % int(Juego.vida))
	# Rostro ajeno baja estrellas.
	M.xp["ilusion"] = float(DatosMagia.XP_NIVEL[1])
	Juego.estrellas = 2
	M.mana = DatosMagia.MANA_MAX
	M.lanzar("rostro_ajeno")
	comprobar(Juego.estrellas == 1, "Rostro ajeno baja una estrella")
	# Riesgo: un guardia cerca de día ve el hechizo.
	Juego.hora = 12.0
	Juego.estrellas = 0
	var guardias: Array = get_tree().get_nodes_in_group("guardias")
	if guardias.size() > 0:
		var g: Node3D = guardias[0]
		jugador.global_position = g.global_position + Vector3(3.0, 0.0, 0.0)
		M.esperas.clear()
		M.mana = DatosMagia.MANA_MAX
		Juego.efectos_activos.erase("sigilo")
		M.lanzar("empujon")
		comprobar(Juego.estrellas >= 1, "un guardia que te ve hacer magia sube la búsqueda")
	else:
		print("  (no hay guardias en la escena: se salta la prueba de riesgo)")
	# Guardado.
	M.xp["sombras"] = float(DatosMagia.XP_NIVEL[2])
	M.preparar("apagon")
	Guardado.guardar(get_tree(), jugador, 5)
	M.reiniciar()
	comprobar(M.nivel("sombras") == 1, "reiniciar deja la magia a cero")
	Guardado.cargar(get_tree(), jugador, 5)
	comprobar(M.nivel("sombras") == 3 and M.preparado == "apagon", "la magia se guarda y se carga")
	Juego.reiniciar()
	comprobar(M.nivel("sombras") == 1, "una partida nueva empieza sin magia aprendida")
	# Grimorio.
	var v: VentanaGrimorio = VentanaGrimorio.new()
	hud._abrir_menu(v)
	await get_tree().process_frame
	await get_tree().process_frame
	comprobar(v.find_children("*", "Button", true, false).size() >= 5, "el grimorio se abre con botones para preparar")
	v.cerrar()
	escena.queue_free()
	await get_tree().process_frame
