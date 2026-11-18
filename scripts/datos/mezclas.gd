# mezclas.gd
# -----------------------------------------------------------------------------
# EL GENERADOR DE RECETAS. En el caldero puedes echar de 2 a 4 ingredientes
# (hierbas que cultivas y aditivos que compras). Cada combinación distinta da
# una poción distinta, con nombre, color, precio y efectos propios:
#
#   * Las pociones "de autor" (GameData.POCIONES) siguen igual.
#   * Cualquier otra combinación válida se genera aquí, siempre igual para los
#     mismos ingredientes (da igual el orden), sin tener que escribirla a mano.
#
# Con 10 hierbas y 8 aditivos salen 7.296 mezclas posibles. Para tener más basta
# con añadir un ingrediente a INGREDIENTES (y su objeto en objetos.gd).
#
# Cómo se decide el resultado (ver _generar):
#   1. Cada ingrediente aporta 1 o 2 efectos (el primero pesa el doble).
#   2. Se suman los pesos y se aplican las REACCIONES (dos efectos que chocan se
#      transforman en otro, como en Schedule I).
#   3. Los efectos buenos más fuertes (máx. 3) son los efectos de la poción.
#   4. Los malos que sobran (máx. 2) son efectos secundarios: pueden salir o no
#      al beberla, con la probabilidad que se enseña en la descripción.
#   5. El precio sale de lo caro que sea cada ingrediente y de cuántos efectos
#      buenos tiene.
#
# Los identificadores de las pociones generadas son "m_" + los ingredientes
# cortos ordenados y unidos con "+": por ejemplo "m_bruma+miel+raiz_ardiente".
# El objeto es "pocion_m_..." y su paquete "paquete_m_...".
# -----------------------------------------------------------------------------
extends RefCounted

const Efectos = preload("res://scripts/datos/efectos.gd")

const MIN_INGREDIENTES: int = 2
const MAX_INGREDIENTES: int = 4
# Curva de progresión (docs/DISENO.md, 6.3): cuántos ingredientes caben en el
# caldero según tu nivel: {nivel mínimo: ingredientes}. Cada ingrediente tiene
# además su propio nivel en la tienda (campo "nivel" de su semilla o aditivo en
# objetos.gd), así que lo más potente no se desbloquea hasta tarde.
const CASILLAS_POR_NIVEL: Dictionary = {1: 2, 6: 3, 9: 4}
# Cada ingrediente de más multiplica el precio (3 ingredientes = x1,4; 4 = x1,8).
const PRECIO_MAXIMO: float = 650.0
const PRECIO_POR_INGREDIENTE_EXTRA: float = 0.4
const MAX_EFECTOS: int = 3
const MAX_SECUNDARIOS: int = 2

