# interior_casa.gd
# -----------------------------------------------------------------------------
# Reparto de habitaciones y muebles del interior de CUALQUIER edificio del mundo (casas, tiendas,
# almacenes y servicios: banco, hospital, taberna...), planta por planta y con escalera.
# Solo calcula DATOS (cajas con posición, tamaño y color): es barato y da siempre lo mismo para el
# mismo edificio. Quien lo convierte en nodos es GestorInteriores, y solo al acercarte.
#
# Cómo reparte: la planta baja tiene una sala de entrada (delante) y, detrás, habitaciones que
# salen de partir el rectángulo al azar (BSP) con puertas que las conectan. Cada habitación recibe
# un oficio (dormitorio, cocina, laboratorio, celda...) y se amuebla con la tabla ROLES. El estilo
# (humilde, normal, rica; común, rústica, magia) cambia colores y muebles. Si hay escalera, ocupa
# una franja pegada a una pared (ver EscaleraEdificio) y todas las plantas la respetan.
# Devuelve {"cajas","luces","habitaciones","tipo","camas","muebles","entrada","salas","estilo","escalera"}.
# -----------------------------------------------------------------------------
class_name InteriorCasa
extends RefCounted

const ALTO_INT: float = 3.0
const TABIQUE: float = 0.15
const GAP: float = 1.0
const MIN_LADO: float = 2.1

const PALETAS: Dictionary = {
	"humilde": {"madera": [Color(0.4, 0.3, 0.2), Color(0.35, 0.27, 0.2)], "tela": [Color(0.45, 0.38, 0.3), Color(0.4, 0.35, 0.3), Color(0.5, 0.42, 0.3)], "suelo": Color(0.33, 0.26, 0.19), "pared": Color(0.75, 0.72, 0.64)},
	"normal": {"madera": [Color(0.45, 0.3, 0.18), Color(0.55, 0.4, 0.25), Color(0.35, 0.25, 0.18), Color(0.6, 0.5, 0.35)], "tela": [Color(0.6, 0.2, 0.2), Color(0.2, 0.35, 0.5), Color(0.3, 0.5, 0.35), Color(0.7, 0.6, 0.3), Color(0.5, 0.35, 0.55)], "suelo": Color(0.45, 0.33, 0.2), "pared": Color(0.82, 0.78, 0.7)},
	"rica": {"madera": [Color(0.3, 0.18, 0.1), Color(0.25, 0.15, 0.1)], "tela": [Color(0.55, 0.1, 0.15), Color(0.15, 0.25, 0.5), Color(0.6, 0.5, 0.15), Color(0.1, 0.35, 0.3)], "suelo": Color(0.6, 0.55, 0.5), "pared": Color(0.9, 0.86, 0.75)},
	"magia": {"madera": [Color(0.2, 0.14, 0.2)], "tela": [Color(0.35, 0.15, 0.5), Color(0.15, 0.2, 0.45), Color(0.5, 0.2, 0.4)], "suelo": Color(0.2, 0.16, 0.25), "pared": Color(0.38, 0.32, 0.5)},
	"rustica": {"madera": [Color(0.38, 0.26, 0.15), Color(0.32, 0.22, 0.13)], "tela": [Color(0.55, 0.4, 0.25), Color(0.5, 0.25, 0.2), Color(0.4, 0.45, 0.3)], "suelo": Color(0.45, 0.32, 0.2), "pared": Color(0.78, 0.7, 0.55)},
}

