# inmobiliaria_mostrador.gd
# -----------------------------------------------------------------------------
# El quiosco de la inmobiliaria en la plaza: E abre la ventana de alquiler y
# compra de casas y huertos. SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name InmobiliariaMostrador
extends Interactuable


func _ready() -> void:
	distancia = 2.6
	Construir.caja(self, Vector3(0, 1.25, 0), Vector3(3.0, 2.5, 2.4), Color(0.2, 0.28, 0.4), true)
	Construir.caja(self, Vector3(0, 2.7, 0), Vector3(3.4, 0.3, 2.8), Color(0.12, 0.15, 0.22), false)
	Construir.caja(self, Vector3(0, 1.1, 1.22), Vector3(1.4, 1.2, 0.06), Color(0.05, 0.08, 0.12), false)
	var t: Label3D = Construir.texto(self, Vector3(0, 3.3, 1.3), "INMOBILIARIA", 72, Color(0.6, 0.85, 1.0))
	t.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func texto_accion() -> String:
	return "Inmobiliaria: alquilar, comprar o vender casas y huertos"


func usar(jugador: Node) -> void:
	jugador.hud.abrir_inmobiliaria()
