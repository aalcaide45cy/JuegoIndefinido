# negocios.gd
# -----------------------------------------------------------------------------
# La lógica de TODOS los negocios del jugador (inmobiliaria, concesionario,
# alquiler de coches, de maquinaria y aeródromo). Es un sistema único hecho por
# datos: lo que se puede tratar está en scripts/datos/negocios.gd.
#
#   Licencias   abren cada negocio y dicen qué se puede hacer (comprar, vender,
#               alquilar) y con qué (pisos, coches, maquinaria, aviones).
#   Mercado     ofertas de vendedores que cambian cada día. Se negocia el precio.
#   Cartera     lo que has comprado. Cada cosa se puede anunciar para venderla
#               o alquilarla, reparar, o sacar a la calle (si es conducible).
#   Clientes    compradores e inquilinos que llegan solos (o los buscas pagando
#               publicidad). Se negocia el precio con ellos.
#   Rentas      los alquileres se cobran solos cada día del juego. Pueden dar
#               problemas: morosos, averías, desgaste y, con vehículos, robos.
#
# El estado vive en Juego.negocio (un diccionario que se guarda con la partida).
# Todas las funciones son estáticas y devuelven un texto para mostrar al jugador
# (si hacen algo) para que las ventanas no repitan lógica.
# GestorNegocios llama a ponerse_al_dia() cada vez que cambia el día.
# SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name Negocios
extends RefCounted

const DatosNegocios = preload("res://scripts/datos/negocios.gd")

const DIAS_OFERTA: int = 4            # Cuánto dura una oferta del mercado.
const DIAS_CLIENTE: int = 3           # Cuánto espera un cliente.
const MAX_DIAS_ATRASADOS: int = 30    # Si pasan más días (F1), se saltan.
const PROB_MORA: float = 0.03
const PROB_AVERIA: float = 0.02
const PROB_CLIENTE: float = 0.4       # Al día, por cosa anunciada.
const OFERTAS_POR_CAT: Dictionary = {"piso": 5, "coche": 5, "pesado": 4, "aire": 3}
# Probabilidad diaria de que un alquilado no se devuelva.
const RIESGO_ROBO: Dictionary = {"piso": 0.0, "coche": 0.003, "pesado": 0.002, "aire": 0.0015}


# ------------------------------- Estado ---------------------------------------

# Devuelve el estado, creándolo la primera vez.
static func estado() -> Dictionary:
	var e: Dictionary = Juego.negocio
	if not e.has("activos"):
		e["licencias"] = {}
		e["activos"] = []
		e["mercado"] = []
		e["leads"] = []
		e["ultimo_dia"] = Juego.dia
		e["sig_id"] = 1
		e["ingresos"] = 0
		e["version"] = 0
	return e


static func _tocar() -> void:
	var e: Dictionary = estado()
	e["version"] = int(e["version"]) + 1


static func _sig_id() -> int:
	var e: Dictionary = estado()
	var id: int = int(e["sig_id"])
	e["sig_id"] = id + 1
	return id


static func _persona() -> String:
	return "%s %s" % [DatosNegocios.NOMBRES_PERSONAS.pick_random(), DatosNegocios.APELLIDOS.pick_random()]


