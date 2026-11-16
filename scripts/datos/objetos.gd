# objetos.gd
# -----------------------------------------------------------------------------
# TODOS los objetos del juego. Para añadir uno nuevo, copia una entrada y
# cámbiale los datos; el resto del código lo leerá solo.
#
# Campos de cada objeto:
#   nombre       lo que ve el jugador.
#   tipo         "herramienta", "material", "semilla", "hierba", "pocion",
#                "arma_cc" (cuerpo a cuerpo), "arma_fuego", "explosivo", "municion".
#   pila         cuántos caben en una casilla (1 = no se amontona; máximo 20).
#   precio       en dólares (0 = no se vende en tiendas).
#   tienda       dónde se compra: "herbolario", "ferreteria", "armeria" o "".
#   nivel        nivel mínimo del jugador para comprarlo (fase 3).
#   habilidad    habilidad necesaria para comprarlo, o "" (fase 3).
#   color        color de su icono y de su modelo en la mano.
#   forma        cómo se dibuja en la mano (mira jugador.gd, _crear_modelo_mano).
#   descripcion  una frase para la tienda.
# Algunos tienen datos extra (agua, daño, munición...) que usa su propio código.
# -----------------------------------------------------------------------------
class_name DatosObjetos
extends RefCounted

const PILA_MAXIMA: int = 20

