# caldero_3d.gd
# -----------------------------------------------------------------------------
# El caldero de tu casa. Pulsa E para echar la hierba que tienes en la
# mano (elígela en la barra rápida con 1-9). Cuando hay GameData.INGREDIENTES_POR_POCION hierbas
# dentro, se mezclan solas: si coinciden con una receta sale una poción; si
# no, sale un bodrio y se pierde.
# -----------------------------------------------------------------------------
class_name Caldero3D
extends Interactuable

var ingredientes: Array[String] = []

var _liquido: Node3D
var _material_liquido: StandardMaterial3D
var _fuego: OmniLight3D


func _ready() -> void:
	distancia = 2.0
	# Cuerpo negro, borde y patas. El cuerpo es sólido para no atravesarlo.
	Construir.cilindro(self, Vector3(0, 0.5, 0), 0.55, 0.7, Color(0.08, 0.08, 0.09), true, 0.0, 0.62)
	Construir.cilindro(self, Vector3(0, 0.87, 0), 0.66, 0.06, Color(0.12, 0.12, 0.13))
	_liquido = Construir.cilindro(self, Vector3(0, 0.86, 0), 0.58, 0.03, Color(0.25, 0.35, 0.45), false, 1.5)
	_material_liquido = (_liquido as MeshInstance3D).mesh.material
	# Brasas debajo y su luz verdosa.
	for i in 3:
		var brasa: Node3D = Construir.caja(self, Vector3.ZERO, Vector3(0.25, 0.08, 0.08),
				Color(0.35, 0.9, 0.5), false, 3.0)
		brasa.rotation.y = i * PI / 3.0
		brasa.position = Vector3(0, 0.05, 0)
	_fuego = Construir.luz(self, Vector3(0, 1.3, 0), Color(0.4, 1.0, 0.55), 1.5, 6.0)
	_actualizar_color()


func _process(_delta: float) -> void:
	# El fuego tiembla y el líquido burbujea un poco.
	var t: float = Time.get_ticks_msec() / 1000.0
	_fuego.light_energy = 1.4 + 0.3 * sin(t * 7.0) + 0.2 * sin(t * 13.0)
	_liquido.position.y = 0.86 + 0.01 * sin(t * 3.0)


# Devuelve el id de hierba ("bruma") de lo que llevas en la mano, o "" si no es una hierba.
func _hierba_en_mano() -> String:
	var id: String = Juego.id_en_mano()
	if id.begins_with("hierba_"):
		return id.trim_prefix("hierba_")
	return ""


func texto_accion() -> String:
	var id_hierba: String = _hierba_en_mano()
	if id_hierba == "":
		return "Caldero (lleva una hierba en la mano: teclas 1-9)"
	return "Echar %s  (%d/%d en el caldero)" % [GameData.HIERBAS[id_hierba]["nombre"],
			ingredientes.size(), GameData.INGREDIENTES_POR_POCION]


func usar(_jugador: Node) -> void:
	var id_hierba: String = _hierba_en_mano()
	if id_hierba == "":
		Juego.avisar("Coge una hierba cosechada en la barra rápida (teclas 1-9) y pulsa E.")
		return
	Juego.quitar("hierba_" + id_hierba)
	ingredientes.append(id_hierba)
	_actualizar_color()
	if ingredientes.size() >= GameData.INGREDIENTES_POR_POCION:
		_mezclar()
	else:
		Juego.avisar("Echas %s al caldero. Falta %d ingrediente más." % [
				GameData.HIERBAS[id_hierba]["nombre"],
				GameData.INGREDIENTES_POR_POCION - ingredientes.size()])


func _mezclar() -> void:
	var id_pocion: String = GameData.buscar_pocion(ingredientes)
	if id_pocion == "":
		Juego.avisar("El caldero escupe un humo gris. Has hecho un bodrio y se ha perdido.")
	else:
		var id_objeto: String = "pocion_" + id_pocion
		if Juego.cabe(id_objeto):
			Juego.anadir(id_objeto)
			Juego.avisar("¡Has preparado %s! Véndela en la ventanilla." %
					GameData.POCIONES[id_pocion]["nombre"])
		else:
			Juego.avisar("Has preparado %s, pero no te cabe y se derrama." %
					GameData.POCIONES[id_pocion]["nombre"])
	ingredientes.clear()
	_actualizar_color()
	Juego.cambio.emit()


# El líquido toma la mezcla de colores de lo que hay dentro.
func _actualizar_color() -> void:
	var color: Color = Color(0.2, 0.3, 0.4)  # Agua sola.
	if not ingredientes.is_empty():
		color = Color(0, 0, 0)
		for id_hierba in ingredientes:
			color += GameData.HIERBAS[id_hierba]["color"]
		color /= float(ingredientes.size())
		color.a = 1.0
	_material_liquido.albedo_color = color
	_material_liquido.emission = color
