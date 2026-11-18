# cultivos.gd
# -----------------------------------------------------------------------------
# Cultivos legales de los huertos (semilla -> cosecha). "tiempo" son los segundos base;
# el tiempo real lo multiplica Economia.FACTOR_TIEMPO_CULTIVO. Se usa con preload.
# -----------------------------------------------------------------------------
extends RefCounted

const CULTIVOS: Dictionary = {
	"semilla_trigo": {"cosecha": "trigo", "tiempo": 150.0, "color": Color(0.85, 0.75, 0.3)},
	"semilla_maiz": {"cosecha": "maiz", "tiempo": 200.0, "color": Color(0.9, 0.8, 0.2)},
	"semilla_tomate": {"cosecha": "tomate", "tiempo": 240.0, "color": Color(0.75, 0.15, 0.1)},
}
