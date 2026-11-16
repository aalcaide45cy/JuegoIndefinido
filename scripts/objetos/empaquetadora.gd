# empaquetadora.gd
# -----------------------------------------------------------------------------
# Máquina de empaquetar de tu casa. Con una poción en la mano, pulsa E: empaqueta
# hasta 5 (tarda 2 s). Los paquetes se pagan un 30% más en los encargos del móvil.
# SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name Empaquetadora
extends Interactuable

var _ocupada: float = 0.0
var _luz: MeshInstance3D


func _ready() -> void:
	distancia = 2.0
	Construir.caja(self, Vector3(0, 0.45, 0), Vector3(1.1, 0.9, 0.7), Color(0.25, 0.28, 0.32), true)
	Construir.caja(self, Vector3(0, 0.95, 0), Vector3(0.9, 0.12, 0.6), Color(0.18, 0.2, 0.24), false)
	Construir.caja(self, Vector3(0, 0.6, 0.36), Vector3(0.6, 0.3, 0.04), Color(0.05, 0.06, 0.08), false)
	_luz = Construir.caja(self, Vector3(0.4, 0.78, 0.36), Vector3(0.1, 0.1, 0.04), Color(0.2, 1.0, 0.4), false, 2.0) as MeshInstance3D
	Construir.texto(self, Vector3(0, 1.3, 0), "EMPAQUETADORA", 36, Color(0.7, 0.9, 1.0))


func _process(delta: float) -> void:
	if _ocupada > 0.0:
		_ocupada -= delta


func texto_accion() -> String:
	var id: String = Juego.id_en_mano()
	if _ocupada > 0.0:
		return "Empaquetando..."
	if id.begins_with("pocion_"):
		return "Empaquetar %s" % DatosObjetos.nombre(id)
	return "Empaquetadora (ten una poción en la mano)"


const DatosObjetos = preload("res://scripts/datos/objetos.gd")


func usar(_jugador: Node) -> void:
	if _ocupada > 0.0:
		return
	var id: String = Juego.id_en_mano()
	if not id.begins_with("pocion_"):
		Juego.avisar("Coge una poción con la barra rápida y pulsa E.")
		return
	var paquete: String = "paquete_" + id.trim_prefix("pocion_")
	if not DatosObjetos.LISTA.has(paquete):
		Juego.avisar("Esa poción no se puede empaquetar.")
		return
	var n: int = mini(5, Juego.cuenta(id))
	Juego.quitar(id, n)
	var sobra: int = Juego.anadir(paquete, n)
	_ocupada = 2.0
	Juego.ganar_xp(3 * n)
	Sonido.tocar(self, "golpe")
	Juego.avisar("Empaquetadas %d. Los paquetes pagan un 30%% más en encargos." % (n - sobra))
