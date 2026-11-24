# magia.gd (datos)
# -----------------------------------------------------------------------------
# CATÁLOGO DE LA MAGIA: 4 escuelas con 3 hechizos cada una (ver docs/MAGIA.md).
# Cada escuela sube de nivel (1 a 5) al usar sus hechizos. El hechizo 1 de cada escuela se sabe
# desde el principio; el 2 se aprende al nivel 2 de la escuela y el 3 al nivel 3.
#
# Campos de cada hechizo:
#   nombre, descripcion   lo que ve el jugador.
#   coste                 maná que gasta (el nivel de la escuela lo abarata un 6 % por nivel).
#   espera                segundos hasta poder lanzarlo otra vez.
#   riesgo                0-1: cuánto llama la atención (1 = muy visible). La magia es ilegal.
#   tipo                  qué hace (lo programa magia.gd): "efecto", "curar", "crecer",
#                         "disfraz", "empujar", "abrir", "apagon", "pavor".
#   efecto, dur, fuerza   para tipo "efecto": un efecto de datos/efectos.gd.
#   radio, valor          alcance en metros y cantidad (vida, segundos de crecimiento...).
# Para equilibrar la magia basta con cambiar números aquí.
# -----------------------------------------------------------------------------
extends RefCounted

const MANA_MAX: float = 100.0
const MANA_REGEN: float = 2.0               # Maná por segundo (más 0,5 por cada nivel total de escuelas).
const XP_NIVEL: Array = [0, 80, 250, 600, 1300]   # XP de escuela para llegar a los niveles 1..5.
const NIVEL_HECHIZO: Array = [1, 2, 3]      # Nivel de escuela que pide cada hechizo (por orden).
const POTENCIA_POR_NIVEL: float = 0.15      # +15 % de efecto por nivel de escuela.
const DESCUENTO_POR_NIVEL: float = 0.06

# Riesgo legal: testigos que ven el hechizo.
const RADIO_GUARDIAS: float = 26.0          # Un guardia a esta distancia (o menos) lo ve.
const RADIO_GENTE: float = 16.0             # Un peatón a esta distancia lo ve (y sube la sospecha).
const SOSPECHA_POR_TESTIGO: float = 6.0     # x riesgo del hechizo.
const NOCHE_RIESGO: float = 0.5             # De noche te ven la mitad.

const ESCUELAS: Dictionary = {
	"naturaleza": {"nombre": "Naturaleza", "color": Color(0.35, 0.9, 0.4),
			"lema": "Hacer crecer, sanar y ver en la oscuridad."},
	"ilusion": {"nombre": "Ilusión", "color": Color(0.75, 0.45, 1.0),
			"lema": "Engañar a los ojos: pasar desapercibido, cambiar de cara, encandilar."},
	"fuerza": {"nombre": "Fuerza", "color": Color(1.0, 0.6, 0.2),
			"lema": "Empujar, protegerse y moverse como el viento."},
	"sombras": {"nombre": "Sombras", "color": Color(0.35, 0.45, 0.95),
			"lema": "Abrir lo cerrado, apagar las luces y sembrar el miedo."},
}

# Orden de los hechizos dentro de cada escuela (el índice decide el nivel que piden).
const ORDEN: Dictionary = {
	"naturaleza": ["brote", "sanar", "ojos_buho"],
	"ilusion": ["velo", "rostro_ajeno", "encanto"],
	"fuerza": ["empujon", "escudo", "zancada"],
	"sombras": ["ganzua_sombria", "apagon", "pavor"],
}