# "Corto" es el nombre que sale en el nombre de la poción; "efectos" son los
# efectos que aporta (el primero pesa el doble); "valor" es lo que aporta al
# precio de la poción.
const INGREDIENTES: Dictionary = {
	# --------------------------------- Hierbas -------------------------------
	"hierba_bruma": {"corto": "Bruma", "efectos": ["calma", "euforia"], "valor": 10},
	"hierba_sepulcral": {"corto": "Sepulcro", "efectos": ["sigilo", "somnolencia"], "valor": 15},
	"hierba_raiz_ardiente": {"corto": "Raíz Ardiente", "efectos": ["velocidad", "temblor"], "valor": 14},
	"hierba_lirio_lunar": {"corto": "Lirio Lunar", "efectos": ["vision"], "valor": 60},
	"hierba_cardo_hierro": {"corto": "Cardo de Hierro", "efectos": ["resistencia", "lentitud"], "valor": 22},
	"hierba_musgo_dulce": {"corto": "Musgo Dulce", "efectos": ["regeneracion"], "valor": 12},
	"hierba_baya_noche": {"corto": "Baya de Noche", "efectos": ["sigilo", "paranoia"], "valor": 30},
	"hierba_flor_sol": {"corto": "Flor de Sol", "efectos": ["fuerza", "euforia"], "valor": 34},
	"hierba_ortiga_negra": {"corto": "Ortiga Negra", "efectos": ["veneno", "fuerza"], "valor": 12},
	"hierba_hongo_risueno": {"corto": "Hongo Risueño", "efectos": ["euforia", "mareo"], "valor": 20},
	# --------------------------------- Aditivos ------------------------------
	"aditivo_miel": {"corto": "Miel", "efectos": ["carisma"], "valor": 8},
	"aditivo_sal": {"corto": "Sal Gorda", "efectos": ["concentracion"], "valor": 6},
	"aditivo_azufre": {"corto": "Azufre", "efectos": ["velocidad", "nauseas"], "valor": 9},
	"aditivo_vinagre": {"corto": "Vinagre", "efectos": ["concentracion", "nauseas"], "valor": 7},
	"aditivo_ceniza": {"corto": "Ceniza", "efectos": ["sigilo"], "valor": 7},
	"aditivo_muelle": {"corto": "Muelle Oxidado", "efectos": ["salto"], "valor": 14},
	"aditivo_arsenico": {"corto": "Arsénico", "efectos": ["veneno"], "valor": 40},
	"aditivo_esencia": {"corto": "Esencia de Rosa", "efectos": ["carisma", "euforia"], "valor": 25},
}

# Cuando dos efectos coinciden en una mezcla se transforman: [a, b, resultado].
const REACCIONES: Array = [
	["veneno", "regeneracion", "resistencia"],   # Un antídoto.
	["euforia", "somnolencia", "calma"],
	["velocidad", "lentitud", "salto"],
	["sigilo", "paranoia", "vision"],
	["nauseas", "calma", "regeneracion"],
	["fuerza", "temblor", "velocidad"],
	["mareo", "concentracion", "vision"],
]

# Primera palabra del nombre y su género, para que concuerde el epíteto.
const FORMAS: Array = [
	["Elixir", 0], ["Tónico", 0], ["Brebaje", 0], ["Infusión", 1], ["Filtro", 0], ["Poción", 1],
	["Néctar", 0], ["Decocción", 1], ["Extracto", 0], ["Esencia", 1], ["Jarabe", 0], ["Tisana", 1],
]
# Frase que sale al vender una poción generada.
const FRASES: Array = [
	"El cliente la prueba, se estremece y asiente despacio.",
	"El cliente sonríe satisfecho y guarda el frasco bajo la capa.",
	"El cliente la huele, arruga la nariz... y paga igualmente.",
	"El cliente murmura que su cuñado también querrá una.",
	"El cliente se la bebe de un trago y se va tarareando.",
	"El cliente jura que no ha visto nada y que no te conoce.",
]
const GRADOS: Array = ["", " Añejo", " Fino", " Concentrado", " Suave", " Espeso"]

# Duración base que se usa para efectos malos (fracción de la normal).
const FACTOR_DURACION_MALO: float = 0.7

static var _cache: Dictionary = {}          # id de poción -> info ya calculada.
static var _cache_objetos: Dictionary = {}  # id de objeto -> datos de objeto ya calculados.
static var _de_autor: Dictionary = {}       # clave de ingredientes -> id de poción de autor.
static var _corto_a_item: Dictionary = {}   # "bruma" -> "hierba_bruma"


# ------------------------------- Ingredientes ---------------------------------

# Cuántos ingredientes caben en el caldero a este nivel.
static func max_ingredientes(nivel: int) -> int:
	var r: int = MIN_INGREDIENTES
	for n in CASILLAS_POR_NIVEL:
		if nivel >= int(n):
			r = maxi(r, int(CASILLAS_POR_NIVEL[n]))
	return mini(r, MAX_INGREDIENTES)


static func es_ingrediente(item_id: String) -> bool:
	return INGREDIENTES.has(item_id)


# "hierba_raiz_ardiente" -> "raiz_ardiente".
static func corto_de(item_id: String) -> String:
	return item_id.trim_prefix("hierba_").trim_prefix("aditivo_")


