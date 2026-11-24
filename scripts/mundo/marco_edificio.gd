# marco_edificio.gd
# -----------------------------------------------------------------------------
# Traduce las coordenadas "del plano" de un edificio a coordenadas del mundo.
#   u  = a lo ancho, de -W/2 a +W/2 (0 = centro de la casa)
#   iv = a lo hondo, desde el muro de la puerta (0) hasta el del fondo (D)
# W y D son las medidas INTERIORES (sin el grosor de los muros).
# Si el edificio tiene la clave "eje" = "x" su puerta mira hacia +X o -X (los de la ciudad
# original, girados 90 grados); si no, mira hacia +Z o -Z (los del mundo grande).
# Lo usan la cáscara (muros, suelos y escaleras: CascaraEdificio) y el reparto de dentro
# (InteriorCasa) para que ambos coincidan al milímetro.
# -----------------------------------------------------------------------------
class_name MarcoEdificio
extends RefCounted

const GROSOR: float = 0.3         # Grosor de los muros (igual que GeneradorMundo.GROSOR_MURO).
const PASO_PISO: float = 3.2      # De la cara de arriba de un suelo a la del siguiente.
const ALTO_LIBRE: float = 3.0     # Altura libre de una planta.

var x: float = 0.0
var y: float = 0.0
var z: float = 0.0
var cara: float = 1.0
var eje_x: bool = false
var W: float = 6.0
var D: float = 6.0
var pisos: int = 1


func configurar(c: Dictionary) -> MarcoEdificio:
	x = float(c["x"])
	y = float(c["y"])
	z = float(c["z"])
	cara = float(c["puerta"])
	eje_x = str(c.get("eje", "z")) == "x"
	W = float(c["w"]) - 2.0 * GROSOR
	D = float(c["d"]) - 2.0 * GROSOR
	pisos = int(c["pisos"])
	return self


# Cara de arriba del suelo de la planta "n" (0 = planta baja).
func suelo_y(n: int) -> float:
	return y + 0.1 + PASO_PISO * float(n)


# Punto del plano (u, iv) a la altura absoluta "ya".
func punto(u: float, iv: float, ya: float) -> Vector3:
	if eje_x:
		return Vector3(x + cara * (D / 2.0 - iv), ya, z + u)
	return Vector3(x + u, ya, z + cara * (D / 2.0 - iv))


# Caja centrada en el plano (u, iv) a altura absoluta "ya" (centro), con tamaño en el plano (su, sv).
func caja_en(mb: ConstructorMalla, u: float, iv: float, ya: float, su: float, sh: float, sv: float, col: Color) -> void:
	mb.caja(punto(u, iv, ya), tam(su, sh, sv), col)


func tam(su: float, sh: float, sv: float) -> Vector3:
	return Vector3(sv, sh, su) if eje_x else Vector3(su, sh, sv)


# Rectángulo del plano (u0, iv0, ancho, hondo) a Rect2 del mundo (x, z).
func rect_mundo(r: Rect2) -> Rect2:
	var a: Vector3 = punto(r.position.x, r.position.y, 0.0)
	var b: Vector3 = punto(r.end.x, r.end.y, 0.0)
	return Rect2(minf(a.x, b.x), minf(a.z, b.z), absf(a.x - b.x), absf(a.z - b.z))
