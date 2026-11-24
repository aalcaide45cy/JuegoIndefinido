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
const Economia = preload("res://scripts/datos/economia.gd")

const CATEGORIAS: Dictionary = {
	"semilla": "Semillas", "material": "Cultivo", "herramienta": "Herramientas",
	"arma_cc": "Cuerpo a cuerpo", "arma_fuego": "Armas de fuego",
	"municion": "Munición", "explosivo": "Explosivos",
	"hierba": "Hierbas", "pocion": "Pociones", "paquete": "Paquetes", "mueble": "Muebles y montaje", "cosecha": "Cosechas", "animal": "Animales", "consumible": "Comida y medicina", "aditivo": "Aditivos del caldero",
}


# Muestra un resumen: dinero, nivel y vida.
static func texto_estado() -> String:
	return "%d $    ·    Nivel %d (%d/%d XP)    ·    Vida %d/%d" % [Juego.dinero, Juego.nivel,
			Juego.xp, Juego.xp_necesaria(), int(Juego.vida), int(Juego.vida_max())]


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


# Base de Pausa e Inicio: lista de botones a la izquierda y, a la derecha, un resumen de tu
# partida y los atajos de teclado/mando.
class MenuLateral extends Ventana:
	var jugador: Node3D = null
	var _aviso: Label
	var _botones: VBoxContainer
	var _derecha: VBoxContainer

	# Monta el marco: título grande, botones (a rellenar por quien hereda) y la columna derecha.
	func _montar(titulo_grande: String, lema: String) -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		var panel: PanelContainer = _panel_base(Vector2(900, 560))
		var fila: HBoxContainer = HBoxContainer.new()
		fila.add_theme_constant_override("separation", 26)
		panel.add_child(fila)
		var izquierda: VBoxContainer = VBoxContainer.new()
		izquierda.custom_minimum_size.x = 330
		izquierda.add_theme_constant_override("separation", 8)
		fila.add_child(izquierda)
		var t: Label = UI.titulo(titulo_grande)
		t.add_theme_font_size_override("font_size", 38)
		izquierda.add_child(t)
		if lema != "":
			izquierda.add_child(UI.nota(lema))
		izquierda.add_child(UI.espaciador_alto(10))
		_botones = VBoxContainer.new()
		_botones.add_theme_constant_override("separation", 7)
		izquierda.add_child(_botones)
		izquierda.add_child(UI.espaciador())
		_aviso = UI.parrafo("", Tema.ACENTO, 15)
		izquierda.add_child(_aviso)
		var vertical: VSeparator = VSeparator.new()
		fila.add_child(vertical)
		_derecha = VBoxContainer.new()
		_derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_derecha.add_theme_constant_override("separation", 12)
		fila.add_child(_derecha)

	func _boton(texto: String, accion: Callable, variacion: String = "", icono: String = "") -> Button:
		var b: Button = UI.boton(texto, accion, variacion, icono)
		b.custom_minimum_size = Vector2(0, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 18)
		_botones.add_child(b)
		return b

	func _ajustes_y_logros() -> void:
		_boton("Partidas…", _partidas, "", "save")
		_boton("Logros", func(): add_child(VentanaLogros.new()), "", "trophy")
		_boton("Ajustes…", func(): add_child(VentanaAjustes.new()), "", "gear")

	func _partidas() -> void:
		pass

	# Tarjeta con tus datos (nivel, vida, dinero, hora).
	func _tarjeta_personaje() -> void:
		var t: PanelContainer = UI.tarjeta()
		_derecha.add_child(t)
		var c: VBoxContainer = VBoxContainer.new()
		c.add_theme_constant_override("separation", 6)
		t.add_child(c)
		c.add_child(UI.seccion("Tu personaje"))
		var datos: HBoxContainer = HBoxContainer.new()
		datos.add_theme_constant_override("separation", 22)
		c.add_child(datos)
		datos.add_child(UI.etiqueta(UI.dinero(Juego.dinero), "Dinero", null, 24))
		datos.add_child(UI.etiqueta("Nivel %d" % Juego.nivel, "Titulo", null, 22))
		datos.add_child(UI.espaciador())
		datos.add_child(UI.etiqueta("Día %d · %s" % [Juego.dia, Juego.texto_hora()], "Subtitulo"))
		c.add_child(UI.etiqueta("Vida  %d / %d" % [int(Juego.vida), int(Juego.vida_max())], "Subtitulo"))
		c.add_child(UI.barra(Juego.vida, Juego.vida_max(), Tema.PELIGRO, 12))
		c.add_child(UI.etiqueta("Experiencia  %d / %d" % [Juego.xp, Juego.xp_necesaria()], "Subtitulo"))
		c.add_child(UI.barra(Juego.xp, Juego.xp_necesaria(), Tema.ACENTO, 12))
		if Juego.oficio != "":
			c.add_child(UI.etiqueta("Oficio: %s" % Juego.DatosOficios.nombre(Juego.oficio), "Subtitulo"))

	# Tarjeta con los atajos más usados (con las teclas que tengas puestas).
	func _tarjeta_atajos() -> void:
		var t: PanelContainer = UI.tarjeta()
		t.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_derecha.add_child(t)
		var c: VBoxContainer = VBoxContainer.new()
		c.add_theme_constant_override("separation", 6)
		t.add_child(c)
		c.add_child(UI.seccion("Atajos"))
		var rejilla: GridContainer = GridContainer.new()
		rejilla.columns = 2
		rejilla.add_theme_constant_override("h_separation", 26)
		rejilla.add_theme_constant_override("v_separation", 7)
		c.add_child(rejilla)
		for a in [["inventario", "Inventario"], ["telefono", "Móvil: encargos, pedidos, taxi"], ["mapa_grande", "Mapa grande"],
				["grimorio", "Grimorio de magia"], ["aspecto", "Ropa y peinado"], ["logros", "Logros"]]:
			var fila: HBoxContainer = HBoxContainer.new()
			fila.add_theme_constant_override("separation", 8)
			var tecla: PanelContainer = UI.tecla(Controles.nombre_teclas(str(a[0])).split(" / ")[0])
			fila.add_child(tecla)
			fila.add_child(UI.etiqueta(str(a[1]), "", Tema.TEXTO_SUAVE, 15))
			rejilla.add_child(fila)
		var pad: Label = UI.nota("Con mando: Start pausa · Select móvil · cruceta ↑ mapa, ↓ inventario.")
		c.add_child(UI.espaciador())
		c.add_child(pad)

	func cerrar() -> void:
		get_tree().paused = false
		super()


