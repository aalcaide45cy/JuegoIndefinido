# efectos_vehiculo.gd
# -----------------------------------------------------------------------------
# Todo lo que se VE de un vehículo además del modelo:
#   - Faros (luz de verdad de noche + cristal que brilla), luces de freno rojas que
#     se encienden al frenar, luces blancas de marcha atrás, intermitentes.
#   - Humo blanco de las ruedas que patinan y marcas negras en el suelo.
#   - Chispas al rozar o chocar, trozos de cristal en los golpes fuertes.
#   - Humo del motor cuando está muy dañado (gris, luego negro) y fuego al final.
# Lo usan el coche del jugador (Vehiculo) y, con menos cosas, el tráfico.
# -----------------------------------------------------------------------------
class_name EfectosVehiculo
extends Node3D

const COLOR_FRENO: Color = Color(1.0, 0.05, 0.03)
const COLOR_FARO: Color = Color(1.0, 0.95, 0.8)
const COLOR_INTERMITENTE: Color = Color(1.0, 0.55, 0.05)

static var _mat_humo: StandardMaterial3D = null
static var _mat_chispa: StandardMaterial3D = null
static var _mat_cristal: StandardMaterial3D = null
static var _mat_humo_negro: StandardMaterial3D = null

var caja: AABB = AABB(Vector3(-1, 0, -2.2), Vector3(2, 1.5, 4.4))   # Tamaño de la carrocería (local).
var con_luz_real: bool = true     # Faros con SpotLight3D (el tráfico solo lleva el brillo).

var _faros: Array = []            # MeshInstance3D (brillo)
var _frenos: Array = []
var _atras: Array = []
var _intermitentes: Array = [[], []]   # [izquierda, derecha]
var _luz_faro: SpotLight3D = null
var _mat_faro: StandardMaterial3D
var _mat_freno: StandardMaterial3D
var _mat_atras: StandardMaterial3D
var _mat_inter: Array = []
var _humos: Array = []            # CPUParticles3D por rueda
var _humo_motor: CPUParticles3D = null
var _t_inter: float = 0.0
var intermitente: int = 0         # 0 nada, 1 izquierda, -1 derecha, 2 las dos (emergencia)


static func _materiales() -> void:
	if _mat_humo != null:
		return
	_mat_humo = StandardMaterial3D.new()
	_mat_humo.albedo_color = Color(0.92, 0.92, 0.92, 0.45)
	_mat_humo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_humo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_humo.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat_humo.vertex_color_use_as_albedo = true
	_mat_humo_negro = _mat_humo.duplicate()
	_mat_humo_negro.albedo_color = Color(0.12, 0.12, 0.12, 0.6)
	_mat_chispa = StandardMaterial3D.new()
	_mat_chispa.albedo_color = Color(1.0, 0.7, 0.2)
	_mat_chispa.emission_enabled = true
	_mat_chispa.emission = Color(1.0, 0.55, 0.1)
	_mat_chispa.emission_energy_multiplier = 4.0
	_mat_chispa.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_cristal = StandardMaterial3D.new()
	_mat_cristal.albedo_color = Color(0.75, 0.9, 1.0, 0.8)
	_mat_cristal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cristal.metallic = 0.6
	_mat_cristal.roughness = 0.1


static func _brillo(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.55)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.0
	return m


# Monta las luces en las esquinas de la caja de la carrocería.
func montar(caja_carroceria: AABB, ruedas_pos: Array, tipo: String = "") -> void:
	_materiales()
	caja = caja_carroceria
	_mat_faro = _brillo(COLOR_FARO)
	_mat_freno = _brillo(COLOR_FRENO)
	_mat_atras = _brillo(Color(1, 1, 1))
	_mat_inter = [_brillo(COLOR_INTERMITENTE), _brillo(COLOR_INTERMITENTE)]
	var x_lado: float = caja.size.x * 0.5 - 0.22
	var y_luz: float = caja.position.y + caja.size.y * (0.42 if caja.size.y < 2.0 else 0.3)
	var z_frente: float = caja.position.z + 0.02
	var z_cola: float = caja.end.z - 0.02
	var cx: float = caja.get_center().x
	for lado in [-1.0, 1.0]:
		var x: float = cx + lado * x_lado
		_faros.append(_pastilla(Vector3(x, y_luz, z_frente), Vector3(0.36, 0.14, 0.05), _mat_faro))
		_frenos.append(_pastilla(Vector3(x, y_luz + 0.04, z_cola), Vector3(0.3, 0.12, 0.05), _mat_freno))
		_atras.append(_pastilla(Vector3(x - lado * 0.24, y_luz - 0.02, z_cola), Vector3(0.1, 0.08, 0.05), _mat_atras))
		var i: int = 0 if lado < 0.0 else 1
		_intermitentes[i].append(_pastilla(Vector3(cx + lado * (x_lado + 0.12), y_luz, z_frente + 0.02),
				Vector3(0.1, 0.1, 0.05), _mat_inter[i]))
		_intermitentes[i].append(_pastilla(Vector3(cx + lado * (x_lado + 0.12), y_luz + 0.04, z_cola - 0.02),
				Vector3(0.1, 0.1, 0.05), _mat_inter[i]))
	if con_luz_real:
		_luz_faro = SpotLight3D.new()
		_luz_faro.position = Vector3(cx, y_luz, z_frente - 0.2)
		_luz_faro.spot_range = 45.0
		_luz_faro.spot_angle = 32.0
		_luz_faro.spot_attenuation = 0.7
		_luz_faro.light_energy = 4.0
		_luz_faro.light_color = COLOR_FARO
		_luz_faro.rotation.x = -0.06
		_luz_faro.visible = false
		add_child(_luz_faro)
		# Humo de cada rueda (se crea apagado).
		for p in ruedas_pos:
			var h: CPUParticles3D = _crear_humo(_mat_humo, 26, 1.6)
			h.position = (p as Vector3) + Vector3(0, -0.2, 0)
			add_child(h)
			_humos.append(h)


