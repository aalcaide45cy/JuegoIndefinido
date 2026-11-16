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
	"hierba": "Hierbas", "pocion": "Pociones",
}


# Muestra un resumen: dinero, nivel y vida.
static func texto_estado() -> String:
	return "%d $    ·    Nivel %d    ·    Vida %d/%d" % [Juego.dinero, Juego.nivel,
			int(Juego.vida), int(Juego.VIDA_MAX)]


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
		var caja: VBoxContainer = panel_centrado(Vector2(380, 380))
		var titulo: Label = Hud.crear_label(32, Color(0.6, 0.9, 0.6))
		titulo.text = "Pausa"
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caja.add_child(titulo)
		caja.add_child(Ventanas.boton_grande("Reanudar", cerrar))
		caja.add_child(Ventanas.boton_grande("Guardar partida", _guardar))
		var cargar: Button = Ventanas.boton_grande("Cargar partida", _cargar)
		cargar.disabled = not Guardado.existe()
		caja.add_child(cargar)
		caja.add_child(Ventanas.boton_grande("Salir del juego", _salir))
		_aviso = Hud.crear_label(16, Color(1, 0.92, 0.6))
		_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caja.add_child(_aviso)

	func cerrar() -> void:
		get_tree().paused = false
		super()

	func _guardar() -> void:
		if Guardado.guardar(get_tree(), jugador):
			_aviso.text = "Partida guardada."
		else:
			_aviso.text = "No se pudo guardar."

	func _cargar() -> void:
		if Guardado.cargar(get_tree(), jugador):
			Juego.avisar("Partida cargada.")
			cerrar()
		else:
			_aviso.text = "No se pudo cargar."

	func _salir() -> void:
		get_tree().paused = false
		get_tree().quit()


# ==============================================================================
# Menú al arrancar: Continuar (si hay partida guardada) o Nueva partida.
class Inicio extends Ventana:
	var jugador: Node3D = null

	func construir() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		var caja: VBoxContainer = panel_centrado(Vector2(420, 360))
		var titulo: Label = Hud.crear_label(36, Color(0.6, 0.9, 0.6))
		titulo.text = "Elixir Clandestino"
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caja.add_child(titulo)
		var lema: Label = Hud.crear_label(15, Color(0.75, 0.8, 0.72))
		lema.text = "La magia está prohibida. Tú, no."
		lema.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caja.add_child(lema)
		var continuar: Button = Ventanas.boton_grande("Continuar", _continuar)
		continuar.disabled = not Guardado.existe()
		caja.add_child(continuar)
		caja.add_child(Ventanas.boton_grande("Nueva partida", _nueva))
		caja.add_child(Ventanas.boton_grande("Salir", _salir))

	func cerrar() -> void:
		get_tree().paused = false
		super()

	func _continuar() -> void:
		if Guardado.cargar(get_tree(), jugador):
			Juego.avisar("Partida cargada.")
			cerrar()

	func _nueva() -> void:
		Juego.reiniciar()
		cerrar()

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
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.4, 0.32), false, 1.5)
		CasillaUI.dibujar_icono(self, Rect2(Vector2.ZERO, size).grow(-8), id)


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

	func construir() -> void:
		var caja: VBoxContainer = panel_centrado(Vector2(640, 600))
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

		# Dinero.
		subtitulo(caja, "Dinero")
		var dinero: HBoxContainer = HBoxContainer.new()
		caja.add_child(dinero)
		for cantidad in [100, 1000, -100]:
			var texto: String = ("+%d $" % cantidad) if cantidad > 0 else ("%d $" % cantidad)
			dinero.add_child(Hud.crear_boton(texto, func() -> void:
				Juego.dinero = maxi(0, Juego.dinero + cantidad)
				Juego.cambio.emit()))

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

		Juego.cambio.connect(_refrescar)
		_refrescar()

	func _process(_delta: float) -> void:
		if not _hora.has_focus():
			_hora.set_value_no_signal(Juego.hora)

	func _refrescar() -> void:
		_estado.text = "%s    ·    Día %d, %s" % [Ventanas.texto_estado(), Juego.dia, Juego.texto_hora()]

	func _velocidad(v: float) -> void:
		Juego.velocidad_tiempo = v
		Juego.avisar("Velocidad del tiempo: %s" % ("pausa" if v == 0.0 else "x%d" % int(v)))

	func _dar() -> void:
		var id: String = _objetos.get_item_metadata(_objetos.selected)
		var sobra: int = Juego.anadir(id, int(_cantidad.value))
		Juego.avisar("Te has dado %s.%s" % [DatosObjetos.nombre(id),
				"" if sobra == 0 else " (No cabían %d.)" % sobra])
