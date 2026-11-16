# game_data.gd
# -----------------------------------------------------------------------------
# Aquí están TODOS los datos del juego: qué hierbas existen, qué pociones se
# pueden hacer y cuánto vale cada cosa.
#
# Si quieres añadir una hierba o una poción nueva, este es el único archivo
# que tienes que tocar. El resto del código lee de aquí.
#
# "class_name GameData" hace que podamos escribir GameData.HIERBAS desde
# cualquier otro script sin tener que cargarlo a mano.
# -----------------------------------------------------------------------------
class_name GameData
extends RefCounted


# Dinero con el que empiezas la partida.
const DINERO_INICIAL: int = 10

# Dinero que necesitas para "ganar" el prototipo (pagar el alquiler al casero).
const OBJETIVO_DINERO: int = 60

# Cuántos ingredientes caben en el caldero antes de mezclar.
const INGREDIENTES_POR_POCION: int = 2


# Hierbas que se pueden plantar en el huerto.
#  - nombre: lo que ve el jugador.
#  - color: color de la planta y del líquido en el caldero.
#  - tiempo: segundos que tarda en crecer.
#  - precio_semilla: monedas que cuesta plantarla.
const HIERBAS: Dictionary = {
	"risuena": {
		"nombre": "Hierba Risueña",
		"color": Color(0.45, 0.85, 0.35),
		"tiempo": 5.0,
		"precio_semilla": 2,
	},
	"seta": {
		"nombre": "Seta Saltarina",
		"color": Color(0.9, 0.35, 0.35),
		"tiempo": 8.0,
		"precio_semilla": 3,
	},
}


# Pociones que se pueden mezclar.
#  - receta: los ingredientes que hay que echar al caldero (el orden da igual).
#  - precio: lo que paga el cliente.
#  - efecto: una frase graciosa que se muestra al venderla.
const POCIONES: Dictionary = {
	"risa": {
		"nombre": "Poción de la Risa Tonta",
		"color": Color(0.55, 0.95, 0.45),
		"receta": ["risuena", "risuena"],
		"precio": 8,
		"efecto": "El cliente se ríe de una piedra durante una hora.",
	},
	"rebote": {
		"nombre": "Elixir del Rebote",
		"color": Color(0.95, 0.75, 0.3),
		"receta": ["risuena", "seta"],
		"precio": 13,
		"efecto": "El cliente rebota como una pelota al salir de la tienda.",
	},
	"bigote": {
		"nombre": "Tónico del Bigote Andante",
		"color": Color(0.75, 0.35, 0.85),
		"receta": ["seta", "seta"],
		"precio": 17,
		"efecto": "Al cliente le crece un bigote que camina solo.",
	},
}


# Recibe la lista de ingredientes que hay en el caldero y devuelve el
# identificador de la poción que sale (por ejemplo "risa").
# Si no coincide con ninguna receta, devuelve un texto vacío "".
static func buscar_pocion(ingredientes: Array) -> String:
	# Ordenamos para que ["seta", "risuena"] y ["risuena", "seta"] cuenten igual.
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


# Devuelve el texto de la receta, por ejemplo "Hierba Risueña + Seta Saltarina".
static func texto_receta(id_pocion: String) -> String:
	var nombres: PackedStringArray = []
	for id_hierba in POCIONES[id_pocion]["receta"]:
		nombres.append(HIERBAS[id_hierba]["nombre"])
	return " + ".join(nombres)
