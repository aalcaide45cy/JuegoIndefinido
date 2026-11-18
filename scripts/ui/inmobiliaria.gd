# inmobiliaria.gd
# -----------------------------------------------------------------------------
# La inmobiliaria: alquilar, comprar o vender casas y huertos. Lo que
# alquilas o compras queda a tu nombre (Juego.viviendas / Juego.huertos);
# lo comprado (Juego.en_propiedad) se puede vender por el 70%.
# SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name Inmobiliaria
extends Ventana

const Propiedades = preload("res://scripts/datos/propiedades.gd")

var _lista: VBoxContainer


func construir() -> void:
	var caja: VBoxContainer = panel_centrado(Vector2(780, 640))
	cabecera(caja, "Inmobiliaria")
	subtitulo(caja, "Alquila (pago único) o compra (25 veces el alquiler; vendes por el 70%).")
	caja.add_child(Hud.crear_boton("Montar mi propia inmobiliaria (comprar pisos, venderlos y alquilarlos)...", _abrir_negocio))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lista)
	Juego.cambio.connect(_pintar)
	_pintar()


# Cierra esta ventana y abre la gestión de tu negocio inmobiliario.
func _abrir_negocio() -> void:
	var hud: Node = self
	while hud != null and not hud is Hud:
		hud = hud.get_parent()
	cerrar()
	if hud != null:
		var v: VentanaNegocios = VentanaNegocios.new()
		v.titulo = "Mi inmobiliaria"
		v.cat_inicial = "piso"
		(hud as Hud).abrir_ventana(v)


func _tiene(p: Dictionary) -> bool:
	return Juego.huertos.has(p["id"]) if p["tipo"] == "huerto" else Juego.viviendas.has(p["id"])


func _pintar() -> void:
	for h in _lista.get_children():
		h.queue_free()
	for tipo in ["casa", "huerto"]:
		var t: Label = Hud.crear_label(20, Color(0.6, 0.9, 0.6))
		t.text = "CASAS" if tipo == "casa" else "HUERTOS (para cultivos legales)"
		_lista.add_child(t)
		for p in Propiedades.LISTA:
			if p["tipo"] != tipo:
				continue
			var fila: HBoxContainer = HBoxContainer.new()
			fila.add_theme_constant_override("separation", 8)
			_lista.add_child(fila)
			var info: Label = Hud.crear_label(16)
			info.custom_minimum_size.x = 300.0
			info.text = "%s  (%d m²)" % [p["nombre"], p["m2"]]
			fila.add_child(info)
			if _tiene(p):
				var estado: Label = Hud.crear_label(16, Color(0.7, 1.0, 0.7))
				estado.text = "TUYA (comprada)" if Juego.en_propiedad.has(p["id"]) else "Alquilada"
				estado.custom_minimum_size.x = 150.0
				fila.add_child(estado)
				fila.add_child(Hud.crear_boton("Vender / dejar", _soltar.bind(p)))
			else:
				fila.add_child(Hud.crear_boton("Alquilar %d $" % p["alquiler"], _alquilar.bind(p)))
				fila.add_child(Hud.crear_boton("Comprar %d $" % Propiedades.precio_compra(p), _comprar.bind(p)))


func _poner(p: Dictionary, valor: bool) -> void:
	var destino: Dictionary = Juego.huertos if p["tipo"] == "huerto" else Juego.viviendas
	if valor:
		destino[p["id"]] = true
	else:
		destino.erase(p["id"])
		Juego.en_propiedad.erase(p["id"])
		if p["tipo"] == "huerto":
			Juego.parcelas.erase(p["id"])


func _alquilar(p: Dictionary) -> void:
	if not Juego.gastar(int(p["alquiler"])):
		Juego.avisar("No te llega para alquilar %s." % p["nombre"])
		return
	_poner(p, true)
	Juego.avisar("Has alquilado: %s." % p["nombre"])
	Juego.cambio.emit()


func _comprar(p: Dictionary) -> void:
	if not Juego.gastar(Propiedades.precio_compra(p)):
		Juego.avisar("No te llega para comprar %s." % p["nombre"])
		return
	_poner(p, true)
	Juego.en_propiedad[p["id"]] = true
	Juego.avisar("¡%s es tuya!" % p["nombre"])
	Juego.cambio.emit()


func _soltar(p: Dictionary) -> void:
	if Juego.en_propiedad.has(p["id"]):
		var devuelto: int = int(Propiedades.precio_compra(p) * Propiedades.DEVOLUCION_VENTA)
		Juego.cobrar(devuelto)
		Juego.avisar("Vendes %s por %d $." % [p["nombre"], devuelto])
	else:
		Juego.avisar("Dejas %s (el alquiler no se devuelve)." % p["nombre"])
	_poner(p, false)
	Juego.cambio.emit()
