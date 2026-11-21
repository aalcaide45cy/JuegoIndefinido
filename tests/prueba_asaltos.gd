# Prueba automática de los asaltos a casas (reglas, entradas, botín, despertar, reacciones y consecuencias).
#   godot --headless --path . res://tests/prueba_asaltos.tscn
# No carga el mundo grande: usa una casa de prueba (CasaAsaltable.casa_de_prueba) y un jugador falso.
extends Node

var fallos: int = 0
var J: Node = null


class FalsoJugador extends CharacterBody3D:
	var agachado: bool = false
	var en_sombra: bool = false
	func _ready() -> void:
		add_to_group("jugador")
		var f: CollisionShape3D = CollisionShape3D.new()
		var c: CapsuleShape3D = CapsuleShape3D.new()
		c.radius = 0.35
		c.height = 1.7
		f.shape = c
		f.position.y = 0.85
		add_child(f)


func comprobar(condicion: bool, texto: String) -> void:
	if not condicion:
		fallos += 1
		print("FALLO: ", texto)


func esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


func _ready() -> void:
	await get_tree().process_frame
	# Vigilante: si algo se cuelga (por ejemplo un error de script dentro de un await), la prueba falla en vez de quedarse parada.
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("FALLO: la prueba se ha quedado colgada")
		get_tree().quit(2))
	await _probar()


func _casa(mundo: Node3D, x: float, espec: Dictionary) -> CasaAsaltable:
	var suelo: StaticBody3D = StaticBody3D.new()
	var f: CollisionShape3D = CollisionShape3D.new()
	var b: BoxShape3D = BoxShape3D.new()
	b.size = Vector3(60, 1, 60)
	f.shape = b
	suelo.add_child(f)
	suelo.position = Vector3(x, -0.5, 0)
	mundo.add_child(suelo)
	return CasaAsaltable.casa_de_prueba(mundo, Vector3(x, 0, 0), espec)