# ==============================================================================
# Menú de pausa (Esc): el juego se para mientras está abierto.
class Pausa extends MenuLateral:

	func construir() -> void:
		_montar("Pausa", "Juego Indefinido")
		_boton("Reanudar", cerrar, "BotonPrimario", "right")
		_boton("Guardar (ranura %d)" % Guardado.ranura, _guardar, "", "save")
		_ajustes_y_logros()
		_boton("Salir del juego", _salir, "BotonPeligro", "exit")
		_tarjeta_personaje()
		_tarjeta_atajos()

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

	func _salir() -> void:
		get_tree().paused = false
		get_tree().quit()


# ==============================================================================
# Menú al arrancar: Continuar (última ranura), Nueva partida, elegir ranura o ver logros.
class Inicio extends MenuLateral:

	func construir() -> void:
		se_cierra_con_atras = false
		_montar("Juego Indefinido", "La magia está prohibida. Tú, no.")
		var ultima: int = Guardado.ultima_ranura()
		var continuar: Button = _boton("Continuar (ranura %d)" % ultima if ultima > 0 else "Continuar", _continuar, "BotonPrimario", "right")
		continuar.disabled = ultima == 0
		_boton("Nueva partida", _nueva, "", "plus")
		_ajustes_y_logros()
		_boton("Salir", _salir, "BotonPeligro", "exit")
		_derecha_inicio(ultima)
		_tarjeta_atajos()

	# A la derecha: un resumen de la última partida (o una bienvenida si no hay ninguna).
	func _derecha_inicio(ultima: int) -> void:
		var t: PanelContainer = UI.tarjeta()
		_derecha.add_child(t)
		var c: VBoxContainer = VBoxContainer.new()
		c.add_theme_constant_override("separation", 6)
		t.add_child(c)
		c.add_child(UI.seccion("Última partida" if ultima > 0 else "Bienvenido"))
		if ultima > 0:
			var r: Dictionary = Guardado.resumen(ultima)
			if r.is_empty() or r.has("roto"):
				c.add_child(UI.parrafo("La ranura %d no se puede leer." % ultima, Tema.PELIGRO))
			else:
				var datos: HBoxContainer = HBoxContainer.new()
				datos.add_theme_constant_override("separation", 22)
				c.add_child(datos)
				datos.add_child(UI.etiqueta(UI.dinero(int(r["dinero"])), "Dinero", null, 24))
				datos.add_child(UI.etiqueta("Nivel %d" % int(r["nivel"]), "Titulo", null, 22))
				datos.add_child(UI.espaciador())
				datos.add_child(UI.etiqueta("Día %d" % int(r["dia"]), "Subtitulo"))
				if str(r["fecha"]) != "":
					c.add_child(UI.nota("Guardada el %s" % str(r["fecha"]).replace("T", " ")))
		else:
			c.add_child(UI.parrafo("Eres un alquimista en una ciudad donde la magia está prohibida. Cultiva Hoja de Bruma, " +
					"cocina pociones, monta negocios y esquiva a la guardia. Empieza con «Nueva partida».", Tema.TEXTO_SUAVE))

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
# Inventario (TAB): mochila con filtros y buscador a la izquierda y la ficha del objeto a la derecha.
class Inventario extends Ventana:
	var _estado: HBoxContainer
	var _detalle: DetalleObjeto
	var _panel: PanelInventario

	func construir() -> void:
		pistas_extra = [["x", "Mandar a barra / mochila"], ["y", "Dividir"]]
		var cuerpo: VBoxContainer = marco("Inventario", "", Vector2(1060, 650))
		_cabecera_extra()
		var columnas: HBoxContainer = HBoxContainer.new()
		columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		columnas.add_theme_constant_override("separation", 18)
		cuerpo.add_child(columnas)
		_panel = PanelInventario.new(Juego.inventario, Juego.TAM_BARRA, Juego.TAM_INVENTARIO, 9, 50.0, _envio, true, true)
		_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columnas.add_child(_panel)
		var derecha: VBoxContainer = VBoxContainer.new()
		derecha.custom_minimum_size.x = 310
		derecha.add_theme_constant_override("separation", 8)
		columnas.add_child(derecha)
		_detalle = DetalleObjeto.new(310.0)
		derecha.add_child(_detalle)
		var botones: HBoxContainer = HBoxContainer.new()
		botones.add_theme_constant_override("separation", 8)
		derecha.add_child(botones)
		var ordenar: Button = UI.boton("Ordenar mochila", func() -> void: Juego.ordenar(Juego.inventario, Juego.TAM_BARRA), "", "menuList")
		ordenar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botones.add_child(ordenar)
		derecha.add_child(UI.nota("Arrastra para mover o apilar · Clic derecho: dividir · Mayús + clic: mochila ↔ barra"))
		_panel.elegido.connect(_ver)
		Juego.cambio.connect(_refrescar)
		_refrescar()
		for it in Juego.inventario:
			if it != null:
				_detalle.mostrar(str(it["id"]), Juego.cuenta(str(it["id"])), it)
				break

	# Dinero, nivel y vida en la cabecera, a la izquierda del botón de cerrar.
	func _cabecera_extra() -> void:
		_estado = HBoxContainer.new()
		_estado.add_theme_constant_override("separation", 16)
		_marco_cabecera.add_child(_estado)
		_marco_cabecera.move_child(_estado, _marco_cabecera.get_child_count() - 2)

	func _refrescar() -> void:
		for h in _estado.get_children():
			h.queue_free()
		_estado.add_child(UI.etiqueta(UI.dinero(Juego.dinero), "Dinero"))
		_estado.add_child(UI.etiqueta("Nivel %d" % Juego.nivel, "Subtitulo"))
		_estado.add_child(UI.etiqueta("Vida %d/%d" % [int(Juego.vida), int(Juego.vida_max())], "Subtitulo"))

	func _ver(casilla: CasillaUI) -> void:
		var it = casilla.lista[casilla.indice]
		if it == null:
			_detalle.mostrar("")
		else:
			_detalle.mostrar(str(it["id"]), Juego.cuenta(str(it["id"])), it)

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
# Tienda: catálogo con categorías, buscador, orden y filtro a la izquierda (pestañas Comprar y
# Vender) y, a la derecha, la ficha del objeto, tu inventario y la zona de venta.
class Tienda extends Ventana:
	var nombre_tienda: String = "Tienda"
	var tienda: String = "herbolario"   # Qué vende (campo "tienda" en objetos.gd).

	var _estado: HBoxContainer
	var _pestanas: UI.Pestanas
	var _categorias: UI.Filtros
	var _lista_comprar: VBoxContainer
	var _lista_vender: VBoxContainer
	var _desplazable: ScrollContainer
	var _orden: OptionButton
	var _solo_puedo: CheckButton
	var _texto: String = ""
	var _detalle: DetalleObjeto
	var _vacio: Label

	func construir() -> void:
		pistas_extra = [["pestanas", "Comprar / Vender"], ["x", "Vender"]]
		var cuerpo: VBoxContainer = marco(nombre_tienda, "", Vector2(1180, 670))
		_estado = HBoxContainer.new()
		_estado.add_theme_constant_override("separation", 16)
		_marco_cabecera.add_child(_estado)
		_marco_cabecera.move_child(_estado, _marco_cabecera.get_child_count() - 2)
		var columnas: HBoxContainer = HBoxContainer.new()
		columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		columnas.add_theme_constant_override("separation", 18)
		cuerpo.add_child(columnas)

		# Izquierda: pestañas Comprar / Vender.
		_pestanas = UI.Pestanas.new()
		_pestanas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columnas.add_child(_pestanas)
		_pestanas.anadir("Comprar", _montar_comprar(), "shoppingCart")
		_pestanas.anadir("Vender", _montar_vender(), "shoppingBasket")
		_pestanas.cambiada.connect(func(_i: int) -> void: _refrescar())

		# Derecha: ficha, inventario compacto y zona de venta.
		var derecha: VBoxContainer = VBoxContainer.new()
		derecha.custom_minimum_size.x = 420
		derecha.add_theme_constant_override("separation", 8)
		columnas.add_child(derecha)
		_detalle = DetalleObjeto.new(420.0)
		derecha.add_child(_detalle)
		var mochila: PanelInventario = PanelInventario.new(Juego.inventario, Juego.TAM_BARRA, Juego.TAM_INVENTARIO, 9, 36.0, _envio, false, true, "Tu mochila")
		mochila.elegido.connect(_ver_casilla)
		derecha.add_child(mochila)
		derecha.add_child(ZonaVenta.new())
		Juego.cambio.connect(_refrescar)
		_refrescar()

	func _montar_comprar() -> Control:
		var caja: VBoxContainer = VBoxContainer.new()
		caja.add_theme_constant_override("separation", 8)
		var fila: HBoxContainer = HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		caja.add_child(fila)
		fila.add_child(UI.buscador("Buscar en el catálogo…", func(t: String) -> void:
			_texto = t
			_refrescar()))
		_orden = OptionButton.new()
		for t in ["Orden: nombre", "Precio: menor primero", "Precio: mayor primero", "Nivel necesario"]:
			_orden.add_item(t)
		_orden.item_selected.connect(func(_i: int) -> void: _refrescar())
		fila.add_child(_orden)
		_categorias = UI.Filtros.new()
		_categorias.anadir("todo", "Todo")
		var vistas: Dictionary = {}
		for id in DatosObjetos.de_tienda(tienda):
			var tipo: String = str(DatosObjetos.datos(id)["tipo"])
			if not vistas.has(tipo):
				vistas[tipo] = true
				_categorias.anadir(tipo, str(CATEGORIAS.get(tipo, tipo)))
		_categorias.cambiado.connect(func(_c: String) -> void: _refrescar())
		caja.add_child(_categorias)
		_solo_puedo = CheckButton.new()
		_solo_puedo.text = "Solo lo que puedo comprar ahora"
		_solo_puedo.toggled.connect(func(_on: bool) -> void: _refrescar())
		caja.add_child(_solo_puedo)
		_desplazable = ScrollContainer.new()
		_desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_desplazable.follow_focus = true
		caja.add_child(_desplazable)
		var interior: VBoxContainer = VBoxContainer.new()
		interior.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_desplazable.add_child(interior)
		_lista_comprar = VBoxContainer.new()
		_lista_comprar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lista_comprar.add_theme_constant_override("separation", 6)
		interior.add_child(_lista_comprar)
		_vacio = UI.nota("Nada coincide con tu búsqueda.")
		_vacio.visible = false
		interior.add_child(_vacio)
		return caja

	func _montar_vender() -> Control:
		var caja: VBoxContainer = VBoxContainer.new()
		caja.add_theme_constant_override("separation", 8)
		caja.add_child(UI.nota("Esto es lo que llevas y esta tienda te compra (la mitad del precio; las cosechas, menos). " +
				"También puedes arrastrar objetos a la zona de venta de la derecha."))
		var desplazable: ScrollContainer = ScrollContainer.new()
		desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		desplazable.follow_focus = true
		caja.add_child(desplazable)
		_lista_vender = VBoxContainer.new()
		_lista_vender.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lista_vender.add_theme_constant_override("separation", 6)
		desplazable.add_child(_lista_vender)
		return caja

	func _refrescar() -> void:
		for h in _estado.get_children():
			h.queue_free()
		_estado.add_child(UI.etiqueta(UI.dinero(Juego.dinero), "Dinero"))
		_estado.add_child(UI.etiqueta("Nivel %d" % Juego.nivel, "Subtitulo"))
		var pos: int = _desplazable.scroll_vertical
		for h in _lista_comprar.get_children():
			_lista_comprar.remove_child(h)
			h.queue_free()
		var ids: Array = []
		for id in DatosObjetos.de_tienda(tienda):
			var d: Dictionary = DatosObjetos.datos(id)
			if _categorias.clave != "todo" and d["tipo"] != _categorias.clave:
				continue
			if _texto != "" and not str(d["nombre"]).to_lower().contains(_texto) and not str(d["descripcion"]).to_lower().contains(_texto):
				continue
			if _solo_puedo.button_pressed and (Juego.motivo_no_compra(id) != "" or Juego.dinero < int(d["precio"])):
				continue
			ids.append(id)
		match _orden.selected:
			0: ids.sort_custom(func(a, b) -> bool: return DatosObjetos.nombre(a) < DatosObjetos.nombre(b))
			1: ids.sort_custom(func(a, b) -> bool: return int(DatosObjetos.datos(a)["precio"]) < int(DatosObjetos.datos(b)["precio"]))
			2: ids.sort_custom(func(a, b) -> bool: return int(DatosObjetos.datos(a)["precio"]) > int(DatosObjetos.datos(b)["precio"]))
			3: ids.sort_custom(func(a, b) -> bool: return int(DatosObjetos.datos(a)["nivel"]) < int(DatosObjetos.datos(b)["nivel"]))
		for id in ids:
			_lista_comprar.add_child(_fila_producto(id))
		_vacio.visible = ids.is_empty()
		_desplazable.set_deferred("scroll_vertical", pos)
		# Pestaña Vender: lo que llevas y se puede vender.
		if _lista_vender != null:
			for h in _lista_vender.get_children():
				_lista_vender.remove_child(h)
				h.queue_free()
			var hay: bool = false
			for lista in [Juego.inventario]:
				for i in lista.size():
					var c = lista[i]
					if c != null and int(DatosObjetos.datos(c["id"])["precio"]) > 0:
						_lista_vender.add_child(_fila_venta(lista, i))
						hay = true
			if not hay:
				_lista_vender.add_child(UI.nota("No llevas nada que se pueda vender."))
		_pestanas.renombrar(0, "Comprar (%d)" % ids.size())

	# Una fila del catálogo: icono, nombre, descripción, requisitos, precio y botones de comprar.
	func _fila_producto(id: String) -> Control:
		var datos: Dictionary = DatosObjetos.datos(id)
		var motivo: String = Juego.motivo_no_compra(id)
		var sin_dinero: bool = Juego.dinero < int(datos["precio"])
		var fondo: PanelContainer = UI.tarjeta()
		var fila: HBoxContainer = HBoxContainer.new()
		fila.add_theme_constant_override("separation", 12)
		fondo.add_child(fila)
		var icono: DetalleObjeto.IconoGrande = DetalleObjeto.IconoGrande.new()
		icono.id = id
		icono.custom_minimum_size = Vector2(56, 56)
		fila.add_child(icono)
		var textos: VBoxContainer = VBoxContainer.new()
		textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		textos.add_theme_constant_override("separation", 2)
		fila.add_child(textos)
		var nombre: Label = UI.etiqueta(str(datos["nombre"]), "", Tema.TEXTO if motivo == "" else Tema.TEXTO_SUAVE, 17)
		nombre.add_theme_font_override("font", Tema.fuente("semibold"))
		textos.add_child(nombre)
		var desc: Label = UI.nota(str(datos["descripcion"]))
		textos.add_child(desc)
		if motivo != "":
			textos.add_child(UI.etiqueta(motivo, "Peligro", null, 13))
		var derecha: VBoxContainer = VBoxContainer.new()
		derecha.add_theme_constant_override("separation", 4)
		derecha.custom_minimum_size.x = 120
		fila.add_child(derecha)
		var precio: Label = UI.etiqueta(UI.dinero(int(datos["precio"])), "Dinero" if not sin_dinero else "Peligro", null, 19)
		precio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		derecha.add_child(precio)
		var botones: HBoxContainer = HBoxContainer.new()
		botones.add_theme_constant_override("separation", 4)
		derecha.add_child(botones)
		var comprar: Button = UI.boton("Comprar", func() -> void: Juego.avisar(Juego.comprar(id)), "BotonPrimario")
		comprar.disabled = motivo != "" or sin_dinero
		comprar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botones.add_child(comprar)
		var cinco: Button = UI.boton("×5", func() -> void: _comprar_varios(id, 5))
		cinco.disabled = comprar.disabled or Juego.dinero < int(datos["precio"]) * 2
		cinco.tooltip_text = "Comprar hasta 5 (se detiene si no te llega el dinero o no te cabe)"
		botones.add_child(cinco)
		var ver: Callable = func() -> void: _detalle.mostrar(id, Juego.cuenta(id))
		comprar.focus_entered.connect(ver)
		fondo.mouse_entered.connect(ver)
		return fondo

	func _comprar_varios(id: String, veces: int) -> void:
		var hechas: int = 0
		for i in veces:
			var antes: int = Juego.dinero
			Juego.comprar(id)
			if Juego.dinero == antes:
				break
			hechas += 1
		Juego.avisar("Has comprado %d × %s." % [hechas, DatosObjetos.nombre(id)])

	# Una fila de la pestaña Vender.
	func _fila_venta(lista: Array, i: int) -> Control:
		var c = lista[i]
		var id: String = str(c["id"])
		var datos: Dictionary = DatosObjetos.datos(id)
		var factor: float = Economia.VENTA_COSECHA if datos["tipo"] == "cosecha" else Economia.VENTA_TIENDA
		var unidad: int = maxi(1, int(int(datos["precio"]) * factor))
		var fondo: PanelContainer = UI.tarjeta()
		var fila: HBoxContainer = HBoxContainer.new()
		fila.add_theme_constant_override("separation", 12)
		fondo.add_child(fila)
		var icono: DetalleObjeto.IconoGrande = DetalleObjeto.IconoGrande.new()
		icono.id = id
		icono.custom_minimum_size = Vector2(48, 48)
		fila.add_child(icono)
		var nombre: Label = UI.etiqueta("%s  ×%d" % [datos["nombre"], int(c["cantidad"])], "", Tema.TEXTO, 17)
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nombre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fila.add_child(nombre)
		fila.add_child(UI.etiqueta("%s c/u" % UI.dinero(unidad), "Subtitulo"))
		var total: Label = UI.etiqueta(UI.dinero(unidad * int(c["cantidad"])), "Dinero", null, 18)
		total.custom_minimum_size.x = 90
		total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fila.add_child(total)
		var vender: Button = UI.boton("Vender todo", func() -> void: Juego.avisar(Juego.vender(lista, i)), "BotonAcento")
		fila.add_child(vender)
		var ver: Callable = func() -> void: _detalle.mostrar(id, Juego.cuenta(id), c)
		vender.focus_entered.connect(ver)
		fondo.mouse_entered.connect(ver)
		return fondo

	func _ver_casilla(casilla: CasillaUI) -> void:
		var it = casilla.lista[casilla.indice]
		if it == null:
			_detalle.mostrar("")
		else:
			_detalle.mostrar(str(it["id"]), Juego.cuenta(str(it["id"])), it)

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
		Hud.centrar(panel, Vector2(1120, 640), espacio_visible())
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
		var caja: VBoxContainer = marco("Academia Plomo y Pericia", "Aprende habilidades para comprar armas y explosivos avanzados", Vector2(780, 560))
		_estado = UI.etiqueta("", "Dinero")
		caja.add_child(_estado)
		var desplazable: ScrollContainer = ScrollContainer.new()
		desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		desplazable.follow_focus = true
		caja.add_child(desplazable)
		_lista = VBoxContainer.new()
		_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lista.add_theme_constant_override("separation", 6)
		desplazable.add_child(_lista)
		Juego.cambio.connect(_refrescar)
		_refrescar()

	func _refrescar() -> void:
		if not is_instance_valid(_lista):
			return
		_estado.text = Ventanas.texto_estado()
		for hijo in _lista.get_children():
			_lista.remove_child(hijo)
			hijo.queue_free()
		for id_hab in DatosHabilidades.LISTA:
			var datos: Dictionary = DatosHabilidades.LISTA[id_hab]
			var sabida: bool = Juego.habilidades.has(id_hab)
			var t: PanelContainer = UI.tarjeta(sabida)
			_lista.add_child(t)
			var fila: HBoxContainer = HBoxContainer.new()
			fila.add_theme_constant_override("separation", 12)
			t.add_child(fila)
			var textos: VBoxContainer = VBoxContainer.new()
			textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			textos.add_theme_constant_override("separation", 2)
			fila.add_child(textos)
			textos.add_child(UI.etiqueta(str(datos["nombre"]), "", Tema.TEXTO if sabida or Juego.nivel >= int(datos["nivel"]) else Tema.TEXTO_SUAVE, 17))
			var falta_nivel: bool = Juego.nivel < int(datos["nivel"])
			textos.add_child(UI.etiqueta("Nivel %d necesario" % int(datos["nivel"]) if falta_nivel else "Nivel %d" % int(datos["nivel"]), "Nota", Tema.PELIGRO if falta_nivel else null))
			if sabida:
				fila.add_child(UI.insignia("APRENDIDA", Tema.ACENTO))
			else:
				fila.add_child(UI.etiqueta(UI.dinero(int(datos["precio"])), "Dinero"))
				var boton: Button = UI.boton("Aprender", func() -> void: Juego.avisar(Juego.aprender(id_hab)), "BotonPrimario")
				boton.disabled = falta_nivel or Juego.dinero < int(datos["precio"])
				fila.add_child(boton)