# Pasa un estado leído de un archivo (los números llegan como decimales) a uno
# válido. Lo que no cuadre se descarta.
static func importar(datos) -> void:
	Juego.negocio = {}
	var e: Dictionary = estado()
	if not datos is Dictionary:
		return
	var lic = datos.get("licencias", {})
	if lic is Dictionary:
		for id in lic:
			if DatosNegocios.LICENCIAS.has(str(id)):
				e["licencias"][str(id)] = true
	var max_id: int = 0
	for a in datos.get("activos", []):
		if not a is Dictionary or not DatosNegocios.CATALOGO.has(str(a.get("tipo", ""))):
			continue
		var n: Dictionary = {"uid": maxi(1, int(a.get("uid", 0))), "tipo": str(a["tipo"]),
				"estado": clampf(float(a.get("estado", 100.0)), 0.0, 100.0), "compra": maxi(0, int(a.get("compra", 0))),
				"venta": bool(a.get("venta", false)), "alq_anuncio": bool(a.get("alq_anuncio", false)), "alq": {}}
		var al = a.get("alq", {})
		if al is Dictionary and not al.is_empty():
			n["alq"] = {"cliente": str(al.get("cliente", "Inquilino")), "renta": maxi(1, int(al.get("renta", 1))),
					"dias": clampi(int(al.get("dias", 1)), 1, 365), "moroso": clampi(int(al.get("moroso", 0)), 0, 3)}
		max_id = maxi(max_id, int(n["uid"]))
		e["activos"].append(n)
	for o in datos.get("mercado", []):
		if o is Dictionary and DatosNegocios.CATALOGO.has(str(o.get("tipo", ""))):
			var no: Dictionary = {"id": maxi(1, int(o.get("id", 0))), "tipo": str(o["tipo"]),
					"estado": clampi(int(o.get("estado", 70)), 0, 100), "cifra": maxi(1, int(o.get("cifra", 1))),
					"limite": maxi(1, int(o.get("limite", 1))), "persona": str(o.get("persona", "Vendedor")),
					"dia": int(o.get("dia", Juego.dia)), "paciencia": clampi(int(o.get("paciencia", 3)), 1, 3)}
			max_id = maxi(max_id, int(no["id"]))
			e["mercado"].append(no)
	for l in datos.get("leads", []):
		if l is Dictionary and str(l.get("kind", "")) in ["venta", "alquiler"] and _activo(int(l.get("uid", -1)), e) != null:
			var nl: Dictionary = {"id": maxi(1, int(l.get("id", 0))), "uid": int(l["uid"]), "kind": str(l["kind"]),
					"persona": str(l.get("persona", "Cliente")), "cifra": maxi(1, int(l.get("cifra", 1))),
					"limite": maxi(1, int(l.get("limite", 1))), "paciencia": clampi(int(l.get("paciencia", 3)), 1, 3),
					"dia": int(l.get("dia", Juego.dia)), "dias": clampi(int(l.get("dias", 7)), 1, 365)}
			max_id = maxi(max_id, int(nl["id"]))
			e["leads"].append(nl)
	e["ultimo_dia"] = int(datos.get("ultimo_dia", Juego.dia))
	e["ingresos"] = maxi(0, int(datos.get("ingresos", 0)))
	e["sig_id"] = maxi(int(datos.get("sig_id", 1)), max_id + 1)


static func _activo(uid: int, e: Dictionary = {}) -> Variant:
	var est: Dictionary = estado() if e.is_empty() else e
	for a in est["activos"]:
		if int(a["uid"]) == uid:
			return a
	return null


# ------------------------------- Licencias ------------------------------------

static func tiene_licencia(id: String) -> bool:
	return estado()["licencias"].has(id)


# ¿Puedes hacer "op" ("comprar", "vender", "alquilar") con la categoría "cat"?
static func permite(cat: String, op: String) -> bool:
	for id in estado()["licencias"]:
		var l: Dictionary = DatosNegocios.LICENCIAS[id]
		if cat in l["cats"] and op in l["ops"]:
			return true
	return false


# Nombres de las licencias que permiten algo (para decirte cuál te falta).
static func licencias_para(cat: String, op: String) -> String:
	var nombres: PackedStringArray = []
	for id in DatosNegocios.LICENCIAS:
		var l: Dictionary = DatosNegocios.LICENCIAS[id]
		if cat in l["cats"] and op in l["ops"]:
			nombres.append(str(l["nombre"]))
	return " o ".join(nombres)


static func capacidad() -> int:
	var total: int = 0
	for id in estado()["licencias"]:
		total += int(DatosNegocios.LICENCIAS[id]["capacidad"])
	return total


static func motivo_no_licencia(id: String) -> String:
	var l: Dictionary = DatosNegocios.LICENCIAS[id]
	if tiene_licencia(id):
		return "Ya la tienes."
	if Juego.nivel < int(l["nivel"]):
		return "Necesitas nivel %d." % int(l["nivel"])
	if Juego.dinero < int(l["precio"]):
		return "Cuesta %d $." % int(l["precio"])
	return ""


