# colocable.gd
# -----------------------------------------------------------------------------
# Objetos que se montan en tu casa (sistema de montaje, estilo Schedule I).
# Con el objeto en la mano pulsa G apuntando al suelo (dentro de tu casa) para
# colocarlo. E sobre él lo recoge; con "Mejora de equipo" en la mano lo sube de
# nivel (máx. 3).
#   lampara       : luz cálida; el nivel la hace más fuerte y de más alcance.
#   foco_cultivo  : las macetas a menos de 3,5 m crecen +25% por nivel.
# Se guardan con la partida (ver guardado.gd). SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name Colocable
extends Interactuable

const TIPOS: Dictionary = {
	"lampara": {"nombre": "Lámpara", "color": Color(1.0, 0.82, 0.5)},
	"foco_cultivo": {"nombre": "Foco de cultivo", "color": Color(0.8, 0.45, 1.0)},
}

var tipo: String = "lampara"
var nivel: int = 1
var _luz: OmniLight3D
var _bombilla: Node3D


func _enter_tree() -> void:
	super()
	add_to_group("colocables")
	if tipo == "foco_cultivo":
		add_to_group("focos")


func _ready() -> void:
	distancia = 2.2
	Construir.cilindro(self, Vector3(0, 0.9, 0), 0.04, 1.8, Color(0.12, 0.12, 0.14), false)
	Construir.cilindro(self, Vector3(0, 0.03, 0), 0.2, 0.06, Color(0.12, 0.12, 0.14), true)
	var color: Color = TIPOS[tipo]["color"]
	_bombilla = Construir.esfera(self, Vector3(0, 1.85, 0), 0.14, color, Vector3.ONE, 3.0)
	_luz = Construir.luz(self, Vector3(0, 1.8, 0), color, 1.0, 5.0)
	_actualizar()


func _actualizar() -> void:
	_luz.light_energy = (1.0 + 0.6 * nivel) if tipo == "lampara" else (0.8 + 0.3 * nivel)
	_luz.omni_range = 4.0 + 1.5 * nivel


func bonus_cultivo() -> float:
	return 1.0 + 0.25 * nivel if tipo == "foco_cultivo" else 1.0


func texto_accion() -> String:
	var mano: String = Juego.id_en_mano()
	if mano == "mejora_equipo" and nivel < 3:
		return "Mejorar %s (nivel %d)" % [TIPOS[tipo]["nombre"], nivel + 1]
	return "Recoger %s (nivel %d)" % [TIPOS[tipo]["nombre"], nivel]


func usar(_jugador: Node) -> void:
	if Juego.id_en_mano() == "mejora_equipo":
		if nivel >= 3:
			Juego.avisar("Ya está al nivel máximo.")
			return
		Juego.quitar("mejora_equipo", 1)
		nivel += 1
		_actualizar()
		Juego.avisar("%s mejorada al nivel %d." % [TIPOS[tipo]["nombre"], nivel])
		return
	if not Juego.cabe(tipo):
		Juego.avisar("No te cabe en la mochila.")
		return
	Juego.anadir(tipo, 1)
	if nivel > 1:
		Juego.anadir("mejora_equipo", nivel - 1)   # Las mejoras puestas se recuperan.
	queue_free()


# Coloca un objeto del inventario donde apunta el jugador. Devuelve un texto de aviso.
static func colocar_desde(jugador: Node3D, id: String) -> String:
	if not TIPOS.has(id):
		return ""
	if not Juego.tiene_vivienda() or Juego.interiores == 0:
		return "Solo puedes montar cosas dentro de una casa tuya."
	var camara: Camera3D = jugador.get_viewport().get_camera_3d()
	var desde: Vector3 = camara.global_position
	var hasta: Vector3 = desde + (-camara.global_basis.z) * 5.0
	var consulta: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(desde, hasta)
	consulta.exclude = [(jugador as CollisionObject3D).get_rid()]
	var choque: Dictionary = jugador.get_world_3d().direct_space_state.intersect_ray(consulta)
	if choque.is_empty() or (choque["normal"] as Vector3).y < 0.7:
		return "Apunta al suelo para colocarlo."
	var pos: Vector3 = choque["position"]
	pos = Vector3(snappedf(pos.x, 0.25), pos.y, snappedf(pos.z, 0.25))
	for otro in jugador.get_tree().get_nodes_in_group("colocables"):
		if (otro as Node3D).global_position.distance_to(pos) < 0.6:
			return "Ahí ya hay algo."
	Juego.quitar(id, 1)
	crear(jugador.get_tree().current_scene, id, 1, pos)
	return "%s colocada. E la recoge o la mejora." % TIPOS[id]["nombre"]


static func crear(padre: Node, id: String, nivel_inicial: int, pos: Vector3) -> Colocable:
	var c: Colocable = Colocable.new()
	c.tipo = id
	c.nivel = clampi(nivel_inicial, 1, 3)
	padre.add_child(c)
	c.global_position = pos
	return c