# ==============================================================================
class Estanteria extends Ventana:
	var _detalle: DetalleObjeto

	func construir() -> void:
		pistas_extra = [["x", "Mandar al otro lado"], ["y", "Dividir"]]
		var cuerpo: VBoxContainer = marco("Estantería de casa", "Guarda aquí lo que no quieras llevar encima", Vector2(1180, 660))
		var columnas: HBoxContainer = HBoxContainer.new()
		columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		columnas.add_theme_constant_override("separation", 18)
		cuerpo.add_child(columnas)
		var izquierda: VBoxContainer = VBoxContainer.new()
		izquierda.add_theme_constant_override("separation", 8)
		columnas.add_child(izquierda)
		var estante: PanelInventario = PanelInventario.new(Juego.estanteria, 0, Juego.TAM_ESTANTERIA, 9, 46.0, _a_inventario, true, false, "Estantería")
		estante.elegido.connect(_ver)
		izquierda.add_child(estante)
		izquierda.add_child(UI.boton("Ordenar estantería", func() -> void: Juego.ordenar(Juego.estanteria), "", "menuList"))
		var centro: VBoxContainer = VBoxContainer.new()
		centro.add_theme_constant_override("separation", 8)
		centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columnas.add_child(centro)
		var mochila: PanelInventario = PanelInventario.new(Juego.inventario, Juego.TAM_BARRA, Juego.TAM_INVENTARIO, 9, 46.0, _a_estanteria, true, true, "Tu mochila")
		mochila.elegido.connect(_ver)
		centro.add_child(mochila)
		_detalle = DetalleObjeto.new(260.0)
		columnas.add_child(_detalle)

	func _ver(casilla: CasillaUI) -> void:
		var it = casilla.lista[casilla.indice]
		if it == null:
			_detalle.mostrar("")
		else:
			_detalle.mostrar(str(it["id"]), Juego.cuenta(str(it["id"])), it)

	func _a_inventario(casilla: CasillaUI) -> void:
		Juego.mover_rapido(Juego.estanteria, casilla.indice, Juego.inventario)

	func _a_estanteria(casilla: CasillaUI) -> void:
		Juego.mover_rapido(Juego.inventario, casilla.indice, Juego.estanteria)


