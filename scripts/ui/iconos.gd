# iconos.gd
# -----------------------------------------------------------------------------
# Iconos de los objetos del inventario, la tienda y la estantería.
# Cada icono se compone de:
#   1. un fondo con degradado, de un color según el TIPO de objeto,
#   2. el dibujo de su forma (casilla_ui.gd, dibujar_icono),
#   3. una insignia pequeña en la esquina que dice qué tipo de objeto es
#      (hoja = hierba, gota = poción, bala = munición...).
# Así, aunque haya 24 sacos o 13 semillas parecidas, se distinguen de un vistazo
# por el fondo, la insignia y el color propio de cada objeto.
# Todo se dibuja por código (no hay imágenes que descargar).
# -----------------------------------------------------------------------------
class_name Iconos
extends RefCounted

const DatosObjetos = preload("res://scripts/datos/objetos.gd")

# Color del fondo por tipo de objeto.
const FONDOS: Dictionary = {
	"semilla": Color(0.2, 0.3, 0.16), "hierba": Color(0.12, 0.3, 0.17), "cosecha": Color(0.34, 0.24, 0.1),
	"pocion": Color(0.3, 0.14, 0.34), "aditivo": Color(0.32, 0.26, 0.1), "consumible": Color(0.32, 0.14, 0.14),
	"herramienta": Color(0.2, 0.24, 0.3), "material": Color(0.24, 0.22, 0.2), "arma_cc": Color(0.28, 0.16, 0.16),
	"arma_fuego": Color(0.22, 0.2, 0.2), "explosivo": Color(0.36, 0.14, 0.08), "municion": Color(0.26, 0.22, 0.12),
	"paquete": Color(0.3, 0.26, 0.18), "animal": Color(0.3, 0.2, 0.16), "mueble": Color(0.22, 0.18, 0.14),
}
const FONDO_POR_DEFECTO: Color = Color(0.14, 0.15, 0.15)

static var _estilos: Dictionary = {}


# Dibuja el icono completo del objeto "id" dentro de "r" (fondo + dibujo + insignia).
static func dibujar(lienzo: CanvasItem, r: Rect2, id: String) -> void:
	var datos: Dictionary = DatosObjetos.datos(id)
	var tipo: String = String(datos.get("tipo", ""))
	# 1. Fondo redondeado con un degradado muy suave (arriba más claro).
	lienzo.draw_style_box(_estilo(tipo), r)
	lienzo.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.35)), Color(1, 1, 1, 0.05))
	# 2. La forma del objeto.
	CasillaUI.dibujar_icono(lienzo, r.grow(-r.size.x * 0.14), id)
	# 3. La insignia del tipo, arriba a la derecha.
	if r.size.x >= 40.0:
		_insignia(lienzo, tipo, r.position + Vector2(r.size.x * 0.82, r.size.y * 0.2), r.size.x * 0.14)


static func _estilo(tipo: String) -> StyleBoxFlat:
	if _estilos.has(tipo):
		return _estilos[tipo]
	var e: StyleBoxFlat = StyleBoxFlat.new()
	e.bg_color = FONDOS.get(tipo, FONDO_POR_DEFECTO)
	e.set_corner_radius_all(6)
	e.border_color = e.bg_color.lightened(0.25)
	e.set_border_width_all(1)
	_estilos[tipo] = e
	return e