const HECHIZOS: Dictionary = {
	# ----------------------------- Naturaleza --------------------------------
	"brote": {"escuela": "naturaleza", "nombre": "Brote",
			"descripcion": "Las plantas de alrededor crecen de golpe (macetas a 8 m).",
			"coste": 25.0, "espera": 20.0, "riesgo": 0.4, "tipo": "crecer", "radio": 8.0, "valor": 45.0},
	"sanar": {"escuela": "naturaleza", "nombre": "Sanar",
			"descripcion": "Recuperas vida al momento y un poco más durante unos segundos.",
			"coste": 30.0, "espera": 12.0, "riesgo": 0.5, "tipo": "curar", "valor": 30.0,
			"efecto": "regeneracion", "dur": 10.0, "fuerza": 1.0},
	"ojos_buho": {"escuela": "naturaleza", "nombre": "Ojos de búho",
			"descripcion": "Ves de noche casi como de día.",
			"coste": 15.0, "espera": 5.0, "riesgo": 0.1, "tipo": "efecto", "efecto": "vision", "dur": 120.0, "fuerza": 1.0},
	# ------------------------------ Ilusión ----------------------------------
	"velo": {"escuela": "ilusion", "nombre": "Velo",
			"descripcion": "Te vuelves casi invisible: los guardias te ven desde mucho más cerca.",
			"coste": 35.0, "espera": 30.0, "riesgo": 0.2, "tipo": "efecto", "efecto": "sigilo", "dur": 25.0, "fuerza": 1.8},
	"rostro_ajeno": {"escuela": "ilusion", "nombre": "Rostro ajeno",
			"descripcion": "Cambias de cara: la policía pierde tu pista (baja una estrella y la alerta).",
			"coste": 50.0, "espera": 90.0, "riesgo": 0.0, "tipo": "disfraz", "valor": 1.0},
	"encanto": {"escuela": "ilusion", "nombre": "Encanto",
			"descripcion": "Encandilas a la gente: los clientes pagan más.",
			"coste": 30.0, "espera": 40.0, "riesgo": 0.3, "tipo": "efecto", "efecto": "carisma", "dur": 90.0, "fuerza": 1.0},
	# ------------------------------- Fuerza ----------------------------------
	"empujon": {"escuela": "fuerza", "nombre": "Empujón",
			"descripcion": "Una onda lanza hacia atrás a quien tengas delante (6 m) y le hace algo de daño.",
			"coste": 20.0, "espera": 4.0, "riesgo": 0.9, "tipo": "empujar", "radio": 6.0, "valor": 12.0},
	"escudo": {"escuela": "fuerza", "nombre": "Escudo",
			"descripcion": "Una coraza invisible: recibes mucho menos daño.",
			"coste": 35.0, "espera": 30.0, "riesgo": 0.6, "tipo": "efecto", "efecto": "resistencia", "dur": 30.0, "fuerza": 1.5},
	"zancada": {"escuela": "fuerza", "nombre": "Zancada",
			"descripcion": "Corres más y saltas más alto durante un rato.",
			"coste": 25.0, "espera": 20.0, "riesgo": 0.5, "tipo": "efecto", "efecto": "velocidad", "dur": 30.0, "fuerza": 1.3,
			"efecto2": "salto"},
	# ------------------------------- Sombras ---------------------------------
	"ganzua_sombria": {"escuela": "sombras", "nombre": "Ganzúa sombría",
			"descripcion": "Abres sin ruido la puerta cerrada que tengas delante (3,5 m).",
			"coste": 30.0, "espera": 15.0, "riesgo": 0.3, "tipo": "abrir", "radio": 3.5},
	"apagon": {"escuela": "sombras", "nombre": "Apagón",
			"descripcion": "Se apagan las luces de alrededor (25 m) durante un minuto y te escondes mejor.",
			"coste": 30.0, "espera": 60.0, "riesgo": 0.2, "tipo": "apagon", "radio": 25.0, "valor": 60.0,
			"efecto": "sigilo", "dur": 30.0, "fuerza": 0.6},
	"pavor": {"escuela": "sombras", "nombre": "Pavor",
			"descripcion": "Quien esté cerca (12 m) huye aterrado.",
			"coste": 40.0, "espera": 45.0, "riesgo": 0.8, "tipo": "pavor", "radio": 12.0},
}


static func escuela_de(id: String) -> String:
	return str(HECHIZOS[id]["escuela"])


static func indice(id: String) -> int:
	return (ORDEN[escuela_de(id)] as Array).find(id)


static func nivel_requerido(id: String) -> int:
	return int(NIVEL_HECHIZO[indice(id)])


static func nivel_por_xp(xp: float) -> int:
	var n: int = 1
	for i in XP_NIVEL.size():
		if xp >= float(XP_NIVEL[i]):
			n = i + 1
	return n


static func todos() -> Array:
	var out: Array = []
	for e in ORDEN:
		out.append_array(ORDEN[e])
	return out
