# casilla_ui.gd
# -----------------------------------------------------------------------------
# Un cuadradito del inventario. Muestra el objeto que hay en una casilla de
# una lista (el inventario o la estantería) y permite:
#   - Arrastrar y soltar en otra casilla: mueve, intercambia o apila.
#   - Clic derecho: divide el montón por la mitad.
#   - Mayúsculas + clic: lo manda de golpe a la otra zona (mochila <-> barra,
#     o inventario <-> estantería).
#   - Pasar el ratón por encima: muestra el nombre y la descripción.
# Los dibujos de los objetos son formas simples hechas con código.
# -----------------------------------------------------------------------------
class_name CasillaUI
extends Control

const DatosObjetos = preload("res://scripts/datos/objetos.gd")

# Se emite con Mayúsculas + clic; quien crea la casilla decide adónde va.
signal envio_rapido(casilla: CasillaUI)
# Se emite al pasar el ratón por encima, al enfocarla con el mando o al hacer clic: las ventanas
# la usan para enseñar el detalle del objeto en su panel lateral.
signal elegida(casilla: CasillaUI)

const TAM: float = 56.0

var lista: Array          # La lista de Juego a la que pertenece (inventario o estanteria).
var indice: int = 0
var numero: String = ""   # Número que se pinta arriba (1-9 en la barra rápida).
var arrastrable: bool = true
var atenuada: bool = false   # Se pinta apagada (no encaja con el filtro o el buscador de la ventana).

# Casilla "cogida" con el mando (A la coge, A en otra la suelta). Solo una a la vez en todo el juego.
static var cogida: CasillaUI = null


func _init(lista_casillas: Array = [], i: int = 0, tam: float = TAM) -> void:
	lista = lista_casillas
	indice = i
	custom_minimum_size = Vector2(tam, tam)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL


func _ready() -> void:
	Juego.cambio.connect(_al_cambiar)
	mouse_entered.connect(func() -> void: elegida.emit(self))
	focus_entered.connect(func() -> void: elegida.emit(self))
	focus_exited.connect(queue_redraw)
	_al_cambiar()


func _exit_tree() -> void:
	if cogida == self:
		cogida = null


func _al_cambiar() -> void:
	var casilla = lista[indice]
	if casilla == null:
		tooltip_text = ""
	else:
		var datos: Dictionary = DatosObjetos.datos(casilla["id"])
		tooltip_text = "%s\n%s" % [datos["nombre"], datos["descripcion"]]
		if casilla.has("agua"):
			tooltip_text += "\nAgua: %d/%d" % [casilla["agua"], datos["agua_max"]]
		if datos.has("cargador"):
			tooltip_text += "\nBalas: %d/%d" % [casilla.get("balas", 0), datos["cargador"]]
	queue_redraw()


