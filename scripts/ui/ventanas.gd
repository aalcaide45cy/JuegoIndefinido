# ventanas.gd
# -----------------------------------------------------------------------------
# Las ventanas del juego, cada una como clase interna (todas heredan de Ventana):
#   Ventanas.Inventario  -> TAB. Mochila de 54 casillas + barra rápida de 9.
#   Ventanas.Tienda      -> al hablar con un vendedor: su género por pestañas
#                           a la izquierda y tu inventario a la derecha.
#   Ventanas.Estanteria  -> la estantería de casa junto a tu inventario.
#   Ventanas.Admin       -> F1. Hora, velocidad del tiempo, dinero, vida,
#                           nivel, habilidades y dar objetos para probar.
# -----------------------------------------------------------------------------
class_name Ventanas
extends RefCounted

const DatosObjetos = preload("res://scripts/datos/objetos.gd")
const DatosHabilidades = preload("res://scripts/datos/habilidades.gd")

const CATEGORIAS: Dictionary = {
	"semilla": "Semillas", "material": "Cultivo", "herramienta": "Herramientas",
	"arma_cc": "Cuerpo a cuerpo", "arma_fuego": "Armas de fuego",
	"municion": "Munición", "explosivo": "Explosivos",
	"hierba": "Hierbas", "pocion": "Pociones", "paquete": "Paquetes", "mueble": "Muebles y montaje", "cosecha": "Cosechas", "animal": "Animales", "consumible": "Comida y medicina", "aditivo": "Aditivos del caldero",
}


# Muestra un resumen: dinero, nivel y vida.
static func texto_estado() -> String:
	return "%d $ (negro %d $)    ·    Nivel %d (%d/%d XP)    ·    Vida %d/%d" % [Juego.dinero, Juego.dinero_negro, Juego.nivel,
			Juego.xp, Juego.xp_necesaria(), int(Juego.vida), int(Juego.VIDA_MAX)]


# Las casillas del inventario del jugador: mochila arriba y barra rápida abajo.
# Con Mayúsculas + clic, "al_enviar" decide adónde va la casilla.
static func montar_inventario(v: Ventana, caja: Container, tam: float, al_enviar: Callable) -> void:
	v.subtitulo(caja, "Mochila")
	v.rejilla(caja, Juego.inventario, Juego.TAM_BARRA, Juego.TAM_INVENTARIO, 9, tam, al_enviar)
	v.subtitulo(caja, "Barra rápida (teclas 1-9)")
	v.rejilla(caja, Juego.inventario, 0, Juego.TAM_BARRA, 9, tam, al_enviar, true)


# Un botón grande para los menús de pausa e inicio.
static func boton_grande(texto: String, al_pulsar: Callable) -> Button:
	var boton: Button = Hud.crear_boton(texto, al_pulsar)
	boton.add_theme_font_size_override("font_size", 22)
	boton.custom_minimum_size = Vector2(0, 46)
	return boton


# ==============================================================================
# Menú de pausa (Esc): el juego se para mientras está abierto.
class Pausa extends Ventana:
	var jugador: Node3D = null
	var _aviso: Label

	func construir() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		var caja: VBoxContainer = panel_centrado(Vector2(380, 480))
		var titulo: Label = Hud.crear_label(32, Color(0.6, 0.9, 0.6))
		titulo.text = "Pausa"
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caja.add_child(titulo)
		caja.add_child(Ventanas.boton_grande("Reanudar", cerrar))
		caja.add_child(Ventanas.boton_grande("Guardar (ranura %d)" % Guardado.ranura, _guardar))
		caja.add_child(Ventanas.boton_grande("Partidas…", _partidas))
		caja.add_child(Ventanas.boton_grande("Logros", _logros))
		caja.add_child(Ventanas.boton_grande("Gráficos…", func(): add_child(VentanaGraficos.new())))
		caja.add_child(Ventanas.boton_grande("Salir del juego", _salir))
		_aviso = Hud.crear_label(16, Color(1, 0.92, 0.6))
		_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caja.add_child(_aviso)

	func cerrar() -> void:
		get_tree().paused = false
		super()

	func _guardar() -> void:
		if Guardado.guardar(get_tree(), jugador):
			_aviso.text = "Partida guardada en la ranura %d." % Guardado.ranura
		else:
			_aviso.text = "No se pudo guardar."

	func _partidas() -> void:
		var v: VentanaPartidas = VentanaPartidas.new()
		v.modo = VentanaPartidas.Modo.PAUSA
		v.jugador = jugador
		v.al_elegir = cerrar
		add_child(v)

	func _logros() -> void:
		add_child(VentanaLogros.new())

	func _salir() -> void:
		get_tree().paused = false
		get_tree().quit()


