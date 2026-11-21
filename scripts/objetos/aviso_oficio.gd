# aviso_oficio.gd
# -----------------------------------------------------------------------------
# Un AVISO de tu oficio por la calle: policía (altercado), médico (herido),
# bombero (fuego), mecánico (coche averiado) o peluquero/barbero (cliente). Tiene una columna de luz para
# verlo de lejos. Acércate y pulsa E varias veces ("golpes") para resolverlo;
# cobras el pago (por el rango) y ganas experiencia de oficio. Si tarda demasiado
# en atenderse, desaparece sin pago. Lo crea y borra gestor_oficio.gd.
# -----------------------------------------------------------------------------
class_name AvisoOficio
extends Interactuable

const Aspecto = preload("res://scripts/jugador/aspecto.gd")

signal resuelto
signal caducado

var oficio: String = ""
var datos: Dictionary = {}
var golpes: int = 1
var tiempo: float = 170.0
var _etiqueta: Label3D
var _llama: OmniLight3D = null
var _t: float = 0.0


func _ready() -> void:
	distancia = 3.2
	ignora_vista = true
	golpes = int(datos.get("golpes", 1))
	var tipo: String = str(datos.get("tipo", "altercado"))
	var col: Color = {"altercado": Color(0.3, 0.45, 1.0), "herido": Color(1.0, 0.3, 0.3),
			"fuego": Color(1.0, 0.55, 0.1), "averia": Color(1.0, 0.85, 0.2),
			"cliente": Color(0.85, 0.4, 0.9)}.get(tipo, Color(1, 1, 1))
	# Columna de luz translúcida.
	var haz: MeshInstance3D = MeshInstance3D.new()
	var cil: CylinderMesh = CylinderMesh.new()
	cil.top_radius = 0.5
	cil.bottom_radius = 0.7
	cil.height = 60.0
	haz.mesh = cil
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	haz.material_override = mat
	haz.position.y = 30.0
	haz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(haz)
	match tipo:
		"altercado":
			# Dos figuras discutiendo.
			Construir.cilindro(self, Vector3(-0.5, 0.8, 0), 0.28, 1.6, Color(0.25, 0.25, 0.3), false)
			Construir.esfera(self, Vector3(-0.5, 1.75, 0), 0.2, Color(0.8, 0.65, 0.55))
			Construir.cilindro(self, Vector3(0.5, 0.8, 0), 0.28, 1.6, Color(0.5, 0.2, 0.2), false)
			Construir.esfera(self, Vector3(0.5, 1.75, 0), 0.2, Color(0.75, 0.6, 0.5))
		"herido":
			# Una persona tumbada con una cruz roja.
			var cuerpo: Node3D = Node3D.new()
			add_child(cuerpo)
			Construir.caja(cuerpo, Vector3(0, 0.25, 0), Vector3(1.7, 0.4, 0.55), Color(0.4, 0.45, 0.6), false)
			Construir.esfera(cuerpo, Vector3(1.05, 0.3, 0), 0.22, Color(0.8, 0.65, 0.55))
			Construir.caja(self, Vector3(0, 1.6, 0), Vector3(0.9, 0.25, 0.1), Color(0.9, 0.1, 0.1), false)
			Construir.caja(self, Vector3(0, 1.6, 0), Vector3(0.25, 0.9, 0.1), Color(0.9, 0.1, 0.1), false)
		"fuego":
			for i in 5:
				var a: float = float(i) * 1.26
				Construir.cilindro(self, Vector3(cos(a) * 0.5, 0.9, sin(a) * 0.5), 0.4, 1.8, Color(1.0, 0.45 + 0.1 * float(i % 3), 0.05), false, 1.0, 0.02)
			Construir.cilindro(self, Vector3(0, 1.2, 0), 0.5, 2.6, Color(1.0, 0.7, 0.1), false, 1.0, 0.02)
			_llama = OmniLight3D.new()
			_llama.light_color = Color(1.0, 0.5, 0.15)
			_llama.omni_range = 12.0
			_llama.light_energy = 3.0
			_llama.position.y = 1.5
			add_child(_llama)
		"cliente":
			# Un cliente sentado en un sillón con el peinado que pide (ver datos/peluqueria.gd).
			Construir.caja(self, Vector3(0, 0.35, 0.2), Vector3(0.9, 0.5, 0.9), Color(0.55, 0.15, 0.2), false)
			Construir.caja(self, Vector3(0, 1.0, 0.6), Vector3(0.9, 1.1, 0.15), Color(0.55, 0.15, 0.2), false)
			var cliente: Node3D = Node3D.new()
			cliente.position = Vector3(0, 0.45, 0.1)
			add_child(cliente)
			Aspecto.vestir(cliente, datos.get("aspecto_cliente", {}))
		"averia":
			Construir.caja(self, Vector3(0, 0.6, 0), Vector3(1.9, 0.8, 4.2), Color(0.55, 0.55, 0.6), false)
			Construir.caja(self, Vector3(0, 1.2, -0.3), Vector3(1.7, 0.6, 2.2), Color(0.6, 0.7, 0.8), false)
			Construir.caja(self, Vector3(0, 1.45, 2.2), Vector3(0.8, 0.12, 0.8), Color(0.9, 0.85, 0.2), false)
	_etiqueta = Construir.texto(self, Vector3(0, 3.6, 0), str(datos.get("texto", "Aviso")), 40, col.lightened(0.3))
	_etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_etiqueta.no_depth_test = true


func _process(delta: float) -> void:
	_t += delta
	tiempo -= delta
	if _llama != null:
		_llama.light_energy = 2.5 + sin(_t * 17.0) * 0.8
	if tiempo <= 0.0:
		caducado.emit()
		queue_free()


func texto_accion() -> String:
	var hecho: int = int(datos.get("golpes", 1)) - golpes
	return "%s (%d/%d): E para atender" % [str(datos.get("texto", "Aviso")), hecho, int(datos.get("golpes", 1))]


func usar(_jugador: Node) -> void:
	if not Juego.en_turno:
		return
	golpes -= 1
	var riesgo: float = float(datos.get("riesgo", 0.0))
	if riesgo > 0.0:
		Juego.cambiar_vida(-riesgo / float(maxi(1, int(datos.get("golpes", 1)))))
	if golpes > 0:
		Juego.avisar("Sigues con el aviso… (%d/%d)" % [int(datos.get("golpes", 1)) - golpes, int(datos.get("golpes", 1))])
		return
	var pago: int = int(round(float(datos.get("pago", 20)) * Juego.DatosOficios.multiplicador(oficio, Juego.xp_oficio(oficio))))
	Juego.cobrar(pago)
	Juego.ganar_xp_oficio(int(datos.get("xp", 10)))
	Juego.avisar("Aviso resuelto: +%d $ y +%d XP de oficio." % [pago, int(datos.get("xp", 10))])
	resuelto.emit()
	queue_free()
