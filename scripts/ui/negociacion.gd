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
	var caja: VBoxContainer = marco("Negociar con %s" % mostrador.nombre, "Reputación %d" % Juego.reputacion, Vector2(540, 400))
	caja.add_child(UI.etiqueta("Quiere: %s" % GameData.pocion(mostrador.pedido)["nombre"], "", Tema.TEXTO, 18))
	caja.add_child(UI.nota("Precio normal: %d $. Pedir más puede salir mal y el cliente se marcha." % mostrador.precio_base()))
	caja.add_child(Ventanas.boton_grande("Vender al precio normal (%d $)" % mostrador.precio_base(), _tratar.bind(0)))
	for pct in [15, 30]:
		var p: int = int(mostrador.precio_base() * (1.0 + pct / 100.0))
		caja.add_child(Ventanas.boton_grande("Pedir +%d%% (%d $)  -  éxito ~%d%%" % [pct, p,
				int(Encargos.prob_contraoferta(pct) * 100.0)], _tratar.bind(pct)))
	_texto = UI.etiqueta("", "", Tema.ACENTO, 18)
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
