# muebles_interior.gd
# -----------------------------------------------------------------------------
# Catálogo de muebles (hechos de cajas de colores) y colocador. Cada mueble es una lista de
# piezas [a lo largo, altura del centro, separación de la pared, ancho, alto, fondo, color, sólido].
# Códigos de color: M madera, Md madera oscura, Ml madera clara, T tela, Td tela oscura, B blanco,
# K metal, N negro, O oro, C encimera, G gris, F nevera, Cl terracota, V planta, Cj cartón,
# P piedra, Fu fuego, Rj rojo, Az azul, Vv violeta, Mg magenta.
# -----------------------------------------------------------------------------
class_name MueblesInterior
extends RefCounted

# nombre: [largo, fondo, piezas]
const ITEMS: Dictionary = {
	"cama": [1.6, 2.1, [[0, .28, 1.0, 1.5, .4, 2.0, "M"], [0, .55, 1.1, 1.42, .18, 1.8, "T"], [0, .7, .38, 1.1, .14, .4, "B", false], [0, .65, .06, 1.6, 1.0, .1, "M"]]],
	"jergon": [1.0, 2.0, [[0, .2, 1.0, .9, .25, 1.9, "Cj"], [0, .38, 1.2, .8, .1, 1.5, "Td"]]],
	"catre": [1.7, .9, [[0, .25, .45, 1.7, .3, .9, "Cj"], [0, .45, .45, 1.6, .12, .8, "T"]]],
	"mesilla": [.45, .45, [[0, .25, .25, .45, .5, .45, "M"], [0, .6, .25, .2, .16, .2, "O", false]]],
	"armario": [1.3, .7, [[0, 1.05, .35, 1.3, 2.1, .7, "Md"], [-.12, 1.0, .72, .05, .3, .03, "K", false], [.12, 1.0, .72, .05, .3, .03, "K", false]]],
	"comoda": [1.2, .5, [[0, .45, .25, 1.2, .9, .5, "M"], [0, .95, .25, 1.3, .05, .55, "Ml", false]]],
	"baul": [.9, .5, [[0, .25, .25, .9, .5, .5, "Md"], [0, .52, .25, .95, .06, .55, "K", false]]],
	"sofa": [2.0, .9, [[0, .65, .18, 2.0, .7, .36, "T"], [0, .28, .55, 2.0, .5, .9, "T"], [-.95, .5, .55, .18, .35, .9, "Td"], [.95, .5, .55, .18, .35, .9, "Td"]]],
	"tele": [1.5, .5, [[0, .28, .25, 1.5, .56, .5, "M"], [0, .88, .2, 1.0, .55, .07, "N"]]],
	"estanteria": [1.4, .4, [[0, 1.0, .2, 1.4, 2.0, .4, "M"], [0, .55, .37, 1.2, .3, .06, "T", false], [0, 1.1, .37, 1.2, .3, .06, "Td", false], [0, 1.65, .37, 1.2, .3, .06, "T", false]]],
	"libreria": [1.8, .45, [[0, 1.1, .22, 1.8, 2.2, .45, "Md"], [-.4, .6, .4, 1.0, .3, .06, "Rj", false], [.4, 1.2, .4, 1.0, .3, .06, "Az", false], [-.3, 1.8, .4, 1.1, .3, .06, "Vv", false]]],
	"encimera": [2.0, .7, [[0, .45, .35, 2.0, .9, .7, "C"], [0, .92, .37, 2.0, .05, .74, "G"], [.4, .95, .35, .6, .03, .45, "K", false]]],
	"nevera": [.7, .7, [[0, .95, .35, .7, 1.9, .7, "F"]]],
	"cocina": [.7, .7, [[0, .45, .35, .7, .9, .7, "K"], [0, .92, .35, .6, .04, .6, "N", false]]],
	"planta": [.4, .4, [[0, .2, .25, .35, .4, .35, "Cl"], [0, .7, .25, .5, .6, .5, "V", false]]],
	"inodoro": [.4, .6, [[0, .22, .36, .4, .44, .55, "B"], [0, .6, .12, .4, .4, .2, "B"]]],
	"lavabo": [.55, .4, [[0, .82, .25, .55, .12, .4, "B"], [0, .4, .2, .2, .8, .2, "B"], [0, 1.55, .03, .5, .6, .04, "Az", false]]],
	"banera": [1.7, .8, [[0, .3, .4, 1.7, .6, .8, "B"], [0, .61, .4, 1.5, .02, .6, "Az", false]]],
	"escritorio": [1.3, 1.2, [[0, .72, .35, 1.3, .06, .7, "M"], [-.6, .35, .35, .06, .7, .6, "Md"], [.6, .35, .35, .06, .7, .6, "Md"], [.2, .95, .2, .5, .3, .05, "N", false], [0, .25, .9, .45, .5, .45, "Ml"]]],
	"caja": [.7, .7, [[0, .35, .4, .7, .7, .7, "Cj"]]],
	"barril": [.65, .65, [[0, .45, .35, .65, .9, .65, "Md"], [0, .7, .35, .68, .06, .68, "K", false]]],
	"saco": [.6, .5, [[0, .25, .3, .6, .5, .5, "Cj"], [0, .55, .3, .4, .15, .35, "Cj", false]]],
	"estante_metal": [1.6, .5, [[0, 1.1, .25, 1.6, 2.2, .5, "K"], [-.35, .35, .5, .55, .4, .15, "Rj", false], [.35, .35, .5, .55, .4, .15, "Az", false], [-.35, 1.05, .5, .55, .4, .15, "T", false], [.35, 1.05, .5, .55, .4, .15, "Cj", false]]],
	"estante_tienda": [1.5, .5, [[0, 1.0, .25, 1.5, 2.0, .5, "Md"], [-.45, .5, .5, .32, .3, .2, "Rj", false], [0, .5, .5, .32, .3, .2, "Az", false], [.45, .5, .5, .32, .3, .2, "O", false], [-.45, 1.1, .5, .32, .3, .2, "V", false], [0, 1.1, .5, .32, .3, .2, "Vv", false], [.45, 1.1, .5, .32, .3, .2, "T", false]]],
	"estante_pociones": [1.4, .4, [[0, 1.0, .2, 1.4, 2.0, .4, "Md"], [-.4, .6, .38, .2, .3, .2, "Vv", false], [0, .6, .38, .2, .3, .2, "V", false], [.4, .6, .38, .2, .3, .2, "Mg", false], [-.4, 1.2, .38, .2, .3, .2, "Az", false], [0, 1.2, .38, .2, .3, .2, "Rj", false], [.4, 1.2, .38, .2, .3, .2, "O", false]]],
	"banco": [1.8, .8, [[0, .5, .45, 1.8, 1.0, .8, "M"], [.3, 1.05, .45, .3, .1, .2, "K", false]]],
	"chimenea": [1.4, .6, [[0, .8, .3, 1.4, 1.6, .6, "P"], [0, .3, .35, .8, .6, .3, "N", false], [0, .3, .4, .5, .3, .1, "Fu", false]]],
	"mostrador": [3.0, .8, [[0, .55, .4, 3.0, 1.1, .8, "M"], [0, 1.12, .4, 3.1, .06, .9, "Ml", false], [.6, 1.25, .4, .4, .25, .3, "K", false]]],
	"maquina": [.8, .7, [[0, .9, .3, .8, 1.8, .6, "Rj"], [0, 1.3, .62, .5, .4, .05, "N", false], [0, 1.6, .62, .6, .1, .05, "O", false]]],
	"camilla": [.9, 2.0, [[0, .4, 1.0, .9, .5, 2.0, "B"], [0, .7, 1.1, .8, .1, 1.8, "Az", false]]],
	"caja_fuerte": [1.0, .8, [[0, .6, .4, 1.0, 1.2, .8, "K"], [0, .6, .82, .5, .5, .05, "O", false]]],
	"archivador": [.8, .5, [[0, .7, .25, .8, 1.4, .5, "K"]]],
	"taquilla": [.6, .5, [[0, .9, .25, .6, 1.8, .5, "K"], [0, 1.2, .52, .1, .3, .03, "N", false]]],
	"caldero": [.7, .7, [[0, .4, .35, .7, .8, .7, "N"], [0, .8, .35, .6, .06, .6, "Vv", false]]],
	"altavoz": [.6, .5, [[0, .9, .25, .6, 1.8, .5, "N"], [0, .7, .52, .4, .4, .03, "G", false]]],
	"piano": [1.5, 1.2, [[0, .45, .6, 1.5, .9, 1.2, "N"], [0, .92, .3, 1.4, .05, .5, "B", false]]],
	"percha": [.8, .3, [[0, 1.6, .06, .8, .08, .06, "Md", false], [-.25, 1.4, .1, .06, .3, .06, "Td", false], [.25, 1.4, .1, .06, .3, .06, "Rj", false]]],
	"cuna": [.8, 1.2, [[0, .35, .6, .8, .5, 1.2, "Ml"], [0, .55, .6, .7, .12, 1.0, "B", false]]],
	"cuadro": [1.0, .1, [[0, 1.7, .03, 1.0, .7, .04, "Mg", false]]],
}

