# admin_catalogo.gd
# -----------------------------------------------------------------------------
# El catálogo del panel de administrador: TODO lo que se puede hacer aparecer.
#
# Se alimenta SOLO de las fuentes del juego, así que lo nuevo que añadan otros
# hilos sale sin tocar el panel:
#   - cada objeto de DatosObjetos.LISTA (armas, explosivos, comida, llaves...);
#   - cada vehículo de Vehiculo.TIPOS;
#   - los PNJ, el dinero y la ropa que se listan aquí abajo;
#   - lo que se registre con AdminCatalogo.registrar(...).
#
# Para sacar un objeto de LISTA en otra categoría, ponle "admin_categoria": "Mi categoría".
#
# REGISTRAR algo propio (un arma que no es un objeto, un explosivo en el mundo, un PNJ nuevo):
#   AdminCatalogo.registrar("bomba_napalm", "Bomba de napalm", "Explosivos",
#       func(cantidad: int, al_suelo: bool, jugador: Node3D) -> String:
#           Combate.lanzar(...)
#           return "Lanzada.")
# La función recibe la cantidad pedida, si se pidió "en el suelo" y el jugador, y devuelve el aviso.
# Se puede llamar desde el _ready() de tu autoload o de tu escena (da igual cuántas veces).
# -----------------------------------------------------------------------------
class_name AdminCatalogo
extends RefCounted

const DatosObjetos = preload("res://scripts/datos/objetos.gd")
const Aspecto = preload("res://scripts/jugador/aspecto.gd")

const CAT_ARMAS: String = "Armas"
const CAT_MUNICION: String = "Munición"
const CAT_EXPLOSIVOS: String = "Explosivos"
const CAT_COMIDA: String = "Comida y bebida"
const CAT_HERRAMIENTAS: String = "Herramientas"
const CAT_INGREDIENTES: String = "Ingredientes mágicos"
const CAT_POCIONES: String = "Pociones"
const CAT_MATERIALES: String = "Materiales y oficios"
const CAT_LLAVES: String = "Llaves"
const CAT_MUEBLES: String = "Muebles y props"
const CAT_ROPA: String = "Ropa y aspecto"
const CAT_DINERO: String = "Dinero"
const CAT_VEHICULOS: String = "Vehículos"
const CAT_NPC: String = "NPC"

# Orden de las categorías en el panel (las nuevas se añaden al final).
const ORDEN: Array = [CAT_ARMAS, CAT_MUNICION, CAT_EXPLOSIVOS, CAT_COMIDA, CAT_HERRAMIENTAS,
		CAT_INGREDIENTES, CAT_POCIONES, CAT_MATERIALES, CAT_LLAVES, CAT_MUEBLES, CAT_ROPA,
		CAT_DINERO, CAT_VEHICULOS, CAT_NPC]

const POR_TIPO: Dictionary = {
	"arma_cc": CAT_ARMAS, "arma_fuego": CAT_ARMAS, "municion": CAT_MUNICION,
	"explosivo": CAT_EXPLOSIVOS, "consumible": CAT_COMIDA, "herramienta": CAT_HERRAMIENTAS,
	"hierba": CAT_INGREDIENTES, "semilla": CAT_INGREDIENTES, "aditivo": CAT_INGREDIENTES,
	"cosecha": CAT_INGREDIENTES, "animal": CAT_INGREDIENTES, "pocion": CAT_POCIONES,
	"material": CAT_MATERIALES, "paquete": CAT_MATERIALES, "mueble": CAT_MUEBLES,
}

# Lo registrado desde fuera: clave -> entrada.
static var _registro: Dictionary = {}


# Añade (o sustituye) una entrada propia. Ver el ejemplo de arriba.
static func registrar(clave: String, nombre: String, categoria: String, accion: Callable,
		descripcion: String = "") -> void:
	_registro["x:" + clave] = {"clave": "x:" + clave, "nombre": nombre, "categoria": categoria,
			"descripcion": descripcion, "tipo": "custom", "accion": accion}


static func quitar_registro(clave: String) -> void:
	_registro.erase("x:" + clave)


