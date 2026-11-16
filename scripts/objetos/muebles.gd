# muebles.gd
# -----------------------------------------------------------------------------
# Los muebles de casa que se usan con E. Son pequeños, así que van juntos en
# este archivo, cada uno como una clase interna:
#   Muebles.Cama        -> dormir: pasa el tiempo y las plantas crecen.
#   Muebles.Grifo       -> rellenar la jarra de agua.
#   Muebles.Estanteria  -> guardar y sacar cosas del inventario.
#   Muebles.HuecoMaceta -> colocar una maceta comprada en la herboristería.
#
# Para crear uno:  var cama := Muebles.Cama.new()
# -----------------------------------------------------------------------------
class_name Muebles
extends RefCounted


class Cama extends Interactuable:
	const HORAS_DE_SUENO: float = 60.0   # Segundos de crecimiento que "pasan" al dormir.

	func _ready() -> void:
		distancia = 2.0
		Construir.caja(self, Vector3(0, 0.25, 0), Vector3(1.1, 0.5, 2.1), Color(0.3, 0.2, 0.13))
		Construir.caja(self, Vector3(0, 0.55, 0.1), Vector3(1.0, 0.12, 1.8), Color(0.45, 0.15, 0.15), false)
		Construir.caja(self, Vector3(0, 0.62, -0.8), Vector3(0.7, 0.12, 0.35), Color(0.8, 0.78, 0.7), false)

	func texto_accion() -> String:
		return "Dormir un rato (las plantas crecen)"

	func usar(jugador: Node) -> void:
		jugador.hud.fundido(func() -> void:
			for maceta in get_tree().get_nodes_in_group("macetas"):
				maceta.adelantar(HORAS_DE_SUENO)
			Juego.avisar("Duermes con un ojo abierto. Las plantas han crecido mientras tanto."), 1.2)


class Grifo extends Interactuable:
	func _ready() -> void:
		distancia = 1.8
		# Encimera de cocina con fregadero, fogón y el grifo.
		Construir.caja(self, Vector3(0, 0.45, 0), Vector3(2.2, 0.9, 0.7), Color(0.35, 0.3, 0.25))
		Construir.caja(self, Vector3(-0.4, 0.91, 0), Vector3(0.7, 0.02, 0.5), Color(0.15, 0.2, 0.25), false)
		Construir.cilindro(self, Vector3(-0.4, 1.1, -0.28), 0.03, 0.4, Color(0.6, 0.6, 0.6))
		Construir.caja(self, Vector3(-0.4, 1.28, -0.18), Vector3(0.05, 0.05, 0.22), Color(0.6, 0.6, 0.6), false)
		Construir.caja(self, Vector3(0.6, 0.92, 0), Vector3(0.6, 0.04, 0.5), Color(0.1, 0.1, 0.1), false)
		Construir.cilindro(self, Vector3(0.6, 1.02, 0), 0.15, 0.16, Color(0.4, 0.25, 0.15))

	func texto_accion() -> String:
		if not Juego.tiene_recipiente():
			return "Grifo (compra una jarra en la herboristería)"
		return "Llenar tus jarras y regaderas"

	func usar(_jugador: Node) -> void:
		if not Juego.tiene_recipiente():
			Juego.avisar("Necesitas una jarra. La venden en la herboristería.")
			return
		Juego.rellenar_agua()
		Juego.avisar("Recipientes llenos.")


class Estanteria extends Interactuable:
	func _ready() -> void:
		distancia = 2.0
		Construir.caja(self, Vector3(0, 1.0, 0), Vector3(1.6, 2.0, 0.45), Color(0.28, 0.19, 0.12))
		for i in 4:
			Construir.caja(self, Vector3(0, 0.3 + i * 0.5, 0.05), Vector3(1.5, 0.04, 0.4), Color(0.18, 0.12, 0.08), false)
		# Unas cajas y botes encima para que parezca usada.
		Construir.caja(self, Vector3(-0.4, 0.9, 0.05), Vector3(0.4, 0.3, 0.3), Color(0.45, 0.35, 0.2), false)
		Construir.cilindro(self, Vector3(0.4, 1.42, 0.05), 0.1, 0.25, Color(0.3, 0.5, 0.4), false, 0.4)

	func texto_accion() -> String:
		return "Estantería (guardar y sacar cosas)"

	func usar(jugador: Node) -> void:
		jugador.hud.abrir_estanteria()


class HuecoMaceta extends Interactuable:
	var _marca: Node3D

	func _ready() -> void:
		distancia = 1.8
		add_to_group("huecos_maceta")
		# Un platillo vacío: aquí cabe una maceta.
		_marca = Construir.cilindro(self, Vector3(0, 0.02, 0), 0.24, 0.04, Color(0.35, 0.3, 0.25))

	func texto_accion() -> String:
		return "Colocar maceta (tienes %d)" % Juego.cuenta("maceta")

	func usar(_jugador: Node) -> void:
		if not Juego.tiene("maceta"):
			Juego.avisar("No tienes macetas. Cómpralas en la herboristería.")
			return
		Juego.quitar("maceta")
		poner_maceta()
		Juego.avisar("Has colocado una maceta. Acércate y pulsa E para plantar.")

	# Cambia el hueco por una maceta de verdad (también lo usa la casa al empezar).
	func poner_maceta() -> Maceta3D:
		var maceta: Maceta3D = Maceta3D.new()
		maceta.position = position
		get_parent().add_child(maceta)
		remove_from_group("huecos_maceta")
		queue_free()
		return maceta
