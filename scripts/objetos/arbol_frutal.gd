# arbol_frutal.gd
# -----------------------------------------------------------------------------
# Un manzano de la granja: cada 300 s da 3 manzanas (se acumulan hasta 12).
# E recoge la fruta. Hace falta tener algún huerto. SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name ArbolFrutal
extends Interactuable

const DatosObjetos = preload("res://scripts/datos/objetos.gd")
const TIEMPO: float = 300.0   # Una tanda cada 5 minutos.
const FRUTOS: int = 3
const MAXIMO: int = 12

var id_arbol: String = "manzano_1"
var _frutas: Node3D


func _ready() -> void:
	distancia = 2.6
	Construir.cilindro(self, Vector3(0, 1.0, 0), 0.25, 2.0, Color(0.3, 0.2, 0.12), true)
	Construir.esfera(self, Vector3(0, 2.8, 0), 1.6, Color(0.18, 0.4, 0.15), Vector3(1, 0.85, 1))
	_frutas = Node3D.new()
	add_child(_frutas)


func _estado() -> Dictionary:
	if not Juego.granja.has(id_arbol):
		Juego.granja[id_arbol] = {"prod": 0, "t": 0.0, "u": Juego.reloj}
	return Juego.granja[id_arbol]


func _process(_delta: float) -> void:
	var e: Dictionary = _estado()
	var pasado: float = maxf(0.0, Juego.reloj - float(e.get("u", Juego.reloj)))
	e["u"] = Juego.reloj
	if not Juego.huertos.is_empty() and int(e["prod"]) < MAXIMO:
		e["t"] = float(e["t"]) + pasado
		while float(e["t"]) >= TIEMPO and int(e["prod"]) < MAXIMO:
			e["t"] = float(e["t"]) - TIEMPO
			e["prod"] = mini(MAXIMO, int(e["prod"]) + FRUTOS)
		if int(e["prod"]) >= MAXIMO:
			e["t"] = 0.0
	var visibles: int = mini(6, int(e["prod"]))
	if _frutas.get_child_count() != visibles:
		for h in _frutas.get_children():
			h.queue_free()
		for i in visibles:
			var a: float = i * 1.1
			Construir.esfera(_frutas, Vector3(cos(a) * 1.3, 2.6 + (i % 3) * 0.3, sin(a) * 1.3), 0.12, Color(0.85, 0.15, 0.1))


func texto_accion() -> String:
	var e: Dictionary = _estado()
	if int(e["prod"]) > 0:
		return "Recoger %d x Manzana" % e["prod"]
	return "Manzano (da fruta cada %d s)" % int(TIEMPO)


func usar(_jugador: Node) -> void:
	if Juego.huertos.is_empty():
		Juego.avisar("Necesitas un huerto alquilado o comprado para aprovechar la granja.")
		return
	var e: Dictionary = _estado()
	var cantidad: int = int(e["prod"])
	if cantidad <= 0:
		Juego.avisar("Aún no hay fruta madura.")
		return
	var sobra: int = Juego.anadir("manzana", cantidad)
	e["prod"] = sobra
	Juego.ganar_xp(cantidad - sobra)
	Juego.avisar("Has recogido %d x Manzana." % (cantidad - sobra))
