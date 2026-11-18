# panel_negocios.gd
# -----------------------------------------------------------------------------
# La pantalla de gestión de tus negocios. Se usa en dos sitios:
#   - dentro del móvil (pestaña Negocios), en modo "compacto" (pantalla estrecha);
#   - dentro de una ventana grande al hablar con la inmobiliaria o el
#     concesionario (ventana_negocios.gd).
# Tiene cinco pantallas: Resumen, Mercado, Cartera, Clientes y Licencias, y una
# sexta, "trato", donde se regatea el precio con un vendedor o un cliente.
# La lógica está en scripts/negocios.gd; aquí solo se dibuja y se llama a ella.
# SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name PanelNegocios
extends VBoxContainer

const DatosNegocios = preload("res://scripts/datos/negocios.gd")
const ACENTO: Color = Color(0.35, 0.8, 1.0)
const AVISO: Color = Color(1.0, 0.8, 0.4)
const MAL: Color = Color(1.0, 0.45, 0.4)
const BIEN: Color = Color(0.6, 1.0, 0.7)
const GRIS: Color = Color(0.7, 0.75, 0.8)

var ancho: float = 700.0          # Ancho de los textos (se ajusta al sitio donde está).
var compacto: bool = false        # true en el móvil.
var cat_inicial: String = ""      # Si no está vacío, empieza en el Mercado de esa categoría.
var punto = null                  # Vector3: plaza de entrega de vehículos (solo en el concesionario).
var giro: float = 0.0

