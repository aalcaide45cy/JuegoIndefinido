# efectos.gd
# -----------------------------------------------------------------------------
# CATÁLOGO DE EFECTOS TEMPORALES. Lo que te pasa al beber una poción (o comer
# algo especial): más velocidad, más resistencia, visión nocturna... y también
# efectos malos (veneno, mareo, lentitud) que pueden salir como "efecto
# secundario" de una mezcla.
#
# Para añadir un efecto nuevo: copia una entrada y cambia los datos. No hay que
# tocar más código si solo usa "mods", "regen" y "visual":
#
#   nombre    lo que ve el jugador.
#   epiteto   [masculino, femenino]: sirve para poner nombre a las pociones
#             generadas ("Tónico Raudo", "Infusión Rauda").
#   bueno     true = efecto bueno, false = malo.
#   dur       segundos que dura por defecto (cada poción lo ajusta).
#   color     color del icono en el HUD.
#   descripcion  frase para las ventanas.
#   mods      multiplicadores que suma Juego.mod("clave"). Claves que usa el juego:
#               velocidad (+0.35 = 35 % más rápido), salto, dano_recibido
#               (-0.4 = recibes 40 % menos), dano_hecho, xp, precio (venta),
#               sigilo (te ven menos), calma (la sospecha baja más rápido),
#               alerta (la búsqueda de los guardias baja más despacio),
#               vision (visión nocturna, 0..1).
#   regen     vida por segundo (positivo cura, negativo hace daño; el daño
#             nunca te mata: se detiene en 1 de vida).
#   visual    efectos en pantalla: "ondas" (mareo), "tinte" (Color con alfa),
#             "vineta" (oscurecer bordes, 0..1).
# -----------------------------------------------------------------------------
extends RefCounted

