# ventana_aspecto.gd
# -----------------------------------------------------------------------------
# La ventana de aspecto (tecla O): a la izquierda una vista previa que gira y a
# la derecha una fila por opción (cuerpo, piel, pelo, sombrero, abrigo...) con
# flechas para cambiar. Los cambios se aplican al momento y se guardan con la
# partida (Juego.aspecto). SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name VentanaAspecto
extends Ventana

const Aspecto = preload("res://scripts/jugador/aspecto.gd")

var _giro: Node3D
var _valores: Dictionary = {}   # clave -> Label con el nombre de la opción elegida


func construir() -> void:
	var caja: VBoxContainer = panel_centrado(Vector2(780, 500))
	cabecera(caja, "Aspecto")
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 18)
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(fila)
	fila.add_child(_vista_previa())
	var opciones: VBoxContainer = VBoxContainer.new()
	opciones.add_theme_constant_override("separation", 8)
	opciones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(opciones)
	for o in Aspecto.OPCIONES:
		opciones.add_child(_fila_opcion(o[0], o[1], o[2]))
	opciones.add_child(Hud.crear_boton("Aleatorio", _aleatorio))
	subtitulo(caja, "Los trajes con modelo (Soldado, Bandido...) ignoran piel, pelo, sombrero y abrigo.")
	_refrescar()


func _fila_opcion(clave: String, titulo: String, nombres: Array) -> HBoxContainer:
	var f: HBoxContainer = HBoxContainer.new()
	f.add_theme_constant_override("separation", 6)
	var t: Label = Hud.crear_label(17, Color(0.75, 0.85, 0.75))
	t.text = titulo
	t.custom_minimum_size.x = 140.0
	f.add_child(t)
	f.add_child(Hud.crear_boton("◀", _cambiar.bind(clave, -1)))
	var v: Label = Hud.crear_label(17)
	v.custom_minimum_size.x = 150.0
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.add_child(v)
	_valores[clave] = [v, nombres]
	f.add_child(Hud.crear_boton("▶", _cambiar.bind(clave, 1)))
	return f


func _vista_previa() -> Control:
	var contenedor: SubViewportContainer = SubViewportContainer.new()
	contenedor.custom_minimum_size = Vector2(280, 380)
	contenedor.stretch = true
	var vp: SubViewport = SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(280, 380)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	contenedor.add_child(vp)
	var entorno: Environment = Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color(0.1, 0.12, 0.11)
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.8, 0.8, 0.85)
	entorno.ambient_light_energy = 0.8
	var camara: Camera3D = Camera3D.new()
	camara.environment = entorno
	camara.position = Vector3(0, 1.0, 3.0)
	camara.fov = 40.0
	vp.add_child(camara)
	camara.rotation.x = -0.05
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
	var n: int = Aspecto.cantidad(clave)
	Juego.aspecto[clave] = posmod(int(Juego.aspecto.get(clave, 0)) + paso, n)
	_aplicar()


func _aleatorio() -> void:
	for o in Aspecto.OPCIONES:
		Juego.aspecto[o[0]] = randi() % Aspecto.cantidad(o[0])
	_aplicar()


func _aplicar() -> void:
	Juego.aspecto = Aspecto.valido(Juego.aspecto)
	var jugador: Jugador = get_tree().get_first_node_in_group("jugador") as Jugador
	if jugador != null:
		jugador.vestir()
	_refrescar()


func _refrescar() -> void:
	for clave in _valores:
		var par: Array = _valores[clave]
		(par[0] as Label).text = str((par[1] as Array)[int(Juego.aspecto.get(clave, 0))])
	if _giro != null:
		for h in _giro.get_children():
			h.queue_free()
		var modelo: Node3D = Node3D.new()
		_giro.add_child(modelo)
		Aspecto.vestir(modelo, Juego.aspecto)
