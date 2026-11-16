# encargos.gd
# -----------------------------------------------------------------------------
# El sistema de encargos del móvil (estilo "Schedule I"): llegan ofertas de
# clientes, las aceptas o rechazas, el comprador te espera en un sitio del mapa
# (sale en brújula, minimapa y mapa grande) y si tardas se va y baja tu
# reputación. También gestiona los pedidos de materiales que haces desde el móvil.
#
# El estado vive en Juego (encargos, pedidos_material, reputacion, avisos) para
# que se guarde con la partida. Este nodo solo lo hace avanzar. Lo añade mundo.gd.
# -----------------------------------------------------------------------------
class_name Encargos
extends Node

const DatosObjetos = preload("res://scripts/datos/objetos.gd")

const NOMBRES: Array[String] = ["Marta", "Ismael", "Rosario", "Dani", "Lola", "Chema", "Vera", "Nico", "Paco", "Inés"]
# Puntos de encuentro (mundo) y su nombre.
const LUGARES: Array = [
	[Vector3(9, 0.2, 9), "Plaza, junto a la fuente"],
	[Vector3(-9, 0.2, 9), "Plaza, lado oeste"],
	[Vector3(16, 0.2, -32), "Calle del Mercado"],
	[Vector3(32, 0.2, -16), "Calle Este"],
	[Vector3(-16, 0.2, 32), "Calle Sur"],
	[Vector3(16, 0.2, -58), "Mercado"],
	[Vector3(58, 0.2, -16), "Barrio Residencial"],
	[Vector3(-16, 0.2, 58), "Zona Industrial"],
]
const VALIDEZ_OFERTA: float = 120.0
const ESPERA_COMPRADOR: float = 300.0
const ENTREGA_MATERIAL: float = 45.0
const TASA_ENVIO: int = 10

var _siguiente: float = 25.0
var _compradores: Dictionary = {}   # id -> Comprador
var _siguiente_id: int = 1
var _aviso: Label
var _capa: CanvasLayer


func _ready() -> void:
	add_to_group("gestor_encargos")
	var capa: CanvasLayer = CanvasLayer.new()
	capa.layer = 5
	add_child(capa)
	_aviso = Label.new()
	_aviso.add_theme_font_size_override("font_size", 18)
	_aviso.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	_aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_aviso.add_theme_constant_override("outline_size", 6)
	_aviso.anchor_left = 0.0
	_aviso.offset_left = 16.0
	_aviso.offset_top = 196.0   # Debajo del panel de vida y de los avisos de sigilo.
	capa.add_child(_aviso)
	_capa = capa
	for e in Juego.encargos:
		_siguiente_id = maxi(_siguiente_id, int(e["id"]) + 1)


func _process(delta: float) -> void:
	# El aviso se escala igual que el resto de la interfaz (pensada para 720 de alto):
	# sin esto, en 4K salía con letra diminuta.
	var factor: float = maxf(0.5, get_viewport().get_visible_rect().size.y / Hud.ALTO_DISENO)
	_capa.scale = Vector2(factor, factor)
	_siguiente -= delta
	if _siguiente <= 0.0:
		_siguiente = randf_range(50.0, 90.0)
		_crear_oferta()
	var cambio: bool = false
	for e in Juego.encargos.duplicate():
		e["t"] = float(e["t"]) - delta
		if float(e["t"]) <= 0.0:
			cambio = true
			if e["estado"] == "oferta":
				Juego.encargos.erase(e)
				_notificar("%s ya no espera tu respuesta (oferta caducada)." % e["cliente"])
			else:
				_comprador_se_va(e)
		elif e["estado"] == "aceptado":
			if not _compradores.has(int(e["id"])):
				_crear_comprador(e)
			else:
				# Tras cargar otra partida el mismo número puede ser otro encargo en otro sitio.
				var c: Comprador = _compradores[int(e["id"])]
				var sitio: Vector3 = Vector3(e["pos"][0], e["pos"][1], e["pos"][2])
				if is_instance_valid(c) and c.position.distance_to(sitio) > 0.5:
					c.position = sitio
	# Compradores cuyo encargo ya no existe (p. ej. al cargar otra partida).
	for id in _compradores.keys():
		var existe: bool = false
		for e in Juego.encargos:
			if int(e["id"]) == int(id):
				existe = true
		if not existe:
			_quitar_comprador(int(id))
	var materiales_listos: Array = []
	for p in Juego.pedidos_material:
		p["t"] = float(p["t"]) - delta
		if float(p["t"]) <= 0.0:
			materiales_listos.append(p)
	for p in materiales_listos:
		Juego.pedidos_material.erase(p)
		_entregar_material(p)
	if cambio:
		Juego.cambio.emit()
	# Aviso fijo en pantalla mientras haya ofertas sin responder.
	var ofertas: int = 0
	for e in Juego.encargos:
		if e["estado"] == "oferta":
			ofertas += 1
	_aviso.text = "Móvil: %d encargo(s) nuevo(s)  [P]" % ofertas if ofertas > 0 and not Juego.menu_abierto else ""


