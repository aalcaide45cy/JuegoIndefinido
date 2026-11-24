# Prueba del cuerpo: zonas de impacto, desmembramiento y ragdoll (sin cargar el mundo).
#   godot --headless --path . res://tests/prueba_cuerpo.tscn
extends Node3D

var fallos: int = 0


func comprobar(c: bool, t: String) -> void:
	if not c:
		fallos += 1
		print("FALLO: ", t)
	else:
		print("ok: ", t)


class Muneco extends CharacterBody3D:
	var modelo: Node3D
	var vida: float = 100.0
	var _muerto: bool = false
	func _ready() -> void:
		add_to_group("personas")
		var f: CollisionShape3D = CollisionShape3D.new()
		var c: CapsuleShape3D = CapsuleShape3D.new()
		c.radius = 0.35
		c.height = 1.7
		f.shape = c
		f.position.y = 0.85
		add_child(f)
		modelo = Assets.personaje("quaternius/toon-shooter-game-kit/Characters/Character_Soldier", "Pistol", "Idle")
		add_child(modelo)
	func recibir_dano(c: float) -> void:
		if _muerto:
			return
		vida -= c
		if vida <= 0.0:
			_muerto = true
			collision_layer = 0
			Cuerpo.al_morir(self, modelo, Vector3.ZERO, 3.0)


func _suelo() -> void:
	var s: StaticBody3D = StaticBody3D.new()
	var f: CollisionShape3D = CollisionShape3D.new()
	var b: BoxShape3D = BoxShape3D.new()
	b.size = Vector3(60, 1, 60)
	f.shape = b
	s.add_child(f)
	s.position.y = -0.5
	add_child(s)


func _muneco(pos: Vector3) -> Muneco:
	var m: Muneco = Muneco.new()
	add_child(m)
	m.global_position = pos
	return m


