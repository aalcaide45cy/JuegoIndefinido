# locales.gd  (datos)
# -----------------------------------------------------------------------------
# NEGOCIOS EN LOS QUE SE PUEDE ENTRAR: restaurante, bar, cafetería, panadería,
# taberna y taller (y los que vengan). Todo son datos: para añadir un negocio
# nuevo se copia una entrada de LOCALES y se le pone su "carta" (lista de ids de
# PRODUCTOS). El edificio, el interior, el mostrador, la ventana y los precios
# salen solos (ver objetos/local_mundo.gd y ui/ventana_local.gd).
#
#   LOCALES   id -> nombre del tipo, tamaño del edificio, color, horario, estilo
#             de decoración, carta, nombres de local (para la variedad) y toque
#             de fantasía.
#   PRODUCTOS id -> lo que vendes y lo que hace: hambre, sed, vida, energia
#             (resistencia), efectos temporales, alcohol, o un objeto para llevar.
#             "magico": id de objeto que gasta (una hoja de bruma): el toque de fantasía.
#             "vehiculo": servicios del taller (reparar, repostar...).
#
# Variedad entre locales: cada local de un mismo tipo tiene su propio nombre,
# colores, disposición, precios (±15 %) y un plato del día con -20 %. Todo sale de
# la semilla del local, así que siempre es el mismo en la misma partida.
#
# El dinero que se gasta aquí es dinero "limpio" (Juego.gastar). El dinero negro
# (PR 15) aún no está en esta rama: cuando llegue, gastar() es el único sitio a tocar.
# -----------------------------------------------------------------------------
extends RefCounted

const Efectos = preload("res://scripts/datos/efectos.gd")