const LISTA: Dictionary = {
	# ------------------------------ Cultivo -----------------------------------
	"semilla_bruma": {
		"nombre": "Semilla de Hoja de Bruma", "tipo": "semilla", "pila": 20, "precio": 10,
		"tienda": "herbolario", "nivel": 1, "habilidad": "",
		"color": Color(0.4, 0.7, 0.4), "forma": "bolsita",
		"descripcion": "Crece rápido. Su humo hace soñar (y está prohibido).",
		"hierba": "bruma",
	},
	"semilla_sepulcral": {
		"nombre": "Espora de Hongo Sepulcral", "tipo": "semilla", "pila": 20, "precio": 15,
		"tienda": "herbolario", "nivel": 1, "habilidad": "",
		"color": Color(0.62, 0.58, 0.7), "forma": "bolsita",
		"descripcion": "Tarda más, pero sus pociones se pagan mejor.",
		"hierba": "sepulcral",
	},
	"tierra": {
		"nombre": "Saco de tierra", "tipo": "material", "pila": 20, "precio": 8,
		"tienda": "herbolario", "nivel": 1, "habilidad": "",
		"color": Color(0.35, 0.24, 0.15), "forma": "saco",
		"descripcion": "Tierra negra de cementerio. Un saco llena una maceta.",
	},
	"abono": {
		"nombre": "Abono de murciélago", "tipo": "material", "pila": 20, "precio": 12,
		"tienda": "herbolario", "nivel": 1, "habilidad": "",
		"color": Color(0.5, 0.45, 0.3), "forma": "saco",
		"descripcion": "Opcional. La planta crece más rápido y da una hierba más.",
	},
	"maceta": {
		"nombre": "Maceta de barro", "tipo": "material", "pila": 20, "precio": 20,
		"tienda": "herbolario", "nivel": 1, "habilidad": "",
		"color": Color(0.6, 0.33, 0.22), "forma": "maceta",
		"descripcion": "Colócala en uno de los huecos para macetas de tu casa.",
	},
	"jarra": {
		"nombre": "Jarra de agua", "tipo": "herramienta", "pila": 1, "precio": 25,
		"tienda": "herbolario", "nivel": 1, "habilidad": "",
		"color": Color(0.55, 0.6, 0.7), "forma": "jarra",
		"descripcion": "Da para 3 riegos. Se rellena en el grifo de la cocina.",
		"agua_max": 3,
	},
	"regadera": {
		"nombre": "Regadera de latón", "tipo": "herramienta", "pila": 1, "precio": 60,
		"tienda": "ferreteria", "nivel": 2, "habilidad": "",
		"color": Color(0.75, 0.6, 0.3), "forma": "regadera",
		"descripcion": "Da para 8 riegos. Para cultivos más grandes.",
		"agua_max": 8,
	},

	# ---------------------- Hierbas cosechadas y pociones ---------------------
	"hierba_bruma": {
		"nombre": "Hoja de Bruma", "tipo": "hierba", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.3, 0.6, 0.35), "forma": "hoja",
		"descripcion": "Cosechada. Échala al caldero.",
	},
	"hierba_sepulcral": {
		"nombre": "Hongo Sepulcral", "tipo": "hierba", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.62, 0.58, 0.7), "forma": "seta",
		"descripcion": "Cosechado. Échalo al caldero.",
	},
	"pocion_humo": {
		"nombre": "Humo del Olvido", "tipo": "pocion", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.35, 0.7, 0.45), "forma": "frasco",
		"descripcion": "Poción prohibida. Se vende en la ventanilla.",
	},
	"pocion_sueno": {
		"nombre": "Elixir del Mal Sueño", "tipo": "pocion", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.45, 0.55, 0.6), "forma": "frasco",
		"descripcion": "Poción prohibida. Se vende en la ventanilla.",
	},
	"pocion_sombra": {
		"nombre": "Tónico de la Sombra Propia", "tipo": "pocion", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.4, 0.3, 0.55), "forma": "frasco",
		"descripcion": "Poción prohibida. Se vende en la ventanilla.",
	},

	# -------------------------- Armas cuerpo a cuerpo -------------------------
	"palo": {
		"nombre": "Palo rudimentario", "tipo": "arma_cc", "pila": 1, "precio": 5,
		"tienda": "ferreteria", "nivel": 1, "habilidad": "",
		"color": Color(0.45, 0.32, 0.2), "forma": "palo", "dano": 10,
		"descripcion": "Un palo con un clavo. Mejor que nada.",
	},
	"bate": {
		"nombre": "Bate de béisbol", "tipo": "arma_cc", "pila": 1, "precio": 40,
		"tienda": "ferreteria", "nivel": 2, "habilidad": "",
		"color": Color(0.7, 0.55, 0.35), "forma": "bate", "dano": 20,
		"descripcion": "Madera de fresno. Golpe contundente.",
	},
	"barra_hierro": {
		"nombre": "Barra de hierro", "tipo": "arma_cc", "pila": 1, "precio": 55,
		"tienda": "ferreteria", "nivel": 3, "habilidad": "",
		"color": Color(0.4, 0.4, 0.42), "forma": "barra", "dano": 25,
		"descripcion": "Pesada y fría.",
	},
	"cuchillo": {
		"nombre": "Cuchillo", "tipo": "arma_cc", "pila": 1, "precio": 35,
		"tienda": "armeria", "nivel": 2, "habilidad": "",
		"color": Color(0.75, 0.75, 0.78), "forma": "cuchillo", "dano": 18,
		"descripcion": "Rápido y silencioso.",
	},
	"katana": {
		"nombre": "Katana", "tipo": "arma_cc", "pila": 1, "precio": 400,
		"tienda": "armeria", "nivel": 6, "habilidad": "espada",
		"color": Color(0.85, 0.85, 0.9), "forma": "katana", "dano": 45,
		"descripcion": "Hoja curva de acero plegado. Requiere saber usar espadas.",
	},

	# ------------------------------ Armas de fuego -----------------------------
	"pistola": {
		"nombre": "Pistola", "tipo": "arma_fuego", "pila": 1, "precio": 250,
		"tienda": "armeria", "nivel": 3, "habilidad": "disparo",
		"color": Color(0.15, 0.15, 0.17), "forma": "pistola", "dano": 20,
		"municion": "municion_pistola", "cargador": 12,
		"descripcion": "Semiautomática. Requiere la habilidad de disparo.",
	},
	"escopeta": {
		"nombre": "Escopeta", "tipo": "arma_fuego", "pila": 1, "precio": 500,
		"tienda": "armeria", "nivel": 5, "habilidad": "disparo",
		"color": Color(0.3, 0.2, 0.12), "forma": "escopeta", "dano": 12,
		"municion": "municion_escopeta", "cargador": 6, "perdigones": 8,
		"descripcion": "Devastadora de cerca.",
	},
	"rifle": {
		"nombre": "Rifle", "tipo": "arma_fuego", "pila": 1, "precio": 900,
		"tienda": "armeria", "nivel": 7, "habilidad": "disparo",
		"color": Color(0.2, 0.22, 0.18), "forma": "rifle", "dano": 30,
		"municion": "municion_rifle", "cargador": 30,
		"descripcion": "Automático. Mucho retroceso.",
	},
	"francotirador": {
		"nombre": "Rifle de francotirador", "tipo": "arma_fuego", "pila": 1, "precio": 1500,
		"tienda": "armeria", "nivel": 9, "habilidad": "punteria",
		"color": Color(0.18, 0.2, 0.2), "forma": "francotirador", "dano": 90,
		"municion": "municion_rifle", "cargador": 5,
		"descripcion": "Con mira telescópica. Requiere puntería avanzada.",
	},
	"lanzagranadas": {
		"nombre": "Lanzagranadas", "tipo": "arma_fuego", "pila": 1, "precio": 2500,
		"tienda": "armeria", "nivel": 10, "habilidad": "explosivos",
		"color": Color(0.25, 0.3, 0.2), "forma": "lanzagranadas", "dano": 100,
		"municion": "granada", "cargador": 1,
		"descripcion": "Dispara granadas. Requiere saber de explosivos.",
	},

	# ------------------------------- Explosivos --------------------------------
	"granada": {
		"nombre": "Granada", "tipo": "explosivo", "pila": 10, "precio": 80,
		"tienda": "armeria", "nivel": 6, "habilidad": "explosivos",
		"color": Color(0.25, 0.32, 0.2), "forma": "granada", "dano": 100,
		"descripcion": "Tira de la anilla y lánzala lejos.",
	},
	"c4": {
		"nombre": "Carga C4", "tipo": "explosivo", "pila": 5, "precio": 300,
		"tienda": "armeria", "nivel": 8, "habilidad": "explosivos",
		"color": Color(0.85, 0.82, 0.7), "forma": "c4", "dano": 150,
		"descripcion": "Se pega a cualquier superficie y se detona a distancia.",
	},
	"detonador": {
		"nombre": "Detonador", "tipo": "herramienta", "pila": 1, "precio": 50,
		"tienda": "armeria", "nivel": 8, "habilidad": "explosivos",
		"color": Color(0.2, 0.2, 0.2), "forma": "detonador",
		"descripcion": "Hace explotar las cargas C4 que hayas colocado.",
	},

	# -------------------------------- Munición ---------------------------------
	"municion_pistola": {
		"nombre": "Balas de pistola", "tipo": "municion", "pila": 20, "precio": 15,
		"tienda": "armeria", "nivel": 3, "habilidad": "disparo",
		"color": Color(0.8, 0.65, 0.3), "forma": "caja",
		"descripcion": "Caja de balas para la pistola.",
	},
	"municion_escopeta": {
		"nombre": "Cartuchos de escopeta", "tipo": "municion", "pila": 20, "precio": 25,
		"tienda": "armeria", "nivel": 5, "habilidad": "disparo",
		"color": Color(0.7, 0.2, 0.15), "forma": "caja",
		"descripcion": "Cartuchos de perdigones.",
	},
	"municion_rifle": {
		"nombre": "Balas de rifle", "tipo": "municion", "pila": 20, "precio": 30,
		"tienda": "armeria", "nivel": 7, "habilidad": "disparo",
		"color": Color(0.75, 0.7, 0.4), "forma": "caja",
		"descripcion": "Para el rifle y el de francotirador.",
	},
}


static func datos(id: String) -> Dictionary:
	return LISTA[id]


static func nombre(id: String) -> String:
	return LISTA[id]["nombre"]


static func pila(id: String) -> int:
	return mini(LISTA[id]["pila"], PILA_MAXIMA)


# Los objetos que se venden en una tienda concreta.
static func de_tienda(tienda: String) -> Array:
	var resultado: Array = []
	for id in LISTA:
		if LISTA[id]["tienda"] == tienda:
			resultado.append(id)
	return resultado
