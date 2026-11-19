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
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)