static func _preparar() -> void:
	if not _corto_a_item.is_empty():
		return
	for item in INGREDIENTES:
		_corto_a_item[corto_de(item)] = item
	for id in GameData.POCIONES:
		var items: Array = items_de_autor(id)
		_de_autor[_clave(items)] = id


static func _clave(items: Array) -> String:
	var cortos: Array = []
	for item in items:
		cortos.append(corto_de(str(item)))
	cortos.sort()
	return "+".join(PackedStringArray(cortos))


# Los ingredientes (objetos) de una poción de autor.
static func items_de_autor(id: String) -> Array:
	var r: Array = []
	for h in GameData.POCIONES[id]["receta"]:
		r.append("hierba_" + str(h))
	return r


# Cuántas mezclas distintas permiten los ingredientes que hay ahora.
static func total_combinaciones() -> int:
	var n: int = INGREDIENTES.size()
	var total: int = 0
	for k in range(MIN_INGREDIENTES, MAX_INGREDIENTES + 1):
		# Combinaciones con repetición: C(n + k - 1, k).
		var c: float = 1.0
		for i in k:
			c = c * float(n + i) / float(i + 1)
		total += int(round(c))
	return total


# ---------------------------------- Búsqueda ----------------------------------

# Recibe los objetos del caldero (por ejemplo ["hierba_bruma", "aditivo_miel"])
# y devuelve el id de la poción que sale, o "" si no se puede hacer nada.
static func buscar(items: Array) -> String:
	_preparar()
	if items.size() < MIN_INGREDIENTES or items.size() > MAX_INGREDIENTES:
		return ""
	for item in items:
		if not INGREDIENTES.has(str(item)):
			return ""
	var clave: String = _clave(items)
	if _de_autor.has(clave):
		return _de_autor[clave]
	return "m_" + clave


# ¿Es un id de poción que existe (de autor o generado y bien formado)?
static func es_valida(id: String) -> bool:
	if GameData.POCIONES.has(id):
		return true
	return not _items_de_generada(id).is_empty()


# Los objetos que forman una poción (de autor o generada).
static func items_de_receta(id: String) -> Array:
	if GameData.POCIONES.has(id):
		return items_de_autor(id)
	return _items_de_generada(id)


# Devuelve [] si el id no es de una mezcla generada válida.
static func _items_de_generada(id: String) -> Array:
	if not id.begins_with("m_"):
		return []
	_preparar()
	var items: Array = []
	for corto in id.trim_prefix("m_").split("+"):
		if not _corto_a_item.has(corto):
			return []
		items.append(_corto_a_item[corto])
	if items.size() < MIN_INGREDIENTES or items.size() > MAX_INGREDIENTES:
		return []
	# El id tiene que estar en forma canónica (ordenado), si no, sería un duplicado.
	if "m_" + _clave(items) != id:
		return []
	return items


static func texto_receta(id: String) -> String:
	var nombres: PackedStringArray = []
	for item in items_de_receta(id):
		nombres.append(INGREDIENTES[item]["corto"] if not GameData.HIERBAS.has(corto_de(item)) \
				else GameData.HIERBAS[corto_de(item)]["nombre"])
	return " + ".join(nombres)


# ----------------------------------- Info -------------------------------------

# Todo lo que hay que saber de una poción:
#  nombre, color, precio, efecto (frase), efectos y secundarios (listas de
#  {"id", "dur", "f", "prob"}), receta (objetos).
static func info(id: String) -> Dictionary:
	if GameData.POCIONES.has(id):
		var p: Dictionary = GameData.POCIONES[id]
		return {
			"nombre": p["nombre"], "color": p["color"], "precio": p["precio"], "efecto": p["efecto"],
			"efectos": _normalizar(p.get("efectos", [])), "secundarios": _normalizar(p.get("secundarios", [])),
			"receta": items_de_autor(id),
			"resumen": texto_efectos(_normalizar(p.get("efectos", [])), _normalizar(p.get("secundarios", []))),
		}
	if _cache.has(id):
		return _cache[id]
	var items: Array = _items_de_generada(id)
	if items.is_empty():
		return {}
	var r: Dictionary = _generar(id, items)
	_cache[id] = r
	return r