# ==============================================================================
class Admin extends Ventana:
	var jugador: Node3D = null
	var _pestanas: UI.Pestanas
	var _paginas: Array = []        # Las páginas con filas (se filtran con el buscador).
	var _campo: LineEdit
	var _resultado: Label

	func construir() -> void:
		pistas_extra = [["pestanas", "Cambiar de pestaña"]]
		var cuerpo: VBoxContainer = marco("Panel de administrador", "Solo para probar el juego (F1)", Vector2(1120, 680))
		_pestanas = UI.Pestanas.new()
		cuerpo.add_child(_pestanas)
		var jug: PaginaAdmin = _pagina("jugador")
		_pestanas.anadir("Jugador", jug, "singleplayer")
		var mun: PaginaAdmin = _pagina("mundo")
		_pestanas.anadir("Mundo", mun, "contrast")
		var obj: VentanaObjetosAdmin = VentanaObjetosAdmin.new()
		obj.jugador = jugador
		obj.incrustada = true
		_pestanas.anadir("Objetos y NPC", obj, "shoppingBasket")
		var tp: VentanaTeletransporte = VentanaTeletransporte.new()
		tp.jugador = jugador
		tp.incrustada = true
		_pestanas.anadir("Teletransporte", tp, "target")
		var veh: PaginaAdmin = _pagina("vehiculos")
		_pestanas.anadir("Vehículos y efectos", veh, "wrench")
		var asa: VentanaAsaltos = VentanaAsaltos.new()
		asa.jugador = jugador
		asa.incrustada = true
		_pestanas.anadir("Asaltos", asa, "locked")
		_paginas = [jug, mun, veh]
		_resultado = UI.nota("", false)
		_campo = UI.buscador("Buscar un ajuste…", _buscar)
		_campo.custom_minimum_size.x = 220
		_pestanas.hueco_extra().add_child(_resultado)
		_pestanas.hueco_extra().add_child(_campo)

	func _pagina(modo: String) -> PaginaAdmin:
		var p: PaginaAdmin = PaginaAdmin.new()
		p.modo = modo
		p.jugador = jugador
		p.incrustada = true
		return p

	func _buscar(texto: String) -> void:
		var total: int = 0
		var primera: int = -1
		for i in _paginas.size():
			_paginas[i].filtrar(texto)
			if texto != "":
				var n: int = _paginas[i].coincidencias()
				total += n
				if n > 0 and primera < 0:
					primera = _pestanas.indice_de(_paginas[i])
		_resultado.text = "" if texto == "" else "%d resultados" % total
		if primera >= 0 and texto != "" and not _paginas.has(_pestanas.contenido(_pestanas.actual)):
			_pestanas.elegir(primera)
		elif primera >= 0 and texto != "" and _pestanas.contenido(_pestanas.actual).coincidencias() == 0:
			_pestanas.elegir(primera)