var _pantalla: String = "resumen"
var _cat: String = "piso"
var _trato: Dictionary = {}       # {modo, origen, id, propuesta, resultado}
var _version: int = -1
var _ultimo_texto: String = ""
var _info: Label
var _ultimo: Label
var _contenido: VBoxContainer


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	Negocios.estado()
	if cat_inicial != "" and DatosNegocios.CATEGORIAS.has(cat_inicial):
		_cat = cat_inicial
		_pantalla = "mercado"
	_info = Hud.crear_label(15 if compacto else 17, Color(0.85, 0.92, 1.0))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.x = ancho
	add_child(_info)
	var nav: GridContainer = GridContainer.new()
	nav.columns = 3 if compacto else 6
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for par in [["resumen", "Resumen"], ["mercado", "Mercado"], ["cartera", "Cartera"], ["clientes", "Clientes"], ["licencias", "Licencias"], ["lavado", "Lavado"]]:
		var b: Button = Hud.crear_boton(par[1], _ir.bind(par[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(b)
	add_child(nav)
	_ultimo = Hud.crear_label(15, AVISO)
	_ultimo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ultimo.custom_minimum_size.x = ancho
	add_child(_ultimo)
	_contenido = VBoxContainer.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.add_theme_constant_override("separation", 8)
	add_child(_contenido)
	_pintar()


func _process(_delta: float) -> void:
	var e: Dictionary = Negocios.estado()
	_info.text = ("Negro %d $  ·  " % Juego.dinero_negro if Juego.dinero_negro > 0 else "") + "%d $  ·  Cartera %d/%d  ·  +%d / -%d $ al día" % [Juego.dinero, e["activos"].size(), Negocios.capacidad(),
			Negocios.ingreso_diario(), Negocios.gasto_diario()]
	# Si cambia algo por su cuenta (pasa un día, llega un cliente) se redibuja,
	# salvo en medio de un regateo para no cortarlo.
	if _pantalla != "trato" and int(e["version"]) != _version:
		_pintar()


# ------------------------------ Ayudas de dibujo ------------------------------

func _tarjeta(color: Color = ACENTO) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	var est: StyleBoxFlat = StyleBoxFlat.new()
	est.bg_color = Color(0.1, 0.13, 0.19)
	est.border_color = color
	est.border_width_left = 5
	est.set_corner_radius_all(14)
	est.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", est)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.add_child(panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	return v


func _txt(v: Container, texto: String, tam: int = 15, color: Color = Color(0.9, 0.92, 0.95)) -> Label:
	var l: Label = Hud.crear_label(tam, color)
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = ancho - 40.0
	v.add_child(l)
	return l


func _fila(v: Container) -> HFlowContainer:
	var f: HFlowContainer = HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 4)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(f)
	return f


func _boton(f: Container, texto: String, accion: Callable, activo: bool = true) -> Button:
	var b: Button = Hud.crear_boton(texto, accion)
	b.disabled = not activo
	f.add_child(b)
	return b


func _ir(pantalla: String) -> void:
	_pantalla = pantalla
	_trato = {}
	_pintar()


func _ir_cat(cat: String) -> void:
	_cat = cat
	_pintar()


# Muestra el resultado de una acción (arriba y como aviso) y redibuja.
func _hecho(texto: String) -> void:
	_ultimo_texto = texto
	if texto != "":
		Juego.avisar(texto)
	_pintar()


func _pintar() -> void:
	for h in _contenido.get_children():
		h.queue_free()
	_version = int(Negocios.estado()["version"])
	_ultimo.text = _ultimo_texto
	match _pantalla:
		"resumen": _pintar_resumen()
		"mercado": _pintar_mercado()
		"cartera": _pintar_cartera()
		"clientes": _pintar_clientes()
		"licencias": _pintar_licencias()
		"lavado": _pintar_lavado()
		"trato": _pintar_trato()


func _nombre_cat(cat: String) -> String:
	return str(DatosNegocios.CATEGORIAS[cat]["nombre"])


func _color_cat(tipo: String) -> Color:
	var cat: String = DatosNegocios.cat_de(tipo)
	return DatosNegocios.CATEGORIAS[cat]["color"] if DatosNegocios.CATEGORIAS.has(cat) else ACENTO


# --------------------------------- Resumen ------------------------------------

func _pintar_resumen() -> void:
	var e: Dictionary = Negocios.estado()
	var v: VBoxContainer = _tarjeta()
	_txt(v, "Tus negocios", 18, ACENTO)
	_txt(v, "Valor de lo que tienes: %d $" % Negocios.patrimonio())
	_txt(v, "Cobras %d $ al día de alquileres y pagas %d $ al día de gastos (impuestos, seguros y cuotas). Un día del juego dura %d min." % [
			Negocios.ingreso_diario(), Negocios.gasto_diario(), int(Juego.duracion_dia_min)])
	_txt(v, "Comprar lleva un %d %% de impuestos y vender una comisión del %d %%." % [int(DatosNegocios.IMPUESTO_COMPRA * 100.0), int(DatosNegocios.COMISION_VENTA * 100.0)], 14, GRIS)
	_txt(v, "Has cobrado %d $ en total por alquileres." % int(e["ingresos"]))
	var libres: int = 0
	var alquilados: int = 0
	for a in e["activos"]:
		if Negocios.esta_alquilado(a):
			alquilados += 1
		else:
			libres += 1
	_txt(v, "%d alquilados, %d sin alquilar. %d clientes esperando." % [alquilados, libres, e["leads"].size()], 15, GRIS)
	var lic: PackedStringArray = []
	for id in e["licencias"]:
		lic.append(str(DatosNegocios.LICENCIAS[id]["nombre"]))
	var v2: VBoxContainer = _tarjeta(AVISO)
	if lic.is_empty():
		_txt(v2, "Para empezar", 17, AVISO)
		_txt(v2, "1. En Licencias compra la de Inmobiliaria o la de Concesionario.\n2. En Mercado busca una oferta y regatea el precio.\n3. En Cartera anuncia lo que compres para venderlo o alquilarlo.\n4. En Clientes negocia con quien se interese. Los alquileres se cobran solos cada día.")
	else:
		_txt(v2, "Licencias: %s." % ", ".join(lic), 15, BIEN)
		_txt(v2, "Consejo: compra barato en Mercado (regateando), repara lo que esté estropeado y véndelo o alquílalo a buen precio.", 14, GRIS)
	if Juego.habilidades.has("negociacion"):
		_txt(v2, "Tu habilidad de Negociación te da ventaja al regatear.", 14, BIEN)
	else:
		_txt(v2, "La habilidad de Negociación (academia) te enseña hasta dónde llega cada cliente.", 14, GRIS)


# --------------------------------- Licencias ----------------------------------

func _pintar_licencias() -> void:
	for id in DatosNegocios.LICENCIAS:
		var l: Dictionary = DatosNegocios.LICENCIAS[id]
		var v: VBoxContainer = _tarjeta()
		_txt(v, str(l["nombre"]), 18, ACENTO)
		_txt(v, str(l["desc"]))
		var permite: PackedStringArray = []
		for c in l["cats"]:
			permite.append(_nombre_cat(str(c)))
		var extra: String = "Permite: %s (%s). " % [", ".join(permite), ", ".join(PackedStringArray(l["ops"]))] if not permite.is_empty() else ""
		_txt(v, "%sCapacidad +%d. Nivel %d." % [extra, int(l["capacidad"]), int(l["nivel"])], 14, GRIS)
		if Negocios.tiene_licencia(str(id)):
			_txt(v, "✔ Licencia activa", 15, BIEN)
		else:
			var motivo: String = Negocios.motivo_no_licencia(str(id))
			var f: HFlowContainer = _fila(v)
			_boton(f, "Comprar licencia (%d $)" % int(l["precio"]), _comprar_licencia.bind(str(id)), motivo == "")
			if motivo != "":
				_txt(v, motivo, 14, MAL)


func _comprar_licencia(id: String) -> void:
	_hecho(Negocios.comprar_licencia(id))


# ----------------------------------- Lavado -----------------------------------
# Dinero negro -> limpio a través de tus negocios (mecánica de ficción del juego).

func _pintar_lavado() -> void:
	var v: VBoxContainer = _tarjeta(MAL)
	_txt(v, "Dinero negro: %d $" % Juego.dinero_negro, 18, MAL)
	_txt(v, "Lo que ganas con el trato ilegal es dinero negro. El banco, las casas, los coches, las licencias y los sueldos solo aceptan dinero limpio. Pásalo por un negocio tuyo: cada uno tiene un límite al día y se queda una comisión.", 14, GRIS)
	_txt(v, "Vigilancia fiscal: %d / 100. Si llega a %d, puede haber una inspección: te quitan parte del dinero negro, te multan y la policía te busca. Baja %d puntos al día." % [
			int(Juego.vigilancia_fiscal), int(Blanqueo.Datos.VIGILANCIA_INSPECCION), int(Blanqueo.Datos.VIGILANCIA_BAJA_DIA)], 14,
			MAL if Juego.vigilancia_fiscal >= Blanqueo.Datos.VIGILANCIA_INSPECCION else AVISO)
	_txt(v, "Ahora llevas la sospecha en %d / 100. Llevar mucho dinero negro encima atrae cacheos." % int(Juego.sospecha), 14, GRIS)
	for id in Blanqueo.Datos.FRENTES:
		var f: Dictionary = Blanqueo.Datos.FRENTES[id]
		var l: Dictionary = DatosNegocios.LICENCIAS[id]
		var t: VBoxContainer = _tarjeta()
		_txt(t, str(l["nombre"]), 17, ACENTO)
		_txt(t, "Comisión %d %%  ·  Riesgo x%.1f" % [int(f["comision"] * 100.0), float(f["riesgo"])], 14, GRIS)
		if not Negocios.tiene_licencia(str(id)):
			_txt(t, "Necesitas su licencia (pestaña Licencias).", 14, MAL)
			continue
		var disp: int = Blanqueo.disponible(str(id))
		_txt(t, "Hoy puede mover %d $ más (límite %d $; crece si tienes propiedades o vehículos de su tipo)." % [disp, Blanqueo.limite(str(id))], 14, BIEN if disp > 0 else AVISO)
		var fila: HFlowContainer = _fila(t)
		for cant in [100, 500, 2000]:
			_boton(fila, "Pasar %d $" % cant, _blanquear.bind(str(id), cant), Juego.dinero_negro > 0 and disp > 0)
		_boton(fila, "Todo lo posible", _blanquear.bind(str(id), 1000000000), Juego.dinero_negro > 0 and disp > 0)
	_txt(v, "Has blanqueado %d $ en total." % Blanqueo.total_blanqueado(), 14, GRIS)


func _blanquear(id: String, cantidad: int) -> void:
	_hecho(Blanqueo.blanquear(id, cantidad))


# ---------------------------------- Mercado -----------------------------------

func _pintar_mercado() -> void:
	var v0: VBoxContainer = _tarjeta(AVISO)
	var f0: HFlowContainer = _fila(v0)
	for cat in DatosNegocios.CATEGORIAS:
		var b: Button = _boton(f0, _nombre_cat(str(cat)), _ir_cat.bind(str(cat)), str(cat) != _cat)
		b.tooltip_text = "Ver ofertas de %s" % _nombre_cat(str(cat))
	if not Negocios.permite(_cat, "comprar"):
		_txt(v0, "Puedes mirar, pero para comprar necesitas la licencia: %s." % Negocios.licencias_para(_cat, "comprar"), 14, MAL)
	var ofertas: Array = Negocios.ofertas_de(_cat)
	ofertas.sort_custom(func(a, b) -> bool: return int(a["cifra"]) < int(b["cifra"]))
	if ofertas.is_empty():
		_txt(_tarjeta(), "No hay ofertas ahora. Mañana llegarán nuevas.", 15, GRIS)
	for o in ofertas:
		var tipo: String = str(o["tipo"])
		var v: VBoxContainer = _tarjeta(_color_cat(tipo))
		_txt(v, "%s  ·  estado %d %%" % [DatosNegocios.nombre(tipo), int(o["estado"])], 17, ACENTO)
		_txt(v, str(DatosNegocios.CATALOGO[tipo]["desc"]), 13, GRIS)
		_txt(v, "Vende: %s. Pide %d $." % [str(o["persona"]), int(o["cifra"])])
		var ref: int = Negocios.valor(tipo, float(o["estado"]))
		var dif: int = ref - int(o["cifra"])
		_txt(v, "Vale en el mercado unos %d $ (%s)." % [ref, "ganga" if dif > ref * 0.05 else "caro" if dif < -ref * 0.1 else "precio normal"], 14,
				BIEN if dif > ref * 0.05 else (MAL if dif < -ref * 0.1 else GRIS))
		if Negocios.permite(_cat, "alquilar"):
			_txt(v, "Alquilado, rendiría unos %d $ al día." % Negocios.renta_ref(tipo, float(o["estado"])), 14, GRIS)
		var motivo: String = Negocios.motivo_no_compra(tipo)
		var f: HFlowContainer = _fila(v)
		_boton(f, "Negociar", _empezar_trato.bind("oferta", int(o["id"])), motivo == "")
		_boton(f, "Comprar a %d $ (+%d%% imp.)" % [int(o["cifra"]), int(DatosNegocios.IMPUESTO_COMPRA * 100.0)], _comprar_directo.bind(int(o["id"]), int(o["cifra"])), motivo == "")
		if motivo != "":
			_txt(v, motivo, 14, MAL)


func _comprar_directo(id: int, precio: int) -> void:
	_hecho(Negocios.comprar_oferta(id, precio))


# ---------------------------------- Cartera -----------------------------------

func _pintar_cartera() -> void:
	var e: Dictionary = Negocios.estado()
	if e["activos"].is_empty():
		_txt(_tarjeta(), "Tu cartera está vacía. Compra algo en el Mercado.", 15, GRIS)
	for a in e["activos"]:
		_tarjeta_activo(a)
	if punto != null:
		_pintar_mis_vehiculos()


func _tarjeta_activo(a: Dictionary) -> void:
	var tipo: String = str(a["tipo"])
	var cat: String = DatosNegocios.cat_de(tipo)
	var uid: int = int(a["uid"])
	var v: VBoxContainer = _tarjeta(_color_cat(tipo))
	_txt(v, DatosNegocios.nombre(tipo), 17, ACENTO)
	_txt(v, "Estado %d %%  ·  vale %d $  ·  compra: %d $" % [int(a["estado"]), Negocios.valor_activo(a), int(a["compra"])], 14)
	if Negocios.esta_alquilado(a):
		var al: Dictionary = a["alq"]
		_txt(v, "Alquilado a %s: %d $/día, quedan %d días%s." % [str(al["cliente"]), int(al["renta"]), int(al["dias"]),
				"  (debe %d días)" % int(al["moroso"]) if int(al["moroso"]) > 0 else ""], 14, BIEN)
	elif bool(a["venta"]) or bool(a["alq_anuncio"]):
		var partes: PackedStringArray = []
		if bool(a["venta"]):
			partes.append("en venta")
		if bool(a["alq_anuncio"]):
			partes.append("en alquiler")
		_txt(v, "Anunciado: %s." % " y ".join(partes), 14, AVISO)
	else:
		_txt(v, "Sin anunciar. Alquiler orientativo: %d $/día." % Negocios.renta_ref(tipo, float(a["estado"])), 14, GRIS)
	var f: HFlowContainer = _fila(v)
	var puede_vender: bool = Negocios.permite(cat, "vender")
	var puede_alquilar: bool = Negocios.permite(cat, "alquilar")
	if puede_vender:
		_boton(f, "Quitar anuncio de venta" if bool(a["venta"]) else "Anunciar venta", _anuncio_venta.bind(uid, not bool(a["venta"])))
		_boton(f, "Buscar comprador (%d $)" % Negocios.coste_publicidad(a, "venta"), _buscar.bind(uid, "venta"))
		_boton(f, "Liquidar (%d $)" % int(round(Negocios.valor_activo(a) * 0.68)), _liquidar.bind(uid))
	if puede_alquilar and not Negocios.esta_alquilado(a):
		_boton(f, "Quitar anuncio de alquiler" if bool(a["alq_anuncio"]) else "Anunciar alquiler", _anuncio_alq.bind(uid, not bool(a["alq_anuncio"])))
		_boton(f, "Buscar inquilino (%d $)" % Negocios.coste_publicidad(a, "alquiler"), _buscar.bind(uid, "alquiler"))
	if Negocios.esta_alquilado(a):
		_boton(f, "Rescindir contrato", _rescindir.bind(uid))
	if float(a["estado"]) < 95.0:
		_boton(f, "Reparar (%d $)" % Negocios.coste_reparacion(a), _reparar.bind(uid))
	if punto != null and Negocios.es_conducible(a):
		_boton(f, "Sacar a la plaza (conducir)", _sacar.bind(uid))
	if not puede_vender:
		_txt(v, "Para venderlo necesitas la licencia: %s." % Negocios.licencias_para(cat, "vender"), 13, MAL)


func _anuncio_venta(uid: int, valor_nuevo: bool) -> void:
	_hecho(Negocios.poner_venta(uid, valor_nuevo))


func _anuncio_alq(uid: int, valor_nuevo: bool) -> void:
	_hecho(Negocios.poner_alquiler(uid, valor_nuevo))


func _buscar(uid: int, kind: String) -> void:
	_hecho(Negocios.buscar_cliente(uid, kind))


func _liquidar(uid: int) -> void:
	_hecho(Negocios.liquidar(uid))


func _rescindir(uid: int) -> void:
	_hecho(Negocios.rescindir(uid))


func _reparar(uid: int) -> void:
	_hecho(Negocios.reparar(uid))


func _sacar(uid: int) -> void:
	var gestor: Node = get_tree().get_first_node_in_group("gestor_vehiculos")
	_hecho(Negocios.sacar_a_calle(uid, gestor, punto, giro))


# Los vehículos tuyos del mundo que se pueden meter en el negocio.
func _pintar_mis_vehiculos() -> void:
	var v: VBoxContainer = _tarjeta(AVISO)
	_txt(v, "Tus vehículos (aportarlos al negocio para venderlos o alquilarlos)", 16, AVISO)
	var hay: bool = false
	for id_v in Juego.vehiculos:
		var d: Dictionary = Juego.vehiculos[id_v]
		var tipo_c: String = DatosNegocios.catalogo_de_vehiculo(str(d["tipo"]))
		if tipo_c == "":
			continue
		hay = true
		var f: HFlowContainer = _fila(v)
		var l: Label = _txt(f, "%s (%d %%)" % [DatosNegocios.nombre(tipo_c), int(d.get("salud", 100.0))], 14)
		l.custom_minimum_size.x = 0.0
		_boton(f, "Aportar", _aportar.bind(str(id_v)))
	if not hay:
		_txt(v, "No tienes vehículos propios.", 14, GRIS)


func _aportar(id_v: String) -> void:
	_hecho(Negocios.aportar_vehiculo(get_tree(), id_v))


# ---------------------------------- Clientes ----------------------------------

func _pintar_clientes() -> void:
	var e: Dictionary = Negocios.estado()
	if e["leads"].is_empty():
		_txt(_tarjeta(), "No hay clientes. Anuncia algo desde Cartera o paga publicidad para que llegue alguien.", 15, GRIS)
	for l in e["leads"]:
		var a = Negocios._activo(int(l["uid"]))
		if a == null:
			continue
		var alquiler: bool = str(l["kind"]) == "alquiler"
		var v: VBoxContainer = _tarjeta(_color_cat(str(a["tipo"])))
		_txt(v, Negocios.texto_lead(l), 16, ACENTO)
		var ref: int = Negocios.renta_ref(str(a["tipo"]), float(a["estado"])) if alquiler else Negocios.valor_activo(a)
		_txt(v, "Ofrece %d $%s  (referencia: %d $%s)" % [int(l["cifra"]), "/día" if alquiler else "", ref, "/día" if alquiler else ""])
		var f: HFlowContainer = _fila(v)
		_boton(f, "Negociar", _empezar_trato.bind("lead", int(l["id"])))
		_boton(f, "Aceptar %d $" % int(l["cifra"]), _aceptar_lead.bind(int(l["id"]), int(l["cifra"])))
		_boton(f, "Rechazar", _rechazar_lead.bind(int(l["id"])))


func _aceptar_lead(id: int, precio: int) -> void:
	_hecho(Negocios.aceptar_lead(id, precio))


func _rechazar_lead(id: int) -> void:
	Negocios.quitar_lead(id)
	_hecho("Rechazas la oferta.")


# ---------------------------------- Regateo -----------------------------------

func _empezar_trato(origen: String, id: int) -> void:
	var t = Negocios.oferta(id) if origen == "oferta" else Negocios.lead(id)
	if t == null:
		_hecho("Ya no está disponible.")
		return
	var modo: String = "comprar" if origen == "oferta" else "vender"
	var cifra: int = int(t["cifra"])
	var propuesta: int = maxi(1, int(round(cifra * 0.9))) if modo == "comprar" else maxi(cifra + 1, int(round(cifra * 1.12)))
	_trato = {"modo": modo, "origen": origen, "id": id, "propuesta": propuesta, "resultado": ""}
	_pantalla = "trato"
	_pintar()


func _referencia():
	if _trato.is_empty():
		return null
	return Negocios.oferta(int(_trato["id"])) if str(_trato["origen"]) == "oferta" else Negocios.lead(int(_trato["id"]))


func _volver_del_trato() -> void:
	_pantalla = "mercado" if str(_trato.get("origen", "oferta")) == "oferta" else "clientes"
	_trato = {}
	_pintar()


func _pintar_trato() -> void:
	var t = _referencia()
	if t == null:
		_hecho("El trato ya no es posible.")
		_volver_del_trato()
		return
	var modo: String = str(_trato["modo"])
	var es_oferta: bool = str(_trato["origen"]) == "oferta"
	var alquiler: bool = not es_oferta and str(t["kind"]) == "alquiler"
	var sufijo: String = " $/día" if alquiler else " $"
	var v: VBoxContainer = _tarjeta(AVISO)
	_txt(v, "Regateando con %s" % str(t["persona"]), 18, AVISO)
	var ref: int
	if es_oferta:
		_txt(v, "%s, estado %d %%." % [DatosNegocios.nombre(str(t["tipo"])), int(t["estado"])])
		ref = Negocios.valor(str(t["tipo"]), float(t["estado"]))
	else:
		_txt(v, Negocios.texto_lead(t))
		var a = Negocios._activo(int(t["uid"]))
		ref = Negocios.renta_ref(str(a["tipo"]), float(a["estado"])) if alquiler else Negocios.valor_activo(a)
	_txt(v, "Referencia del mercado: %d%s." % [ref, sufijo], 14, GRIS)
	_txt(v, "%s %d%s." % ["Pide" if modo == "comprar" else "Ofrece", int(t["cifra"]), sufijo], 20, Color(1, 1, 1))
	_txt(v, Negocios.pista(t, modo), 14, GRIS)
	_txt(v, "Paciencia: %s%s" % ["●".repeat(int(t["paciencia"])), "○".repeat(3 - int(t["paciencia"]))], 15, AVISO)
	if str(_trato["resultado"]) != "":
		_txt(v, str(_trato["resultado"]), 16, Color(1, 0.9, 0.6))
	var v2: VBoxContainer = _tarjeta()
	_txt(v2, "Tu propuesta: %d%s" % [int(_trato["propuesta"]), sufijo], 20, ACENTO)
	var f: HFlowContainer = _fila(v2)
	for pct in [-10, -5, -1, 1, 5, 10]:
		_boton(f, "%+d%%" % pct, _ajustar.bind(pct))
	var f2: HFlowContainer = _fila(v2)
	_boton(f2, "Proponer %d%s" % [int(_trato["propuesta"]), sufijo], _proponer)
	_boton(f2, "Aceptar su precio (%d%s)" % [int(t["cifra"]), sufijo], _aceptar_su_precio)
	_boton(f2, "Marcharme", _volver_del_trato)


func _ajustar(pct: int) -> void:
	var t = _referencia()
	if t == null:
		return
	var paso: int = maxi(1, int(round(absf(float(t["cifra"]) * pct / 100.0))))
	_trato["propuesta"] = maxi(1, int(_trato["propuesta"]) + (paso if pct > 0 else -paso))
	_pintar()


func _proponer() -> void:
	var t = _referencia()
	if t == null:
		_volver_del_trato()
		return
	var r: Dictionary = Negocios.negociar(t, str(_trato["modo"]), int(_trato["propuesta"]))
	match str(r["r"]):
		"acepta":
			_cerrar_trato(int(r["precio"]), str(r["texto"]))
		"contra":
			_trato["resultado"] = str(r["texto"])
			_pintar()
		_:
			if str(_trato["origen"]) == "oferta":
				Negocios.retirar_oferta(int(_trato["id"]))
			else:
				Negocios.quitar_lead(int(_trato["id"]))
			_ultimo_texto = "%s %s" % [str(t["persona"]), str(r["texto"])]
			Juego.avisar(_ultimo_texto)
			_volver_del_trato()


func _aceptar_su_precio() -> void:
	var t = _referencia()
	if t == null:
		_volver_del_trato()
		return
	_cerrar_trato(int(t["cifra"]), "")


func _cerrar_trato(precio: int, texto: String) -> void:
	var origen: String = str(_trato["origen"])
	var id: int = int(_trato["id"])
	var msg: String = Negocios.comprar_oferta(id, precio) if origen == "oferta" else Negocios.aceptar_lead(id, precio)
	_ultimo_texto = (texto + " " + msg).strip_edges()
	Juego.avisar(_ultimo_texto)
	_volver_del_trato()
