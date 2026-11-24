# Prueba de la física y destrucción del escenario (scripts/fisica/).
# godot --headless --path . res://tests/prueba_fisica.tscn
# Comprueba: disparos que mueven y rompen, explosión que lanza y rompe, bidón que explota
# en cadena, coche que tumba una farola, bolardo que para el coche, empujar con el jugador,
# muebles sueltos de los interiores y que el mundo grande genere mobiliario con física.
extends Node3D

var fallos: int = 0


func _comprobar(ok: bool, texto: String) -> void:
	if ok:
		print("  bien: ", texto)
	else:
		fallos += 1
		print("FALLO: ", texto)


func _esperar(seg: float) -> void:
	var t: float = 0.0
	while t < seg:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second


func _ready() -> void:
	FisicaEscenario.calidad = 2
	await get_tree().process_frame
	var suelo: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var caja: BoxShape3D = BoxShape3D.new()
	caja.size = Vector3(200, 1, 200)
	cs.shape = caja
	suelo.add_child(cs)
	suelo.position = Vector3(0, -0.5, 0)
	add_child(suelo)
	add_child(GestorFisica.new())

	# 1) Todos los tipos del catálogo se crean, nacen congelados y con su forma.
	var x: float = -40.0
	for t in ObjetoFisico.TIPOS:
		var o: ObjetoFisico = ObjetoFisico.crear(t)
		o.position = Vector3(x, 0, -30)
		add_child(o)
		x += 4.0
		if not o.freeze:
			_comprobar(false, "%s nace congelado" % t)
	_comprobar(true, "%d tipos creados" % ObjetoFisico.TIPOS.size())

	# 2) Un disparo despierta y mueve una caja.
	var c: ObjetoFisico = _poner("caja", Vector3(0, 0, 0))
	await _esperar(0.1)
	c.impacto(c.global_position + Vector3(0, 0.3, 0.3), Vector3(0, 0, -1), 10.0, 20.0)
	await _esperar(0.6)
	_comprobar(not c.freeze and c.global_position.z < -0.1, "un disparo empuja la caja (z=%.2f)" % c.global_position.z)

	# 3) Disparar a una farola no la mueve, pero si le das arriba se rompe el farol.
	var f: ObjetoFisico = _poner("farola", Vector3(10, 0, 0), true)
	await _esperar(0.1)
	f.impacto(f.global_position + Vector3(0.7, 4.35, 0), Vector3(0, 0, -1), 25.0, 20.0)
	await _esperar(0.3)
	_comprobar(f.freeze, "la farola sigue en pie tras un disparo")
	_comprobar(f._lampara == null and f._luz == null, "el farol se rompe y la luz se apaga")

	# 4) Un coche a 15 m/s tumba la farola; el coche pierde algo de velocidad.
	var frac: float = f.golpe_vehiculo(Vector3(15, 0, 0), 1300.0)
	await _esperar(2.0)
	_comprobar(frac > 0.0 and frac < 1.0, "el coche pierde parte de su velocidad (%.2f)" % frac)
	_comprobar(not f.freeze and f.global_transform.basis.y.dot(Vector3.UP) < 0.6, "la farola vuelca (inclinación %.2f)" % f.global_transform.basis.y.dot(Vector3.UP))

	# 5) Un bolardo para en seco a un coche lento.
	var b: ObjetoFisico = _poner("bolardo", Vector3(20, 0, 0))
	await _esperar(0.1)
	_comprobar(b.golpe_vehiculo(Vector3(6, 0, 0), 1300.0) >= 1.0, "el bolardo para el coche a 6 m/s")
	_comprobar(b.freeze, "el bolardo no se mueve")

	# 6) Una explosión lanza y rompe lo que hay cerca.
	var banco: ObjetoFisico = _poner("banco", Vector3(30, 0, 0))
	var papelera: ObjetoFisico = _poner("papelera", Vector3(33, 0, 0))
	var lejos: ObjetoFisico = _poner("papelera", Vector3(60, 0, 0))
	await _esperar(0.1)
	var p0: Vector3 = papelera.global_position
	var escombros_antes: int = FisicaEscenario._escombros.size()
	Combate.explosion(self, Vector3(31.5, 0.5, 0), 6.0, 150.0)
	await _esperar(0.5)
	_comprobar(not is_instance_valid(banco) or banco.roto, "el banco revienta con la explosión")
	_comprobar(not is_instance_valid(papelera) or papelera.roto or papelera.global_position.distance_to(p0) > 1.0, "la papelera sale volando")
	_comprobar(lejos.freeze, "la papelera lejana no se entera")
	_comprobar(FisicaEscenario._escombros.size() > escombros_antes, "hay escombros (%d)" % FisicaEscenario._escombros.size())

	# 7) Un bidón rojo explota y hace explotar al de al lado.
	var b1: ObjetoFisico = _poner("bidon_rojo", Vector3(50, 0, 10))
	var b2: ObjetoFisico = _poner("bidon_rojo", Vector3(52, 0, 10))
	await _esperar(0.1)
	var crateres: int = Destruccion._crateres.size()
	b1.impacto(b1.global_position + Vector3(0, 0.5, 0.3), Vector3(0, 0, -1), 50.0, 10.0)
	await _esperar(0.5)
	_comprobar(not is_instance_valid(b1), "el primer bidón ha reventado")
	_comprobar(not is_instance_valid(b2), "el segundo bidón explota en cadena")
	_comprobar(Destruccion._crateres.size() >= crateres + 1, "la explosión deja cráter")

	# 8) La boca de riego rota suelta agua.
	var br: ObjetoFisico = _poner("boca_riego", Vector3(-20, 0, 10))
	await _esperar(0.1)
	br.romper(Vector3.ZERO)
	await _esperar(0.1)
	var chorros: int = 0
	for n in get_children():
		if n is CPUParticles3D and not (n as CPUParticles3D).one_shot:
			chorros += 1
	_comprobar(chorros >= 1, "la boca de riego echa agua")

	# 9) El jugador (un CharacterBody3D en el grupo "jugador") empuja una caja al andar.
	var j: CharacterBody3D = CharacterBody3D.new()
	var cap: CollisionShape3D = CollisionShape3D.new()
	var capsula: CapsuleShape3D = CapsuleShape3D.new()
	capsula.radius = 0.35
	capsula.height = 1.8
	cap.shape = capsula
	cap.position.y = 0.9
	j.add_child(cap)
	j.add_to_group("jugador")
	j.position = Vector3(-10, 0, 5)
	add_child(j)
	var c2: ObjetoFisico = _poner("caja", Vector3(-10, 0, 4.0))
	await _esperar(0.1)
	for i in 60:
		j.velocity = Vector3(0, -1, -3.5)
		j.move_and_slide()
		await get_tree().physics_frame
	_comprobar(not c2.freeze and c2.global_position.z < 3.5, "el jugador empuja la caja (z=%.2f)" % c2.global_position.z)
	_comprobar(j.collision_mask & ObjetoFisico.CAPA != 0, "el jugador choca con los objetos")

	# 9b) Un Vehiculo de verdad en marcha arrolla una papelera (GestorFisica mira por delante).
	var coche: Vehiculo = Vehiculo.new()
	coche.tipo = "sedan"
	add_child(coche)
	coche.global_position = Vector3(-30, 0.3, 20)
	var pap: ObjetoFisico = _poner("papelera", Vector3(-30, 0, 17.0))
	await _esperar(0.1)
	coche.set("_v", 12.0)
	for i in 30:
		coche.chasis.velocity = -coche.chasis.global_basis.z * 12.0
		await get_tree().physics_frame
	_comprobar(not is_instance_valid(pap) or not pap.freeze, "un coche en marcha arrolla la papelera")

	# 10) Interiores: las sillas y cajas sueltas se separan; la cama y lo de encima de la mesa, no.
	var gi: GestorInteriores = GestorInteriores.new()
	var datos: Dictionary = {"cajas": [
			[Vector3(0, 0.35, 0), Vector3(0.4, 0.5, 0.4), Color(0.5, 0.4, 0.3), true],      # silla (suelo en 0.1)
			[Vector3(2, 0.4, 0), Vector3(0.6, 0.6, 0.6), Color(0.6, 0.5, 0.3), true],       # caja
			[Vector3(4, 0.3, 0), Vector3(1.5, 0.4, 2.0), Color(0.5, 0.3, 0.2), true],       # cama (grande)
			[Vector3(6, 0.8, 0), Vector3(1.2, 0.06, 0.7), Color(0.5, 0.3, 0.2), true],      # tablero de mesa
			[Vector3(6, 0.98, 0), Vector3(0.3, 0.3, 0.3), Color(0.2, 0.2, 0.2), true],      # algo encima
			[Vector3(8, 0.3, 0), Vector3(0.35, 0.4, 0.35), Color(0.68, 0.36, 0.22), true],  # maceta
			[Vector3(8, 0.8, 0), Vector3(0.5, 0.6, 0.5), Color(0.2, 0.5, 0.2), false],      # planta encima
		], "muebles": [], "camas": []}
	var sueltos: Dictionary = gi._sueltos(datos)
	_comprobar(sueltos.has(0) and sueltos.has(1) and sueltos.has(5), "silla, caja y maceta van con física")
	_comprobar(not sueltos.has(2) and not sueltos.has(4), "la cama y lo de encima de la mesa se quedan fijos")
	_comprobar(sueltos.has(5) and (sueltos[5] as Array).has(6), "la planta va con su maceta")
	var mueble: ObjetoFisico = gi._mueble_fisico(datos["cajas"], sueltos[5])
	add_child(mueble)
	_comprobar(mueble.material_fisico == "ceramica", "la maceta es de cerámica")
	gi.free()

	# 11) El mundo grande pone mobiliario con física en una ciudad.
	GeneradorMundo.iniciar(1847, Rect2(-110.0, -120.0, 440.0, 240.0))
	var ciudad: Dictionary = {}
	for s in GeneradorMundo.todos_asentamientos():
		if int(s["tipo"]) == 2:
			ciudad = s
			break
	var total: int = 0
	var tipos_vistos: Dictionary = {}
	if not ciudad.is_empty():
		var pc: Vector2 = ciudad["pos"]
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var tr: Vector2i = Vector2i(floori(pc.x / GeneradorMundo.TROZO) + dx, floori(pc.y / GeneradorMundo.TROZO) + dz)
				var d: Dictionary = GeneradorMundo.generar_cercano(tr)
				for pr in d.get("props", []):
					if pr["tipo"] == "fisico":
						total += 1
						tipos_vistos[pr["obj"]] = true
						if not ObjetoFisico.TIPOS.has(pr["obj"]):
							_comprobar(false, "tipo desconocido en el mundo: %s" % pr["obj"])
	print("  mobiliario en 9 trozos de ciudad: ", total, " objetos de ", tipos_vistos.keys())
	_comprobar(total > 40, "la ciudad tiene mobiliario con física")
	_comprobar(tipos_vistos.has("farola") and tipos_vistos.has("papelera"), "hay farolas y papeleras")

	print("TODO BIEN" if fallos == 0 else "HAY FALLOS: %d" % fallos)
	get_tree().quit()


func _poner(t: String, pos: Vector3, luz: bool = false) -> ObjetoFisico:
	var o: ObjetoFisico = ObjetoFisico.crear(t, luz)
	o.position = pos
	add_child(o)
	return o
