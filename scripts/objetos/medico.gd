# medico.gd
# -----------------------------------------------------------------------------
# El médico de la botica. Pulsa E para abrir su consulta (VentanaMedico): cura
# las heridas, quita los efectos malos de las pociones y vende un refuerzo
# contra el daño. Aparece dentro de cada botica (ver Barrio._decorar_tienda).
# Los precios están en scripts/ui/ventana_medico.gd.
# -----------------------------------------------------------------------------
class_name Medico
extends Interactuable


func _ready() -> void:
	distancia = 2.4
	# Bata blanca, cabeza y una cruz roja en el pecho.
	Construir.cilindro(self, Vector3(0, 0.65, 0), 0.3, 1.3, Color(0.88, 0.88, 0.85), false, 0.0, 0.24)
	Construir.esfera(self, Vector3(0, 1.48, 0), 0.19, Color(0.8, 0.68, 0.58))
	Construir.esfera(self, Vector3(0, 1.62, -0.02), 0.17, Color(0.25, 0.2, 0.15), Vector3(1, 0.5, 1))
	Construir.caja(self, Vector3(0, 1.0, 0.27), Vector3(0.22, 0.06, 0.03), Color(0.85, 0.15, 0.15), false)
	Construir.caja(self, Vector3(0, 1.0, 0.27), Vector3(0.06, 0.22, 0.03), Color(0.85, 0.15, 0.15), false)
	# Cartel con una cruz roja.
	Construir.caja(self, Vector3(0, 2.2, 0), Vector3(0.8, 0.5, 0.06), Color(0.95, 0.95, 0.92), false)
	Construir.caja(self, Vector3(0, 2.2, 0.04), Vector3(0.4, 0.1, 0.03), Color(0.85, 0.15, 0.15), false)
	Construir.caja(self, Vector3(0, 2.2, 0.04), Vector3(0.1, 0.4, 0.03), Color(0.85, 0.15, 0.15), false)
	Construir.texto(self, Vector3(0, 2.65, 0.06), "MÉDICO", 36, Color(0.95, 0.95, 0.92))


func texto_accion() -> String:
	return "Hablar con el médico (curarte)"


func usar(jugador: Node) -> void:
	jugador.hud.abrir_medico()