# Una insignia redonda con un símbolo sencillo dentro. "c" es el centro y "k" el radio.
static func _insignia(l: CanvasItem, tipo: String, c: Vector2, k: float) -> void:
	if not FONDOS.has(tipo):
		return
	l.draw_circle(c, k + 1.5, Color(0, 0, 0, 0.55))
	l.draw_circle(c, k, FONDOS[tipo].lightened(0.1))
	var b: Color = Color(0.95, 0.95, 0.9)
	match tipo:
		"hierba":   # Una hojita.
			l.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k * 0.8), c + Vector2(k * 0.6, 0),
					c + Vector2(0, k * 0.8), c + Vector2(-k * 0.6, 0)]), Color(0.5, 0.9, 0.5))
		"semilla":   # Tres puntitos.
			for p in [Vector2(-0.4, 0.2), Vector2(0.4, 0.2), Vector2(0, -0.45)]:
				l.draw_circle(c + p * k, k * 0.2, Color(0.85, 0.75, 0.5))
		"cosecha":   # Una manzanita.
			l.draw_circle(c + Vector2(0, k * 0.1), k * 0.55, Color(0.9, 0.35, 0.25))
			l.draw_line(c + Vector2(0, -k * 0.4), c + Vector2(k * 0.2, -k * 0.8), Color(0.4, 0.7, 0.3), 1.5)
		"pocion":   # Una gota.
			l.draw_circle(c + Vector2(0, k * 0.25), k * 0.5, Color(0.8, 0.5, 1.0))
			l.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k * 0.8), c + Vector2(k * 0.45, k * 0.1),
					c + Vector2(-k * 0.45, k * 0.1)]), Color(0.8, 0.5, 1.0))
		"aditivo":   # Una chispa de cuatro puntas.
			l.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k * 0.85), c + Vector2(k * 0.2, -k * 0.2),
					c + Vector2(k * 0.85, 0), c + Vector2(k * 0.2, k * 0.2), c + Vector2(0, k * 0.85),
					c + Vector2(-k * 0.2, k * 0.2), c + Vector2(-k * 0.85, 0), c + Vector2(-k * 0.2, -k * 0.2)]),
					Color(1.0, 0.9, 0.4))
		"consumible":   # Una cruz de curar.
			l.draw_rect(Rect2(c + Vector2(-k * 0.2, -k * 0.65), Vector2(k * 0.4, k * 1.3)), Color(1, 0.4, 0.4))
			l.draw_rect(Rect2(c + Vector2(-k * 0.65, -k * 0.2), Vector2(k * 1.3, k * 0.4)), Color(1, 0.4, 0.4))
		"herramienta":   # Una llave: círculo y mango.
			l.draw_arc(c + Vector2(-k * 0.25, -k * 0.25), k * 0.35, 0, TAU, 10, b, 1.6)
			l.draw_line(c + Vector2(0, 0), c + Vector2(k * 0.6, k * 0.6), b, 2.0)
		"material":   # Un ladrillo.
			l.draw_rect(Rect2(c + Vector2(-k * 0.6, -k * 0.35), Vector2(k * 1.2, k * 0.7)), Color(0.75, 0.6, 0.5))
		"arma_cc":   # Dos líneas cruzadas.
			l.draw_line(c + Vector2(-k * 0.6, -k * 0.6), c + Vector2(k * 0.6, k * 0.6), b, 2.0)
			l.draw_line(c + Vector2(k * 0.6, -k * 0.6), c + Vector2(-k * 0.6, k * 0.6), b, 2.0)
		"arma_fuego":   # Una mira.
			l.draw_arc(c, k * 0.55, 0, TAU, 12, b, 1.5)
			l.draw_line(c + Vector2(-k * 0.8, 0), c + Vector2(k * 0.8, 0), b, 1.2)
			l.draw_line(c + Vector2(0, -k * 0.8), c + Vector2(0, k * 0.8), b, 1.2)
		"explosivo":   # Una llama.
			l.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k * 0.85), c + Vector2(k * 0.55, k * 0.2),
					c + Vector2(0, k * 0.8), c + Vector2(-k * 0.55, k * 0.2)]), Color(1.0, 0.6, 0.2))
		"municion":   # Una bala.
			l.draw_rect(Rect2(c + Vector2(-k * 0.25, -k * 0.2), Vector2(k * 0.5, k * 0.9)), Color(0.9, 0.75, 0.35))
			l.draw_circle(c + Vector2(0, -k * 0.2), k * 0.25, Color(0.8, 0.5, 0.3))
		"paquete":   # Una caja con cinta.
			l.draw_rect(Rect2(c + Vector2(-k * 0.6, -k * 0.5), Vector2(k * 1.2, k * 1.0)), Color(0.85, 0.7, 0.45))
			l.draw_line(c + Vector2(0, -k * 0.5), c + Vector2(0, k * 0.5), Color(0.7, 0.2, 0.2), 2.0)
		"animal":   # Una huella.
			l.draw_circle(c + Vector2(0, k * 0.2), k * 0.35, Color(0.95, 0.85, 0.7))
			for p in [Vector2(-0.5, -0.3), Vector2(0, -0.55), Vector2(0.5, -0.3)]:
				l.draw_circle(c + p * k, k * 0.17, Color(0.95, 0.85, 0.7))
		"mueble":   # Una silla vista de lado.
			l.draw_line(c + Vector2(-k * 0.4, -k * 0.6), c + Vector2(-k * 0.4, k * 0.6), b, 2.0)
			l.draw_line(c + Vector2(-k * 0.4, 0), c + Vector2(k * 0.5, 0), b, 2.0)
			l.draw_line(c + Vector2(k * 0.5, 0), c + Vector2(k * 0.5, k * 0.6), b, 2.0)