# Qué lleva cada tipo de habitación: [mueble, paredes donde probar, probabilidad, veces].
const ROLES: Dictionary = {
	"salon": [["sofa", "SWE", 1.0, 1], ["tele", "NWE", 0.9, 1], ["estanteria", "EWN", 0.8, 1], ["planta", "SWEN", 0.8, 2], ["comoda", "NWE", 0.4, 1], ["mesa", "", 0.5, 1], ["alfombra", "", 0.8, 1], ["cuadro", "NWE", 0.5, 1]],
	"salon_cocina": [["encimera", "WEN", 1.0, 1], ["nevera", "WEN", 1.0, 1], ["cocina", "WEN", 0.7, 1], ["sofa", "SWE", 1.0, 1], ["tele", "NWE", 0.8, 1], ["mesa", "", 0.9, 1], ["planta", "SWEN", 0.6, 1]],
	"loft": [["cama", "NWE", 1.0, 1], ["mesilla", "NWE", 0.9, 1], ["armario", "WEN", 1.0, 1], ["encimera", "WES", 1.0, 1], ["nevera", "WES", 1.0, 1], ["sofa", "EWS", 0.9, 1], ["estanteria", "EWS", 0.7, 1], ["lavabo", "SWE", 0.6, 1], ["mesa", "", 0.9, 1], ["planta", "SWE", 0.7, 1]],
	"recibidor": [["percha", "WE", 0.8, 1], ["baul", "WEN", 0.7, 1], ["planta", "SWEN", 0.8, 1], ["comoda", "WEN", 0.5, 1]],
	"pasillo": [["planta", "SWEN", 0.7, 1], ["cuadro", "NWE", 0.6, 1], ["comoda", "WEN", 0.4, 1], ["baul", "WEN", 0.4, 1]],
	"cocina": [["encimera", "WEN", 1.0, 2], ["nevera", "WEN", 1.0, 1], ["cocina", "WEN", 1.0, 1], ["caja", "WEN", 0.5, 1], ["mesa", "", 0.7, 1], ["estante_metal", "WEN", 0.4, 1]],
	"comedor": [["comoda", "WEN", 0.9, 1], ["estanteria", "WEN", 0.6, 1], ["mesa_grande", "", 1.0, 1], ["planta", "SWEN", 0.7, 1], ["cuadro", "NWE", 0.6, 1]],
	"dormitorio": [["cama", "NWE", 1.0, 1], ["mesilla", "NWE", 0.9, 2], ["armario", "WENS", 1.0, 1], ["comoda", "WENS", 0.5, 1], ["baul", "WENS", 0.3, 1], ["alfombra", "", 0.6, 1], ["cuna", "WENS", 0.2, 1]],
	"bano": [["inodoro", "NWE", 1.0, 1], ["lavabo", "NWE", 1.0, 1], ["banera", "WEN", 0.8, 1]],
	"aseo": [["inodoro", "NWE", 1.0, 1], ["lavabo", "NWE", 1.0, 1]],
	"estudio": [["escritorio", "NWE", 1.0, 1], ["libreria", "WEN", 1.0, 2], ["sofa", "SWE", 0.4, 1], ["planta", "SWEN", 0.5, 1], ["alfombra", "", 0.6, 1]],
	"laboratorio": [["caldero", "NWE", 1.0, 2], ["estante_pociones", "WEN", 1.0, 2], ["libreria", "WEN", 0.8, 1], ["mesa_alq", "", 1.0, 1], ["escritorio", "WEN", 0.6, 1], ["alfombra", "", 0.8, 1]],
	"despensa": [["estante_metal", "WEN", 1.0, 2], ["caja", "WEN", 1.0, 2], ["barril", "WEN", 1.0, 2], ["saco", "WEN", 0.8, 2]],
	"trastero": [["caja", "WENS", 1.0, 3], ["barril", "WENS", 0.7, 1], ["estante_metal", "WEN", 0.7, 1], ["saco", "WENS", 0.5, 1]],
	"taller_casa": [["banco", "NWE", 1.0, 2], ["estante_metal", "WEN", 0.8, 1], ["caja", "WEN", 0.8, 2], ["barril", "WEN", 0.5, 1]],
	"tienda_sala": [["mostrador", "N", 1.0, 1], ["estante_tienda", "WE", 1.0, 3], ["estante_tienda", "N", 0.8, 1], ["planta", "SWE", 0.6, 1], ["caja", "WE", 0.5, 1]],
	"almacen_sala": [["estante_metal", "NWE", 1.0, 5], ["banco", "EW", 0.9, 1], ["barril", "SWE", 1.0, 3], ["caja", "WEN", 1.0, 4]],
	"oficina": [["escritorio", "NWE", 1.0, 1], ["archivador", "WEN", 1.0, 2], ["estanteria", "WEN", 0.6, 1], ["planta", "SWEN", 0.6, 1], ["mesa", "", 0.4, 1]],
	"sala_reuniones": [["mesa_grande", "", 1.0, 2], ["estanteria", "WEN", 0.6, 1], ["planta", "SWEN", 0.6, 1]],
	"sala_banco": [["mostrador", "N", 1.0, 1], ["archivador", "WE", 0.8, 2], ["planta", "SWE", 0.9, 2], ["sofa", "WE", 0.6, 1], ["cuadro", "WE", 0.6, 1]],
	"boveda": [["caja_fuerte", "NWE", 1.0, 3], ["archivador", "WEN", 1.0, 3], ["taquilla", "WEN", 1.0, 3], ["caja", "WEN", 0.8, 2]],
	"recepcion": [["mostrador", "N", 1.0, 1], ["sofa", "WE", 1.0, 2], ["planta", "SWE", 0.9, 2], ["archivador", "WE", 0.5, 1]],
	"consulta": [["camilla", "NWE", 1.0, 1], ["escritorio", "WEN", 1.0, 1], ["estanteria", "WEN", 0.8, 1], ["taquilla", "WEN", 0.6, 1]],
	"quirofano": [["estante_metal", "WEN", 1.0, 2], ["taquilla", "WEN", 1.0, 2], ["camilla", "WEN", 1.0, 1]],
	"sala_camas": [["camilla", "WE", 1.0, 6], ["armario", "WEN", 0.6, 1], ["planta", "SWE", 0.6, 1]],
	"farmacia": [["estante_pociones", "WEN", 1.0, 3], ["mostrador", "N", 0.8, 1], ["archivador", "WEN", 0.5, 1]],
	"sala_taberna": [["mostrador", "N", 1.0, 1], ["barril", "NWE", 1.0, 3], ["chimenea", "WE", 0.8, 1], ["mesa", "", 1.0, 4], ["mesa", "", 0.6, 2], ["planta", "SWE", 0.6, 1]],
	"bodega": [["barril", "WENS", 1.0, 6], ["caja", "WENS", 1.0, 3], ["estante_metal", "WEN", 0.8, 1]],
	"pista": [["pista", "", 1.0, 1], ["altavoz", "NWE", 1.0, 3], ["sofa", "WE", 1.0, 2]],
	"vip": [["sofa", "NWE", 1.0, 3], ["mesa", "", 1.0, 2], ["mostrador", "WE", 0.6, 1], ["altavoz", "WE", 0.6, 1]],
	"camerino": [["armario", "WEN", 1.0, 1], ["escritorio", "NWE", 1.0, 1], ["sofa", "WE", 0.6, 1], ["planta", "SWEN", 0.5, 1]],
	"salon_maquinas": [["maquina", "NWE", 1.0, 10], ["maquina", "SWE", 0.8, 4], ["planta", "SWE", 0.6, 1]],
	"salon_juego": [["mesa_juego", "", 1.0, 3], ["mostrador", "N", 1.0, 1], ["maquina", "WE", 0.8, 4], ["planta", "SWE", 0.7, 2]],
	"taller_nave": [["elevador", "", 1.0, 2], ["banco", "NWE", 1.0, 2], ["estante_metal", "WEN", 1.0, 2], ["barril", "WEN", 1.0, 2], ["caja", "WEN", 1.0, 3], ["taquilla", "WEN", 0.8, 2]],
	"tienda_gas": [["estante_tienda", "NWE", 1.0, 3], ["mostrador", "N", 1.0, 1], ["nevera", "WE", 1.0, 2], ["planta", "SWE", 0.5, 1]],
	"recepcion_pol": [["mostrador", "N", 1.0, 1], ["archivador", "WE", 1.0, 2], ["sofa", "WE", 0.8, 1], ["planta", "SWE", 0.6, 1]],
	"celda": [["jergon", "NWE", 1.0, 2], ["inodoro", "NWE", 1.0, 1], ["banco", "WE", 0.6, 1]],
	"garaje": [["taquilla", "NWE", 1.0, 4], ["banco", "NWE", 1.0, 1], ["barril", "WEN", 0.8, 2], ["caja", "WEN", 1.0, 3], ["elevador", "", 1.0, 1]],
	"dormitorio_colectivo": [["cama", "WE", 1.0, 4], ["mesilla", "WE", 0.9, 3], ["armario", "NWE", 1.0, 2], ["taquilla", "WEN", 0.8, 2]],
	"sala_club": [["mostrador", "N", 1.0, 1], ["sofa", "WE", 1.0, 3], ["mesa", "", 1.0, 3], ["piano", "WE", 0.6, 1], ["altavoz", "WE", 0.6, 2], ["planta", "SWE", 0.7, 2]],
	"sala_timba": [["mesa_juego", "", 1.0, 2], ["mostrador", "N", 0.8, 1], ["barril", "WEN", 1.0, 3], ["caja", "WEN", 1.0, 2], ["mesa", "", 0.8, 2]],
	"oficina_prestamista": [["mostrador", "N", 1.0, 1], ["caja_fuerte", "WE", 1.0, 2], ["archivador", "WE", 1.0, 2], ["planta", "SWE", 0.5, 1]],
	"mercadillo": [["mostrador", "WE", 1.0, 3], ["estante_tienda", "N", 1.0, 2], ["caja", "WENS", 1.0, 4], ["barril", "WENS", 0.8, 2], ["saco", "WENS", 0.8, 2]],
	"almacen_ilegal": [["caja", "WENS", 1.0, 6], ["estante_metal", "WEN", 1.0, 3], ["barril", "WENS", 1.0, 3]],
}