# Pone "f" y "prob" a las entradas de las pociones de autor si no los tienen.
static func _normalizar(lista: Array) -> Array:
	var r: Array = []
	for e in lista:
		var d: Dictionary = e.duplicate()
		if not d.has("f"):
			d["f"] = 1.0
		if not d.has("prob"):
			d["prob"] = 1.0
		r.append(d)
	return r


static func _generar(id: String, items: Array) -> Dictionary:
	# 1. Pesos de cada efecto.
	var pesos: Dictionary = {}
	var valor: float = 0.0
	var color: Color = Color(0, 0, 0)
	var cuenta: Dictionary = {}   # Cuántas veces sale cada ingrediente.
	for item in items:
		var d: Dictionary = INGREDIENTES[item]
		var efs: Array = d["efectos"]
		for i in efs.size():
			pesos[efs[i]] = int(pesos.get(efs[i], 0)) + (2 if i == 0 else 1)
		valor += float(d["valor"])
		color += _color_de(item)
		cuenta[item] = int(cuenta.get(item, 0)) + 1
	color /= float(items.size())
	color.a = 1.0
	# 2. Reacciones.
	for r in REACCIONES:
		if pesos.has(r[0]) and pesos.has(r[1]):
			var w: int = maxi(int(pesos[r[0]]), int(pesos[r[1]]))
			pesos.erase(r[0])
			pesos.erase(r[1])
			pesos[r[2]] = int(pesos.get(r[2], 0)) + w
	# 3. Buenos y malos, de más a menos peso (el id desempata para que sea siempre igual).
	var buenos: Array = []
	var malos: Array = []
	for e in pesos:
		(buenos if Efectos.es_bueno(e) else malos).append(e)
	buenos.sort_custom(func(a: String, b: String) -> bool:
		return pesos[a] > pesos[b] or (pesos[a] == pesos[b] and a < b))
	malos.sort_custom(func(a: String, b: String) -> bool:
		return pesos[a] > pesos[b] or (pesos[a] == pesos[b] and a < b))
	var efectos: Array = []
	var secundarios: Array = []
	if buenos.is_empty():
		# Mezcla solo mala: sus efectos salen siempre (es un veneno o una porquería).
		for e in malos.slice(0, MAX_EFECTOS):
			efectos.append(_registro(e, int(pesos[e]), 1.0))
	else:
		for e in buenos.slice(0, MAX_EFECTOS):
			efectos.append(_registro(e, int(pesos[e]), 1.0))
		for e in malos.slice(0, MAX_SECUNDARIOS):
			secundarios.append(_registro(e, int(pesos[e]), clampf(0.2 + 0.12 * float(pesos[e]), 0.2, 0.85)))
	# 4. Precio.
	var precio: float = valor * 1.6 + 8.0 * float(buenos.slice(0, MAX_EFECTOS).size())
	precio *= 1.0 + PRECIO_POR_INGREDIENTE_EXTRA * float(items.size() - MIN_INGREDIENTES)
	if buenos.is_empty():
		precio *= 0.35   # Un veneno puro vale poco: no tiene gracia como poción de venta.
	precio = minf(precio, PRECIO_MAXIMO)
	var nombre: String = _nombre(id, items, cuenta, efectos[0]["id"] if not efectos.is_empty() else "")
	var res: Dictionary = {
		"nombre": nombre, "color": color, "precio": maxi(5, int(round(precio))),
		"efectos": efectos, "secundarios": secundarios, "receta": items,
	}
	res["resumen"] = texto_efectos(efectos, secundarios)
	res["efecto"] = FRASES[_hash(id + "f") % FRASES.size()]
	return res


