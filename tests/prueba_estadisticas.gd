# Prueba de estadísticas: resistencia, hambre, sed, atributos, guardado y barra de vida.
#   godot --headless --path . res://tests/prueba_estadisticas.tscn
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
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()

	# Resistencia: correr la gasta, agotarse bloquea, parar la recupera.
	comprobar(J.puede_correr(), "al empezar se puede correr")
	for i in 100:
		J.avanzar_resistencia(0.1, true)
	comprobar(J.resistencia <= 0.0 and J.agotado, "10 s corriendo agotan")
	comprobar(not J.puede_correr(), "agotado no corre")
	for i in 100:
		J.avanzar_resistencia(0.1, false)
	comprobar(not J.agotado and J.puede_correr(), "descansando se vuelve a correr")

	# Hambre y sed bajan la resistencia máxima.
	J.hambre = 100.0
	comprobar(J.resistencia_max() < 60.0, "hambre alta baja el tope de aliento")
	J.comer(100.0)
	J.sed = 0.0
	comprobar(is_equal_approx(J.resistencia_max(), 100.0), "sin hambre ni sed, tope completo")

	# Atributos: constitución sube la vida máxima; fuerza se limita a 20.
	J.subir_atributo("constitucion", 5)
	comprobar(is_equal_approx(J.vida_max(), 120.0), "constitución 10 = 120 de vida")
	J.subir_atributo("fuerza", 99)
	comprobar(J.atributo("fuerza") == 20, "atributo máximo 20")

	# Guardado y carga.
	J.hambre = 33.0
	J.sed = 44.0
	Guardado.guardar(get_tree(), hud.jugador, 5)
	J.reiniciar()
	comprobar(J.atributo("constitucion") == 5, "reiniciar deja atributos en 5")
	Guardado.cargar(get_tree(), hud.jugador, 5)
	comprobar(J.atributo("constitucion") == 10 and J.atributo("fuerza") == 20, "se cargan los atributos")
	comprobar(absf(J.hambre - 33.0) < 0.01 and absf(J.sed - 44.0) < 0.01, "se cargan hambre y sed")

	# Esquiva y golpes: gastan aliento; esquivando no recibes daño.
	J.reiniciar()
	comprobar(J.gastar_resistencia(25.0) and is_equal_approx(J.resistencia, 75.0), "esquivar gasta 25 de aliento")
	J.invulnerable = 0.4
	var v0: float = J.vida
	J.cambiar_vida(-30.0)
	comprobar(is_equal_approx(J.vida, v0), "esquivando no hay daño")
	J.invulnerable = 0.0
	J.cambiar_vida(-30.0)
	comprobar(J.vida < v0, "sin esquivar sí hay daño")
	comprobar(not J.gastar_resistencia(1000.0), "no se puede gastar más aliento del que hay")

	# Matón: pelea, barra y botín.
	var maton: Maton = Maton.new()
	escena.add_child(maton)
	await get_tree().process_frame
	var dinero0: int = J.dinero
	maton.recibir_dano(30.0)
	var bm: BarraVida = maton.get_node_or_null("BarraVida") as BarraVida
	comprobar(bm != null and bm.visible, "el matón herido enseña su barra")
	maton.recibir_dano(100.0)
	comprobar(J.dinero > dinero0, "el matón muerto deja botín")
	comprobar(not maton.is_in_group("danable"), "el matón muerto ya no se puede herir")

	# Reputación en tres bandos, bandas y protección.
	var Bandas = load("res://scripts/datos/bandas.gd")
	J.reiniciar()
	J.cambiar_rep("hampa", 20)
	J.cambiar_rep("ley", -150)
	J.cambiar_rep("gente", 10)
	comprobar(J.rep_hampa == 20 and J.rep_ley == -100 and J.reputacion == 10, "la reputación se guarda por bando y se limita")
	comprobar(not J.protegido(), "sin cuota ni respeto no estás protegido")
	J.cambiar_rep("hampa", 15)
	comprobar(J.protegido(), "con 30 de hampa te respetan")
	J.reiniciar()
	J.dia = 5
	J.proteccion_hasta_dia = 5
	comprobar(J.protegido(), "pagar la cuota protege ese día")
	J.dia = 6
	comprobar(not J.protegido(), "al día siguiente caduca")
	comprobar(Bandas.dueno(3, 4) == Bandas.dueno(3, 4) and Bandas.BANDAS.has(Bandas.dueno(-7, 12)), "cada ciudad tiene una banda fija")
	J.rep_hampa = 12
	J.rep_ley = -7
	J.proteccion_hasta_dia = 9
	J.territorios = {"3,4": "jugador"}
	J.reclutas = 3
	J.deuda = 500
	J.dias_deuda = 2
	Guardado.guardar(get_tree(), hud.jugador, 5)
	J.reiniciar()
	Guardado.cargar(get_tree(), hud.jugador, 5)
	comprobar(J.rep_hampa == 12 and J.rep_ley == -7 and J.proteccion_hasta_dia == 9, "se guardan reputación y protección")
	comprobar(J.territorios.has("3,4") and J.reclutas == 3 and J.deuda == 500 and J.dias_deuda == 2, "se guardan territorios, reclutas y deuda")

	# Barra de vida de NPC: se crea al recibir daño y se oculta después.
	var guardias: Array = get_tree().get_nodes_in_group("guardias")
	if not guardias.is_empty():
		var g: Node3D = guardias[0]
		g.visible = true
		g.recibir_dano(10.0)
		var barra: BarraVida = g.get_node_or_null("BarraVida") as BarraVida
		comprobar(barra != null and barra.visible, "el guardia herido enseña su barra")
		if barra != null:
			barra._process(BarraVida.VISIBLE_TRAS_DANO + 1.0)
			comprobar(not barra.visible, "la barra se oculta sola")
	else:
		print("(sin guardias en la escena: se omite la comprobación de la barra)")
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)
