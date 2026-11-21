# ventana_graficos.gd
# -----------------------------------------------------------------------------
# El menú de gráficos (Esc > Gráficos, o desde el menú de inicio). Cada opción
# cambia el ajuste en el autoload Graficos, que lo aplica y lo guarda al
# momento. Las opciones que el renderizador actual no puede dar (SSAO, SSR,
# niebla volumétrica, SDFGI) salen apagadas con el aviso "solo Forward+".
# -----------------------------------------------------------------------------
class_name VentanaGraficos
extends Ventana

var _lista: VBoxContainer
var _aviso: Label
var _scroll: ScrollContainer


func construir() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Panel propio (sin el desplazamiento de panel_centrado): esta ventana ya trae su ScrollContainer,
	# y uno dentro de otro dejaba la lista con altura 0 (solo se veía el título).
	var panel: PanelContainer = Hud.crear_panel()
	Hud.centrar(panel, Vector2(900, 700), espacio_visible())
	add_child(panel)
	var caja: VBoxContainer = VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	panel.add_child(caja)
	cabecera(caja, "Gráficos  (renderizador: %s)" % Graficos.nombre_renderizador())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(_scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	_scroll.add_child(_lista)
	_aviso = Hud.crear_label(16, Color(1, 0.92, 0.6))
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_aviso)
	_rellenar()


func _rellenar() -> void:
	var pos: int = _scroll.scroll_vertical
	for h in _lista.get_children():
		h.queue_free()
	var G: Node = Graficos
	# --- General
	_titulo("General")
	var nombres: Array = ["Bajo", "Medio", "Alto", "Ultra", "Personalizado"]
	_opcion("Preset", nombres, nombres.find(String(G.v["preset"])), func(i: int) -> void:
		if nombres[i] == "Personalizado":
			return
		G.aplicar_preset(nombres[i])
		if nombres[i] == "Ultra" and not G.forward:
			_decir("Ultra luce mejor con Forward+ (SSAO, SSR, niebla volumétrica, SDFGI): actívalo abajo y reinicia.")
		_rellenar())
	_opcion("Renderizador", ["Compatibilidad (ligero)", "Forward+ (alto, reinicia el juego)"],
			1 if G.quiere_forward() else 0, func(i: int) -> void:
		G.poner("renderizador", "forward" if i == 1 else "compat", false)
		_rellenar()
		if G.quiere_forward() != G.forward:
			_decir("Cambiar de renderizador reinicia el juego. Guarda la partida antes y pulsa «Reiniciar ahora».")
			_boton("Reiniciar ahora", func() -> void: G.reiniciar()))
	# --- Pantalla
	_titulo("Pantalla")
	_opcion("Modo", G.NOM_MODO, int(G.v["modo_ventana"]), func(i: int) -> void: G.poner("modo_ventana", i, false))
	var res_txt: Array = []
	var res_val: Array = []
	var pantalla: Vector2i = DisplayServer.screen_get_size()
	for r in G.RESOLUCIONES:
		if r.x <= pantalla.x and r.y <= pantalla.y:
			res_txt.append("%d x %d" % [r.x, r.y])
			res_val.append("%dx%d" % [r.x, r.y])
	var actual: int = maxi(0, res_val.find(String(G.v["resolucion"])))
	_opcion("Resolución (modo ventana)", res_txt, actual, func(i: int) -> void: G.poner("resolucion", res_val[i], false))
	_opcion("Sincronía vertical (VSync)", G.NOM_VSYNC, int(G.v["vsync"]), func(i: int) -> void: G.poner("vsync", i, false))
	var fps_txt: Array = []
	for f in G.LIMITES_FPS:
		fps_txt.append("Sin límite" if f == 0 else "%d FPS" % f)
	_opcion("Límite de FPS", fps_txt, maxi(0, G.LIMITES_FPS.find(int(G.v["fps_max"]))),
			func(i: int) -> void: G.poner("fps_max", G.LIMITES_FPS[i], false))
	_deslizador("Escala de render (3D)", "escala", 0.5, 1.5, 0.05, "%d %%", 100.0)
	_opcion("Método de escalado", G.NOM_ESCALADO, int(G.v["escalado"]), func(i: int) -> void:
		G.poner("escalado", i)
		if i == 2 and not G.forward:
			_decir("FSR 2 solo existe en Forward+; mientras tanto se usa FSR 1."))
	_opcion("Antialiasing", G.NOM_AA, int(G.v["aa"]), func(i: int) -> void:
		G.poner("aa", i)
		if i == 5 and not G.forward:
			_decir("TAA solo funciona en Forward+."))
	# --- Mundo
	_titulo("Mundo")
	_opcion("Calidad de sombras", G.SOMBRAS, int(G.v["sombras"]), func(i: int) -> void: G.poner("sombras", i))
	_opcion("Distancia de dibujado", G.NOM_DIST, int(G.v["dist_dibujado"]), func(i: int) -> void: G.poner("dist_dibujado", i))
	_opcion("Distancia de carga de trozos", G.NOM_TROZOS, int(G.v["trozos"]), func(i: int) -> void: G.poner("trozos", i))
	_opcion("Densidad de vegetación", G.NOM_VEG, int(G.v["vegetacion"]), func(i: int) -> void:
		G.poner("vegetacion", i)
		G.recargar_mundo())
	_opcion("Densidad de peatones", G.NOM_GENTE, int(G.v["peatones"]), func(i: int) -> void: G.poner("peatones", i))
	_opcion("Densidad de tráfico", G.NOM_GENTE, int(G.v["trafico"]), func(i: int) -> void: G.poner("trafico", i))
	# --- Efectos
	_titulo("Efectos")
	_casilla("Brillo de luces (glow)", "glow")
	_casilla("SSAO (oclusión ambiental)", "ssao")
	_casilla("SSR (reflejos en pantalla)", "ssr")
	_casilla("Niebla volumétrica", "niebla_vol")
	_casilla("SDFGI (luz global)", "sdfgi")
	# --- Imagen
	_titulo("Imagen")
	_deslizador("Campo de visión (FOV)", "fov", 50.0, 110.0, 1.0, "%d°", 1.0)
	_deslizador("Brillo", "brillo", 0.5, 1.6, 0.05, "%d %%", 100.0)
	_casilla("Contador de FPS (también con F3)", "contador_fps")
	_scroll.set_deferred("scroll_vertical", pos)


