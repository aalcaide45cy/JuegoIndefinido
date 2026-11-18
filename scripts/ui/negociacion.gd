# negociacion.gd
# -----------------------------------------------------------------------------
# Ventana para negociar el precio de una venta en la ventanilla. Eliges: vender
# al precio normal, pedir un +15% o un +30% (el cliente puede ofenderse y irse;
# tu reputación ayuda) o dejarlo. SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name Negociacion
extends Ventana

var mostrador: Mostrador
var _texto: Label


func construir() -> void:
	var caja: VBoxContainer = panel_centrado(Vector2(520, 380))
	cabecera(caja, "Negociar con %s" % mostrador.nombre)
	subtitulo(caja, "Quiere: %s. Precio normal: %d $. Reputación: %d" % [
			GameData.pocion(mostrador.pedido)["nombre"], mostrador.precio_base(), Juego.reputacion])
	caja.add_child(Ventanas.boton_grande("Vender al precio normal (%d $)" % mostrador.precio_base(), _tratar.bind(0)))
	for pct in [15, 30]:
		var p: int = int(mostrador.precio_base() * (1.0 + pct / 100.0))
		caja.add_child(Ventanas.boton_grande("Pedir +%d%% (%d $)  -  éxito ~%d%%" % [pct, p,
				int(Encargos.prob_contraoferta(pct) * 100.0)], _tratar.bind(pct)))
	_texto = Hud.crear_label(18, Color(1, 0.9, 0.6))
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_texto)


func _tratar(pct: int) -> void:
	if not is_instance_valid(mostrador):
		cerrar()
		return
	if pct == 0 or randf() < Encargos.prob_contraoferta(pct):
		mostrador.cerrar_trato(int(mostrador.precio_base() * (1.0 + pct / 100.0)))
	else:
		mostrador.trato_fallido()
	cerrar()
