# habilidades.gd
# -----------------------------------------------------------------------------
# Las habilidades que el jugador puede aprender. Algunas tiendas no te venden
# ciertos objetos si no tienes la habilidad (mira "habilidad" en objetos.gd).
# En la fase 3 se aprenderán pagando a instructores; de momento se activan
# desde el panel de administrador (F1).
# -----------------------------------------------------------------------------
class_name DatosHabilidades
extends RefCounted

const LISTA: Dictionary = {
	"disparo": {"nombre": "Manejo de armas de fuego", "precio": 300, "nivel": 3},
	"punteria": {"nombre": "Puntería avanzada", "precio": 800, "nivel": 8},
	"espada": {"nombre": "Esgrima", "precio": 500, "nivel": 5},
	"explosivos": {"nombre": "Explosivos", "precio": 1000, "nivel": 6},
}


static func nombre(id: String) -> String:
	return LISTA[id]["nombre"] if LISTA.has(id) else id