# Programa de cada servicio: sala de entrada, habitaciones de detrás (de mayor a menor) y plantas de arriba.
const SERV: Dictionary = {
	"banco": {"entrada": "sala_banco", "resto": ["boveda", "oficina", "oficina", "aseo"], "alto": ["oficina", "sala_reuniones", "oficina", "aseo"], "frac": 0.55},
	"hospital": {"entrada": "recepcion", "resto": ["consulta", "consulta", "quirofano", "farmacia", "aseo"], "alto": ["sala_camas", "sala_camas", "consulta", "sala_camas", "aseo"], "frac": 0.4},
	"taberna": {"entrada": "sala_taberna", "resto": ["bodega", "cocina", "aseo"], "alto": [], "frac": 0.6},
	"discoteca": {"entrada": "pista", "resto": ["camerino", "bodega", "aseo"], "alto": ["vip", "vip", "oficina", "aseo"], "frac": 0.65},
	"tragaperras": {"entrada": "salon_maquinas", "resto": ["oficina", "bodega"], "alto": [], "frac": 0.7},
	"casino": {"entrada": "salon_juego", "resto": ["boveda", "oficina", "aseo"], "alto": ["vip", "salon_juego", "sala_reuniones", "oficina"], "frac": 0.65},
	"taller": {"entrada": "taller_nave", "resto": ["oficina", "garaje", "aseo"], "alto": [], "frac": 0.65},
	"gasolinera": {"entrada": "tienda_gas", "resto": ["bodega"], "alto": [], "frac": 0.7},
	"comisaria": {"entrada": "recepcion_pol", "resto": ["oficina", "celda", "celda", "boveda"], "alto": [], "frac": 0.4},
	"bomberos": {"entrada": "garaje", "resto": ["dormitorio_colectivo", "cocina", "aseo"], "alto": [], "frac": 0.6},
	"club": {"entrada": "sala_club", "resto": ["camerino", "vip", "bodega"], "alto": [], "frac": 0.6},
	"timba": {"entrada": "sala_timba", "resto": ["bodega", "oficina"], "alto": [], "frac": 0.6},
	"prestamista": {"entrada": "oficina_prestamista", "resto": ["oficina", "boveda"], "alto": [], "frac": 0.5},
	"mercado_negro": {"entrada": "mercadillo", "resto": ["almacen_ilegal", "oficina"], "alto": [], "frac": 0.6},
}
# Para los servicios sin programa propio (peluquería, barbería, negocios nuevos...).
const SERV_GENERICO: Dictionary = {"entrada": "oficina", "resto": ["bodega", "aseo"], "alto": ["oficina", "aseo"], "frac": 0.55}


