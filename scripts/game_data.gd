# game_data.gd
# -----------------------------------------------------------------------------
# Aquí están TODOS los datos del juego: qué hierbas existen, qué pociones se
# pueden hacer y cuánto vale cada cosa.
#
# Si añades una hierba "x", crea también en scripts/datos/objetos.gd sus
# objetos "semilla_x" y "hierba_x". Cada poción "y" necesita su objeto "pocion_y".
#
# "class_name GameData" hace que podamos escribir GameData.HIERBAS desde
# cualquier otro script sin tener que cargarlo a mano.
# -----------------------------------------------------------------------------
class_name GameData
extends RefCounted


# Dólares con los que empiezas la partida.
const DINERO_INICIAL: int = 200

# Dinero que necesitas para "ganar" el prototipo (pagar el alquiler al casero).
const OBJETIVO_DINERO: int = 1000

# Cuántos ingredientes caben en el caldero antes de mezclar.
const INGREDIENTES_POR_POCION: int = 2


# Hierbas que se pueden plantar en el huerto.
#  - nombre: lo que ve el jugador.
#  - forma: cómo se dibuja ("hoja" = planta de hojas dentadas, "seta" = hongo).
#  - color: color de la planta y del líquido en el caldero.
#  - tiempo: segundos que tarda en crecer.
#  - precio_semilla: dólares que cuesta una semilla en el puesto del mercado.
const HIERBAS: Dictionary = {
	# La hierba estrella: ilegal, de hojas dentadas, cuyo humo hace soñar.
	"bruma": {
		"nombre": "Hoja de Bruma",
		"forma": "hoja",
		"color": Color(0.3, 0.6, 0.35),
		"tiempo": 15.0,
		"precio_semilla": 10,
	},
	# Un hongo pálido que solo crece donde hay huesos.
	"sepulcral": {
		"nombre": "Hongo Sepulcral",
		"forma": "seta",
		"color": Color(0.62, 0.58, 0.7),
		"tiempo": 25.0,
		"precio_semilla": 15,
	},
}


# Lo que cuesta alquilar la casa del callejón (pago único en este prototipo).
const PRECIO_ALQUILER: int = 100

# Pociones que se pueden mezclar.
#  - receta: los ingredientes que hay que echar al caldero (el orden da igual).
#  - precio: lo que paga el cliente.
#  - efecto: una frase (oscura y algo absurda) que se muestra al venderla.
const POCIONES: Dictionary = {
	"humo": {
		"nombre": "Humo del Olvido",
		"color": Color(0.35, 0.7, 0.45),
		"receta": ["bruma", "bruma"],
		"precio": 40,
		"efecto": "El cliente olvida su nombre, sus deudas y dónde enterró a su suegra.",
	},
	"sueno": {
		"nombre": "Elixir del Mal Sueño",
		"color": Color(0.45, 0.55, 0.6),
		"receta": ["bruma", "sepulcral"],
		"precio": 65,
		"efecto": "Esta noche soñará con sus antepasados. Ellos no están contentos.",
	},
	"sombra": {
		"nombre": "Tónico de la Sombra Propia",
		"color": Color(0.4, 0.3, 0.55),
		"receta": ["sepulcral", "sepulcral"],
		"precio": 85,
		"efecto": "La sombra del cliente se marcha por su cuenta. Volverá... quizá.",
	},
}


# Recibe la lista de ingredientes que hay en el caldero y devuelve el
# identificador de la poción que sale (por ejemplo "humo").
# Si no coincide con ninguna receta, devuelve un texto vacío "".
static func buscar_pocion(ingredientes: Array) -> String:
	# Ordenamos para que ["sepulcral", "bruma"] y ["bruma", "sepulcral"] cuenten igual.
	var ordenados: Array = []
	ordenados.append_array(ingredientes)
	ordenados.sort()
	for id_pocion in POCIONES:
		var receta: Array = []
		receta.append_array(POCIONES[id_pocion]["receta"])
		receta.sort()
		if receta == ordenados:
			return id_pocion
	return ""


# Devuelve el texto de la receta, por ejemplo "Hoja de Bruma + Hongo Sepulcral".
static func texto_receta(id_pocion: String) -> String:
	var nombres: PackedStringArray = []
	for id_hierba in POCIONES[id_pocion]["receta"]:
		nombres.append(HIERBAS[id_hierba]["nombre"])
	return " + ".join(nombres)
