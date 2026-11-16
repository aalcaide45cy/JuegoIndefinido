# caldero_3d.gd
# -----------------------------------------------------------------------------
# El caldero de tu casa. Pulsa E y se abre su ventana (Ventanas.Caldero):
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
	Construir.cilindro(self, Vector3(0, 0.5, 0), 0.55, 0.7, Color(0.08, 0.08, 0.09), true, 0.0, 0.62)
	Construir.cilindro(self, Vector3(0, 0.87, 0), 0.66, 0.06, Color(0.12, 0.12, 0.13))
	_liquido = Construir.cilindro(self, Vector3(0, 0.86, 0), 0.58, 0.03, Color(0.25, 0.35, 0.45), false, 1.5)
	_material_liquido = (_liquido as MeshInstance3D).mesh.material
	# Brasas debajo y su luz verdosa.
	for i in 3:
		var brasa: Node3D = Construir.caja(self, Vector3.ZERO, Vector3(0.25, 0.08, 0.08),
				Color(0.35, 0.9, 0.5), false, 3.0)
		brasa.rotation.y = i * PI / 3.0
		brasa.position = Vector3(0, 0.05, 0)
	_fuego = Construir.luz(self, Vector3(0, 1.3, 0), Color(0.4, 1.0, 0.55), 1.5, 6.0)
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
