# granja.gd
# -----------------------------------------------------------------------------
# Animales de los corrales: qué producen y cada cuántos segundos (por animal).
# Se usa con preload.
# -----------------------------------------------------------------------------
extends RefCounted

const ESPECIES: Dictionary = {
	"gallina": {"producto": "huevo", "tiempo": 60.0, "color": Color(0.95, 0.93, 0.85), "tam": Vector3(0.35, 0.35, 0.45)},
	"vaca": {"producto": "leche", "tiempo": 180.0, "color": Color(0.9, 0.9, 0.9), "tam": Vector3(0.9, 0.9, 1.6)},
}