# ==============================================================================
# Menú al arrancar: Continuar (última ranura), Nueva partida, elegir ranura o ver logros.
class Inicio extends Ventana:
	var jugador: Node3D = null

	func construir() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		var caja: VBoxContainer = panel_centrado(Vector2(420, 500))
		var titulo: Label = Hud.crear_label(36, Color(0.6, 0.9, 0.6))
		titulo.text = "Elixir Clandestino"
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caja.add_child(titulo)
		var lema: Label = Hud.crear_label(15, Color(0.75, 0.8, 0.72))
		lema.text = "La magia está prohibida. Tú, no."
		lema.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caja.add_child(lema)
		var ultima: int = Guardado.ultima_ranura()
		var continuar: Button = Ventanas.boton_grande("Continuar (ranura %d)" % ultima if ultima > 0 else "Continuar", _continuar)
		continuar.disabled = ultima == 0
		caja.add_child(continuar)
		caja.add_child(Ventanas.boton_grande("Nueva partida", _nueva))
		caja.add_child(Ventanas.boton_grande("Partidas…", _partidas))
		caja.add_child(Ventanas.boton_grande("Logros", func(): add_child(VentanaLogros.new())))
		caja.add_child(Ventanas.boton_grande("Gráficos…", func(): add_child(VentanaGraficos.new())))
		caja.add_child(Ventanas.boton_grande("Salir", _salir))

	func cerrar() -> void:
		get_tree().paused = false
		super()

	func _continuar() -> void:
		if Guardado.cargar(get_tree(), jugador, Guardado.ultima_ranura()):
			Juego.avisar("Partida cargada.")
			cerrar()

	# Empieza en la primera ranura vacía; si están todas llenas, deja elegir cuál reemplazar.
	func _nueva() -> void:
		var libre: int = Guardado.ranura_libre()
		if libre == 0:
			_partidas()
			return
		Juego.reiniciar()
		Guardado.ranura = libre
		cerrar()

	func _partidas() -> void:
		var v: VentanaPartidas = VentanaPartidas.new()
		v.modo = VentanaPartidas.Modo.INICIO
		v.jugador = jugador
		v.al_elegir = cerrar
		add_child(v)

	func _salir() -> void:
		get_tree().paused = false
		get_tree().quit()


# ==============================================================================
class Inventario extends Ventana:
	var _estado: Label

	func construir() -> void:
		var caja: VBoxContainer = panel_centrado(Vector2(600, 640))
		var fila: HBoxContainer = cabecera(caja, "Inventario")
		fila.add_child(Hud.crear_boton("Ordenar", func() -> void: Juego.ordenar(Juego.inventario, Juego.TAM_BARRA)))
		fila.move_child(fila.get_child(fila.get_child_count() - 1), 2)
		_estado = Hud.crear_label(17, Color(1, 0.92, 0.6))
		caja.add_child(_estado)
		Ventanas.montar_inventario(self, caja, 58.0, _envio)
		var ayuda: Label = Hud.crear_label(13, Color(0.65, 0.65, 0.62))
		ayuda.text = "Arrastra para mover o apilar · Clic derecho: dividir · Mayús + clic: mochila ↔ barra"
		caja.add_child(ayuda)
		Juego.cambio.connect(_refrescar)
		_refrescar()

	func _refrescar() -> void:
		_estado.text = Ventanas.texto_estado()

	func _envio(casilla: CasillaUI) -> void:
		if casilla.indice < Juego.TAM_BARRA:
			Juego.mover_rapido(Juego.inventario, casilla.indice, Juego.inventario, Juego.TAM_BARRA)
		else:
			_a_barra(casilla.indice)

	func _a_barra(i: int) -> void:
		for hueco in Juego.TAM_BARRA:
			if Juego.inventario[hueco] == null:
				Juego.mover(Juego.inventario, i, Juego.inventario, hueco)
				return
		Juego.avisar("La barra rápida está llena.")