func _decir(t: String) -> void:
	_aviso.text = t


func _titulo(t: String) -> void:
	var l: Label = Hud.crear_label(20, Color(0.6, 0.9, 0.6))
	l.text = t
	_lista.add_child(l)


func _fila(texto: String) -> HBoxContainer:
	var f: HBoxContainer = HBoxContainer.new()
	f.add_theme_constant_override("separation", 12)
	var l: Label = Hud.crear_label(17, Color(0.9, 0.92, 0.88))
	l.text = texto
	l.custom_minimum_size.x = 300
	f.add_child(l)
	_lista.add_child(f)
	return f


func _opcion(texto: String, etiquetas: Array, elegido: int, al_cambiar: Callable) -> void:
	var f: HBoxContainer = _fila(texto)
	var o: OptionButton = OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.add_theme_font_size_override("font_size", 16)
	for t in etiquetas:
		o.add_item(String(t))
	o.select(elegido)
	o.item_selected.connect(al_cambiar)
	f.add_child(o)


func _casilla(texto: String, clave: String) -> void:
	var libre: bool = Graficos.disponible(clave)
	var f: HBoxContainer = _fila(texto + ("" if libre else "  (solo Forward+)"))
	var c: CheckBox = CheckBox.new()
	c.button_pressed = bool(Graficos.v[clave]) and libre
	c.disabled = not libre
	c.toggled.connect(func(on: bool) -> void:
		Graficos.poner(clave, on, clave != "contador_fps"))
	f.add_child(c)


func _deslizador(texto: String, clave: String, minimo: float, maximo: float, paso: float,
		formato: String, mult: float) -> void:
	var f: HBoxContainer = _fila(texto)
	var s: HSlider = HSlider.new()
	s.min_value = minimo
	s.max_value = maximo
	s.step = paso
	s.value = float(Graficos.v[clave])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size.y = 28
	f.add_child(s)
	var val: Label = Hud.crear_label(17, Color(1, 0.92, 0.6))
	val.custom_minimum_size.x = 70
	val.text = formato % int(roundf(s.value * mult))
	f.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		val.text = formato % int(roundf(x * mult))
		Graficos.poner(clave, x, clave == "escala"))


func _boton(texto: String, al_pulsar: Callable) -> void:
	_lista.add_child(Hud.crear_boton(texto, al_pulsar))
