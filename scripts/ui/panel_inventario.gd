# panel_inventario.gd
# -----------------------------------------------------------------------------
# La mochila (o la estantería) como panel reutilizable: filtros por grupo de objeto,
# buscador, la rejilla de casillas y, si se pide, la barra rápida de debajo.
# Los objetos que no encajan con el filtro se ven apagados (no desaparecen, para
# que las posiciones no cambien al arrastrar). Emite "elegido" al pasar por una casilla.
# -----------------------------------------------------------------------------
class_name PanelInventario
extends VBoxContainer

signal elegido(casilla: CasillaUI)

const DatosObjetos = preload("res://scripts/datos/objetos.gd")

# Grupo de cada tipo de objeto (para los filtros).
const GRUPOS: Dictionary = {
	"semilla": "cultivo", "material": "cultivo", "cosecha": "cultivo", "animal": "cultivo",
	"hierba": "magia", "pocion": "magia", "aditivo": "magia",
	"consumible": "comida", "arma_cc": "armas", "arma_fuego": "armas", "municion": "armas",
	"explosivo": "armas", "herramienta": "herramientas", "mueble": "casa", "paquete": "casa",
}
const NOMBRES_GRUPO: Dictionary = {
	"todo": "Todo", "cultivo": "Cultivo", "magia": "Hierbas y pociones", "comida": "Comida y medicina",
	"armas": "Armas y munición", "herramientas": "Herramientas", "casa": "Casa y paquetes", "otros": "Otros",
}

var lista: Array
var _filtros: UI.Filtros = null
var _buscar: LineEdit = null
var _casillas: Array[CasillaUI] = []
var _contador: Label
var _texto: String = ""


# Crea el panel. "al_enviar": qué hace Mayús + clic / X del mando. "barra": añade la barra rápida abajo.
func _init(lista_casillas: Array, desde: int, hasta: int, columnas: int, tam: float,
		al_enviar: Callable, con_filtros: bool = true, con_barra: bool = false, titulo_lista: String = "Mochila") -> void:
	lista = lista_casillas
	add_theme_constant_override("separation", 8)
	if con_filtros:
		var fila: HBoxContainer = HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		add_child(fila)
		_buscar = UI.buscador("Buscar en %s…" % titulo_lista.to_lower(), _al_buscar)
		fila.add_child(_buscar)
		_filtros = UI.Filtros.new()
		_filtros.anadir("todo", "Todo")
		for g in ["cultivo", "magia", "comida", "armas", "herramientas", "casa", "otros"]:
			_filtros.anadir(g, str(NOMBRES_GRUPO[g]))
		_filtros.cambiado.connect(func(_c: String) -> void: _aplicar())
		add_child(_filtros)
	var cab: HBoxContainer = HBoxContainer.new()
	cab.add_theme_constant_override("separation", 8)
	cab.add_child(UI.seccion(titulo_lista))
	cab.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contador = UI.etiqueta("", "Nota")
	cab.add_child(_contador)
	add_child(cab)
	var grid: GridContainer = GridContainer.new()
	grid.columns = columnas
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	add_child(grid)
	for i in range(desde, hasta):
		var c: CasillaUI = CasillaUI.new(lista, i, tam)
		if al_enviar.is_valid():
			c.envio_rapido.connect(al_enviar)
		c.elegida.connect(func(x: CasillaUI) -> void: elegido.emit(x))
		grid.add_child(c)
		_casillas.append(c)
	if con_barra:
		if tam >= 44.0:
			add_child(UI.seccion("Barra rápida (teclas 1-9)"))
		var barra: GridContainer = GridContainer.new()
		barra.columns = Juego.TAM_BARRA
		barra.add_theme_constant_override("h_separation", 5)
		add_child(barra)
		for i in Juego.TAM_BARRA:
			var c: CasillaUI = CasillaUI.new(Juego.inventario, i, tam)
			c.numero = str(i + 1)
			if al_enviar.is_valid():
				c.envio_rapido.connect(al_enviar)
			c.elegida.connect(func(x: CasillaUI) -> void: elegido.emit(x))
			barra.add_child(c)
	Juego.cambio.connect(_aplicar)
	_aplicar()


func _exit_tree() -> void:
	if Juego.cambio.is_connected(_aplicar):
		Juego.cambio.disconnect(_aplicar)


func _al_buscar(texto: String) -> void:
	_texto = texto
	_aplicar()


# El grupo de un objeto para los filtros.
static func grupo_de(id: String) -> String:
	return str(GRUPOS.get(str(DatosObjetos.datos(id)["tipo"]), "otros"))


# Atenúa las casillas que no encajan con el filtro y el buscador, y cuenta las ocupadas.
func _aplicar() -> void:
	var grupo: String = _filtros.clave if _filtros != null else "todo"
	var ocupadas: int = 0
	var coinciden: int = 0
	for c in _casillas:
		var it = lista[c.indice]
		var encaja: bool = true
		if it != null:
			ocupadas += 1
			var id: String = str(it["id"])
			if grupo != "todo" and grupo_de(id) != grupo:
				encaja = false
			if encaja and _texto != "" and not DatosObjetos.nombre(id).to_lower().contains(_texto):
				encaja = false
			if encaja:
				coinciden += 1
		else:
			encaja = grupo == "todo" and _texto == ""
		var cambio: bool = c.atenuada != (not encaja)
		c.atenuada = not encaja
		if cambio:
			c.queue_redraw()
	if _contador != null:
		var filtrado: bool = grupo != "todo" or _texto != ""
		_contador.text = ("%d coinciden · " % coinciden if filtrado else "") + "%d / %d casillas" % [ocupadas, _casillas.size()]