func _crear_oferta() -> void:
	var ofertas: int = 0
	for e in Juego.encargos:
		if e["estado"] == "oferta":
			ofertas += 1
	if ofertas >= 3 or Juego.encargos.size() >= 6:
		return
	var ids: Array = GameData.POCIONES.keys()
	var pocion: String = ids[randi() % ids.size()]
	var cantidad: int = randi_range(1, 3) + (1 if Juego.nivel >= 3 else 0)
	var precio: int = int(GameData.POCIONES[pocion]["precio"])
	var factor: float = randf_range(1.15, 1.6) * (1.0 + clampf(Juego.reputacion, 0, 100) / 250.0)
	var lugar: Array = LUGARES[randi() % LUGARES.size()]
	var pos: Vector3 = lugar[0]
	# El número nunca repite uno que ya exista (por ejemplo, tras cargar una partida).
	for otro in Juego.encargos:
		_siguiente_id = maxi(_siguiente_id, int(otro["id"]) + 1)
	var e: Dictionary = {
		"id": _siguiente_id, "cliente": NOMBRES[randi() % NOMBRES.size()], "pocion": pocion,
		"cantidad": cantidad, "pago": int(precio * cantidad * factor), "estado": "oferta",
		"t": VALIDEZ_OFERTA, "lugar": lugar[1], "pos": [pos.x, pos.y, pos.z],
	}
	_siguiente_id += 1
	Juego.encargos.append(e)
	_notificar("Mensaje de %s: quiere %d x %s. Mira el móvil (P)." % [e["cliente"], cantidad, GameData.POCIONES[pocion]["nombre"]])
	Sonido.tocar(self, "alerta", -10.0)
	Juego.cambio.emit()


func aceptar(id: int) -> void:
	for e in Juego.encargos:
		if int(e["id"]) == id and e["estado"] == "oferta":
			e["estado"] = "aceptado"
			e["t"] = ESPERA_COMPRADOR
			_crear_comprador(e)
			_notificar("Encargo aceptado. %s te espera en: %s." % [e["cliente"], e["lugar"]])
			Juego.cambio.emit()
			return


func rechazar(id: int) -> void:
	for e in Juego.encargos:
		if int(e["id"]) == id and e["estado"] == "oferta":
			Juego.encargos.erase(e)
			Juego.cambio.emit()
			return


# Abandonar un encargo ya aceptado (el comprador se va y baja la reputación).
func cancelar(id: int) -> void:
	for e in Juego.encargos:
		if int(e["id"]) == id and e["estado"] == "aceptado":
			_comprador_se_va(e)
			Juego.cambio.emit()
			return


func _crear_comprador(e: Dictionary) -> void:
	var p: Array = e["pos"]
	var c: Comprador = Comprador.new()
	c.id_encargo = int(e["id"])
	c.gestor = self
	c.position = Vector3(p[0], p[1], p[2])
	get_parent().add_child(c)
	_compradores[int(e["id"])] = c


func _quitar_comprador(id: int) -> void:
	if _compradores.has(id):
		if is_instance_valid(_compradores[id]):
			_compradores[id].queue_free()
		_compradores.erase(id)


func _comprador_se_va(e: Dictionary) -> void:
	_quitar_comprador(int(e["id"]))
	Juego.encargos.erase(e)
	Juego.reputacion = maxi(-50, Juego.reputacion - 5)
	_notificar("%s se cansó de esperar y se fue. Reputación -5." % e["cliente"])


# Lo llama el comprador al pulsar E.
func entregar(id: int) -> String:
	for e in Juego.encargos:
		if int(e["id"]) != id or e["estado"] != "aceptado":
			continue
		var item: String = "pocion_" + str(e["pocion"])
		var paquete: String = "paquete_" + str(e["pocion"])
		var cant: int = int(e["cantidad"])
		var bonus: float = 1.0
		if Juego.tiene(paquete, cant):
			item = paquete
			bonus = 1.3   # Empaquetado: +30%.
		elif not Juego.tiene(item, cant):
			return "Te faltan pociones: necesitas %d x %s (mejor si van empaquetadas)." % [cant, GameData.POCIONES[e["pocion"]]["nombre"]]
		Juego.quitar(item, cant)
		e["pago"] = int(int(e["pago"]) * bonus)
		Juego.cobrar(int(e["pago"]))
		Juego.ganar_xp(15 * cant)
		Juego.reputacion = mini(100, Juego.reputacion + 3)
		_quitar_comprador(id)
		Juego.encargos.erase(e)
		_notificar("Venta a %s: +%d $ y reputación +3." % [e["cliente"], e["pago"]])
		Sonido.tocar(self, "compra")
		Juego.cambio.emit()
		return ""
	return "Este encargo ya no existe."


# Pedido de materiales desde el móvil: paga ahora y llega en unos segundos.
func pedir_material(id: String, cantidad: int) -> String:
	var d: Dictionary = DatosObjetos.datos(id)
	var coste: int = int(d["precio"]) * cantidad + TASA_ENVIO
	if not Juego.gastar(coste):
		return "No tienes %d $ (incluye %d $ de envío)." % [coste, TASA_ENVIO]
	Juego.pedidos_material.append({"id": id, "cantidad": cantidad, "t": ENTREGA_MATERIAL})
	_notificar("Pedido enviado: %d x %s. Llegará en %d s." % [cantidad, d["nombre"], int(ENTREGA_MATERIAL)])
	Juego.cambio.emit()
	return ""


func _entregar_material(p: Dictionary) -> void:
	var sobra: int = Juego.anadir(str(p["id"]), int(p["cantidad"]))
	var nombre: String = DatosObjetos.nombre(str(p["id"]))
	if sobra > 0:
		_notificar("Llegó tu pedido de %s pero no cabía todo en la mochila: se perdieron %d." % [nombre, sobra])
	else:
		_notificar("Ha llegado tu pedido: %d x %s (ya está en tu mochila)." % [p["cantidad"], nombre])
	Sonido.tocar(self, "compra", -8.0)


func _notificar(texto: String) -> void:
	Juego.nuevo_aviso(texto)