# Hora del juego (0-24). Si cierra < abre, pasa de medianoche.
const LOCALES: Dictionary = {
	"restaurante": {
		"nombre": "Restaurante", "npc": "Camarero", "estilo": "comedor",
		"ancho": 20.0, "fondo": 14.0, "color": Color(0.8, 0.55, 0.35), "franja": Color(0.85, 0.3, 0.2),
		"abre": 12.0, "cierra": 24.0,
		"carta": ["ensalada", "sopa", "estofado", "asado", "trucha_bruma", "banquete_bruma", "tarta_miel", "vino", "agua"],
		"nombres": ["El Duende Goloso", "La Cuchara de Plata", "Casa Marisol", "El Caldero Dorado", "La Luna Llena", "Los Tres Gatos"],
		"fantasia": "Platos encantados con hoja de bruma que dan efectos como las pociones.",
	},
	"bar": {
		"nombre": "Bar", "npc": "Barman", "estilo": "barra",
		"ancho": 16.0, "fondo": 11.0, "color": Color(0.55, 0.32, 0.4), "franja": Color(0.2, 0.65, 0.75),
		"abre": 12.0, "cierra": 3.0,
		"carta": ["cerveza", "vino", "limonada", "chupito_bruma", "tapas", "bocata", "patatas", "agua"],
		"nombres": ["Bar El Gnomo", "Bar La Esquina", "Bar Ojo de Gato", "Bar Casa Pepe", "Bar El Rincón", "Bar La Hoja"],
		"fantasia": "El chupito de bruma te vuelve casi invisible un rato. Ojo: la cuarta copa marea.",
	},
	"cafeteria": {
		"nombre": "Cafetería", "npc": "Camarera", "estilo": "cafe",
		"ancho": 14.0, "fondo": 10.0, "color": Color(0.85, 0.75, 0.6), "franja": Color(0.45, 0.28, 0.15),
		"abre": 6.0, "cierra": 22.0,
		"carta": ["cafe_solo", "cafe_leche", "te_bruma", "croissant", "tostada", "zumo", "tarta_miel", "batido_estrella"],
		"nombres": ["Café La Nube", "Café del Reloj", "Café Violeta", "Café Los Sueños", "Café Pluma", "Café Bruma"],
		"fantasia": "El té de bruma calma los nervios y el batido de estrella da buen humor.",
	},
	"panaderia": {
		"nombre": "Panadería", "npc": "Panadero", "estilo": "panaderia",
		"ancho": 14.0, "fondo": 10.0, "color": Color(0.9, 0.78, 0.5), "franja": Color(0.75, 0.5, 0.2),
		"abre": 6.0, "cierra": 15.0,
		"carta": ["pan_barra", "empanada", "bollo", "pastel_nata", "pan_bruma", "pan_llevar", "empanada_llevar"],
		"nombres": ["Panadería La Espiga", "Horno de San Remigio", "Panadería El Trigal", "Horno La Abuela", "Panadería Miga de Oro"],
		"fantasia": "El pan de bruma lo hornean de madrugada y te hace correr un rato.",
	},
	"taberna": {
		"nombre": "Taberna", "npc": "Tabernero", "estilo": "taberna",
		"ancho": 16.0, "fondo": 11.0, "color": Color(0.5, 0.3, 0.18), "franja": Color(0.7, 0.2, 0.15),
		"abre": 11.0, "cierra": 2.0,
		"carta": ["cerveza", "vino_especiado", "hidromiel_bruma", "estofado", "sopa", "queso_pan", "agua"],
		"nombres": ["Taberna del Jabalí", "Taberna La Jarra Rota", "Posada del Cuervo", "Taberna El Tonel", "Taberna Los Ocho Barriles"],
		"fantasia": "La hidromiel de bruma sube la fama y ayuda a escuchar rumores.",
	},
	"posada": {
		"nombre": "Posada", "npc": "Posadero", "estilo": "posada",
		"ancho": 20.0, "fondo": 14.0, "color": Color(0.6, 0.45, 0.3), "franja": Color(0.3, 0.45, 0.75),
		"abre": 0.0, "cierra": 24.0,
		"carta": ["cama_posada", "cama_bruma", "desayuno_posada", "agua"],
		"nombres": ["Posada del Gallo Dormilón", "Hostal La Almohada", "Posada Luna de Miel", "Hostal El Cuco", "Posada Las Cuatro Camas"],
		"fantasia": "La cama de bruma te regala un sueño con efectos al despertar.",
	},
	"gimnasio": {
		"nombre": "Gimnasio", "npc": "Entrenador", "estilo": "gimnasio",
		"ancho": 20.0, "fondo": 14.0, "color": Color(0.35, 0.5, 0.6), "franja": Color(0.9, 0.35, 0.15),
		"abre": 7.0, "cierra": 23.0,
		"carta": ["entrena_fuerza", "entrena_agilidad", "entrena_constitucion", "entrena_bruma", "batido_proteico", "agua"],
		"nombres": ["Gimnasio Músculo de Piedra", "Gimnasio El Mamut", "Gimnasio Titán", "Gimnasio La Pesa Feliz", "Gimnasio Hierro y Bruma"],
		"fantasia": "El entrenamiento de bruma sube un atributo al azar sin pasar por las pesas.",
	},
	"peluqueria": {
		"nombre": "Peluquería", "npc": "Peluquera", "estilo": "salon", "tipo": "aspecto",
		"ancho": 18.0, "fondo": 12.0, "color": Color(0.85, 0.6, 0.7), "franja": Color(0.95, 0.45, 0.7),
		"abre": 9.0, "cierra": 21.0, "carta": [],
		"nombres": ["Peluquería Tijeras de Luna", "Salón Mechón Dorado", "Peluquería La Madeja", "Estilismo Bruma", "Peluquería Rizos"],
		"fantasia": "Tintes mágicos de hoja de bruma: verde bruma y violeta de luna.",
	},
	"barberia": {
		"nombre": "Barbería", "npc": "Barbero", "estilo": "barberia", "tipo": "aspecto",
		"ancho": 18.0, "fondo": 12.0, "color": Color(0.55, 0.32, 0.25), "franja": Color(0.85, 0.15, 0.15),
		"abre": 9.0, "cierra": 21.0, "carta": [],
		"nombres": ["Barbería Navaja de Plata", "Barbería El Bigote", "Barbería Don Isidro", "Barbería La Perilla", "Barbería Luna Nueva"],
		"fantasia": "La navaja de plata deja un afeitado «de luna».",
	},
	"taller": {
		"nombre": "Taller", "npc": "Mecánico", "estilo": "taller", "tipo": "taller",
		"ancho": 20.0, "fondo": 14.0, "color": Color(0.3, 0.32, 0.36), "franja": Color(0.95, 0.7, 0.1),
		"abre": 8.0, "cierra": 20.0,
		"carta": ["reparar", "revision", "repostar", "bidon", "aceite_bruma"],
		"nombres": ["Taller Hermanos Vega", "Taller El Pistón", "Taller Tuerca y Tornillo", "Taller La Llave Inglesa", "Taller Cuatro Ruedas"],
		"fantasia": "El aceite de bruma deja el vehículo como nuevo y con el depósito lleno.",
	},
}

