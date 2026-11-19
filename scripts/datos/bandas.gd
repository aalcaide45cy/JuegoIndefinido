# bandas.gd
# -----------------------------------------------------------------------------
# Las bandas del mundo (ver docs/MUNDO_NOCTURNO_STATS_BANDAS.md, sección 8) y la
# reputación en tres bandos: gente corriente, hampa y ley. Todo son datos.
# Cada ciudad grande pertenece a una banda (según su posición): sus matones
# rondan la zona industrial y su bidón cobra la cuota de protección.
# Nombres inventados y libres: se pueden cambiar sin tocar el código.
# -----------------------------------------------------------------------------
extends RefCounted

const BANDAS: Dictionary = {
	"cuervos": {"nombre": "Los Cuervos del Puerto", "color": Color(0.35, 0.35, 0.45), "tema": "contrabando"},
	"mano": {"nombre": "La Mano Gris", "color": Color(0.6, 0.6, 0.6), "tema": "casinos y préstamos"},
	"niebla": {"nombre": "Hijos de la Niebla", "color": Color(0.45, 0.7, 0.55), "tema": "hierbas y pociones"},
	"cerrojos": {"nombre": "Los Cerrojos", "color": Color(0.8, 0.45, 0.2), "tema": "robos y talleres"},
}
const ORDEN: Array = ["cuervos", "mano", "niebla", "cerrojos"]

const CUOTA_DIA: int = 50
const REP_MIN: int = -100
const REP_MAX: int = 100
# Con esta reputación en el hampa, los matones te dejan en paz.
const REP_RESPETO: int = 30


# La banda dueña de la ciudad (ci, cj): fija para cada ciudad.
static func dueno(ci: int, cj: int) -> String:
	var h: int = abs(ci * 73856093 ^ cj * 19349663)
	return ORDEN[h % ORDEN.size()]


static func nombre(id: String) -> String:
	return String(BANDAS.get(id, {}).get("nombre", "una banda"))


static func texto_reputacion(gente: int, hampa: int, ley: int) -> String:
	return "Gente %+d   Hampa %+d   Ley %+d" % [gente, hampa, ley]


# ------------------------- Territorios, jefes y reclutas -----------------------
const CUOTA_TERRITORIO: int = 150     # Por día, de cada barrio que controlas.
const MAX_RECLUTAS: int = 4
const PRECIO_RECLUTA: int = 100
const SUELDO_RECLUTA: int = 40        # Por día y recluta.
const VIDA_JEFE: float = 220.0


# Clave del territorio (la zona chunga de una ciudad) en una posición, o "" si no hay ciudad.
static func clave_en(x: float, z: float) -> String:
	for s in GeneradorMundo.asentamientos_cerca(Rect2(x - 2.0, z - 2.0, 4.0, 4.0)):
		if int(s["tipo"]) == 2:
			return "%d,%d" % [int(s["ci"]), int(s["cj"])]
	return ""


static func dueno_de_clave(clave: String) -> String:
	var partes: PackedStringArray = clave.split(",")
	if partes.size() != 2:
		return "cuervos"
	return dueno(int(partes[0]), int(partes[1]))
