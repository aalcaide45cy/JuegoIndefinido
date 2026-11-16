# minijuego_plantar.gd
# -----------------------------------------------------------------------------
# El minijuego que aparece al plantar en una maceta vacía. Cuatro pasos:
#   1. TIERRA:  mantén pulsado para echar tierra y para dentro de la franja verde.
#   2. SEMILLA: elige semilla y suéltala cuando esté encima del agujero.
#   3. AGUA:    mantén pulsado para regar; ni poco ni demasiado (franja verde).
#   4. ABONO:   opcional, si tienes. Crece más rápido y da una hierba más.
# Cada paso da una nota de 0 a 1; la media es la calidad de la planta, y la
# calidad decide cuántas hierbas cosecharás.
#
# "Pulsar" es el botón izquierdo del ratón sobre la maceta o la barra ESPACIO.
# Si cancelas, no se gasta nada.
# -----------------------------------------------------------------------------
class_name MinijuegoPlantar
extends Control

signal terminado   # Se emite al cerrar (el HUD devuelve el control al jugador).

enum Paso { TIERRA, SEMILLA, AGUA, ABONO, RESULTADO }

# Franjas buenas (de 0 = vacío a 1 = hasta arriba).
const FRANJA_TIERRA: Vector2 = Vector2(0.68, 0.84)
const FRANJA_AGUA: Vector2 = Vector2(0.55, 0.75)
const VELOCIDAD_TIERRA: float = 0.45
const VELOCIDAD_AGUA: float = 0.38

var maceta: Maceta3D

var _paso: Paso = Paso.TIERRA
var _tierra: float = 0.0
var _agua: float = 0.0
var _semilla: String = ""
var _semilla_soltada: bool = false
var _pos_semilla: float = 0.0    # De -1 (izquierda) a 1 (derecha); 0 = el agujero.
var _caida: float = 0.0          # Animación de la semilla cayendo.
var _con_abono: bool = false
var _notas: Array[float] = []
var _vertiendo: bool = false
var _espacio_antes: bool = false
var _tiempo: float = 0.0

var _titulo: Label
var _explicacion: Label
var _lienzo: Control
var _botones: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Fondo oscuro semitransparente que tapa el juego.
	var fondo: ColorRect = ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var panel: PanelContainer = Hud.crear_panel()
	Hud.centrar(panel, Vector2(620, 560))
	add_child(panel)
	var caja: VBoxContainer = VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	panel.add_child(caja)

	_titulo = Hud.crear_label(26, Color(0.6, 0.9, 0.6))
	caja.add_child(_titulo)
	_explicacion = Hud.crear_label(17)
	_explicacion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_explicacion.custom_minimum_size = Vector2(580, 50)
	caja.add_child(_explicacion)

	_lienzo = Control.new()
	_lienzo.custom_minimum_size = Vector2(580, 320)
	_lienzo.mouse_filter = Control.MOUSE_FILTER_STOP
	_lienzo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_lienzo.draw.connect(_dibujar)
	_lienzo.gui_input.connect(_raton_en_lienzo)
	caja.add_child(_lienzo)

	_botones = HBoxContainer.new()
	_botones.alignment = BoxContainer.ALIGNMENT_CENTER
	_botones.add_theme_constant_override("separation", 12)
	caja.add_child(_botones)

	_ir_a(Paso.TIERRA)


func _process(delta: float) -> void:
	_tiempo += delta
	var espacio: bool = Input.is_physical_key_pressed(KEY_SPACE)
	var pulsado: bool = _vertiendo or espacio
	var espacio_recien: bool = espacio and not _espacio_antes
	_espacio_antes = espacio

	match _paso:
		Paso.TIERRA:
			if pulsado:
				_tierra = minf(1.0, _tierra + VELOCIDAD_TIERRA * delta)
		Paso.AGUA:
			if pulsado:
				_agua = minf(1.0, _agua + VELOCIDAD_AGUA * delta)
		Paso.SEMILLA:
			if _semilla != "" and not _semilla_soltada:
				_pos_semilla = sin(_tiempo * 2.6)
				if espacio_recien:
					_soltar_semilla()
			elif _semilla_soltada:
				_caida = minf(1.0, _caida + delta * 2.5)
	_lienzo.queue_redraw()


