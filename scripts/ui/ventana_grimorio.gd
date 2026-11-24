# ventana_grimorio.gd
# -----------------------------------------------------------------------------
# El grimorio (tecla K): una pestaña por escuela de magia (Naturaleza, Ilusión,
# Fuerza, Sombras) con su nivel y experiencia, y los hechizos como tarjetas.
# "Preparar" deja listo un hechizo que ya sepas para lanzarlo con F.
# -----------------------------------------------------------------------------
class_name VentanaGrimorio
extends Ventana

const DatosMagia = preload("res://scripts/datos/magia.gd")

var _pestanas: UI.Pestanas
var _estado: HBoxContainer
var _paginas: Dictionary = {}   # escuela -> VBoxContainer con sus tarjetas


func construir() -> void:
	pistas_extra = [["pestanas", "Cambiar de escuela"]]
	var cuerpo: VBoxContainer = marco("Grimorio", "La magia está prohibida: si te ven, sube la búsqueda", Vector2(960, 650))
	_estado = HBoxContainer.new()
	_estado.add_theme_constant_override("separation", 12)
	_marco_cabecera.add_child(_estado)
	_marco_cabecera.move_child(_estado, _marco_cabecera.get_child_count() - 2)
	_pestanas = UI.Pestanas.new()
	cuerpo.add_child(_pestanas)
	for e in DatosMagia.ESCUELAS:
		var desplazable: ScrollContainer = ScrollContainer.new()
		desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		desplazable.follow_focus = true
		var pagina: VBoxContainer = VBoxContainer.new()
		pagina.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pagina.add_theme_constant_override("separation", 8)
		desplazable.add_child(pagina)
		_paginas[e] = pagina
		_pestanas.anadir(str(DatosMagia.ESCUELAS[e]["nombre"]), desplazable)
	cuerpo.add_child(UI.nota("De noche y dentro de los edificios es más seguro. F lanza el hechizo preparado · Q cambia de hechizo."))
	_rellenar()


func _rellenar() -> void:
	var M: Node = Magia
	for h in _estado.get_children():
		_estado.remove_child(h)
		h.queue_free()
	_estado.add_child(UI.etiqueta("Maná", "Subtitulo"))
	var barra: ProgressBar = UI.barra(M.mana, DatosMagia.MANA_MAX, Tema.MAGIA, 12)
	barra.custom_minimum_size.x = 150
	_estado.add_child(barra)
	_estado.add_child(UI.etiqueta("%d / %d" % [int(M.mana), int(DatosMagia.MANA_MAX)], "Dinero"))
	for e in DatosMagia.ESCUELAS:
		var pagina: VBoxContainer = _paginas[e]
		for h in pagina.get_children():
			pagina.remove_child(h)
			h.queue_free()
		var esc: Dictionary = DatosMagia.ESCUELAS[e]
		var color: Color = esc["color"]
		var n: int = M.nivel(e)
		var cab: PanelContainer = UI.tarjeta()
		cab.add_theme_stylebox_override("panel", Tema.caja(Color(color.r, color.g, color.b, 0.1), Color(color.r, color.g, color.b, 0.5), 1, 10, 14, 10))
		var cc: VBoxContainer = VBoxContainer.new()
		cc.add_theme_constant_override("separation", 4)
		cab.add_child(cc)
		var sig: String = "nivel máximo" if n >= DatosMagia.XP_NIVEL.size() else "%d / %d XP" % [int(M.xp.get(e, 0.0)), int(DatosMagia.XP_NIVEL[n])]
		var fila: HBoxContainer = HBoxContainer.new()
		cc.add_child(fila)
		fila.add_child(UI.etiqueta("%s · nivel %d" % [esc["nombre"], n], "Titulo", color, 22))
		fila.add_child(UI.espaciador())
		fila.add_child(UI.etiqueta(sig, "Subtitulo"))
		cc.add_child(UI.nota(str(esc["lema"])))
		var xp_hasta: float = float(DatosMagia.XP_NIVEL[mini(n, DatosMagia.XP_NIVEL.size() - 1)])
		var xp_desde: float = float(DatosMagia.XP_NIVEL[maxi(n - 1, 0)])
		cc.add_child(UI.barra(float(M.xp.get(e, 0.0)) - xp_desde, maxf(xp_hasta - xp_desde, 1.0), color, 8))
		pagina.add_child(cab)
		for id in DatosMagia.ORDEN[e]:
			pagina.add_child(_tarjeta_hechizo(id, color))


func _tarjeta_hechizo(id: String, color: Color) -> Control:
	var M: Node = Magia
	var h: Dictionary = DatosMagia.HECHIZOS[id]
	var sabe: bool = M.sabe(id)
	var preparado: bool = M.preparado == id
	var t: PanelContainer = UI.tarjeta(preparado)
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	t.add_child(fila)
	var punto: ColorRect = ColorRect.new()
	punto.color = color if sabe else Tema.TEXTO_TENUE
	punto.custom_minimum_size = Vector2(4, 40)
	fila.add_child(punto)
	var textos: VBoxContainer = VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 3)
	fila.add_child(textos)
	var nombre: Label = UI.etiqueta(str(h["nombre"]), "", Tema.TEXTO if sabe else Tema.TEXTO_SUAVE, 18)
	nombre.add_theme_font_override("font", Tema.fuente("semibold"))
	textos.add_child(nombre)
	textos.add_child(UI.nota(str(h["descripcion"])))
	var coste: Label = UI.etiqueta("%d maná" % int(M.coste(id)), "Subtitulo", Tema.MAGIA)
	coste.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(coste)
	if sabe:
		var b: Button = UI.boton("Preparado" if preparado else "Preparar", func() -> void:
			M.preparar(id)
			_rellenar(), "BotonPrimario" if not preparado else "")
		b.disabled = preparado
		b.custom_minimum_size.x = 120
		fila.add_child(b)
	else:
		var falta: PanelContainer = UI.insignia("Nivel %d" % DatosMagia.nivel_requerido(id), Tema.TEXTO_TENUE)
		falta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fila.add_child(falta)
	return t
