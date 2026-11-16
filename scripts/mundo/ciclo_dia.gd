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
	_ventanas_encendidas_forzar = true   # Y las farolas tampoco: se ajustan también entonces.


# -1 = sin comprobar. Se reinicia al arrancar porque las casas (y sus ventanas) se
# crean después de que el ciclo calcule la primera vez.
var _ventanas_encendidas: int = -1
var _encendido_previo: float = -1.0
var _ventanas_encendidas_forzar: bool = true


# Cada cuánto se recalculan cielo y luces: no hace falta en cada fotograma
# (la hora avanza despacio y cambiar el cielo obliga a redibujarlo).
const PASO_HORA: float = 0.01          # Horas de juego (unos 36 s de juego).
const INTERVALO_LUCES: float = 0.25    # Segundos reales entre repasos de luces cercanas.
# Una luz se apaga si la cámara está más lejos que su alcance + esto (en metros).
const DISTANCIA_LUCES: float = 30.0

var _hora_previa: float = -100.0
var _t_luces: float = 0.0


func _process(delta: float) -> void:
	if absf(Juego.hora - _hora_previa) >= PASO_HORA or _ventanas_encendidas == -1:
		_hora_previa = Juego.hora
		actualizar()
	_t_luces -= delta
	if _t_luces <= 0.0:
		_t_luces = INTERVALO_LUCES
		_luces_cercanas()


# Solo se dibujan las luces cercanas a la cámara y, las de noche, cuando están
# encendidas. Con el renderizador Compatibilidad cada luz visible obliga a
# dibujar otra vez los objetos que toca, así que esto ahorra mucho.
func _luces_cercanas() -> void:
	var camara: Camera3D = get_viewport().get_camera_3d()
	if camara == null:
		return
	var ojo: Vector3 = camara.global_position
	for nodo in get_tree().get_nodes_in_group("luces_lod"):
		var foco: OmniLight3D = nodo as OmniLight3D
		if foco == null:
			continue
		var cerca: bool = foco.global_position.distance_to(ojo) < foco.omni_range + DISTANCIA_LUCES
		var encendida: bool = foco.light_energy > 0.01 or not foco.is_in_group("luces_noche")
		foco.visible = cerca and encendida


func actualizar() -> void:
	# Ángulo del sol: sale a las 6:00, está arriba a las 13:00 y se pone a las 20:00
	# (14 horas de luz). Así la noche del cielo coincide con la del juego
	# (Juego.es_de_noche): antes a las 18:00 ya estaba oscuro y los guardias
	# no salían hasta las 20:00.
	var h: float = fposmod(Juego.hora, 24.0)
	var t: float
	if h >= 6.0 and h < 20.0:
		t = (h - 6.0) / 14.0 * PI
	else:
		t = PI + fposmod(h - 20.0, 24.0) / 10.0 * PI
	var altura: float = sin(t)                         # 1 = mediodía, -1 = medianoche.
	var dia: float = smoothstep(-0.15, 0.25, altura)    # 0 = noche, 1 = día.

	_sol.rotation = Vector3(-t, deg_to_rad(30), 0)
	_sol.light_energy = 0.85 * dia   # (Con 1.1 las fachadas claras salían quemadas en blanco.)
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
	_ambiente.ambient_light_energy = lerpf(0.35, 0.6, dia)
	_ambiente.fog_light_color = NIEBLA_NOCHE.lerp(NIEBLA_DIA, dia)
	_ambiente.fog_density = lerpf(0.03, 0.004, dia)   # De día casi sin niebla: lo lejano no se ve lavado.

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
