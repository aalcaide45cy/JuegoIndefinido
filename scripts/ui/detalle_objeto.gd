# detalle_objeto.gd
# -----------------------------------------------------------------------------
# Ficha de un objeto: icono grande, nombre, tipo, descripción y datos útiles
# (precio, venta, daño, cura, nivel y habilidad que pide...). Las ventanas con
# casillas (inventario, tiendas, estantería) la tienen a un lado y la rellenan
# con mostrar() al pasar el ratón o el mando por encima de un objeto.
# -----------------------------------------------------------------------------
class_name DetalleObjeto
extends PanelContainer

const DatosObjetos = preload("res://scripts/datos/objetos.gd")
const DatosHabilidades = preload("res://scripts/datos/habilidades.gd")
const Economia = preload("res://scripts/datos/economia.gd")

var _caja: VBoxContainer


func _init(ancho: float = 300.0) -> void:
	theme_type_variation = "PanelHondo"
	custom_minimum_size = Vector2(ancho, 120)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Con scroll por si la ficha es larga y la ventana pequeña.
	var desplazable: ScrollContainer = ScrollContainer.new()
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(desplazable)
	_caja = VBoxContainer.new()
	_caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_caja.add_theme_constant_override("separation", 8)
	desplazable.add_child(_caja)
	mostrar("")


# id vacío = "elige un objeto". "cantidad" y "casilla" (el diccionario de la casilla, con agua y balas) son opcionales.
func mostrar(id: String, cantidad: int = 0, casilla: Dictionary = {}) -> void:
	for h in _caja.get_children():
		_caja.remove_child(h)
		h.queue_free()
	if id == "" or not DatosObjetos.existe(id):
		var vacio: Label = UI.nota("Pasa el ratón (o el mando) por un objeto para ver su ficha.")
		vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vacio.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vacio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_caja.add_child(vacio)
		return
	var d: Dictionary = DatosObjetos.datos(id)
	var cabecera: HBoxContainer = HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 12)
	_caja.add_child(cabecera)
	var icono: IconoGrande = IconoGrande.new()
	icono.id = id
	cabecera.add_child(icono)
	var titulos: VBoxContainer = VBoxContainer.new()
	titulos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulos.add_theme_constant_override("separation", 4)
	cabecera.add_child(titulos)
	var nombre: Label = UI.etiqueta(str(d["nombre"]), "Titulo", Tema.TEXTO, 21)
	nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulos.add_child(nombre)
	var tipos: HBoxContainer = HBoxContainer.new()
	tipos.add_theme_constant_override("separation", 6)
	titulos.add_child(tipos)
	tipos.add_child(UI.insignia(str(Ventanas.CATEGORIAS.get(d["tipo"], d["tipo"])), Tema.AZUL))
	if d["tipo"] in ["pocion", "paquete", "hierba", "arma_fuego", "explosivo"]:
		tipos.add_child(UI.insignia("ilegal", Tema.PELIGRO))
	if cantidad > 0:
		titulos.add_child(UI.etiqueta("Tienes %d" % cantidad, "Subtitulo"))
	_caja.add_child(UI.parrafo(str(d["descripcion"]), Tema.TEXTO_SUAVE, 15))
	_caja.add_child(UI.separador())
	var filas: GridContainer = GridContainer.new()
	filas.columns = 2
	filas.add_theme_constant_override("h_separation", 14)
	filas.add_theme_constant_override("v_separation", 5)
	_caja.add_child(filas)
	if int(d["precio"]) > 0:
		_dato(filas, "Precio", UI.dinero(int(d["precio"])), Tema.DINERO)
		var factor: float = Economia.VENTA_COSECHA if d["tipo"] == "cosecha" else Economia.VENTA_TIENDA
		_dato(filas, "Se vende por", UI.dinero(maxi(1, int(int(d["precio"]) * factor))), Tema.DINERO)
	if d.has("dano"):
		_dato(filas, "Daño", str(d["dano"]))
	if d.has("cargador"):
		var texto: String = "%d balas" % int(d["cargador"])
		if casilla.has("balas"):
			texto = "%d / %d" % [int(casilla["balas"]), int(d["cargador"])]
		_dato(filas, "Cargador", texto)
		if d.has("municion") and DatosObjetos.existe(str(d["municion"])):
			_dato(filas, "Munición", DatosObjetos.nombre(str(d["municion"])))
	if d.has("cura"):
		_dato(filas, "Cura", "+%d vida" % int(d["cura"]), Tema.BRUMA)
	if d.has("agua_max"):
		var agua: String = "%d / %d" % [int(casilla.get("agua", 0)), int(d["agua_max"])] if casilla.has("agua") else str(d["agua_max"])
		_dato(filas, "Agua", agua, Tema.AZUL)
	if d.has("quita"):
		_dato(filas, "Quita", ", ".join(PackedStringArray(d["quita"])))
	if int(d.get("nivel", 1)) > 1 and str(d.get("tienda", "")) != "":
		var ok: bool = Juego.nivel >= int(d["nivel"])
		_dato(filas, "Nivel necesario", str(d["nivel"]), Tema.BRUMA if ok else Tema.PELIGRO)
	if str(d.get("habilidad", "")) != "":
		var tiene: bool = Juego.habilidades.has(d["habilidad"])
		_dato(filas, "Habilidad", DatosHabilidades.nombre(d["habilidad"]), Tema.BRUMA if tiene else Tema.PELIGRO)
	_dato(filas, "Se apila hasta", str(DatosObjetos.pila(id)))


func _dato(filas: GridContainer, nombre: String, valor: String, color: Color = Tema.TEXTO) -> void:
	filas.add_child(UI.etiqueta(nombre, "Subtitulo", null, 14))
	var v: Label = UI.etiqueta(valor, "", color, 15)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	filas.add_child(v)


# El icono del objeto en un cuadrado grande.
class IconoGrande extends Control:
	var id: String = ""

	func _ready() -> void:
		custom_minimum_size = Vector2(84, 84)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_style_box(Tema.caja(Color(0.05, 0.058, 0.07), Tema.BORDE, 1, 10, 0, 0), Rect2(Vector2.ZERO, size))
		if id != "":
			Iconos.dibujar(self, Rect2(Vector2.ZERO, size).grow(-6), id)
