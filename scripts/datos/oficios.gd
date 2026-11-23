# oficios.gd
# -----------------------------------------------------------------------------
# CATÁLOGO DE OFICIOS. Cualquier persona puede hacerse policía, médico, bombero o
# mecánico: se ficha en su lugar de trabajo (Mayús+E en hospital y taller; E en
# comisaría y parque de bomberos) y se "entra de servicio". En servicio salen
# AVISOS por la calle (un marcador con su luz): llegas, pulsas E varias veces y
# cobras. Con los avisos ganas experiencia de oficio y asciendes de rango (más
# sueldo y ventajas). Todo en datos para ajustar sin tocar código:
#
#   nombre, lugar (servicio donde se ficha), sueldo_hora ($ por hora de juego en
#   servicio, multiplicado por el rango), rangos [[nombre, xp, multiplicador]],
#   avisos [{texto, tipo (aspecto del marcador), local (opcional: pide un cliente de
#   datos/peluqueria.gd), pago, xp, golpes (pulsaciones de
#   E para resolverlo), riesgo (vida que pierdes al resolverlo)}], ventaja.
# Para añadir un oficio nuevo copia una entrada (y, si hace falta, un lugar nuevo
# en generador_mundo.gd).
# -----------------------------------------------------------------------------
extends RefCounted

const LISTA: Dictionary = {
	"policia": {
		"nombre": "Policía", "lugar": "comisaria", "sueldo_hora": 14.0,
		"rangos": [["Agente", 0, 1.0], ["Sargento", 120, 1.4], ["Inspector", 350, 1.9], ["Comisario", 800, 2.6]],
		"avisos": [
			{"texto": "Altercado en la calle", "tipo": "altercado", "pago": 38, "xp": 14, "golpes": 3, "riesgo": 8.0},
			{"texto": "Robo en un comercio", "tipo": "altercado", "pago": 55, "xp": 20, "golpes": 4, "riesgo": 10.0},
		],
		"ventaja": "De servicio no te registran los guardias; desde Sargento, nunca.",
		"requisito": "Sin búsqueda activa (0 estrellas) y poca sospecha.",
	},
	"medico": {
		"nombre": "Médico", "lugar": "hospital", "sueldo_hora": 16.0,
		"rangos": [["Practicante", 0, 1.0], ["Médico", 120, 1.4], ["Cirujano", 350, 1.9], ["Director del hospital", 800, 2.6]],
		"avisos": [
			{"texto": "Persona herida en la calle", "tipo": "herido", "pago": 42, "xp": 14, "golpes": 2, "riesgo": 0.0},
			{"texto": "Desmayo: hay que atenderlo", "tipo": "herido", "pago": 34, "xp": 12, "golpes": 2, "riesgo": 0.0},
		],
		"ventaja": "Descuento en el hospital: 25 % (Practicante) hasta 70 % (Director).",
		"requisito": "",
	},
	"bombero": {
		"nombre": "Bombero", "lugar": "bomberos", "sueldo_hora": 15.0,
		"rangos": [["Aspirante", 0, 1.0], ["Bombero", 120, 1.4], ["Sargento de bomberos", 350, 1.9], ["Jefe de parque", 800, 2.6]],
		"avisos": [
			{"texto": "Incendio en una casa", "tipo": "fuego", "pago": 60, "xp": 20, "golpes": 4, "riesgo": 12.0},
			{"texto": "Fuego en un contenedor", "tipo": "fuego", "pago": 30, "xp": 10, "golpes": 2, "riesgo": 4.0},
		],
		"ventaja": "De servicio recibes menos daño: 10 % (Aspirante) hasta 40 % (Jefe).",
		"requisito": "",
	},
	"mecanico": {
		"nombre": "Mecánico", "lugar": "taller", "sueldo_hora": 12.0,
		"rangos": [["Aprendiz", 0, 1.0], ["Oficial", 120, 1.4], ["Maestro", 350, 1.9], ["Jefe de taller", 800, 2.6]],
		"avisos": [
			{"texto": "Coche averiado en la calzada", "tipo": "averia", "pago": 36, "xp": 12, "golpes": 3, "riesgo": 0.0},
		],
		"ventaja": "Descuento en el taller: 20 % (Aprendiz) hasta 60 % (Jefe).",
		"requisito": "",
	},
	"peluquero": {
		"nombre": "Peluquero", "lugar": "peluqueria", "sueldo_hora": 11.0,
		"rangos": [["Aprendiz de tijeras", 0, 1.0], ["Peluquero", 120, 1.4], ["Estilista", 350, 1.9], ["Maestro del salón", 800, 2.6]],
		"avisos": [
			{"texto": "Cliente a domicilio", "tipo": "cliente", "local": "peluqueria", "pago": 34, "xp": 12, "golpes": 3, "riesgo": 0.0},
			{"texto": "Novia con prisa", "tipo": "cliente", "local": "peluqueria", "pago": 52, "xp": 18, "golpes": 4, "riesgo": 0.0},
		],
		"ventaja": "Cortes y tintes a mitad de precio en las peluquerías.",
		"requisito": "",
	},
	"barbero": {
		"nombre": "Barbero", "lugar": "barberia", "sueldo_hora": 11.0,
		"rangos": [["Aprendiz de navaja", 0, 1.0], ["Barbero", 120, 1.4], ["Maestro barbero", 350, 1.9], ["Barbero real", 800, 2.6]],
		"avisos": [
			{"texto": "Cliente con barba", "tipo": "cliente", "local": "barberia", "pago": 32, "xp": 12, "golpes": 3, "riesgo": 0.0},
			{"texto": "Afeitado de gala", "tipo": "cliente", "local": "barberia", "pago": 48, "xp": 16, "golpes": 4, "riesgo": 0.0},
		],
		"ventaja": "Cortes y barbas a mitad de precio en las barberías.",
		"requisito": "",
	},
}

