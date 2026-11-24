# Prueba de sangre, charcos, gritos, guardias y peatones al recibir daño.
#   godot --headless --path . res://tests/prueba_gore.tscn
extends Node

var fallos: int = 0


func comprobar(c: bool, t: String) -> void:
	if not c:
		fallos += 1
		print("FALLO: ", t)


func _ready() -> void:
	await get_tree().process_frame
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	for i in 3:
		await get_tree().process_frame
	var J = raiz.get_node("Juego")
	var G = raiz.get_node("Graficos")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	var pos: Vector3 = hud.jugador.global_position + Vector3(0, 0, -6)

	# Niveles de violencia: contadores de efectos.
	G.v["gore"] = 2
	var antes: int = Gore._charcos.size()
	Gore.salpicar(escena, pos, Vector3.UP, 1.0)
	Gore.charco(escena, pos, 0.8)
	Gore.trozos(escena, pos, 5)
	Gore.muerte(escena, pos, Vector3.UP, 2.0)
	comprobar(Gore._charcos.size() == antes + 1, "gore completo: charco (el de la muerte lo pone Cuerpo bajo el cadáver)")
	comprobar(Gore._trozos.size() >= 5, "gore completo: hay trozos")
	for i in 60:
		Gore.charco(escena, pos, 0.5)
	comprobar(Gore._charcos.size() <= Gore.MAX_CHARCOS[2], "tope de charcos")
	G.v["gore"] = 1
	var tz: int = Gore._trozos.size()
	Gore.trozos(escena, pos, 5)
	comprobar(Gore._trozos.size() <= tz, "gore reducido: sin trozos nuevos")
	G.v["gore"] = 0
	var c0: int = Gore._charcos.size()
	Gore.charco(escena, pos, 0.5)
	comprobar(Gore._charcos.size() == c0, "gore apagado: sin charco")
	G.v["gore"] = 2
	Gore.grito(escena, pos, 0)

	# Guardia: parada, esquiva, derribo y muerte.
	var gu: Guardia = Guardia.new()
	gu.pasea_ciudad = false
	gu.ruta = [pos]
	escena.add_child(gu)
	await get_tree().process_frame
	gu._poner_activo(true)
	gu._persiguiendo = false
	gu.recibir_dano(5.0)
	comprobar(gu._vida < Guardia.VIDA_MAXIMA, "guardia recibe daño")
	for i in 30:   # Puede parar o esquivar alguno: se repite hasta que le entra uno.
		if gu._t_aturdido > 0.0:
			break
		gu._vida = Guardia.VIDA_MAXIMA
		gu.recibir_dano(20.0)
	comprobar(gu._t_aturdido > 0.0, "golpe fuerte derriba al guardia")
	gu._persiguiendo = true
	gu._parar()
	gu._esquivar()
	gu.recibir_dano(500.0)
	await get_tree().process_frame
	comprobar(gu._muerto, "guardia muere")

	# Peatones: hay que dejar que la vida urbana cree alguno.
	var vu: VidaUrbana = null
	for n in escena.find_children("*", "VidaUrbana", true, false):
		vu = n
	comprobar(vu != null, "hay VidaUrbana")
	if vu != null:
		hud.jugador.global_position = Vector3(30, 1, -30)
		for i in 400:
			await get_tree().physics_frame
		print("peatones: ", vu._peatones.size())
		if not vu._peatones.is_empty():
			var p = vu._peatones[0]
			p.derribar(Vector3.FORWARD, 9.0, true)
			comprobar(p.has_meta("muerto"), "atropello a 9 m/s mata")
			await get_tree().create_timer(0.7).timeout
			if vu._peatones.size() > 1:
				var q = vu._peatones[1]
				q.recibir_dano(5.0)
				comprobar(q.huyendo, "peatón golpeado huye")
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit()
