# ciclo_dia.gd
# -----------------------------------------------------------------------------
# El cielo y la luz según la hora del juego (Juego.hora, de 0 a 24):
#   - El sol sale hacia las 6:00, está arriba a las 12:00 y se pone a las 18:00.
#   - De noche manda la luna, el cielo se oscurece y se enciende la niebla azul.
#   - Las luces del grupo "luces_noche" (farolas, ventanas...) se encienden
#     solas al anochecer y se apagan al amanecer.
# Cambia la hora con el panel de administrador (F1) para ver cómo queda.
# -----------------------------------------------------------------------------
class_name CicloDia
extends Node3D

const CIELO_NOCHE: Color = Color(0.03, 0.04, 0.07)
const CIELO_DIA: Color = Color(0.55, 0.7, 0.88)
const AMBIENTE_NOCHE: Color = Color(0.3, 0.33, 0.45)
const AMBIENTE_DIA: Color = Color(0.8, 0.84, 0.9)
const NIEBLA_NOCHE: Color = Color(0.07, 0.09, 0.12)
const NIEBLA_DIA: Color = Color(0.62, 0.7, 0.78)

var _ambiente: Environment
var _sol: DirectionalLight3D
var _luna: DirectionalLight3D
var _material_cielo: ProceduralSkyMaterial


func _ready() -> void:
	_ambiente = Environment.new()
	# Cielo con degradado y disco solar; sus colores cambian con la hora.
	_material_cielo = ProceduralSkyMaterial.new()
	_material_cielo.sun_angle_max = 25.0
	_material_cielo.sun_curve = 0.15
	var cielo: Sky = Sky.new()
	cielo.sky_material = _material_cielo
	_ambiente.sky = cielo
	_ambiente.background_mode = Environment.BG_SKY
	_ambiente.adjustment_enabled = true
	_ambiente.adjustment_contrast = 1.08
	_ambiente.adjustment_saturation = 1.12
	_ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_ambiente.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_ambiente.fog_enabled = true
	# Brillo suave alrededor de las luces (farolas, ventanas, caldero).
	_ambiente.glow_enabled = true
	_ambiente.glow_intensity = 0.6
	var entorno: WorldEnvironment = WorldEnvironment.new()
	entorno.environment = _ambiente
	add_child(entorno)

	_sol = DirectionalLight3D.new()
	_sol.shadow_enabled = true
	_sol.directional_shadow_max_distance = 70.0
	add_child(_sol)

	_luna = DirectionalLight3D.new()
	_luna.light_color = Color(0.6, 0.7, 1.0)
	_luna.shadow_enabled = true
	_luna.directional_shadow_max_distance = 40.0
	_luna.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	add_child(_luna)
	actualizar()
	_ventanas_encendidas = -1   # Las casas aún no existen: se comprobará en el primer fotograma.


# -1 = sin comprobar. Se reinicia al arrancar porque las casas (y sus ventanas) se
# crean después de que el ciclo calcule la primera vez.
var _ventanas_encendidas: int = -1
var _encendido_previo: float = -1.0
var _ventanas_encendidas_forzar: bool = true


func _process(_delta: float) -> void:
	actualizar()


func actualizar() -> void:
	# Ángulo del sol: 0 a las 6:00, PI/2 a las 12:00, PI a las 18:00.
	var t: float = (Juego.hora - 6.0) / 24.0 * TAU
	var altura: float = sin(t)                         # 1 = mediodía, -1 = medianoche.
	var dia: float = smoothstep(-0.12, 0.3, altura)    # 0 = noche, 1 = día.

	_sol.rotation = Vector3(-t, deg_to_rad(30), 0)
	_sol.light_energy = 1.1 * dia
	_sol.visible = dia > 0.01
	_sol.light_color = Color(1.0, 0.55, 0.3).lerp(Color(1.0, 0.96, 0.88), clampf(altura * 2.5, 0.0, 1.0))
	_luna.light_energy = 0.25 * (1.0 - dia)
	_luna.visible = dia < 0.99

	# Cielo: azul de día, casi negro de noche y naranja en el amanecer y el atardecer.
	var crepusculo: float = clampf(1.0 - absf(altura + 0.05) * 4.0, 0.0, 1.0)
	var horizonte: Color = Color(0.04, 0.05, 0.1).lerp(Color(0.68, 0.8, 0.92), dia)
	horizonte = horizonte.lerp(Color(1.0, 0.5, 0.28), crepusculo * 0.75)
	_material_cielo.sky_top_color = Color(0.012, 0.016, 0.04).lerp(Color(0.2, 0.45, 0.82), dia)
	_material_cielo.sky_horizon_color = horizonte
	_material_cielo.ground_horizon_color = horizonte
	_material_cielo.ground_bottom_color = Color(0.02, 0.025, 0.04).lerp(Color(0.25, 0.27, 0.3), dia)
	_material_cielo.energy_multiplier = lerpf(0.5, 1.0, dia)
	_ambiente.ambient_light_color = AMBIENTE_NOCHE.lerp(AMBIENTE_DIA, dia)
	_ambiente.ambient_light_energy = lerpf(0.35, 0.8, dia)
	_ambiente.fog_light_color = NIEBLA_NOCHE.lerp(NIEBLA_DIA, dia)
	_ambiente.fog_density = lerpf(0.035, 0.008, dia)

	# Luces de la ciudad: encendidas de noche, apagadas de día.
	var encendido: float = 1.0 - smoothstep(0.0, 0.35, altura)
	# Ventanas con luz: se encienden y apagan de golpe, solo cuando cambia el estado.
	var ventanas_encendidas: int = 1 if encendido > 0.5 else 0
	if ventanas_encendidas != _ventanas_encendidas and is_inside_tree():
		_ventanas_encendidas = ventanas_encendidas
		for ventana in get_tree().get_nodes_in_group("ventanas_noche"):
			(ventana as Node3D).visible = ventanas_encendidas == 1
	# Las luces solo se tocan cuando el nivel cambia de verdad (no cada fotograma).
	if absf(encendido - _encendido_previo) > 0.01 or _ventanas_encendidas_forzar:
		_encendido_previo = encendido
		_ventanas_encendidas_forzar = false
		for luz in get_tree().get_nodes_in_group("luces_noche"):
			var foco: Light3D = luz as Light3D
			if foco != null:
				foco.light_energy = float(foco.get_meta("energia_base", 1.0)) * encendido