func _raton_en_lienzo(evento: InputEvent) -> void:
	var boton: InputEventMouseButton = evento as InputEventMouseButton
	if boton == null or boton.button_index != MOUSE_BUTTON_LEFT:
		return
	_vertiendo = boton.pressed
	if boton.pressed and _paso == Paso.SEMILLA and _semilla != "" and not _semilla_soltada:
		_soltar_semilla()


# --------------------------------- Pasos --------------------------------------

func _ir_a(paso: Paso) -> void:
	_paso = paso
	_vertiendo = false
	for b in _botones.get_children():
		b.queue_free()
	match paso:
		Paso.TIERRA:
			_titulo.text = "1/4  Echa la tierra"
			_explicacion.text = "Mantén pulsado el ratón sobre la maceta (o ESPACIO) para echar tierra. Suelta cuando llegue a la franja verde. ¡Si te pasas, se desborda!"
			_boton("Listo", _terminar_tierra)
		Paso.SEMILLA:
			_titulo.text = "2/4  Planta la semilla"
			_explicacion.text = "Elige qué semilla plantar:"
			for id_hierba in GameData.HIERBAS:
				var id_objeto: String = "semilla_" + id_hierba
				if Juego.tiene(id_objeto):
					_boton("%s (%d)" % [Juego.DatosObjetos.nombre(id_objeto), Juego.cuenta(id_objeto)],
							_elegir_semilla.bind(id_hierba))
		Paso.AGUA:
			_titulo.text = "3/4  Riega"
			_explicacion.text = "Mantén pulsado para echar agua con la jarra. La tierra tiene que quedar húmeda (franja verde), no encharcada."
			_boton("Listo", _terminar_agua)
		Paso.ABONO:
			_titulo.text = "4/4  Abono (opcional)"
			_explicacion.text = "El abono hace que crezca más rápido y dé una hierba más."
			_boton("Echar abono (tienes %d)" % Juego.cuenta("abono"), _elegir_abono.bind(true))
			_boton("Sin abono", _elegir_abono.bind(false))
		Paso.RESULTADO:
			var nota: float = _nota_media()
			var cosecha: int = 1 + int(nota >= 0.45) + int(nota >= 0.8) + int(_con_abono)
			_titulo.text = "¡Plantado!"
			_explicacion.text = "Calidad: %d%%. Cuando crezca cosecharás %d %s." % [
					int(nota * 100), cosecha, GameData.HIERBAS[_semilla]["nombre"]]
			_boton("Hecho", _finalizar)
	if paso != Paso.RESULTADO:
		_boton("Cancelar", cerrar)


func _terminar_tierra() -> void:
	if _tierra < 0.1:
		_explicacion.text = "Todavía no has echado tierra. Mantén pulsado sobre la maceta."
		return
	_notas.append(_nota_franja(_tierra, FRANJA_TIERRA))
	_ir_a(Paso.SEMILLA)


func _elegir_semilla(id_hierba: String) -> void:
	_semilla = id_hierba
	for b in _botones.get_children():
		b.queue_free()
	_boton("Cancelar", cerrar)
	_explicacion.text = "La semilla se mueve de lado a lado. Haz clic (o ESPACIO) cuando esté justo encima del agujero."


func _soltar_semilla() -> void:
	_semilla_soltada = true
	_notas.append(clampf(1.0 - absf(_pos_semilla) / 0.6, 0.0, 1.0))
	var acierto: String = "¡Justo en el agujero!" if absf(_pos_semilla) < 0.15 else "Ha caído un poco desviada."
	_explicacion.text = acierto
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if is_inside_tree():
			_ir_a(Paso.AGUA))


