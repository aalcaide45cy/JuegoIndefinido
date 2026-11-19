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
	"casino": {"abre": 20.0, "cierra": 7.0},
}

# Ruleta europea (37 números, un solo cero). Pago: pleno x35, docena x2, color/par/mitad x1.
const ROJOS: Array = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const FICHAS: Array = [10, 50, 200, 1000]
# Si ganas más de esto en una noche, seguridad te acompaña a la puerta y no vuelves ese día.
const LIMITE_GANANCIA_NOCHE: int = 5000
const BLACKJACK_PAGO: float = 1.5

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


# --------------------------------- Ruleta ------------------------------------

static func es_rojo(n: int) -> bool:
	return ROJOS.has(n)


# Gira la ruleta y calcula el pago TOTAL (apuesta incluida; 0 si pierdes).
# tipo: "rojo", "negro", "par", "impar", "falta" (1-18), "pasa" (19-36),
#       "docena1", "docena2", "docena3" o "pleno" (con "valor" = número).
static func ruleta(tipo: String, valor: int, apuesta: int, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = rng.randi() % 37
	return {"numero": n, "pago": pago_ruleta(n, tipo, valor, apuesta)}


static func pago_ruleta(n: int, tipo: String, valor: int, apuesta: int) -> int:
	var gana: bool = false
	var mult: int = 2   # Pago total por apuesta 1 a 1.
	match tipo:
		"rojo": gana = n != 0 and es_rojo(n)
		"negro": gana = n != 0 and not es_rojo(n)
		"par": gana = n != 0 and n % 2 == 0
		"impar": gana = n % 2 == 1
		"falta": gana = n >= 1 and n <= 18
		"pasa": gana = n >= 19
		"docena1":
			gana = n >= 1 and n <= 12
			mult = 3
		"docena2":
			gana = n >= 13 and n <= 24
			mult = 3
		"docena3":
			gana = n >= 25
			mult = 3
		"pleno":
			gana = n == valor
			mult = 36
	return apuesta * mult if gana else 0


# -------------------------------- Blackjack ----------------------------------
# Una carta es un número 1-13 (1 = as, 11-13 = figuras). Baraja infinita.

static func valor_carta(c: int) -> int:
	return 11 if c == 1 else mini(c, 10)


# Total de una mano (los ases valen 11 o 1 para no pasarse).
static func total_mano(cartas: Array) -> int:
	var total: int = 0
	var ases: int = 0
	for c in cartas:
		total += valor_carta(int(c))
		if int(c) == 1:
			ases += 1
	while total > 21 and ases > 0:
		total -= 10
		ases -= 1
	return total


static func es_blackjack(cartas: Array) -> bool:
	return cartas.size() == 2 and total_mano(cartas) == 21


static func nombre_carta(c: int) -> String:
	match c:
		1: return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
	return str(c)


# El crupier pide hasta tener 17 o más. Devuelve la mano final.
static func jugar_crupier(mano: Array, rng: RandomNumberGenerator) -> Array:
	while total_mano(mano) < 17:
		mano.append(1 + rng.randi() % 13)
	return mano


# Pago TOTAL al acabar (apuesta incluida; 0 si pierdes). Blackjack natural paga 3:2.
static func pago_blackjack(jugador: Array, crupier: Array, apuesta: int) -> int:
	var tj: int = total_mano(jugador)
	var tc: int = total_mano(crupier)
	if tj > 21:
		return 0
	if es_blackjack(jugador):
		return apuesta if es_blackjack(crupier) else int(floor(apuesta * (1.0 + BLACKJACK_PAGO)))
	if tc > 21 or tj > tc:
		return apuesta * 2
	if tj == tc:
		return apuesta
	return 0
