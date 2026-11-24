# ventana_partidas.gd
# -----------------------------------------------------------------------------
# La lista de ranuras de partida guardada (5). Se abre encima del menú de
# inicio o del de pausa:
#   modo INICIO -> "Jugar" (carga la ranura, o empieza una nueva si está vacía) y "Borrar".
#   modo PAUSA  -> "Guardar aquí", "Cargar" y "Borrar".
# Borrar y sobrescribir piden una segunda pulsación para confirmar.
# "al_elegir" se llama cuando se ha cargado o empezado una partida (el menú de debajo se cierra).
# -----------------------------------------------------------------------------
class_name VentanaPartidas
extends Ventana

enum Modo { INICIO, PAUSA }

var modo: Modo = Modo.INICIO
var jugador: Node3D = null
var al_elegir: Callable = Callable()

var _caja: VBoxContainer
var _aviso: Label
var _filas: VBoxContainer
var _confirmar: String = ""   # "borrar:3" o "guardar:2": la acción que espera confirmación.


func construir() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pistas_extra = []
	var cuerpo: VBoxContainer = marco("Partidas guardadas" if modo == Modo.INICIO else "Guardar y cargar",
			"%d ranuras" % Guardado.NUM_RANURAS, Vector2(860, 600))
	_caja = cuerpo
	var desplazable: ScrollContainer = ScrollContainer.new()
	desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desplazable.follow_focus = true
	cuerpo.add_child(desplazable)
	_filas = VBoxContainer.new()
	_filas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filas.add_theme_constant_override("separation", 8)
	desplazable.add_child(_filas)
	_aviso = UI.parrafo("", Tema.ACENTO)
	cuerpo.add_child(_aviso)
	_rellenar()


static func texto_resumen(n: int) -> String:
	var r: Dictionary = Guardado.resumen(n)
	if r.is_empty():
		return "Ranura %d:  vacía" % n
	if r.has("roto"):
		return "Ranura %d:  archivo dañado" % n
	var t: String = "Ranura %d:  Día %d  ·  Nivel %d  ·  %d $" % [n, r["dia"], r["nivel"], r["dinero"]]
	if str(r["fecha"]) != "":
		t += "   (%s)" % str(r["fecha"]).replace("T", " ")
	return t


func _rellenar() -> void:
	for h in _filas.get_children():
		_filas.remove_child(h)
		h.queue_free()
	for n in range(1, Guardado.NUM_RANURAS + 1):
		_filas.add_child(_tarjeta(n))


func _tarjeta(n: int) -> Control:
	var r: Dictionary = Guardado.resumen(n)
	var existe: bool = Guardado.existe(n)
	var t: PanelContainer = UI.tarjeta(n == Guardado.ranura)
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	t.add_child(fila)
	var numero: Label = UI.etiqueta(str(n), "Titulo", Tema.ACENTO if existe else Tema.TEXTO_TENUE, 30)
	numero.custom_minimum_size.x = 40
	numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numero.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(numero)
	var textos: VBoxContainer = VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 3)
	fila.add_child(textos)
	if not existe or r.is_empty():
		textos.add_child(UI.etiqueta("Ranura vacía", "", Tema.TEXTO_SUAVE, 18))
		textos.add_child(UI.nota("Aquí empezará una partida nueva."))
	elif r.has("roto"):
		textos.add_child(UI.etiqueta("Archivo dañado", "", Tema.PELIGRO, 18))
		textos.add_child(UI.nota("Se puede borrar para liberar la ranura."))
	else:
		var cab: HBoxContainer = HBoxContainer.new()
		cab.add_theme_constant_override("separation", 8)
		textos.add_child(cab)
		cab.add_child(UI.etiqueta("Día %d  ·  Nivel %d" % [r["dia"], r["nivel"]], "", Tema.TEXTO, 18))
		if n == Guardado.ranura:
			cab.add_child(UI.insignia("EN USO", Tema.ACENTO))
		var linea: String = UI.dinero(int(r["dinero"]))
		if str(r["fecha"]) != "":
			linea += "   ·   " + str(r["fecha"]).replace("T", " ").substr(0, 16)
		textos.add_child(UI.nota(linea))
	var botones: HBoxContainer = HBoxContainer.new()
	botones.add_theme_constant_override("separation", 8)
	botones.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(botones)
	if modo == Modo.INICIO:
		botones.add_child(_boton("Jugar" if existe else "Nueva", func(): _jugar(n), "BotonPrimario"))
	else:
		botones.add_child(_boton("¿Sobrescribir?" if _confirmar == "guardar:%d" % n else "Guardar aquí", func(): _guardar(n), "BotonPrimario"))
		var cargar: Button = _boton("Cargar", func(): _cargar(n))
		cargar.disabled = not existe
		botones.add_child(cargar)
	var borrar: Button = _boton("¿Seguro?" if _confirmar == "borrar:%d" % n else "Borrar", func(): _borrar(n), "BotonPeligro")
	borrar.disabled = not existe
	botones.add_child(borrar)
	return t


func _boton(texto: String, accion: Callable, variacion: String = "") -> Button:
	var b: Button = UI.boton(texto, accion, variacion)
	b.custom_minimum_size = Vector2(130, 40)
	return b


func _jugar(n: int) -> void:
	_confirmar = ""
	if Guardado.existe(n):
		if Guardado.cargar(get_tree(), jugador, n):
			Juego.avisar("Partida %d cargada." % n)
			_terminar()
		else:
			_aviso.text = "No se pudo cargar la ranura %d." % n
	else:
		Juego.reiniciar()
		Guardado.ranura = n
		Juego.avisar("Nueva partida en la ranura %d." % n)
		_terminar()


func _guardar(n: int) -> void:
	if Guardado.existe(n) and _confirmar != "guardar:%d" % n:
		_confirmar = "guardar:%d" % n
		_aviso.text = "La ranura %d ya tiene una partida. Pulsa otra vez para sobrescribirla." % n
		_rellenar()
		return
	_confirmar = ""
	_aviso.text = "Partida guardada en la ranura %d." % n if Guardado.guardar(get_tree(), jugador, n) else "No se pudo guardar."
	_rellenar()


func _cargar(n: int) -> void:
	_confirmar = ""
	if Guardado.cargar(get_tree(), jugador, n):
		Juego.avisar("Partida %d cargada." % n)
		_terminar()
	else:
		_aviso.text = "No se pudo cargar la ranura %d." % n


func _borrar(n: int) -> void:
	if _confirmar != "borrar:%d" % n:
		_confirmar = "borrar:%d" % n
		_aviso.text = "Pulsa otra vez para borrar la ranura %d. No se puede deshacer." % n
		_rellenar()
		return
	_confirmar = ""
	_aviso.text = "Ranura %d borrada." % n if Guardado.borrar(n) else "No se pudo borrar."
	_rellenar()


func _terminar() -> void:
	if al_elegir.is_valid():
		al_elegir.call()
	cerrar()