# Los productos. Campos (todos opcionales menos nombre y precio):
#   hambre / sed   cuánto bajan (0-100).     vida / energia   cuánto suben.
#   efectos        [{"id", "dur", "f"}] de datos/efectos.gd.   alcohol   1 = copa (la 4ª marea).
#   magico         objeto que gasta.         objeto   objeto que te llevas (en vez de comerlo aquí).
#   vehiculo       solo taller: "reparar", "revision", "repostar", "bidon" o "bruma".
const PRODUCTOS: Dictionary = {
	# ------------------------------- comida -----------------------------------
	"ensalada": {"nombre": "Ensalada del huerto", "precio": 14, "hambre": 25, "vida": 3,
			"desc": "Fresca y ligera."},
	"sopa": {"nombre": "Sopa de huesos", "precio": 16, "hambre": 30, "vida": 5,
			"efectos": [{"id": "regeneracion", "dur": 20.0, "f": 0.8}], "desc": "Caliente y espesa."},
	"estofado": {"nombre": "Estofado del Prefecto", "precio": 30, "hambre": 50, "vida": 12,
			"efectos": [{"id": "resistencia", "dur": 60.0, "f": 0.6}], "desc": "Un plato de ricos."},
	"asado": {"nombre": "Asado de la casa", "precio": 42, "hambre": 70, "vida": 20,
			"efectos": [{"id": "regeneracion", "dur": 30.0, "f": 1.0}], "desc": "Cura y sacia de verdad."},
	"trucha_bruma": {"nombre": "Trucha a la bruma", "precio": 38, "hambre": 45, "vida": 8, "magico": "hierba_bruma",
			"efectos": [{"id": "vision", "dur": 120.0, "f": 1.0}], "desc": "Ojos de gato un buen rato."},
	"banquete_bruma": {"nombre": "Banquete encantado", "precio": 90, "hambre": 100, "sed": 40, "vida": 40, "magico": "hierba_bruma",
			"efectos": [{"id": "resistencia", "dur": 90.0, "f": 1.0}, {"id": "regeneracion", "dur": 40.0, "f": 1.0},
					{"id": "concentracion", "dur": 90.0, "f": 0.8}],
			"desc": "El plato que cocinan los duendes."},
	"tarta_miel": {"nombre": "Tarta de miel", "precio": 12, "hambre": 14, "vida": 2,
			"efectos": [{"id": "buen_humor", "dur": 90.0, "f": 0.6}], "desc": "Dulce y feliz."},
	"tapas": {"nombre": "Tapas variadas", "precio": 14, "hambre": 28, "desc": "Para compartir (o no)."},
	"bocata": {"nombre": "Bocata de la casa", "precio": 11, "hambre": 35, "desc": "Contundente."},
	"patatas": {"nombre": "Patatas bravas", "precio": 8, "hambre": 20, "desc": "Pican más de lo que parece."},
	"queso_pan": {"nombre": "Queso y pan", "precio": 9, "hambre": 25, "desc": "Sencillo y bueno."},
	"croissant": {"nombre": "Cruasán", "precio": 6, "hambre": 14, "desc": "Crujiente."},
	"tostada": {"nombre": "Tostada con tomate", "precio": 7, "hambre": 18, "desc": "El desayuno de siempre."},
	# ------------------------------- bebida -----------------------------------
	"agua": {"nombre": "Jarra de agua", "precio": 3, "sed": 40, "desc": "Fresquita."},
	"vino": {"nombre": "Copa de vino", "precio": 16, "sed": 20, "alcohol": 1,
			"efectos": [{"id": "carisma", "dur": 90.0, "f": 0.8}], "desc": "Suelta la lengua."},
	"cerveza": {"nombre": "Caña de cerveza", "precio": 8, "sed": 30, "hambre": 3, "alcohol": 1,
			"efectos": [{"id": "calma", "dur": 60.0, "f": 0.8}], "desc": "Baja la sospecha."},
	"limonada": {"nombre": "Limonada", "precio": 6, "sed": 35, "desc": "Sin alcohol."},
	"zumo": {"nombre": "Zumo de naranja", "precio": 7, "sed": 30, "hambre": 5, "desc": "Recién exprimido."},
	"chupito_bruma": {"nombre": "Chupito de bruma", "precio": 20, "sed": 10, "alcohol": 1, "magico": "hierba_bruma",
			"efectos": [{"id": "sigilo", "dur": 90.0, "f": 1.0}], "desc": "Los guardias te ven menos."},
	"vino_especiado": {"nombre": "Vino especiado", "precio": 14, "sed": 22, "alcohol": 1,
			"efectos": [{"id": "resistencia", "dur": 45.0, "f": 0.5}], "desc": "Calienta por dentro."},
	"hidromiel_bruma": {"nombre": "Hidromiel de bruma", "precio": 24, "sed": 20, "alcohol": 1, "magico": "hierba_bruma",
			"efectos": [{"id": "carisma", "dur": 120.0, "f": 1.0}], "rumor": true, "desc": "Sube la fama y suelta rumores."},
	"cafe_solo": {"nombre": "Café solo", "precio": 5, "sed": 10, "energia": 25,
			"efectos": [{"id": "velocidad", "dur": 40.0, "f": 0.6}], "desc": "Un subidón de energía."},
	"cafe_leche": {"nombre": "Café con leche", "precio": 6, "sed": 15, "energia": 20, "hambre": 4, "desc": "El de siempre."},
	"te_bruma": {"nombre": "Té de bruma", "precio": 13, "sed": 25, "magico": "hierba_bruma",
			"efectos": [{"id": "calma", "dur": 150.0, "f": 1.0}, {"id": "regeneracion", "dur": 20.0, "f": 0.6}],
			"desc": "Calma los nervios y la sospecha."},
	"batido_estrella": {"nombre": "Batido de estrella", "precio": 15, "sed": 30, "hambre": 10, "energia": 10,
			"efectos": [{"id": "buen_humor", "dur": 150.0, "f": 1.0}], "desc": "Brilla un poquito."},
	# ------------------------------ panadería ---------------------------------
	"pan_barra": {"nombre": "Barra de pan caliente", "precio": 4, "hambre": 20, "desc": "Recién hecha."},
	"empanada": {"nombre": "Empanada de molleja", "precio": 10, "hambre": 30, "vida": 4, "desc": "No preguntes de qué es."},
	"bollo": {"nombre": "Bollo de canela", "precio": 6, "hambre": 14,
			"efectos": [{"id": "buen_humor", "dur": 60.0, "f": 0.5}], "desc": "Huele a domingo."},
	"pastel_nata": {"nombre": "Pastel de nata", "precio": 7, "hambre": 14, "energia": 8, "desc": "Con canela por encima."},
	"pan_bruma": {"nombre": "Pan de bruma", "precio": 18, "hambre": 30, "magico": "hierba_bruma",
			"efectos": [{"id": "velocidad", "dur": 90.0, "f": 0.9}], "desc": "Te hace correr un buen rato."},
	"pan_llevar": {"nombre": "Pan para llevar", "precio": 5, "objeto": "pan", "desc": "Se guarda en la mochila."},
	"empanada_llevar": {"nombre": "Empanada para llevar", "precio": 12, "objeto": "empanada", "desc": "Se guarda en la mochila."},
	# ------------------------------ posada y gimnasio ---------------------------
	#   dormir: pasa la noche hasta las 7:00 (vida y aliento al máximo).  entrena: sube un atributo (1 al día cada uno).
	"cama_posada": {"nombre": "Cama para pasar la noche", "precio": 40, "dormir": 1, "desc": "Duermes hasta las 7:00. Vida y aliento al máximo."},
	"cama_bruma": {"nombre": "Cama de bruma", "precio": 90, "dormir": 1, "magico": "hierba_bruma",
			"efectos": [{"id": "regeneracion", "dur": 60.0, "f": 1.0}, {"id": "concentracion", "dur": 240.0, "f": 1.0}],
			"desc": "Sueños lúcidos: te despiertas con concentración."},
	"desayuno_posada": {"nombre": "Desayuno de la casa", "precio": 12, "hambre": 40, "sed": 20, "desc": "Pan, queso y leche."},
	"entrena_fuerza": {"nombre": "Pesas", "precio": 25, "entrena": "fuerza", "desc": "Sube fuerza. Cansa y da hambre."},
	"entrena_agilidad": {"nombre": "Cinta y comba", "precio": 25, "entrena": "agilidad", "desc": "Sube agilidad. Cansa y da sed."},
	"entrena_constitucion": {"nombre": "Circuito de resistencia", "precio": 30, "entrena": "constitucion", "desc": "Sube constitución (más vida máxima)."},
	"entrena_bruma": {"nombre": "Entrenamiento de bruma", "precio": 70, "entrena": "azar", "magico": "hierba_bruma", "desc": "Sube un atributo al azar, sin sudar tanto."},
	"batido_proteico": {"nombre": "Batido proteico", "precio": 10, "hambre": 15, "sed": 20, "energia": 30, "desc": "Recupera el aliento."},
	# --------------------------------- taller ---------------------------------
	"reparar": {"nombre": "Reparación completa", "precio": 0, "vehiculo": "reparar", "desc": "Chapa y motor como nuevos."},
	"revision": {"nombre": "Revisión rápida", "precio": 0, "vehiculo": "revision", "desc": "Recupera un 40 % de salud, más barata."},
	"repostar": {"nombre": "Llenar el depósito", "precio": 0, "vehiculo": "repostar", "desc": "Gasolina hasta arriba."},
	"bidon": {"nombre": "Bidón de gasolina", "precio": 15, "vehiculo": "bidon", "desc": "Para el camino."},
	"aceite_bruma": {"nombre": "Aceite de bruma", "precio": 60, "vehiculo": "bruma", "magico": "hierba_bruma",
			"desc": "Reparación completa y depósito lleno, con magia."},
}

