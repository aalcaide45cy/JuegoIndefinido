# juego.gd  (se carga solo al arrancar, con el nombre "Juego")
# -----------------------------------------------------------------------------
# El "cerebro" de la partida: dinero, inventario, hierbas cosechadas y
# pociones hechas. Como está en Proyecto > Configuración > Autoload, cualquier
# script puede escribir, por ejemplo, Juego.dinero o Juego.avisar("Hola").
#
# También crea los controles (teclas) para no tener que configurarlos a mano.
# -----------------------------------------------------------------------------
extends Node

# Se emite cada vez que cambia el dinero o el inventario (el HUD se refresca).
signal cambio
# Se emite para mostrar un mensaje en pantalla.
signal mensaje(texto: String)

var dinero: int = 0
var objetos: Dictionary = {}    # id_objeto (de GameData.OBJETOS) -> cantidad
var agua_jarra: int = 0         # Riegos que le quedan a la jarra.
var hierbas: Dictionary = {}    # id_hierba -> cantidad cosechada
var pociones: Dictionary = {}   # id_pocion -> cantidad lista para vender
var ha_ganado: bool = false
var casa_alquilada: bool = false
var almacen: Dictionary = {}    # Lo guardado en la estantería de casa: id_objeto -> cantidad

# true mientras hay un menú abierto (tienda, inventario, minijuego):
# el jugador no se mueve y el ratón se puede usar para hacer clic.
var menu_abierto: bool = false

# Qué hierba tienes "en la mano" para echar al caldero. Se cambia con Q.
var _indice_hierba: int = 0


func _ready() -> void:
	randomize()
	_crear_controles()
	reiniciar()


func reiniciar() -> void:
	dinero = GameData.DINERO_INICIAL
	for id_objeto in GameData.OBJETOS:
		objetos[id_objeto] = 0
		almacen[id_objeto] = 0
	agua_jarra = 0
	casa_alquilada = false
	for id_hierba in GameData.HIERBAS:
		hierbas[id_hierba] = 0
	for id_pocion in GameData.POCIONES:
		pociones[id_pocion] = 0
	ha_ganado = false
	cambio.emit()


# ------------------------- Hierba seleccionada --------------------------------

func hierba_seleccionada() -> String:
	return GameData.HIERBAS.keys()[_indice_hierba]


func siguiente_hierba() -> void:
	_indice_hierba = (_indice_hierba + 1) % GameData.HIERBAS.size()
	avisar("En la mano: %s" % GameData.HIERBAS[hierba_seleccionada()]["nombre"])
	cambio.emit()


# ------------------------------ Dinero ----------------------------------------

# Intenta pagar. Devuelve true si había dinero suficiente.
func gastar(cantidad: int) -> bool:
	if dinero < cantidad:
		return false
	dinero -= cantidad
	cambio.emit()
	return true


func cobrar(cantidad: int) -> void:
	dinero += cantidad
	cambio.emit()
	if not ha_ganado and dinero >= GameData.OBJETIVO_DINERO:
		ha_ganado = true
		avisar("¡Has reunido %d $ y pagado el alquiler! Prototipo superado." %
				GameData.OBJETIVO_DINERO)


# ------------------------------ Objetos ---------------------------------------

func tiene(id_objeto: String, cantidad: int = 1) -> bool:
	return objetos[id_objeto] >= cantidad


# Compra un objeto del puesto. Devuelve un texto con lo que ha pasado.
func comprar(id_objeto: String) -> String:
	var datos: Dictionary = GameData.OBJETOS[id_objeto]
	if datos["unico"] and objetos[id_objeto] > 0:
		return "Ya tienes %s." % datos["nombre"]
	if not gastar(datos["precio"]):
		return "No te llega: %s cuesta %d $." % [datos["nombre"], datos["precio"]]
	objetos[id_objeto] += 1
	if id_objeto == "jarra":
		agua_jarra = GameData.CARGAS_JARRA  # La jarra viene llena.
	cambio.emit()
	return "Has comprado %s por %d $." % [datos["nombre"], datos["precio"]]


# Gasta un objeto (por ejemplo, un saco de tierra al plantar).
func usar_objeto(id_objeto: String) -> void:
	objetos[id_objeto] -= 1
	cambio.emit()


# Mueve un objeto entre el inventario y la estantería de casa.
func guardar_en_almacen(id_objeto: String) -> void:
	if objetos[id_objeto] <= 0:
		return
	objetos[id_objeto] -= 1
	almacen[id_objeto] += 1
	cambio.emit()


func sacar_de_almacen(id_objeto: String) -> void:
	if almacen[id_objeto] <= 0:
		return
	almacen[id_objeto] -= 1
	objetos[id_objeto] += 1
	cambio.emit()


func avisar(texto: String) -> void:
	mensaje.emit(texto)


# ------------------------------ Controles -------------------------------------
# Usamos "physical_keycode": la tecla por su posición en el teclado.

func _crear_controles() -> void:
	_accion("adelante", [KEY_W, KEY_UP])
	_accion("atras", [KEY_S, KEY_DOWN])
	_accion("izquierda", [KEY_A, KEY_LEFT])
	_accion("derecha", [KEY_D, KEY_RIGHT])
	_accion("correr", [KEY_SHIFT])
	_accion("saltar", [KEY_SPACE])
	_accion("usar", [KEY_E])
	_accion("cambiar_hierba", [KEY_Q])
	_accion("cambiar_camara", [KEY_V])
	_accion("inventario", [KEY_TAB])
	_accion("liberar_raton", [KEY_ESCAPE])


func _accion(nombre: String, teclas: Array) -> void:
	if InputMap.has_action(nombre):
		return
	InputMap.add_action(nombre)
	for tecla in teclas:
		var evento: InputEventKey = InputEventKey.new()
		evento.physical_keycode = tecla
		InputMap.action_add_event(nombre, evento)
