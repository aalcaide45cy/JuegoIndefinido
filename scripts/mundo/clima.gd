# clima.gd
# -----------------------------------------------------------------------------
# El tiempo atmosférico: despejado, nublado, lluvia, tormenta y niebla.
# Cambia solo cada pocas horas de juego y las transiciones son suaves.
#
# Efectos que se ven y se oyen:
#   - Cielo gris, luz más débil y niebla (se aplica desde ciclo_dia.gd).
#   - Lluvia que cae alrededor de la cámara (no dentro de los edificios).
#   - Relámpagos y truenos en la tormenta.
#   - Sonido de lluvia (lo mezcla musica.gd leyendo Clima.lluvia).
# Efectos en el juego:
#   - Los huertos crecen más deprisa con lluvia (Clima.crecimiento()).
#   - Los guardias te ven de más cerca con niebla y lluvia (Clima.sigilo()).
#   - La lluvia llena poco a poco las jarras y regaderas que llevas fuera.
#   - Con tormenta caminas algo más despacio (Clima.velocidad()).
# El panel de administrador (F1) permite forzar cualquier clima para probarlo.
# -----------------------------------------------------------------------------
class_name Clima
extends Node3D

const DatosObjetos = preload("res://scripts/datos/objetos.gd")

# Valores objetivo de cada clima: nubes (0-1), niebla (0-1), lluvia (0-1), viento (0-1).
const TIPOS: Dictionary = {
	"despejado": {"nombre": "Despejado", "nubes": 0.0, "niebla": 0.0, "lluvia": 0.0, "viento": 0.15},
	"nublado": {"nombre": "Nublado", "nubes": 0.6, "niebla": 0.05, "lluvia": 0.0, "viento": 0.35},
	"lluvia": {"nombre": "Lluvia", "nubes": 0.85, "niebla": 0.22, "lluvia": 0.6, "viento": 0.5},
	"tormenta": {"nombre": "Tormenta", "nubes": 1.0, "niebla": 0.32, "lluvia": 1.0, "viento": 1.0},
	"niebla": {"nombre": "Niebla", "nubes": 0.45, "niebla": 1.0, "lluvia": 0.0, "viento": 0.1},
}
# Qué clima puede venir después de cada uno (peso relativo).
const SIGUIENTE: Dictionary = {
	"despejado": {"despejado": 0.15, "nublado": 0.55, "niebla": 0.3},
	"nublado": {"despejado": 0.3, "lluvia": 0.4, "niebla": 0.1, "nublado": 0.2},
	"lluvia": {"nublado": 0.4, "tormenta": 0.25, "despejado": 0.1, "lluvia": 0.25},
	"tormenta": {"lluvia": 0.7, "nublado": 0.3},
	"niebla": {"despejado": 0.5, "nublado": 0.4, "lluvia": 0.1},
}
const SEGUNDOS_TRANSICION: float = 25.0   # Lo que tarda en cambiar el aspecto del cielo.

# Estado compartido (estático para que cualquier script pueda preguntar).
static var actual: String = "despejado"
static var restante: float = 6.0          # Horas de juego que le quedan a este clima.
static var nubes: float = 0.0             # Valores suavizados que se ven en pantalla.
static var niebla: float = 0.0
static var lluvia: float = 0.0
static var viento: float = 0.15
static var relampago: float = 0.0         # 1 = destello en este instante; baja solo.

var _ciclo: CicloDia
var _gotas_suaves: CPUParticles3D
var _gotas_fuertes: CPUParticles3D
var _rayo: DirectionalLight3D
var _t_aplicar: float = 0.0
var _t_rayo: float = 12.0
var _t_trueno: float = -1.0
var _t_recipientes: float = 0.0
var _avisado_recipientes: bool = false
var _previo: Array = [-1.0, -1.0, -1.0]


# ----------------------------- Consultas para el resto del juego -----------------------------

# Multiplicador del radio con el que los guardias te ven (1 = normal).
static func sigilo() -> float:
	return clampf(1.0 - 0.5 * niebla - 0.15 * lluvia, 0.4, 1.0)


# Multiplicador de la velocidad de crecimiento de los cultivos al aire libre.
static func crecimiento() -> float:
	return 1.0 + 0.5 * lluvia


# Multiplicador de la velocidad del jugador.
static func velocidad() -> float:
	return 1.0 - 0.1 * clampf((lluvia - 0.6) / 0.4, 0.0, 1.0)


