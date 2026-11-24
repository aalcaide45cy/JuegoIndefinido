# ventana_controles.gd
# -----------------------------------------------------------------------------
# Esc > "Controles…": sensibilidad del ratón y del mando, invertir el eje vertical, activar el
# mando y reasignar las teclas (pulsa "Cambiar" y luego la tecla nueva; Esc cancela).
# Todo lo guarda la autocarga Controles (user://controles.cfg).
# -----------------------------------------------------------------------------
class_name VentanaControles
extends VentanaOpciones

var _esperando: String = ""        # Acción que espera tecla nueva ("" = ninguna).
var _botones: Dictionary = {}      # acción -> Button


func construir() -> void:
	montar("Controles", Vector2(900, 760))
	_rellenar()


func _rellenar() -> void:
	vaciar()
	_botones.clear()
	titulo("Ratón y mando")
	deslizador("Sensibilidad del ratón", Controles.sensibilidad_raton, 0.2, 3.0, 0.05, "%d %%", 100.0, func(x: float) -> void:
		Controles.sensibilidad_raton = x
		Controles.guardar())
	deslizador("Sensibilidad del mando", Controles.sensibilidad_mando, 0.2, 3.0, 0.05, "%d %%", 100.0, func(x: float) -> void:
		Controles.sensibilidad_mando = x
		Controles.guardar())
	casilla("Invertir eje vertical (mirar)", Controles.invertir_y, func(on: bool) -> void:
		Controles.invertir_y = on
		Controles.guardar())
	casilla("Usar mando", Controles.mando_activo, func(on: bool) -> void:
		Controles.mando_activo = on
		Controles.guardar())
	var mandos: Array = Input.get_connected_joypads()
	var info: Label = Hud.crear_label(15, Color(0.75, 0.8, 0.72))
	info.text = ("Mando conectado: %s" % Input.get_joy_name(mandos[0])) if mandos.size() > 0 else "No hay ningún mando conectado."
	lista.add_child(info)
	titulo("Teclas")
	for a in Controles.ACCIONES:
		var accion: String = str(a[0])
		var f: HBoxContainer = fila(str(a[1]))
		var b: Button = Hud.crear_boton(Controles.nombre_teclas(accion), _empezar.bind(accion))
		b.custom_minimum_size.x = 260
		f.add_child(b)
		_botones[accion] = b
	var abajo: HBoxContainer = HBoxContainer.new()
	abajo.add_child(Hud.crear_boton("Restablecer todo", func() -> void:
		Controles.restablecer()
		_rellenar()
		aviso.text = "Controles restablecidos."))
	lista.add_child(abajo)
	var ayuda: Label = Hud.crear_label(15, Color(0.75, 0.8, 0.72))
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ayuda.text = "Mando: stick izquierdo andar · stick derecho mirar · gatillo derecho disparar · gatillo izquierdo apuntar · A saltar · B agacharse · X usar · Y recargar · LB/RB objeto · pulsar stick izquierdo correr · Select móvil · Start pausa · cruceta: arriba mapa, abajo inventario, izquierda montar, derecha esquivar."
	lista.add_child(ayuda)


func _empezar(accion: String) -> void:
	_esperando = accion
	(_botones[accion] as Button).text = "Pulsa una tecla… (Esc cancela)"
	aviso.text = ""


func _input(evento: InputEvent) -> void:
	if _esperando == "" or not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	get_viewport().set_input_as_handled()
	var tecla: int = int((evento as InputEventKey).physical_keycode)
	var accion: String = _esperando
	_esperando = ""
	if tecla == KEY_ESCAPE:
		(_botones[accion] as Button).text = Controles.nombre_teclas(accion)
		return
	var quitada: String = Controles.cambiar_tecla(accion, tecla)
	for a in _botones:
		(_botones[a] as Button).text = Controles.nombre_teclas(str(a))
	aviso.text = "Hecho." if quitada == "" else "Hecho. La tecla %s ya no hace «%s»: ponle otra." % [OS.get_keycode_string(tecla), quitada]
