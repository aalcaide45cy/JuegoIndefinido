# economia.gd
# -----------------------------------------------------------------------------
# Todos los números que equilibran el dinero del juego, en un solo sitio.
# Cambiar el equilibrio = tocar este archivo (ver docs/DISENO.md y docs/MEJORAS.md).
# Sin class_name: se usa con preload("res://scripts/datos/economia.gd").
# -----------------------------------------------------------------------------
extends RefCounted

# Qué parte del precio paga una tienda cuando le vendes algo.
const VENTA_TIENDA: float = 0.5
const VENTA_COSECHA: float = 0.33      # Cosechas legales (huerto, granja): pagan menos que lo ilegal.

# Los cultivos legales tardan el doble que en el prototipo.
const FACTOR_TIEMPO_CULTIVO: float = 2.0
const M2_POR_UNIDAD: int = 16          # Un huerto da 1 cosecha por cada 16 m2...
const MAX_UNIDADES_HUERTO: int = 80    # ...con este tope.

# Alquiler: se paga por adelantado y además cada día de juego un % del precio de compra.
# Si no puedes pagar, se acumulan impagos; a los 3 días pierdes la propiedad.
const ALQUILER_DIARIO: float = 0.04
const DIAS_IMPAGO_MAX: int = 3

# Multas.
const MULTA_CACHEO_PORCENTAJE: float = 0.05    # del dinero que llevas, más lo confiscado.
const MULTA_REGISTRO_PORCENTAJE: float = 0.05
const MULTA_MUERTE_PORCENTAJE: float = 0.15
const MULTA_MUERTE_MINIMA: int = 20
const MULTA_ATROPELLO: int = 150               # Un guardia te pilla atropellando a alguien.
const MULTA_SIN_CARNET: int = 100              # Conducir sin carnet delante de un guardia.

# Niveles: 1 a NIVEL_MAX. xp para pasar del nivel n al n+1 = 60 * n^1.5 (nivel 10: 1.900; 19: 5.000).
const NIVEL_MAX: int = 20
const BONUS_PRECIO_POR_NIVEL: float = 0.01     # +1 % en ventas de pociones por cada nivel sobre el 1.


static func xp_para_subir(nivel: int) -> int:
	return int(round(60.0 * pow(float(nivel), 1.5)))


# Multiplicador de precio de venta de pociones según tu nivel (nivel 20 = +19 %).
static func bonus_nivel(nivel: int) -> float:
	return 1.0 + BONUS_PRECIO_POR_NIVEL * float(nivel - 1)


static func alquiler_diario(precio_compra: int) -> int:
	return maxi(1, int(round(precio_compra * ALQUILER_DIARIO)))
