# Prueba de las partidas guardadas (ranuras) y los logros. Se ejecuta con:
#   godot --headless --path . res://tests/prueba_partidas.tscn
extends Node

var fallos: int = 0


func comprobar(condicion: bool, texto: String) -> void:
	if not condicion:
		fallos += 1
		print("FALLO: ", texto)


func _ready() -> void:
	await get_tree().process_frame
	await _probar()


func _probar() -> void:
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	var J = raiz.get_node("Juego")
	var L = raiz.get_node("Logros")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	var jugador = hud.jugador
	if hud._menu != null:
		hud._menu.cerrar()
	await get_tree().process_frame

	# Dejar todo limpio (incluida la partida antigua, para probar la migración).
	for n in range(1, Guardado.NUM_RANURAS + 1):
		Guardado.borrar(n)
	L.reiniciar()
	J.reiniciar()
	comprobar(not Guardado.hay_alguna(), "sin partidas al empezar")
	comprobar(Guardado.ranura_libre() == 1, "ranura libre = 1")
	comprobar(Guardado.ultima_ranura() == 0, "sin última ranura")

	# Dos ranuras distintas no se mezclan.
	J.dinero = 111
	J.dia = 3
	comprobar(Guardado.guardar(get_tree(), jugador, 2), "guardar ranura 2")
	J.dinero = 999
	J.dia = 7
	comprobar(Guardado.guardar(get_tree(), jugador, 4), "guardar ranura 4")
	comprobar(Guardado.existe(2) and Guardado.existe(4) and not Guardado.existe(1), "existen 2 y 4")
	comprobar(Guardado.ranura_libre() == 1, "ranura libre sigue siendo 1")
	comprobar(Guardado.ultima_ranura() == 4, "última ranura = 4 (%d)" % Guardado.ultima_ranura())
	var r2: Dictionary = Guardado.resumen(2)
	comprobar(r2.get("dinero", -1) == 111 and r2.get("dia", -1) == 3, "resumen ranura 2 %s" % str(r2))
	comprobar(str(r2.get("fecha", "")) != "", "el resumen trae fecha")
	comprobar(Guardado.resumen(1).is_empty(), "resumen de ranura vacía")
	J.dinero = 5
	comprobar(Guardado.cargar(get_tree(), jugador, 2), "cargar ranura 2")
	comprobar(J.dinero == 111 and J.dia == 3, "ranura 2 restaurada (%d $, día %d)" % [J.dinero, J.dia])
	comprobar(Guardado.ranura == 2, "ranura actual = 2")
	J.dinero = 222
	comprobar(Guardado.guardar(get_tree(), jugador), "guardar en la ranura actual")
	comprobar(Guardado.resumen(2)["dinero"] == 222 and Guardado.resumen(4)["dinero"] == 999, "solo cambió la ranura 2")
	comprobar(not FileAccess.file_exists(Guardado.ruta(2) + ".tmp"), "no queda archivo temporal")

	# Borrar.
	comprobar(Guardado.borrar(4) and not Guardado.existe(4), "borrar ranura 4")
	comprobar(not Guardado.cargar(get_tree(), jugador, 4), "no se carga una ranura borrada")

	# Migración de la partida antigua.
	Guardado.borrar(1)
	var vieja: FileAccess = FileAccess.open(Guardado.RUTA_ANTIGUA, FileAccess.WRITE)
	vieja.store_string(FileAccess.get_file_as_string(Guardado.ruta(2)))
	vieja.close()
	comprobar(Guardado.existe(1), "la partida antigua pasa a la ranura 1")
	comprobar(not FileAccess.file_exists(Guardado.RUTA_ANTIGUA), "se quita el archivo antiguo")

	# Archivo roto.
	var roto: FileAccess = FileAccess.open(Guardado.ruta(3), FileAccess.WRITE)
	roto.store_string("esto no es json")
	roto.close()
	comprobar(Guardado.resumen(3).has("roto"), "ranura rota detectada")
	comprobar(not Guardado.cargar(get_tree(), jugador, 3), "ranura rota no carga")
	Guardado.borrar(3)

	# Ventana de partidas.
	var v: VentanaPartidas = VentanaPartidas.new()
	v.modo = VentanaPartidas.Modo.PAUSA
	v.jugador = jugador
	hud._raiz.add_child(v)
	await get_tree().process_frame
	comprobar(v._filas.get_child_count() == Guardado.NUM_RANURAS, "una fila por ranura")
	v._borrar(1)
	comprobar(Guardado.existe(1), "borrar pide confirmación")
	v._borrar(1)
	comprobar(not Guardado.existe(1), "borrar confirmado")
	v._guardar(5)
	comprobar(Guardado.existe(5), "guardar desde la ventana")
	v.cerrar()
	await get_tree().process_frame

	# Menús de inicio y pausa con ranuras.
	var inicio: Ventanas.Inicio = Ventanas.Inicio.new()
	inicio.jugador = jugador
	hud._abrir_menu(inicio)
	await get_tree().process_frame
	inicio._partidas()
	await get_tree().process_frame
	comprobar(inicio.get_child_count() > 2, "ventana de partidas sobre el inicio")
	inicio.cerrar()
	await get_tree().process_frame
	get_tree().paused = false

	# Logros.
	L.reiniciar()
	J.reiniciar()
	var avisados: Array = []
	L.desbloqueado.connect(func(id): avisados.append(id))
	L.comprobar()
	comprobar(not L.tiene("dinero_1k"), "sin dinero no hay logro")
	J.dinero = 1500
	J.nivel = 3
	L.comprobar()
	comprobar(L.tiene("dinero_1k") and L.tiene("nivel_3"), "logros de dinero y nivel")
	comprobar(not L.tiene("dinero_10k"), "dinero_10k aún no")
	comprobar(avisados.has("dinero_1k"), "señal de logro emitida")
	var n0: int = avisados.size()
	L.comprobar()
	comprobar(avisados.size() == n0, "no se repite el aviso")
	comprobar(not L.desbloquear("dinero_1k"), "desbloquear repetido devuelve false")
	comprobar(not L.desbloquear("no_existe"), "logro inexistente")
	await get_tree().process_frame
	await get_tree().process_frame
	comprobar(hud._cartel_logro != null, "el HUD enseña el cartel de logro")
	# Persisten.
	var antes: int = L.conseguidos.size()
	L.cargar()
	comprobar(L.conseguidos.size() == antes, "logros guardados en disco")
	# Nueva partida / cargar otra ranura no los pierde.
	J.reiniciar()
	comprobar(L.tiene("dinero_1k"), "reiniciar la partida no quita logros")
	# Ventana de logros.
	var vl: VentanaLogros = VentanaLogros.new()
	hud._raiz.add_child(vl)
	await get_tree().process_frame
	vl.cerrar()
	# Los datos son coherentes.
	for id in L.Datos.LISTA:
		var d: Dictionary = L.Datos.LISTA[id]
		comprobar(d.has("nombre") and d.has("desc") and d.has("steam"), "logro %s completo" % id)
		if d.has("tipo"):
			comprobar(L.cuenta(d["tipo"]) is int, "tipo %s válido" % d["tipo"])

	# Limpiar para no dejar basura.
	for n in range(1, Guardado.NUM_RANURAS + 1):
		Guardado.borrar(n)
	L.reiniciar()
	print("RESULTADO PARTIDAS: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)
