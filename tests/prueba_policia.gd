# Prueba automática de la policía por estrellas, el taxi, los servicios y los distritos.
#   godot --headless --path . res://tests/prueba_policia.tscn
extends Node

const DatosPolicia = preload("res://scripts/datos/policia.gd")
const Taxi = preload("res://scripts/datos/taxi.gd")

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
	for i in 3:
		await get_tree().process_frame
	var J = raiz.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	var jugador = hud.jugador
	if hud._menu != null:
		hud._menu.cerrar()
	await get_tree().process_frame
	J.reiniciar()
	J.dinero = 5000

	# --- Estrellas ---
	J.subir_estrellas(1, "prueba")
	comprobar(J.estrellas == 1, "1 estrella")
	J.exigir_estrellas(3)
	comprobar(J.estrellas == 3, "exigir 3 estrellas (hay %d)" % J.estrellas)
	J.subir_estrellas(9)
	comprobar(J.estrellas == 5, "tope de 5 estrellas")
	J.alerta = 0.0
	J.estrellas = 2
	J._t_estrella = 0.0
	J._avanzar_estrellas(40.0)
	comprobar(J.estrellas == 1, "bajan solas si te pierden (hay %d)" % J.estrellas)
	J.alerta = 100.0
	J._avanzar_estrellas(500.0)
	comprobar(J.estrellas == 1, "no bajan mientras te ven")
	J.alerta = 0.0

	# --- Refuerzos y coches patrulla ---
	J.estrellas = 4
	J.alerta = 100.0
	var gestor: GestorPolicia = escena.find_children("*", "GestorPolicia", true, false)[0]
	for i in 12:
		gestor._t = 2.0
		gestor._process(0.0)
		await get_tree().physics_frame
	var g: int = get_tree().get_nodes_in_group("policia_refuerzo").size()
	print("Refuerzos con 4 estrellas: ", g, " (coches: ", get_tree().get_nodes_in_group("coches_policia").size(), ")")
	comprobar(g > 0, "aparecen refuerzos")
	J.estrellas = 0
	J.alerta = 0.0
	for i in 5:
		await get_tree().physics_frame
	await get_tree().process_frame
	comprobar(get_tree().get_nodes_in_group("policia_refuerzo").size() == 0, "se retiran sin estrellas")

	# --- Detención ---
	J.estrellas = 3
	J.anadir("hierba_bruma", 4)
	var d0: int = J.dinero
	var h0: float = J.hora
	var txt: String = J.detener()
	print(txt)
	comprobar(J.dinero < d0, "la detención cobra multa")
	comprobar(not J.lleva_ilegal(), "la detención confisca lo ilegal")
	comprobar(J.estrellas == 0, "la detención quita las estrellas")
	comprobar(not is_equal_approx(J.hora, h0), "la detención pasa el tiempo")

	# --- Taxi ---
	J.dinero = 5000
	var lista: Array = Taxi.destinos(jugador.global_position)
	print("Destinos de taxi: ", lista.size())
	comprobar(lista.size() >= 10, "hay destinos")
	var lejos: Dictionary = lista[lista.size() - 1]
	comprobar(int(lejos["precio"]) > int(lista[0]["precio"]), "el taxi cobra por distancia")
	comprobar(Taxi.motivo_no(jugador) == "", "se puede pedir taxi")
	J.estrellas = 1
	comprobar(Taxi.motivo_no(jugador) != "", "no hay taxi con la policía detrás")
	J.estrellas = 0
	var dia0: int = J.dia
	var err: String = Taxi.pedir(jugador, lejos)
	comprobar(err == "", "pedir taxi: " + err)
	for i in 150:
		await get_tree().physics_frame
	var distancia: float = Vector2(jugador.global_position.x, jugador.global_position.z).distance_to(
			Vector2(lejos["pos"].x, lejos["pos"].z))
	print("Taxi: destino ", lejos["nombre"], " a ", int(lejos["dist"]), " m; ahora a ", int(distancia), " m; y=", jugador.global_position.y)
	comprobar(distancia < 5.0, "el taxi te deja en el destino")
	comprobar(J.dinero < 5000, "el taxi cobra")

	# --- Distritos y servicios ---
	var ciudades: Array = GeneradorMundo.todos_asentamientos().filter(func(s) -> bool: return int(s["tipo"]) == 2)
	print("Ciudades: ", ciudades.size())
	if not ciudades.is_empty():
		var s: Dictionary = ciudades[0]
		var vistos: Dictionary = {}
		for k in range(-4, 4):
			for l in range(-4, 4):
				vistos[GeneradorMundo.distrito_de(s, k, l)] = true
		comprobar(vistos.size() == 4, "la ciudad tiene 4 distritos (%s)" % str(vistos.keys()))
		var servicios: Array = []
		for k in range(-4, 4):
			for l in range(-4, 4):
				var sv: String = GeneradorMundo.servicio_de(s, k, l)
				if sv != "":
					servicios.append(sv)
		comprobar(servicios.size() == 7 and servicios.has("comisaria") and servicios.has("bomberos"), "la ciudad tiene 7 servicios (%s)" % str(servicios))
		var p: Vector2 = s["pos"]
		var dist: Dictionary = GeneradorMundo.distrito_en(p.x + 1.0, p.y + 1.0)
		comprobar(not dist.is_empty() and dist["id"] == "centro", "distrito en el centro de la ciudad")
		var c: Dictionary = GeneradorMundo.casa(s, 1, 1, 0)
		comprobar(c.get("servicio", "") == "banco", "el banco existe")

	# --- Servicios ---
	var gas: ServicioMundo = ServicioMundo.new()
	gas.servicio = "gasolinera"
	escena.add_child(gas)
	gas.global_position = jugador.global_position
	var banco: ServicioMundo = ServicioMundo.new()
	banco.servicio = "banco"
	escena.add_child(banco)
	J.dinero = 1000
	banco.usar(jugador)
	comprobar(J.banco > 900 and J.dinero == 20, "banco ingresa (banco %d, bolsillo %d)" % [J.banco, J.dinero])
	J._interes_banco()
	comprobar(J.banco > 900, "interés del banco")
	var hosp: ServicioMundo = ServicioMundo.new()
	hosp.servicio = "hospital"
	escena.add_child(hosp)
	J.dinero = 500
	J.vida = 20.0
	hosp.usar(jugador)
	comprobar(J.vida == 100.0 and J.dinero < 500, "hospital cura y cobra")
	for sv in ["taller", "taberna"]:
		var n: ServicioMundo = ServicioMundo.new()
		n.servicio = sv
		escena.add_child(n)
		comprobar(n.texto_accion() != "", "texto de " + sv)
	comprobar(gas.texto_accion() != "", "texto de gasolinera")
	# Con un coche cerca, repostar.
	var coche: Vehiculo = Vehiculo.new()
	coche.tipo = "sedan"
	coche.id = "mio_prueba"
	escena.add_child(coche)
	coche.global_position = jugador.global_position + Vector3(3, 0, 0)
	coche.gasolina = 20.0
	J.dinero = 500
	gas.usar(jugador)
	comprobar(coche.gasolina == 100.0 and J.dinero < 500, "repostar llena el depósito (%f, %d $)" % [coche.gasolina, J.dinero])
	coche.salud = 50.0
	var taller: ServicioMundo = ServicioMundo.new()
	taller.servicio = "taller"
	escena.add_child(taller)
	taller.global_position = jugador.global_position
	taller.usar(jugador)
	comprobar(coche.salud == 100.0, "taller repara")

	# --- Móvil ---
	hud._abrir_menu(Telefono.new())
	await get_tree().process_frame
	var tel = hud._menu
	if tel is Telefono:
		tel._cambiar_pestana(5)
		await get_tree().process_frame
		comprobar(tel._contenido.get_child_count() > 3, "la pestaña Taxi tiene destinos")
		tel.cerrar()

	print("RESULTADO POLICIA: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)
