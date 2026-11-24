# ventana_local.gd
# -----------------------------------------------------------------------------
# La carta de un negocio (restaurante, bar, cafetería, panadería, taberna) o la lista
# de servicios del taller. Se abre con E en el mostrador (ver objetos/local_mundo.gd).
# Cada fila: nombre, lo que hace, precio y botón de pedir. El plato del día (★) lleva
# un 20 % de descuento y lo que lleva ✦ gasta una hoja de bruma. Los datos están en
# datos/locales.gd; pedir y pagar, en LocalMundo.pedir() (estático, se puede probar).
# -----------------------------------------------------------------------------
class_name VentanaLocal
extends Ventana

const Locales = preload("res://scripts/datos/locales.gd")

var local_mundo: LocalMundo = null

var _lista: VBoxContainer
var _estado: Label
var _mensaje: Label
var _filas: Array = []   # [{"item", "boton", "precio"}]


func construir() -> void:
	var datos: Dictionary = Locales.LOCALES[local_mundo.local]
	var caja: VBoxContainer = marco(local_mundo.nombre, "%s  ·  abierto %s" % [str(datos["nombre"]), Locales.texto_horario(local_mundo.local)], Vector2(820, 640))
	caja.add_child(UI.nota(str(datos["fantasia"])))
	_estado = Hud.crear_label(17, Color(1, 0.92, 0.6))
	caja.add_child(_estado)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 8)
	scroll.add_child(_lista)
	_mensaje = Hud.crear_label(17, Color(0.7, 0.95, 0.7))
	_mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_mensaje)
	for item in local_mundo.carta():
		_fila(item)
	_refrescar()


func _fila(item: Dictionary) -> void:
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	_lista.add_child(fila)
	var textos: VBoxContainer = VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(textos)
	var titulo: Label = Hud.crear_label(18, Color(0.95, 0.9, 0.7))
	var marca: String = ("  ★ plato del día" if bool(item.get("dia", false)) else "") + ("  ✦" if item.has("magico") else "")
	titulo.text = str(item["nombre"]) + marca
	textos.add_child(titulo)
	var info: Label = Hud.crear_label(15, Color(0.7, 0.8, 0.72))
	var res: String = Locales.resumen(item)
	info.text = str(item.get("desc", "")) + ("  (" + res + ")" if res != "" else "")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	textos.add_child(info)
	var precio: Label = Hud.crear_label(18, Color(1, 0.92, 0.6))
	precio.custom_minimum_size.x = 80.0
	precio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila.add_child(precio)
	var boton: Button = Hud.crear_boton("Reparar" if Locales.es_taller(local_mundo.local) else ("Dormir" if item.has("dormir") else ("Entrenar" if item.has("entrena") else "Pedir")), _pedir.bind(item))
	boton.custom_minimum_size.x = 100.0
	fila.add_child(boton)
	_filas.append({"item": item, "boton": boton, "precio": precio})


func _vehiculo():
	if not Locales.es_taller(local_mundo.local):
		return null
	return LocalMundo.vehiculo_taller(get_tree(), local_mundo.punto_vehiculo)


func _pedir(item: Dictionary) -> void:
	var r: Dictionary = LocalMundo.pedir(item, _vehiculo(), local_mundo.local)
	_mensaje.text = str(r["msg"])
	_mensaje.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7) if bool(r["ok"]) else Color(1.0, 0.6, 0.5))
	if bool(r["ok"]):
		Juego.avisar(str(r["msg"]))
	_refrescar()


func _refrescar() -> void:
	var v = _vehiculo()
	var linea: String = "Llevas %d $   ·   hambre %d   ·   sed %d   ·   vida %d/%d" % [Juego.dinero, int(Juego.hambre), int(Juego.sed), int(Juego.vida), int(Juego.vida_max())]
	if Locales.es_taller(local_mundo.local):
		if v == null:
			linea += "   ·   sin vehículo cerca (acércalo al taller)"
		else:
			linea += "   ·   %s: salud %d %%, gasolina %d %%" % [Vehiculo.TIPOS[v.tipo]["nombre"], int(float(v.get("salud"))), int(float(v.get("gasolina")))]
	elif LocalMundo.copas_hoy() > 0:
		linea += "   ·   copas hoy: %d" % LocalMundo.copas_hoy()
	_estado.text = linea
	for f in _filas:
		var item: Dictionary = f["item"]
		var p: int = LocalMundo.precio_final(item, local_mundo.local)
		var ok: bool = true
		if item.has("vehiculo"):
			p = LocalMundo.precio_taller(item, v)
			ok = p >= 0
		var etiqueta: Label = f["precio"]
		etiqueta.text = ("%d $" % p) if ok else "—"
		(f["boton"] as Button).disabled = not ok or Juego.dinero < p
