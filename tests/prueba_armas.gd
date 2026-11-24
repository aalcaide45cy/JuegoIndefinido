# Prueba de armas dentro del mundo: balas por zonas, escopeta, cuchillo, explosión y efectos.
#   godot --headless --path . res://tests/prueba_armas.tscn
extends Node

var fallos: int = 0


func comprobar(c: bool, t: String) -> void:
	if not c:
		fallos += 1
		print("FALLO: ", t)
	else:
		print("ok: ", t)


func _guardia(escena: Node, pos: Vector3) -> Guardia:
	var gu: Guardia = Guardia.new()
	gu.pasea_ciudad = false
	gu.ruta = [pos]
	escena.add_child(gu)
	await get_tree().process_frame
	gu._poner_activo(true)
	gu.global_position = pos
	gu._persiguiendo = false
	for i in 3:
		await get_tree().physics_frame
	return gu


func _ready() -> void:
	await get_tree().process_frame
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	for i in 3:
		await get_tree().process_frame
	var J = raiz.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	var jug = hud.jugador
	await get_tree().create_timer(2.0).timeout
	Graficos.v["gore"] = 2
	var adelante: Vector3 = -jug.global_basis.z
	adelante.y = 0.0
	adelante = adelante.normalized()
	# 1) Guardia: tiro de pistola en la cabeza.
	var gu: Guardia = await _guardia(escena, jug.global_position + adelante * 6.0)
	var cabeza: Vector3 = gu.global_position + Vector3(0, 1.6, 0)
	var dir: Vector3 = (cabeza - jug._origen()).normalized()
	var r: String = jug._bala(dir, 20.0, "bala", true)
	print("tiro a la cabeza: ", r)
	comprobar(r == "cabeza", "la pistola en la cabeza da 'cabeza' (marcador rojo)")
	comprobar(gu._muerto, "el guardia muere de un tiro en la cabeza")
	await get_tree().create_timer(0.2).timeout
	var esq: Skeleton3D = Cuerpo.esqueleto(gu._modelo)
	comprobar(esq != null and Cuerpo._simulador(esq) != null, "el guardia cae con ragdoll")
	# Disparar al cadáver: la bala da en un hueso del ragdoll y lo mueve.
	var r2: String = jug._bala((Cuerpo.centro(gu, gu._modelo) - jug._origen()).normalized(), 20.0, "bala", true)
	print("tiro al cadáver: ", r2)
	# 2) Otro guardia: tiro en la pierna (no muere; daño reducido).
	var g2: Guardia = await _guardia(escena, jug.global_position + adelante * 6.0 + adelante.cross(Vector3.UP) * 2.5)
	var vida0: float = g2._vida
	var e2: Skeleton3D = Cuerpo.esqueleto(g2._modelo)
	var pierna: Vector3 = e2.global_transform * e2.get_bone_global_pose(Cuerpo.hueso(e2, "LowerLeg.L")).origin + Vector3(0, -0.12, 0)
	print("zona pierna: ", Cuerpo.zona_de(g2, g2._modelo, jug._origen(), (pierna - jug._origen()).normalized(), pierna))
	print("guardia pos ", g2.global_position, " jugador ", jug._origen())
	var r3: String = ""
	for i in 6:   # El guardia a veces para o esquiva: se intenta varias veces.
		r3 = jug._bala((pierna - jug._origen()).normalized(), 20.0, "bala", false)
		if g2._vida < vida0:
			break
	print("pierna: ", r3, " vida ", vida0, " -> ", g2._vida)
	comprobar(g2._vida < vida0 and vida0 - g2._vida <= 20.0 * 0.7, "en la pierna hace menos daño")
	# 3) Disparo completo (efectos) con escopeta y rifle, sin errores.
	var casilla: Dictionary = {"id": "escopeta", "balas": 6}
	jug._disparar(casilla, J.DatosObjetos.datos("escopeta"))
	comprobar(casilla["balas"] == 5, "la escopeta gasta un cartucho")
	jug._enfriamiento = 0.0
	var casilla2: Dictionary = {"id": "rifle", "balas": 30}
	for i in 5:
		jug._disparar(casilla2, J.DatosObjetos.datos("rifle"))
	comprobar(jug._bloom > 0.0, "disparar seguido abre la dispersión")
	comprobar(EfectosArma._casquillos.size() >= 5, "salen casquillos")
	# 4) Explosión junto a un guardia: lo lanza y puede arrancarle algo.
	var g3: Guardia = await _guardia(escena, jug.global_position + adelante * 10.0)
	Combate.explosion(escena, g3.global_position + Vector3(0.5, 0.2, 0), 6.0, 150.0)
	await get_tree().create_timer(0.3).timeout
	comprobar(g3._muerto, "la granada mata al guardia de al lado")
	# 5) Cuchillo.
	jug._golpear(J.DatosObjetos.datos("cuchillo"))
	await get_tree().create_timer(1.0).timeout
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit()