const ROJO: Color = Color(0.7, 0.15, 0.15)


static func _col(P: PlanoInterior, cod: String, tela: Color) -> Color:
	match cod:
		"M": return P.est["madera"]
		"Md": return (P.est["madera"] as Color).darkened(0.2)
		"Ml": return (P.est["madera"] as Color).lightened(0.15)
		"T": return tela
		"Td": return tela.darkened(0.15)
		"B": return Color(0.9, 0.9, 0.88)
		"K": return Color(0.55, 0.57, 0.6)
		"N": return Color(0.08, 0.08, 0.1)
		"O": return Color(0.95, 0.82, 0.4)
		"C": return Color(0.8, 0.78, 0.72)
		"G": return Color(0.25, 0.25, 0.28)
		"F": return Color(0.85, 0.85, 0.88)
		"Cl": return Color(0.65, 0.35, 0.22)
		"V": return Color(0.2, 0.5, 0.25)
		"Cj": return Color(0.62, 0.48, 0.28)
		"P": return Color(0.5, 0.5, 0.52)
		"Fu": return Color(1.0, 0.55, 0.15)
		"Rj": return ROJO
		"Az": return Color(0.35, 0.55, 0.85)
		"Vv": return Color(0.55, 0.3, 0.8)
		"Mg": return Color(0.8, 0.3, 0.6)
	return Color(0.5, 0.5, 0.5)


