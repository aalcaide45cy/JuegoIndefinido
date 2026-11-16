# mostrador.gd
# -----------------------------------------------------------------------------
# La ventanilla de venta de tu casa. Cuando ya tienes la casa alquilada, de vez
# en cuando llega un cliente que pide una poción (prohibida, claro) y espera
# con una paciencia limitada.
# Pulsa E en el mostrador para venderle si tienes lo que pide.
# -----------------------------------------------------------------------------
class_name Mostrador
extends Interactuable

const NOMBRES: Array[String] = [
	"La Viuda Remedios", "El Enterrador Tito", "Fray Anselmo (sin hábito)",
	"La Baronesa Pálida", "Un bardo con ojeras", "Sir Gualterio el Tuerto",
	"La Vieja del Pozo", "Un guardia (fuera de turno)",
]
const PACIENCIA_MAX: float = 45.0

var id_casa: String = "plaza"   # A qué vivienda pertenece esta ventanilla.
var presente: bool = false
var nombre: String = ""
var pedido: String = ""
var paciencia: float = 0.0
# Dónde espera el cliente respecto al mostrador y hacia dónde mira.
# (Quien crea el mostrador puede cambiarlo antes de añadirlo a la escena.)
var posicion_cliente: Vector3 = Vector3(1.1, -1.05, 0)
var giro_cliente: float = PI / 2.0

var _espera_siguiente: float = 6.0   # Segundos hasta que llegue alguien.
var _cliente: Node3D                 # El muñeco del cliente.
var _material_ropa: StandardMaterial3D
var _cartel: Label3D                 # Nombre, pedido y paciencia sobre su cabeza.
var _persona: Node3D                 # Modelo animado del cliente (puede ser null).
var llegado: bool = false            # Ya está en la ventanilla (antes viene caminando).
var _saliendo: bool = false          # Se aleja caminando tras el trato.
const VELOCIDAD_CLIENTE: float = 1.5
const DISTANCIA_PASEO: float = 14.0  # Desde dónde aparece (a lo largo de la fachada).


func _ready() -> void:
	distancia = 2.0
	# El cliente espera al otro lado del mostrador (1,1 m a la derecha, +X).
	_cliente = Node3D.new()
	_cliente.position = posicion_cliente
	_cliente.rotation.y = giro_cliente
	add_child(_cliente)
	var ropa: Node3D = Construir.cilindro(_cliente, Vector3(0, 0.65, 0), 0.32, 1.3, Color.GRAY, false, 0.0, 0.22)
	_material_ropa = Construir.material_propio(ropa)   # Propio: cambia de color con cada cliente.
	Construir.esfera(_cliente, Vector3(0, 1.5, 0), 0.19, Color(0.7, 0.66, 0.6))
	Construir.cilindro(_cliente, Vector3(0, 1.62, 0), 0.22, 0.25, Color(0.1, 0.1, 0.12), false, 0.0, 0.05)
	var persona: Node3D = Assets.personaje("quaternius/toon-shooter-game-kit/Characters/Character_Hazmat", "", "Idle")
	if persona != null:
		for h in _cliente.get_children():
			(h as Node3D).visible = false
		_cliente.add_child(persona)
		_persona = persona
	_cartel = Construir.texto(self, posicion_cliente + Vector3(0, 2.1, 0), "", 32)
	_cartel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cliente.visible = false
	_cartel.visible = false


func _inicio() -> Vector3:
	return posicion_cliente + Vector3(0, 0, DISTANCIA_PASEO)


# Mueve al cliente hacia "destino" (coordenadas locales). Devuelve true al llegar.
func _caminar(delta: float, destino: Vector3) -> bool:
	var falta: Vector3 = destino - _cliente.position
	falta.y = 0.0
	if falta.length() < 0.1:
		return true
	var paso: Vector3 = falta.normalized() * minf(falta.length(), VELOCIDAD_CLIENTE * delta)
	_cliente.position += paso
	_cliente.rotation.y = lerp_angle(_cliente.rotation.y, atan2(paso.x, paso.z), minf(1.0, delta * 8.0))
	Assets.poner_animacion(_persona, "Walk")
	return false