static func comprar_licencia(id: String) -> String:
	if not DatosNegocios.LICENCIAS.has(id):
		return ""
	var motivo: String = motivo_no_licencia(id)
	if motivo != "":
		return motivo
	var l: Dictionary = DatosNegocios.LICENCIAS[id]
	if not Juego.gastar(int(l["precio"])):
		return "No te llega para la licencia."
	estado()["licencias"][id] = true
	_tocar()
	Juego.ganar_xp(40)
	return "¡Ya tienes la licencia de %s!" % str(l["nombre"])


# ------------------------------- Valores --------------------------------------

# El mercado sube y baja un poco con los días (±8%), distinto en cada categoría.
static func factor_mercado(cat: String) -> float:
	var fase: float = float(cat.hash() % 100) * 0.1
	return 1.0 + 0.08 * sin(float(Juego.dia) * 0.37 + fase)


# Lo que vale ahora algo en ese estado (0 a 100).
static func valor(tipo: String, estado_pct: float) -> int:
	var cat: String = DatosNegocios.cat_de(tipo)
	return int(round(DatosNegocios.precio_base(tipo) * (0.45 + 0.55 * estado_pct / 100.0) * factor_mercado(cat)))


static func renta_ref(tipo: String, estado_pct: float) -> int:
	return maxi(1, int(round(DatosNegocios.renta_base(tipo) * (0.5 + 0.5 * estado_pct / 100.0))))


static func valor_activo(a: Dictionary) -> int:
	return valor(str(a["tipo"]), float(a["estado"]))


static func esta_alquilado(a: Dictionary) -> bool:
	return not a["alq"].is_empty()


# Cuánto cobras al día ahora mismo de todos tus alquileres.
static func ingreso_diario() -> int:
	var total: int = 0
	for a in estado()["activos"]:
		if esta_alquilado(a):
			total += int(round(float(a["alq"]["renta"]) * (0.7 + 0.3 * float(a["estado"]) / 100.0)))
	return total


# Lo que cuesta cada día mantener todo: impuestos, seguros y aparcamiento de cada
# cosa (alquilada o no) y la cuota de cada licencia.
static func gasto_diario() -> int:
	var total: float = 0.0
	for a in estado()["activos"]:
		total += float(valor_activo(a)) * float(DatosNegocios.CATEGORIAS[DatosNegocios.cat_de(str(a["tipo"]))]["gasto"])
	for id in estado()["licencias"]:
		total += float(DatosNegocios.LICENCIAS[id]["precio"]) * DatosNegocios.CUOTA_LICENCIA
	return int(round(total))


static func patrimonio() -> int:
	var total: int = 0
	for a in estado()["activos"]:
		total += valor_activo(a)
	return total


# ------------------------------- Mercado --------------------------------------

static func _crear_oferta(tipo: String) -> Dictionary:
	var est: int = randi_range(35, 100)
	var v: float = float(valor(tipo, float(est)))
	var cifra: int = maxi(2, int(round(v * randf_range(0.97, 1.3))))
	var limite: int = mini(cifra - 1, maxi(1, int(round(v * randf_range(0.82, 0.97)))))
	return {"id": _sig_id(), "tipo": tipo, "estado": est, "cifra": cifra, "limite": limite,
			"persona": _persona(), "dia": Juego.dia, "paciencia": 3}


static func refrescar_mercado() -> void:
	var e: Dictionary = estado()
	var vigentes: Array = []
	for o in e["mercado"]:
		if Juego.dia - int(o["dia"]) < DIAS_OFERTA:
			vigentes.append(o)
	for cat in DatosNegocios.CATEGORIAS:
		var cuantas: int = 0
		for o in vigentes:
			if DatosNegocios.cat_de(str(o["tipo"])) == cat:
				cuantas += 1
		var tipos: Array = DatosNegocios.tipos_de(cat)
		var objetivo: int = int(OFERTAS_POR_CAT.get(cat, 4))
		while cuantas < objetivo and not tipos.is_empty():
			vigentes.append(_crear_oferta(str(tipos.pick_random())))
			cuantas += 1
	e["mercado"] = vigentes
	_tocar()


static func ofertas_de(cat: String) -> Array:
	var r: Array = []
	for o in estado()["mercado"]:
		if DatosNegocios.cat_de(str(o["tipo"])) == cat:
			r.append(o)
	return r


