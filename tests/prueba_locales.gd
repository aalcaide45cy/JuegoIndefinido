# Prueba de locales nocturnos: horarios, tragaperras (retorno ~88 %), discoteca y servicios en el mapa.
#   godot --headless --path . res://tests/prueba_locales.tscn
extends Node

var fallos: int = 0


func comprobar(condicion: bool, texto: String) -> void:
	if not condicion:
		fallos += 1
		print("FALLO: ", texto)


func _servicio(arbol: SceneTree, nombre: String):
	for n in arbol.get_nodes_in_group("interactuable"):
		if n is ServicioMundo and n.servicio == nombre:
			return n
	return null


func _ready() -> void:
	await get_tree().process_frame
	var Casino = load("res://scripts/datos/casino.gd")
	comprobar(Casino.abierto("discoteca", 23.0) and Casino.abierto("discoteca", 2.0), "discoteca abre de noche")
	comprobar(not Casino.abierto("discoteca", 12.0), "discoteca cerrada de día")
	comprobar(Casino.abierto("tragaperras", 19.0) and not Casino.abierto("tragaperras", 10.0), "horario de tragaperras")
	# Ruleta: pagos exactos.
	comprobar(Casino.pago_ruleta(1, "rojo", 0, 10) == 20, "1 es rojo y paga x2")
	comprobar(Casino.pago_ruleta(0, "rojo", 0, 10) == 0 and Casino.pago_ruleta(0, "par", 0, 10) == 0, "el cero pierde color y par")
	comprobar(Casino.pago_ruleta(17, "pleno", 17, 10) == 360, "pleno paga 35 a 1 (36 en total)")
	comprobar(Casino.pago_ruleta(5, "docena1", 0, 10) == 30 and Casino.pago_ruleta(30, "docena1", 0, 10) == 0, "docenas")
	var rr: RandomNumberGenerator = RandomNumberGenerator.new()
	rr.seed = 7
	var gasto: float = 0.0
	var cobro: float = 0.0
	for i in 200000:
		var g: Dictionary = Casino.ruleta("rojo", 0, 1, rr)
		gasto += 1.0
		cobro += float(g["pago"])
	comprobar(absf(cobro / gasto - 0.973) < 0.03, "ruleta devuelve ~97 %%: %f" % (cobro / gasto))
	# Blackjack.
	comprobar(Casino.total_mano([1, 13]) == 21 and Casino.es_blackjack([1, 13]), "A+K es blackjack")
	comprobar(Casino.total_mano([1, 1, 9]) == 21, "dos ases y un 9 = 21")
	comprobar(Casino.total_mano([10, 9, 5]) == 24, "te pasas con 24")
	comprobar(Casino.pago_blackjack([1, 13], [10, 7], 100) == 250, "blackjack natural paga 3:2")
	comprobar(Casino.pago_blackjack([10, 8], [10, 8], 100) == 100, "empate devuelve")
	comprobar(Casino.pago_blackjack([10, 10, 5], [10, 7], 100) == 0, "pasarse pierde")
	comprobar(Casino.pago_blackjack([10, 8], [10, 6, 9], 100) == 200, "el crupier se pasa: ganas")
	var rb: RandomNumberGenerator = RandomNumberGenerator.new()
	rb.seed = 3
	for i in 500:
		var mano: Array = Casino.jugar_crupier([1 + rb.randi() % 13], rb)
		if Casino.total_mano(mano) < 17:
			comprobar(false, "el crupier siempre llega a 17")
			break
	comprobar(Casino.abierto("casino", 22.0) and not Casino.abierto("casino", 12.0), "horario del casino")
	var suma: float = 0.0
	var n: int = 400000
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	for i in n:
		var t: Dictionary = Casino.tirada(rng.randf(), rng)
		suma += float(t["multiplicador"])
		var r: Array = t["rodillos"]
		var iguales: bool = r[0] == r[1] and r[1] == r[2]
		if float(t["multiplicador"]) == 0.0 and iguales:
			comprobar(false, "una tirada perdedora no puede tener tres iguales")
			break
	var retorno: float = suma / n
	print("Retorno medio: ", retorno)
	comprobar(absf(retorno - 0.88) < 0.04, "retorno cerca del 88 %%: %f" % retorno)

	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	var J = raiz.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	# Locales en el mapa: la ciudad original no los lleva; se crean a mano con el mismo script.
	var disco: ServicioMundo = ServicioMundo.new()
	disco.servicio = "discoteca"
	escena.add_child(disco)
	var slot: ServicioMundo = ServicioMundo.new()
	slot.servicio = "tragaperras"
	escena.add_child(slot)
	await get_tree().process_frame
	J.hora = 12.0
	J.dinero = 200
	disco.usar(hud.jugador)
	comprobar(J.dinero == 200, "cerrada de día no cobra")
	J.hora = 23.0
	disco.usar(hud.jugador)
	comprobar(J.dinero <= 180, "la entrada cuesta")
	J.dinero = 1000
	var cambio: bool = false
	for i in 100:
		var previo: int = J.dinero
		slot.usar(hud.jugador)
		if J.dinero != previo:
			cambio = true
	comprobar(cambio, "la tragaperras mueve dinero")
	J.dinero = 2
	slot.usar(hud.jugador)
	comprobar(J.dinero == 2, "sin dinero no apuesta")
	# Timba: retorno 92 %, trampas solo con Ojo alto.
	var rt: RandomNumberGenerator = RandomNumberGenerator.new()
	rt.seed = 11
	var ganado: float = 0.0
	for i in 100000:
		var r: String = Casino.timba(rt, 5)
		comprobar(r != "trampa", "sin Ojo no se descubren trampas")
		if r == "gana":
			ganado += 2.0
	comprobar(absf(ganado / 100000.0 - 0.92) < 0.03, "la timba devuelve ~92 %%: %f" % (ganado / 100000.0))
	var vio_trampa: bool = false
	for i in 400:
		if Casino.timba(rt, 10) == "trampa":
			vio_trampa = true
	comprobar(vio_trampa, "con Ojo alto se ven trampas")
	comprobar(Casino.deuda_tras_dia(300) == 390 and Casino.deuda_tras_dia(390) == 507, "interés del 30 %% diario")
	comprobar(Casino.oferta_mercado(3)[0] != null and Casino.abierto("mercado_negro", 2.0) and not Casino.abierto("mercado_negro", 14.0), "mercado negro de madrugada")
	# Prestamista y mercado.
	var pre: ServicioMundo = ServicioMundo.new()
	pre.servicio = "prestamista"
	escena.add_child(pre)
	var mer: ServicioMundo = ServicioMundo.new()
	mer.servicio = "mercado_negro"
	escena.add_child(mer)
	var club: ServicioMundo = ServicioMundo.new()
	club.servicio = "club"
	escena.add_child(club)
	await get_tree().process_frame
	J.dinero = 100
	pre.usar(hud.jugador)
	comprobar(J.deuda == 300 and J.dinero == 400, "el prestamista da 300")
	J.dia_nuevo.emit()
	comprobar(J.deuda == 390 and J.dias_deuda == 1, "la deuda crece cada día")
	pre.usar(hud.jugador)
	comprobar(J.deuda == 0 and J.dinero == 10, "pagar la deuda")
	J.hora = 12.0
	J.dinero = 1000
	mer.usar(hud.jugador)
	comprobar(J.dinero == 1000, "el mercado negro cerrado de día no cobra")
	J.hora = 2.0
	mer.usar(hud.jugador)
	comprobar(J.dinero < 1000, "el mercado negro vende de madrugada")
	var copa_antes: int = J.dinero
	J.hora = 23.0
	club.usar(hud.jugador)
	comprobar(J.dinero == copa_antes - Casino.COPA_CLUB, "el club cobra la copa")
	# Territorios y reclutas.
	var Bandas = load("res://scripts/datos/bandas.gd")
	var jefe: Maton = Maton.new()
	jefe.jefe = true
	jefe.territorio = "1,2"
	escena.add_child(jefe)
	await get_tree().process_frame
	comprobar(is_equal_approx(jefe.vida, Bandas.VIDA_JEFE), "el jefe tiene más vida")
	jefe.recibir_dano(1000.0)
	comprobar(J.territorios.has("1,2"), "tumbar al jefe da el barrio")
	var d0: int = J.dinero
	J.dia_nuevo.emit()
	comprobar(J.dinero == d0 + Bandas.CUOTA_TERRITORIO, "el barrio paga su cuota")
	J.reclutas = 2
	d0 = J.dinero
	J.dia_nuevo.emit()
	comprobar(J.dinero == d0 + Bandas.CUOTA_TERRITORIO - 2 * Bandas.SUELDO_RECLUTA, "se paga a los reclutas")
	var aliado: Maton = Maton.new()
	aliado.aliado = true
	escena.add_child(aliado)
	await get_tree().process_frame
	comprobar(aliado.is_in_group("aliados") and not aliado.is_in_group("danable") and not aliado.is_in_group("matones"), "el aliado no es objetivo")
	aliado.recibir_dano(1000.0)
	comprobar(J.reclutas == 1, "un recluta caído se pierde")
	# Atraco en zona chunga: solo de noche, en la zona industrial y con dinero encima.
	J.distrito_actual = {"id": "industrial"}
	J.dinero = 1000
	J.hora = 12.0
	comprobar(J.probabilidad_atraco() == 0.0, "de día no hay atraco")
	J.hora = 23.0
	var p0: float = J.probabilidad_atraco()
	comprobar(p0 > 0.0, "de noche en la zona industrial hay riesgo")
	J.subir_atributo("sigilo", 10)
	comprobar(J.probabilidad_atraco() < p0, "el sigilo reduce el riesgo")
	J.dinero = 50
	comprobar(J.probabilidad_atraco() == 0.0, "sin dinero no te atracan")
	J.distrito_actual = {"id": "residencial"}
	J.dinero = 1000
	comprobar(J.probabilidad_atraco() == 0.0, "fuera de la zona chunga no hay riesgo")
	J.distrito_actual = {"id": "industrial"}
	var antes_d: int = J.dinero
	for i in 400:
		J._posible_atraco()
	comprobar(J.dinero < antes_d, "al final alguien te atraca")
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)
