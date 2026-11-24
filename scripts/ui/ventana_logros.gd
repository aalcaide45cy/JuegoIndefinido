# ventana_logros.gd
# -----------------------------------------------------------------------------
# La lista de logros (tecla L, o desde los menús de inicio y pausa): resumen con
# barra de progreso, pestañas por tipo (Todos, Conseguidos, Pendientes), buscador
# y filtro por categoría. Cada logro es una tarjeta con su progreso.
# -----------------------------------------------------------------------------
class_name VentanaLogros
extends Ventana

const Datos = preload("res://scripts/datos/logros.gd")

const CATEGORIA_DE_TIPO: Dictionary = {
	"dia": "Supervivencia", "dinero": "Dinero", "nivel": "Progreso", "habilidades": "Progreso", "reputacion": "Progreso",
	"recetas": "Alquimia", "viviendas": "Propiedades", "propiedades": "Propiedades", "granja": "Propiedades",
	"vehiculos": "Propiedades", "personal": "Negocios", "licencias": "Negocios",
}

var _pestanas: UI.Pestanas
var _categorias: UI.Filtros
var _lista: VBoxContainer
var _vacio: Label
var _texto: String = ""
var _desplazable: ScrollContainer


func construir() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pistas_extra = [["pestanas", "Todos / Conseguidos / Pendientes"]]
	var cuerpo: VBoxContainer = marco("Logros", "%d de %d conseguidos" % [Logros.conseguidos.size(), Logros.total()], Vector2(860, 650))
	cuerpo.add_child(UI.barra(Logros.conseguidos.size(), Logros.total(), Tema.ACENTO, 12))
	_pestanas = UI.Pestanas.new()
	cuerpo.add_child(_pestanas)
	for nombre in ["Todos", "Conseguidos", "Pendientes"]:
		_pestanas.anadir(nombre, Control.new())
	_pestanas.cambiada.connect(func(_i: int) -> void: _rellenar())
	_pestanas.hueco_extra().add_child(UI.buscador("Buscar logro…", func(t: String) -> void:
		_texto = t
		_rellenar()))
	_categorias = UI.Filtros.new()
	_categorias.anadir("todas", "Todas las categorías")
	var vistas: Dictionary = {}
	for id in Datos.LISTA:
		var c: String = _categoria(id)
		if not vistas.has(c):
			vistas[c] = true
			_categorias.anadir(c, c)
	_categorias.cambiado.connect(func(_c: String) -> void: _rellenar())
	# Los filtros y la lista van debajo de la barra de pestañas, fuera de la pila de pestañas.
	_pestanas.solo_barra()
	cuerpo.add_child(_categorias)
	_desplazable = ScrollContainer.new()
	_desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_desplazable.follow_focus = true
	cuerpo.add_child(_desplazable)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	_desplazable.add_child(_lista)
	_vacio = UI.nota("No hay logros que encajen con eso.")
	cuerpo.add_child(_vacio)
	_rellenar()


func _categoria(id: String) -> String:
	return str(CATEGORIA_DE_TIPO.get(str(Datos.LISTA[id].get("tipo", "")), "Otros"))


func _rellenar() -> void:
	for h in _lista.get_children():
		_lista.remove_child(h)
		h.queue_free()
	# Primero los conseguidos, luego los que faltan.
	var ids: Array = Datos.LISTA.keys()
	ids.sort_custom(func(a, b): return int(Logros.tiene(a)) > int(Logros.tiene(b)))
	var n: int = 0
	for id in ids:
		var d: Dictionary = Datos.LISTA[id]
		var tengo: bool = Logros.tiene(id)
		if _pestanas.actual == 1 and not tengo:
			continue
		if _pestanas.actual == 2 and tengo:
			continue
		if _categorias.clave != "todas" and _categoria(id) != _categorias.clave:
			continue
		if _texto != "" and not (str(d["nombre"]) + " " + str(d["desc"])).to_lower().contains(_texto):
			continue
		_lista.add_child(_tarjeta(id, d, tengo))
		n += 1
	_vacio.visible = n == 0


func _tarjeta(id: String, d: Dictionary, tengo: bool) -> Control:
	var t: PanelContainer = UI.tarjeta(tengo)
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	t.add_child(fila)
	var medalla: TextureRect = TextureRect.new()
	medalla.texture = Tema.icono("medal1" if tengo else "locked")
	medalla.custom_minimum_size = Vector2(34, 34)
	medalla.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medalla.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	medalla.modulate = Tema.ACENTO if tengo else Tema.TEXTO_TENUE
	medalla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(medalla)
	var textos: VBoxContainer = VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 3)
	fila.add_child(textos)
	var nombre: Label = UI.etiqueta(str(d["nombre"]), "", Tema.TEXTO if tengo else Tema.TEXTO_SUAVE, 18)
	nombre.add_theme_font_override("font", Tema.fuente("semibold"))
	textos.add_child(nombre)
	textos.add_child(UI.nota(str(d["desc"])))
	var lado: VBoxContainer = VBoxContainer.new()
	lado.custom_minimum_size.x = 170
	lado.add_theme_constant_override("separation", 4)
	fila.add_child(lado)
	if tengo:
		var fecha: String = str(Logros.conseguidos.get(id, "")).replace("T", " ")
		lado.add_child(UI.insignia("CONSEGUIDO", Tema.ACENTO))
		if fecha != "":
			lado.add_child(UI.etiqueta(fecha.substr(0, 16), "Nota"))
	else:
		var valor: int = int(d.get("valor", 0))
		if d.has("tipo") and valor > 0:
			var actual: int = mini(Logros.cuenta(str(d["tipo"])), valor)
			lado.add_child(UI.etiqueta("%s / %s" % [UI.numero(actual), UI.numero(valor)], "Subtitulo"))
			lado.add_child(UI.barra(actual, valor, Tema.BRUMA, 8))
		else:
			lado.add_child(UI.insignia("PENDIENTE", Tema.TEXTO_TENUE))
	return t
