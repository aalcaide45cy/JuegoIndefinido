# estadisticas.gd
# -----------------------------------------------------------------------------
# Estadísticas del jugador (ver docs/MUNDO_NOCTURNO_STATS_BANDAS.md, sección 5).
# Vitales (barras que suben y bajan solas): resistencia, hambre y sed.
# Atributos (1-20, suben con el uso y con puntos de nivel): fuerza, agilidad,
# constitución, puntería, carisma, sigilo y ojo.
# Todo son datos: aquí solo hay números y textos, la lógica está en Juego.
# -----------------------------------------------------------------------------
extends RefCounted

const ATRIBUTOS: Dictionary = {
	"fuerza": {"nombre": "Fuerza", "texto": "Más daño cuerpo a cuerpo."},
	"agilidad": {"nombre": "Agilidad", "texto": "Corres más tiempo y recuperas antes el aliento."},
	"constitucion": {"nombre": "Constitución", "texto": "Más vida máxima."},
	"punteria": {"nombre": "Puntería", "texto": "Menos dispersión con armas de fuego."},
	"carisma": {"nombre": "Carisma", "texto": "Mejores precios y tratos."},
	"sigilo": {"nombre": "Sigilo", "texto": "Menos sospecha."},
	"ojo": {"nombre": "Ojo", "texto": "Ver trampas y estadísticas de otros."},
}
const ORDEN: Array = ["fuerza", "agilidad", "constitucion", "punteria", "carisma", "sigilo", "ojo"]

const ATRIBUTO_INICIAL: int = 5
const ATRIBUTO_MAX: int = 20

# Resistencia (0-100): se gasta al correr y se recupera al andar o parar.
const RESISTENCIA_MAX: float = 100.0
const GASTO_CORRER: float = 16.0          # Por segundo corriendo.
const RECUPERA: float = 14.0              # Por segundo sin correr.
const UMBRAL_RECUPERAR: float = 20.0      # Tras agotarte no corres hasta pasar de esto.

# Hambre y sed (0 = bien, 100 = fatal). Suben con el tiempo real de juego.
const HAMBRE_POR_MIN: float = 2.2         # ~45 min reales de 0 a 100.
const SED_POR_MIN: float = 3.3            # ~30 min reales.
const MAL_ESTADO: float = 75.0            # Desde aquí baja la resistencia máxima.


static func nuevos_atributos() -> Dictionary:
	var d: Dictionary = {}
	for id in ORDEN:
		d[id] = ATRIBUTO_INICIAL
	return d


static func nombre(id: String) -> String:
	return String(ATRIBUTOS.get(id, {}).get("nombre", id))


# Vida máxima: 100 + 4 por cada punto de constitución por encima de 5.
static func vida_maxima(constitucion: int) -> float:
	return 100.0 + 4.0 * float(constitucion - ATRIBUTO_INICIAL)