# "" si puedes comprar esa cosa; si no, el motivo.
static func motivo_no_compra(tipo: String) -> String:
	var cat: String = DatosNegocios.cat_de(tipo)
	if not permite(cat, "comprar"):
		return "Necesitas la licencia: %s" % licencias_para(cat, "comprar")
	if estado()["activos"].size() >= capacidad():
		return "Cartera llena (%d). Vende algo o amplía con la Oficina grande." % capacidad()
	return ""


static func oferta(id: int) -> Variant:
	for o in estado()["mercado"]:
		if int(o["id"]) == id:
			return o
	return null


static func comprar_oferta(id: int, precio: int) -> String:
	var o = oferta(id)
	if o == null:
		return "Esa oferta ya no está."
	var motivo: String = motivo_no_compra(str(o["tipo"]))
	if motivo != "":
		return motivo
	var total: int = precio_con_impuesto(precio)
	if not Juego.gastar(total):
		return "No te llega: son %d $ con impuestos." % total
	estado()["activos"].append(_nuevo_activo(str(o["tipo"]), float(o["estado"]), total))
	estado()["mercado"].erase(o)
	_tocar()
	Juego.ganar_xp(clampi(precio / 300, 5, 80))
	return "Compras %s por %d $ (%d $ con impuestos)." % [DatosNegocios.nombre(str(o["tipo"])), precio, total]


# Lo que pagas de verdad al comprar (el precio más el impuesto de compraventa).
static func precio_con_impuesto(precio: int) -> int:
	return precio + int(round(precio * DatosNegocios.IMPUESTO_COMPRA))


# Lo que cobras de verdad al vender (el precio menos la comisión).
static func precio_neto(precio: int) -> int:
	return precio - int(round(precio * DatosNegocios.COMISION_VENTA))


static func _nuevo_activo(tipo: String, est: float, compra: int) -> Dictionary:
	return {"uid": _sig_id(), "tipo": tipo, "estado": clampf(est, 0.0, 100.0), "compra": compra,
			"venta": false, "alq_anuncio": false, "alq": {}}


# ------------------------------- Negociación ----------------------------------
# Sirve para todo: ofertas del mercado (modo "comprar": el vendedor baja hasta
# su límite) y clientes (modo "vender": el cliente sube hasta su límite; vale
# para vender y para fijar el alquiler). "t" es la oferta o el cliente: se
# cambia ahí mismo ("cifra" = lo que dice ahora la otra parte, "limite" = hasta
# dónde llega, "paciencia" = cuántas veces más puedes regatear).
# Devuelve {"r": "acepta" | "contra" | "se_va", "precio": int, "texto": String}.

# Hasta dónde llega de verdad: tu reputación y la habilidad de Negociación le
# quitan un poco de dureza.
static func ventaja() -> float:
	var v: float = clampf(float(Juego.reputacion), -50.0, 100.0) / 1500.0
	if Juego.habilidades.has("negociacion"):
		v += 0.05
	return v


static func limite_efectivo(t: Dictionary, modo: String) -> float:
	var lim: float = float(t["limite"])
	return lim * (1.0 - ventaja()) if modo == "comprar" else lim * (1.0 + ventaja())


static func negociar(t: Dictionary, modo: String, propuesta: int) -> Dictionary:
	var cifra: int = int(t["cifra"])
	var lim: float = limite_efectivo(t, modo)
	if modo == "comprar":
		if propuesta >= cifra:
			return {"r": "acepta", "precio": cifra, "texto": "Hecho: %d $." % cifra}
		if float(propuesta) >= lim:
			return {"r": "acepta", "precio": propuesta, "texto": "Aceptado: %d $." % propuesta}
		var resta: int = 1
		var ofensa: bool = float(propuesta) < lim * 0.7
		if ofensa:
			resta = 2
		t["paciencia"] = int(t["paciencia"]) - resta
		if int(t["paciencia"]) <= 0:
			return {"r": "se_va", "precio": 0, "texto": "Se harta y se marcha." if not ofensa else "Se ofende por tu oferta y se marcha."}
		var nueva: int = clampi(int(ceil(float(cifra) - (float(cifra) - lim) * 0.45)), mini(int(ceil(lim)), cifra), cifra)
		t["cifra"] = nueva
		return {"r": "contra", "precio": nueva, "texto": "Contraoferta: %d $." % nueva if not ofensa else "Eso es una ofensa. Lo deja en %d $." % nueva}
	# modo "vender"
	if propuesta <= cifra:
		return {"r": "acepta", "precio": cifra, "texto": "Hecho: %d $." % cifra}
	if float(propuesta) <= lim:
		return {"r": "acepta", "precio": propuesta, "texto": "Aceptado: %d $." % propuesta}
	var resta2: int = 1
	var abuso: bool = float(propuesta) > lim * 1.3
	if abuso:
		resta2 = 2
	t["paciencia"] = int(t["paciencia"]) - resta2
	if int(t["paciencia"]) <= 0:
		return {"r": "se_va", "precio": 0, "texto": "Se harta y se marcha." if not abuso else "Le parece abusivo y se marcha."}
	var nueva2: int = clampi(int(floor(float(cifra) + (lim - float(cifra)) * 0.45)), cifra, maxi(cifra, int(floor(lim))))
	t["cifra"] = nueva2
	return {"r": "contra", "precio": nueva2, "texto": "Contraoferta: %d $." % nueva2 if not abuso else "Eso es muchísimo. Sube hasta %d $." % nueva2}


