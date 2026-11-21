# peluqueria.gd  (datos)
# -----------------------------------------------------------------------------
# Los locales de estética: PELUQUERÍA y BARBERÍA. Todo son datos para añadir
# locales parecidos (tatuajes, manicura, sastrería...) sin repetir código:
#
#   LOCALES: id del local -> nombre, oficio (el que se ficha ahí con Mayús+E) y
#            las opciones de aspecto que se pueden cambiar allí (claves de aspecto.gd).
#   PRECIOS: clave de aspecto -> precio de cada opción (mismo orden que en aspecto.gd).
#   MAGICOS: clave -> {índice: id de objeto que gasta} (tintes mágicos con Hoja de Bruma).
#   CLIENTES: lo que piden los clientes cuando trabajas de peluquero o barbero.
# La ventana está en scripts/ui/ventana_peluqueria.gd.
# -----------------------------------------------------------------------------
extends RefCounted

const LOCALES: Dictionary = {
	"peluqueria": {"nombre": "Peluquería", "oficio": "peluquero", "opciones": ["peinado", "pelo"]},
	"barberia": {"nombre": "Barbería", "oficio": "barbero", "opciones": ["peinado", "barba"]},
}

const PRECIOS: Dictionary = {
	"peinado": [8, 12, 6, 15, 12, 18],
	"pelo": [10, 10, 10, 12, 10, 14, 45, 45],
	"barba": [0, 6, 8, 10, 14],
}

# Los tintes verde y violeta llevan una hoja de bruma (además del dinero).
const MAGICOS: Dictionary = {
	"pelo": {6: "hierba_bruma", 7: "hierba_bruma"},
}

# Descuento del peluquero/barbero en su propio local.
const DESCUENTO_OFICIO: float = 0.5

# Clientes del oficio: cada cliente pide un peinado (y un color o una barba).
const PIDE_PEINADO: Array = [0, 1, 2, 3, 4, 5]
const PIDE_COLOR: Array = [0, 1, 2, 3, 4, 5]
const PIDE_BARBA: Array = [1, 2, 3, 4]


static func existe(local: String) -> bool:
	return LOCALES.has(local)


static func nombre(local: String) -> String:
	return str(LOCALES[local]["nombre"]) if LOCALES.has(local) else ""


static func opciones(local: String) -> Array:
	return LOCALES[local]["opciones"] if LOCALES.has(local) else []


static func precio_opcion(clave: String, indice: int) -> int:
	var l: Array = PRECIOS.get(clave, [])
	return int(l[indice]) if indice >= 0 and indice < l.size() else 0


# Objeto que gasta esa opción (tinte mágico) o "".
static func objeto_magico(clave: String, indice: int) -> String:
	return str((MAGICOS.get(clave, {}) as Dictionary).get(indice, ""))


# Precio de pasar del aspecto "actual" al "nuevo" en este local (solo cuenta lo que cambia).
static func precio_cambio(local: String, actual: Dictionary, nuevo: Dictionary) -> int:
	var total: int = 0
	for clave in opciones(local):
		if int(actual.get(clave, 0)) != int(nuevo.get(clave, 0)):
			total += precio_opcion(clave, int(nuevo.get(clave, 0)))
	return total


# Objetos mágicos que hacen falta para el cambio: {id: cantidad}.
static func objetos_cambio(local: String, actual: Dictionary, nuevo: Dictionary) -> Dictionary:
	var r: Dictionary = {}
	for clave in opciones(local):
		var n: int = int(nuevo.get(clave, 0))
		if int(actual.get(clave, 0)) != n:
			var o: String = objeto_magico(clave, n)
			if o != "":
				r[o] = int(r.get(o, 0)) + 1
	return r


# Un cliente al azar para el oficio: {texto, aspecto (qué pide)}.
static func cliente_al_azar(local: String, rng: RandomNumberGenerator, Aspecto) -> Dictionary:
	var pide: Dictionary = {}
	pide["peinado"] = PIDE_PEINADO[rng.randi() % PIDE_PEINADO.size()]
	var texto: String = "Peinado %s" % str(Aspecto.PEINADOS[pide["peinado"]]).to_lower()
	if local == "barberia":
		pide["barba"] = PIDE_BARBA[rng.randi() % PIDE_BARBA.size()]
		texto += " y %s" % str(Aspecto.BARBAS[pide["barba"]]).to_lower()
	else:
		pide["pelo"] = PIDE_COLOR[rng.randi() % PIDE_COLOR.size()]
		texto += " en %s" % str(Aspecto.NOMBRES_PELO[pide["pelo"]]).to_lower()
	return {"texto": texto, "pide": pide}
