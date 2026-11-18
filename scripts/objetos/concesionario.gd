# concesionario.gd
# -----------------------------------------------------------------------------
# El concesionario: un quiosco donde E abre la lista de vehículos a la venta.
# Lo que compras aparece en la plaza de entrega (marcada con un cuadro amarillo
# en el suelo). SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name Concesionario
extends Interactuable

# Dónde aparece lo comprado (coordenadas locales del quiosco) y hacia dónde mira.
var entrega: Vector3 = Vector3(0, 0.05, -10.0)
var giro_entrega: float = 0.0
var categorias: Array = []   # Vacío = vende de todo (ver Vehiculo.TIPOS, campo "cat").


func _ready() -> void:
	distancia = 2.8
	Construir.caja(self, Vector3(0, 1.25, 0), Vector3(3.0, 2.5, 2.4), Color(0.35, 0.12, 0.1), true)
	Construir.caja(self, Vector3(0, 2.7, 0), Vector3(3.4, 0.3, 2.8), Color(0.15, 0.06, 0.05), false)
	Construir.caja(self, Vector3(0, 1.1, 1.22), Vector3(1.4, 1.2, 0.06), Color(0.05, 0.05, 0.08), false)
	var t: Label3D = Construir.texto(self, Vector3(0, 3.3, 1.3), "CONCESIONARIO", 72, Color(1.0, 0.75, 0.5))
	t.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	Construir.caja(self, entrega + Vector3(0, -0.03, 0), Vector3(6.0, 0.02, 9.0), Color(0.8, 0.65, 0.1), false, 0.4)


func texto_accion() -> String:
	return "Concesionario: comprar y vender vehículos"


func usar(jugador: Node) -> void:
	var v: VentanaConcesionario = VentanaConcesionario.new()
	v.punto = to_global(entrega)
	v.giro = global_rotation.y + giro_entrega
	v.categorias = categorias
	jugador.hud.abrir_ventana(v)
