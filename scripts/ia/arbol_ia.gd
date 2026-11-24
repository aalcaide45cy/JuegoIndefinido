# arbol_ia.gd
# -----------------------------------------------------------------------------
# Árbol de comportamiento (Behavior Tree) pequeño y rápido para la IA de los personajes.
#
# Cómo funciona, en sencillo: cada personaje "piensa" varias veces por segundo recorriendo un
# árbol de decisiones desde arriba. Cada nodo responde EXITO, FALLO o CORRIENDO (sigue haciéndolo):
#   - Selector:   prueba sus hijos en orden y se queda con el PRIMERO que no falla
#                 ("si me disparan, huyo; si no, si hay pelea, miro; si no, paseo").
#   - Secuencia:  hace sus hijos uno detrás de otro; si uno falla, para ("ver arma -> gritar -> correr").
#   - Utilidad:   puntúa a sus hijos con una función y elige el MEJOR (cada uno según su carácter:
#                 el valiente puntúa alto "pelear", el miedoso "huir").
#   - Condicion / Accion: hojas que miran algo o hacen algo (funciones de PersonaIA).
#   - Decoradores: Enfriamiento (no repetir antes de X s), Probabilidad, Invertir, Limite de tiempo.
#
# El árbol se construye UNA vez por tipo de personaje y lo comparten todos: lo que cambia de
# uno a otro (qué hijo estaba corriendo, enfriamientos...) se guarda en la "pizarra" de cada
# personaje (bb, un Dictionary), así que mil peatones cuestan lo mismo que uno en memoria.
# -----------------------------------------------------------------------------
class_name ArbolIA
extends RefCounted

enum { EXITO, FALLO, CORRIENDO }

static var _siguiente_id: int = 0


class Nodo extends RefCounted:
	var id: int = 0
	var nombre: String = ""

	func _init() -> void:
		id = ArbolIA._siguiente_id
		ArbolIA._siguiente_id += 1

	func tick(_p: Object, _bb: Dictionary, _delta: float) -> int:
		return ArbolIA.FALLO

	# Se llama cuando el nodo deja de correr porque otra rama tomó el control.
	func cortar(_p: Object, _bb: Dictionary) -> void:
		pass


# Elige el primer hijo que no falla. Re-evalúa desde el principio cada vez (así una rama más
# importante, como "me disparan", puede interrumpir a otra que estaba corriendo, como "pasear").
class Selector extends Nodo:
	var hijos: Array = []

	func tick(p: Object, bb: Dictionary, delta: float) -> int:
		var clave: String = "s%d" % id
		var antes: int = int(bb.get(clave, -1))
		for i in hijos.size():
			var r: int = (hijos[i] as Nodo).tick(p, bb, delta)
			if r != ArbolIA.FALLO:
				if antes >= 0 and antes != i and antes < hijos.size():
					(hijos[antes] as Nodo).cortar(p, bb)
				bb[clave] = i if r == ArbolIA.CORRIENDO else -1
				return r
		if antes >= 0 and antes < hijos.size():
			(hijos[antes] as Nodo).cortar(p, bb)
		bb[clave] = -1
		return ArbolIA.FALLO

	func cortar(p: Object, bb: Dictionary) -> void:
		var clave: String = "s%d" % id
		var antes: int = int(bb.get(clave, -1))
		if antes >= 0 and antes < hijos.size():
			(hijos[antes] as Nodo).cortar(p, bb)
		bb[clave] = -1