# Pone un mueble pegado a una de las paredes ("SNWE", en orden aleatorio). true si cupo.
static func poner(P: PlanoInterior, nombre: String, r: Rect2, paredes: String) -> bool:
	if not ITEMS.has(nombre):
		return false
	var it: Array = ITEMS[nombre]
	var orden: Array = []
	for i in paredes.length():
		orden.append(paredes.substr(i, 1))
	for i in range(orden.size() - 1, 0, -1):
		var j: int = P.rng.randi() % (i + 1)
		var t: Variant = orden[i]
		orden[i] = orden[j]
		orden[j] = t
	P.nombre_pieza_vital = nombre == "cama" or nombre == "jergon" or nombre == "catre"
	for w in orden:
		var a: float = P.hueco(r, w, float(it[0]), float(it[1]))
		if is_nan(a):
			continue
		P.nombre_pieza_vital = false
		var n0: int = P.cajas.size()
		var tela: Color = P.color_tela()
		for pt in it[2]:
			P.pieza(r, w, a, 0.0, float(pt[0]), float(pt[1]), float(pt[2]), float(pt[3]), float(pt[4]), float(pt[5]),
					_col(P, str(pt[6]), tela), pt.size() < 8 or bool(pt[7]))
		match nombre:
			"cama", "jergon", "catre":
				P.anotar_cama(n0)
			"mesilla":
				P.anotar_mueble(n0, "joyero" if P.muebles.size() % 2 == 0 else "cajon")
			"armario":
				P.anotar_mueble(n0, "armario")
			"escritorio", "comoda":
				P.anotar_mueble(n0, "cajon")
		return true
	if nombre == "cama" or nombre == "jergon":
		return poner(P, "catre", r, paredes)   # Habitación pequeña: un catre estrecho.
	return false