const LISTA: Dictionary = {
	# ------------------------------- Buenos ----------------------------------
	"velocidad": {
		"nombre": "Velocidad", "epiteto": ["Raudo", "Rauda"], "bueno": true, "dur": 90.0,
		"color": Color(0.95, 0.8, 0.25), "descripcion": "Corres y andas un 35 % más rápido.",
		"mods": {"velocidad": 0.35},
	},
	"salto": {
		"nombre": "Piernas de resorte", "epiteto": ["Saltarín", "Saltarina"], "bueno": true, "dur": 90.0,
		"color": Color(0.5, 0.9, 0.4), "descripcion": "Saltas un 60 % más alto.",
		"mods": {"salto": 0.6},
	},
	"resistencia": {
		"nombre": "Resistencia", "epiteto": ["Férreo", "Férrea"], "bueno": true, "dur": 120.0,
		"color": Color(0.55, 0.65, 0.8), "descripcion": "Recibes un 40 % menos de daño.",
		"mods": {"dano_recibido": -0.4},
	},
	"fuerza": {
		"nombre": "Fuerza", "epiteto": ["Bravío", "Bravía"], "bueno": true, "dur": 90.0,
		"color": Color(0.9, 0.35, 0.25), "descripcion": "Tus golpes y disparos hacen un 50 % más de daño.",
		"mods": {"dano_hecho": 0.5},
	},
	"vision": {
		"nombre": "Ojos de gato", "epiteto": ["Lunar", "Lunar"], "bueno": true, "dur": 150.0,
		"color": Color(0.5, 0.75, 1.0), "descripcion": "Ves casi como de día cuando es de noche.",
		"mods": {"vision": 1.0},
		"visual": {"tinte": Color(0.45, 0.7, 1.0, 0.07)},
	},
	"regeneracion": {
		"nombre": "Regeneración", "epiteto": ["Sanador", "Sanadora"], "bueno": true, "dur": 40.0,
		"color": Color(0.4, 0.95, 0.5), "descripcion": "Recuperas vida poco a poco.",
		"regen": 1.5,
	},
	"sigilo": {
		"nombre": "Sigilo", "epiteto": ["Sombrío", "Sombría"], "bueno": true, "dur": 120.0,
		"color": Color(0.5, 0.4, 0.7), "descripcion": "Los guardias te ven desde mucho más cerca.",
		"mods": {"sigilo": 0.45},
	},
	"concentracion": {
		"nombre": "Concentración", "epiteto": ["Lúcido", "Lúcida"], "bueno": true, "dur": 150.0,
		"color": Color(0.35, 0.85, 0.85), "descripcion": "Ganas un 50 % más de experiencia.",
		"mods": {"xp": 0.5},
	},
	"carisma": {
		"nombre": "Carisma", "epiteto": ["Encantador", "Encantadora"], "bueno": true, "dur": 150.0,
		"color": Color(0.95, 0.55, 0.75), "descripcion": "Los clientes pagan un 20 % más.",
		"mods": {"precio": 0.2},
	},
	"calma": {
		"nombre": "Calma", "epiteto": ["Sereno", "Serena"], "bueno": true, "dur": 120.0,
		"color": Color(0.55, 0.85, 0.7), "descripcion": "La sospecha de la policía baja mucho más rápido.",
		"mods": {"calma": 1.0},
	},
	"euforia": {
		"nombre": "Euforia", "epiteto": ["Jubiloso", "Jubilosa"], "bueno": true, "dur": 75.0,
		"color": Color(1.0, 0.65, 0.35), "descripcion": "Te sientes imparable (+15 % de velocidad), pero ves el mundo muy rosa.",
		"mods": {"velocidad": 0.15},
		"visual": {"tinte": Color(1.0, 0.45, 0.7, 0.10)},
	},

	# -------------------------------- Malos ----------------------------------
	"veneno": {
		"nombre": "Veneno", "epiteto": ["Ponzoñoso", "Ponzoñosa"], "bueno": false, "dur": 30.0,
		"color": Color(0.5, 0.8, 0.15), "descripcion": "Pierdes vida poco a poco (no llega a matarte).",
		"regen": -1.2,
		"visual": {"tinte": Color(0.4, 0.8, 0.1, 0.07)},
	},
	"nauseas": {
		"nombre": "Náuseas", "epiteto": ["Nauseabundo", "Nauseabunda"], "bueno": false, "dur": 40.0,
		"color": Color(0.6, 0.65, 0.2), "descripcion": "Se te revuelve el estómago y la pantalla se ondula.",
		"regen": -0.5,
		"visual": {"ondas": 0.6, "tinte": Color(0.5, 0.6, 0.1, 0.06)},
	},
	"lentitud": {
		"nombre": "Lentitud", "epiteto": ["Pesado", "Pesada"], "bueno": false, "dur": 60.0,
		"color": Color(0.5, 0.5, 0.55), "descripcion": "Te mueves un 35 % más despacio.",
		"mods": {"velocidad": -0.35},
	},
	"mareo": {
		"nombre": "Mareo", "epiteto": ["Vertiginoso", "Vertiginosa"], "bueno": false, "dur": 45.0,
		"color": Color(0.75, 0.55, 0.9), "descripcion": "El mundo da vueltas: la pantalla se ondula.",
		"visual": {"ondas": 1.0},
	},
	"somnolencia": {
		"nombre": "Somnolencia", "epiteto": ["Soporífero", "Soporífera"], "bueno": false, "dur": 50.0,
		"color": Color(0.35, 0.4, 0.6), "descripcion": "Te pesan los párpados y vas un 15 % más lento.",
		"mods": {"velocidad": -0.15},
		"visual": {"vineta": 0.75},
	},
	"temblor": {
		"nombre": "Temblor", "epiteto": ["Trémulo", "Trémula"], "bueno": false, "dur": 45.0,
		"color": Color(0.85, 0.5, 0.3), "descripcion": "Te tiemblan las manos: haces un 20 % menos de daño.",
		"mods": {"dano_hecho": -0.2},
		"visual": {"ondas": 0.25},
	},
	"paranoia": {
		"nombre": "Paranoia", "epiteto": ["Receloso", "Recelosa"], "bueno": false, "dur": 60.0,
		"color": Color(0.9, 0.3, 0.3), "descripcion": "Los guardias te ven de más lejos y te buscan durante más tiempo.",
		"mods": {"sigilo": -0.3, "alerta": 1.0},
		"visual": {"vineta": 0.45, "tinte": Color(0.8, 0.1, 0.1, 0.05)},
	},
}


static func existe(id: String) -> bool:
	return LISTA.has(id)


static func datos(id: String) -> Dictionary:
	return LISTA[id]


static func nombre(id: String) -> String:
	return LISTA[id]["nombre"]


static func es_bueno(id: String) -> bool:
	return LISTA[id]["bueno"]


# Texto corto de una lista de efectos: "Velocidad 90 s, Mareo 40 %".
# "lista" es un Array de {"id", "dur", "f", "prob"}.
static func resumen(lista: Array) -> String:
	var partes: PackedStringArray = []
	for e in lista:
		var t: String = "%s (%s)" % [nombre(e["id"]), duracion_texto(float(e["dur"]))]
		if float(e.get("prob", 1.0)) < 0.999:
			t += " %d %%" % int(round(float(e["prob"]) * 100.0))
		partes.append(t)
	return ", ".join(partes)


static func duracion_texto(segundos: float) -> String:
	var s: int = int(round(segundos))
	if s >= 60:
		return "%d min %02d s" % [s / 60, s % 60] if s % 60 != 0 else "%d min" % (s / 60)
	return "%d s" % s
