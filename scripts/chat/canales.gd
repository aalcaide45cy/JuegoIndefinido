# canales.gd
# -----------------------------------------------------------------------------
# Datos de los canales del chat: nombre, color, alcance y límites. Son solo
# datos (sin nodos), así que los usan igual el servidor y el cliente.
#
#   CERCANO  -> lo oyen los jugadores a menos de 25 m
#   GRITAR   -> lo oyen los jugadores a menos de 120 m (sale en mayúsculas)
#   GRUPO    -> los miembros de tu grupo, estén donde estén
#   PRIVADO  -> solo la persona a la que escribes (y tú)
#   FACCION  -> los miembros de tu facción
#   SISTEMA  -> avisos del juego (cobros, encargos, policía, cosechas...);
#               solo los manda el servidor, nadie puede escribir ahí
# -----------------------------------------------------------------------------
class_name Canales
extends RefCounted

enum Id { TODO, CERCANO, GRUPO, PRIVADO, FACCION, GRITAR, SISTEMA }

const ORDEN: Array = [Id.TODO, Id.CERCANO, Id.GRUPO, Id.PRIVADO, Id.FACCION, Id.GRITAR, Id.SISTEMA]
const ESCRIBIBLES: Array = [Id.CERCANO, Id.GRUPO, Id.PRIVADO, Id.FACCION, Id.GRITAR]

const ALCANCE_CERCANO: float = 25.0
const ALCANCE_GRITAR: float = 120.0

const DATOS: Dictionary = {
	Id.TODO: {"nombre": "Todo", "clave": "todo", "color": Color(0.92, 0.95, 0.90), "atajo": ""},
	Id.CERCANO: {"nombre": "Cercano", "clave": "cercano", "color": Color(0.96, 0.96, 0.88), "atajo": "c"},
	Id.GRUPO: {"nombre": "Grupo", "clave": "grupo", "color": Color(0.55, 0.72, 1.0), "atajo": "g"},
	Id.PRIVADO: {"nombre": "Privado", "clave": "privado", "color": Color(1.0, 0.62, 0.86), "atajo": "p"},
	Id.FACCION: {"nombre": "Facción", "clave": "faccion", "color": Color(0.50, 0.92, 0.60), "atajo": "f"},
	Id.GRITAR: {"nombre": "Gritar", "clave": "gritar", "color": Color(1.0, 0.62, 0.30), "atajo": "gr"},
	Id.SISTEMA: {"nombre": "Sistema", "clave": "sistema", "color": Color(1.0, 0.82, 0.32), "atajo": ""},
}

# Categorías de los avisos del sistema (y su color).
const CATEGORIAS: Dictionary = {
	"cobros": {"nombre": "Cobros", "color": Color(1.0, 0.86, 0.35)},
	"encargos": {"nombre": "Encargos", "color": Color(0.42, 0.82, 1.0)},
	"policia": {"nombre": "Policía", "color": Color(1.0, 0.45, 0.42)},
	"cosechas": {"nombre": "Cosechas", "color": Color(0.55, 0.92, 0.55)},
	"otros": {"nombre": "Sistema", "color": Color(0.80, 0.84, 0.80)},
}

# Límites de tasa (por jugador): como mucho "max" mensajes cada "ventana" segundos,
# y una espera mínima entre dos mensajes del mismo canal.
const LIMITE_MENSAJES: int = 5
const VENTANA_SEG: float = 8.0
const ESPERA_GRITAR: float = 8.0
const ESPERA_MIN: float = 0.6
const MAX_LARGO: int = 200
const MAX_LARGO_NOMBRE: int = 20
const MAX_HISTORIAL: int = 300
const MAX_REPETIDOS: int = 3          # El mismo texto 3 veces seguidas = spam.
const SEG_REPETIDOS: float = 30.0
const INFRACCIONES_PARA_SILENCIO: int = 3
const SEG_SILENCIO: float = 60.0


static func nombre(id: int) -> String:
	return String(DATOS[id]["nombre"])


static func color(id: int) -> Color:
	return DATOS[id]["color"]


static func desde_clave(clave: String) -> int:
	for id in DATOS:
		if DATOS[id]["clave"] == clave or DATOS[id]["atajo"] == clave:
			return id
	return -1


# Lo que se pinta en la lista: los canales de "Todo" son todos menos él mismo.
static func es_escribible(id: int) -> bool:
	return ESCRIBIBLES.has(id)
