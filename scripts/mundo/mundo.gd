# mundo.gd
# -----------------------------------------------------------------------------
# La escena principal del juego 3D. Monta todo al arrancar:
#   - el ambiente nocturno (cielo oscuro, luna, niebla),
#   - los barrios de la ciudad (de momento, la plaza y tu herboristería),
#   - el HUD y el jugador.
#
# Para ampliar la ciudad, añade más barrios en _ready() (mira barrio.gd).
# -----------------------------------------------------------------------------
extends Node3D

# Dónde empieza el jugador: en la plaza, mirando a la herboristería (norte).
const INICIO_JUGADOR: Vector3 = Vector3(0, 0, 8)


func _ready() -> void:
	_crear_ambiente()

	_anadir_barrio(BarrioPlaza.new(), Vector3.ZERO)
	_anadir_barrio(InteriorHerboristeria.new(), Vector3.ZERO)
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


func _crear_ambiente() -> void:
	var ambiente: Environment = Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color(0.03, 0.04, 0.07)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color(0.3, 0.33, 0.45)
	ambiente.ambient_light_energy = 0.35
	ambiente.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Niebla: lo que está lejos se pierde en un azul grisáceo.
	ambiente.fog_enabled = true
	ambiente.fog_light_color = Color(0.07, 0.09, 0.12)
	ambiente.fog_density = 0.035
	# Brillo suave alrededor de las luces (farolas, ventanas, caldero).
	ambiente.glow_enabled = true
	ambiente.glow_intensity = 0.6
	var entorno: WorldEnvironment = WorldEnvironment.new()
	entorno.environment = ambiente
	add_child(entorno)

	# La luna: una luz direccional fría y débil, con sombras.
	var luna: DirectionalLight3D = DirectionalLight3D.new()
	luna.light_color = Color(0.6, 0.7, 1.0)
	luna.light_energy = 0.25
	luna.shadow_enabled = true
	luna.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	add_child(luna)