# Una pista sobre el margen que queda. Con "Negociación" dice hasta dónde llega.
static func pista(t: Dictionary, modo: String) -> String:
	var lim: float = limite_efectivo(t, modo)
	var cifra: float = float(t["cifra"])
	var margen: float = absf(cifra - lim) / maxf(1.0, cifra)
	var s: String
	if margen < 0.04:
		s = "Está casi en su último precio."
	elif margen < 0.12:
		s = "Todavía tiene algo de margen."
	else:
		s = "Hay mucho margen para regatear."
	if Juego.habilidades.has("negociacion"):
		s += " (Su límite ronda los %d $.)" % int(round(lim))
	return s


static func retirar_oferta(id: int) -> void:
	var o = oferta(id)
	if o != null:
		estado()["mercado"].erase(o)
		_tocar()


# ------------------------------- Cartera --------------------------------------

static func poner_venta(uid: int, valor_nuevo: bool) -> String:
	var a = _activo(uid)
	if a == null:
		return ""
	if valor_nuevo and not permite(DatosNegocios.cat_de(str(a["tipo"])), "vender"):
		return "Necesitas la licencia: %s" % licencias_para(DatosNegocios.cat_de(str(a["tipo"])), "vender")
	a["venta"] = valor_nuevo
	_tocar()
	return "Anuncias %s en venta." % DatosNegocios.nombre(str(a["tipo"])) if valor_nuevo else "Quitas el anuncio de venta."


static func poner_alquiler(uid: int, valor_nuevo: bool) -> String:
	var a = _activo(uid)
	if a == null:
		return ""
	if valor_nuevo and not permite(DatosNegocios.cat_de(str(a["tipo"])), "alquilar"):
		return "Necesitas la licencia: %s" % licencias_para(DatosNegocios.cat_de(str(a["tipo"])), "alquilar")
	if valor_nuevo and esta_alquilado(a):
		return "Ya está alquilado."
	a["alq_anuncio"] = valor_nuevo
	_tocar()
	return "Anuncias %s para alquilar." % DatosNegocios.nombre(str(a["tipo"])) if valor_nuevo else "Quitas el anuncio de alquiler."


static func coste_publicidad(a: Dictionary, kind: String) -> int:
	if kind == "venta":
		return maxi(20, valor_activo(a) / 100)
	return maxi(10, 2 * renta_ref(str(a["tipo"]), float(a["estado"])))


static func _lead_de(uid: int, kind: String) -> Variant:
	for l in estado()["leads"]:
		if int(l["uid"]) == uid and str(l["kind"]) == kind:
			return l
	return null


static func _crear_lead(a: Dictionary, kind: String) -> Dictionary:
	var tipo: String = str(a["tipo"])
	var cifra: int
	var limite: int
	var dias: int = 0
	if kind == "venta":
		var v: float = float(valor_activo(a))
		cifra = maxi(1, int(round(v * randf_range(0.78, 0.97))))
		limite = maxi(cifra + 1, int(round(v * randf_range(0.95, 1.15))))
	else:
		var r: float = float(renta_ref(tipo, float(a["estado"])))
		cifra = maxi(1, int(round(r * randf_range(0.75, 0.95))))
		limite = maxi(cifra + 1, int(round(r * randf_range(0.97, 1.25))))
		dias = randi_range(5, 20)
	var l: Dictionary = {"id": _sig_id(), "uid": int(a["uid"]), "kind": kind, "persona": _persona(),
			"cifra": cifra, "limite": limite, "paciencia": 3, "dia": Juego.dia, "dias": dias}
	estado()["leads"].append(l)
	return l