# Hace los hijos en orden, recordando por cuál va (con memoria).
class Secuencia extends Nodo:
	var hijos: Array = []

	func tick(p: Object, bb: Dictionary, delta: float) -> int:
		var clave: String = "q%d" % id
		var i: int = int(bb.get(clave, 0))
		while i < hijos.size():
			var r: int = (hijos[i] as Nodo).tick(p, bb, delta)
			if r == ArbolIA.CORRIENDO:
				bb[clave] = i
				return r
			if r == ArbolIA.FALLO:
				bb[clave] = 0
				return r
			i += 1
		bb[clave] = 0
		return ArbolIA.EXITO

	func cortar(p: Object, bb: Dictionary) -> void:
		var clave: String = "q%d" % id
		var i: int = int(bb.get(clave, 0))
		if i < hijos.size():
			(hijos[i] as Nodo).cortar(p, bb)
		bb[clave] = 0


# Puntúa cada opción con su función (p, bb) -> float y ejecuta la mejor. Mientras la elegida
# corre, solo cambia si otra la supera con claridad (histéresis): así no "duda" cada fotograma.
class Utilidad extends Nodo:
	var hijos: Array = []
	var puntos: Array = []        # Callables (p, bb) -> float
	var histeresis: float = 0.15

	func tick(p: Object, bb: Dictionary, delta: float) -> int:
		var clave: String = "u%d" % id
		var actual: int = int(bb.get(clave, -1))
		var mejor: int = -1
		var mejor_v: float = 0.0
		for i in hijos.size():
			var v: float = float((puntos[i] as Callable).call(p, bb))
			if i == actual:
				v += histeresis
			if v > mejor_v:
				mejor_v = v
				mejor = i
		if mejor < 0:
			if actual >= 0:
				(hijos[actual] as Nodo).cortar(p, bb)
			bb[clave] = -1
			return ArbolIA.FALLO
		if actual >= 0 and actual != mejor:
			(hijos[actual] as Nodo).cortar(p, bb)
		var r: int = (hijos[mejor] as Nodo).tick(p, bb, delta)
		bb[clave] = mejor if r == ArbolIA.CORRIENDO else -1
		bb["eleccion_" + nombre] = (hijos[mejor] as Nodo).nombre
		return r

	func cortar(p: Object, bb: Dictionary) -> void:
		var clave: String = "u%d" % id
		var actual: int = int(bb.get(clave, -1))
		if actual >= 0:
			(hijos[actual] as Nodo).cortar(p, bb)
		bb[clave] = -1


class Condicion extends Nodo:
	var f: Callable

	func tick(p: Object, bb: Dictionary, _delta: float) -> int:
		return ArbolIA.EXITO if bool(f.call(p, bb)) else ArbolIA.FALLO


# Hoja que hace algo: f(p, bb, delta) -> EXITO / FALLO / CORRIENDO.
# "al_cortar" (opcional) limpia lo que hiciera falta si otra rama la interrumpe.
class Accion extends Nodo:
	var f: Callable
	var al_cortar: Callable

	func tick(p: Object, bb: Dictionary, delta: float) -> int:
		var clave: String = "a%d" % id
		if not bb.has(clave):
			bb[clave] = true
			bb["t_" + nombre] = 0.0
		bb["t_" + nombre] = float(bb.get("t_" + nombre, 0.0)) + delta
		var r: int = int(f.call(p, bb, delta))
		if r != ArbolIA.CORRIENDO:
			bb.erase(clave)
		return r

	func cortar(p: Object, bb: Dictionary) -> void:
		var clave: String = "a%d" % id
		if bb.has(clave):
			bb.erase(clave)
			if al_cortar.is_valid():
				al_cortar.call(p, bb)


# No deja entrar al hijo hasta que pasen "segundos" desde la última vez que terminó.
class Enfriamiento extends Nodo:
	var hijo: Nodo
	var segundos: float = 5.0

	func tick(p: Object, bb: Dictionary, delta: float) -> int:
		var clave: String = "e%d" % id
		var ahora: float = float(bb.get("reloj", 0.0))
		if ahora < float(bb.get(clave, -1.0e9)) and not bb.has(clave + "c"):
			return ArbolIA.FALLO
		var r: int = hijo.tick(p, bb, delta)
		if r == ArbolIA.CORRIENDO:
			bb[clave + "c"] = true
		else:
			bb.erase(clave + "c")
			if r == ArbolIA.EXITO:
				bb[clave] = ahora + segundos
		return r

	func cortar(p: Object, bb: Dictionary) -> void:
		var clave: String = "e%d" % id
		if bb.has(clave + "c"):
			bb.erase(clave + "c")
			bb[clave] = float(bb.get("reloj", 0.0)) + segundos * 0.5
		hijo.cortar(p, bb)