static func _estilo(c: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var distrito: String = str(c.get("distrito", "residencial"))
	var ta: int = int(c.get("tipo_asent", 1))
	var nivel: String = "normal"
	var tema: String = "comun"
	var r: float = rng.randf()
	if distrito == "rico":
		nivel = "rica"
	elif distrito == "industrial":
		nivel = "humilde"
	elif ta == 0:
		nivel = "humilde" if r < 0.8 else "normal"
		tema = "rustica"
	elif ta == 1:
		nivel = "humilde" if r < 0.25 else ("normal" if r < 0.9 else "rica")
		tema = "rustica" if rng.randf() < 0.5 else "comun"
	else:
		nivel = "humilde" if r < 0.3 else ("normal" if r < 0.9 else "rica")
	if distrito != "industrial" and not c.has("servicio") and rng.randf() < 0.07:
		tema = "magia"
	var clave: String = "magia" if tema == "magia" else ("rustica" if tema == "rustica" and nivel != "rica" else nivel)
	var pal: Dictionary = PALETAS[clave]
	var tipo: String = "vivienda"
	if c.has("servicio"):
		tipo = "servicio"
	elif distrito == "industrial":
		tipo = "almacen"
	elif distrito == "centro":
		tipo = "tienda"
	var maderas: Array = pal["madera"]
	return {"nivel": nivel, "tema": tema, "tipo": tipo, "madera": maderas[rng.randi() % maderas.size()], "tela": pal["tela"],
			"suelo": pal["suelo"], "pared": pal["pared"]}


static func generar(c: Dictionary) -> Dictionary:
	var P: PlanoInterior = PlanoInterior.new()
	P.configurar(c)
	P.rng.seed = int(c.get("var", 0)) * 7919 + int(absf(P.x) * 13.0) + int(absf(P.z) * 29.0) + 17
	var est: Dictionary = _estilo(c, P.rng)
	P.est = est
	var e: Dictionary = EscaleraEdificio.de(c)
	for n in P.pisos:
		P.ir_a_nivel(n)
		_planta(P, c, est, e, n)
	# Como mucho unas 10 luces por edificio (cada luz cuesta).
	var luces: Array = P.luces
	if luces.size() > 10:
		var pocas: Array = []
		var paso: float = float(luces.size()) / 10.0
		for i in 10:
			pocas.append(luces[int(i * paso)])
		luces = pocas
	return {"cajas": P.cajas, "luces": luces, "habitaciones": P.habitaciones, "tipo": est["tipo"],
			"camas": P.camas, "muebles": P.muebles, "salas": P.salas, "paredes": P.paredes_info, "estilo": est, "escalera": e,
			"entrada": P.punto(0.0, 0.6, P.y + 0.1)}


# ---------------------------------- una planta ----------------------------------

static func _planta(P: PlanoInterior, c: Dictionary, est: Dictionary, e: Dictionary, n: int) -> void:
	var W: float = P.W
	var D: float = P.D
	var paredes: Array = []
	var R: Rect2 = Rect2(-W / 2.0, 0.0, W, D)
	if n == 0:
		P.reservar(Rect2(-0.9, 0.0, 1.8, 1.5))   # La entrada.
	if not e.is_empty():
		var fr: Rect2 = e["franja"]
		var iv_f: float = e["iv_frente"]
		var lado: float = e["lado"]
		var hall: Rect2 = Rect2(fr.position.x, 0.0, fr.size.x, iv_f)
		P.sala(hall, "rellano")
		P.suelo(hall, (est["suelo"] as Color).darkened(0.1))
		P.luz(hall.get_center().x, iv_f / 2.0, 2.7)
		P.reservar(fr)
		var u_muro: float = float(e["u_borde"]) + (-0.075 if lado < 0.0 else 0.075)
		paredes.append({"eje": "z", "fijo": u_muro, "a0": 0.0, "a1": iv_f, "puertas": [clampf(iv_f / 2.0, 0.8, 1.6)]})
		if lado < 0.0:
			R = Rect2(fr.end.x, 0.0, W / 2.0 - fr.end.x, D)
		else:
			R = Rect2(-W / 2.0, 0.0, fr.position.x + W / 2.0, D)
	var tipo: String = est["tipo"]
	var prog: Dictionary = SERV.get(str(c.get("servicio", "")), SERV_GENERICO) as Dictionary
	var frac: float = float(prog.get("frac", 0.45))
	var F: float = R.size.y
	if R.size.y >= 7.5:
		F = clampf(R.size.y * frac, 2.8, 8.0)
	var banda: Rect2 = R
	var hojas: Array = []
	if F < R.size.y - 0.1:
		banda = Rect2(R.position.x, 0.0, R.size.x, F - TABIQUE / 2.0)
		var fondo: Rect2 = Rect2(R.position.x, F + TABIQUE / 2.0, R.size.x, R.size.y - F - TABIQUE / 2.0)
		var pared_f: Dictionary = {"eje": "x", "fijo": F, "a0": R.position.x, "a1": R.end.x, "puertas": []}
		paredes.append(pared_f)
		_bsp(P, fondo, 0, est, paredes, hojas)
		for h in hojas:
			var hr: Rect2 = h
			if hr.size.x >= 1.6:
				(pared_f["puertas"] as Array).append(clampf(hr.get_center().x + P.rng.randf_range(-0.3, 0.3), hr.position.x + 0.8, hr.end.x - 0.8))
	# Las puertas que caen justo en una pared que se cruza se mueven a un sitio libre.
	for pw in paredes:
		if not pw.has("bsp"):
			continue
		var prohibidos: Array = []
		for o in paredes:
			if o["eje"] != pw["eje"] and float(o["a0"]) - 0.2 <= float(pw["fijo"]) and float(o["a1"]) + 0.2 >= float(pw["fijo"]):
				prohibidos.append(float(o["fijo"]))
		var hcs: Array = pw["puertas"]
		for i in hcs.size():
			var ok: bool = true
			for f in prohibidos:
				if absf(float(hcs[i]) - float(f)) < 0.85:
					ok = false
			if ok:
				continue
			var mejor: float = NAN
			for margen in [0.85, 0.7, 0.6]:
				var t: float = float(pw["a0"]) + 0.6
				while t <= float(pw["a1"]) - 0.6:
					var libre_t: bool = true
					for f in prohibidos:
						if absf(t - float(f)) < margen:
							libre_t = false
					if libre_t and (is_nan(mejor) or absf(t - float(hcs[i])) < absf(mejor - float(hcs[i]))):
						mejor = t
					t += 0.1
				if not is_nan(mejor):
					break
			if not is_nan(mejor):
				hcs[i] = mejor
	# Tabiques con puertas.
	for pw in paredes:
		P.paredes_info.append({"nivel": n, "eje": pw["eje"], "fijo": pw["fijo"], "a0": pw["a0"], "a1": pw["a1"], "puertas": (pw["puertas"] as Array).duplicate()})
		for hc in pw["puertas"]:
			P.zona_puerta(pw["eje"], float(pw["fijo"]), float(hc))
		_tabique(P, pw["eje"], float(pw["fijo"]), float(pw["a0"]), float(pw["a1"]), pw["puertas"], est["pared"])
	# Oficios de las salas.
	var roles: Array = _roles(P, est, tipo, prog, n, hojas, banda)
	var todas: Array = [banda]
	todas.append_array(hojas)
	for i in todas.size():
		_amueblar(P, roles[i], todas[i], est)
	if n == 0 and tipo == "vivienda" and (P.camas.size() < 2 or P.muebles.size() < 2):
		P.holg_extra = 0.0
		for sala_r in todas:
			if P.camas.size() < 2 and MueblesInterior.poner(P, "cama", sala_r, "NWES"):
				MueblesInterior.poner(P, "mesilla", sala_r, "NWES")
			if P.muebles.size() < 2:
				MueblesInterior.poner(P, "armario", sala_r, "NWES")
		if P.camas.is_empty():
			var destinos: Array = hojas.duplicate()
			destinos.append(banda)
			for sala_r in destinos:
				if MueblesInterior.poner(P, "jergon", sala_r, "N" if sala_r == banda else "NWES"):
					break
	P.luz(banda.get_center().x, banda.get_center().y, 2.7)
	for h in hojas:
		P.luz((h as Rect2).get_center().x, (h as Rect2).get_center().y, 2.7)


# Parte la sala r al azar en habitaciones con puertas entre las dos mitades.
static func _bsp(P: PlanoInterior, r: Rect2, prof: int, est: Dictionary, paredes: Array, hojas: Array) -> void:
	var parar: float = 0.15 if est["nivel"] == "rica" else (0.45 if est["nivel"] == "humilde" else 0.3)
	var puede_x: bool = r.size.x >= 2.0 * MIN_LADO + TABIQUE
	var puede_z: bool = r.size.y >= 2.0 * MIN_LADO + TABIQUE
	if (not puede_x and not puede_z) or prof >= 3 or (prof >= 1 and r.size.x * r.size.y < 12.0) \
			or (prof >= 1 and P.rng.randf() < parar):
		hojas.append(r)
		return
	var vertical: bool = puede_x and (not puede_z or r.size.x > r.size.y * 1.1 or (r.size.x > r.size.y * 0.9 and P.rng.randf() < 0.5))
	var t: float = P.rng.randf_range(0.4, 0.6)
	if vertical:
		var pos: float = clampf(r.position.x + r.size.x * t, r.position.x + MIN_LADO + TABIQUE / 2.0, r.end.x - MIN_LADO - TABIQUE / 2.0)
		var hc: float = P.rng.randf_range(r.position.y + 0.8, r.end.y - 0.8)
		paredes.append({"eje": "z", "fijo": pos, "a0": r.position.y, "a1": r.end.y, "puertas": [hc], "bsp": true})
		_bsp(P, Rect2(r.position.x, r.position.y, pos - TABIQUE / 2.0 - r.position.x, r.size.y), prof + 1, est, paredes, hojas)
		_bsp(P, Rect2(pos + TABIQUE / 2.0, r.position.y, r.end.x - pos - TABIQUE / 2.0, r.size.y), prof + 1, est, paredes, hojas)
	else:
		var pos2: float = clampf(r.position.y + r.size.y * t, r.position.y + MIN_LADO + TABIQUE / 2.0, r.end.y - MIN_LADO - TABIQUE / 2.0)
		var hc2: float = P.rng.randf_range(r.position.x + 0.8, r.end.x - 0.8)
		paredes.append({"eje": "x", "fijo": pos2, "a0": r.position.x, "a1": r.end.x, "puertas": [hc2], "bsp": true})
		_bsp(P, Rect2(r.position.x, r.position.y, r.size.x, pos2 - TABIQUE / 2.0 - r.position.y), prof + 1, est, paredes, hojas)
		_bsp(P, Rect2(r.position.x, pos2 + TABIQUE / 2.0, r.size.x, r.end.y - pos2 - TABIQUE / 2.0), prof + 1, est, paredes, hojas)


# Oficio de cada sala (la primera de la lista es la de la entrada).
static func _roles(P: PlanoInterior, est: Dictionary, tipo: String, prog: Dictionary, n: int,
		hojas: Array, banda: Rect2) -> Array:
	var out: Array = []
	var pool: Array = []
	var entrada: String = "salon"
	if tipo == "servicio":
		if n == 0:
			entrada = prog["entrada"]
			pool = (prog["resto"] as Array).duplicate()
		else:
			var alto: Array = prog["alto"]
			entrada = "pasillo" if hojas.size() > 0 else (alto[(n - 1) % alto.size()] if alto.size() > 0 else "oficina")
			pool = alto.duplicate()
	elif n > 0:
		entrada = "pasillo" if hojas.size() > 0 else "dormitorio"
		pool = ["dormitorio", "dormitorio", "bano", "estudio", "dormitorio", "trastero"]
		if est["tema"] == "magia" and n == 1:
			pool[1] = "laboratorio"
	elif tipo == "tienda":
		entrada = "tienda_sala"
		pool = ["despensa", "oficina", "aseo"]
	elif tipo == "almacen":
		entrada = "almacen_sala"
		pool = ["oficina", "trastero", "aseo"]
	elif P.pisos > 1:
		entrada = "recibidor" if banda.size.y < 3.4 else "salon"
		pool = ["cocina", "comedor" if est["nivel"] != "humilde" else "despensa", "estudio", "aseo", "trastero"]
		if est["tema"] == "magia":
			pool[1] = "laboratorio"
	else:
		entrada = "salon_cocina" if hojas.size() < 3 else "salon"
		pool = ["dormitorio", "bano", "cocina", "dormitorio", "estudio", "despensa"]
		if entrada == "salon_cocina":
			pool.erase("cocina")
		if hojas.is_empty():
			entrada = "loft"
		if est["tema"] == "magia" and hojas.size() > 2:
			pool[2] = "laboratorio"
		if est["tema"] == "rustica" and hojas.size() > 3:
			pool[4] = "taller_casa"
	out.append(entrada)
	# La sala más pequeña es el baño/aseo si el programa lo tiene.
	var orden: Array = []
	for i in hojas.size():
		orden.append(i)
	orden.sort_custom(func(a, b): return (hojas[a] as Rect2).get_area() > (hojas[b] as Rect2).get_area())
	var rol_h: Array = []
	rol_h.resize(hojas.size())
	var bano: String = ""
	for b in ["bano", "aseo"]:
		if pool.has(b):
			bano = b
	if bano != "" and hojas.size() >= 2:
		rol_h[orden[orden.size() - 1]] = bano
		orden.pop_back()
		while pool.has("bano"):
			pool.erase("bano")
		while pool.has("aseo"):
			pool.erase("aseo")
	var k: int = 0
	for i in orden:
		rol_h[i] = pool[k] if k < pool.size() else ("trastero" if tipo != "servicio" else "oficina")
		k += 1
	out.append_array(rol_h)
	return out


static func _amueblar(P: PlanoInterior, rol: String, r: Rect2, est: Dictionary) -> void:
	P.sala(r, rol)
	var col_suelo: Color = est["suelo"]
	match rol:
		"bano", "aseo":
			col_suelo = Color(0.72, 0.76, 0.78)
		"cocina":
			col_suelo = Color(0.7, 0.6, 0.5)
		"dormitorio", "estudio", "sala_banco", "recepcion":
			col_suelo = (est["tela"][0] as Color).darkened(0.35)
		"laboratorio":
			col_suelo = Color(0.22, 0.16, 0.28)
		"taller_nave", "garaje", "almacen_sala", "bodega", "almacen_ilegal":
			col_suelo = Color(0.35, 0.35, 0.37)
		"pista":
			col_suelo = Color(0.08, 0.06, 0.12)
	P.suelo(r, col_suelo)
	P.holg_extra = 0.45 if minf(r.size.x, r.size.y) < 3.0 else 0.0
	var lista: Array = ROLES.get(rol, ROLES["trastero"])
	for it in lista:
		for k in int(it[3]):
			if P.rng.randf() > float(it[2]):
				continue
			if str(it[1]) == "":
				MueblesInterior.libre(P, str(it[0]), r)
			else:
				var nombre: String = str(it[0])
				if nombre == "cama" and est["nivel"] == "humilde":
					nombre = "jergon"
				MueblesInterior.poner(P, nombre, r, str(it[1]))
	# Toques de estilo.
	if est["nivel"] == "rica" and rol in ["salon", "comedor", "estudio"]:
		MueblesInterior.poner(P, "piano" if rol == "salon" else "libreria", r, "WEN")
		MueblesInterior.poner(P, "cuadro", r, "NWE")
	if est["tema"] == "magia" and rol in ["salon", "dormitorio", "estudio"]:
		MueblesInterior.poner(P, "estante_pociones", r, "WEN")
		MueblesInterior.poner(P, "caldero", r, "WEN")
	if est["tema"] == "rustica" and rol in ["salon", "salon_cocina", "comedor"]:
		MueblesInterior.poner(P, "chimenea", r, "WEN")


# Pared interior a lo largo de u (eje "x": iv fijo) o de iv (eje "z": u fijo), con puertas.
static func _tabique(P: PlanoInterior, eje: String, fijo: float, a0: float, a1: float, huecos: Array, col: Color) -> void:
	var cursor: float = a0
	var hs: Array = huecos.duplicate()
	hs.sort()
	for hc in hs:
		_tramo(P, eje, fijo, cursor, float(hc) - GAP / 2.0, 0.0, ALTO_INT, col, true)
		_tramo(P, eje, fijo, float(hc) - GAP / 2.0, float(hc) + GAP / 2.0, 2.1, ALTO_INT, col, false)
		cursor = float(hc) + GAP / 2.0
	_tramo(P, eje, fijo, cursor, a1, 0.0, ALTO_INT, col, true)


static func _tramo(P: PlanoInterior, eje: String, fijo: float, a: float, b: float, h0: float, h1: float, col: Color, solido: bool) -> void:
	if b - a < 0.02:
		return
	var m: float = (a + b) / 2.0
	if eje == "x":
		P.caja(m, fijo, (h0 + h1) / 2.0, b - a, h1 - h0, TABIQUE, col, solido)
	else:
		P.caja(fijo, m, (h0 + h1) / 2.0, TABIQUE, h1 - h0, b - a, col, solido)
