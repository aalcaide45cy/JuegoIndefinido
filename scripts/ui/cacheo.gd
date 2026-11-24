# cacheo.gd
# -----------------------------------------------------------------------------
# Minijuego del cacheo: un guardia te registra. Tienes 6 segundos para esconder
# lo ilegal pulsando sobre cada montón (65% de éxito por intento). Al acabar el
# tiempo se confisca lo que no escondiste y te cobran una multa. Si no llevas
# nada ilegal, te dejan ir. SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name Cacheo
extends Ventana

const Economia = preload("res://scripts/datos/economia.gd")
const DatosObjetos = preload("res://scripts/datos/objetos.gd")
const TIEMPO: float = 6.0
const PROB_ESCONDER: float = 0.65
const TIPOS_ILEGALES: Array = ["pocion", "paquete", "hierba", "arma_fuego", "explosivo"]

var _resto: float = TIEMPO
var _estado: Dictionary = {}   # indice -> "escondido" | "visible" | ""
var _etiqueta: Label
var _lista: VBoxContainer
var _acabado: bool = false


func construir() -> void:
	var caja: VBoxContainer = marco("¡Cacheo!", "El guardia revisa tus cosas", Vector2(560, 520))
	caja.add_child(UI.nota("Esconde lo ilegal antes de que acabe el tiempo."))
	_etiqueta = UI.etiqueta("", "Titulo", Tema.PELIGRO, 26)
	caja.add_child(_etiqueta)
	var desplazable: ScrollContainer = ScrollContainer.new()
	desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desplazable.follow_focus = true
	caja.add_child(desplazable)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	desplazable.add_child(_lista)
	_pintar()


# Cerrar la ventana (Esc o el botón) no libra del cacheo: se resuelve en ese momento
# con lo que hayas conseguido esconder. Antes bastaba pulsar Esc para irse de rositas.
func cerrar() -> void:
	if not _acabado:
		_terminar()
	super()


func _ilegales() -> Array:
	var r: Array = []
	for i in Juego.inventario.size():
		var c = Juego.inventario[i]
		if c != null and DatosObjetos.datos(c["id"])["tipo"] in TIPOS_ILEGALES:
			r.append(i)
	return r


func _pintar() -> void:
	for h in _lista.get_children():
		h.queue_free()
	var hay: bool = false
	for i in _ilegales():
		hay = true
		var c = Juego.inventario[i]
		var e: String = _estado.get(i, "")
		var texto: String = "%d x %s" % [c["cantidad"], DatosObjetos.nombre(c["id"])]
		if e == "escondido":
			texto += "   (escondido)"
		elif e == "visible":
			texto += "   (¡lo ven!)"
		var b: Button = UI.boton("Esconder: " + texto, _esconder.bind(i), "BotonSuave")
		b.disabled = e != ""
		_lista.add_child(b)
	if not hay:
		_lista.add_child(UI.nota("No llevas nada ilegal. Con suerte te dejan ir."))


func _esconder(i: int) -> void:
	if _acabado or _estado.get(i, "") != "":
		return
	_estado[i] = "escondido" if randf() < PROB_ESCONDER else "visible"
	_pintar()


func _process(delta: float) -> void:
	if _acabado:
		return
	_resto -= delta
	_etiqueta.text = "Tiempo: %.1f s" % maxf(0.0, _resto)
	if _resto <= 0.0:
		_terminar()


func _terminar() -> void:
	_acabado = true
	var confiscados: int = 0
	var unidades: int = 0
	for i in _ilegales():
		if _estado.get(i, "") == "escondido":
			continue
		var c = Juego.inventario[i]
		unidades += int(c["cantidad"])
		confiscados += 1
		Juego.inventario[i] = null
	# Solo hay multa si encuentran algo: antes también cobraban el % del dinero cuando "no
	# encuentran nada y te dejan ir".
	var multa: int = 0
	if confiscados > 0:
		multa = mini(Juego.dinero, 20 * confiscados + 5 * unidades + int(Juego.dinero * Economia.MULTA_CACHEO_PORCENTAJE))
	Juego.dinero -= multa
	Juego.cambio.emit()
	for h in _lista.get_children():
		h.queue_free()
	if confiscados == 0:
		subtitulo(_lista, "El guardia no encuentra nada y te deja ir.")
		Juego.avisar("El cacheo terminó sin problemas.")
	else:
		subtitulo(_lista, "Te confiscan %d montón(es) y te cobran una multa de %d $." % [confiscados, multa])
		Juego.avisar("Cacheo: confiscado lo ilegal y multa de %d $." % multa)
