# policia.gd
# -----------------------------------------------------------------------------
# Los números de la policía por estrellas (niveles de búsqueda), en un solo sitio.
# Cada delito sube las estrellas (Juego.subir_estrellas); si te pierden de vista
# bajan solas. Más estrellas = guardias más rápidos, refuerzos que aparecen cerca
# y, desde 3 estrellas, coches patrulla. Sin class_name:
# preload("res://scripts/datos/policia.gd").
# -----------------------------------------------------------------------------
extends RefCounted

const MAX_ESTRELLAS: int = 5

# Índice = estrellas (0 a 5).
const VELOCIDAD_GUARDIA: Array = [1.0, 1.0, 1.1, 1.2, 1.3, 1.4]   # Multiplica la carrera del guardia.
const DANO_GUARDIA: Array = [8.0, 8.0, 10.0, 12.0, 15.0, 20.0]    # Golpe por segundo.
const REFUERZOS: Array = [0, 0, 2, 3, 5, 7]                       # Guardias extra cerca de ti.
const COCHES: Array = [0, 0, 0, 1, 2, 3]                          # Coches patrulla persiguiéndote.
const SEGUNDOS_PARA_BAJAR: Array = [0.0, 25.0, 35.0, 45.0, 60.0, 80.0]   # Fuera de su vista, cada cuánto pierdes 1.
const MULTA_DETENCION: Array = [0, 40, 120, 300, 700, 1500]       # Mínimo; también un % de tu dinero.
const MULTA_DETENCION_PORCENTAJE: float = 0.04
const HORAS_CARCEL: Array = [0.0, 2.0, 4.0, 6.0, 8.0, 12.0]       # Horas de juego que pasas retenido.

const DISTANCIA_REFUERZO_MIN: float = 38.0
const DISTANCIA_REFUERZO_MAX: float = 60.0
const DISTANCIA_BORRAR_REFUERZO: float = 140.0

# La riqueza atrae vigilancia: sube un poco la probabilidad de cacheo y el nº de refuerzos.
# Devuelve 0.0 (pobre) a 1.0 (muy rico).
static func riqueza(dinero: int) -> float:
	return clampf(log(maxf(1.0, float(dinero)) / 500.0) / log(200.0), 0.0, 1.0)


static func texto_estrellas(n: int) -> String:
	var s: String = ""
	for i in MAX_ESTRELLAS:
		s += "★" if i < n else "☆"
	return s
