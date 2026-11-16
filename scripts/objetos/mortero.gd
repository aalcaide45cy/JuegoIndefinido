# mortero.gd
# -----------------------------------------------------------------------------
# Un mortero de piedra. Con 2 o más hierbas en la mano, E abre el minijuego de
# machacar (MinijuegoMachacar). SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name Mortero
extends Interactuable


func _ready() -> void:
	distancia = 1.8
	Construir.cilindro(self, Vector3(0, 0.45, 0), 0.22, 0.9, Color(0.35, 0.34, 0.33), true, 0.0, 0.3)
	Construir.cilindro(self, Vector3(0, 0.93, 0), 0.28, 0.08, Color(0.4, 0.39, 0.38))
	Construir.texto(self, Vector3(0, 1.35, 0), "MORTERO", 32, Color(0.85, 0.9, 0.8))


func texto_accion() -> String:
	var id: String = Juego.id_en_mano()
	if id.begins_with("hierba_") and Juego.cuenta(id) >= 2:
		return "Machacar 2 hierbas (minijuego)"
	return "Mortero (ten 2 o más hierbas iguales en la mano)"


func usar(jugador: Node) -> void:
	var id: String = Juego.id_en_mano()
	if not id.begins_with("hierba_") or Juego.cuenta(id) < 2:
		Juego.avisar("Coge 2 o más hierbas iguales con la barra rápida y pulsa E.")
		return
	jugador.hud.abrir_mortero(id)