func _es_seleccionada() -> bool:
	return is_same(lista, Juego.inventario) and indice == Juego.seleccion


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	# Fondo y borde: dorado en la casilla en la mano, azul si la tiene "cogida" el mando.
	draw_style_box(Tema.caja(Color(0.075, 0.085, 0.1, 0.95), Tema.BORDE_SUAVE, 1, 6, 0, 0), r)
	var seleccionada: bool = _es_seleccionada()
	if seleccionada:
		draw_style_box(Tema.caja(Color(0, 0, 0, 0), Tema.ACENTO, 2, 6, 0, 0), r)
	if numero != "":
		draw_string(Tema.fuente("semibold"), Vector2(5, 14), numero, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 12, Tema.ACENTO if seleccionada else Tema.TEXTO_TENUE)
	var casilla = lista[indice]
	if casilla != null:
		Iconos.dibujar(self, r.grow(-4.0), casilla["id"])
		# Cantidad abajo a la derecha (si es un montón) o el agua de la jarra.
		var texto: String = ""
		if casilla["cantidad"] > 1:
			texto = str(casilla["cantidad"])
		elif casilla.has("agua"):
			texto = "%d/%d" % [casilla["agua"], DatosObjetos.datos(casilla["id"])["agua_max"]]
		if texto != "":
			var fuente: Font = Tema.fuente("bold")
			draw_string_outline(fuente, Vector2(0, size.y - 6), texto, HORIZONTAL_ALIGNMENT_RIGHT,
					size.x - 6, 15, 5, Color.BLACK)
			draw_string(fuente, Vector2(0, size.y - 6), texto, HORIZONTAL_ALIGNMENT_RIGHT,
					size.x - 6, 15, Color.WHITE)
	if atenuada:
		draw_style_box(Tema.caja(Color(0.03, 0.035, 0.045, 0.78), Color(0, 0, 0, 0), 0, 6, 0, 0), r)
	if cogida == self:
		draw_style_box(Tema.caja(Color(Tema.AZUL.r, Tema.AZUL.g, Tema.AZUL.b, 0.18), Tema.AZUL, 3, 6, 0, 0), r)
	elif has_focus():
		draw_style_box(Tema.caja(Color(1, 1, 1, 0.06), Tema.ACENTO, 2, 6, 0, 0), r)


# --------------------------- Arrastrar y soltar --------------------------------
# Godot llama a estas funciones solo: _get_drag_data al empezar a arrastrar,
# _can_drop_data mientras pasas por encima y _drop_data al soltar.

func _get_drag_data(_pos: Vector2) -> Variant:
	if not arrastrable or lista[indice] == null:
		return null
	var vista: Control = Control.new()
	# El dibujo que acompaña al ratón es grande (al menos 88 px) para verlo bien.
	var lado: float = maxf(size.x * 1.7, 88.0)
	var dibujo: CasillaUI = CasillaUI.new(lista, indice, lado)
	dibujo.size = Vector2(lado, lado)
	dibujo.modulate.a = 0.92
	dibujo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dibujo.position = -Vector2(lado, lado) / 2.0
	vista.add_child(dibujo)
	set_drag_preview(vista)
	return {"lista": lista, "indice": indice}


func _can_drop_data(_pos: Vector2, datos: Variant) -> bool:
	return arrastrable and datos is Dictionary and datos.has("lista")


func _drop_data(_pos: Vector2, datos: Variant) -> void:
	Juego.mover(datos["lista"], datos["indice"], lista, indice)


func _gui_input(evento: InputEvent) -> void:
	# Mando y teclado: A / Intro coge la casilla y suelta en otra (como arrastrar); X la manda a la
	# otra zona (como Mayús + clic); Y divide el montón (como clic derecho).
	if arrastrable and evento is InputEventJoypadButton and evento.pressed:
		var b: int = (evento as InputEventJoypadButton).button_index
		if b == JOY_BUTTON_X:
			envio_rapido.emit(self)
			accept_event()
			return
		if b == JOY_BUTTON_Y:
			Juego.dividir(lista, indice)
			accept_event()
			return
	if arrastrable and evento.is_action_pressed("ui_accept"):
		_coger_o_soltar()
		accept_event()
		return
	var boton: InputEventMouseButton = evento as InputEventMouseButton
	if boton == null or not boton.pressed:
		return
	if boton.button_index == MOUSE_BUTTON_LEFT:
		elegida.emit(self)
	if not arrastrable:
		return
	if boton.button_index == MOUSE_BUTTON_RIGHT:
		Juego.dividir(lista, indice)
	elif boton.button_index == MOUSE_BUTTON_LEFT and boton.shift_pressed:
		envio_rapido.emit(self)


func _coger_o_soltar() -> void:
	if cogida == null:
		if lista[indice] != null:
			cogida = self
			queue_redraw()
	else:
		var origen: CasillaUI = cogida
		cogida = null
		if origen != self and is_instance_valid(origen):
			Juego.mover(origen.lista, origen.indice, lista, indice)
		origen.queue_redraw()
		queue_redraw()