static func nombre() -> String:
	return String(TIPOS[actual]["nombre"])


# Fuerza un clima (panel de administrador). "horas" = cuánto dura.
static func poner(id: String, horas: float = 6.0) -> void:
	if not TIPOS.has(id):
		return
	actual = id
	restante = horas


static func exportar() -> Dictionary:
	return {"id": actual, "rest": restante}


static func importar(d: Variant) -> void:
	if not d is Dictionary or not TIPOS.has(String(d.get("id", ""))):
		return
	actual = String(d["id"])
	restante = clampf(float(d.get("rest", 6.0)), 0.5, 24.0)
	# Al cargar una partida el cielo ya aparece así, sin transición.
	var t: Dictionary = TIPOS[actual]
	nubes = t["nubes"]
	niebla = t["niebla"]
	lluvia = t["lluvia"]
	viento = t["viento"]


# Lo llama ciclo_dia.gd al final de su cálculo: oscurece y nubla el cielo según el clima.
# "dia" va de 0 (noche) a 1 (día).
static func aplicar(amb: Environment, cielo: ProceduralSkyMaterial, sol: DirectionalLight3D,
		luna: DirectionalLight3D, dia: float) -> void:
	if nubes < 0.001 and niebla < 0.001:
		return
	var gris: Color = Color(0.04, 0.045, 0.06).lerp(Color(0.52, 0.56, 0.62), dia)
	cielo.sky_top_color = cielo.sky_top_color.lerp(gris, nubes * 0.85)
	cielo.sky_horizon_color = cielo.sky_horizon_color.lerp(gris.lightened(0.08), nubes * 0.8)
	cielo.ground_horizon_color = cielo.ground_horizon_color.lerp(gris.lightened(0.08), nubes * 0.8)
	cielo.energy_multiplier *= 1.0 - 0.3 * nubes
	sol.light_energy *= 1.0 - 0.65 * nubes
	luna.light_energy *= 1.0 - 0.6 * nubes
	amb.ambient_light_energy *= 1.0 - 0.12 * nubes
	var pesado: float = maxf(nubes * 0.6, niebla)
	amb.fog_light_color = amb.fog_light_color.lerp(gris.lightened(0.05), pesado * 0.7)
	amb.fog_density += niebla * lerpf(0.02, 0.035, dia)


# --------------------------------------- Nodo ---------------------------------------

func _ready() -> void:
	for hijo in get_parent().get_children():
		if hijo is CicloDia:
			_ciclo = hijo as CicloDia
	# Cada partida nueva empieza con tiempo despejado; al cargar se restaura (importar).
	actual = "despejado"
	restante = randf_range(4.0, 8.0)
	nubes = 0.0
	niebla = 0.0
	lluvia = 0.0
	viento = 0.15
	relampago = 0.0

	_rayo = DirectionalLight3D.new()
	_rayo.light_color = Color(0.8, 0.88, 1.0)
	_rayo.light_energy = 0.0
	_rayo.shadow_enabled = false
	_rayo.rotation = Vector3(deg_to_rad(-70), deg_to_rad(40), 0)
	_rayo.visible = false
	add_child(_rayo)
	_gotas_suaves = _crear_gotas(450, 0.5)
	_gotas_fuertes = _crear_gotas(900, 0.8)


func _crear_gotas(cantidad: int, opacidad: float) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = cantidad
	p.lifetime = 0.55
	p.preprocess = 0.55
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(13, 0.2, 13)
	p.position = Vector3(0, 9, 0)
	p.direction = Vector3(0, -1, 0)
	p.spread = 1.5
	p.initial_velocity_min = 19.0
	p.initial_velocity_max = 22.0
	p.gravity = Vector3.ZERO
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var malla: BoxMesh = BoxMesh.new()
	malla.size = Vector3(0.008, 0.55, 0.008)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.82, 0.95, opacidad)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	malla.material = mat
	p.mesh = malla
	add_child(p)
	return p


