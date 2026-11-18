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
	_caja = panel_centrado(Vector2(860, 560))
	cabecera(_caja, "Partidas guardadas" if modo == Modo.INICIO else "Guardar y cargar")
	_filas = VBoxContainer.new()
	_filas.add_theme_constant_override("separation", 8)
	_caja.add_child(_filas)
	_aviso = Hud.crear_label(16, Color(1, 0.92, 0.6))
	_caja.add_child(_aviso)
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
		h.queue_free()
	for n in range(1, Guardado.NUM_RANURAS + 1):
		var fila: HBoxContainer = HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		_filas.add_child(fila)
		var etiqueta: Label = Hud.crear_label(18, Color(0.6, 0.9, 0.6) if n == Guardado.ranura else Color(0.9, 0.9, 0.85))
		etiqueta.text = texto_resumen(n)
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(etiqueta)
		var existe: bool = Guardado.existe(n)
		if modo == Modo.INICIO:
			fila.add_child(_boton("Jugar" if existe else "Nueva", func(): _jugar(n)))
		else:
			fila.add_child(_boton("¿Sobrescribir?" if _confirmar == "guardar:%d" % n else "Guardar aquí", func(): _guardar(n)))
			var cargar: Button = _boton("Cargar", func(): _cargar(n))
			cargar.disabled = not existe
			fila.add_child(cargar)
		var borrar: Button = _boton("¿Seguro?" if _confirmar == "borrar:%d" % n else "Borrar", func(): _borrar(n))
		borrar.disabled = not existe
		fila.add_child(borrar)


func _boton(texto: String, accion: Callable) -> Button:
	var b: Button = Hud.crear_boton(texto, accion)
	b.custom_minimum_size = Vector2(150, 40)
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
