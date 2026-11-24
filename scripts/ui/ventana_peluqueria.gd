# ventana_peluqueria.gd
# -----------------------------------------------------------------------------
# La ventana de la peluquería y la barbería: eliges un peinado, un color de pelo
# o una barba (según el local), ves el resultado en un muñeco que gira y pagas
# el cambio. Qué se puede cambiar y los precios están en datos/peluqueria.gd.
# Los tintes mágicos gastan una hoja de bruma. El peluquero/barbero paga la mitad.
# -----------------------------------------------------------------------------
class_name VentanaPeluqueria
extends Ventana

const Aspecto = preload("res://scripts/jugador/aspecto.gd")

var local: String = "peluqueria"
var _nuevo: Dictionary = {}
var _giro: Node3D
var _valores: Dictionary = {}
var _precio: Label
var _boton: Button


func construir() -> void:
	_nuevo = Aspecto.valido(Juego.aspecto)
	var caja: VBoxContainer = panel_centrado(Vector2(760, 470))
	cabecera(caja, Juego.DatosPeluqueria.nombre(local))
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 18)
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(fila)
	fila.add_child(_vista_previa())
	var opciones: VBoxContainer = VBoxContainer.new()
	opciones.add_theme_constant_override("separation", 10)
	opciones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(opciones)
	for o in Aspecto.OPCIONES:
		if Juego.DatosPeluqueria.opciones(local).has(o[0]):
			opciones.add_child(_fila_opcion(o[0], o[1], o[2]))
	_precio = Hud.crear_label(18, Color(1, 0.92, 0.6))
	opciones.add_child(_precio)
	_boton = Hud.crear_boton("Pagar y cambiar", _pagar)
	opciones.add_child(_boton)
	subtitulo(caja, "Los tintes verde y violeta son mágicos: llevan una hoja de bruma. Si trabajas aquí, pagas la mitad.")
	_refrescar()


func _fila_opcion(clave: String, titulo: String, nombres: Array) -> HBoxContainer:
	var f: HBoxContainer = HBoxContainer.new()
	f.add_theme_constant_override("separation", 6)
	var t: Label = Hud.crear_label(17, Color(0.75, 0.85, 0.75))
	t.text = titulo
	t.custom_minimum_size.x = 110.0
	f.add_child(t)
	f.add_child(Hud.crear_boton("◀", _cambiar.bind(clave, -1)))
	var v: Label = Hud.crear_label(17)
	v.custom_minimum_size.x = 190.0
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.add_child(v)
	_valores[clave] = [v, nombres]
	f.add_child(Hud.crear_boton("▶", _cambiar.bind(clave, 1)))
	return f


func _vista_previa() -> Control:
	var contenedor: SubViewportContainer = SubViewportContainer.new()
	contenedor.custom_minimum_size = Vector2(260, 360)
	contenedor.stretch = true
	var vp: SubViewport = SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(260, 360)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	contenedor.add_child(vp)
	var entorno: Environment = Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color(0.16, 0.12, 0.16)
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.85, 0.82, 0.85)
	entorno.ambient_light_energy = 0.8
	var camara: Camera3D = Camera3D.new()
	camara.environment = entorno
	camara.position = Vector3(0, 1.05, 2.5)
	camara.fov = 40.0
	vp.add_child(camara)
	camara.rotation.x = -0.03
	var sol: DirectionalLight3D = DirectionalLight3D.new()
	sol.rotation = Vector3(-0.7, 0.5, 0.0)
	vp.add_child(sol)
	_giro = Node3D.new()
	vp.add_child(_giro)
	return contenedor


func _process(delta: float) -> void:
	if _giro != null:
		_giro.rotation.y += delta * 0.8


func _cambiar(clave: String, paso: int) -> void:
	_nuevo[clave] = posmod(int(_nuevo.get(clave, 0)) + paso, Aspecto.cantidad(clave))
	_refrescar()


func precio_final() -> int:
	var p: int = Juego.DatosPeluqueria.precio_cambio(local, Juego.aspecto, _nuevo)
	if Juego.oficio == str(Juego.DatosPeluqueria.LOCALES[local]["oficio"]):
		p = int(round(p * Juego.DatosPeluqueria.DESCUENTO_OFICIO))
	return p


func _refrescar() -> void:
	for clave in _valores:
		var par: Array = _valores[clave]
		var i: int = int(_nuevo.get(clave, 0))
		var txt: String = str((par[1] as Array)[i])
		var m: String = Juego.DatosPeluqueria.objeto_magico(clave, i)
		(par[0] as Label).text = txt + (" ✦" if m != "" else "") + ("  (%d $)" % Juego.DatosPeluqueria.precio_opcion(clave, i))
	var precio: int = precio_final()
	var cambia: bool = Juego.DatosPeluqueria.precio_cambio(local, Juego.aspecto, _nuevo) > 0 or _distinto()
	_precio.text = "Total: %d $   (llevas %d $)" % [precio, Juego.dinero]
	_boton.disabled = not cambia
	if _giro != null:
		for h in _giro.get_children():
			h.queue_free()
		var modelo: Node3D = Node3D.new()
		_giro.add_child(modelo)
		var vista: Dictionary = _nuevo.duplicate()
		vista["sombrero"] = 3   # Sin sombrero, para ver el peinado.
		Aspecto.vestir(modelo, vista)


func _distinto() -> bool:
	for clave in Juego.DatosPeluqueria.opciones(local):
		if int(_nuevo.get(clave, 0)) != int(Juego.aspecto.get(clave, 0)):
			return true
	return false


func _pagar() -> void:
	var precio: int = precio_final()
	var objetos: Dictionary = Juego.DatosPeluqueria.objetos_cambio(local, Juego.aspecto, _nuevo)
	for id in objetos:
		if not Juego.tiene(id, int(objetos[id])):
			Juego.avisar("Para ese tinte mágico necesitas: %s." % str(Juego.DatosObjetos.datos(id)["nombre"]))
			return
	if not Juego.gastar(precio):
		Juego.avisar("El cambio cuesta %d $." % precio)
		return
	for id in objetos:
		Juego.quitar(id, int(objetos[id]))
	for clave in Juego.DatosPeluqueria.opciones(local):
		Juego.aspecto[clave] = int(_nuevo.get(clave, 0))
	Juego.aspecto = Aspecto.valido(Juego.aspecto)
	var jugador: Jugador = get_tree().get_first_node_in_group("jugador") as Jugador
	if jugador != null:
		jugador.vestir()
	Juego.avisar("¡Listo! Sales con otro aspecto (%d $)." % precio)
	Juego.cambio.emit()
	_refrescar()