# ==============================================================================
class Tienda extends Ventana:
	var nombre_tienda: String = "Tienda"
	var tienda: String = "herbolario"   # Qué vende (campo "tienda" en objetos.gd).

	var _estado: Label
	var _pestanas: TabContainer
	var _listas: Dictionary = {}        # categoría -> VBoxContainer con sus filas

	func construir() -> void:
		var panel: PanelContainer = Hud.crear_panel()
		Hud.centrar(panel, Vector2(1180, 650))
		add_child(panel)
		var raiz: VBoxContainer = VBoxContainer.new()
		raiz.add_theme_constant_override("separation", 10)
		panel.add_child(raiz)
		cabecera(raiz, nombre_tienda)
		_estado = Hud.crear_label(17, Color(1, 0.92, 0.6))
		raiz.add_child(_estado)

		var columnas: HBoxContainer = HBoxContainer.new()
		columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		columnas.add_theme_constant_override("separation", 18)
		raiz.add_child(columnas)

		# Izquierda: lo que vende, por pestañas.
		var izquierda: VBoxContainer = VBoxContainer.new()
		izquierda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columnas.add_child(izquierda)
		subtitulo(izquierda, "Género del vendedor")
		_pestanas = TabContainer.new()
		_pestanas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_pestanas.add_theme_font_size_override("font_size", 15)
		izquierda.add_child(_pestanas)
		for id in DatosObjetos.de_tienda(tienda):
			var categoria: String = CATEGORIAS[DatosObjetos.datos(id)["tipo"]]
			if not _listas.has(categoria):
				var desplazable: ScrollContainer = ScrollContainer.new()
				desplazable.name = categoria
				desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
				_pestanas.add_child(desplazable)
				var lista: VBoxContainer = VBoxContainer.new()
				lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				lista.add_theme_constant_override("separation", 6)
				desplazable.add_child(lista)
				_listas[categoria] = lista

		# Zona para vender arrastrando.
		var venta: ZonaVenta = ZonaVenta.new()
		izquierda.add_child(venta)

		# Derecha: tu inventario.
		var derecha: VBoxContainer = VBoxContainer.new()
		columnas.add_child(derecha)
		Ventanas.montar_inventario(self, derecha, 48.0, _envio)

		Juego.cambio.connect(_refrescar)
		_refrescar()

	func _refrescar() -> void:
		_estado.text = Ventanas.texto_estado()
		for categoria in _listas:
			for hijo in _listas[categoria].get_children():
				hijo.queue_free()
		for id in DatosObjetos.de_tienda(tienda):
			var categoria: String = CATEGORIAS[DatosObjetos.datos(id)["tipo"]]
			_listas[categoria].add_child(_fila_producto(id))

	# Una fila del catálogo: icono, nombre, precio, requisitos y botón de comprar.
	func _fila_producto(id: String) -> Control:
		var datos: Dictionary = DatosObjetos.datos(id)
		var fondo: PanelContainer = PanelContainer.new()
		var estilo: StyleBoxFlat = StyleBoxFlat.new()
		estilo.bg_color = Color(0.12, 0.13, 0.12)
		estilo.set_corner_radius_all(6)
		estilo.corner_detail = 1   # Esquina cortada: estilo low poly
		estilo.set_content_margin_all(6)
		fondo.add_theme_stylebox_override("panel", estilo)
		var fila: HBoxContainer = HBoxContainer.new()
		fila.add_theme_constant_override("separation", 10)
		fondo.add_child(fila)

		var icono: IconoObjeto = IconoObjeto.new()
		icono.id = id
		fila.add_child(icono)

		var textos: VBoxContainer = VBoxContainer.new()
		textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(textos)
		var titulo: Label = Hud.crear_label(16)
		titulo.text = "%s   —   %d $" % [datos["nombre"], datos["precio"]]
		if datos["pila"] > 1:
			titulo.text += "   (montones de %d)" % DatosObjetos.pila(id)
		textos.add_child(titulo)
		var descripcion: Label = Hud.crear_label(13, Color(0.7, 0.72, 0.68))
		descripcion.text = datos["descripcion"]
		descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		textos.add_child(descripcion)
		var motivo: String = Juego.motivo_no_compra(id)
		if motivo != "":
			var aviso: Label = Hud.crear_label(13, Color(1, 0.45, 0.4))
			aviso.text = "🔒 " + motivo
			textos.add_child(aviso)

		var boton: Button = Hud.crear_boton("Comprar", func() -> void: Juego.avisar(Juego.comprar(id)))
		boton.disabled = motivo != "" or Juego.dinero < datos["precio"]
		boton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fila.add_child(boton)
		return fondo

	func _envio(casilla: CasillaUI) -> void:
		Juego.avisar(Juego.vender(casilla.lista, casilla.indice))


# Recuadro donde se sueltan cosas para venderlas a la tienda.
class ZonaVenta extends PanelContainer:
	func _ready() -> void:
		custom_minimum_size = Vector2(0, 54)
		var estilo: StyleBoxFlat = StyleBoxFlat.new()
		estilo.bg_color = Color(0.2, 0.12, 0.1, 0.8)
		estilo.border_color = Color(0.7, 0.45, 0.3)
		estilo.set_border_width_all(2)
		estilo.set_corner_radius_all(6)
		estilo.corner_detail = 1   # Esquina cortada: estilo low poly
		add_theme_stylebox_override("panel", estilo)
		var texto: Label = Hud.crear_label(15, Color(1, 0.8, 0.65))
		texto.text = "Arrastra aquí algo de tu inventario para venderlo (a mitad de precio) · o Mayús + clic"
		texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(texto)

	func _can_drop_data(_pos: Vector2, datos: Variant) -> bool:
		return datos is Dictionary and datos.has("lista")

	func _drop_data(_pos: Vector2, datos: Variant) -> void:
		Juego.avisar(Juego.vender(datos["lista"], datos["indice"]))


# El dibujo de un objeto en un cuadrado (para las filas de la tienda).
class IconoObjeto extends Control:
	var id: String = ""

	func _ready() -> void:
		custom_minimum_size = Vector2(52, 52)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.09))
		Iconos.dibujar(self, Rect2(Vector2.ZERO, size).grow(-2), id)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.4, 0.32), false, 1.5)


# ==============================================================================
# Una casilla donde se sueltan ingredientes: solo acepta hierbas y aditivos, de
# uno en uno. Un clic la vacía y devuelve el ingrediente al inventario.
class CasillaIngrediente extends CasillaUI:
	signal vaciada

	func _get_drag_data(_pos: Vector2) -> Variant:
		return null

	func _can_drop_data(_pos: Vector2, datos: Variant) -> bool:
		if not datos is Dictionary or not datos.has("lista"):
			return false
		var origen = datos["lista"][datos["indice"]]
		return origen != null and GameData.Mezclas.es_ingrediente(str(origen["id"]))

	func _drop_data(_pos: Vector2, datos: Variant) -> void:
		var origen: Array = datos["lista"]
		var i: int = datos["indice"]
		var c = origen[i]
		if lista[indice] != null:
			if not Juego.cabe(lista[indice]["id"], lista[indice]["cantidad"]):
				Juego.avisar("No te cabe lo que ya había en la casilla.")
				return
			Juego.anadir(lista[indice]["id"], lista[indice]["cantidad"])
		lista[indice] = {"id": c["id"], "cantidad": 1}
		c["cantidad"] -= 1
		if c["cantidad"] <= 0:
			origen[i] = null
		Juego.cambio.emit()

	func _gui_input(evento: InputEvent) -> void:
		var boton: InputEventMouseButton = evento as InputEventMouseButton
		if boton != null and boton.pressed and lista[indice] != null:
			vaciada.emit()


