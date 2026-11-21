# Prueba de la salud (hospital, convalecencia) y los oficios (fichar, turno, avisos,
# ascensos, guardado). Sin ventana:
#   godot --headless --path . res://tests/prueba_oficios.tscn
# Usa la carpeta de datos del proyecto: ejecútala en un clon con custom_user_dir propio.
extends Node

var fallos: int = 0


func comprobar(condicion: bool, texto: String) -> void:
	if not condicion:
		fallos += 1
		print("FALLO: ", texto)


func _ready() -> void:
	await get_tree().process_frame
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	var J = raiz.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	var jugador = hud.jugador
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	await get_tree().process_frame

	# --- Hospital: cuesta dinero, cura y deja convaleciente ---
	var hosp: ServicioMundo = ServicioMundo.new()
	hosp.servicio = "hospital"
	escena.add_child(hosp)
	J.dinero = 500
	J.vida = 30.0
	var precio: int = hosp._precio_cura()
	comprobar(precio > 0, "la cura tiene precio")
	hosp.usar(jugador)
	comprobar(is_equal_approx(J.vida, J.VIDA_MAX), "el hospital cura del todo")
	comprobar(J.dinero == 500 - precio, "el hospital cobra %d" % precio)
	comprobar(J.sin_correr > 80.0, "tras el hospital no puedes correr (%.0f s)" % J.sin_correr)
	var t0: float = J.sin_correr
	await get_tree().create_timer(1.0).timeout
	comprobar(J.sin_correr < t0, "la convalecencia baja con el tiempo")
	J.sin_correr = 0.0

	# --- Oficios: fichar y cobrar ---
	comprobar(J.oficio == "", "sin oficio al empezar")
	hosp.usar(jugador)   # Sin Mayús: sin vida que curar, no pasa nada.
	J.estrellas = 2
	var com: ServicioMundo = ServicioMundo.new()
	com.servicio = "comisaria"
	escena.add_child(com)
	com.usar(jugador)
	comprobar(J.oficio == "", "con estrellas no te hacen policía")
	J.estrellas = 0
	J.sospecha = 0.0
	com.usar(jugador)
	comprobar(J.oficio == "policia", "sin búsqueda te hacen policía")
	comprobar(J.es_policia_activo() == false, "fuera de turno y de rango Agente aún te registran")
	com.usar(jugador)
	comprobar(J.en_turno, "entras de servicio")
	comprobar(J.es_policia_activo(), "de servicio no te registran")

	var gestor: GestorOficio = escena.find_children("*", "GestorOficio", true, false)[0]
	await get_tree().process_frame
	# Dos segundos reales de turno dan algo de sueldo acumulado.
	J.velocidad_tiempo = 600.0
	await get_tree().create_timer(1.0).timeout
	J.velocidad_tiempo = 1.0
	comprobar(J.turno_pago > 0.0, "el turno acumula sueldo (%.2f)" % J.turno_pago)

	# Un aviso: se crea, se atiende con varias pulsaciones y paga.
	var dinero_antes: int = J.dinero
	var xp_antes: int = J.xp_oficio()
	var creado: bool = false
	for i in 20:
		creado = gestor.crear_aviso()
		if creado:
			break
		await get_tree().create_timer(1.0).timeout
	if not creado:
		# Sin calles cerca (el jugador empieza en la plaza original): lo coloca a mano.
		var a: AvisoOficio = AvisoOficio.new()
		a.oficio = J.oficio
		a.datos = J.DatosOficios.LISTA["policia"]["avisos"][0]
		a.position = jugador.global_position + Vector3(5, 0, 0)
		escena.add_child(a)
		gestor.aviso = a
	comprobar(gestor.aviso != null and is_instance_valid(gestor.aviso), "hay un aviso activo")
	var av: AvisoOficio = gestor.aviso
	var golpes: int = av.golpes
	for i in golpes:
		av.usar(jugador)
	await get_tree().process_frame
	comprobar(J.dinero > dinero_antes, "resolver el aviso paga")
	comprobar(J.xp_oficio() > xp_antes, "resolver el aviso da experiencia de oficio")

	# Ascenso por experiencia.
	J.ganar_xp_oficio(200)
	comprobar(J.rango_oficio() >= 1, "asciendes de rango (%s)" % J.DatosOficios.nombre_rango("policia", J.xp_oficio()))
	var antes_cobro: int = J.dinero
	com.usar(jugador)   # Terminar turno.
	comprobar(not J.en_turno, "terminas el turno")
	comprobar(J.dinero >= antes_cobro, "al terminar cobras el sueldo")
	comprobar(J.es_policia_activo(), "desde Sargento no te registran ni fuera de turno")

	# Cambiar de oficio conserva el rango del anterior.
	var xp_pol: int = J.xp_oficio("policia")
	var bom: ServicioMundo = ServicioMundo.new()
	bom.servicio = "bomberos"
	escena.add_child(bom)
	bom.usar(jugador)
	comprobar(J.oficio == "bombero", "te haces bombero")
	comprobar(J.xp_oficio("policia") == xp_pol, "conservas la experiencia de policía")
	comprobar(J.xp_oficio() == 0, "como bombero empiezas de cero")
	bom.usar(jugador)
	var dano_normal: float = 1.0
	comprobar(J.mod("dano_recibido") < 0.0, "el bombero de servicio recibe menos daño")

	# Médico: descuento en el hospital.
	J.terminar_turno()
	J.vida = 30.0
	var p_normal: int = hosp._precio_cura()
	J.oficio = "medico"
	var p_medico: int = hosp._precio_cura()
	comprobar(p_medico < p_normal, "el médico paga menos en el hospital (%d < %d)" % [p_medico, p_normal])

	# Guardado y carga conservan oficio y rango.
	J.oficios_xp["medico"] = 130
	comprobar(Guardado.guardar(get_tree(), jugador, 5), "guardar")
	J.reiniciar()
	comprobar(J.oficio == "" and J.oficios_xp.is_empty(), "reiniciar borra el oficio")
	comprobar(Guardado.cargar(get_tree(), jugador, 5), "cargar")
	comprobar(J.oficio == "medico" and J.xp_oficio("medico") == 130 and J.xp_oficio("policia") == xp_pol,
			"la partida guarda oficio y rangos")
	Guardado.borrar(5)

	print("RESULTADO: TODO BIEN" if fallos == 0 else "RESULTADO: %d FALLOS" % fallos)
	get_tree().quit()