const COPAS_PARA_MAREARSE: int = 4
const DESCUENTO_PLATO_DIA: float = 0.2


static func existe(local: String) -> bool:
	return LOCALES.has(local)


static func es_taller(local: String) -> bool:
	return str((LOCALES.get(local, {}) as Dictionary).get("tipo", "")) == "taller"


static func es_aspecto(local: String) -> bool:
	return str((LOCALES.get(local, {}) as Dictionary).get("tipo", "")) == "aspecto"


static func abierto(local: String, hora: float) -> bool:
	if not LOCALES.has(local):
		return true
	var l: Dictionary = LOCALES[local]
	var abre: float = l["abre"]
	var cierra: float = l["cierra"]
	if cierra > abre:
		return hora >= abre and hora < cierra
	return hora >= abre or hora < cierra


static func texto_horario(local: String) -> String:
	var l: Dictionary = LOCALES.get(local, {"abre": 0.0, "cierra": 24.0})
	return "%02d:00-%02d:00" % [int(l["abre"]) % 24, int(l["cierra"]) % 24]


# Número estable (0..2^31) a partir de una semilla y un entero: la variedad no usa azar de verdad.
static func _h(semilla: int, k: int) -> int:
	var x: int = ((semilla * 73856093) ^ (k * 19349663)) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return (x ^ (x >> 16)) & 0x7fffffff