# ==============================================================================
# La ventana del caldero: eliges una receta (o experimentas), arrastras
# ingredientes y preparas. Cada combinación distinta de 2 a 4 ingredientes da
# una poción distinta (ver scripts/datos/mezclas.gd); las que descubres se
# apuntan en el recetario de la izquierda.
class VentanaCaldero extends Ventana:
	var _slots: Array = []
	var _receta: String = ""
	var _resultado: Label
	var _detalle: Label
	var _preparar: Button
	var _lista_recetas: VBoxContainer
	var _titulo_recetas: Label
	var _botones_receta: Dictionary = {}
	var _cocinando: bool = false
	var _pocion_al_fuego: String = ""   # Qué se está removiendo ahora mismo.

	func construir() -> void:
		_slots.resize(GameData.Mezclas.max_ingredientes(Juego.nivel))   # Más casillas al subir de nivel (6 y 9).
		var panel: PanelContainer = Hud.crear_panel()
		Hud.centrar(panel, Vector2(1120, 640))
		add_child(panel)
		var raiz: VBoxContainer = VBoxContainer.new()
		raiz.add_theme_constant_override("separation", 10)
		panel.add_child(raiz)
		cabecera(raiz, "Caldero")
		var columnas: HBoxContainer = HBoxContainer.new()
		columnas.add_theme_constant_override("separation", 24)
		raiz.add_child(columnas)

		# Izquierda: recetario, casillas de ingredientes y botón de preparar.
		var izquierda: VBoxContainer = VBoxContainer.new()
		izquierda.custom_minimum_size = Vector2(480, 0)
		izquierda.add_theme_constant_override("separation", 8)
		columnas.add_child(izquierda)
		_titulo_recetas = subtitulo(izquierda, "")
		_titulo_recetas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_titulo_recetas.custom_minimum_size = Vector2(470, 40)
		var desplazable: ScrollContainer = ScrollContainer.new()
		desplazable.custom_minimum_size = Vector2(480, 130)
		desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		izquierda.add_child(desplazable)
		_lista_recetas = VBoxContainer.new()
		_lista_recetas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lista_recetas.add_theme_constant_override("separation", 4)
		desplazable.add_child(_lista_recetas)
		_detalle = Hud.crear_label(14, Color(0.8, 0.85, 0.75))
		_detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detalle.custom_minimum_size = Vector2(460, 96)
		izquierda.add_child(_detalle)
		subtitulo(izquierda, "Arrastra de 2 a %d ingredientes (clic en una casilla para quitarlo)%s" % [_slots.size(),
				"" if _slots.size() >= GameData.Mezclas.MAX_INGREDIENTES else " · más casillas en el nivel %d" % _siguiente_nivel_casillas()])
		var fila: HBoxContainer = HBoxContainer.new()
		fila.add_theme_constant_override("separation", 10)
		izquierda.add_child(fila)
		for i in _slots.size():
			var slot: CasillaIngrediente = CasillaIngrediente.new(_slots, i, 76.0)
			slot.vaciada.connect(_quitar.bind(i))
			fila.add_child(slot)
		var botones: HBoxContainer = HBoxContainer.new()
		botones.add_theme_constant_override("separation", 10)
		izquierda.add_child(botones)
		botones.add_child(Hud.crear_boton("Colocar los de la receta", _autorrellenar))
		_preparar = Ventanas.boton_grande("Preparar", _hacer)
		_preparar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botones.add_child(_preparar)
		_resultado = Hud.crear_label(15, Color(1, 0.92, 0.6))
		_resultado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_resultado.custom_minimum_size = Vector2(460, 50)
		izquierda.add_child(_resultado)

		# Derecha: tu inventario (Mayús + clic manda el ingrediente al caldero).
		var derecha: VBoxContainer = VBoxContainer.new()
		columnas.add_child(derecha)
		Ventanas.montar_inventario(self, derecha, 50.0, _envio)

		_reconstruir_recetas()
		Juego.cambio.connect(_refrescar)
		_refrescar()

	func _siguiente_nivel_casillas() -> int:
		for n in GameData.Mezclas.CASILLAS_POR_NIVEL:
			if int(n) > Juego.nivel:
				return int(n)
		return Juego.nivel

	# Las recetas de autor y las que has descubierto, por orden alfabético.
	func _reconstruir_recetas() -> void:
		for hijo in _lista_recetas.get_children():
			hijo.queue_free()
		_botones_receta.clear()
		var ids: Array = GameData.POCIONES.keys()
		var descubiertas: Array = []
		for id in Juego.recetario:
			if GameData.existe_pocion(str(id)):
				descubiertas.append(str(id))
		descubiertas.sort_custom(func(a: String, b: String) -> bool:
			return GameData.pocion(a)["nombre"] < GameData.pocion(b)["nombre"])
		ids.append_array(descubiertas)
		for id_pocion in ids:
			var boton: Button = Hud.crear_boton(GameData.pocion(id_pocion)["nombre"], _elegir.bind(id_pocion))
			boton.toggle_mode = true
			boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
			boton.set_pressed_no_signal(id_pocion == _receta)
			_lista_recetas.add_child(boton)
			_botones_receta[id_pocion] = boton
		_titulo_recetas.text = "Recetario: %d recetas conocidas · prueba mezclas nuevas para descubrir más (%d posibles)" % [
				ids.size(), GameData.Mezclas.total_combinaciones() + GameData.POCIONES.size()]

	# Al cerrar, lo que quede en las casillas vuelve al inventario.
	func cerrar() -> void:
		# Si cierras a medio remover no pierdes los ingredientes: sale una poción (como con 0 aciertos).
		if _cocinando and _pocion_al_fuego != "":
			Juego.anadir("pocion_" + _pocion_al_fuego, 1)
			Juego.avisar("Dejas la mezcla a medias: sale 1 x %s." % GameData.pocion(_pocion_al_fuego)["nombre"])
			_cocinando = false
		_devolver_todo()
		super()

	func _devolver_todo() -> void:
		for i in _slots.size():
			_quitar(i)

	func _quitar(i: int) -> void:
		var c = _slots[i]
		if c == null:
			return
		_slots[i] = null
		var sobra: int = Juego.anadir(c["id"], c["cantidad"])
		if sobra > 0:
			Juego.avisar("No te cabía en el inventario: se han perdido %d %s." % [sobra,
					DatosObjetos.nombre(c["id"])])

	func _elegir(id_pocion: String) -> void:
		_receta = id_pocion
		for id in _botones_receta:
			_botones_receta[id].set_pressed_no_signal(id == id_pocion)
		_refrescar()

	# Mueve un ingrediente del inventario a la primera casilla libre.
	func _envio(casilla: CasillaUI) -> void:
		var c = Juego.inventario[casilla.indice]
		if c == null or not GameData.Mezclas.es_ingrediente(str(c["id"])):
			return
		for i in _slots.size():
			if _slots[i] == null:
				_slots[i] = {"id": c["id"], "cantidad": 1}
				c["cantidad"] -= 1
				if c["cantidad"] <= 0:
					Juego.inventario[casilla.indice] = null
				Juego.cambio.emit()
				return

	# Vacía las casillas y pone justo los ingredientes de la receta elegida.
	func _autorrellenar() -> void:
		if _receta == "":
			_resultado.text = "Elige primero una receta."
			return
		_devolver_todo()
		for id in GameData.Mezclas.items_de_receta(_receta):
			var hueco: int = _slots.find(null)
			if hueco == -1 or not Juego.tiene(id):
				_resultado.text = "Te faltan ingredientes para esa receta."
				break
			Juego.quitar(id)
			_slots[hueco] = {"id": id, "cantidad": 1}
		Juego.cambio.emit()

	# Los ingredientes que hay ahora mismo en las casillas.
	func _ingredientes() -> Array:
		var ids: Array = []
		for c in _slots:
			if c != null:
				ids.append(str(c["id"]))
		return ids

	func _hacer() -> void:
		if _cocinando:
			return   # Ya hay una mezcla al fuego: no se gastan más ingredientes hasta terminarla.
		var ids: Array = _ingredientes()
		if ids.size() < GameData.Mezclas.MIN_INGREDIENTES:
			return
		var id_pocion: String = GameData.buscar_pocion(ids)
		for i in _slots.size():
			_slots[i] = null
		if id_pocion == "":
			_resultado.text = "El caldero escupe un humo gris. Has hecho un bodrio y se ha perdido."
			Juego.cambio.emit()
			return
		# Mezcla buena: antes de sacar la poción hay que remover a tiempo (minijuego).
		_cocinando = true
		_pocion_al_fuego = id_pocion
		var barra: BarraRemover = BarraRemover.new()
		barra.terminado.connect(_terminar_cocinado.bind(id_pocion))
		add_child(barra)
		Juego.cambio.emit()

	func _terminar_cocinado(aciertos: int, id_pocion: String) -> void:
		_cocinando = false
		_pocion_al_fuego = ""
		# 0 aciertos: 1 poción (no se pierde nada); 1-2: 2 pociones; 3: 3 pociones y más XP.
		var cantidad: int = 1 if aciertos == 0 else (2 if aciertos < 3 else 3)
		var objeto: String = "pocion_" + id_pocion
		Juego.ganar_xp(10 + 8 * aciertos)
		var sobra: int = Juego.anadir(objeto, cantidad)
		var datos: Dictionary = GameData.pocion(id_pocion)
		var calidad: String = ["con mala mano", "regular", "bien", "¡perfecta!"][aciertos]
		var texto: String = "Mezcla %s: %d x %s%s." % [calidad, cantidad - sobra, datos["nombre"],
				"" if sobra == 0 else " (el resto no cabía y se derramó)"]
		if Juego.descubrir_receta(id_pocion):
			Juego.ganar_xp(30)
			texto = "¡RECETA NUEVA! " + texto + " Apuntada en el recetario (+30 XP).\n" + datos["resumen"]
			_receta = id_pocion
			_reconstruir_recetas()
		_resultado.text = texto
		Juego.cambio.emit()

	func _refrescar() -> void:
		var ids: Array = _ingredientes()
		var en_mesa: String = GameData.buscar_pocion(ids)
		if en_mesa != "" and (GameData.POCIONES.has(en_mesa) or Juego.recetario.has(en_mesa)):
			# Es una receta que ya conoces: se enseña lo que sale.
			_detalle.text = _texto_pocion(en_mesa)
		elif ids.size() >= GameData.Mezclas.MIN_INGREDIENTES and en_mesa != "":
			_detalle.text = "Mezcla desconocida: ¡prepárala para descubrir qué sale!\nIngredientes: %s" % ", ".join(
					PackedStringArray(ids.map(func(x: String) -> String: return DatosObjetos.nombre(x))))
		elif _receta != "":
			_detalle.text = _texto_pocion(_receta)
		else:
			_detalle.text = "Elige una receta del recetario o experimenta: cualquier combinación de 2 a 4 ingredientes da algo distinto."
		_preparar.disabled = ids.size() < GameData.Mezclas.MIN_INGREDIENTES or _cocinando

	func _texto_pocion(id: String) -> String:
		var datos: Dictionary = GameData.pocion(id)
		return "%s  (%d $)\nIngredientes: %s\n%s" % [datos["nombre"], datos["precio"], GameData.texto_receta(id),
				datos["resumen"]]