func _probar() -> void:
	J = get_tree().root.get_node("Juego")
	Engine.time_scale = 4.0
	Asaltos.activo = true
	Asaltos.dificultad = 1
	Asaltos.puertas_cerradas = true
	J.reiniciar()
	J.hora = 23.0
	J.policia_activa = true
	var mundo: Node3D = Node3D.new()
	add_child(mundo)

	# ---------------------------- Reglas sin escena ----------------------------
	comprobar(Asaltos.perfil_de("rico", false) == "rica", "barrio alto = casa rica")
	comprobar(Asaltos.perfil_de("industrial", false) == "humilde", "zona industrial = casa humilde")
	comprobar(Asaltos.perfil_de("residencial", false) == "normal", "residencial = normal")
	comprobar(Asaltos.perfil_de("residencial", true) == "humilde", "casa de una sala = humilde")
	comprobar(Asaltos.ocupacion_a_las(23.0)["duermen"] and float(Asaltos.ocupacion_a_las(3.0)["presentes"]) == 1.0, "de noche duermen todos")
	comprobar(not Asaltos.ocupacion_a_las(7.5)["duermen"] and float(Asaltos.ocupacion_a_las(7.5)["presentes"]) > 0.5, "por la mañana están despiertos en casa")
	comprobar(float(Asaltos.ocupacion_a_las(13.0)["presentes"]) < 0.5, "a mediodía suele estar vacía")
	comprobar(Asaltos.es_asaltable({"id": "", "distrito": "residencial", "x": 0, "z": 0}), "casa residencial normal es asaltable")
	comprobar(not Asaltos.es_asaltable({"id": "w_c_1", "distrito": "residencial"}), "casa en alquiler no es asaltable")
	comprobar(not Asaltos.es_asaltable({"id": "", "distrito": "industrial"}), "almacén no es asaltable")
	comprobar(not Asaltos.es_asaltable({"id": "", "servicio": "banco", "distrito": "centro"}), "servicio no es asaltable")
	var t_h: float = Asaltos.tiempo_forzar("puerta", "ganzua", "humilde")
	var t_r: float = Asaltos.tiempo_forzar("puerta", "ganzua", "rica")
	comprobar(t_r > t_h, "la casa rica tiene mejor cerradura (%.1f > %.1f)" % [t_r, t_h])
	comprobar(Asaltos.tiempo_forzar("puerta", "palanca", "normal") < Asaltos.tiempo_forzar("puerta", "ganzua", "normal"), "palanca más rápida que ganzúa")
	comprobar(Asaltos.ruido_forzar("puerta", "palanca") > Asaltos.ruido_forzar("puerta", "ganzua") * 3.0, "palanca mucho más ruidosa")
	comprobar(Asaltos.ruido_forzar("ventana", "romper") > Asaltos.ruido_forzar("ventana", "ganzua"), "romper cristal más ruidoso")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var suma_rica: float = 0.0
	var suma_humilde: float = 0.0
	for i in 200:
		suma_rica += float(Asaltos.botin("rica", "cajon", rng)["dinero"])
		suma_humilde += float(Asaltos.botin("humilde", "cajon", rng)["dinero"])
	comprobar(suma_rica > suma_humilde * 2.5, "más botín en casa rica (%d vs %d)" % [suma_rica, suma_humilde])
	var fuerte: Dictionary = Asaltos.botin("rica", "caja_fuerte", rng)
	comprobar(int(fuerte["dinero"]) > 90, "la caja fuerte da dinero (%d)" % int(fuerte["dinero"]))
	var armados_ind: int = 0
	var armados_res: int = 0
	for i in 1000:
		if Asaltos.va_armado("industrial", rng): armados_ind += 1
		if Asaltos.va_armado("centro", rng): armados_res += 1
	comprobar(armados_ind > armados_res * 2, "más armados en la zona industrial (%d vs %d)" % [armados_ind, armados_res])
	var a_cerca: float = Asaltos.alerta_por_ruido(0.8, 2.0, 1.0, false)
	var a_lejos: float = Asaltos.alerta_por_ruido(0.8, 12.0, 1.0, false)
	var a_pared: float = Asaltos.alerta_por_ruido(0.8, 2.0, 1.0, true)
	comprobar(a_cerca > a_lejos and a_cerca > a_pared, "el ruido cerca despierta más que lejos o tras la pared")
	comprobar(Asaltos.alerta_por_ruido(0.8, 20.0, 1.0, false) == 0.0, "a 20 m no se oye nada")
	comprobar(Asaltos.alerta_por_ruido(0.8, 2.0, 1.4, false) < a_cerca, "sueño profundo cuesta más")
	comprobar(Asaltos.ruido_pasos(3.0, true, false) < Asaltos.ruido_pasos(3.0, false, false), "agachado haces menos ruido")
	comprobar(Asaltos.ruido_pasos(6.0, false, true) > Asaltos.ruido_pasos(3.0, false, false), "correr hace más ruido")
	comprobar(Asaltos.ruido_pasos(0.0, false, false) == 0.0, "quieto no haces ruido")
	var cuenta: Dictionary = {}
	for i in 500:
		var r: String = Asaltos.elegir_reaccion("padre", false, rng)
		cuenta[r] = int(cuenta.get(r, 0)) + 1
	comprobar(not cuenta.has("arma"), "sin arma nadie usa arma")
	comprobar(cuenta.size() >= 4, "reacciones variadas sin arma: %s" % str(cuenta))
	var armas: int = 0
	for i in 200:
		if Asaltos.elegir_reaccion("madre", true, rng) == "arma": armas += 1
	comprobar(armas > 120, "los armados casi siempre sacan el arma (%d/200)" % armas)

	# Ajustes: pacífico apaga despertar y armas.
	Asaltos.dificultad = 0
	comprobar(Asaltos.alerta_por_ruido(1.0, 1.0, 1.0, false) == 0.0, "pacífico: nadie se despierta")
	comprobar(not Asaltos.va_armado("industrial", rng), "pacífico: nadie armado")
	Asaltos.dificultad = 1

	# ------------------------------- Casa de prueba ----------------------------
	var jugador: FalsoJugador = FalsoJugador.new()
	mundo.add_child(jugador)
	jugador.position = Vector3(0, 0.1, 5.0)
	var casa: CasaAsaltable = _casa(mundo, 0.0, {"id": "prueba_rica", "perfil": "rica", "distrito": "rico", "semilla": 3})
	await get_tree().physics_frame
	await get_tree().physics_frame
	comprobar(casa.puerta != null and casa.ventanas.size() >= 1, "la casa tiene puerta y ventana forzables")
	comprobar(casa.vecinos.size() >= 2, "casa rica con 2 o más ocupantes (%d)" % casa.vecinos.size())
	comprobar(casa.botines.size() == 4, "casa rica con 4 muebles de botín (%d)" % casa.botines.size())
	for v in casa.vecinos:
		comprobar((v as Vecino).esta_durmiendo(), "todos duermen al principio")
	comprobar(casa.puerta.texto_accion().find("Mayús") >= 0, "el texto de la puerta explica las opciones")

	# La puerta bloquea el paso hasta que se fuerza.
	jugador.global_position = Vector3(0, 0.1, 6.0)
	jugador.velocity = Vector3(0, 0, -4.0)
	for i in 80:
		await get_tree().physics_frame
		jugador.velocity = Vector3(0, jugador.velocity.y, -4.0)
		jugador.move_and_slide()
	comprobar(jugador.global_position.z > 3.0, "la puerta cerrada bloquea el paso (z=%.2f)" % jugador.global_position.z)

	# Sin ganzúa, E no hace nada.
	jugador.global_position = Vector3(0, 0.1, 5.2)
	J.vida = 100.0
	casa.puerta.usar(jugador)
	comprobar(not casa.puerta.activa, "sin ganzúa no se fuerza en silencio")

	# Forzar con ganzúa (silencioso): no despierta a casi nadie y abre.
	J.anadir("ganzua", 3)
	casa.puerta.forzar_con(jugador, "ganzua", "rica")
	comprobar(casa.puerta.activa, "empieza a forzar con ganzúa")
	var t: float = 0.0
	while casa.puerta.activa and t < 40.0:
		casa.puerta.avanzar(0.25)
		t += 0.25
	comprobar(casa.puerta.forzada, "la ganzúa abre la puerta (tardó %.1f s)" % t)
	comprobar(t >= 9.0, "tarda en casa rica (>= 9 s)")
	comprobar(casa.puerta._cuerpo_losa.collision_layer == 0, "la hoja de la puerta deja de chocar")
	var despiertos: int = 0
	for v in casa.vecinos:
		if not (v as Vecino).esta_durmiendo(): despiertos += 1
	print("Despiertos tras ganzúa: ", despiertos, "/", casa.vecinos.size())
	comprobar(despiertos < casa.vecinos.size(), "con ganzúa no despierta a todos")
	await esperar(0.7)

	# Entrar y moverse agachado vs. corriendo.
	jugador.global_position = casa.a_mundo(Vector3(0, 0.1, 0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	comprobar(casa.jugador_dentro, "se detecta que estás dentro")
	comprobar(J.interiores == 1, "cuenta como estar en un interior")

	# Botín: registrar un cajón.
	var cajon: BotinCasa = casa.botines[0]
	var dinero0: int = J.dinero_negro if "dinero_negro" in J else J.dinero
	jugador.global_position = cajon.global_position + Vector3(0, -0.9, 0.5)
	comprobar(cajon.texto_accion().begins_with("Registrar"), "texto del cajón")
	cajon.usar(jugador)
	comprobar(cajon.activa, "registrar el cajón empieza")
	t = 0.0
	while cajon.activa and t < 20.0:
		cajon.avanzar(0.25)
		t += 0.25
	comprobar(cajon.vacio, "el cajón queda vacío")
	var dinero1: int = J.dinero_negro if "dinero_negro" in J else J.dinero
	var objetos: int = J.cuenta("joyas") + J.cuenta("reloj_oro") + J.cuenta("plata")
	comprobar(dinero1 > dinero0 or objetos > 0, "se roba algo (dinero %d→%d, objetos %d)" % [dinero0, dinero1, objetos])
	comprobar(int(J.asaltos_info["robado"]) == dinero1 - dinero0, "se anota lo robado")
	comprobar(cajon.texto_accion().find("vacío") >= 0, "cajón vacío tras robar")

	# La caja fuerte pide ganzúa o palanca.
	var fuerte_b: BotinCasa = casa.botines[3]
	comprobar(fuerte_b.contenedor == "caja_fuerte", "el cuarto mueble es la caja fuerte")
	J.quitar("ganzua", J.cuenta("ganzua"))
	fuerte_b.usar(jugador)
	comprobar(not fuerte_b.activa, "la caja fuerte no se abre sin herramienta")
	J.anadir("ganzua", 2)
	fuerte_b.usar(jugador)
	comprobar(fuerte_b.activa, "con ganzúa sí se abre")
	fuerte_b.cancelar()

	# --------------------------------- Despertar -------------------------------
	var v0: Vecino = casa.vecinos[0]
	if not v0.esta_durmiendo():
		v0 = casa.vecinos[1]
	var cama0: Vector3 = v0.global_position
	var n: int = 0
	while v0.esta_durmiendo() and n < 400:
		v0.oir(0.12, cama0 + Vector3(2, 0, 2), false)   # Pasitos cerca.
		n += 1
	comprobar(not v0.esta_durmiendo(), "al final el ruido despierta")
	comprobar(n > 3, "pero no con un solo ruidito (hicieron falta %d)" % n)
	# Los durmientes lejos no se despiertan con un ruido muy lejano.
	var v1: Vecino = null
	for v in casa.vecinos:
		if (v as Vecino).esta_durmiendo():
			v1 = v
			break
	if v1 != null:
		v1.oir(1.0, v1.global_position + Vector3(30, 0, 0), true)
		comprobar(v1.esta_durmiendo(), "un ruido a 30 m no despierta")
		# La luz de la linterna.
		var l: int = 0
		while v1.esta_durmiendo() and l < 400:
			v1.iluminar(0.2)
			l += 1
		comprobar(not v1.esta_durmiendo() and l > 8, "la linterna en la cara despierta poco a poco (%d pulsos)" % l)

	# Reacciones forzadas, una a una.
	await esperar(1.5)
	# Puños: te pega.
	var v_p: Vecino = _nuevo_vecino(casa, "punos", false, jugador)
	J.vida = 100.0
	jugador.global_position = v_p.global_position + Vector3(1.0, 0, 0)
	await esperar(2.5)
	comprobar(J.vida < 100.0, "el que se enfrenta con puños te hace daño (vida %.0f)" % J.vida)
	v_p.queue_free()
	# Arma: dispara y sube las estrellas.
	J.estrellas = 0
	var v_a: Vecino = _nuevo_vecino(casa, "arma", true, jugador)
	J.vida = 100.0
	jugador.global_position = v_a.global_position + Vector3(0, 0, 5.0)
	await esperar(5.0)
	comprobar(J.estrellas >= 2, "los tiros suben las estrellas (%d)" % J.estrellas)
	v_a.queue_free()

	# Daño: herir sube estrellas; golpe flojo = inconsciente; golpe fuerte = muerte.
	J.estrellas = 0
	var v_d: Vecino = _nuevo_vecino(casa, "huir", false, jugador)
	v_d.estado = Vecino.Estado.DORMIDO
	v_d.recibir_dano(8.0)
	comprobar(J.estrellas >= Asaltos.ESTRELLAS_HERIDO, "herir sube a %d estrellas (hay %d)" % [Asaltos.ESTRELLAS_HERIDO, J.estrellas])
	comprobar(not v_d.esta_durmiendo(), "un golpe despierta de golpe")
	v_d.recibir_dano(999.0 * 0.0 + v_d.vida + 1.0)   # Le dejo a cero con un golpe de ~puños (flojo).
	comprobar(v_d.estado == Vecino.Estado.INCONSCIENTE or v_d.estado == Vecino.Estado.MUERTO, "a cero con golpe flojo queda fuera de combate")
	J.estrellas = 0
	var v_m: Vecino = _nuevo_vecino(casa, "punos", false, jugador)
	v_m.vida = 5.0
	v_m.recibir_dano(5.0)
	comprobar(v_m.estado == Vecino.Estado.INCONSCIENTE, "puñetazo que le deja a cero = inconsciente")
	var v_k: Vecino = _nuevo_vecino(casa, "punos", false, jugador)
	v_k.vida = 5.0
	v_k.recibir_dano(25.0)
	comprobar(v_k.estado == Vecino.Estado.MUERTO, "golpe fuerte que le deja a cero = muerte")
	comprobar(J.estrellas >= Asaltos.ESTRELLAS_MUERTE, "matar sube a %d estrellas (hay %d)" % [Asaltos.ESTRELLAS_MUERTE, J.estrellas])

	# Denuncia: el que llama a la policía si no estás cerca.
	J.estrellas = 0
	J.rep_ley = 0
	casa.denunciada = false
	var v_l: Vecino = _nuevo_vecino(casa, "llamar", false, jugador)
	jugador.global_position = v_l.global_position + Vector3(0, 0, 2.0)
	await esperar(3.0)
	comprobar(not casa.denunciada, "no le dejas llamar si estás a su lado")
	jugador.global_position = casa.a_mundo(Vector3(0, 0.1, 14.0))
	await esperar(Asaltos.SEGUNDOS_HASTA_DENUNCIA / 4.0 + 6.0)
	comprobar(casa.denunciada, "al alejarte, llama a la policía")
	comprobar(J.estrellas >= Asaltos.ESTRELLAS_DENUNCIA, "la denuncia sube estrellas (%d)" % J.estrellas)
	comprobar(int(J.asaltos_info["buscado_hasta"]) > J.dia, "queda anotado que te buscan")
	comprobar(J.rep_ley < 0, "baja la reputación con la ley")
	v_l.queue_free()

	# Alarma en casas ricas.
	var alarmas: int = 0
	for s in 30:
		var c2: CasaAsaltable = CasaAsaltable.new().configurar({"id": "x%d" % s, "perfil": "rica", "distrito": "rico", "semilla": s})
		c2.name = "c%d" % s
		mundo.add_child(c2)
		if c2.tiene_alarma: alarmas += 1
		c2.queue_free()
	comprobar(alarmas > 4 and alarmas < 25, "algunas casas ricas tienen alarma (%d/30)" % alarmas)

	# Pacífico: puertas aún se fuerzan, pero nadie se despierta.
	var a_dorm: Vecino = _nuevo_vecino(casa, "punos", false, jugador)
	a_dorm.estado = Vecino.Estado.DORMIDO
	Asaltos.dificultad = 0
	a_dorm.oir(1.0, a_dorm.global_position, false)
	comprobar(a_dorm.esta_durmiendo(), "dificultad pacífica: el ruido no despierta")
	Asaltos.dificultad = 1
	a_dorm.queue_free()

	# Ventana: romper cristal duele y mete dentro.
	var casa2: CasaAsaltable = _casa(mundo, 100.0, {"id": "prueba_normal", "perfil": "normal", "distrito": "residencial", "semilla": 9})
	await get_tree().physics_frame
	jugador.global_position = casa2.ventanas[0].global_position + Vector3(0, -1.4, 0.7)
	J.vida = 100.0
	casa2.ventanas[0].forzar_con(jugador, "romper", "normal")
	t = 0.0
	while casa2.ventanas[0].activa and t < 20.0:
		casa2.ventanas[0].avanzar(0.25)
		t += 0.25
	comprobar(casa2.ventanas[0].forzada, "romper el cristal abre la ventana")
	comprobar(J.vida < 100.0, "romper el cristal duele")
	comprobar(casa2.esta_dentro(jugador.global_position), "tras la ventana estás dentro de la casa")

	# Interrumpir: alejarse cancela.
	var casa3: CasaAsaltable = _casa(mundo, 200.0, {"id": "prueba_h", "perfil": "humilde", "distrito": "industrial", "semilla": 2})
	await get_tree().physics_frame
	jugador.global_position = Vector3(200.0, 0.1, 5.2)
	casa3.puerta.forzar_con(jugador, "palanca", "humilde")
	casa3.puerta.avanzar(0.5)
	jugador.global_position = Vector3(200.0, 0.1, 30.0)
	casa3.puerta.avanzar(0.5)
	comprobar(not casa3.puerta.activa and not casa3.puerta.forzada, "alejarse interrumpe el forzado")

	# Palanca: ruido fuerte, despierta a la gente.
	var dorm: int = 0
	for v in casa3.vecinos:
		if (v as Vecino).esta_durmiendo(): dorm += 1
	jugador.global_position = Vector3(200.0, 0.1, 5.2)
	casa3.puerta.forzar_con(jugador, "palanca", "humilde")
	t = 0.0
	while casa3.puerta.activa and t < 20.0:
		casa3.puerta.avanzar(0.25)
		t += 0.25
	var dorm2: int = 0
	for v in casa3.vecinos:
		if (v as Vecino).esta_durmiendo(): dorm2 += 1
	print("Palanca: dormidos antes %d, después %d" % [dorm, dorm2])
	comprobar(casa3.puerta.forzada, "la palanca abre la puerta")

	# A patadas: ruido máximo, la gente se despierta.
	jugador.global_position = Vector3(100.0, 0.1, 5.2)
	var dorm_a: int = 0
	for v in casa2.vecinos:
		if (v as Vecino).esta_durmiendo(): dorm_a += 1
	casa2.puerta.forzar_con(jugador, "patada", "normal")
	t = 0.0
	while casa2.puerta.activa and t < 20.0:
		casa2.puerta.avanzar(0.25)
		t += 0.25
	var dorm_b: int = 0
	for v in casa2.vecinos:
		if (v as Vecino).esta_durmiendo(): dorm_b += 1
	print("Patada: dormidos antes %d, después %d" % [dorm_a, dorm_b])
	comprobar(dorm_b < dorm_a, "a patadas se despierta alguien")

	# Ser dueño: puertas abiertas y nadie dentro.
	J.viviendas["prueba_h"] = true
	J.cambio.emit()
	comprobar(casa3.propia and casa3.vecinos.is_empty(), "si la casa es tuya deja de ser un blanco")

	# Ajuste apagado: la casa queda como antes.
	Asaltos.activo = false
	var casa4: CasaAsaltable = _casa(mundo, 300.0, {"id": "off", "perfil": "normal", "semilla": 1})
	await get_tree().physics_frame
	comprobar(casa4.puerta == null and casa4.vecinos.is_empty() and casa4.botines.is_empty(), "con los asaltos apagados no hay puerta cerrada ni gente")
	Asaltos.activo = true

	# Despierto en casa (anochecer/mañana): te ve en cuanto entras en su campo de visión.
	J.estrellas = 0
	var v_t: Vecino = _nuevo_vecino(casa, "punos", false, jugador)
	v_t.estado = Vecino.Estado.ATENTO
	v_t.atento = true
	v_t.reaccion = ""
	v_t.testigo = false
	jugador.global_position = v_t.global_position + Vector3(-3.0, 0, -1.0)   # Dentro de la casa, a la vista.
	await esperar(1.5)
	comprobar(v_t.estado != Vecino.Estado.ATENTO, "el que está despierto te ve y reacciona")
	comprobar(J.estrellas >= Asaltos.ESTRELLAS_ALLANAMIENTO, "que te vean dentro sube estrellas (%d)" % J.estrellas)
	v_t.queue_free()
	# Y por la mañana temprano hay ocupantes despiertos.
	J.hora = 7.5
	var atentos: int = 0
	for s2 in 20:
		var c5: CasaAsaltable = CasaAsaltable.new().configurar({"id": "m%d" % s2, "perfil": "normal", "distrito": "residencial", "semilla": s2 * 3})
		mundo.add_child(c5)
		for v in c5.vecinos:
			if (v as Vecino).estado == Vecino.Estado.ATENTO: atentos += 1
		c5.queue_free()
	comprobar(atentos > 5, "por la mañana hay gente despierta en casa (%d)" % atentos)
	J.hora = 13.0
	var casas_vacias: int = 0
	for s3 in 20:
		var c6: CasaAsaltable = CasaAsaltable.new().configurar({"id": "d%d" % s3, "perfil": "normal", "distrito": "residencial", "semilla": s3 * 5})
		mundo.add_child(c6)
		if c6.vecinos.is_empty(): casas_vacias += 1
		c6.queue_free()
	comprobar(casas_vacias > 3, "a mediodía hay casas vacías (%d/20)" % casas_vacias)
	J.hora = 23.0

	# Casas reales del mundo (con el reparto de InteriorCasa): camas, muebles y entradas.
	GeneradorMundo.iniciar(1847, Rect2(-110.0, -120.0, 440.0, 240.0))
	var probadas: int = 0
	var con_camas: int = 0
	var con_botin: int = 0
	var ricas_con_fuerte: int = 0
	for s4 in GeneradorMundo.todos_asentamientos():
		var p4: Vector2 = s4["pos"]
		var m4: float = float(s4["mitad"]) + 20.0
		for c4 in GeneradorMundo._casas_en(s4, Rect2(p4.x - m4, p4.y - m4, m4 * 2.0, m4 * 2.0)):
			if not Asaltos.es_asaltable(c4):
				continue
			var d4: Dictionary = InteriorCasa.generar(c4)
			if d4["tipo"] != "vivienda":
				continue
			probadas += 1
			if (d4["camas"] as Array).size() > 0: con_camas += 1
			var c7: CasaAsaltable = CasaAsaltable.desde_interior(c4, d4, null)
			mundo.add_child(c7)
			if c7.botines.size() > 0: con_botin += 1
			if c7.perfil == "rica":
				for b in c7.botines:
					if (b as BotinCasa).contenedor == "caja_fuerte": ricas_con_fuerte += 1; break
			comprobar(c7.vecinos.size() >= 1, "casa real con al menos 1 ocupante (%s)" % c7.id)
			comprobar(c7.vecinos.size() <= (d4["camas"] as Array).size(), "no más ocupantes que camas (%s)" % c7.id)
			for v in c7.vecinos:
				comprobar(c7.esta_dentro((v as Vecino).global_position) , "el ocupante duerme dentro de la casa real (%s)" % c7.id)
			c7.queue_free()
			if probadas >= 60:
				break
		if probadas >= 60:
			break
	print("Casas reales probadas: %d, con camas: %d, con botín: %d, ricas con caja fuerte: %d" % [probadas, con_camas, con_botin, ricas_con_fuerte])
	comprobar(probadas >= 20 and con_camas == probadas and con_botin == probadas, "todas las casas normales tienen camas y botín")

	# Persistencia de la información.
	var copia: Dictionary = JSON.parse_string(JSON.stringify(J.asaltos_info))
	comprobar(copia is Dictionary and int(copia["asaltos"]) >= 1, "la info de asaltos sobrevive a JSON (%s)" % str(copia))

	Engine.time_scale = 1.0
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


# Crea un vecino ya despierto con una reacción fija, cerca del jugador.
func _nuevo_vecino(casa: CasaAsaltable, reaccion: String, armado: bool, jugador: Node3D) -> Vecino:
	var v: Vecino = Vecino.new()
	v.casa = casa
	v.rol = Asaltos.ROLES[0]
	v.armado = armado
	v.cama = casa.a_mundo(Vector3(-3, 0.6, -3))
	v.salida = casa.a_mundo(Vector3(0, 0.1, casa.cara * (casa.fondo / 2.0 + 1.5)))
	casa.add_child(v)
	v.position = Vector3(1.5, 0.1, 0.5)
	v.estado = Vecino.Estado.REACCIONANDO
	v.reaccion = reaccion
	v.testigo = true
	v._zzz.visible = false
	v._cuerpo.rotation.x = 0.0
	v._cuerpo.position = Vector3.ZERO
	return v
