# puerta_mundo.gd
# -----------------------------------------------------------------------------
# La puerta de una casa del mundo grande: una hoja que gira sobre su bisagra al
# pulsar E (se abre hacia dentro). La crea GestorInteriores al acercarte a la casa.
#   - Casas normales: se abren y se cierran libremente.
#   - Casas en alquiler o venta: cerradas con llave hasta que las alquilas o las compras
#     (entonces se abren con E desde la propia puerta, ver PropiedadMundo).
# El choque de la hoja solo existe cuando el interior de la casa está cargado.
# -----------------------------------------------------------------------------
class_name PuertaMundo
extends Interactuable

const ANCHO: float = 1.2
const ALTO: float = 2.05

static var _malla: BoxMesh = null
static var _mat: Dictionary = {}

var id_casa: String = ""
var cara: float = 1.0
var abierta: bool = false
var _bisagra: Node3D
var _cuerpo: StaticBody3D = null
var _tween: Tween = null


func _ready() -> void:
	distancia = 2.2
	add_to_group("puertas_casa")


# Prepara la hoja (color según la casa). Se llama justo después de crearla.
func montar(color: Color) -> void:
	if _malla == null:
		_malla = BoxMesh.new()
		_malla.size = Vector3(ANCHO, ALTO, 0.07)
	var clave: String = color.to_html()
	if not _mat.has(clave):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		_mat[clave] = m
	_bisagra = Node3D.new()
	_bisagra.position = Vector3(-ANCHO / 2.0, 0.0, 0.0)
	add_child(_bisagra)
	var hoja: MeshInstance3D = MeshInstance3D.new()
	hoja.mesh = _malla
	hoja.material_override = _mat[clave]
	hoja.position = Vector3(ANCHO / 2.0, ALTO / 2.0, 0.0)
	hoja.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bisagra.add_child(hoja)
	var pomo: MeshInstance3D = MeshInstance3D.new()
	var esf: SphereMesh = SphereMesh.new()
	esf.radius = 0.05
	esf.height = 0.1
	pomo.mesh = esf
	pomo.position = Vector3(ANCHO - 0.12, 1.0, 0.07 * cara)
	pomo.material_override = _mat_pomo()
	_bisagra.add_child(pomo)


static func _mat_pomo() -> StandardMaterial3D:
	if not _mat.has("pomo"):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(0.8, 0.7, 0.3)
		m.metallic = 0.4
		_mat["pomo"] = m
	return _mat["pomo"]


func con_choque(si: bool) -> void:
	if si and _cuerpo == null:
		_cuerpo = StaticBody3D.new()
		var cs: CollisionShape3D = CollisionShape3D.new()
		var caja: BoxShape3D = BoxShape3D.new()
		caja.size = Vector3(ANCHO, ALTO, 0.1)
		cs.shape = caja
		cs.position = Vector3(ANCHO / 2.0, ALTO / 2.0, 0.0)
		_cuerpo.add_child(cs)
		_bisagra.add_child(_cuerpo)
	elif not si and _cuerpo != null:
		_cuerpo.queue_free()
		_cuerpo = null


func _bloqueada() -> bool:
	return id_casa != "" and not Juego.viviendas.has(id_casa)


func texto_accion() -> String:
	if _bloqueada():
		return "Cerrada con llave (alquílala o cómprala para entrar)"
	return "Cerrar la puerta" if abierta else "Abrir la puerta"


func usar(_jugador: Node) -> void:
	if _bloqueada():
		Juego.avisar("La puerta está cerrada con llave. Alquila o compra la casa para entrar.")
		return
	alternar()


func alternar() -> void:
	poner_abierta(not abierta)


func poner_abierta(si: bool, animar: bool = true) -> void:
	abierta = si
	var giro: float = 90.0 * cara if si else 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animar or not is_inside_tree():
		_bisagra.rotation_degrees.y = giro
		return
	_tween = create_tween()
	_tween.tween_property(_bisagra, "rotation_degrees:y", giro, 0.3)