# ==============================================================================
# La academia: aquí se aprenden habilidades pagando. Sin la habilidad, las
# tiendas no te venden ciertas armas y explosivos.
class Instructor extends Ventana:
	var _estado: Label
	var _lista: VBoxContainer

	func construir() -> void:
		var caja: VBoxContainer = panel_centrado(Vector2(720, 520))
		cabecera(caja, "Academia Plomo y Pericia")
		_estado = Hud.crear_label(17, Color(1, 0.92, 0.6))
		caja.add_child(_estado)
		subtitulo(caja, "Aprende una habilidad para poder comprar armas y explosivos avanzados.")
		_lista = VBoxContainer.new()
		_lista.add_theme_constant_override("separation", 8)
		caja.add_child(_lista)
		Juego.cambio.connect(_refrescar)
		_refrescar()

	func _refrescar() -> void:
		_estado.text = Ventanas.texto_estado()
		for hijo in _lista.get_children():
			hijo.queue_free()
		for id_hab in DatosHabilidades.LISTA:
			var datos: Dictionary = DatosHabilidades.LISTA[id_hab]
			var fila: HBoxContainer = HBoxContainer.new()
			fila.add_theme_constant_override("separation", 12)
			_lista.add_child(fila)
			var texto: Label = Hud.crear_label(17)
			texto.text = "%s   —   %d $   (nivel %d)" % [datos["nombre"], datos["precio"], datos["nivel"]]
			texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fila.add_child(texto)
			var sabida: bool = Juego.habilidades.has(id_hab)
			var boton: Button = Hud.crear_boton("Aprendida" if sabida else "Aprender",
					func() -> void: Juego.avisar(Juego.aprender(id_hab)))
			boton.disabled = sabida or Juego.nivel < datos["nivel"] or Juego.dinero < datos["precio"]
			fila.add_child(boton)


