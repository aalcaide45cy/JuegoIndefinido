# ventana_grimorio.gd
# -----------------------------------------------------------------------------
# El grimorio (tecla K): las 4 escuelas de magia con su nivel y experiencia, y sus hechizos.
# Pulsa "Preparar" en un hechizo que sepas para lanzarlo con F.
# -----------------------------------------------------------------------------
class_name VentanaGrimorio
extends Ventana

const DatosMagia = preload("res://scripts/datos/magia.gd")

var _caja: VBoxContainer


func construir() -> void:
	var caja: VBoxContainer = panel_centrado(Vector2(980, 760))
	cabecera(caja, "Grimorio")
	_caja = VBoxContainer.new()
	_caja.add_theme_constant_override("separation", 8)
	caja.add_child(_caja)
	_rellenar()


func _rellenar() -> void:
	for h in _caja.get_children():
		_caja.remove_child(h)
		h.queue_free()
	var M: Node = Magia
	var cab: Label = Hud.crear_label(16, Color(0.75, 0.8, 0.72))
	cab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cab.text = "Maná %d / %d.  La magia está prohibida: si un guardia te ve, sube la búsqueda; si te ve la gente, sube la sospecha. De noche y dentro de los edificios es más seguro.  F lanzar · Q cambiar de hechizo." % [int(M.mana), int(DatosMagia.MANA_MAX)]
	_caja.add_child(cab)
	for e in DatosMagia.ESCUELAS:
		var esc: Dictionary = DatosMagia.ESCUELAS[e]
		var n: int = M.nivel(e)
		var tit: Label = Hud.crear_label(22, esc["color"])
		var sig: String = "nivel máximo" if n >= DatosMagia.XP_NIVEL.size() else "%d / %d XP" % [int(M.xp.get(e, 0.0)), int(DatosMagia.XP_NIVEL[n])]
		tit.text = "%s  ·  nivel %d  (%s)" % [esc["nombre"], n, sig]
		_caja.add_child(tit)
		var lema: Label = Hud.crear_label(15, Color(0.75, 0.8, 0.72))
		lema.text = str(esc["lema"])
		_caja.add_child(lema)
		for id in DatosMagia.ORDEN[e]:
			var h: Dictionary = DatosMagia.HECHIZOS[id]
			var fila: HBoxContainer = HBoxContainer.new()
			fila.add_theme_constant_override("separation", 12)
			var sabe: bool = M.sabe(id)
			var t: Label = Hud.crear_label(17, Color(0.92, 0.92, 0.88) if sabe else Color(0.5, 0.5, 0.5))
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			t.text = "%s%s  (%d maná)  ·  %s" % ["▶ " if M.preparado == id else "", h["nombre"], int(M.coste(id)), h["descripcion"]]
			fila.add_child(t)
			if sabe:
				var b: Button = Hud.crear_boton("Preparado" if M.preparado == id else "Preparar", func() -> void:
					M.preparar(id)
					_rellenar())
				b.disabled = M.preparado == id
				fila.add_child(b)
			else:
				var falta: Label = Hud.crear_label(15, Color(0.6, 0.6, 0.6))
				falta.text = "Nivel %d" % DatosMagia.nivel_requerido(id)
				fila.add_child(falta)
			_caja.add_child(fila)