# Paga publicidad y llega un cliente ahora mismo.
static func buscar_cliente(uid: int, kind: String) -> String:
	var a = _activo(uid)
	if a == null:
		return ""
	var cat: String = DatosNegocios.cat_de(str(a["tipo"]))
	if not permite(cat, "vender" if kind == "venta" else "alquilar"):
		return "Necesitas la licencia: %s" % licencias_para(cat, "vender" if kind == "venta" else "alquilar")
	if kind == "alquiler" and esta_alquilado(a):
		return "Ya está alquilado."
	if _lead_de(uid, kind) != null:
		return "Ya hay un cliente esperando: mira la pestaña Clientes."
	var coste: int = coste_publicidad(a, kind)
	if not Juego.gastar(coste):
		return "No te llega para la publicidad (%d $)." % coste
	var l: Dictionary = _crear_lead(a, kind)
	_tocar()
	return "Publicidad (%d $): %s se interesa. Mira la pestaña Clientes." % [coste, str(l["persona"])]


static func coste_reparacion(a: Dictionary) -> int:
	return int(round(DatosNegocios.precio_base(str(a["tipo"])) * (100.0 - float(a["estado"])) / 100.0 * 0.4))


static func reparar(uid: int) -> String:
	var a = _activo(uid)
	if a == null:
		return ""
	var coste: int = coste_reparacion(a)
	if coste <= 0:
		return "No necesita reparación."
	if not Juego.gastar(coste):
		return "No te llega para reparar (%d $)." % coste
	a["estado"] = 100.0
	_tocar()
	return "Reparado por %d $." % coste


# Venta rápida a un chatarrero o liquidador: sin regatear, pero al 68%.
static func liquidar(uid: int) -> String:
	var a = _activo(uid)
	if a == null:
		return ""
	var precio: int = int(round(valor_activo(a) * 0.68))
	return _vender_activo(a, precio, "Liquidas")


static func _vender_activo(a: Dictionary, precio: int, verbo: String) -> String:
	var e: Dictionary = estado()
	var neto: int = precio_neto(precio) if verbo != "Liquidas" else precio
	var beneficio: int = neto - int(a["compra"])
	e["activos"].erase(a)
	var restantes: Array = []
	for l in e["leads"]:
		if int(l["uid"]) != int(a["uid"]):
			restantes.append(l)
	e["leads"] = restantes
	Juego.cobrar(neto)
	_tocar()
	Juego.ganar_xp(clampi(precio / 300, 5, 80))
	if beneficio > 0:
		Juego.reputacion = mini(100, Juego.reputacion + 1)
	return "%s %s por %d $, cobras %d $ tras la comisión (%s %d $ en total)." % [verbo, DatosNegocios.nombre(str(a["tipo"])), precio, neto,
			"ganas" if beneficio >= 0 else "pierdes", absi(beneficio)]


static func rescindir(uid: int) -> String:
	var a = _activo(uid)
	if a == null or not esta_alquilado(a):
		return ""
	var quien: String = str(a["alq"]["cliente"])
	a["alq"] = {}
	_tocar()
	return "Rescindes el contrato de %s." % quien


# ------------------------------- Clientes -------------------------------------

static func lead(id: int) -> Variant:
	for l in estado()["leads"]:
		if int(l["id"]) == id:
			return l
	return null


static func quitar_lead(id: int) -> void:
	var l = lead(id)
	if l != null:
		estado()["leads"].erase(l)
		_tocar()


static func texto_lead(l: Dictionary) -> String:
	var a = _activo(int(l["uid"]))
	var nombre: String = DatosNegocios.nombre(str(a["tipo"])) if a != null else "?"
	if str(l["kind"]) == "venta":
		return "%s quiere COMPRAR tu %s." % [str(l["persona"]), nombre]
	return "%s quiere ALQUILAR tu %s por %d días." % [str(l["persona"]), nombre, int(l["dias"])]


