# Prueba de la peluquería, la barbería y los oficios de peluquero y barbero. Sin ventana:
#   godot --headless --path . res://tests/prueba_peluqueria.tscn
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
	var P = J.DatosPeluqueria
	var A = J.DatosAspecto
	var hud = escena.find_children("*", "Hud", true, false)[0]
	var jugador = hud.jugador
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	await get_tree().process_frame

	# --- Datos: cada opción tiene precio y los locales existen ---
	for l in P.LOCALES:
		for clave in P.opciones(l):
			comprobar(P.PRECIOS.has(clave) and (P.PRECIOS[clave] as Array).size() == A.cantidad(clave),
					"precios de %s en %s completos" % [clave, l])
	for o in J.DatosOficios.LISTA:
		comprobar(J.DatosOficios.oficio_de_lugar(str(J.DatosOficios.LISTA[o]["lugar"])) == o, "lugar único de " + o)
	comprobar(A.valido({"peinado": 99, "barba": -4})["peinado"] == A.cantidad("peinado") - 1, "valida peinado fuera de rango")
	comprobar(A.valido({"peinado": 1})["barba"] == 0, "una partida vieja sin barba carga bien")

	# --- Mundo: hay peluquerías y barberías generadas ---
	var hay_p: bool = false
	var hay_b: bool = false
	for s in GeneradorMundo.SERVICIOS_CIUDAD.values():
		hay_p = hay_p or s == "peluqueria"
		hay_b = hay_b or s == "barberia"
	comprobar(hay_p and hay_b, "la ciudad tiene peluquería y barbería")

	# --- Ventana: cambiar peinado y barba cuesta, cambia el aspecto del jugador ---
	var barb: ServicioMundo = ServicioMundo.new()
	barb.servicio = "barberia"
	escena.add_child(barb)
	var v: VentanaPeluqueria = VentanaPeluqueria.new()
	v.local = "barberia"
	hud.abrir_ventana(v)
	await get_tree().process_frame
	J.dinero = 100
	v._cambiar("barba", 4)    # Barba larga: 14 $
	v._cambiar("peinado", 3)  # Mohicano: 15 $
	comprobar(v.precio_final() == 29, "precio barbería = 29 (%d)" % v.precio_final())
	v._pagar()
	comprobar(J.dinero == 71, "cobra 29 $ (%d)" % J.dinero)
	comprobar(int(J.aspecto["barba"]) == 4 and int(J.aspecto["peinado"]) == 3, "aspecto cambiado")
	# Sin dinero no cambia.
	J.dinero = 1
	v._cambiar("barba", -1)
	v._pagar()
	comprobar(int(J.aspecto["barba"]) == 4, "sin dinero no cambia")
	v.cerrar()
	await get_tree().process_frame

	# --- Peluquería: tinte mágico exige una hoja de bruma ---
	var pel: VentanaPeluqueria = VentanaPeluqueria.new()
	pel.local = "peluqueria"
	hud.abrir_ventana(pel)
	await get_tree().process_frame
	J.dinero = 200
	pel._cambiar("pelo", -2)   # Pasa de 0 a 6 (da la vuelta): verde mágico.
	comprobar(int(pel._nuevo["pelo"]) == 6, "el tinte verde es el 6")
	pel._pagar()
	comprobar(int(J.aspecto["pelo"]) == 0 and J.dinero == 200, "sin hoja de bruma no hay tinte mágico")
	J.anadir("hierba_bruma", 1)
	pel._pagar()
	comprobar(int(J.aspecto["pelo"]) == 6, "con hoja de bruma sí")
	comprobar(not J.tiene("hierba_bruma", 1), "gasta la hoja de bruma")
	comprobar(J.dinero == 200 - 45, "tinte cuesta 45 $ (%d)" % J.dinero)
	pel.cerrar()
	await get_tree().process_frame

	# --- Oficio: ser peluquero, descuento y clientes ---
	J.oficio = ""
	var peluq: ServicioMundo = ServicioMundo.new()
	peluq.servicio = "peluqueria"
	escena.add_child(peluq)
	Input.action_press("correr")
	peluq.usar(jugador)
	Input.action_release("correr")
	comprobar(J.oficio == "peluquero", "Mayús+E te hace peluquero")
	var p2: VentanaPeluqueria = VentanaPeluqueria.new()
	p2.local = "peluqueria"
	hud.abrir_ventana(p2)
	await get_tree().process_frame
	p2._cambiar("peinado", 1)
	var normal: int = P.precio_cambio("peluqueria", J.aspecto, p2._nuevo)
	comprobar(p2.precio_final() == int(round(normal * 0.5)), "el peluquero paga la mitad")
	p2.cerrar()
	J.empezar_turno()
	var gestor: GestorOficio = escena.find_children("*", "GestorOficio", true, false)[0]
	await get_tree().process_frame
	var creado: bool = false
	for i in 20:
		creado = gestor.crear_aviso()
		if creado:
			break
		await get_tree().create_timer(0.3).timeout
	comprobar(creado, "sale un cliente")
	if creado:
		var a: AvisoOficio = gestor.aviso
		comprobar(a.datos.has("aspecto_cliente") and str(a.datos["texto"]).contains("Peinado"), "el cliente pide algo: " + str(a.datos["texto"]))
		var antes: int = J.dinero
		var xp: int = J.xp_oficio()
		for i in int(a.datos["golpes"]):
			a.usar(jugador)
		comprobar(J.dinero > antes and J.xp_oficio() > xp, "atender al cliente paga y da experiencia")
	J.terminar_turno()

	# --- Guardado: el aspecto con barba sobrevive ---
	var g = raiz.get_node_or_null("Guardado")
	if g != null:
		J.aspecto["barba"] = 3
		J.aspecto = A.valido(J.aspecto)
		comprobar(int(J.aspecto["barba"]) == 3, "aspecto válido conserva barba")

	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit()