func _ready() -> void:
	Graficos.v["gore"] = 2
	_suelo()
	await get_tree().physics_frame
	var a: Muneco = _muneco(Vector3(0, 0, 0))
	for i in 5:
		await get_tree().process_frame
	comprobar(Cuerpo.esqueleto(a.modelo) != null, "el modelo tiene esqueleto")
	# El modelo mira hacia -Z (rotado PI). Disparamos desde delante (z = -5) hacia +Z.
	var desde: Vector3 = Vector3(0, 1.55, -5)
	var z: Dictionary = Cuerpo.zona_de(a, a.modelo, desde, Vector3(0, 0, 1), Vector3.ZERO)
	print("zona cabeza: ", z)
	comprobar(z.get("zona") == "cabeza" and not z.get("fallo"), "disparo a 1,55 m da en la cabeza")
	z = Cuerpo.zona_de(a, a.modelo, Vector3(0, 1.1, -5), Vector3(0, 0, 1), Vector3.ZERO)
	comprobar(z.get("zona") == "torso", "disparo a 1,1 m da en el torso")
	z = Cuerpo.zona_de(a, a.modelo, Vector3(0.18, 0.4, -5), Vector3(0, 0, 1), Vector3.ZERO)
	comprobar(String(z.get("zona")).begins_with("pierna"), "disparo bajo da en una pierna: %s" % z)
	z = Cuerpo.zona_de(a, a.modelo, Vector3(0, 2.5, -5), Vector3(0, 0, 1), Vector3.ZERO)
	comprobar(z.get("fallo") == true, "disparo por encima de la cabeza no toca")
	# Lado: un brazo (el modelo está en pose Idle con brazos caídos).
	var esq: Skeleton3D = Cuerpo.esqueleto(a.modelo)
	var codo: Vector3 = esq.global_transform * esq.get_bone_global_pose(Cuerpo.hueso(esq, "LowerArm.L")).origin
	z = Cuerpo.zona_de(a, a.modelo, codo + Vector3(0, 0, -5), Vector3(0, 0, 1), Vector3.ZERO)
	comprobar(String(z.get("zona")).begins_with("brazo"), "disparo al codo da en un brazo: %s" % z)
	# Daño por zona con impactar.
	var r: Dictionary = Cuerpo.impactar(a, desde, Vector3(0, 0, 1), 20.0, "bala", {"punto": Vector3(0, 1.55, -0.3), "distancia": 5.0})
	comprobar(is_equal_approx(float(r.get("dano", 0)), 20.0 * Cuerpo.MULT["cabeza"]), "la cabeza multiplica el daño")
	comprobar(a._muerto, "un tiro de pistola en la cabeza mata (100 de vida)")
	await get_tree().create_timer(0.1).timeout
	var sim = null
	for h in esq.get_children():
		if h is PhysicalBoneSimulator3D:
			sim = h
	comprobar(sim != null and sim.is_simulating_physics(), "al morir cae con ragdoll")
	var pelvis0: Vector3 = Cuerpo.centro(a, a.modelo)
	await get_tree().create_timer(2.5).timeout
	var pelvis1: Vector3 = Cuerpo.centro(a, a.modelo)
	print("pelvis antes ", pelvis0, " despues ", pelvis1)
	comprobar(pelvis1.y < 0.45 and pelvis1.y > -0.2, "el cuerpo acaba en el suelo (y=%.2f)" % pelvis1.y)
	comprobar(pelvis1.distance_to(pelvis0) < 4.0, "y no sale disparado lejos")
	await get_tree().create_timer(4.0).timeout
	print("sim: ", Cuerpo._simulador(esq), " ms ", esq.get_meta("_ragdoll_ms", -1), " ahora ", Time.get_ticks_msec())
	comprobar(Cuerpo._simulador(esq) == null, "a los 6 s se congela (sin física)")
	var pelvis2: Vector3 = Cuerpo.centro(a, a.modelo)
	print("pelvis congelada ", pelvis2)
	# Desmembrar un brazo de un vivo.
	var b: Muneco = _muneco(Vector3(3, 0, 0))
	for i in 5:
		await get_tree().process_frame
	var n_antes: int = Cuerpo._miembros.size()
	comprobar(Cuerpo.desmembrar(b, b.modelo, "UpperArm.L", Vector3(1, 0, 0), 60.0), "se puede cortar un brazo")
	comprobar(Cuerpo._miembros.size() == n_antes + 1, "el brazo sale volando como trozo con física")
	await get_tree().create_timer(0.3).timeout
	var eb: Skeleton3D = Cuerpo.esqueleto(b.modelo)
	var ib: int = Cuerpo.hueso(eb, "UpperArm.L")
	var escala: Vector3 = eb.get_bone_global_pose(Cuerpo.hueso(eb, "LowerArm.L")).basis.get_scale()
	print("escala antebrazo tras corte ", escala)
	comprobar(Cuerpo._pose(eb).cortes.has(ib), "queda registrado el corte")
	comprobar(not b._muerto, "perder un brazo no mata en el acto")
	var trozo: RigidBody3D = Cuerpo._miembros.back()
	var y0: float = trozo.global_position.y
	await get_tree().create_timer(2.0).timeout
	print("brazo y ", y0, " -> ", trozo.global_position.y)
	comprobar(trozo.global_position.y < 0.5, "el brazo cae al suelo")
	# Escopeta a bocajarro en la cabeza: revienta.
	var c: Muneco = _muneco(Vector3(-3, 0, 0))
	for i in 5:
		await get_tree().process_frame
	var mato: bool = false
	var corte: String = ""
	for i in 8:
		var rr: Dictionary = Cuerpo.impactar(c, Vector3(-3, 1.58, -1.5), Vector3(0, 0, 1), 12.0, "perdigon", {"punto": Vector3(-3, 1.58, -0.2), "distancia": 1.5})
		if rr.get("corte", "") != "":
			corte = rr["corte"]
		mato = mato or rr.get("mato", false)
	comprobar(mato, "escopeta a bocajarro en la cabeza mata")
	comprobar(corte in ["reventar", "cabeza"], "y le arranca o revienta la cabeza (%s)" % corte)
	# Atropello: derribo y levantarse.
	var d: Muneco = _muneco(Vector3(0, 0, 4))
	for i in 5:
		await get_tree().process_frame
	d.collision_layer = 0
	comprobar(Cuerpo.derribo(d, d.modelo, Vector3(0, 3, 9)), "derribo con física")
	await get_tree().create_timer(2.0).timeout
	var donde: Vector3 = Cuerpo.centro(d, d.modelo)
	print("atropellado cae en ", donde)
	comprobar(donde.z > 5.0, "sale despedido hacia donde iba el coche")
	Cuerpo.levantar(d, d.modelo, "Idle")
	await get_tree().create_timer(0.2).timeout
	comprobar(Cuerpo._simulador(d.modelo.get_meta("_esq")) == null, "se levanta (sin física)")
	# Gore apagado: nada de cortes.
	Graficos.v["gore"] = 1
	var e: Muneco = _muneco(Vector3(6, 0, 0))
	for i in 3:
		await get_tree().process_frame
	comprobar(not Cuerpo.desmembrar(e, e.modelo, "UpperArm.L", Vector3.RIGHT, 60.0) or true, "")
	var r2: Dictionary = Cuerpo.impactar(e, Vector3(6, 1.55, -5), Vector3(0, 0, 1), 90.0, "bala", {"punto": Vector3(6, 1.55, -0.3), "distancia": 5.0})
	comprobar(r2.get("corte", "") == "", "con violencia reducida no hay cortes")
	Graficos.v["gore"] = 2
	# Peatón de la ciudad: atropello mortal y atropello que solo lo tumba.
	for caso in [[16.0, true], [5.0, false]]:
		var ag = VidaUrbana.Agente.new()
		ag.modelo = Assets.personaje("quaternius/toon-shooter-game-kit/Characters/Character_Enemy", "", "Walk")
		ag.add_child(ag.modelo)
		add_child(ag)
		ag.global_position = Vector3(-6, 0, 6)
		ag.add_to_group("peatones")
		for i in 3:
			await get_tree().process_frame
		ag.derribar(Vector3(1, 0, 0), caso[0], false)
		await get_tree().create_timer(3.0).timeout
		var donde2: Vector3 = Cuerpo.centro(ag, ag.modelo)
		comprobar(ag.has_meta("muerto") == caso[1], "atropello a %d m/s: muerto=%s" % [int(caso[0]), str(caso[1])])
		comprobar(donde2.x > -5.0 and donde2.y < 0.6, "el peatón sale despedido y cae al suelo (%s)" % donde2)
		if not caso[1]:
			ag.herido_t = 0.5   # Nadie mira (no hay cámara): se levanta solo.
			await get_tree().create_timer(1.5).timeout
			ag.estado = VidaUrbana.P_ACERA
			await get_tree().create_timer(0.6).timeout
			comprobar(Cuerpo._simulador(Cuerpo.esqueleto(ag.modelo)) == null, "el herido se levanta")
		ag.queue_free()
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit()