func _terminar_agua() -> void:
	if _agua < 0.1:
		_explicacion.text = "La tierra sigue seca. Mantén pulsado para regar."
		return
	_notas.append(_nota_franja(_agua, FRANJA_AGUA))
	if Juego.tiene("abono"):
		_ir_a(Paso.ABONO)
	else:
		_ir_a(Paso.RESULTADO)


func _elegir_abono(usar_abono: bool) -> void:
	_con_abono = usar_abono
	_ir_a(Paso.RESULTADO)


# Gasta los materiales y planta de verdad.
func _finalizar() -> void:
	# Se comprueba otra vez por si algo ha cambiado mientras jugabas el minijuego.
	if not Juego.tiene("tierra") or not Juego.tiene("semilla_" + _semilla) \
			or (_con_abono and not Juego.tiene("abono")):
		Juego.avisar("Te falta algún material: no se ha plantado nada.")
		cerrar()
		return
	Juego.quitar("tierra")
	Juego.quitar("semilla_" + _semilla)
	if _con_abono:
		Juego.quitar("abono")
	var recipiente = Juego.recipiente_de_agua()
	var quedan: int = 0
	if recipiente != null:
		recipiente["agua"] -= 1
		quedan = recipiente["agua"]
	Juego.cambio.emit()
	maceta.plantar(_semilla, _nota_media(), _con_abono)
	Juego.ganar_xp(10)
	Juego.avisar("Has plantado %s. Te quedan %d riegos en el recipiente." % [
			GameData.HIERBAS[_semilla]["nombre"], quedan])
	cerrar()


func cerrar() -> void:
	terminado.emit()
	queue_free()


# ------------------------------- Notas ----------------------------------------

# 1 si el valor está dentro de la franja; baja cuanto más lejos esté.
func _nota_franja(valor: float, franja: Vector2) -> float:
	if valor >= franja.x and valor <= franja.y:
		return 1.0
	var distancia: float = franja.x - valor if valor < franja.x else valor - franja.y
	return clampf(1.0 - distancia / 0.35, 0.0, 1.0)


func _nota_media() -> float:
	if _notas.is_empty():
		return 0.0
	var suma: float = 0.0
	for n in _notas:
		suma += n
	return suma / _notas.size()


func _boton(texto: String, al_pulsar: Callable) -> void:
	var b: Button = Hud.crear_boton(texto, al_pulsar)
	_botones.add_child(b)


# ------------------------------- Dibujo ---------------------------------------
# La maceta vista de lado, en el centro del lienzo.

