# caldero_3d.gd
# -----------------------------------------------------------------------------
# El caldero de tu casa. Pulsa E y se abre su ventana (Ventanas.VentanaCaldero):
# eliges una receta, arrastras las hierbas a las casillas y preparas. Si la
# mezcla no coincide con ninguna receta, sale un bodrio y se pierde.
# -----------------------------------------------------------------------------
class_name Caldero3D
extends Interactuable

var ingredientes: Array[String] = []

var _liquido: Node3D
var _material_liquido: StandardMaterial3D
var _fuego: OmniLight3D


func _ready() -> void:
	distancia = 2.0
	# Cuerpo negro, borde y patas. El cuerpo es sólido para no atravesarlo.
	var cuerpo: Node3D = Construir.cilindro(self, Vector3(0, 0.5, 0), 0.55, 0.7, Color(0.08, 0.08, 0.09), true, 0.0, 0.62)
	var borde: Node3D = Construir.cilindro(self, Vector3(0, 0.87, 0), 0.66, 0.06, Color(0.12, 0.12, 0.13))
	# Con el modelo del paquete "Fantasy Props", el caldero de cajas queda solo de choque.
	if Assets.existe("quaternius/fantasy-props-megakit/Cauldron"):
		Construir.ocultar_mallas(cuerpo)
		borde.visible = false
		Assets.colocar_solido(self, "quaternius/fantasy-props-megakit/Cauldron", Vector3.ZERO, 0.0,
				Vector3.ONE * 1.15, false)
	_liquido = Construir.cilindro(self, Vector3(0, 0.86, 0), 0.58, 0.03, Color(0.25, 0.35, 0.45), false, 1.5)
	_material_liquido = Construir.material_propio(_liquido)   # Propio: cambia de color.
	# Brasas debajo y su luz verdosa.
	for i in 3:
		var brasa: Node3D = Construir.caja(self, Vector3.ZERO, Vector3(0.25, 0.08, 0.08),
				Color(0.35, 0.9, 0.5), false, 3.0)
		brasa.rotation.y = i * PI / 3.0
		brasa.position = Vector3(0, 0.05, 0)
	_fuego = Construir.luz(self, Vector3(0, 1.3, 0), Color(0.4, 1.0, 0.55), 1.5, 6.0)
	# Humo verdoso que sube del caldero.
	var humo: CPUParticles3D = CPUParticles3D.new()
	humo.position = Vector3(0, 0.95, 0)
	humo.amount = 16
	humo.lifetime = 2.2
	humo.direction = Vector3.UP
	humo.spread = 14.0
	humo.gravity = Vector3.ZERO
	humo.initial_velocity_min = 0.25
	humo.initial_velocity_max = 0.5
	humo.scale_amount_min = 0.6
	humo.scale_amount_max = 1.6
	var bola: SphereMesh = SphereMesh.new()
	bola.radius = 0.06
	bola.height = 0.12
	var mat_humo: StandardMaterial3D = Construir.material(Color(0.4, 0.9, 0.55, 0.35), 0.8)
	mat_humo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bola.material = mat_humo
	humo.mesh = bola
	add_child(humo)
	_actualizar_color()


func _process(_delta: float) -> void:
	# El fuego tiembla y el líquido burbujea un poco.
	var t: float = Time.get_ticks_msec() / 1000.0
	_fuego.light_energy = 1.4 + 0.3 * sin(t * 7.0) + 0.2 * sin(t * 13.0)
	_liquido.position.y = 0.86 + 0.01 * sin(t * 3.0)


func texto_accion() -> String:
	return "Usar el caldero (preparar pociones)"


func usar(jugador: Node) -> void:
	jugador.hud.abrir_caldero()


# El líquido toma la mezcla de colores de lo que hay dentro.
func _actualizar_color() -> void:
	var color: Color = Color(0.2, 0.3, 0.4)  # Agua sola.
	if not ingredientes.is_empty():
		color = Color(0, 0, 0)
		for id_hierba in ingredientes:
			color += GameData.HIERBAS[id_hierba]["color"]
		color /= float(ingredientes.size())
		color.a = 1.0
	_material_liquido.albedo_color = color
	_material_liquido.emission = color
