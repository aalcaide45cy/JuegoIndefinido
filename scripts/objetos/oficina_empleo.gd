# oficina_empleo.gd
# -----------------------------------------------------------------------------
# La Bolsa de trabajo: un quiosco donde E abre la ventana para contratar,
# asignar y despedir personal y recoger lo que producen. SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name OficinaEmpleo
extends Interactuable


func _ready() -> void:
	distancia = 2.6
	Construir.caja(self, Vector3(0, 1.25, 0), Vector3(3.0, 2.5, 2.4), Color(0.3, 0.25, 0.12), true)
	Construir.caja(self, Vector3(0, 2.7, 0), Vector3(3.4, 0.3, 2.8), Color(0.15, 0.12, 0.06), false)
	Construir.caja(self, Vector3(0, 1.1, 1.22), Vector3(1.4, 1.2, 0.06), Color(0.05, 0.05, 0.05), false)
	var t: Label3D = Construir.texto(self, Vector3(0, 3.3, 1.3), "BOLSA DE TRABAJO", 72, Color(1.0, 0.9, 0.5))
	t.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func texto_accion() -> String:
	return "Bolsa de trabajo: contratar personal y recoger su producción"


func usar(jugador: Node) -> void:
	jugador.hud.abrir_ventana(BolsaTrabajo.new())