func _process(delta: float) -> void:
	# Cuándo cambia el clima (el reloj va al ritmo del tiempo de juego).
	restante -= delta * 24.0 / (maxf(1.0, Juego.duracion_dia_min) * 60.0) * Juego.velocidad_tiempo
	if restante <= 0.0:
		_elegir_siguiente()

	# Los valores se acercan suavemente a los del clima actual.
	var objetivo: Dictionary = TIPOS[actual]
	var paso: float = delta / SEGUNDOS_TRANSICION
	nubes = move_toward(nubes, float(objetivo["nubes"]), paso)
	niebla = move_toward(niebla, float(objetivo["niebla"]), paso)
	lluvia = move_toward(lluvia, float(objetivo["lluvia"]), paso)
	viento = move_toward(viento, float(objetivo["viento"]), paso)

	# Repinta el cielo solo cuando algo ha cambiado de verdad (y no más de 2 veces por segundo).
	_t_aplicar -= delta
	if _t_aplicar <= 0.0:
		_t_aplicar = 0.5
		var ahora: Array = [snappedf(nubes, 0.01), snappedf(niebla, 0.01), snappedf(relampago, 0.05)]
		if ahora != _previo and _ciclo != null:
			_previo = ahora
			_ciclo.actualizar()

	_actualizar_lluvia()
	_actualizar_rayos(delta)
	_llenar_recipientes(delta)


func _elegir_siguiente() -> void:
	var pesos: Dictionary = SIGUIENTE[actual].duplicate()
	# Al amanecer es más fácil que haya niebla.
	if pesos.has("niebla") and Juego.hora > 4.0 and Juego.hora < 9.0:
		pesos["niebla"] = float(pesos["niebla"]) * 2.5
	var total: float = 0.0
	for k in pesos:
		total += float(pesos[k])
	var tirada: float = randf() * total
	var elegido: String = actual
	for k in pesos:
		tirada -= float(pesos[k])
		if tirada <= 0.0:
			elegido = k
			break
	var anterior: String = actual
	actual = elegido
	restante = randf_range(3.0, 8.0)
	if actual != anterior:
		var avisos: Dictionary = {
			"despejado": "Despeja el cielo.", "nublado": "Se cubre el cielo de nubes.",
			"lluvia": "Empieza a llover.", "tormenta": "Se acerca una tormenta.",
			"niebla": "Cae una niebla espesa: los guardias te verán menos.",
		}
		Juego.avisar(String(avisos[actual]))
		_avisado_recipientes = false


func _actualizar_lluvia() -> void:
	var camara: Camera3D = get_viewport().get_camera_3d()
	var fuera: bool = Juego.interiores == 0
	# Las gotas siguen a la cámara. Dentro de un edificio no se ven.
	if camara != null:
		global_position = camara.global_position
	_gotas_suaves.emitting = fuera and lluvia > 0.08
	_gotas_fuertes.emitting = fuera and lluvia > 0.65
	# El viento inclina la lluvia.
	var inclinacion: Vector3 = Vector3(viento * 6.0, 0, viento * 2.0)
	_gotas_suaves.gravity = inclinacion
	_gotas_fuertes.gravity = inclinacion


func _actualizar_rayos(delta: float) -> void:
	relampago = maxf(0.0, relampago - delta * 3.0)
	_rayo.light_energy = 2.0 * relampago
	_rayo.visible = relampago > 0.02
	if actual == "tormenta" and lluvia > 0.5:
		_t_rayo -= delta
		if _t_rayo <= 0.0:
			_t_rayo = randf_range(7.0, 22.0)
			relampago = 1.0
			_t_aplicar = 0.0
			_t_trueno = randf_range(0.4, 3.0)   # El trueno llega después, según lo lejos que caiga.
			_rayo.rotation = Vector3(deg_to_rad(randf_range(-80.0, -55.0)), deg_to_rad(randf_range(0.0, 360.0)), 0)
	if _t_trueno >= 0.0:
		_t_trueno -= delta
		if _t_trueno < 0.0:
			Sonido.tocar(self, "trueno", -2.0 if Juego.interiores == 0 else -10.0)
			_t_trueno = -1.0


# La lluvia llena de a poco jarras y regaderas del inventario (solo si estás fuera).
func _llenar_recipientes(delta: float) -> void:
	_t_recipientes -= delta
	if _t_recipientes > 0.0 or lluvia < 0.3 or Juego.interiores > 0:
		return
	_t_recipientes = 2.0
	var cambio: bool = false
	for casilla in Juego.inventario:
		if casilla != null and casilla.has("agua"):
			var maximo: int = int(DatosObjetos.datos(casilla["id"])["agua_max"])
			if int(casilla["agua"]) < maximo:
				casilla["agua"] = int(casilla["agua"]) + 1
				cambio = true
	if cambio:
		Juego.cambio.emit()
		if not _avisado_recipientes:
			_avisado_recipientes = true
			Juego.avisar("La lluvia va llenando tus recipientes de agua.")