static func aceptar_lead(id: int, precio: int) -> String:
	var l = lead(id)
	if l == null:
		return "Ese cliente ya no está."
	var a = _activo(int(l["uid"]))
	if a == null:
		quitar_lead(id)
		return "Eso ya no es tuyo."
	if str(l["kind"]) == "venta":
		return _vender_activo(a, precio, "Vendes")
	if esta_alquilado(a):
		quitar_lead(id)
		return "Ya está alquilado."
	a["alq"] = {"cliente": str(l["persona"]), "renta": precio, "dias": int(l["dias"]), "moroso": 0}
	a["alq_anuncio"] = false
	estado()["leads"].erase(l)
	_tocar()
	Juego.ganar_xp(10)
	return "Alquilas %s a %s: %d $ al día durante %d días." % [DatosNegocios.nombre(str(a["tipo"])), str(l["persona"]), precio, int(a["alq"]["dias"])]


# ------------------------------- Vehículos ------------------------------------

# ¿Se puede sacar a la calle para conducirlo? (Solo si tiene vehículo conducible.)
static func es_conducible(a: Dictionary) -> bool:
	var d: Dictionary = DatosNegocios.CATALOGO[str(a["tipo"])]
	return d.has("vehiculo") and Vehiculo.TIPOS.has(str(d["vehiculo"])) and not esta_alquilado(a)


static func sacar_a_calle(uid: int, gestor: Node, punto: Vector3, giro: float) -> String:
	var a = _activo(uid)
	if a == null or gestor == null or not es_conducible(a):
		return "No se puede sacar."
	var d: Dictionary = DatosNegocios.CATALOGO[str(a["tipo"])]
	var id_v: String = str(gestor.call("entregar", str(d["vehiculo"]), punto, giro))
	if Juego.vehiculos.has(id_v):
		Juego.vehiculos[id_v]["salud"] = float(a["estado"])
	var e: Dictionary = estado()
	e["activos"].erase(a)
	var restantes: Array = []
	for l in e["leads"]:
		if int(l["uid"]) != uid:
			restantes.append(l)
	e["leads"] = restantes
	_tocar()
	Juego.cambio.emit()
	return "Sacas %s a la plaza de entrega. Ya lo puedes conducir." % DatosNegocios.nombre(str(a["tipo"]))


# Aporta al negocio un vehículo tuyo (comprado o robado) para venderlo o alquilarlo.
static func aportar_vehiculo(arbol: SceneTree, id_v: String) -> String:
	if not Juego.vehiculos.has(id_v):
		return "Ese vehículo no es tuyo."
	var tipo_v: String = str(Juego.vehiculos[id_v]["tipo"])
	var tipo: String = DatosNegocios.catalogo_de_vehiculo(tipo_v)
	if tipo == "":
		return "Ese vehículo no se puede tratar en el negocio."
	var motivo: String = motivo_no_compra(tipo)
	if motivo != "":
		return motivo
	for nodo in arbol.get_nodes_in_group("vehiculos"):
		if nodo is Vehiculo and (nodo as Vehiculo).id == id_v and (nodo as Vehiculo).conductor != null:
			return "Primero baja del vehículo."
	var salud: float = float(Juego.vehiculos[id_v].get("salud", 100.0))
	Juego.vehiculos.erase(id_v)
	arbol.call_group("gestor_vehiculos", "sincronizar")
	estado()["activos"].append(_nuevo_activo(tipo, salud, 0))
	_tocar()
	Juego.cambio.emit()
	return "Aportas %s a tu cartera de negocio." % DatosNegocios.nombre(tipo)


# ------------------------------- Paso de los días -----------------------------

static func ponerse_al_dia() -> void:
	var e: Dictionary = estado()
	var hoy: int = Juego.dia
	var ultimo: int = int(e["ultimo_dia"])
	if ultimo > hoy:   # Se retrasó el día (panel de admin).
		e["ultimo_dia"] = hoy
		return
	var pendientes: int = mini(hoy - ultimo, MAX_DIAS_ATRASADOS)
	var resumen: Dictionary = {"cobro": 0, "moras": 0, "averias": 0, "gastos": 0}
	for i in pendientes:
		_procesar_dia(resumen)
	e["ultimo_dia"] = hoy
	if pendientes > 0 or e["mercado"].is_empty():
		refrescar_mercado()
	if int(resumen["cobro"]) > 0 or int(resumen["gastos"]) > 0:
		Juego.nuevo_aviso("Negocios: cobras %d $ de alquileres y pagas %d $ de gastos." % [int(resumen["cobro"]), int(resumen["gastos"])])
	_tocar()


