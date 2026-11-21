# objeto_suelo.gd
# -----------------------------------------------------------------------------
# Un objeto del inventario tirado en el suelo (lo crea el panel de administrador).
# Pulsa E para cogerlo.
# -----------------------------------------------------------------------------
class_name ObjetoSuelo
extends Interactuable

const DatosObjetos = preload("res://scripts/datos/objetos.gd")

var id: String = ""
var cantidad: int = 1


# Lo deja delante del jugador (cada "fila" lo aleja medio metro para que no se amontonen).
static func crear(jugador: Node3D, id_objeto: String, n: int, fila: int = 0) -> ObjetoSuelo:
	var o: ObjetoSuelo = ObjetoSuelo.new()
	o.id = id_objeto
	o.cantidad = n
	jugador.get_parent().add_child(o)
	o.global_position = AdminCatalogo.punto_delante(jugador, 1.2 + 0.5 * fila) + Vector3(0, 0.15, 0)
	return o


func _ready() -> void:
	var d: Dictionary = DatosObjetos.datos(id)
	var color: Color = d.get("color", Color(0.7, 0.7, 0.7))
	var caja: MeshInstance3D = MeshInstance3D.new()
	var malla: BoxMesh = BoxMesh.new()
	malla.size = Vector3(0.3, 0.2, 0.3)
	caja.mesh = malla
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	caja.material_override = mat
	add_child(caja)
	var etiqueta: Label3D = Label3D.new()
	etiqueta.text = "%s%s" % [d["nombre"], "" if cantidad == 1 else " x%d" % cantidad]
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.pixel_size = 0.004
	etiqueta.no_depth_test = true
	etiqueta.position.y = 0.4
	add_child(etiqueta)


func texto_accion() -> String:
	return "Coger %s" % DatosObjetos.nombre(id)


func usar(_jugador: Node) -> void:
	var sobra: int = Juego.anadir(id, cantidad)
	if sobra == 0:
		Juego.avisar("Coges %d x %s." % [cantidad, DatosObjetos.nombre(id)])
		queue_free()
	else:
		cantidad = sobra
		Juego.avisar("No cabe todo; quedan %d en el suelo." % sobra)
