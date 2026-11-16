# mundo.gd
# -----------------------------------------------------------------------------
# La escena principal del juego 3D. Monta todo al arrancar:
#   - el cielo y la luz del día y la noche (ciclo_dia.gd),
#   - los barrios de la ciudad (de momento, la Plaza del Ahorcado, con la
#     herboristería y la casa en alquiler),
#   - el HUD y el jugador.
#
# Para ampliar la ciudad, añade más barrios en _ready() (mira barrio.gd).
# -----------------------------------------------------------------------------
extends Node3D

# Dónde empieza el jugador: en la plaza, mirando a la herboristería (norte).
const INICIO_JUGADOR: Vector3 = Vector3(0, 0, 8)


func _ready() -> void:
	add_child(CicloDia.new())

	_anadir_barrio(BarrioPlaza.new(), Vector3.ZERO)
	# Ejemplo para el futuro:
	# _anadir_barrio(BarrioMercado.new(), Vector3(0, 0, -60))

	var hud: Hud = Hud.new()
	add_child(hud)
	var jugador: Jugador = Jugador.new()
	jugador.position = INICIO_JUGADOR
	jugador.hud = hud
	add_child(jugador)
	hud.jugador = jugador


func _anadir_barrio(barrio: Barrio, pos: Vector3) -> void:
	barrio.position = pos
	add_child(barrio)
