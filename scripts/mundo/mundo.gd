# mundo.gd
# -----------------------------------------------------------------------------
# La escena principal del juego 3D. Monta todo al arrancar:
#   - el cielo y la luz del día y la noche (ciclo_dia.gd),
#   - los barrios de la ciudad: la Plaza del Ahorcado en el centro y, unidos
#     por calles, el Mercado (norte), el Barrio Residencial (este) y la Zona
#     Industrial (sur),
#   - el HUD y el jugador.
#
# Para ampliar la ciudad, añade más barrios en _ready() (mira barrio.gd).
# -----------------------------------------------------------------------------
extends Node3D

# Dónde empieza el jugador: en la plaza, mirando a la herboristería (norte).
const INICIO_JUGADOR: Vector3 = Vector3(0, 0, 8)
# Metros que se añaden alrededor de los barrios antes de poner el muro.
const MARGEN_CIUDAD: float = 6.0


func _ready() -> void:
	add_child(CicloDia.new())

	_anadir_barrio(BarrioPlaza.new(), Vector3.ZERO)
	# Tres calles salen de la plaza: norte, este y sur.
	_anadir_barrio(BarrioMercado.new(), Vector3(16, 0, -64))
	_anadir_barrio(BarrioResidencial.new(), Vector3(64, 0, -16))
	_anadir_barrio(BarrioIndustrial.new(), Vector3(-16, 0, 64))

	_guardias_nocturnos()
	_cerrar_ciudad()
	# Junta las miles de piezas que no se mueven en pocas mallas grandes (ver
	# Construir.fusionar_estaticos): muchas menos llamadas de dibujo por fotograma.
	var fusionadas: int = Construir.fusionar_estaticos(self)
	print("Mallas fusionadas: %d" % fusionadas)

	var hud: Hud = Hud.new()
	add_child(hud)
	var jugador: Jugador = Jugador.new()
	jugador.position = INICIO_JUGADOR
	jugador.hud = hud
	add_child(jugador)
	hud.jugador = jugador
	add_child(Encargos.new())
	Sonido.ambiente(self)
	_polvo_en_el_aire(jugador)


# Motas de polvo / luciérnagas flotando alrededor del jugador (partículas ligeras).
func _polvo_en_el_aire(jugador: Node3D) -> void:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14, 4, 14)
	p.position = Vector3(0, 3, 0)
	p.direction = Vector3(0.3, 0.2, 0.1)
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.35
	p.gravity = Vector3.ZERO
	p.local_coords = false
	var malla: SphereMesh = SphereMesh.new()
	malla.radius = 0.02
	malla.height = 0.04
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.75, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.6)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	malla.material = mat
	p.mesh = malla
	jugador.add_child(p)


# Refuerzos de noche: guardias extra que solo existen de noche y recorren toda la ciudad.
func _guardias_nocturnos() -> void:
	var nodos: Array = RedCalles.NODOS.keys()
	for i in 4:
		var g: Guardia = Guardia.new()
		g.solo_noche = true
		add_child(g)
		var inicio: String = nodos[randi() % nodos.size()]
		g.global_position = RedCalles.NODOS[inicio]
		g._nodo_destino = inicio


# Cierra la ciudad: calcula el rectángulo que ocupan todos los barrios y pone
#   - un suelo oscuro debajo de todo (así los huecos entre barrios son solares
#     y no un vacío por el que caer),
#   - un muro alto y sólido por todo el perímetro (nadie sale del mapa).
# Si añades barrios nuevos, se adapta solo al nuevo tamaño.
func _cerrar_ciudad() -> void:
	var limites: Rect2 = Rect2()
	var primero: bool = true
	for malla in find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = malla as MeshInstance3D
		if m.mesh == null:
			continue
		var caja: AABB = m.global_transform * m.get_aabb()
		if caja.position.y > 3.0:
			continue  # Tejados y pisos altos no cuentan: solo lo que está a pie de calle.
		var rect: Rect2 = Rect2(caja.position.x, caja.position.z, caja.size.x, caja.size.z)
		limites = rect if primero else limites.merge(rect)
		primero = false
	limites = limites.grow(MARGEN_CIUDAD)

	var centro: Vector2 = limites.get_center()
	# Suelo de seguridad bajo todo el rectángulo (su cara de arriba queda un pelín
	# por debajo de los suelos de los barrios para no parpadear con ellos).
	Construir.caja(self, Vector3(centro.x, -0.65, centro.y), Vector3(limites.size.x, 1.2, limites.size.y),
			Color(0.1, 0.09, 0.09))
	# Cuatro muros de piedra oscura alrededor.
	var alto: float = 9.0
	var grosor: float = 2.0
	var piedra: Color = Color(0.2, 0.19, 0.2)
	Construir.caja(self, Vector3(centro.x, alto / 2.0, limites.position.y - grosor / 2.0),
			Vector3(limites.size.x + 2.0 * grosor, alto, grosor), piedra)
	Construir.caja(self, Vector3(centro.x, alto / 2.0, limites.end.y + grosor / 2.0),
			Vector3(limites.size.x + 2.0 * grosor, alto, grosor), piedra)
	Construir.caja(self, Vector3(limites.position.x - grosor / 2.0, alto / 2.0, centro.y),
			Vector3(grosor, alto, limites.size.y), piedra)
	Construir.caja(self, Vector3(limites.end.x + grosor / 2.0, alto / 2.0, centro.y),
			Vector3(grosor, alto, limites.size.y), piedra)


func _anadir_barrio(barrio: Barrio, pos: Vector3) -> void:
	barrio.position = pos
	add_child(barrio)
