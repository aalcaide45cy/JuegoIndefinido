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


const MANDO: Array = [
	["Andar / conducir", "Stick izquierdo"], ["Mirar", "Stick derecho"], ["Disparar / golpear", "Gatillo derecho"],
	["Apuntar (zoom)", "Gatillo izquierdo"], ["Saltar", "A"], ["Agacharse", "B"], ["Usar", "X"], ["Recargar", "Y"],
	["Objeto anterior / siguiente", "LB / RB"], ["Correr", "Pulsar stick izquierdo"], ["Cambiar cámara", "Pulsar stick derecho"],
	["Móvil", "Select"], ["Pausa y cerrar ventanas", "Start"], ["Mapa grande", "Cruceta arriba"],
	["Inventario", "Cruceta abajo"], ["Montar objeto", "Cruceta izquierda"], ["Esquivar", "Cruceta derecha"],
]


func construir() -> void:
	if incrustada:
		montar_incrustada()
	else:
		montar("Controles", Vector2(900, 700))
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
	nota_fila(("Mando conectado: %s" % Input.get_joy_name(mandos[0])) if mandos.size() > 0 else "No hay ningún mando conectado.")
	titulo("Teclas")
	for a in Controles.ACCIONES:
		var accion: String = str(a[0])
		var f: HBoxContainer = fila(str(a[1]))
		f.add_child(UI.espaciador())
		var b: Button = UI.boton(Controles.nombre_teclas(accion), _empezar.bind(accion))
		b.custom_minimum_size.x = 260
		f.add_child(b)
		_botones[accion] = b
	boton_fila("Restablecer todo", func() -> void:
		Controles.restablecer()
		_rellenar()
		aviso.text = "Controles restablecidos.", "BotonPeligro")
	titulo("Mando (fijo)")
	for m in MANDO:
		var f: HBoxContainer = fila(str(m[0]))
		f.add_child(UI.espaciador())
		var cap: PanelContainer = UI.insignia(str(m[1]), Tema.AZUL)
		f.add_child(cap)
	filtrar(_filtro)


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
