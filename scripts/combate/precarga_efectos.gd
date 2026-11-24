# precarga_efectos.gd
# -----------------------------------------------------------------------------
# Quita el "tirón" de la primera muerte. La primera vez que salía sangre el juego
# tenía que generar texturas y sonidos (bucles de miles de píxeles y muestras en
# GDScript) y compilar los shaders de cada material nuevo: eso congelaba la imagen
# un instante. Aquí se hace todo al arrancar, repartido en varios fotogramas:
#   1) genera texturas de manchas, fogonazo, gritos, crujidos y sonidos de armas;
#   2) dibuja una vez cada efecto (sangre, charco, neblina, chispas, humo, muñón,
#      casquillo...) escondido bajo el suelo, para que la tarjeta compile sus shaders;
#   3) carga la librería de animaciones de las personas.
# Lo lanza el jugador al aparecer: Precarga.iniciar(self).
# -----------------------------------------------------------------------------
class_name Precarga
extends Node

static var hecha: bool = false

var _pasos: Array = []
var _testigos: Array = []
var _jugador: Node3D


static func iniciar(jugador: Node3D) -> void:
	if hecha or jugador == null or not jugador.is_inside_tree():
		return
	hecha = true
	var p: Precarga = Precarga.new()
	p.name = "PrecargaEfectos"
	p._jugador = jugador
	jugador.get_tree().root.add_child.call_deferred(p)


func _ready() -> void:
	# Un paso por fotograma: así ninguno tarda tanto como para notarse.
	_pasos = [
		func() -> void: Gore.salpicar_preparar(),
		func() -> void: Gore._texturas_mancha.append(Gore._textura_mancha(0)),
		func() -> void: Gore._texturas_mancha.append(Gore._textura_mancha(1)),
		func() -> void: Gore._texturas_mancha.append(Gore._textura_mancha(2)),
		func() -> void: Gore._texturas_mancha.append(Gore._textura_mancha(3)),
		func() -> void: _gritos(0),
		func() -> void: _gritos(1),
		func() -> void: _gritos(2),
		func() -> void: _crujidos(),
		func() -> void: EfectosArma._tex_fogonazo = EfectosArma._textura_fogonazo() if EfectosArma._tex_fogonazo == null else EfectosArma._tex_fogonazo,
		func() -> void: _sonidos(["disparo_pistola", "disparo_escopeta"]),
		func() -> void: _sonidos(["disparo_rifle", "disparo_francotirador", "disparo_lanzagranadas"]),
		func() -> void: _sonidos(["impacto_metal", "casquillo", "casquillo_escopeta", "rebote", "impacto_madera", "impacto_tierra", "impacto_piedra"]),
		func() -> void: _persona(),
		func() -> void: _shaders(),
		func() -> void: pass,
		func() -> void: pass,
		func() -> void: _limpiar(),
	]


func _process(_delta: float) -> void:
	if _pasos.is_empty():
		queue_free()
		return
	var paso: Callable = _pasos.pop_front()
	paso.call()


# Carga la librería de animaciones de las personas (y suelta el muñeco de prueba).
func _persona() -> void:
	var n: Node3D = Assets.persona()
	if n != null:
		n.free()


func _gritos(i: int) -> void:
	if Gore._gritos.size() == i:
		Gore._gritos.append(Gore._generar_grito([520.0, 300.0, 380.0][i]))


func _crujidos() -> void:
	for clave in ["crujido", "crujido_fuerte"]:
		if not Gore._sonidos.has(clave):
			Gore._sonidos[clave] = Gore._generar_crujido(clave == "crujido_fuerte")


func _sonidos(claves: Array) -> void:
	for c in claves:
		EfectosArma._flujo(c)


# Dibuja cada efecto una vez, 4 m por debajo de lo que mira la cámara (tapado por el
# suelo pero dentro del encuadre: la tarjeta lo dibuja y compila sus shaders).
func _shaders() -> void:
	if not is_instance_valid(_jugador) or not _jugador.is_inside_tree():
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var p: Vector3 = cam.global_position - cam.global_basis.z * 6.0 + Vector3.DOWN * 4.0
	var escena: Node = _jugador.get_parent()
	var antes: Array = escena.get_children()
	var nivel_antes: int = int(Graficos.v.get("gore", 2))
	Graficos.v["gore"] = 2
	Gore.salpicar(_jugador, p, Vector3.UP, 1.0)
	Gore.mancha(_jugador, p, Vector3.UP, 0.3)
	Gore.charco(_jugador, p + Vector3.UP * 0.5, 0.4)
	Gore.niebla(_jugador, p, 0.3)
	Gore.trozos(_jugador, p, 1, Vector3.UP, true)
	Graficos.v["gore"] = nivel_antes
	var chorro: CPUParticles3D = Gore.chorro()
	escena.add_child(chorro)
	chorro.global_position = p
	chorro.emitting = true
	_testigos.append(chorro)
	var munon: MeshInstance3D = MeshInstance3D.new()
	var esf: SphereMesh = SphereMesh.new()
	esf.material = Cuerpo._material_munon()
	munon.mesh = esf
	escena.add_child(munon)
	munon.global_position = p
	_testigos.append(munon)
	EfectosArma.chispas(_jugador, p, Vector3.UP, 2)
	EfectosArma.lascas(_jugador, p, Vector3.UP, Color.GRAY, 2)
	EfectosArma.humo(_jugador, p, Vector3.UP, 0.5)
	EfectosArma.trazadora(_jugador, p, p + Vector3(0, 0, 4))
	_boca_muda(p)
	for h in escena.get_children():
		if not antes.has(h):
			_testigos.append(h)


# El fogonazo sin su luz ni sonido (solo para compilar el material).
func _boca_muda(p: Vector3) -> void:
	EfectosArma.boca(_jugador, p, Vector3.FORWARD, "pistola")


func _limpiar() -> void:
	for t in _testigos:
		if is_instance_valid(t) and t is Node and not (t as Node).is_queued_for_deletion():
			(t as Node).queue_free()
	_testigos.clear()
	Gore._charcos.clear()
	Gore._manchas.clear()
	Gore._trozos.clear()