# ------------------------------ Iconos ----------------------------------------
# Dibuja el objeto "id" dentro del rectángulo "r". Cada "forma" (ver
# scripts/datos/objetos.gd) tiene su dibujo; las armas se ven de perfil.

static func dibujar_icono(lienzo: CanvasItem, r: Rect2, id: String) -> void:
	var datos: Dictionary = DatosObjetos.datos(id)
	var c: Color = datos["color"]
	var o: Vector2 = r.position
	var s: Vector2 = r.size
	var oscuro: Color = c.darkened(0.45)
	match datos["forma"]:
		"bolsita":
			lienzo.draw_rect(Rect2(o + s * Vector2(0.2, 0.25), s * Vector2(0.6, 0.7)), Color(0.75, 0.65, 0.45))
			lienzo.draw_rect(Rect2(o + s * Vector2(0.3, 0.1), s * Vector2(0.4, 0.18)), Color(0.6, 0.5, 0.35))
			lienzo.draw_circle(o + s * Vector2(0.5, 0.6), s.x * 0.16, c)
		"saco":
			lienzo.draw_rect(Rect2(o + s * Vector2(0.15, 0.2), s * Vector2(0.7, 0.75)), c)
			lienzo.draw_rect(Rect2(o + s * Vector2(0.35, 0.05), s * Vector2(0.3, 0.2)), c.darkened(0.3))
		"maceta":
			lienzo.draw_colored_polygon(PackedVector2Array([o + s * Vector2(0.1, 0.25), o + s * Vector2(0.9, 0.25),
					o + s * Vector2(0.75, 0.95), o + s * Vector2(0.25, 0.95)]), c)
		"jarra", "regadera":
			lienzo.draw_rect(Rect2(o + s * Vector2(0.25, 0.25), s * Vector2(0.5, 0.7)), c)
			lienzo.draw_rect(Rect2(o + s * Vector2(0.3, 0.45), s * Vector2(0.4, 0.45)), Color(0.35, 0.55, 0.9))
			lienzo.draw_arc(o + s * Vector2(0.78, 0.55), s.x * 0.15, -PI / 2, PI / 2, 8, c, 3.0)
			if datos["forma"] == "regadera":
				lienzo.draw_line(o + s * Vector2(0.25, 0.4), o + s * Vector2(0.0, 0.15), c, 4.0)
		"hoja":
			for k in 5:
				var ang: float = -PI / 2 + (k - 2) * 0.45
				lienzo.draw_line(o + s * Vector2(0.5, 0.85), o + s * Vector2(0.5, 0.85) + Vector2(cos(ang), sin(ang)) * s.x * 0.45, c, 5.0)
		"seta":
			lienzo.draw_rect(Rect2(o + s * Vector2(0.42, 0.45), s * Vector2(0.16, 0.45)), Color(0.85, 0.82, 0.75))
			lienzo.draw_circle(o + s * Vector2(0.5, 0.42), s.x * 0.32, c)
		"frasco":
			lienzo.draw_circle(o + s * Vector2(0.5, 0.65), s.x * 0.3, c)
			lienzo.draw_rect(Rect2(o + s * Vector2(0.42, 0.1), s * Vector2(0.16, 0.3)), Color(0.7, 0.75, 0.8))
		"palo", "bate", "barra":
			var grueso: float = 6.0 if datos["forma"] == "palo" else 8.0
			lienzo.draw_line(o + s * Vector2(0.15, 0.9), o + s * Vector2(0.85, 0.1), c, grueso)
			if datos["forma"] == "bate":
				lienzo.draw_line(o + s * Vector2(0.55, 0.45), o + s * Vector2(0.85, 0.1), c, 13.0)
		"cuchillo", "katana":
			var largo: float = 0.55 if datos["forma"] == "katana" else 0.35
			lienzo.draw_line(o + s * Vector2(0.15, 0.85), o + s * Vector2(0.3, 0.7), Color(0.2, 0.15, 0.1), 6.0)
			lienzo.draw_line(o + s * Vector2(0.3, 0.7), o + s * Vector2(0.3 + largo, 0.7 - largo), c, 5.0)
		"pistola":
			lienzo.draw_rect(Rect2(o + s * Vector2(0.15, 0.3), s * Vector2(0.7, 0.2)), c.lightened(0.15))
			lienzo.draw_rect(Rect2(o + s * Vector2(0.2, 0.45), s * Vector2(0.2, 0.4)), c.lightened(0.15))
		"escopeta", "rifle", "francotirador", "lanzagranadas":
			lienzo.draw_rect(Rect2(o + s * Vector2(0.0, 0.42), s * Vector2(1.0, 0.13)), c.lightened(0.2))
			lienzo.draw_rect(Rect2(o + s * Vector2(0.0, 0.45), s * Vector2(0.3, 0.3)), Color(0.35, 0.22, 0.12))
			if datos["forma"] == "francotirador":
				lienzo.draw_rect(Rect2(o + s * Vector2(0.4, 0.28), s * Vector2(0.3, 0.1)), Color(0.1, 0.1, 0.1))
			if datos["forma"] == "lanzagranadas":
				lienzo.draw_rect(Rect2(o + s * Vector2(0.45, 0.33), s * Vector2(0.5, 0.3)), c)
		"pan":
			lienzo.draw_circle(o + s * Vector2(0.5, 0.6), s.x * 0.32, c)
			lienzo.draw_arc(o + s * Vector2(0.5, 0.6), s.x * 0.2, PI, TAU, 8, oscuro, 3.0)
		"venda":
			lienzo.draw_rect(Rect2(o + s * Vector2(0.15, 0.3), s * Vector2(0.7, 0.4)), c)
			lienzo.draw_rect(Rect2(o + s * Vector2(0.45, 0.35), s * Vector2(0.1, 0.3)), Color(0.8, 0.15, 0.15))
			lienzo.draw_rect(Rect2(o + s * Vector2(0.35, 0.45), s * Vector2(0.3, 0.1)), Color(0.8, 0.15, 0.15))
		"granada":
			lienzo.draw_circle(o + s * Vector2(0.5, 0.6), s.x * 0.3, c)
			lienzo.draw_rect(Rect2(o + s * Vector2(0.42, 0.15), s * Vector2(0.16, 0.2)), Color(0.5, 0.5, 0.5))
		"c4":
			lienzo.draw_rect(Rect2(o + s * Vector2(0.1, 0.3), s * Vector2(0.8, 0.45)), c)
			lienzo.draw_rect(Rect2(o + s * Vector2(0.35, 0.4), s * Vector2(0.3, 0.2)), Color(0.15, 0.15, 0.15))
			lienzo.draw_circle(o + s * Vector2(0.5, 0.5), s.x * 0.05, Color(1, 0.2, 0.2))
		"detonador":
			lienzo.draw_rect(Rect2(o + s * Vector2(0.3, 0.3), s * Vector2(0.4, 0.6)), c.lightened(0.2))
			lienzo.draw_line(o + s * Vector2(0.6, 0.3), o + s * Vector2(0.7, 0.05), Color(0.6, 0.6, 0.6), 3.0)
			lienzo.draw_circle(o + s * Vector2(0.5, 0.5), s.x * 0.08, Color(1, 0.2, 0.2))
		_:  # "caja" y cualquier otra: una caja con su color.
			lienzo.draw_rect(Rect2(o + s * Vector2(0.15, 0.3), s * Vector2(0.7, 0.55)), c)
			lienzo.draw_rect(Rect2(o + s * Vector2(0.15, 0.3), s * Vector2(0.7, 0.12)), oscuro)
