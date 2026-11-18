# ventana_logros.gd
# -----------------------------------------------------------------------------
# La lista de logros (tecla L, o desde los menús de inicio y pausa).
# -----------------------------------------------------------------------------
class_name VentanaLogros
extends Ventana

const Datos = preload("res://scripts/datos/logros.gd")


func construir() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var caja: VBoxContainer = panel_centrado(Vector2(760, 620))
	cabecera(caja, "Logros  (%d/%d)" % [Logros.conseguidos.size(), Logros.total()])
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(scroll)
	var lista: VBoxContainer = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 6)
	scroll.add_child(lista)
	# Primero los conseguidos, luego los que faltan.
	var ids: Array = Datos.LISTA.keys()
	ids.sort_custom(func(a, b): return int(Logros.tiene(a)) > int(Logros.tiene(b)))
	for id in ids:
		var d: Dictionary = Datos.LISTA[id]
		var tengo: bool = Logros.tiene(id)
		var l: Label = Hud.crear_label(18, Color(0.6, 0.9, 0.6) if tengo else Color(0.62, 0.62, 0.6))
		l.text = "%s  %s   —   %s" % ["[x]" if tengo else "[ ]", d["nombre"], d["desc"]]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 700
		lista.add_child(l)