# Todas las entradas. "categoria" = "" para todas; "texto" filtra por nombre/id (sin mayúsculas).
static func entradas(categoria: String = "", texto: String = "") -> Array:
	var todas: Array = []
	for id in DatosObjetos.LISTA:
		var d: Dictionary = DatosObjetos.LISTA[id]
		var cat: String = str(d.get("admin_categoria", ""))
		if cat == "":
			cat = CAT_LLAVES if str(id).contains("llave") else str(POR_TIPO.get(d["tipo"], CAT_MATERIALES))
		todas.append({"clave": "o:" + id, "id": id, "nombre": str(d["nombre"]), "categoria": cat,
				"descripcion": str(d.get("descripcion", "")), "tipo": "objeto"})
	for tipo_v in Vehiculo.TIPOS:
		todas.append({"clave": "v:" + tipo_v, "id": tipo_v, "nombre": str(Vehiculo.TIPOS[tipo_v]["nombre"]),
				"categoria": CAT_VEHICULOS, "descripcion": "Aparece a 1 m delante de ti y es tuyo.", "tipo": "vehiculo"})
	todas.append_array(_npcs())
	todas.append_array(_dinero())
	todas.append_array(_ropa())
	todas.append_array(_registro.values())
	var q: String = texto.strip_edges().to_lower()
	var salida: Array = []
	for e in todas:
		if categoria != "" and e["categoria"] != categoria:
			continue
		if q != "" and not (str(e["nombre"]).to_lower().contains(q) or str(e["clave"]).to_lower().contains(q)):
			continue
		salida.append(e)
	salida.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["nombre"]).naturalnocasecmp_to(str(b["nombre"])) < 0)
	return salida


# Las categorías que tienen algo, en orden.
static func categorias() -> Array:
	var hay: Dictionary = {}
	for e in entradas():
		hay[e["categoria"]] = true
	var lista: Array = []
	for c in ORDEN:
		if hay.has(c):
			lista.append(c)
	for c in hay:
		if not lista.has(c):
			lista.append(c)
	return lista


static func _npcs() -> Array:
	var lista: Array = []
	for par in [["guardia", "Guardia", "Un policía de patrulla."],
			["maton", "Matón", "Un matón de banda. Te ataca cuerpo a cuerpo."],
			["jefe", "Jefe de barrio", "Más vida y más daño."],
			["recluta", "Recluta (aliado)", "Te sigue y pelea a tu lado."],
			["vecino", "Vecino", "Un vecino que reacciona a lo que pase."]]:
		lista.append({"clave": "n:" + par[0], "id": par[0], "nombre": par[1], "categoria": CAT_NPC,
				"descripcion": par[2], "tipo": "npc"})
	return lista


static func _dinero() -> Array:
	var lista: Array = []
	for cantidad in [100, 1000, 10000, 100000]:
		lista.append({"clave": "d:%d" % cantidad, "id": str(cantidad), "nombre": "Dinero limpio %d $" % cantidad,
				"categoria": CAT_DINERO, "descripcion": "Efectivo. La cantidad multiplica.", "tipo": "dinero"})
	if "dinero_negro" in Juego:
		for cantidad in [100, 1000, 10000, 100000]:
			lista.append({"clave": "dn:%d" % cantidad, "id": str(cantidad), "nombre": "Dinero negro %d $" % cantidad,
					"categoria": CAT_DINERO, "descripcion": "Dinero sucio. La cantidad multiplica.", "tipo": "dinero_negro"})
	return lista


static func _ropa() -> Array:
	var lista: Array = []
	for o in Aspecto.OPCIONES:
		if o[0] in ["cuerpo", "sombrero", "abrigo", "bufanda", "peinado"]:
			for i in (o[2] as Array).size():
				lista.append({"clave": "r:%s:%d" % [o[0], i], "id": "%s:%d" % [o[0], i],
						"nombre": "%s: %s" % [o[1], o[2][i]], "categoria": CAT_ROPA,
						"descripcion": "Te lo pones al momento.", "tipo": "ropa"})
	return lista


# ------------------------------- Hacer aparecer --------------------------------

# Hace aparecer la entrada. Devuelve el aviso para el jugador.
static func dar(e: Dictionary, cantidad: int, al_suelo: bool, jugador: Node3D) -> String:
	cantidad = maxi(1, cantidad)
	match e["tipo"]:
		"objeto":
			return dar_objeto(str(e["id"]), cantidad, al_suelo, jugador)
		"vehiculo":
			return dar_vehiculo(str(e["id"]), jugador)
		"npc":
			return dar_npc(str(e["id"]), cantidad, jugador)
		"dinero":
			Juego.dinero += int(e["id"]) * cantidad
			Juego.cambio.emit()
			return "Te has dado %d $." % (int(e["id"]) * cantidad)
		"dinero_negro":
			Juego.dinero_negro += int(e["id"]) * cantidad
			Juego.cambio.emit()
			return "Te has dado %d $ de dinero negro." % (int(e["id"]) * cantidad)
		"ropa":
			var partes: PackedStringArray = str(e["id"]).split(":")
			Juego.aspecto[partes[0]] = int(partes[1])
			Juego.aspecto = Aspecto.valido(Juego.aspecto)
			if jugador != null and jugador.has_method("vestir"):
				jugador.vestir()
			return "Te has puesto: %s." % e["nombre"]
		"custom":
			var accion: Callable = e["accion"]
			if not accion.is_valid():
				return "Esta entrada ya no funciona."
			return str(accion.call(cantidad, al_suelo, jugador))
	return "No sé hacer aparecer eso."


