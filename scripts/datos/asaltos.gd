# asaltos.gd
# -----------------------------------------------------------------------------
# Las reglas de los ASALTOS A CASAS, todas en un sitio (sin escenas, fácil de probar):
#   - ajustes (se pueden apagar del todo: el juego no obliga a robar nunca),
#   - perfiles de casa (humilde / normal / rica) y cuánta gente duerme y va armada según el barrio,
#   - métodos de forzar puerta y ventana (tiempo, ruido, herramienta),
#   - botín por tipo de casa y de mueble,
#   - cómo se despierta la gente (ruido, luz, sigilo) y cómo reacciona.
# Lo usan entrada_forzable.gd, botin_casa.gd, vecino.gd y casa_asaltable.gd.
# -----------------------------------------------------------------------------
class_name Asaltos
extends RefCounted

# ------------------------------- Ajustes -------------------------------------
# "activo": false = las casas se quedan como antes (puertas abiertas, nadie dentro).
# "dificultad": 0 pacífico (nadie se despierta ni ataca), 1 normal, 2 duro, 3 brutal.
const NOMBRES_DIFICULTAD: Array = ["Pacífico", "Normal", "Duro", "Brutal"]
const MULT_DESPERTAR: Array = [0.0, 1.0, 1.7, 2.6]    # Qué fácil se despierta la gente.
const MULT_ARMADOS: Array = [0.0, 1.0, 1.5, 2.2]      # Cuánta gente va armada.
const MULT_DANO: Array = [0.0, 1.0, 1.3, 1.7]         # Daño que hacen al pelear.
const MULT_BOTIN: Array = [1.0, 1.0, 1.2, 1.5]        # Más riesgo, más botín.

const RUTA_AJUSTES: String = "user://asaltos.cfg"
static var activo: bool = true
static var dificultad: int = 1
static var puertas_cerradas: bool = true   # Las casas de otros vienen con la puerta cerrada con llave.
static var _cargado: bool = false


static func cargar_ajustes() -> void:
	_cargado = true
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(RUTA_AJUSTES) != OK:
		return
	activo = bool(cfg.get_value("asaltos", "activo", true))
	dificultad = clampi(int(cfg.get_value("asaltos", "dificultad", 1)), 0, 3)
	puertas_cerradas = bool(cfg.get_value("asaltos", "puertas_cerradas", true))


static func guardar_ajustes() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("asaltos", "activo", activo)
	cfg.set_value("asaltos", "dificultad", dificultad)
	cfg.set_value("asaltos", "puertas_cerradas", puertas_cerradas)
	cfg.save(RUTA_AJUSTES)


static func asegurar_ajustes() -> void:
	if not _cargado:
		cargar_ajustes()


# ------------------------------- Perfiles ------------------------------------
# ocupantes: cuánta gente duerme (mín, máx). botin: multiplicador. alarma: probabilidad de
# alarma antirrobo. sueno: lo profundo que duermen (1 = normal; más alto, cuesta más despertarles).
const PERFILES: Dictionary = {
	"humilde": {"nombre": "casa humilde", "ocupantes": [1, 2], "botin": 0.6, "alarma": 0.0, "sueno": 0.9, "cajones": 2},
	"normal": {"nombre": "casa normal", "ocupantes": [1, 3], "botin": 1.0, "alarma": 0.1, "sueno": 1.0, "cajones": 3},
	"rica": {"nombre": "casa rica", "ocupantes": [2, 4], "botin": 2.4, "alarma": 0.45, "sueno": 1.15, "cajones": 4},
}

# Probabilidad de que cada persona de la casa tenga un arma (según el barrio).
const ARMADOS_POR_DISTRITO: Dictionary = {"industrial": 0.4, "rico": 0.35, "centro": 0.12,
		"residencial": 0.15, "ciudad": 0.15, "": 0.12}


# "pequena": la casa es de una sola sala (ver InteriorCasa): gente humilde.
static func perfil_de(distrito: String, pequena: bool = false) -> String:
	if distrito == "rico":
		return "rica"
	if distrito == "industrial" or pequena:
		return "humilde"
	return "normal"


# ¿Se puede asaltar esta casa del mundo (diccionario de GeneradorMundo.casa)? Solo las viviendas
# normales: las que están en alquiler/venta (id), los servicios y las tiendas/almacenes no.
static func es_asaltable(c: Dictionary) -> bool:
	asegurar_ajustes()
	if not activo or not puertas_cerradas:
		return false
	if str(c.get("id", "")) != "" or c.has("servicio"):
		return false
	var d: String = str(c.get("distrito", ""))
	return d != "industrial" and d != "centro"


