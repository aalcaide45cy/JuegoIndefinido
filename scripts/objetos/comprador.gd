# comprador.gd
# -----------------------------------------------------------------------------
# El cliente de un encargo aceptado en el móvil: espera de pie en su punto de
# encuentro. Pulsa E para entregarle las pociones. Sale en brújula y mapas.
# -----------------------------------------------------------------------------
class_name Comprador
extends Interactuable

var id_encargo: int = 0
var gestor: Encargos
var _cartel: Label3D


func _ready() -> void:
	distancia = 2.4
	var persona: Node3D = Assets.personaje("quaternius/toon-shooter-game-kit/Characters/Character_Hazmat", "", "Idle")
	if persona != null:
		add_child(persona)
	else:
		Construir.cilindro(self, Vector3(0, 0.8, 0), 0.3, 1.6, Color(0.7, 0.4, 0.2), false)
		Construir.esfera(self, Vector3(0, 1.75, 0), 0.2, Color(0.8, 0.65, 0.55))
	_cartel = Construir.texto(self, Vector3(0, 2.3, 0), "", 32, Color(1.0, 0.85, 0.4))
	_cartel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_to_group("poi")
	set_meta("poi_color", Color(1.0, 0.6, 0.15))
	set_meta("poi_nombre", "Comprador")


func _datos() -> Dictionary:
	for e in Juego.encargos:
		if int(e["id"]) == id_encargo:
			return e
	return {}


func _process(_delta: float) -> void:
	var e: Dictionary = _datos()
	if e.is_empty():
		return
	set_meta("poi_nombre", "Comprador: " + str(e["cliente"]))
	_cartel.text = "%s\n%d x %s\n%d s" % [e["cliente"], e["cantidad"], GameData.POCIONES[e["pocion"]]["nombre"], int(e["t"])]


func texto_accion() -> String:
	var e: Dictionary = _datos()
	if e.is_empty():
		return "..."
	return "Entregar %d x %s (%d $)" % [e["cantidad"], GameData.POCIONES[e["pocion"]]["nombre"], e["pago"]]


func usar(_jugador: Node) -> void:
	if gestor != null:
		var error: String = gestor.entregar(id_encargo)
		if error != "":
			Juego.avisar(error)
