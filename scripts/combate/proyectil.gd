# proyectil.gd
# -----------------------------------------------------------------------------
# Una granada o un cohete: una bolita con física que explota cuando se acaba la
# mecha o, si "al_chocar" es true, en cuanto toca algo.
# -----------------------------------------------------------------------------
class_name Proyectil
extends RigidBody3D

var mecha: float = 2.5
var al_chocar: bool = false
var radio: float = 6.0
var dano: float = 100.0
var color: Color = Color(0.25, 0.32, 0.2)
var tam: float = 0.08

var _explotada: bool = false
var _tiempo: float = 0.0


func _ready() -> void:
	var forma: CollisionShape3D = CollisionShape3D.new()
	var esfera: SphereShape3D = SphereShape3D.new()
	esfera.radius = tam
	forma.shape = esfera
	add_child(forma)
	var malla: MeshInstance3D = MeshInstance3D.new()
	var visual: SphereMesh = SphereMesh.new()
	visual.radius = tam
	visual.height = tam * 2.0
	visual.material = Construir.material(color)
	malla.mesh = visual
	add_child(malla)
	contact_monitor = true
	max_contacts_reported = 2
	if al_chocar:
		body_entered.connect(func(_cuerpo: Node) -> void:
			if _tiempo > 0.05:
				_explotar())


func _physics_process(delta: float) -> void:
	_tiempo += delta
	if _tiempo >= mecha:
		_explotar()


func _explotar() -> void:
	if _explotada:
		return
	_explotada = true
	Combate.explosion(get_parent() as Node3D, global_position, radio, dano)
	queue_free()