# ¿Asaltaste esta casa hace poco? Entonces ya no tiene la puerta cerrada ni botín.
static func forzada_reciente(id: String) -> bool:
	var casas: Dictionary = Juego.asaltos_info.get("casas", {})
	return casas.has(id) and Juego.dia - int(casas[id]) < DIAS_REPOSICION


# Nombre estable de una casa del mundo para guardar si la asaltaste.
static func id_de_casa(c: Dictionary) -> String:
	return "casa_%d_%d" % [roundi(float(c["x"])), roundi(float(c["z"]))]


# ¿Hay gente en casa a esta hora? De noche duermen todos; por la mañana temprano y al anochecer
# están en casa pero despiertos y atentos; de día suele estar vacía (trabajo, colegio).
# Devuelve {"presentes": probabilidad de que cada ocupante esté, "duermen": bool}.
static func ocupacion_a_las(hora: float) -> Dictionary:
	if hora >= 22.0 or hora < 6.0:
		return {"presentes": 1.0, "duermen": true}
	if hora < 9.0 or hora >= 19.0:
		return {"presentes": 0.7, "duermen": false}
	return {"presentes": 0.3, "duermen": false}


# ------------------------------ Entradas -------------------------------------
# Cada método: segundos, ruido (0 a 1), herramienta que gasta ("" = ninguna), daño que te haces.
const METODOS_PUERTA: Dictionary = {
	"ganzua": {"nombre": "ganzúa", "tiempo": 7.0, "ruido": 0.12, "herramienta": "ganzua", "rotura": 0.15, "dano": 0.0},
	"palanca": {"nombre": "palanca", "tiempo": 3.0, "ruido": 0.75, "herramienta": "palanca", "rotura": 0.0, "dano": 0.0},
	"patada": {"nombre": "patadas", "tiempo": 5.0, "ruido": 1.0, "herramienta": "", "rotura": 0.0, "dano": 4.0},
}
const METODOS_VENTANA: Dictionary = {
	"ganzua": {"nombre": "ganzúa", "tiempo": 9.0, "ruido": 0.08, "herramienta": "ganzua", "rotura": 0.2, "dano": 0.0},
	"palanca": {"nombre": "palanca", "tiempo": 5.0, "ruido": 0.5, "herramienta": "palanca", "rotura": 0.0, "dano": 0.0},
	"romper": {"nombre": "romper el cristal", "tiempo": 2.5, "ruido": 0.9, "herramienta": "", "rotura": 0.0, "dano": 6.0},
}
const MULT_TIEMPO_PERFIL: Dictionary = {"humilde": 0.8, "normal": 1.0, "rica": 1.5}   # Mejores cerraduras.


static func metodo(tipo_entrada: String, id_metodo: String) -> Dictionary:
	var tabla: Dictionary = METODOS_PUERTA if tipo_entrada == "puerta" else METODOS_VENTANA
	return tabla.get(id_metodo, {})


# Segundos que cuesta forzar. La habilidad "sigilo" (y el efecto de sigilo) lo hace más rápido.
static func tiempo_forzar(tipo_entrada: String, id_metodo: String, perfil: String) -> float:
	var m: Dictionary = metodo(tipo_entrada, id_metodo)
	if m.is_empty():
		return 0.0
	var t: float = float(m["tiempo"]) * float(MULT_TIEMPO_PERFIL.get(perfil, 1.0))
	if Juego.habilidades.has("sigilo"):
		t *= 0.8
	return t


# Ruido de la acción (el sigilo lo baja). 0 a 1.
static func ruido_forzar(tipo_entrada: String, id_metodo: String) -> float:
	var m: Dictionary = metodo(tipo_entrada, id_metodo)
	if m.is_empty():
		return 0.0
	var r: float = float(m["ruido"])
	if Juego.habilidades.has("sigilo"):
		r *= 0.7
	return clampf(r * clampf(1.0 - Juego.mod("sigilo"), 0.3, 1.8), 0.0, 1.0)


# El mejor método "silencioso" y el mejor "a lo bruto" con lo que llevas en la mochila.
static func metodo_silencioso(tipo_entrada: String) -> String:
	return "ganzua" if Juego.tiene("ganzua") else ""


static func metodo_bruto(tipo_entrada: String) -> String:
	if Juego.tiene("palanca"):
		return "palanca"
	return "patada" if tipo_entrada == "puerta" else "romper"


