# ventana_graficos.gd
# -----------------------------------------------------------------------------
# El menú de gráficos (Esc > Gráficos, o desde el menú de inicio). Cada opción
# cambia el ajuste en el autoload Graficos, que lo aplica y lo guarda al
# momento. Las opciones que el renderizador actual no puede dar (SSAO, SSR,
# niebla volumétrica, SDFGI) salen apagadas con el aviso "solo Forward+".
# -----------------------------------------------------------------------------
class_name VentanaGraficos
extends VentanaOpciones


func construir() -> void:
	if incrustada:
		montar_incrustada()
	else:
		montar("Gráficos", Vector2(900, 700), "Renderizador: %s" % Graficos.nombre_renderizador())
	_rellenar()


func _rellenar() -> void:
	var pos: int = _desplazable.scroll_vertical
	vaciar()
	var G: Node = Graficos
	# --- General
	titulo("General")
	var nombres: Array = ["Bajo", "Medio", "Alto", "Ultra", "Personalizado"]
	opcion("Preset", nombres, nombres.find(String(G.v["preset"])), func(i: int) -> void:
		if nombres[i] == "Personalizado":
			return
		G.aplicar_preset(nombres[i])
		if nombres[i] == "Ultra" and not G.forward:
			_decir("Ultra luce mejor con Forward+ (SSAO, SSR, niebla volumétrica, SDFGI): actívalo abajo y reinicia.")
		_rellenar(), "Un solo ajuste que cambia todo lo demás.")
	opcion("Renderizador", ["Compatibilidad (ligero)", "Forward+ (alto, reinicia el juego)"],
			1 if G.quiere_forward() else 0, func(i: int) -> void:
		G.poner("renderizador", "forward" if i == 1 else "compat", false)
		_rellenar()
		if G.quiere_forward() != G.forward:
			_decir("Cambiar de renderizador reinicia el juego. Guarda la partida antes y pulsa «Reiniciar ahora».")
			boton_fila("Reiniciar ahora", func() -> void: G.reiniciar(), "BotonPeligro"))
	# --- Pantalla
	titulo("Pantalla")
	opcion("Modo", G.NOM_MODO, int(G.v["modo_ventana"]), func(i: int) -> void: G.poner("modo_ventana", i, false))
	var res_txt: Array = []
	var res_val: Array = []
	var pantalla: Vector2i = DisplayServer.screen_get_size()
	for r in G.RESOLUCIONES:
		if r.x <= pantalla.x and r.y <= pantalla.y:
			res_txt.append("%d x %d" % [r.x, r.y])
			res_val.append("%dx%d" % [r.x, r.y])
	var actual: int = maxi(0, res_val.find(String(G.v["resolucion"])))
	opcion("Resolución (modo ventana)", res_txt, actual, func(i: int) -> void: G.poner("resolucion", res_val[i], false))
	opcion("Sincronía vertical (VSync)", G.NOM_VSYNC, int(G.v["vsync"]), func(i: int) -> void: G.poner("vsync", i, false))
	var fps_txt: Array = []
	for f in G.LIMITES_FPS:
		fps_txt.append("Sin límite" if f == 0 else "%d FPS" % f)
	opcion("Límite de FPS", fps_txt, maxi(0, G.LIMITES_FPS.find(int(G.v["fps_max"]))),
			func(i: int) -> void: G.poner("fps_max", G.LIMITES_FPS[i], false))
	_deslizador("Escala de render (3D)", "escala", 0.5, 1.5, 0.05, "%d %%", 100.0)
	opcion("Método de escalado", G.NOM_ESCALADO, int(G.v["escalado"]), func(i: int) -> void:
		G.poner("escalado", i)
		if i == 2 and not G.forward:
			_decir("FSR 2 solo existe en Forward+; mientras tanto se usa FSR 1."))
	opcion("Antialiasing", G.NOM_AA, int(G.v["aa"]), func(i: int) -> void:
		G.poner("aa", i)
		if i == 5 and not G.forward:
			_decir("TAA solo funciona en Forward+."))
	# --- Mundo
	titulo("Mundo")
	opcion("Calidad de sombras", G.SOMBRAS, int(G.v["sombras"]), func(i: int) -> void: G.poner("sombras", i))
	opcion("Distancia de dibujado", G.NOM_DIST, int(G.v["dist_dibujado"]), func(i: int) -> void: G.poner("dist_dibujado", i))
	opcion("Distancia de carga de trozos", G.NOM_TROZOS, int(G.v["trozos"]), func(i: int) -> void: G.poner("trozos", i))
	opcion("Densidad de vegetación", G.NOM_VEG, int(G.v["vegetacion"]), func(i: int) -> void:
		G.poner("vegetacion", i)
		G.recargar_mundo())
	opcion("Densidad de peatones", G.NOM_GENTE, int(G.v["peatones"]), func(i: int) -> void: G.poner("peatones", i))
	opcion("Densidad de tráfico", G.NOM_GENTE, int(G.v["trafico"]), func(i: int) -> void: G.poner("trafico", i))
	# --- Efectos
	titulo("Efectos")
	_casilla("Brillo de luces (glow)", "glow")
	_casilla("SSAO (oclusión ambiental)", "ssao")
	_casilla("SSR (reflejos en pantalla)", "ssr")
	_casilla("Niebla volumétrica", "niebla_vol")
	_casilla("SDFGI (luz global)", "sdfgi")
	# --- Imagen
	titulo("Imagen")
	_deslizador("Campo de visión (FOV)", "fov", 50.0, 110.0, 1.0, "%d°", 1.0)
	_deslizador("Brillo", "brillo", 0.5, 1.6, 0.05, "%d %%", 100.0)
	_casilla("Contador de FPS (también con F3)", "contador_fps")
	# --- Violencia
	titulo("Violencia")
	opcion("Sangre y desmembramientos", G.NOM_GORE, int(G.v["gore"]), func(i: int) -> void: G.poner("gore", i, false))
	_casilla("Gritos de la gente", "gritos")
	filtrar(_filtro)
	_desplazable.set_deferred("scroll_vertical", pos)


func _decir(t: String) -> void:
	aviso.text = t


func _casilla(texto: String, clave: String) -> void:
	var libre: bool = Graficos.disponible(clave)
	var c: CheckButton = casilla(texto + ("" if libre else "  (solo Forward+)"), bool(Graficos.v[clave]) and libre,
			func(on: bool) -> void: Graficos.poner(clave, on, clave != "contador_fps"))
	c.disabled = not libre


func _deslizador(texto: String, clave: String, minimo: float, maximo: float, paso: float,
		formato: String, mult: float) -> void:
	deslizador(texto, float(Graficos.v[clave]), minimo, maximo, paso, formato, mult,
			func(x: float) -> void: Graficos.poner(clave, x, clave == "escala"))