func _pastilla(pos: Vector3, tam: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = tam
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


static func _crear_humo(mat: Material, cantidad: int, vida: float) -> CPUParticles3D:
	var h: CPUParticles3D = CPUParticles3D.new()
	h.emitting = false
	h.amount = cantidad
	h.lifetime = vida
	h.local_coords = false
	h.direction = Vector3(0, 1, 0)
	h.spread = 50.0
	h.initial_velocity_min = 0.6
	h.initial_velocity_max = 1.8
	h.gravity = Vector3(0, 0.6, 0)
	h.damping_min = 0.5
	h.damping_max = 1.2
	h.scale_amount_min = 0.7
	h.scale_amount_max = 1.6
	var curva: Curve = Curve.new()
	curva.add_point(Vector2(0, 0.4))
	curva.add_point(Vector2(0.4, 1.0))
	curva.add_point(Vector2(1, 1.6))
	h.scale_amount_curve = curva
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.75))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	h.color_ramp = grad
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.material = mat
	h.mesh = q
	return h


# Lo llama el vehículo cada fotograma.
#   frenando, atras: luces · noche: faros · deslices: deslizamiento por rueda (m/s)
func actualizar(delta: float, frenando: bool, atras: bool, noche: bool, deslices: Array, salud: float) -> void:
	_mat_freno.emission_energy_multiplier = 4.0 if frenando else (0.9 if noche else 0.0)
	_mat_atras.emission_energy_multiplier = 2.5 if atras else 0.0
	_mat_faro.emission_energy_multiplier = 3.0 if noche else 0.25
	if _luz_faro != null:
		_luz_faro.visible = noche
	_t_inter += delta
	var on: bool = fmod(_t_inter, 0.8) < 0.4
	for i in 2:
		var activo: bool = intermitente == 2 or (intermitente == 1 and i == 0) or (intermitente == -1 and i == 1)
		(_mat_inter[i] as StandardMaterial3D).emission_energy_multiplier = 3.5 if (activo and on) else 0.0
	for i in mini(_humos.size(), deslices.size()):
		var h: CPUParticles3D = _humos[i]
		var d: float = float(deslices[i])
		var sale: bool = d > 4.5
		if h.emitting != sale:
			h.emitting = sale
		if sale:
			h.initial_velocity_max = 1.2 + d * 0.08
	_humo_del_motor(salud)


func _humo_del_motor(salud: float) -> void:
	if salud >= 35.0:
		if _humo_motor != null:
			_humo_motor.emitting = false
		return
	if _humo_motor == null:
		_humo_motor = _crear_humo(_mat_humo, 18, 2.2)
		_humo_motor.position = Vector3(caja.get_center().x, caja.end.y - caja.size.y * 0.25, caja.position.z + caja.size.z * 0.18)
		_humo_motor.spread = 20.0
		add_child(_humo_motor)
	_humo_motor.emitting = true
	var negro: bool = salud < 15.0
	(_humo_motor.mesh as QuadMesh).material = _mat_humo_negro if negro else _mat_humo
	_humo_motor.amount = 30 if negro else 18


# Explosión pequeña de partículas que se borra sola (chispas, cristales).
static func estallido(padre: Node, punto: Vector3, normal: Vector3, clase: String, fuerza: float) -> void:
	if padre == null or not padre.is_inside_tree():
		return
	_materiales()
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.direction = normal
	var malla: Mesh
	if clase == "cristal":
		p.amount = clampi(int(fuerza * 3.0), 12, 60)
		p.lifetime = 1.4
		p.spread = 70.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 4.0 + fuerza * 0.2
		p.gravity = Vector3(0, -9.8, 0)
		p.angular_velocity_min = -400.0
		p.angular_velocity_max = 400.0
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.2
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.06, 0.01, 0.05)
		bm.material = _mat_cristal
		malla = bm
	else:
		p.amount = clampi(int(fuerza * 4.0), 10, 70)
		p.lifetime = 0.5
		p.spread = 55.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 7.0 + fuerza * 0.3
		p.gravity = Vector3(0, -9.8, 0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.0
		var bm2: BoxMesh = BoxMesh.new()
		bm2.size = Vector3(0.025, 0.16, 0.025)
		bm2.material = _mat_chispa
		malla = bm2
		p.particle_flag_align_y = true
	p.mesh = malla
	padre.get_tree().current_scene.add_child(p)
	p.global_position = punto
	p.emitting = true
	p.finished.connect(p.queue_free)