# ==============================================================================
class Estanteria extends Ventana:
	var _estado: Label

	func construir() -> void:
		var panel: PanelContainer = Hud.crear_panel()
		Hud.centrar(panel, Vector2(1100, 620))
		add_child(panel)
		var raiz: VBoxContainer = VBoxContainer.new()
		raiz.add_theme_constant_override("separation", 10)
		panel.add_child(raiz)
		cabecera(raiz, "Estantería de casa")
		_estado = Hud.crear_label(15, Color(0.75, 0.8, 0.72))
		_estado.text = "Arrastra entre la estantería y tu inventario · Mayús + clic: mandar al otro lado"
		raiz.add_child(_estado)
		var columnas: HBoxContainer = HBoxContainer.new()
		columnas.add_theme_constant_override("separation", 24)
		raiz.add_child(columnas)

		var izquierda: VBoxContainer = VBoxContainer.new()
		columnas.add_child(izquierda)
		var fila: HBoxContainer = HBoxContainer.new()
		izquierda.add_child(fila)
		subtitulo(fila, "Estantería (%d casillas)   " % Juego.TAM_ESTANTERIA)
		fila.add_child(Hud.crear_boton("Ordenar", func() -> void: Juego.ordenar(Juego.estanteria)))
		rejilla(izquierda, Juego.estanteria, 0, Juego.TAM_ESTANTERIA, 9, 50.0, _a_inventario)

		var derecha: VBoxContainer = VBoxContainer.new()
		columnas.add_child(derecha)
		Ventanas.montar_inventario(self, derecha, 50.0, _a_estanteria)

	func _a_inventario(casilla: CasillaUI) -> void:
		Juego.mover_rapido(Juego.estanteria, casilla.indice, Juego.inventario)

	func _a_estanteria(casilla: CasillaUI) -> void:
		Juego.mover_rapido(Juego.inventario, casilla.indice, Juego.estanteria)