func _dibujar() -> void:
	var c: float = _lienzo.size.x / 2.0
	var arriba: float = 80.0
	var abajo: float = 300.0
	var ancho_arriba: float = 240.0
	var ancho_abajo: float = 170.0
	var alto_util: float = abajo - arriba - 10.0

	# Interior de la maceta (oscuro) y los bordes de barro.
	var interior: PackedVector2Array = [Vector2(c - ancho_arriba / 2, arriba), Vector2(c + ancho_arriba / 2, arriba),
			Vector2(c + ancho_abajo / 2, abajo), Vector2(c - ancho_abajo / 2, abajo)]
	_lienzo.draw_colored_polygon(interior, Color(0.08, 0.06, 0.05))

	# Tierra: rellena desde abajo hasta su nivel. Se oscurece al mojarse.
	if _tierra > 0.0:
		var y_tierra: float = abajo - _tierra * alto_util
		var ancho_nivel: float = lerpf(ancho_abajo, ancho_arriba, (abajo - y_tierra) / (abajo - arriba))
		var color_tierra: Color = Color(0.4, 0.27, 0.17).darkened(_agua * 0.6)
		var relleno: PackedVector2Array = [Vector2(c - ancho_nivel / 2, y_tierra), Vector2(c + ancho_nivel / 2, y_tierra),
				Vector2(c + ancho_abajo / 2, abajo), Vector2(c - ancho_abajo / 2, abajo)]
		_lienzo.draw_colored_polygon(relleno, color_tierra)
		# Agujero para la semilla.
		if _paso == Paso.SEMILLA:
			_lienzo.draw_circle(Vector2(c, y_tierra + 6), 10.0, Color(0.1, 0.07, 0.05))
		# Agua encharcada por encima si te pasas.
		if _agua > FRANJA_AGUA.y:
			var charco: float = (_agua - FRANJA_AGUA.y) * 60.0
			_lienzo.draw_rect(Rect2(c - ancho_nivel / 2 + 4, y_tierra - charco, ancho_nivel - 8, charco),
					Color(0.3, 0.45, 0.7, 0.7))

	# Borde de la maceta.
	_lienzo.draw_polyline(interior + PackedVector2Array([interior[0]]), Color(0.6, 0.35, 0.22), 8.0)

	# Franja verde del paso actual.
	if _paso == Paso.TIERRA:
		var y0: float = abajo - FRANJA_TIERRA.y * alto_util
		var y1: float = abajo - FRANJA_TIERRA.x * alto_util
		_lienzo.draw_rect(Rect2(c - ancho_arriba / 2 - 30, y0, ancho_arriba + 60, y1 - y0), Color(0.3, 0.9, 0.4, 0.25))
		_lienzo.draw_line(Vector2(c - ancho_arriba / 2 - 30, y0), Vector2(c + ancho_arriba / 2 + 30, y0), Color(0.4, 1, 0.5), 2)
		_lienzo.draw_line(Vector2(c - ancho_arriba / 2 - 30, y1), Vector2(c + ancho_arriba / 2 + 30, y1), Color(0.4, 1, 0.5), 2)
	elif _paso == Paso.AGUA:
		# Barra de humedad a la derecha.
		var bx: float = c + ancho_arriba / 2 + 50
		_lienzo.draw_rect(Rect2(bx, arriba, 30, abajo - arriba), Color(0.1, 0.1, 0.12))
		var yf0: float = abajo - FRANJA_AGUA.y * (abajo - arriba)
		var yf1: float = abajo - FRANJA_AGUA.x * (abajo - arriba)
		_lienzo.draw_rect(Rect2(bx - 6, yf0, 42, yf1 - yf0), Color(0.3, 0.9, 0.4, 0.35))
		var alto_agua: float = _agua * (abajo - arriba)
		_lienzo.draw_rect(Rect2(bx + 4, abajo - alto_agua, 22, alto_agua), Color(0.35, 0.55, 0.9))
		_lienzo.draw_string(get_theme_default_font(), Vector2(bx - 20, arriba - 10), "Humedad",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.85, 0.9))

	# Chorro de tierra o de agua mientras pulsas.
	var pulsado: bool = _vertiendo or Input.is_physical_key_pressed(KEY_SPACE)
	if pulsado and (_paso == Paso.TIERRA or _paso == Paso.AGUA):
		var color_chorro: Color = Color(0.4, 0.27, 0.17) if _paso == Paso.TIERRA else Color(0.4, 0.6, 0.95, 0.8)
		var y_fin: float = abajo - (_tierra if _paso == Paso.TIERRA else _tierra) * alto_util
		var temblor: float = sin(_tiempo * 40.0) * 2.0
		_lienzo.draw_rect(Rect2(c - 8 + temblor, 0, 16, y_fin), color_chorro)

	# La semilla moviéndose (o cayendo).
	if _paso == Paso.SEMILLA and _semilla != "":
		var y_tierra2: float = abajo - _tierra * alto_util
		var x: float = c + _pos_semilla * (ancho_arriba / 2.0 - 20.0)
		var y: float = lerpf(30.0, y_tierra2 + 4, _caida)
		_lienzo.draw_circle(Vector2(x, y), 9.0, GameData.HIERBAS[_semilla]["color"].lightened(0.3))
		if not _semilla_soltada:
			_lienzo.draw_line(Vector2(c, 45), Vector2(c, y_tierra2 - 4), Color(1, 1, 1, 0.15), 2)