const DESCUENTO_HOSPITAL: Array = [0.25, 0.4, 0.55, 0.7]
const DESCUENTO_TALLER: Array = [0.2, 0.3, 0.45, 0.6]
const REDUCCION_DANO_BOMBERO: Array = [0.1, 0.2, 0.3, 0.4]
const AVISO_ESPERA_MIN: float = 40.0     # Segundos reales entre avisos (mínimo y máximo).
const AVISO_ESPERA_MAX: float = 85.0
const AVISO_DURACION: float = 170.0      # Tiempo para llegar y resolverlo.
const AVISO_DIST_MIN: float = 70.0
const AVISO_DIST_MAX: float = 150.0
const XP_POR_HORA: float = 3.0           # XP de oficio por hora de juego en servicio.
const CONVALECENCIA_HOSPITAL: float = 90.0   # Segundos sin correr al salir del hospital.
const CONVALECENCIA_MEDICO: float = 45.0     # ...y del médico de la botica.


static func existe(id: String) -> bool:
	return LISTA.has(id)


static func nombre(id: String) -> String:
	return str(LISTA[id]["nombre"]) if LISTA.has(id) else ""


static func oficio_de_lugar(lugar: String) -> String:
	for id in LISTA:
		if str(LISTA[id]["lugar"]) == lugar:
			return id
	return ""


# Posición (0..3) del rango que corresponde a esa experiencia.
static func indice_rango(id: String, xp: int) -> int:
	if not LISTA.has(id):
		return 0
	var r: Array = LISTA[id]["rangos"]
	var mejor: int = 0
	for i in r.size():
		if xp >= int(r[i][1]):
			mejor = i
	return mejor


static func nombre_rango(id: String, xp: int) -> String:
	return str(LISTA[id]["rangos"][indice_rango(id, xp)][0]) if LISTA.has(id) else ""


static func multiplicador(id: String, xp: int) -> float:
	return float(LISTA[id]["rangos"][indice_rango(id, xp)][2]) if LISTA.has(id) else 1.0


# XP del siguiente rango, o -1 si ya eres el jefe.
static func xp_siguiente(id: String, xp: int) -> int:
	if not LISTA.has(id):
		return -1
	var i: int = indice_rango(id, xp)
	var r: Array = LISTA[id]["rangos"]
	return int(r[i + 1][1]) if i + 1 < r.size() else -1