static func nombre_local(local: String, semilla: int) -> String:
	var l: Dictionary = LOCALES.get(local, {})
	var nombres: Array = l.get("nombres", [])
	if nombres.is_empty():
		return str(l.get("nombre", local))
	return str(nombres[_h(semilla, 1) % nombres.size()])


# Color de paredes propio de este local (el del tipo, algo distinto según la semilla).
static func color_local(local: String, semilla: int) -> Color:
	var base: Color = (LOCALES.get(local, {}) as Dictionary).get("color", Color(0.6, 0.5, 0.4))
	var t: float = float(_h(semilla, 2) % 1000) / 1000.0
	return base.lightened(0.18 * (t - 0.5)).lerp(Color.from_hsv(float(_h(semilla, 3) % 360) / 360.0, 0.35, 0.7), 0.12)


# La carta de este local: lista de {id, nombre, precio, ...} con los precios ya variados y el plato del día.
# En el taller los precios dependen del vehículo (precio 0 aquí: los calcula la ventana).
static func carta(local: String, semilla: int) -> Array:
	var ids: Array = (LOCALES.get(local, {}) as Dictionary).get("carta", [])
	var salida: Array = []
	var dia_i: int = -1
	if ids.size() > 3 and not es_taller(local):
		dia_i = _h(semilla, 7) % ids.size()
	for i in ids.size():
		var id: String = str(ids[i])
		var p: Dictionary = (PRODUCTOS[id] as Dictionary).duplicate(true)
		p["id"] = id
		if not p.has("vehiculo"):
			var factor: float = 0.85 + float(_h(semilla, 10 + i) % 31) / 100.0   # 0,85 a 1,15
			var precio: int = maxi(1, int(round(float(p["precio"]) * factor)))
			if i == dia_i and not p.has("magico"):
				p["dia"] = true
				precio = maxi(1, int(round(precio * (1.0 - DESCUENTO_PLATO_DIA))))
			p["precio"] = precio
		salida.append(p)
	return salida


# Frase corta con lo que hace un producto (para la ventana).
static func resumen(p: Dictionary) -> String:
	var trozos: PackedStringArray = PackedStringArray()
	if p.has("hambre"):
		trozos.append("hambre -%d" % int(p["hambre"]))
	if p.has("sed"):
		trozos.append("sed -%d" % int(p["sed"]))
	if p.has("vida"):
		trozos.append("vida +%d" % int(p["vida"]))
	if p.has("energia"):
		trozos.append("energía +%d" % int(p["energia"]))
	for e in p.get("efectos", []):
		var d: Dictionary = (Efectos.LISTA as Dictionary).get(str(e["id"]), {})
		trozos.append("%s %ds" % [str(d.get("nombre", e["id"])), int(e["dur"])])
	if p.has("objeto"):
		trozos.append("te lo llevas")
	if p.has("magico"):
		trozos.append("✦ gasta 1 hoja de bruma")
	return ", ".join(trozos)
