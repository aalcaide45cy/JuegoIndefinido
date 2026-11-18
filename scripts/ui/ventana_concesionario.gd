# ventana_concesionario.gd
# -----------------------------------------------------------------------------
# Compra, venta y negociación de vehículos (datos en Vehiculo.TIPOS).
#   - Pestaña COMPRAR: lista por categorías; el vehículo aparece en el punto de entrega.
#   - Pestaña VENDER: tus vehículos (Juego.vehiculos). Puedes venderlos al precio
#     de tasación o negociar +15 % / +30 % (puede salir mal, como en la ventanilla).
# SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name VentanaConcesionario
extends Ventana

var punto: Vector3 = Vector3.ZERO
var giro: float = 0.0
var categorias: Array = []   # Vacío = se vende de todo.

var _lista: VBoxContainer
var _modo: String = "comprar"
var _texto: Label


func construir() -> void:
	var caja: VBoxContainer = panel_centrado(Vector2(800, 600))
	cabecera(caja, "Concesionario")
	var pestanas: HBoxContainer = HBoxContainer.new()
	pestanas.add_theme_constant_override("separation", 8)
	caja.add_child(pestanas)
	pestanas.add_child(Hud.crear_boton("Comprar", _cambiar_modo.bind("comprar")))
	pestanas.add_child(Hud.crear_boton("Vender / negociar", _cambiar_modo.bind("vender")))
	subtitulo(caja, "Gasolina y reparaciones: ferretería. Los vehículos se guardan donde los dejes. H engancha remolques.")
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lista)
	_texto = Hud.crear_label(17, Color(1, 0.9, 0.6))
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_texto)
	_pintar()


func _cambiar_modo(m: String) -> void:
	_modo = m
	_texto.text = ""
	_pintar()


func _categoria(t: Dictionary) -> String:
	if t.has("cat"):
		return str(t["cat"])
	return "Coches"


func _fila(texto: String, ancho: float = 420.0) -> HBoxContainer:
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_lista.add_child(fila)
	var info: Label = Hud.crear_label(17)
	info.custom_minimum_size.x = ancho
	info.text = texto
	fila.add_child(info)
	return fila


func _pintar() -> void:
	for h in _lista.get_children():
		h.queue_free()
	if _modo == "comprar":
		var cats: Array = []
		for id_t in Vehiculo.TIPOS:
			var c: String = _categoria(Vehiculo.TIPOS[id_t])
			if not cats.has(c) and (categorias.is_empty() or categorias.has(c)):
				cats.append(c)
		for c in cats:
			var t: Label = Hud.crear_label(20, Color(0.6, 0.9, 0.6))
			t.text = c.to_upper()
			_lista.add_child(t)
			for id_t in Vehiculo.TIPOS:
				var d: Dictionary = Vehiculo.TIPOS[id_t]
				if _categoria(d) != c:
					continue
				var extra: String = "  ·  %d km/h" % int(float(d["vmax"]) * 3.6) if d.has("vmax") else ""
				var fila: HBoxContainer = _fila("%s%s" % [d["nombre"], extra])
				fila.add_child(Hud.crear_boton("Comprar %d $" % d["precio"], _comprar.bind(id_t)))
	else:
		var hay: bool = false
		for id_v in Juego.vehiculos:
			var v: Dictionary = Juego.vehiculos[id_v]
			if not Vehiculo.TIPOS.has(str(v["tipo"])):
				continue
			hay = true
			var valor: int = Vehiculo.valor_venta(str(v["tipo"]), float(v.get("salud", 100.0)))
			var fila: HBoxContainer = _fila("%s  (estado %d %%)" % [Vehiculo.TIPOS[v["tipo"]]["nombre"], int(v.get("salud", 100.0))], 300.0)
			fila.add_child(Hud.crear_boton("Vender %d $" % valor, _vender.bind(str(id_v), 0)))
			for pct in [15, 30]:
				fila.add_child(Hud.crear_boton("+%d %%" % pct, _vender.bind(str(id_v), pct)))
		if not hay:
			var vacio: Label = Hud.crear_label(17, Color(0.8, 0.8, 0.8))
			vacio.text = "No tienes vehículos. (Los robados también cuentan.)"
			_lista.add_child(vacio)


func _gestor() -> GestorVehiculos:
	return get_tree().get_first_node_in_group("gestor_vehiculos") as GestorVehiculos


func _comprar(id_t: String) -> void:
	var t: Dictionary = Vehiculo.TIPOS[id_t]
	var gestor: GestorVehiculos = _gestor()
	if gestor == null:
		return
	if not Juego.gastar(int(t["precio"])):
		_texto.text = "No te llega para comprar: %s." % t["nombre"]
		return
	gestor.entregar(id_t, punto, giro)
	_texto.text = "¡Compraste %s! Está en la plaza de entrega (cuadro amarillo)." % t["nombre"]
	Juego.cambio.emit()


# pct = 0: venta a precio de tasación. Si no, se pide +pct % y puede salir mal.
func _vender(id_v: String, pct: int) -> void:
	if not Juego.vehiculos.has(id_v):
		return
	var v: Dictionary = Juego.vehiculos[id_v]
	var base: int = Vehiculo.valor_venta(str(v["tipo"]), float(v.get("salud", 100.0)))
	if pct > 0 and randf() >= Encargos.prob_contraoferta(pct):
		_texto.text = "El comprador se ofende y se marcha. Puedes volver a intentarlo."
		Juego.reputacion = maxi(-50, Juego.reputacion - 1)
		return
	var precio: int = int(base * (1.0 + pct / 100.0))
	var gestor: GestorVehiculos = _gestor()
	if gestor != null and not gestor.retirar(id_v):
		_texto.text = "Bájate del vehículo antes de venderlo."
		return
	Juego.cobrar(precio)
	_texto.text = "Vendido por %d $." % precio
	_pintar()