# ------------------------------- Botín ---------------------------------------
# Cada contenedor da dinero (va al dinero negro) y a veces objetos que se pueden vender.
# "dinero": [mín, máx] a multiplicar por el perfil. "objetos": [id, probabilidad, cantidad máx].
const CONTENEDORES: Dictionary = {
	"cajon": {"nombre": "cajón", "tiempo": 2.0, "ruido": 0.18, "dinero": [8, 45],
			"objetos": [["plata", 0.15, 1], ["reloj_oro", 0.08, 1]]},
	"joyero": {"nombre": "joyero", "tiempo": 3.0, "ruido": 0.12, "dinero": [0, 30],
			"objetos": [["joyas", 0.6, 1], ["reloj_oro", 0.3, 1]]},
	"armario": {"nombre": "armario", "tiempo": 2.5, "ruido": 0.22, "dinero": [5, 35],
			"objetos": [["electronica", 0.2, 1], ["licor", 0.3, 2]]},
	"caja_fuerte": {"nombre": "caja fuerte", "tiempo": 8.0, "ruido": 0.1, "dinero": [90, 320],
			"objetos": [["joyas", 0.7, 2], ["cuadro", 0.15, 1]], "herramienta": "ganzua"},
}
# Qué contenedores hay en cada perfil de casa, por orden (el último solo en casas ricas con caja fuerte).
const CONTENEDORES_POR_PERFIL: Dictionary = {
	"humilde": ["cajon", "armario"],
	"normal": ["cajon", "joyero", "armario"],
	"rica": ["cajon", "joyero", "armario", "caja_fuerte"],
}


# Lo que hay dentro de un contenedor: {"dinero": int, "objetos": [[id, n], ...]}.
static func botin(perfil: String, contenedor: String, rng: RandomNumberGenerator) -> Dictionary:
	var c: Dictionary = CONTENEDORES.get(contenedor, {})
	if c.is_empty():
		return {"dinero": 0, "objetos": []}
	var mult: float = float(PERFILES.get(perfil, PERFILES["normal"])["botin"]) * float(MULT_BOTIN[clampi(dificultad, 0, 3)])
	var rango: Array = c["dinero"]
	var dinero: int = int(round(rng.randf_range(float(rango[0]), float(rango[1])) * mult))
	var objetos: Array = []
	for o in c["objetos"]:
		if rng.randf() < float(o[1]) * minf(1.6, 0.6 + mult * 0.4):
			objetos.append([str(o[0]), rng.randi_range(1, int(o[2]))])
	return {"dinero": dinero, "objetos": objetos}


# El dinero robado es negro si existe esa cuenta (rama de dinero limpio y negro); si no, va a la cartera.
static func cobrar_botin(cantidad: int) -> void:
	if cantidad <= 0:
		return
	if Juego.has_method("cobrar_negro"):
		Juego.call("cobrar_negro", cantidad)
	else:
		Juego.cobrar(cantidad)


# ------------------------------ Ocupantes ------------------------------------
const ROLES: Array = [
	{"id": "padre", "nombre": "El hombre de la casa", "vida": 70.0, "vel": 3.6, "peso": 3.0},
	{"id": "madre", "nombre": "La mujer de la casa", "vida": 55.0, "vel": 3.8, "peso": 3.0},
	{"id": "abuelo", "nombre": "El abuelo", "vida": 40.0, "vel": 2.2, "peso": 1.2},
	{"id": "joven", "nombre": "El chaval", "vida": 60.0, "vel": 4.3, "peso": 1.6},
]
# Reacciones al despertar y a verte.
const REACCIONES: Array = ["huir", "llamar", "punos", "objeto", "arma"]
# Peso base de cada reacción por rol (sin arma). Con arma pesa mucho "arma".
const PESOS_REACCION: Dictionary = {
	"padre": {"huir": 0.5, "llamar": 1.0, "punos": 2.5, "objeto": 2.0},
	"madre": {"huir": 1.2, "llamar": 2.5, "punos": 0.6, "objeto": 1.4},
	"abuelo": {"huir": 0.8, "llamar": 2.2, "punos": 0.2, "objeto": 1.6},
	"joven": {"huir": 1.4, "llamar": 1.0, "punos": 1.4, "objeto": 1.0},
}
const ARMAS_OCUPANTE: Dictionary = {
	"punos": {"nombre": "los puños", "dano": 6.0, "alcance": 1.6, "pausa": 1.1},
	"objeto": {"nombre": "un objeto", "dano": 11.0, "alcance": 1.8, "pausa": 1.3},   # Sartén, lámpara, bate...
	"arma": {"nombre": "una pistola", "dano": 13.0, "alcance": 14.0, "pausa": 1.4},
}


