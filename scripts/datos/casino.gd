# casino.gd
# -----------------------------------------------------------------------------
# Locales nocturnos (ver docs/MUNDO_NOCTURNO_STATS_BANDAS.md, secciones 3 y 4):
# horarios, precios y la tragaperras. SOLO dinero del juego.
# La casa gana a la larga: la tragaperras devuelve un 88 % (ver RETORNO).
# -----------------------------------------------------------------------------
extends RefCounted

# Horario (hora del juego): abre y cierra. Si cierra < abre, pasa de medianoche.
const HORARIOS: Dictionary = {
	"discoteca": {"abre": 21.0, "cierra": 6.0},
	"tragaperras": {"abre": 18.0, "cierra": 4.0},
}

const ENTRADA_DISCOTECA: int = 20
const COPA_DISCOTECA: int = 12
const APUESTAS: Array = [5, 25, 100]

# Símbolos de los rodillos.
const SIMBOLOS: Array = ["Hierba", "Caldero", "Corona", "Calavera", "Moneda", "Pocion"]

# Premios por apuesta: [probabilidad, multiplicador]. Esperanza = suma(p * m) = 0,88.
const PREMIOS: Array = [[0.006, 50.0], [0.03, 10.0], [0.06, 3.0], [0.10, 1.0]]
const RETORNO: float = 0.88


static func abierto(servicio: String, hora: float) -> bool:
	if not HORARIOS.has(servicio):
		return true
	var h: Dictionary = HORARIOS[servicio]
	var abre: float = h["abre"]
	var cierra: float = h["cierra"]
	if cierra > abre:
		return hora >= abre and hora < cierra
	return hora >= abre or hora < cierra


static func texto_horario(servicio: String) -> String:
	var h: Dictionary = HORARIOS.get(servicio, {"abre": 0.0, "cierra": 24.0})
	return "%02d:00-%02d:00" % [int(h["abre"]), int(h["cierra"]) % 24]


# Una tirada: devuelve {"rodillos": [a, b, c], "multiplicador": x}. "azar" en [0, 1).
static func tirada(azar: float, rng: RandomNumberGenerator) -> Dictionary:
	var acumulado: float = 0.0
	var mult: float = 0.0
	for p in PREMIOS:
		acumulado += float(p[0])
		if azar < acumulado:
			mult = float(p[1])
			break
	var rodillos: Array = []
	if mult >= 50.0:
		var s: String = "Corona"
		rodillos = [s, s, s]
	elif mult >= 10.0:
		var s2: String = SIMBOLOS[rng.randi() % 3]
		rodillos = [s2, s2, s2]
	elif mult >= 3.0:
		var s3: String = SIMBOLOS[3 + rng.randi() % 3]
		rodillos = [s3, s3, s3]
	elif mult >= 1.0:
		var s4: String = SIMBOLOS[rng.randi() % 6]
		var otro: String = SIMBOLOS[(SIMBOLOS.find(s4) + 1 + rng.randi() % 5) % 6]
		rodillos = [s4, s4, otro]
	else:
		# Sin premio: tres símbolos que nunca son los tres iguales.
		var a: int = rng.randi() % 6
		var b: int = (a + 1 + rng.randi() % 5) % 6
		var c: int = rng.randi() % 6
		rodillos = [SIMBOLOS[a], SIMBOLOS[b], SIMBOLOS[c]]
	return {"rodillos": rodillos, "multiplicador": mult}