# ==============================================================================
class Admin extends Ventana:
	var _estado: Label
	var _hora: HSlider
	var _vida: HSlider
	var _objetos: OptionButton
	var _cantidad: SpinBox
	var _casillas_habilidad: Dictionary = {}
	var _texto_duracion: Label

	func construir() -> void:
		var caja: VBoxContainer = panel_centrado(Vector2(640, 880))
		cabecera(caja, "Panel de administrador (F1)")
		_estado = Hud.crear_label(17, Color(1, 0.92, 0.6))
		caja.add_child(_estado)

		# Hora del día y velocidad del tiempo.
		subtitulo(caja, "Hora del día")
		_hora = HSlider.new()
		_hora.min_value = 0.0
		_hora.max_value = 23.99
		_hora.step = 0.05
		_hora.value = Juego.hora
		_hora.value_changed.connect(func(v: float) -> void: Juego.hora = v)
		caja.add_child(_hora)
		var velocidades: HBoxContainer = HBoxContainer.new()
		caja.add_child(velocidades)
		for par in [["Pausa", 0.0], ["Normal", 1.0], ["x10", 10.0], ["x60", 60.0]]:
			velocidades.add_child(Hud.crear_boton(par[0], _velocidad.bind(par[1])))
		for par in [["Mañana", 8.0], ["Tarde", 17.0], ["Noche", 22.0]]:
			velocidades.add_child(Hud.crear_boton(par[0], func() -> void:
				Juego.hora = par[1]
				_hora.set_value_no_signal(par[1])))

		# Clima y volumen del sonido.
		subtitulo(caja, "Clima")
		var tiempo: HBoxContainer = HBoxContainer.new()
		caja.add_child(tiempo)
		for id in Clima.TIPOS:
			tiempo.add_child(Hud.crear_boton(String(Clima.TIPOS[id]["nombre"]), func() -> void:
				Clima.poner(id, 6.0)))
		subtitulo(caja, "Volumen de la música y del ambiente")
		var vol_musica: HSlider = HSlider.new()
		vol_musica.min_value = 0.0
		vol_musica.max_value = 1.0
		vol_musica.step = 0.05
		vol_musica.value = Musica.volumen_musica
		vol_musica.value_changed.connect(func(v: float) -> void:
			Musica.volumen_musica = v
			Musica.guardar_opciones())
		caja.add_child(vol_musica)
		var vol_ambiente: HSlider = HSlider.new()
		vol_ambiente.min_value = 0.0
		vol_ambiente.max_value = 1.0
		vol_ambiente.step = 0.05
		vol_ambiente.value = Musica.volumen_ambiente
		vol_ambiente.value_changed.connect(func(v: float) -> void:
			Musica.volumen_ambiente = v
			Musica.guardar_opciones())
		caja.add_child(vol_ambiente)

		# Duración de un día entero, en minutos reales.
		_texto_duracion = subtitulo(caja, "")
		var duracion: HSlider = HSlider.new()
		duracion.min_value = 2.0
		duracion.max_value = 240.0
		duracion.step = 1.0
		duracion.value = Juego.duracion_dia_min
		duracion.value_changed.connect(func(v: float) -> void:
			Juego.duracion_dia_min = v
			_actualizar_duracion())
		caja.add_child(duracion)
		_actualizar_duracion()

		# Dinero.
		subtitulo(caja, "Dinero")
		var dinero: HBoxContainer = HBoxContainer.new()
		caja.add_child(dinero)
		for cantidad in [100, 1000, -100]:
			var texto: String = ("+%d $" % cantidad) if cantidad > 0 else ("%d $" % cantidad)
			dinero.add_child(Hud.crear_boton(texto, func() -> void:
				Juego.dinero = maxi(0, Juego.dinero + cantidad)
				Juego.cambio.emit()))

		# Modo volar: W/A/S/D hacia donde miras, Espacio sube, C baja, Shift x3.
		# La rueda del ratón cambia la velocidad mientras vuelas.
		subtitulo(caja, "Modo volar (rueda del ratón = velocidad)")
		var fila_vuelo: HBoxContainer = HBoxContainer.new()
		caja.add_child(fila_vuelo)
		var volar: CheckButton = CheckButton.new()
		volar.text = "Volar"
		volar.button_pressed = Juego.modo_volar
		volar.focus_mode = Control.FOCUS_NONE
		var texto_vuelo: Label = Hud.crear_label(16, Color(0.8, 0.9, 1.0))
		var refrescar_vuelo: Callable = func() -> void:
			texto_vuelo.text = "Vuelo: %d m/s (%d km/h)" % [int(Juego.velocidad_vuelo), int(Juego.velocidad_vuelo * 3.6)]
		volar.toggled.connect(func(v: bool) -> void:
			Juego.modo_volar = v
			Juego.avisar("Modo volar activado. Rueda del ratón = velocidad." if v else "Modo volar desactivado.")
			refrescar_vuelo.call())
		fila_vuelo.add_child(volar)
		fila_vuelo.add_child(Hud.crear_boton("Velocidad normal", func() -> void:
			Juego.velocidad_vuelo = Juego.VELOCIDAD_VUELO_NORMAL
			refrescar_vuelo.call()
			Juego.avisar("Velocidad de vuelo normal: %d m/s" % int(Juego.VELOCIDAD_VUELO_NORMAL))))
		fila_vuelo.add_child(texto_vuelo)
		refrescar_vuelo.call()

		# Policía.
		var policia: CheckButton = CheckButton.new()
		policia.text = "Policía activa"
		policia.button_pressed = Juego.policia_activa
		policia.focus_mode = Control.FOCUS_NONE
		policia.toggled.connect(func(v: bool) -> void:
			Juego.policia_activa = v
			if not v:
				Juego.alerta = 0.0)
		caja.add_child(policia)
		var sosp: HSlider = HSlider.new()
		sosp.min_value = 0.0
		sosp.max_value = 100.0
		sosp.value = Juego.sospecha
		sosp.value_changed.connect(func(v: float) -> void: Juego.sospecha = v)
		subtitulo(caja, "Sospecha de la policía (0-100)")
		caja.add_child(sosp)

		# Vida.
		subtitulo(caja, "Vida")
		var fila_vida: HBoxContainer = HBoxContainer.new()
		caja.add_child(fila_vida)
		_vida = HSlider.new()
		_vida.min_value = 0
		_vida.max_value = Juego.VIDA_MAX
		_vida.value = Juego.vida
		_vida.custom_minimum_size = Vector2(380, 0)
		_vida.value_changed.connect(func(v: float) -> void: Juego.cambiar_vida(v - Juego.vida))
		fila_vida.add_child(_vida)
		fila_vida.add_child(Hud.crear_boton("Curar", func() -> void:
			Juego.cambiar_vida(Juego.VIDA_MAX)
			_vida.set_value_no_signal(Juego.vida)))

		# Nivel y habilidades.
		subtitulo(caja, "Nivel y habilidades")
		var fila_nivel: HBoxContainer = HBoxContainer.new()
		caja.add_child(fila_nivel)
		fila_nivel.add_child(Hud.crear_boton("Nivel -1", func() -> void:
			Juego.nivel = maxi(1, Juego.nivel - 1)
			Juego.cambio.emit()))
		fila_nivel.add_child(Hud.crear_boton("Nivel +1", func() -> void:
			Juego.nivel += 1
			Juego.cambio.emit()))
		var fila_hab: HFlowContainer = HFlowContainer.new()
		caja.add_child(fila_hab)
		for id_hab in DatosHabilidades.LISTA:
			var marca: CheckBox = CheckBox.new()
			marca.text = DatosHabilidades.nombre(id_hab)
			marca.focus_mode = Control.FOCUS_NONE
			marca.button_pressed = Juego.habilidades.has(id_hab)
			marca.toggled.connect(func(activa: bool) -> void:
				if activa:
					Juego.habilidades[id_hab] = true
				else:
					Juego.habilidades.erase(id_hab)
				Juego.cambio.emit())
			fila_hab.add_child(marca)

		# Dar objetos.
		subtitulo(caja, "Darme un objeto")
		var fila_dar: HBoxContainer = HBoxContainer.new()
		caja.add_child(fila_dar)
		_objetos = OptionButton.new()
		_objetos.focus_mode = Control.FOCUS_NONE
		for id in DatosObjetos.LISTA:
			_objetos.add_item(DatosObjetos.nombre(id))
			_objetos.set_item_metadata(_objetos.item_count - 1, id)
		fila_dar.add_child(_objetos)
		_cantidad = SpinBox.new()
		_cantidad.min_value = 1
		_cantidad.max_value = 100
		_cantidad.value = 1
		fila_dar.add_child(_cantidad)
		fila_dar.add_child(Hud.crear_boton("Dar", _dar))

		# Efectos de pociones (para probarlos) y recetas.
		subtitulo(caja, "Efectos y recetas")
		var fila_efecto: HBoxContainer = HBoxContainer.new()
		caja.add_child(fila_efecto)
		var lista_efectos: OptionButton = OptionButton.new()
		lista_efectos.focus_mode = Control.FOCUS_NONE
		for id_e in Juego.DatosEfectos.LISTA:
			lista_efectos.add_item(Juego.DatosEfectos.nombre(id_e))
			lista_efectos.set_item_metadata(lista_efectos.item_count - 1, id_e)
		fila_efecto.add_child(lista_efectos)
		fila_efecto.add_child(Hud.crear_boton("Aplicar 2 min", func() -> void:
			var id_e: String = lista_efectos.get_item_metadata(lista_efectos.selected)
			Juego.aplicar_efecto(id_e, 120.0, 1.0)))
		fila_efecto.add_child(Hud.crear_boton("Quitar todos", func() -> void:
			Juego.efectos_activos.clear()
			Juego.efectos_cambiados.emit()))
		fila_efecto.add_child(Hud.crear_boton("3 pociones al azar", func() -> void:
			var ids_i: Array = GameData.Mezclas.INGREDIENTES.keys()
			var n: int = randi_range(2, GameData.Mezclas.max_ingredientes(Juego.nivel))
			var mezcla: Array = []
			for i in n:
				mezcla.append(ids_i.pick_random())
			var id_p: String = GameData.buscar_pocion(mezcla)
			Juego.anadir("pocion_" + id_p, 3)
			Juego.descubrir_receta(id_p)
			Juego.avisar("Te has dado 3 x %s." % GameData.pocion(id_p)["nombre"])))

		Juego.cambio.connect(_refrescar)
		_refrescar()

	func _process(_delta: float) -> void:
		if not _hora.has_focus():
			_hora.set_value_no_signal(Juego.hora)

	func _refrescar() -> void:
		_estado.text = "%s    ·    Día %d, %s" % [Ventanas.texto_estado(), Juego.dia, Juego.texto_hora()]

	func _actualizar_duracion() -> void:
		_texto_duracion.text = "Duración de un día entero: %d minutos reales (normal: %d)" % [
				int(Juego.duracion_dia_min), int(Juego.DURACION_DIA_POR_DEFECTO)]

	func _velocidad(v: float) -> void:
		Juego.velocidad_tiempo = v
		Juego.avisar("Velocidad del tiempo: %s" % ("pausa" if v == 0.0 else "x%d" % int(v)))

	func _dar() -> void:
		var id: String = _objetos.get_item_metadata(_objetos.selected)
		var sobra: int = Juego.anadir(id, int(_cantidad.value))
		Juego.avisar("Te has dado %s.%s" % [DatosObjetos.nombre(id),
				"" if sobra == 0 else " (No cabían %d.)" % sobra])