static func rol_aleatorio(rng: RandomNumberGenerator) -> Dictionary:
	var total: float = 0.0
	for r in ROLES:
		total += float(r["peso"])
	var x: float = rng.randf() * total
	for r in ROLES:
		x -= float(r["peso"])
		if x <= 0.0:
			return r
	return ROLES[0]


# ¿Esta persona va armada? Depende del barrio y de la dificultad.
static func va_armado(distrito: String, rng: RandomNumberGenerator) -> bool:
	var p: float = float(ARMADOS_POR_DISTRITO.get(distrito, 0.12)) * float(MULT_ARMADOS[clampi(dificultad, 0, 3)])
	return rng.randf() < p


# Elige cómo reacciona al despertarse. Armados: casi siempre se enfrentan con el arma.
static func elegir_reaccion(rol: String, armado: bool, rng: RandomNumberGenerator) -> String:
	if armado and rng.randf() < 0.75:
		return "arma"
	var pesos: Dictionary = PESOS_REACCION.get(rol, PESOS_REACCION["padre"])
	var total: float = 0.0
	for k in pesos:
		total += float(pesos[k])
	var x: float = rng.randf() * total
	for k in pesos:
		x -= float(pesos[k])
		if x <= 0.0:
			return str(k)
	return "llamar"


# ------------------------------ Despertar ------------------------------------
const ALCANCE_RUIDO: float = 16.0      # A esta distancia ya no se oye nada.
const UMBRAL_DESPERTAR: float = 1.0    # La "alerta" del durmiente llega a esto y se despierta.
const GANANCIA_RUIDO: float = 0.9      # Cuánto sube la alerta con un ruido fuerte y cercano.
const GANANCIA_LUZ: float = 0.16       # Por segundo con la linterna apuntándole de cerca.
const BAJADA_ALERTA: float = 0.08      # Por segundo: si te quedas quieto, el sueño vuelve.


# Cuánta alerta gana un durmiente por un ruido de "intensidad" (0 a 1) a "distancia" metros.
# "pared": true si el ruido sale de fuera de la casa (la pared lo apaga).
static func alerta_por_ruido(intensidad: float, distancia: float, sueno: float, pared: bool) -> float:
	var cerca: float = clampf(1.0 - distancia / ALCANCE_RUIDO, 0.0, 1.0)
	var a: float = intensidad * cerca * GANANCIA_RUIDO / maxf(sueno, 0.1)
	if pared:
		a *= 0.55
	return a * float(MULT_DESPERTAR[clampi(dificultad, 0, 3)])


# Ruido de tus pasos dentro de la casa (por segundo y con el sigilo ya aplicado).
static func ruido_pasos(velocidad: float, agachado: bool, corriendo: bool) -> float:
	if velocidad < 0.6:
		return 0.0
	var r: float = 0.08
	if agachado:
		r = 0.025
	elif corriendo:
		r = 0.4
	r *= clampf(1.0 - Juego.mod("sigilo"), 0.3, 1.8)
	if Juego.habilidades.has("sigilo"):
		r *= 0.7
	return r


# ----------------------------- Consecuencias ---------------------------------
# Estrellas por delito. Se suman con Juego.exigir_estrellas (nunca bajan).
const ESTRELLAS_ALLANAMIENTO: int = 1       # Te ven dentro (o salta la alarma).
const ESTRELLAS_DENUNCIA: int = 2           # Un testigo llama a la policía.
const ESTRELLAS_HERIDO: int = 2             # Hieres a un ocupante.
const ESTRELLAS_MUERTE: int = 4             # Matas a un ocupante.
const SEGUNDOS_HASTA_DENUNCIA: float = 8.0  # Lo que tarda el testigo en llamar.
const DIAS_BUSCADO: int = 2                 # Días que dura la denuncia en tu contra.
const DANO_MORTAL: float = 15.0             # Un golpe de al menos esto que lo deja a cero = muerte; menos = inconsciente.
const DIAS_REPOSICION: int = 3              # Tras asaltar una casa, tarda estos días en volver a tener botín.

# Info persistente de asaltos (se guarda con la partida): {"casas": {id: dia}, "buscado_hasta": dia,
# "asaltos": n, "robado": n}
static func nueva_info() -> Dictionary:
	return {"casas": {}, "buscado_hasta": 0, "asaltos": 0, "robado": 0}
