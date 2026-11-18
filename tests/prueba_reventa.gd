# Comprar una oferta y revenderla al instante nunca debe dar ganancia.
#   godot --headless --path . res://tests/prueba_reventa.tscn
extends Node

var fallos: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	var J = raiz.get_node("Juego")
	var lm: Rect2 = J.limites_mundo
	if lm.size.x < 10000.0 or lm.size.y < 10000.0 or not lm.has_point(Vector2(4990, -4990)):
		fallos += 1
		print("FALLO: Juego.limites_mundo no cubre el mundo de 10 km: ", lm)
	J.reiniciar()
	J.nivel = 30
	J.reputacion = 100
	J.habilidades["negociacion"] = true
	for id in preload("res://scripts/datos/negocios.gd").LICENCIAS:
		Negocios.estado()["licencias"][id] = true
	var mejor: float = -1.0
	var peor_txt: String = ""
	for ronda in 40:
		J.dinero = 100000000
		Negocios.estado()["activos"].clear()
		Negocios.estado()["mercado"].clear()
		Negocios.estado()["leads"].clear()
		Negocios.refrescar_mercado()
		for o in Negocios.estado()["mercado"].duplicate():
			var antes: int = J.dinero
			var r: String = Negocios.comprar_oferta(int(o["id"]), 1)   # Siempre el precio mínimo permitido.
			if Negocios.estado()["activos"].is_empty():
				continue
			var a: Dictionary = Negocios.estado()["activos"][0]
			var gasto: int = antes - J.dinero
			# Mejor cliente posible: acepta el techo de su límite.
			Negocios.poner_venta(int(a["uid"]), true)
			var l: Dictionary = Negocios._crear_lead(a, "venta")
			var precio: int = int(floor(Negocios.limite_efectivo(l, "vender")))
			var antes2: int = J.dinero
			Negocios.aceptar_lead(int(l["id"]), precio)
			var cobro: int = J.dinero - antes2
			var ganancia: float = float(cobro) / float(maxi(1, gasto)) - 1.0
			if ganancia > mejor:
				mejor = ganancia
				peor_txt = "%s gasto %d cobro %d" % [o["tipo"], gasto, cobro]
			Negocios.estado()["activos"].clear()
	print("Mejor ganancia posible comprando y revendiendo: %.1f %%  (%s)" % [mejor * 100.0, peor_txt])
	if mejor > 0.0:
		fallos += 1
		print("FALLO: se puede ganar dinero comprando y revendiendo al instante")
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit()
