# Prueba de los logros que fallaban: Granjero, Primera receta y Terrateniente.
#   godot --headless --path . res://tests/prueba_logros.tscn
extends Node

var fallos: int = 0


func comprobar(c: bool, t: String) -> void:
	if not c:
		fallos += 1
		print("FALLO: ", t)


func _ready() -> void:
	await get_tree().process_frame
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	var J = raiz.get_node("Juego")
	var L = raiz.get_node("Logros")
	L.reiniciar()
	J.reiniciar()
	await get_tree().create_timer(2.5).timeout   # Deja correr la comprobación de logros.
	print("tras empezar, conseguidos: ", L.conseguidos.keys())
	comprobar(not L.tiene("granjero"), "Granjero no debe salir al empezar")
	comprobar(not L.tiene("terrateniente"), "Terrateniente no debe salir al empezar")
	comprobar(not L.tiene("primera_receta"), "Primera receta no debe salir al empezar")
	# Una casa alquilada y un huerto: 2 propiedades, no 3.
	J.viviendas["plaza"] = true
	J.huertos["huerto_a"] = true
	comprobar(L.cuenta("propiedades") == 2, "propiedades = 2 (da %d)" % L.cuenta("propiedades"))
	# Un manzano que da fruta solo, sin animales: no es granjero.
	J.granja["arbol_x"] = {"prod": 3, "t": 0.0, "u": 0.0}
	comprobar(L.cuenta("granja") == 0, "un árbol solo no cuenta como animal (da %d)" % L.cuenta("granja"))
	J.granja["corral_x"] = {"n": 1, "prod": 0, "t": 0.0, "nivel": 1, "u": 0.0}
	comprobar(L.cuenta("granja") == 1, "un animal cuenta (da %d)" % L.cuenta("granja"))
	# Primera receta con una poción clásica.
	var clasica: String = GameData.POCIONES.keys()[0]
	J.descubrir_receta(clasica)
	comprobar(L.tiene("primera_receta"), "Primera receta con poción clásica")
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit()