# Muebles que van en medio de la sala. Devuelve true si cupo.
static func libre(P: PlanoInterior, nombre: String, r: Rect2) -> bool:
	var m: Color = P.est["madera"]
	match nombre:
		"alfombra":
			var su: float = minf(r.size.x - 1.0, 2.6)
			var sv: float = minf(r.size.y - 1.0, 2.0)
			if su < 1.2 or sv < 1.2:
				return false
			P.caja(r.get_center().x, r.get_center().y, 0.035, su, 0.03, sv, P.color_tela().darkened(0.2), false)
			return true
		"mesa", "mesa_grande":
			var su2: float = 1.3 if nombre == "mesa" else 2.2
			var p: Variant = P.centro_libre(r, su2, 1.9)
			if p == null:
				return false
			var pu: Vector2 = p
			P.caja(pu.x, pu.y, 0.76, su2, 0.08, 0.9, m)
			for dx in [-1.0, 1.0]:
				for dz in [-1.0, 1.0]:
					P.caja(pu.x + dx * (su2 / 2.0 - 0.08), pu.y + dz * 0.37, 0.37, 0.08, 0.74, 0.08, m.darkened(0.2))
			for dz in [-1.0, 1.0]:
				P.caja(pu.x, pu.y + dz * 0.75, 0.25, 0.4, 0.5, 0.4, m.lightened(0.1))
			return true
		"mesa_alq":
			var p2: Variant = P.centro_libre(r, 1.6, 1.0)
			if p2 == null:
				return false
			var q: Vector2 = p2
			P.caja(q.x, q.y, 0.8, 1.6, 0.1, 0.9, m.darkened(0.2))
			P.caja(q.x - 0.4, q.y, 1.0, 0.15, 0.3, 0.15, Color(0.55, 0.3, 0.8), false)
			P.caja(q.x, q.y, 1.0, 0.15, 0.3, 0.15, Color(0.3, 0.8, 0.4), false)
			P.caja(q.x + 0.4, q.y, 1.0, 0.15, 0.3, 0.15, Color(0.9, 0.3, 0.3), false)
			return true
		"mesa_juego":
			var p3: Variant = P.centro_libre(r, 2.0, 1.2, 0.9)
			if p3 == null:
				return false
			var s: Vector2 = p3
			P.caja(s.x, s.y, 0.45, 0.4, 0.9, 0.4, m.darkened(0.3))
			P.caja(s.x, s.y, 0.9, 2.0, 0.1, 1.2, Color(0.1, 0.45, 0.25))
			P.caja(s.x, s.y - 0.9, 0.5, 2.1, 0.2, 0.2, m)
			return true
		"elevador":
			var p4: Variant = P.centro_libre(r, 2.4, 4.0, 0.9)
			if p4 == null:
				return false
			var t: Vector2 = p4
			P.caja(t.x, t.y, 0.2, 2.4, 0.3, 4.0, Color(0.9, 0.7, 0.1))
			for dx in [-1.0, 1.0]:
				P.caja(t.x + dx * 1.3, t.y, 1.0, 0.2, 2.0, 0.3, Color(0.3, 0.3, 0.33))
			return true
		"pista":
			var nx: int = clampi(int(r.size.x), 2, 12)
			var nz: int = clampi(int(r.size.y), 2, 8)
			var cols: Array = [Color(0.8, 0.1, 0.6), Color(0.1, 0.6, 0.9), Color(0.5, 0.2, 0.9), Color(0.9, 0.8, 0.2)]
			for i in nx:
				for j in nz:
					var cx: float = r.position.x + (i + 0.5) * r.size.x / nx
					var cz: float = r.position.y + (j + 0.5) * r.size.y / nz
					P.caja(cx, cz, 0.03, r.size.x / nx - 0.05, 0.03, r.size.y / nz - 0.05, cols[(i + j * 2) % 4].darkened(0.3 if (i + j) % 2 == 0 else 0.0), false)
			return true
	return false
