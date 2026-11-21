# barra_vida.gd
# -----------------------------------------------------------------------------
# Barra de vida flotante sobre la cabeza de un NPC (guardia, peatón, matón).
# Se crea la primera vez que el NPC recibe daño y se oculta unos segundos
# después de la última herida. Siempre mira a la cámara (billboard).
# Colores por bando: verde neutral, rojo enemigo, azul ley, naranja banda.
# Va bajo un nodo con script (esta clase), así que la fusión de mallas no la toca.
# -----------------------------------------------------------------------------
class_name BarraVida
extends Node3D

const ANCHO: float = 0.9
const ALTO: float = 0.1
const VISIBLE_TRAS_DANO: float = 6.0

const COLORES: Dictionary = {
	"neutral": Color(0.35, 0.8, 0.35),
	"enemigo": Color(0.85, 0.2, 0.2),
	"ley": Color(0.3, 0.5, 0.95),
	"banda": Color(0.95, 0.55, 0.15),
}

var _relleno: MeshInstance3D
var _t: float = 0.0
var _fraccion: float = 1.0


# Pone una barra sobre "padre" (a "altura" metros del suelo) o devuelve la que ya tiene.
static func de(padre: Node3D, altura: float = 2.2, bando: String = "neutral") -> BarraVida:
	var existente: Node = padre.get_node_or_null("BarraVida")
	if existente != null:
		return existente as BarraVida
	var b: BarraVida = BarraVida.new()
	b.name = "BarraVida"
	b.position = Vector3(0, altura, 0)
	b._construir(COLORES.get(bando, COLORES["neutral"]))
	padre.add_child(b)
	return b


func _construir(color: Color) -> void:
	var fondo: MeshInstance3D = MeshInstance3D.new()
	var qf: QuadMesh = QuadMesh.new()
	qf.size = Vector2(ANCHO + 0.06, ALTO + 0.05)
	qf.material = _material(Color(0.04, 0.04, 0.04, 0.85))
	fondo.mesh = qf
	add_child(fondo)
	_relleno = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(ANCHO, ALTO)
	q.center_offset = Vector3(ANCHO / 2.0, 0, 0)   # Crece desde la izquierda.
	q.material = _material(color)
	_relleno.mesh = q
	_relleno.position = Vector3(-ANCHO / 2.0, 0, 0.004)
	add_child(_relleno)
	visible = false


func _material(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


# Muestra la barra con la vida actual (0-1) y empieza la cuenta atrás para ocultarla.
func mostrar(fraccion: float) -> void:
	_fraccion = clampf(fraccion, 0.0, 1.0)
	_relleno.scale.x = maxf(_fraccion, 0.001)
	visible = _fraccion > 0.0
	_t = VISIBLE_TRAS_DANO
	set_process(true)


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		visible = false
		set_process(false)