# Tira un dado al entrar (no en cada fotograma): con probabilidad p entra; si no, falla un rato.
class Probabilidad extends Nodo:
	var hijo: Nodo
	var p: float = 0.5
	var reintento: float = 4.0

	func tick(pe: Object, bb: Dictionary, delta: float) -> int:
		var clave: String = "p%d" % id
		if not bb.has(clave + "c"):
			var ahora: float = float(bb.get("reloj", 0.0))
			if ahora < float(bb.get(clave, -1.0e9)):
				return ArbolIA.FALLO
			if randf() > p:
				bb[clave] = ahora + reintento
				return ArbolIA.FALLO
		var r: int = hijo.tick(pe, bb, delta)
		if r == ArbolIA.CORRIENDO:
			bb[clave + "c"] = true
		else:
			bb.erase(clave + "c")
		return r

	func cortar(pe: Object, bb: Dictionary) -> void:
		bb.erase("p%dc" % id)
		hijo.cortar(pe, bb)


class Invertir extends Nodo:
	var hijo: Nodo

	func tick(p: Object, bb: Dictionary, delta: float) -> int:
		var r: int = hijo.tick(p, bb, delta)
		if r == ArbolIA.CORRIENDO:
			return r
		return ArbolIA.FALLO if r == ArbolIA.EXITO else ArbolIA.EXITO

	func cortar(p: Object, bb: Dictionary) -> void:
		hijo.cortar(p, bb)


# ------------------------------ Constructores ---------------------------------
# Para escribir los árboles de forma legible (ver arboles_ia.gd).

static func selector(nombre: String, hijos: Array) -> Selector:
	var n: Selector = Selector.new()
	n.nombre = nombre
	n.hijos = hijos
	return n


static func secuencia(nombre: String, hijos: Array) -> Secuencia:
	var n: Secuencia = Secuencia.new()
	n.nombre = nombre
	n.hijos = hijos
	return n


# opciones: Array de [Callable puntuacion, Nodo].
static func utilidad(nombre: String, opciones: Array, histeresis: float = 0.15) -> Utilidad:
	var n: Utilidad = Utilidad.new()
	n.nombre = nombre
	n.histeresis = histeresis
	for o in opciones:
		n.puntos.append(o[0])
		n.hijos.append(o[1])
	return n


static func si(nombre: String, f: Callable) -> Condicion:
	var n: Condicion = Condicion.new()
	n.nombre = nombre
	n.f = f
	return n


static func hacer(nombre: String, f: Callable, al_cortar: Callable = Callable()) -> Accion:
	var n: Accion = Accion.new()
	n.nombre = nombre
	n.f = f
	n.al_cortar = al_cortar
	return n


static func enfriar(segundos: float, hijo: Nodo) -> Enfriamiento:
	var n: Enfriamiento = Enfriamiento.new()
	n.nombre = "enfriar_" + hijo.nombre
	n.segundos = segundos
	n.hijo = hijo
	return n


static func quiza(p: float, hijo: Nodo, reintento: float = 4.0) -> Probabilidad:
	var n: Probabilidad = Probabilidad.new()
	n.nombre = "quiza_" + hijo.nombre
	n.p = p
	n.reintento = reintento
	n.hijo = hijo
	return n


static func no(hijo: Nodo) -> Invertir:
	var n: Invertir = Invertir.new()
	n.nombre = "no_" + hijo.nombre
	n.hijo = hijo
	return n
