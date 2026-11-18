# habilidades.gd
# -----------------------------------------------------------------------------
# Las habilidades que el jugador puede aprender. Algunas tiendas no te venden
# ciertos objetos si no tienes la habilidad (mira "habilidad" en objetos.gd).
# En la fase 3 se aprenderán pagando a instructores; de momento se activan
# desde el panel de administrador (F1).
# -----------------------------------------------------------------------------
extends RefCounted

const LISTA: Dictionary = {
	"cultivo": {"nombre": "Cultivo (plantas un 15 % más rápido)", "precio": 350, "nivel": 3},
	"sigilo": {"nombre": "Sigilo (la sospecha sube un 30 % más despacio)", "precio": 500, "nivel": 4},
	"conduccion": {"nombre": "Carnet de conducir", "precio": 150, "nivel": 1},   # Sin él, los guardias te multan si te ven conduciendo.
	"disparo": {"nombre": "Manejo de armas de fuego", "precio": 300, "nivel": 3},
	"punteria": {"nombre": "Puntería avanzada", "precio": 800, "nivel": 8},
	"espada": {"nombre": "Esgrima", "precio": 500, "nivel": 5},
	"explosivos": {"nombre": "Explosivos", "precio": 1000, "nivel": 6},
	"negociacion": {"nombre": "Negociación", "precio": 400, "nivel": 2},   # Regatear mejor; ver su límite a los clientes.
}


static func nombre(id: String) -> String:
	return LISTA[id]["nombre"] if LISTA.has(id) else id