# Una página de filas del panel de administrador: "jugador", "mundo" o "vehiculos" (y efectos).
class PaginaAdmin extends VentanaOpciones:
	var modo: String = "jugador"
	var jugador: Node3D = null
	var _lista_vehiculos: OptionButton
	var _hora: HSlider
	var _vida: HSlider
	var _texto_duracion: Label
	var _resumen: Label

	func _refrescar_resumen() -> void:
		if is_instance_valid(_resumen):
			_resumen.text = Ventanas.texto_estado()

	func construir() -> void:
		montar_incrustada()
		match modo:
			"jugador":
				_pagina_jugador()
			"mundo":
				_pagina_mundo()
			_:
				_pagina_vehiculos()
		filtrar("")

	func _process(_delta: float) -> void:
		if modo == "mundo" and _hora != null and not _hora.has_focus():
			_hora.set_value_no_signal(Juego.hora)

	func _pagina_jugador() -> void:
		titulo("Estado")
		var estado: HBoxContainer = fila("Resumen")
		_resumen = UI.etiqueta(Ventanas.texto_estado(), "Dinero", null, 16)
		estado.add_child(_resumen)
		Juego.cambio.connect(_refrescar_resumen)
		_vida = deslizador("Vida", Juego.vida, 0, Juego.vida_max(), 1.0, "%d", 1.0, func(v: float) -> void: Juego.cambiar_vida(v - Juego.vida))
		boton_fila("Curar del todo", func() -> void:
			Juego.cambiar_vida(Juego.vida_max())
			_vida.set_value_no_signal(Juego.vida))
		titulo("Dinero")
		var f_dinero: HBoxContainer = fila("Dinero")
		for cantidad in [100, 1000, 10000, -100]:
			var t: String = ("+%s" % UI.dinero(cantidad)) if cantidad > 0 else UI.dinero(cantidad)
			f_dinero.add_child(UI.boton(t, func() -> void:
				Juego.dinero = maxi(0, Juego.dinero + cantidad)
				Juego.cambio.emit()))
		titulo("Nivel y habilidades")
		var f_nivel: HBoxContainer = fila("Nivel")
		f_nivel.add_child(UI.boton("Nivel −1", func() -> void:
			Juego.nivel = maxi(1, Juego.nivel - 1)
			Juego.cambio.emit()))
		f_nivel.add_child(UI.boton("Nivel +1", func() -> void:
			Juego.nivel += 1
			Juego.cambio.emit()))
		for id_hab in DatosHabilidades.LISTA:
			casilla(DatosHabilidades.nombre(id_hab), Juego.habilidades.has(id_hab), func(activa: bool) -> void:
				if activa:
					Juego.habilidades[id_hab] = true
				else:
					Juego.habilidades.erase(id_hab)
				Juego.cambio.emit())
		titulo("Movimiento")
		casilla("Modo volar", Juego.modo_volar, func(v: bool) -> void:
			Juego.modo_volar = v
			Juego.avisar("Modo volar activado. Rueda del ratón = velocidad." if v else "Modo volar desactivado."),
				"W/A/S/D hacia donde miras, Espacio sube, C baja, Mayús x3. La rueda del ratón cambia la velocidad.")
		deslizador("Velocidad de vuelo (m/s)", Juego.velocidad_vuelo, 5.0, 300.0, 1.0, "%d", 1.0, func(v: float) -> void:
			Juego.velocidad_vuelo = v)
		titulo("Policía")
		casilla("Policía activa", Juego.policia_activa, func(v: bool) -> void:
			Juego.policia_activa = v
			if not v:
				Juego.alerta = 0.0)
		deslizador("Sospecha de la policía", Juego.sospecha, 0.0, 100.0, 1.0, "%d", 1.0, func(v: float) -> void: Juego.sospecha = v)

	func _pagina_mundo() -> void:
		titulo("Hora del día")
		_hora = deslizador("Hora", Juego.hora, 0.0, 23.99, 0.05, "%d h", 1.0, func(v: float) -> void: Juego.hora = v)
		var f_vel: HBoxContainer = fila("Velocidad del tiempo")
		for par in [["Pausa", 0.0], ["Normal", 1.0], ["x10", 10.0], ["x60", 60.0]]:
			f_vel.add_child(UI.boton(par[0], func() -> void:
				Juego.velocidad_tiempo = par[1]
				Juego.avisar("Velocidad del tiempo: %s" % ("pausa" if par[1] == 0.0 else "x%d" % int(par[1])))))
		var f_mom: HBoxContainer = fila("Ir a")
		for par in [["Mañana", 8.0], ["Tarde", 17.0], ["Noche", 22.0]]:
			f_mom.add_child(UI.boton(par[0], func() -> void:
				Juego.hora = par[1]
				_hora.set_value_no_signal(par[1])))
		deslizador("Duración de un día (minutos reales)", Juego.duracion_dia_min, 2.0, 240.0, 1.0, "%d min", 1.0, func(v: float) -> void:
			Juego.duracion_dia_min = v, "Lo normal son %d." % int(Juego.DURACION_DIA_POR_DEFECTO))
		titulo("Clima")
		var f_clima: HBoxContainer = fila("Tiempo")
		for id in Clima.TIPOS:
			f_clima.add_child(UI.boton(String(Clima.TIPOS[id]["nombre"]), func() -> void: Clima.poner(id, 6.0)))
		titulo("Sonido")
		deslizador("Música", Musica.volumen_musica, 0.0, 1.0, 0.05, "%d %%", 100.0, func(v: float) -> void:
			Musica.volumen_musica = v
			Musica.guardar_opciones())
		deslizador("Ambiente", Musica.volumen_ambiente, 0.0, 1.0, 0.05, "%d %%", 100.0, func(v: float) -> void:
			Musica.volumen_ambiente = v
			Musica.guardar_opciones())

	func _pagina_vehiculos() -> void:
		titulo("Vehículo")
		nota_fila("Aparece a 1 m de ti, mirando hacia donde miras.")
		var f_veh: HBoxContainer = fila("Tipo de vehículo")
		_lista_vehiculos = OptionButton.new()
		_lista_vehiculos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for tipo_v in Vehiculo.TIPOS:
			_lista_vehiculos.add_item(str(Vehiculo.TIPOS[tipo_v]["nombre"]))
			_lista_vehiculos.set_item_metadata(_lista_vehiculos.item_count - 1, tipo_v)
		f_veh.add_child(_lista_vehiculos)
		f_veh.add_child(UI.boton("Aparecer", _aparecer_vehiculo, "BotonPrimario"))
		titulo("Efectos de pociones")
		var f_efecto: HBoxContainer = fila("Efecto")
		var lista_efectos: OptionButton = OptionButton.new()
		lista_efectos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for id_e in Juego.DatosEfectos.LISTA:
			lista_efectos.add_item(Juego.DatosEfectos.nombre(id_e))
			lista_efectos.set_item_metadata(lista_efectos.item_count - 1, id_e)
		f_efecto.add_child(lista_efectos)
		f_efecto.add_child(UI.boton("Aplicar 2 min", func() -> void:
			var id_e: String = lista_efectos.get_item_metadata(lista_efectos.selected)
			Juego.aplicar_efecto(id_e, 120.0, 1.0)))
		f_efecto.add_child(UI.boton("Quitar todos", func() -> void:
			Juego.efectos_activos.clear()
			Juego.efectos_cambiados.emit()))
		titulo("Recetas")
		boton_fila("Darme 3 pociones al azar (y descubrir su receta)", func() -> void:
			var ids_i: Array = GameData.Mezclas.INGREDIENTES.keys()
			var n: int = randi_range(2, GameData.Mezclas.max_ingredientes(Juego.nivel))
			var mezcla: Array = []
			for i in n:
				mezcla.append(ids_i.pick_random())
			var id_p: String = GameData.buscar_pocion(mezcla)
			Juego.anadir("pocion_" + id_p, 3)
			Juego.descubrir_receta(id_p)
			Juego.avisar("Te has dado 3 x %s." % GameData.pocion(id_p)["nombre"]))

	# Aparecer un vehículo delante de ti, mirando hacia donde miras.
	func _aparecer_vehiculo() -> void:
		var gestor: Node = get_tree().get_first_node_in_group("gestor_vehiculos")
		if gestor == null or jugador == null or _lista_vehiculos.selected < 0:
			Juego.avisar("No se puede crear el vehículo ahora.")
			return
		var tipo_v: String = str(_lista_vehiculos.get_item_metadata(_lista_vehiculos.selected))
		var giro: float = float(jugador.get("_giro"))
		var adelante: Vector3 = Basis(Vector3.UP, giro) * Vector3.FORWARD
		var largo: float = float(Vehiculo.TIPOS[tipo_v]["largo"])
		var hueco: float = 1.0 + largo / 2.0   # El morro queda a 1 m de ti.
		var p: Vector3 = jugador.global_position + adelante * hueco
		# Suelo bajo ese punto (rayo hacia abajo); si no hay, a la altura de tus pies.
		var espacio: PhysicsDirectSpaceState3D = jugador.get_world_3d().direct_space_state
		var rayo: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				p + Vector3(0, 3, 0), p - Vector3(0, 30, 0))
		var golpe: Dictionary = espacio.intersect_ray(rayo)
		p.y = float(golpe["position"].y) + 0.15 if not golpe.is_empty() else jugador.global_position.y
		var id_v: String = gestor.entregar(tipo_v, p, giro)
		Juego.avisar("Vehículo creado: %s (es tuyo, id %s)." % [Vehiculo.TIPOS[tipo_v]["nombre"], id_v])