static func _procesar_dia(resumen: Dictionary) -> void:
	var e: Dictionary = estado()
	var perdidos: Array = []
	for a in e["activos"]:
		var tipo: String = str(a["tipo"])
		var cat: String = DatosNegocios.cat_de(tipo)
		var nombre: String = DatosNegocios.nombre(tipo)
		if esta_alquilado(a):
			var al: Dictionary = a["alq"]
			a["estado"] = maxf(0.0, float(a["estado"]) - float(DatosNegocios.CATEGORIAS[cat]["desgaste"]))
			if randf() < float(RIESGO_ROBO.get(cat, 0.0)):
				perdidos.append(a)
				Juego.nuevo_aviso("¡%s no ha devuelto tu %s! Lo das por perdido." % [str(al["cliente"]), nombre])
				continue
			if randf() < PROB_MORA:
				al["moroso"] = int(al["moroso"]) + 1
				resumen["moras"] = int(resumen["moras"]) + 1
				if int(al["moroso"]) >= 3:
					Juego.nuevo_aviso("%s se marcha de tu %s sin pagar tres días." % [str(al["cliente"]), nombre])
					a["alq"] = {}
					continue
			else:
				al["moroso"] = 0
				var pago: int = int(round(float(al["renta"]) * (0.7 + 0.3 * float(a["estado"]) / 100.0)))
				Juego.dinero += pago
				e["ingresos"] = int(e["ingresos"]) + pago
				resumen["cobro"] = int(resumen["cobro"]) + pago
			if randf() < PROB_AVERIA:
				a["estado"] = maxf(0.0, float(a["estado"]) - 15.0)
				resumen["averias"] = int(resumen["averias"]) + 1
				Juego.nuevo_aviso("Avería en tu %s (estado %d %%). Repáralo desde Cartera." % [nombre, int(a["estado"])])
			al["dias"] = int(al["dias"]) - 1
			if int(al["dias"]) <= 0:
				Juego.nuevo_aviso("Termina el contrato de %s con tu %s." % [str(al["cliente"]), nombre])
				a["alq"] = {}
		else:
			if bool(a["venta"]) and _lead_de(int(a["uid"]), "venta") == null and randf() < PROB_CLIENTE:
				var l: Dictionary = _crear_lead(a, "venta")
				Juego.nuevo_aviso("Negocios: %s ofrece %d $ por tu %s." % [str(l["persona"]), int(l["cifra"]), nombre])
			if bool(a["alq_anuncio"]) and _lead_de(int(a["uid"]), "alquiler") == null and randf() < PROB_CLIENTE:
				var l2: Dictionary = _crear_lead(a, "alquiler")
				Juego.nuevo_aviso("Negocios: %s quiere alquilar tu %s por %d $ al día." % [str(l2["persona"]), nombre, int(l2["cifra"])])
	for a in perdidos:
		e["activos"].erase(a)
	# Gastos fijos del día: si no te llega el dinero, lo que no pagas se deteriora.
	var gastos: int = gasto_diario()
	if gastos > 0:
		if Juego.dinero >= gastos:
			Juego.dinero -= gastos
			resumen["gastos"] = int(resumen["gastos"]) + gastos
		else:
			resumen["gastos"] = int(resumen["gastos"]) + Juego.dinero
			Juego.dinero = 0
			for a in e["activos"]:
				a["estado"] = maxf(0.0, float(a["estado"]) - 3.0)
			Juego.nuevo_aviso("No puedes pagar los gastos de tus negocios: tus propiedades y vehículos se deterioran.")
	# Los clientes que esperan demasiado se van.
	var vigentes: Array = []
	for l in e["leads"]:
		if Juego.dia - int(l["dia"]) < DIAS_CLIENTE and _activo(int(l["uid"]), e) != null:
			vigentes.append(l)
	e["leads"] = vigentes
	Juego.cambio.emit()
