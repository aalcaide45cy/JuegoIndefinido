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

# Cuántos ingredientes caben en el caldero depende del nivel (2, 3 o 4): ver
# Mezclas.CASILLAS_POR_NIVEL en scripts/datos/mezclas.gd, que también genera una
# poción distinta por cada combinación.

const Mezclas = preload("res://scripts/datos/mezclas.gd")


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
		"tiempo": 60.0,
		"precio_semilla": 10,
	},
	# Un hongo pálido que solo crece donde hay huesos.
	"sepulcral": {
		"nombre": "Hongo Sepulcral",
		"forma": "seta",
		"color": Color(0.62, 0.58, 0.7),
		"tiempo": 120.0,
		"precio_semilla": 15,
	},
	# Hierbas nuevas (cada una aporta efectos distintos a las pociones; ver mezclas.gd).
	"raiz_ardiente": {
		"nombre": "Raíz Ardiente", "forma": "hoja", "color": Color(0.85, 0.3, 0.15),
		"tiempo": 45.0, "precio_semilla": 14,
	},
	"lirio_lunar": {
		"nombre": "Lirio Lunar", "forma": "hoja", "color": Color(0.55, 0.7, 0.95),
		"tiempo": 150.0, "precio_semilla": 20,
	},
	"cardo_hierro": {
		"nombre": "Cardo de Hierro", "forma": "hoja", "color": Color(0.5, 0.55, 0.6),
		"tiempo": 75.0, "precio_semilla": 16,
	},
	"musgo_dulce": {
		"nombre": "Musgo Dulce", "forma": "hoja", "color": Color(0.5, 0.85, 0.4),
		"tiempo": 40.0, "precio_semilla": 12,
	},
	"baya_noche": {
		"nombre": "Baya de Noche", "forma": "hoja", "color": Color(0.3, 0.2, 0.5),
		"tiempo": 110.0, "precio_semilla": 15,
	},
	"flor_sol": {
		"nombre": "Flor de Sol", "forma": "hoja", "color": Color(0.95, 0.8, 0.25),
		"tiempo": 130.0, "precio_semilla": 16,
	},
	"ortiga_negra": {
		"nombre": "Ortiga Negra", "forma": "hoja", "color": Color(0.15, 0.3, 0.2),
		"tiempo": 35.0, "precio_semilla": 11,
	},
	"hongo_risueno": {
		"nombre": "Hongo Risueño", "forma": "seta", "color": Color(0.95, 0.6, 0.7),
		"tiempo": 80.0, "precio_semilla": 14,
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
		"efectos": [{"id": "calma", "dur": 90.0}, {"id": "euforia", "dur": 40.0}],
		"secundarios": [{"id": "mareo", "dur": 30.0, "prob": 0.4}],
	},
	"sueno": {
		"nombre": "Elixir del Mal Sueño",
		"color": Color(0.45, 0.55, 0.6),
		"receta": ["bruma", "sepulcral"],
		"precio": 65,
		"efecto": "Esta noche soñará con sus antepasados. Ellos no están contentos.",
		"efectos": [{"id": "sigilo", "dur": 100.0}],
		"secundarios": [{"id": "somnolencia", "dur": 40.0, "prob": 0.6}],
	},
	"sombra": {
		"nombre": "Tónico de la Sombra Propia",
		"color": Color(0.4, 0.3, 0.55),
		"receta": ["sepulcral", "sepulcral"],
		"precio": 85,
		"efecto": "La sombra del cliente se marcha por su cuenta. Volverá... quizá.",
		"efectos": [{"id": "sigilo", "dur": 150.0, "f": 1.3}, {"id": "vision", "dur": 120.0}],
		"secundarios": [{"id": "paranoia", "dur": 40.0, "prob": 0.5}],
	},
}


# Recibe los objetos que hay en el caldero (por ejemplo ["hierba_bruma",
# "aditivo_miel"]) y devuelve el identificador de la poción que sale (por
# ejemplo "humo" o "m_bruma+miel"). Si no se puede hacer nada, devuelve "".
static func buscar_pocion(items: Array) -> String:
	return Mezclas.buscar(items)


# Todos los datos de una poción (de autor o generada): ver Mezclas.info().
static func pocion(id: String) -> Dictionary:
	return Mezclas.info(id)


static func existe_pocion(id: String) -> bool:
	return Mezclas.es_valida(id)


# Devuelve el texto de la receta, por ejemplo "Hoja de Bruma + Hongo Sepulcral".
static func texto_receta(id_pocion: String) -> String:
	return Mezclas.texto_receta(id_pocion)


# Las pociones que los clientes pueden pedir: las de autor y las recetas que
# ya has descubierto tú.
static func pedibles() -> Array:
	var r: Array = POCIONES.keys()
	for id in Juego.recetario:
		if not POCIONES.has(id) and Mezclas.es_valida(id):
			r.append(id)
	return r
