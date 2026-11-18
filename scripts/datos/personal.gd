# personal.gd
# -----------------------------------------------------------------------------
# Datos del personal que se contrata en la Bolsa de trabajo. Sin class_name (se
# usa con preload). Para añadir un oficio: una entrada en OFICIOS y su trabajo
# en gestor_personal.gd.
# -----------------------------------------------------------------------------
extends RefCounted

# sueldo = dólares por día del juego (para nivel 1; sube con el nivel).
const OFICIOS: Dictionary = {
	"agricultor": {"nombre": "Agricultor", "sueldo": 280,
			"descripcion": "Cosecha tu huerto asignado cuando madura y lo vuelve a sembrar."},
	"ganadero": {"nombre": "Ganadero", "sueldo": 200,
			"descripcion": "Recoge los huevos o la leche del corral asignado."},
	"guardaespaldas": {"nombre": "Guardaespaldas", "sueldo": 240,
			"descripcion": "Baja tu sospecha poco a poco mientras trabaja para ti."},
}
const NOMBRES: Array = ["Marta", "Eloy", "Inés", "Bruno", "Lola", "Teo", "Nuria", "Hugo", "Carmen", "Raúl",
		"Olga", "Dídac", "Paula", "Iker", "Rosa", "Gael", "Alba", "Nico", "Vera", "Leo"]
const APELLIDOS: Array = ["Cuervo", "Barro", "Mirlo", "Sal", "Hierro", "Brasa", "Niebla", "Trigo", "Pozo", "Zorro"]
const MAX_PERSONAL: int = 8


static func sueldo(oficio: String, nivel: int) -> int:
	return int(OFICIOS[oficio]["sueldo"] * (0.8 + 0.3 * nivel))


# Candidatos del día: siempre los mismos para un día dado (cambian cada día).
static func candidatos(dia: int) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = dia * 7919 + 13
	var lista: Array = []
	var oficios: Array = OFICIOS.keys()
	for i in 6:
		var oficio: String = oficios[rng.randi() % oficios.size()]
		var nivel: int = 1 + int(rng.randf() < 0.45) + int(rng.randf() < 0.2)
		lista.append({"id": "d%d_%d" % [dia, i], "nombre": "%s %s" % [NOMBRES[rng.randi() % NOMBRES.size()],
				APELLIDOS[rng.randi() % APELLIDOS.size()]], "oficio": oficio, "nivel": nivel,
				"sueldo": sueldo(oficio, nivel), "destino": ""})
	return lista