static func _registro(id_efecto: String, peso: int, prob: float) -> Dictionary:
	var base: float = float(Efectos.datos(id_efecto)["dur"])
	var dur: float = base * (0.8 + 0.1 * float(peso))
	if not Efectos.es_bueno(id_efecto) and prob < 1.0:
		dur *= FACTOR_DURACION_MALO
	dur = maxf(10.0, round(dur / 5.0) * 5.0)
	return {"id": id_efecto, "dur": dur, "f": clampf(0.8 + 0.12 * float(peso), 0.8, 1.6), "prob": prob}


# El color con que cada ingrediente tiñe la mezcla.
static func _color_de(item: String) -> Color:
	var c: String = corto_de(item)
	if GameData.HIERBAS.has(c):
		return GameData.HIERBAS[c]["color"]
	var h: int = _hash(item)
	return Color.from_hsv(float(h % 360) / 360.0, 0.55, 0.85)


static func _hash(texto: String) -> int:
	var h: int = 2166136261
	for i in texto.length():
		h = ((h ^ texto.unicode_at(i)) * 16777619) & 0x7fffffff
	return h


static func _nombre(id: String, items: Array, cuenta: Dictionary, id_efecto: String) -> String:
	var h: int = _hash(id)
	var forma: Array = FORMAS[h % FORMAS.size()]
	var epiteto: String = ""
	if id_efecto != "":
		epiteto = " " + str(Efectos.datos(id_efecto)["epiteto"][int(forma[1])])
	# Los dos ingredientes más abundantes (los empates, por orden alfabético).
	var distintos: Array = cuenta.keys()
	distintos.sort_custom(func(a: String, b: String) -> bool:
		return cuenta[a] > cuenta[b] or (cuenta[a] == cuenta[b] and a < b))
	var de: String = " de " + str(INGREDIENTES[distintos[0]]["corto"])
	if distintos.size() > 1:
		de += " y " + str(INGREDIENTES[distintos[1]]["corto"])
	var grado: String = GRADOS[(h / 7) % GRADOS.size()] if items.size() >= 3 else ""
	return "%s%s%s%s" % [forma[0], epiteto, de, grado]


static func texto_efectos(efectos: Array, secundarios: Array) -> String:
	var t: String = "Efectos: " + Efectos.resumen(efectos) + "."
	if not secundarios.is_empty():
		t += " Efectos secundarios posibles: " + Efectos.resumen(secundarios) + "."
	return t


# ------------------------- Objetos de las pociones ----------------------------

# Si "objeto" es "pocion_m_..." o "paquete_m_..." de una mezcla válida, devuelve
# sus datos como objeto de inventario; si no, un diccionario vacío.
static func objeto(objeto_id: String) -> Dictionary:
	if _cache_objetos.has(objeto_id):
		return _cache_objetos[objeto_id]
	var r: Dictionary = _crear_objeto(objeto_id)
	if not r.is_empty():
		_cache_objetos[objeto_id] = r
	return r


static func _crear_objeto(objeto_id: String) -> Dictionary:
	var paquete: bool = objeto_id.begins_with("paquete_m_")
	if not paquete and not objeto_id.begins_with("pocion_m_"):
		return {}
	var id: String = objeto_id.trim_prefix("paquete_" if paquete else "pocion_")
	var i: Dictionary = info(id)
	if i.is_empty():
		return {}
	if paquete:
		return {
			"nombre": "Paquete: " + i["nombre"], "tipo": "paquete", "pila": 20, "precio": 0,
			"tienda": "", "nivel": 1, "habilidad": "", "color": Color(0.75, 0.6, 0.4), "forma": "saco",
			"descripcion": "Poción empaquetada. Los clientes de los encargos pagan un 30% más.",
		}
	return {
		"nombre": i["nombre"], "tipo": "pocion", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "", "color": i["color"], "forma": "frasco",
		"descripcion": "Poción prohibida (se vende en la ventanilla o se bebe con el clic izquierdo). " + i["resumen"],
	}