func _process(delta: float) -> void:
	_cartel.position = _cliente.position + Vector3(0, 2.1, 0)
	if _saliendo:
		if _caminar(delta, _inicio()):
			_saliendo = false
			_cliente.visible = false
			_cartel.visible = false
		return
	if not presente:
		if not Juego.alquilada(id_casa):
			return  # Nadie viene a comprar hasta que tengas tu escondite.
		_espera_siguiente -= delta
		if _espera_siguiente <= 0.0:
			_llega_cliente()
		return
	if not llegado:
		_cartel.text = "%s\nviene hacia la ventanilla..." % nombre
		if _caminar(delta, posicion_cliente):
			llegado = true
			_cliente.rotation.y = giro_cliente
			Assets.poner_animacion(_persona, "Idle")
			Juego.avisar("%s ha llegado a la ventanilla de tu casa." % nombre)
		return
	paciencia -= delta
	if paciencia <= 0.0:
		Juego.avisar("%s se ha cansado de esperar y se va." % nombre)
		_se_marcha()
		return
	# Barra de paciencia hecha con texto: #### = le queda paciencia.
	var llenos: int = ceili(paciencia / PACIENCIA_MAX * 10.0)
	_cartel.text = "%s\nQuiere: %s\n[%s%s]" % [nombre, GameData.POCIONES[pedido]["nombre"],
			"#".repeat(llenos), ".".repeat(10 - llenos)]


func _item_para_vender() -> String:
	if Juego.tiene("paquete_" + pedido):
		return "paquete_" + pedido
	if Juego.tiene("pocion_" + pedido):
		return "pocion_" + pedido
	return ""


func precio_base() -> int:
	var base: int = int(GameData.POCIONES[pedido]["precio"])
	return int(base * 1.3) if _item_para_vender().begins_with("paquete") else base


func texto_accion() -> String:
	if not presente:
		return "No hay nadie en el mostrador"
	if not llegado:
		return "%s se acerca a la ventanilla..." % nombre
	var datos: Dictionary = GameData.POCIONES[pedido]
	if _item_para_vender() != "":
		return "Atender a %s: %s (%d $, se puede negociar)" % [nombre, datos["nombre"], precio_base()]
	return "Te pide %s (prepárala en el caldero)" % datos["nombre"]


func usar(jugador: Node) -> void:
	if not presente or not llegado:
		return
	if _item_para_vender() == "":
		Juego.avisar("No tienes %s. Receta: %s." % [GameData.POCIONES[pedido]["nombre"],
				GameData.texto_receta(pedido)])
		return
	jugador.hud.abrir_negociacion(self)


# La ventana de negociación llama aquí con el precio acordado.
func cerrar_trato(precio: int) -> void:
	var item: String = _item_para_vender()
	if not presente or item == "":
		return
	Juego.quitar(item)
	if Juego.es_de_noche() and Juego.policia_activa:
		Juego.alerta = 100.0   # De noche, vender por la ventana sí te puede costar una detención.
		Juego.motivo_alerta = "Te vieron vender de noche por la ventana"
	Juego.avisar("Vendido por %d $. %s" % [precio, GameData.POCIONES[pedido]["efecto"]])
	Juego.cobrar(precio)
	Juego.ganar_xp(25)
	Juego.reputacion = mini(100, Juego.reputacion + 1)
	_se_marcha()


func trato_fallido() -> void:
	Juego.reputacion = maxi(-50, Juego.reputacion - 1)
	Juego.avisar("%s se ofende y se marcha." % nombre)
	_se_marcha()


func _llega_cliente() -> void:
	presente = true
	llegado = false
	nombre = NOMBRES.pick_random()
	pedido = GameData.POCIONES.keys().pick_random()
	paciencia = PACIENCIA_MAX
	_material_ropa.albedo_color = Color.from_hsv(randf(), 0.35, 0.35)
	_cliente.position = _inicio()
	_cliente.visible = true
	_cartel.visible = true
	Juego.avisar("Alguien viene caminando hacia la ventanilla de tu casa: es %s." % nombre)


func _se_marcha() -> void:
	presente = false
	llegado = false
	_saliendo = true
	_espera_siguiente = randf_range(5.0, 10.0)