static func dar_objeto(id: String, cantidad: int, al_suelo: bool, jugador: Node3D) -> String:
	var nombre: String = DatosObjetos.nombre(id)
	if al_suelo and jugador != null:
		var n: int = cantidad
		var pila: int = DatosObjetos.pila(id)
		while n > 0:
			var trozo: int = mini(n, pila)
			ObjetoSuelo.crear(jugador, id, trozo, (cantidad - n) / pila)
			n -= trozo
		return "%d x %s en el suelo, delante de ti (E para cogerlo)." % [cantidad, nombre]
	var sobra: int = Juego.anadir(id, cantidad)
	return "Te has dado %d x %s.%s" % [cantidad - sobra, nombre, "" if sobra == 0 else " (No cabían %d.)" % sobra]


# Pone el arma en la barra, la selecciona, la carga y te da munición de sobra.
static func equipar(id: String) -> String:
	var d: Dictionary = DatosObjetos.datos(id)
	if Juego.anadir(id, 1) > 0:
		return "No cabe en el inventario."
	var i: int = -1
	for k in Juego.inventario.size():
		if Juego.inventario[k] != null and Juego.inventario[k]["id"] == id:
			i = k
			break
	var j: int = i
	if i >= Juego.TAM_BARRA:
		j = -1
		for k in Juego.TAM_BARRA:
			if Juego.inventario[k] == null:
				j = k
				break
		if j == -1:
			j = Juego.seleccion
		Juego.mover(Juego.inventario, i, Juego.inventario, j)
	Juego.seleccion = j
	var casilla = Juego.inventario[j]
	var extra: String = ""
	if d["tipo"] == "arma_fuego":
		casilla["balas"] = int(d["cargador"])
		Juego.anadir(str(d["municion"]), int(d["cargador"]) * 4)
		extra = " Cargada y con %d de munición de reserva." % (int(d["cargador"]) * 4)
	Juego.cambio.emit()
	return "Llevas en la mano: %s.%s" % [d["nombre"], extra]


# Munición para todas las armas de fuego que lleves (o de todas, si no llevas ninguna).
static func dar_municion(cantidad: int = 60) -> String:
	var tipos: Dictionary = {}
	for casilla in Juego.inventario:
		if casilla != null:
			var d: Dictionary = DatosObjetos.datos(casilla["id"])
			if d["tipo"] == "arma_fuego":
				tipos[str(d["municion"])] = true
	if tipos.is_empty():
		for id in DatosObjetos.LISTA:
			if DatosObjetos.LISTA[id]["tipo"] == "municion":
				tipos[id] = true
	for id in tipos:
		Juego.anadir(id, cantidad)
	return "Munición añadida (%d de cada tipo)." % cantidad


# Un punto delante del jugador, sobre el suelo.
static func punto_delante(jugador: Node3D, distancia: float, lado: float = 0.0) -> Vector3:
	var giro: float = float(jugador.get("_giro"))
	var base: Basis = Basis(Vector3.UP, giro)
	var p: Vector3 = jugador.global_position + base * Vector3(lado, 0, -distancia)
	var rayo: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			p + Vector3(0, 3, 0), p - Vector3(0, 30, 0))
	var golpe: Dictionary = jugador.get_world_3d().direct_space_state.intersect_ray(rayo)
	p.y = float(golpe["position"].y) if not golpe.is_empty() else jugador.global_position.y
	return p


static func dar_vehiculo(tipo_v: String, jugador: Node3D) -> String:
	var gestor: Node = jugador.get_tree().get_first_node_in_group("gestor_vehiculos")
	if gestor == null:
		return "No se puede crear el vehículo ahora."
	var giro: float = float(jugador.get("_giro"))
	var largo: float = float(Vehiculo.TIPOS[tipo_v]["largo"])
	var p: Vector3 = punto_delante(jugador, 1.0 + largo / 2.0)
	p.y += 0.15
	var id_v: String = gestor.entregar(tipo_v, p, giro)
	return "Vehículo creado: %s (es tuyo, id %s)." % [Vehiculo.TIPOS[tipo_v]["nombre"], id_v]


static func dar_npc(tipo_n: String, cantidad: int, jugador: Node3D) -> String:
	var padre: Node = jugador.get_parent()
	for i in mini(cantidad, 20):
		var p: Vector3 = punto_delante(jugador, 4.0, (i - (mini(cantidad, 20) - 1) / 2.0) * 1.5)
		var n: Node3D = null
		match tipo_n:
			"guardia":
				n = Guardia.new()
				n.refuerzo = true
				n.estrellas_minimas = 0
			"maton":
				n = Maton.new()
			"jefe":
				n = Maton.new()
				n.jefe = true
			"recluta":
				n = Maton.new()
				n.aliado = true
			"vecino":
				n = Vecino.new()
				n.atento = true
		if n == null:
			return "No sé crear ese PNJ."
		padre.add_child(n)
		n.global_position = p + Vector3(0, 0.3, 0)
		if "visible" in n:
			n.visible = true
	return "Aparecen %d delante de ti." % mini(cantidad, 20)
