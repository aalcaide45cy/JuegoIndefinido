# propiedades.gd
# -----------------------------------------------------------------------------
# Lista de viviendas y huertos que se pueden alquilar o comprar en la
# inmobiliaria. "alquiler" se paga una vez (por adelantado); comprar cuesta
# 25 veces el alquiler y al vender te devuelven el 70% de lo que pagaste.
# El id coincide con el de la casa (Barrio.vivienda) o el huerto (BarrioCampo).
# -----------------------------------------------------------------------------
extends RefCounted

const FACTOR_COMPRA: int = 25
const DEVOLUCION_VENTA: float = 0.7

const LISTA: Array = [
	{"id": "plaza", "tipo": "casa", "nombre": "Casa de la plaza", "alquiler": 100, "m2": 80},
	{"id": "pozo", "tipo": "casa", "nombre": "Casa del Pozo", "alquiler": 160, "m2": 80},
	{"id": "boticario", "tipo": "casa", "nombre": "Casa del Boticario", "alquiler": 250, "m2": 80},
	{"id": "torcida", "tipo": "casa", "nombre": "Casa Torcida", "alquiler": 400, "m2": 80},
	{"id": "atico", "tipo": "casa", "nombre": "Ático de la avenida", "alquiler": 700, "m2": 80},
	{"id": "huerto_a", "tipo": "huerto", "nombre": "Huerto pequeño A", "alquiler": 80, "m2": 144},
	{"id": "huerto_b", "tipo": "huerto", "nombre": "Huerto pequeño B", "alquiler": 80, "m2": 144},
	{"id": "huerto_c", "tipo": "huerto", "nombre": "Huerto mediano C", "alquiler": 180, "m2": 288},
	{"id": "huerto_d", "tipo": "huerto", "nombre": "Huerto mediano D", "alquiler": 180, "m2": 288},
	{"id": "huerto_e", "tipo": "huerto", "nombre": "Huerto grande E", "alquiler": 400, "m2": 572},
	{"id": "huerto_f", "tipo": "huerto", "nombre": "Huerto grande F", "alquiler": 400, "m2": 572},
	{"id": "huerto_g", "tipo": "huerto", "nombre": "Gran huerto G", "alquiler": 900, "m2": 1020},
	{"id": "huerto_h", "tipo": "huerto", "nombre": "Gran huerto H", "alquiler": 900, "m2": 1020},
]


static func precio_compra(p: Dictionary) -> int:
	return int(p["alquiler"]) * FACTOR_COMPRA


# ----------------------- Propiedades del mundo grande ------------------------
# Las casas y huertos de aldeas, pueblos y ciudades del mundo generado tienen
# ids que empiezan por "w_" y su ficha se calcula del id (ver generador_mundo.gd).

static func es_del_mundo(id: String) -> bool:
	return id.begins_with("w_")


static func de_id(id: String) -> Dictionary:
	return GeneradorMundo.propiedad(id)


# Las casas y huertos del mundo grande que tienes ahora (para venderlos en la inmobiliaria).
static func del_mundo_propias() -> Array:
	var out: Array = []
	for id in Juego.viviendas.keys() + Juego.huertos.keys():
		if es_del_mundo(str(id)):
			var p: Dictionary = de_id(str(id))
			if not p.is_empty():
				out.append(p)
	return out


# Alquila o compra una propiedad. Devuelve true si se pudo pagar.
static func contratar(p: Dictionary, comprar: bool) -> bool:
	var coste: int = precio_compra(p) if comprar else int(p["alquiler"])
	if not Juego.gastar(coste):
		Juego.avisar("No te llega el dinero: piden %d $." % coste)
		return false
	if p["tipo"] == "huerto":
		Juego.huertos[p["id"]] = true
	else:
		Juego.viviendas[p["id"]] = true
	if comprar:
		Juego.en_propiedad[p["id"]] = true
		Juego.avisar("¡Compraste: %s!" % p["nombre"])
	else:
		Juego.avisar("Alquilaste: %s." % p["nombre"])
	Juego.cambio.emit()
	return true
