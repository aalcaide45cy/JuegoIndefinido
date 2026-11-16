# maceta_3d.gd
# -----------------------------------------------------------------------------
# Una maceta de la herboristería. Igual que en el prototipo 2D tiene tres
# estados: VACIA -> CRECIENDO -> LISTA.
#   - Vacía: E planta la hierba que tienes en la mano (Q para cambiarla).
#   - Lista: E la cosecha y la guarda en tu inventario.
# -----------------------------------------------------------------------------
class_name Maceta3D
extends Interactuable

enum Estado { VACIA, CRECIENDO, LISTA }

var estado: Estado = Estado.VACIA
var tipo_hierba: String = ""
var progreso: float = 0.0   # De 0.0 (recién plantada) a 1.0 (lista).

var _planta: Node3D = null              # La planta que crece (se escala).
var _materiales_planta: Array[StandardMaterial3D] = []


func _ready() -> void:
	# Maceta de barro con tierra encima.
	Construir.cilindro(self, Vector3(0, 0.15, 0), 0.2, 0.3, Color(0.45, 0.25, 0.18), false, 0.0, 0.25)
	Construir.cilindro(self, Vector3(0, 0.29, 0), 0.22, 0.03, Color(0.15, 0.1, 0.08))


func _process(delta: float) -> void:
	if estado == Estado.CRECIENDO:
		progreso += delta / GameData.HIERBAS[tipo_hierba]["tiempo"]
		if progreso >= 1.0:
			progreso = 1.0
			estado = Estado.LISTA
		_planta.scale = Vector3.ONE * lerpf(0.15, 1.0, progreso)
	elif estado == Estado.LISTA:
		# La planta lista brilla un poco, como respirando.
		var pulso: float = 0.6 + 0.5 * sin(Time.get_ticks_msec() / 300.0)
		for mat in _materiales_planta:
			mat.emission_energy_multiplier = pulso


func texto_accion() -> String:
	match estado:
		Estado.VACIA:
			var datos: Dictionary = GameData.HIERBAS[Juego.hierba_seleccionada()]
			return "Plantar %s (%d monedas)" % [datos["nombre"], datos["precio_semilla"]]
		Estado.CRECIENDO:
			return "%s creciendo... %d%%" % [GameData.HIERBAS[tipo_hierba]["nombre"], int(progreso * 100)]
		_:
			return "Cosechar %s" % GameData.HIERBAS[tipo_hierba]["nombre"]


func usar(_jugador: Node) -> void:
	match estado:
		Estado.VACIA:
			var id_hierba: String = Juego.hierba_seleccionada()
			var precio: int = GameData.HIERBAS[id_hierba]["precio_semilla"]
			if not Juego.gastar(precio):
				Juego.avisar("No tienes monedas para esa semilla (cuesta %d)." % precio)
				return
			_plantar(id_hierba)
			Juego.avisar("Has plantado %s." % GameData.HIERBAS[id_hierba]["nombre"])
		Estado.CRECIENDO:
			Juego.avisar("Todavía está creciendo. Paciencia...")
		Estado.LISTA:
			Juego.hierbas[tipo_hierba] += 1
			Juego.avisar("Has cosechado 1 %s." % GameData.HIERBAS[tipo_hierba]["nombre"])
			_vaciar()
			Juego.cambio.emit()


func _plantar(id_hierba: String) -> void:
	tipo_hierba = id_hierba
	progreso = 0.0
	estado = Estado.CRECIENDO
	_planta = Node3D.new()
	_planta.position.y = 0.3
	_planta.scale = Vector3.ONE * 0.15
	add_child(_planta)
	var color: Color = GameData.HIERBAS[id_hierba]["color"]
	if GameData.HIERBAS[id_hierba]["forma"] == "seta":
		# Hongo: un tallo pálido y un sombrero aplastado.
		Construir.cilindro(_planta, Vector3(0, 0.12, 0), 0.04, 0.24, Color(0.85, 0.82, 0.75), false, 0.3)
		Construir.esfera(_planta, Vector3(0, 0.26, 0), 0.15, color, Vector3(1, 0.5, 1), 0.3)
	else:
		# Hoja de Bruma: un tallo y hojas alargadas en abanico.
		Construir.cilindro(_planta, Vector3(0, 0.2, 0), 0.015, 0.4, color.darkened(0.3), false, 0.3)
		for i in 7:
			var hoja: Node3D = Construir.caja(_planta, Vector3.ZERO, Vector3(0.05, 0.3, 0.01), color, false, 0.3)
			hoja.rotation = Vector3(0.0, i * TAU / 7.0, 0.7)
			hoja.position = Vector3(0, 0.3, 0) + hoja.basis * Vector3(0, 0.15, 0)
	for hijo in _planta.get_children():
		var malla: MeshInstance3D = hijo as MeshInstance3D
		_materiales_planta.append(malla.mesh.material)


func _vaciar() -> void:
	tipo_hierba = ""
	progreso = 0.0
	estado = Estado.VACIA
	_materiales_planta.clear()
	if _planta != null:
		_planta.queue_free()
		_planta = null
