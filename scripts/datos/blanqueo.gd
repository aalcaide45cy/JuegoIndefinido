# blanqueo.gd  (datos)
# -----------------------------------------------------------------------------
# Dinero limpio y dinero negro: todos los números en un solo sitio.
# Es una mecánica DE FICCIÓN dentro del juego (como en otros juegos de negocios):
#   - Lo que ganas con el trato ilegal (pociones, hierbas...) es DINERO NEGRO.
#   - El dinero negro NO vale en el banco, ni para licencias, casas, coches o
#     sueldos. Solo sirve en la calle (tiendas, taxi, gasolina, taberna).
#   - Para usarlo "limpio" hay que pasarlo por un negocio tuyo (un FRENTE): cada
#     frente tiene un límite al día, una comisión y un riesgo distintos.
# Sin class_name: preload("res://scripts/datos/blanqueo.gd").
# -----------------------------------------------------------------------------
extends RefCounted

# Frentes: id de licencia (scripts/datos/negocios.gd) -> reglas.
#   cap       lo máximo que puede pasar por él cada día (con el negocio recién abierto).
#   comision  lo que se queda el negocio (0.25 = 25 %).
#   riesgo    cuánto sube la vigilancia fiscal (1.0 = normal).
#   cats      categorías de cartera que lo hacen crecer (cada propiedad o vehículo suma).
const FRENTES: Dictionary = {
	"tienda": {"cap": 300, "comision": 0.25, "riesgo": 1.0, "cats": []},
	"alquiler_coches": {"cap": 1200, "comision": 0.18, "riesgo": 0.9, "cats": ["coche"]},
	"inmobiliaria": {"cap": 1800, "comision": 0.16, "riesgo": 0.8, "cats": ["piso"]},
	"concesionario": {"cap": 2500, "comision": 0.14, "riesgo": 0.8, "cats": ["coche", "pesado"]},
	"alquiler_maquinaria": {"cap": 3500, "comision": 0.12, "riesgo": 0.7, "cats": ["pesado"]},
	"aerodromo": {"cap": 9000, "comision": 0.10, "riesgo": 0.6, "cats": ["aire"]},
}
# Cada propiedad/vehículo de las categorías del frente sube su límite un 25 % (hasta 4).
const CRECE_POR_ACTIVO: float = 0.25
const MAX_ACTIVOS_CUENTAN: int = 4

# Vigilancia fiscal (0 a 100): sube al blanquear, baja cada día. Pasar todo el límite de
# un frente de golpe sube 40 puntos (x riesgo).
const VIGILANCIA_POR_LIMITE: float = 40.0
const VIGILANCIA_BAJA_DIA: float = 8.0
const VIGILANCIA_INSPECCION: float = 80.0
const INSPECCION_PROB: float = 0.5            # Cada día que estés por encima.
const INSPECCION_CONFISCA_NEGRO: float = 0.25 # Parte del dinero negro que te quitan.
const INSPECCION_MULTA_LIMPIO: float = 0.05   # Parte del dinero limpio.
const INSPECCION_VIGILANCIA_TRAS: float = 40.0
const INSPECCION_ESTRELLAS: int = 1
# Blanquear también hace sospechar a los guardias (puntos de sospecha por cada 1.000 $).
const SOSPECHA_POR_MIL: float = 4.0

# Llevar encima mucho dinero negro es sospechoso.
const UMBRAL_SOSPECHOSO: int = 300            # Por debajo no cuenta.
const SOSPECHA_POR_SEGUNDO_MAX: float = 1.2
const SOSPECHA_NEGRO_REF: float = 4000.0      # Con tanto dinero negro, la sospecha extra es 1,0/s.
# Cacheo: si no lo escondes, te quitan esta parte del dinero negro.
const CACHEO_CONFISCA: float = 0.6
# Detención (estrellas n): parte que confiscan = 0,4 + 0,12 x n (máx. 1).
const DETENCION_BASE: float = 0.4
const DETENCION_POR_ESTRELLA: float = 0.12
# Si mueres pierdes esta parte del dinero negro (se lo quedan por el camino).
const MUERTE_PIERDE: float = 0.4


static func sospecha_por_segundo(negro: int) -> float:
	if negro < UMBRAL_SOSPECHOSO:
		return 0.0
	return clampf(float(negro) / SOSPECHA_NEGRO_REF, 0.1, SOSPECHA_POR_SEGUNDO_MAX)


static func fraccion_detencion(estrellas: int) -> float:
	return clampf(DETENCION_BASE + DETENCION_POR_ESTRELLA * float(estrellas), 0.0, 1.0)
