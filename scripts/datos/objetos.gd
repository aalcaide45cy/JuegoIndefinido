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
#   tienda       dónde se compra: "herbolario", "ferreteria", "armeria",
#                "panaderia", "botica" o "".
#   nivel        nivel mínimo del jugador para comprarlo (fase 3).
#   habilidad    habilidad necesaria para comprarlo, o "" (fase 3).
#   color        color de su icono y de su modelo en la mano.
#   forma        cómo se dibuja en la mano (mira jugador.gd, _crear_modelo_mano).
#   descripcion  una frase para la tienda.
# Algunos tienen datos extra (agua, daño, munición...) que usa su propio código.
# -----------------------------------------------------------------------------
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
		"tienda": "herbolario", "nivel": 2, "habilidad": "",
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
	"abono_mejorado": {
		"nombre": "Abono mejorado", "tipo": "material", "pila": 20, "precio": 40,
		"tienda": "herbolario", "nivel": 3, "habilidad": "",
		"color": Color(0.35, 0.65, 0.3), "forma": "saco",
		"descripcion": "Con E sobre una planta creciendo: +50% de velocidad y una hierba más (una vez).",
	},
	"mejora_maceta": {
		"nombre": "Mejora de maceta", "tipo": "material", "pila": 20, "precio": 90,
		"tienda": "herbolario", "nivel": 2, "habilidad": "",
		"color": Color(0.8, 0.8, 0.9), "forma": "saco",
		"descripcion": "Con E sobre una maceta sube su nivel (máx. 3): crece más rápido y da más hierbas.",
	},
	"kit_riego": {
		"nombre": "Kit de riego", "tipo": "material", "pila": 20, "precio": 120,
		"tienda": "herbolario", "nivel": 2, "habilidad": "",
		"color": Color(0.3, 0.6, 0.9), "forma": "jarra",
		"descripcion": "Con E sobre una maceta instala riego automático: +20% de velocidad.",
	},
	"maceta": {
		"nombre": "Maceta de barro", "tipo": "material", "pila": 20, "precio": 20,
		"tienda": "herbolario", "nivel": 1, "habilidad": "",
		"color": Color(0.6, 0.33, 0.22), "forma": "maceta",
		"descripcion": "Colócala en uno de los huecos para macetas de tu casa.",
	},
	"lampara": {
		"nombre": "Lámpara", "tipo": "mueble", "pila": 20, "precio": 35,
		"tienda": "ferreteria", "nivel": 1, "habilidad": "",
		"color": Color(1.0, 0.82, 0.5), "forma": "jarra",
		"descripcion": "Para montar en tu casa: apunta al suelo y pulsa G. Mejorable (niveles 1-3).",
	},
	"foco_cultivo": {
		"nombre": "Foco de cultivo", "tipo": "mueble", "pila": 20, "precio": 110,
		"tienda": "ferreteria", "nivel": 2, "habilidad": "",
		"color": Color(0.8, 0.45, 1.0), "forma": "jarra",
		"descripcion": "Se monta con G. Las macetas a menos de 3,5 m crecen +25% por nivel.",
	},
	"mejora_equipo": {
		"nombre": "Mejora de equipo", "tipo": "material", "pila": 20, "precio": 90,
		"tienda": "ferreteria", "nivel": 2, "habilidad": "",
		"color": Color(0.7, 0.9, 1.0), "forma": "saco",
		"descripcion": "Con E sobre una lámpara o foco montados, sube su nivel (máx. 3).",
	},
	"bidon_gasolina": {
		"nombre": "Bidón de gasolina", "tipo": "material", "pila": 10, "precio": 30,
		"tienda": "ferreteria", "nivel": 1, "habilidad": "",
		"color": Color(0.8, 0.15, 0.1), "forma": "saco",
		"descripcion": "Con E sobre un vehículo (en la mano) rellena el 40 % del depósito.",
	},
	"kit_reparacion": {
		"nombre": "Kit de reparación", "tipo": "material", "pila": 10, "precio": 80,
		"tienda": "ferreteria", "nivel": 1, "habilidad": "",
		"color": Color(0.6, 0.6, 0.65), "forma": "saco",
		"descripcion": "Con E sobre un vehículo (en la mano) lo deja como nuevo.",
	},
	"semilla_trigo": {
		"nombre": "Semillas de Trigo", "tipo": "semilla", "pila": 20, "precio": 6,
		"tienda": "herbolario", "nivel": 1, "habilidad": "",
		"color": Color(0.8, 0.7, 0.35), "forma": "bolsita",
		"descripcion": "Cultivo legal para tu huerto (E en la entrada del huerto con ellas en la mano).",
	},
	"semilla_maiz": {
		"nombre": "Semillas de Maíz", "tipo": "semilla", "pila": 20, "precio": 8,
		"tienda": "herbolario", "nivel": 1, "habilidad": "",
		"color": Color(0.8, 0.7, 0.35), "forma": "bolsita",
		"descripcion": "Cultivo legal para tu huerto (E en la entrada del huerto con ellas en la mano).",
	},
	"semilla_tomate": {
		"nombre": "Semillas de Tomate", "tipo": "semilla", "pila": 20, "precio": 9,
		"tienda": "herbolario", "nivel": 1, "habilidad": "",
		"color": Color(0.8, 0.7, 0.35), "forma": "bolsita",
		"descripcion": "Cultivo legal para tu huerto (E en la entrada del huerto con ellas en la mano).",
	},
	"trigo": {
		"nombre": "Trigo", "tipo": "cosecha", "pila": 20, "precio": 14,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.85, 0.7, 0.3), "forma": "saco",
		"descripcion": "Cosecha legal del huerto. Se vende en las tiendas (a un tercio del precio).",
	},
	"maiz": {
		"nombre": "Maíz", "tipo": "cosecha", "pila": 20, "precio": 18,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.85, 0.7, 0.3), "forma": "saco",
		"descripcion": "Cosecha legal del huerto. Se vende en las tiendas (a un tercio del precio).",
		"cura": 5,
	},
	"tomate": {
		"nombre": "Tomate", "tipo": "cosecha", "pila": 20, "precio": 24,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.85, 0.7, 0.3), "forma": "saco",
		"descripcion": "Cosecha legal del huerto. Se vende en las tiendas (a un tercio del precio).",
		"cura": 6,
	},
	"gallina": {
		"nombre": "Gallina", "tipo": "animal", "pila": 1, "precio": 45,
		"tienda": "herbolario", "nivel": 4, "habilidad": "",
		"color": Color(0.9, 0.85, 0.7), "forma": "saco",
		"descripcion": "Mételas en el gallinero de la granja (E). Cada una pone un huevo por minuto.",
	},
	"vaca": {
		"nombre": "Vaca", "tipo": "animal", "pila": 1, "precio": 260,
		"tienda": "herbolario", "nivel": 6, "habilidad": "",
		"color": Color(0.9, 0.85, 0.7), "forma": "saco",
		"descripcion": "Métela en el establo de la granja (E). Da leche cada 2 minutos.",
	},
	"huevo": {
		"nombre": "Huevo", "tipo": "cosecha", "pila": 20, "precio": 7,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.9, 0.85, 0.7), "forma": "saco",
		"descripcion": "Producto legal del gallinero. Se vende en las tiendas.",
		"cura": 4,
	},
	"leche": {
		"nombre": "Leche", "tipo": "cosecha", "pila": 20, "precio": 16,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.9, 0.85, 0.7), "forma": "saco",
		"descripcion": "Producto legal del establo. Se vende en las tiendas.",
		"cura": 12, "quita": ["nauseas"],
	},
	"manzana": {
		"nombre": "Manzana", "tipo": "cosecha", "pila": 20, "precio": 8,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.9, 0.85, 0.7), "forma": "saco",
		"descripcion": "Fruta del manzano de la granja. Se vende en las tiendas.",
		"cura": 8,
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

	# ---------------- Hierbas nuevas (ver scripts/datos/mezclas.gd) ----------------
	"semilla_raiz_ardiente": {
		"nombre": "Semilla de Raíz Ardiente", "tipo": "semilla", "pila": 20, "precio": 14,
		"tienda": "herbolario", "nivel": 1, "habilidad": "",
		"color": Color(0.85, 0.3, 0.15), "forma": "bolsita",
		"descripcion": "Da velocidad. Escuece al tocarla.",
		"hierba": "raiz_ardiente",
	},
	"hierba_raiz_ardiente": {
		"nombre": "Raíz Ardiente", "tipo": "hierba", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.85, 0.3, 0.15), "forma": "hoja",
		"descripcion": "Cosechada. Échala al caldero: da velocidad. Escuece al tocarla.",
	},
	"semilla_musgo_dulce": {
		"nombre": "Esporas de Musgo Dulce", "tipo": "semilla", "pila": 20, "precio": 12,
		"tienda": "herbolario", "nivel": 1, "habilidad": "",
		"color": Color(0.5, 0.85, 0.4), "forma": "bolsita",
		"descripcion": "Regenera la vida. Sabe a miel.",
		"hierba": "musgo_dulce",
	},
	"hierba_musgo_dulce": {
		"nombre": "Musgo Dulce", "tipo": "hierba", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.5, 0.85, 0.4), "forma": "hoja",
		"descripcion": "Cosechada. Échala al caldero: regenera la vida. Sabe a miel.",
	},
	"semilla_ortiga_negra": {
		"nombre": "Semilla de Ortiga Negra", "tipo": "semilla", "pila": 20, "precio": 11,
		"tienda": "herbolario", "nivel": 2, "habilidad": "",
		"color": Color(0.15, 0.3, 0.2), "forma": "bolsita",
		"descripcion": "Da fuerza, pero envenena.",
		"hierba": "ortiga_negra",
	},
	"hierba_ortiga_negra": {
		"nombre": "Ortiga Negra", "tipo": "hierba", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.15, 0.3, 0.2), "forma": "hoja",
		"descripcion": "Cosechada. Échala al caldero: da fuerza, pero envenena.",
	},
	"semilla_cardo_hierro": {
		"nombre": "Semilla de Cardo de Hierro", "tipo": "semilla", "pila": 20, "precio": 16,
		"tienda": "herbolario", "nivel": 3, "habilidad": "",
		"color": Color(0.5, 0.55, 0.6), "forma": "bolsita",
		"descripcion": "Da resistencia, a costa de ir más lento.",
		"hierba": "cardo_hierro",
	},
	"hierba_cardo_hierro": {
		"nombre": "Cardo de Hierro", "tipo": "hierba", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.5, 0.55, 0.6), "forma": "hoja",
		"descripcion": "Cosechada. Échala al caldero: da resistencia, a costa de ir más lento.",
	},
	"semilla_hongo_risueno": {
		"nombre": "Espora de Hongo Risueño", "tipo": "semilla", "pila": 20, "precio": 14,
		"tienda": "herbolario", "nivel": 3, "habilidad": "",
		"color": Color(0.95, 0.6, 0.7), "forma": "bolsita",
		"descripcion": "Da euforia y algo de mareo.",
		"hierba": "hongo_risueno",
	},
	"hierba_hongo_risueno": {
		"nombre": "Hongo Risueño", "tipo": "hierba", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.95, 0.6, 0.7), "forma": "seta",
		"descripcion": "Cosechada. Échala al caldero: da euforia y algo de mareo.",
	},
	"semilla_baya_noche": {
		"nombre": "Semilla de Baya de Noche", "tipo": "semilla", "pila": 20, "precio": 15,
		"tienda": "herbolario", "nivel": 5, "habilidad": "",
		"color": Color(0.3, 0.2, 0.5), "forma": "bolsita",
		"descripcion": "Sigilo, y una pizca de paranoia.",
		"hierba": "baya_noche",
	},
	"hierba_baya_noche": {
		"nombre": "Baya de Noche", "tipo": "hierba", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.3, 0.2, 0.5), "forma": "hoja",
		"descripcion": "Cosechada. Échala al caldero: sigilo, y una pizca de paranoia.",
	},
	"semilla_flor_sol": {
		"nombre": "Semilla de Flor de Sol", "tipo": "semilla", "pila": 20, "precio": 16,
		"tienda": "herbolario", "nivel": 6, "habilidad": "",
		"color": Color(0.95, 0.8, 0.25), "forma": "bolsita",
		"descripcion": "Fuerza y buen humor.",
		"hierba": "flor_sol",
	},
	"hierba_flor_sol": {
		"nombre": "Flor de Sol", "tipo": "hierba", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.95, 0.8, 0.25), "forma": "hoja",
		"descripcion": "Cosechada. Échala al caldero: fuerza y buen humor.",
	},
	"semilla_lirio_lunar": {
		"nombre": "Semilla de Lirio Lunar", "tipo": "semilla", "pila": 20, "precio": 20,
		"tienda": "herbolario", "nivel": 7, "habilidad": "",
		"color": Color(0.55, 0.7, 0.95), "forma": "bolsita",
		"descripcion": "Visión nocturna. Solo florece de noche.",
		"hierba": "lirio_lunar",
	},
	"hierba_lirio_lunar": {
		"nombre": "Lirio Lunar", "tipo": "hierba", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.55, 0.7, 0.95), "forma": "hoja",
		"descripcion": "Cosechada. Échala al caldero: visión nocturna. Solo florece de noche.",
	},

	# -------------- Aditivos del caldero (se compran, no se cultivan) --------------
	"aditivo_miel": {
		"nombre": "Miel de colmena", "tipo": "aditivo", "pila": 20, "precio": 8,
		"tienda": "herbolario", "nivel": 1, "habilidad": "",
		"color": Color(0.9, 0.7, 0.2), "forma": "jarra",
		"descripcion": "Aditivo del caldero: aporta carisma.",
	},
	"aditivo_sal": {
		"nombre": "Sal gorda", "tipo": "aditivo", "pila": 20, "precio": 6,
		"tienda": "herbolario", "nivel": 1, "habilidad": "",
		"color": Color(0.92, 0.92, 0.9), "forma": "saco",
		"descripcion": "Aditivo del caldero: aporta concentración.",
	},
	"aditivo_ceniza": {
		"nombre": "Ceniza", "tipo": "aditivo", "pila": 20, "precio": 7,
		"tienda": "herbolario", "nivel": 2, "habilidad": "",
		"color": Color(0.45, 0.45, 0.47), "forma": "saco",
		"descripcion": "Aditivo del caldero: aporta sigilo.",
	},
	"aditivo_azufre": {
		"nombre": "Azufre", "tipo": "aditivo", "pila": 20, "precio": 9,
		"tienda": "botica", "nivel": 2, "habilidad": "",
		"color": Color(0.9, 0.85, 0.2), "forma": "saco",
		"descripcion": "Aditivo del caldero: velocidad, pero revuelve el estómago.",
	},
	"aditivo_vinagre": {
		"nombre": "Vinagre", "tipo": "aditivo", "pila": 20, "precio": 7,
		"tienda": "botica", "nivel": 2, "habilidad": "",
		"color": Color(0.75, 0.55, 0.5), "forma": "frasco",
		"descripcion": "Aditivo del caldero: concentración y náuseas.",
	},
	"aditivo_esencia": {
		"nombre": "Esencia de rosa", "tipo": "aditivo", "pila": 20, "precio": 12,
		"tienda": "botica", "nivel": 4, "habilidad": "",
		"color": Color(0.95, 0.5, 0.65), "forma": "frasco",
		"descripcion": "Aditivo del caldero: carisma y euforia.",
	},
	"aditivo_muelle": {
		"nombre": "Muelle oxidado", "tipo": "aditivo", "pila": 20, "precio": 10,
		"tienda": "ferreteria", "nivel": 3, "habilidad": "",
		"color": Color(0.55, 0.4, 0.3), "forma": "barra",
		"descripcion": "Aditivo del caldero: piernas de resorte.",
	},
	"aditivo_arsenico": {
		"nombre": "Polvo de arsénico", "tipo": "aditivo", "pila": 20, "precio": 11,
		"tienda": "botica", "nivel": 5, "habilidad": "",
		"color": Color(0.85, 0.85, 0.8), "forma": "saco",
		"descripcion": "Aditivo del caldero: veneno. Con cuidado.",
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
	"paquete_humo": {
		"nombre": "Paquete: Humo del Olvido", "tipo": "paquete", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.75, 0.6, 0.4), "forma": "saco",
		"descripcion": "Poción empaquetada. Los clientes de los encargos pagan un 30% más.",
	},
	"paquete_sueno": {
		"nombre": "Paquete: Elixir del Mal Sueño", "tipo": "paquete", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.75, 0.6, 0.4), "forma": "saco",
		"descripcion": "Poción empaquetada. Los clientes de los encargos pagan un 30% más.",
	},
	"paquete_sombra": {
		"nombre": "Paquete: Tónico de la Sombra Propia", "tipo": "paquete", "pila": 20, "precio": 0,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.75, 0.6, 0.4), "forma": "saco",
		"descripcion": "Poción empaquetada. Los clientes de los encargos pagan un 30% más.",
	},
	"polvo_bruma": {
		"nombre": "Polvo de Hoja de Bruma", "tipo": "material", "pila": 20, "precio": 14,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.5, 0.75, 0.5), "forma": "saco",
		"descripcion": "Hierba machacada en el mortero. Legal: se vende en las tiendas.",
	},
	"polvo_sepulcral": {
		"nombre": "Polvo de Hongo Sepulcral", "tipo": "material", "pila": 20, "precio": 20,
		"tienda": "", "nivel": 1, "habilidad": "",
		"color": Color(0.7, 0.65, 0.78), "forma": "saco",
		"descripcion": "Hongo machacado en el mortero. Legal: se vende en las tiendas.",
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

	# ------------------------- Comida y medicinas ------------------------------
	# Se usan con el clic izquierdo con ellos en la mano. Campos:
	#   "cura"    vida que recupera al momento.
	#   "efectos" lista de {"id", "dur", "f"}: efectos temporales (ver efectos.gd).
	#   "quita"   lista de efectos malos que elimina (veneno, náuseas...).
	"pan": {
		"nombre": "Pan duro", "tipo": "consumible", "pila": 20, "precio": 5,
		"tienda": "panaderia", "nivel": 1, "habilidad": "",
		"color": Color(0.75, 0.55, 0.3), "forma": "pan", "cura": 10,
		"descripcion": "Duro como una piedra, pero alimenta.",
	},
	"empanada": {
		"nombre": "Empanada de molleja", "tipo": "consumible", "pila": 20, "precio": 12,
		"tienda": "panaderia", "nivel": 1, "habilidad": "",
		"color": Color(0.8, 0.6, 0.3), "forma": "pan", "cura": 25,
		"descripcion": "No preguntes de qué es la molleja.",
	},
	"sopa": {
		"nombre": "Sopa de huesos", "tipo": "consumible", "pila": 20, "precio": 18,
		"tienda": "panaderia", "nivel": 1, "habilidad": "",
		"color": Color(0.85, 0.7, 0.4), "forma": "jarra", "cura": 15,
		"efectos": [{"id": "regeneracion", "dur": 20.0, "f": 0.8}],
		"descripcion": "Caliente y espesa: cura un poco y te va sanando después.",
	},
	"estofado": {
		"nombre": "Estofado del Prefecto", "tipo": "consumible", "pila": 20, "precio": 38,
		"tienda": "panaderia", "nivel": 3, "habilidad": "",
		"color": Color(0.6, 0.35, 0.2), "forma": "jarra", "cura": 35,
		"efectos": [{"id": "regeneracion", "dur": 30.0, "f": 1.0}, {"id": "resistencia", "dur": 60.0, "f": 0.6}],
		"descripcion": "Un plato de los ricos. Cura bastante y aguanta golpes un rato.",
	},
	"cafe": {
		"nombre": "Café negro", "tipo": "consumible", "pila": 20, "precio": 12,
		"tienda": "panaderia", "nivel": 1, "habilidad": "",
		"color": Color(0.25, 0.15, 0.1), "forma": "jarra",
		"efectos": [{"id": "velocidad", "dur": 45.0, "f": 0.7}, {"id": "concentracion", "dur": 60.0, "f": 0.7}],
		"descripcion": "Amargo como un lunes. Algo de velocidad y concentración.",
	},
	"te_calmante": {
		"nombre": "Té calmante", "tipo": "consumible", "pila": 20, "precio": 14,
		"tienda": "panaderia", "nivel": 1, "habilidad": "",
		"color": Color(0.5, 0.7, 0.45), "forma": "jarra", "cura": 5,
		"efectos": [{"id": "calma", "dur": 90.0, "f": 1.0}],
		"descripcion": "Baja la sospecha de la policía durante un rato.",
	},
	"venda": {
		"nombre": "Venda limpia", "tipo": "consumible", "pila": 10, "precio": 20,
		"tienda": "botica", "nivel": 1, "habilidad": "",
		"color": Color(0.9, 0.9, 0.85), "forma": "venda", "cura": 30,
		"descripcion": "Cierra heridas. Casi limpia.",
	},
	"tonico": {
		"nombre": "Tónico curativo", "tipo": "consumible", "pila": 10, "precio": 55,
		"tienda": "botica", "nivel": 2, "habilidad": "",
		"color": Color(0.8, 0.25, 0.3), "forma": "frasco", "cura": 70,
		"descripcion": "Sabe a hierro y a mala decisión. Cura mucho.",
	},
	"analgesico": {
		"nombre": "Analgésico", "tipo": "consumible", "pila": 10, "precio": 30,
		"tienda": "botica", "nivel": 1, "habilidad": "",
		"color": Color(0.95, 0.95, 0.95), "forma": "caja", "cura": 10,
		"efectos": [{"id": "resistencia", "dur": 90.0, "f": 0.75}],
		"descripcion": "Apaga el dolor: recibes menos daño durante un rato.",
	},
	"antidoto": {
		"nombre": "Antídoto", "tipo": "consumible", "pila": 10, "precio": 40,
		"tienda": "botica", "nivel": 2, "habilidad": "",
		"color": Color(0.4, 0.8, 0.6), "forma": "frasco", "cura": 10,
		"quita": ["veneno", "nauseas", "mareo"],
		"descripcion": "Quita el veneno, las náuseas y el mareo.",
	},
	"jarabe_regenerador": {
		"nombre": "Jarabe regenerador", "tipo": "consumible", "pila": 10, "precio": 70,
		"tienda": "botica", "nivel": 3, "habilidad": "",
		"color": Color(0.4, 0.9, 0.5), "forma": "frasco",
		"efectos": [{"id": "regeneracion", "dur": 60.0, "f": 1.5}],
		"descripcion": "Cura 2 de vida por segundo durante un minuto.",
	},
	"botiquin": {
		"nombre": "Botiquín", "tipo": "consumible", "pila": 5, "precio": 90,
		"tienda": "botica", "nivel": 2, "habilidad": "",
		"color": Color(0.85, 0.2, 0.2), "forma": "caja", "cura": 60,
		"quita": ["veneno", "nauseas"],
		"descripcion": "Vendas, alcohol y puntos. Cura mucho y quita el veneno.",
	},
	"maletin_medico": {
		"nombre": "Maletín del médico", "tipo": "consumible", "pila": 3, "precio": 220,
		"tienda": "botica", "nivel": 5, "habilidad": "",
		"color": Color(0.2, 0.2, 0.25), "forma": "caja", "cura": 100,
		"quita": ["veneno", "nauseas", "mareo", "somnolencia"],
		"efectos": [{"id": "regeneracion", "dur": 20.0, "f": 1.0}],
		"descripcion": "Lo mejor que se vende sin receta: cura toda la vida y limpia los males.",
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


const Mezclas = preload("res://scripts/datos/mezclas.gd")


# ¿Existe el objeto? Incluye las pociones generadas por mezclas (pocion_m_...).
static func existe(id: String) -> bool:
	return LISTA.has(id) or not Mezclas.objeto(id).is_empty()


# Los datos de un objeto. Las pociones generadas se calculan al pedirlas.
static func datos(id: String) -> Dictionary:
	if LISTA.has(id):
		return LISTA[id]
	var d: Dictionary = Mezclas.objeto(id)
	assert(not d.is_empty(), "Objeto desconocido: " + id)
	return d


static func nombre(id: String) -> String:
	return datos(id)["nombre"]


static func pila(id: String) -> int:
	return mini(datos(id)["pila"], PILA_MAXIMA)


# Los objetos que se venden en una tienda concreta.
static func de_tienda(tienda: String) -> Array:
	var resultado: Array = []
	for id in LISTA:
		if LISTA[id]["tienda"] == tienda:
			resultado.append(id)
	return resultado
