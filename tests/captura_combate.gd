# Capturas de combate, matones y bandas. Con xvfb:
#   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/captura_combate.tscn -- /carpeta
extends Node

var carpeta: String = "."


func _foto(nombre: String) -> void:
	for i in 6:
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)
	print("FOTO ", nombre)


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	var J = raiz.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	var jugador = hud.jugador
	J.velocidad_tiempo = 0.0
	J.modo_volar = true
	var elegido: Dictionary = {}
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if int(s["tipo"]) == 2 and not bool(s.get("montana", false)):
			elegido = s
			break
	var punto: Vector3 = Vector3.ZERO
	var cara: float = 1.0
	for k in range(-4, 0):
		for l in range(1, 4):
			var c: Dictionary = GeneradorMundo.casa(elegido, k, l, 0)
			if not c.is_empty() and str(c.get("distrito", "")) == "industrial":
				cara = float(c["puerta"])
				punto = Vector3(float(c["x"]) + float(c["w"]) * 0.3, c["y"], float(c["z"]) + cara * (float(c["d"]) / 2.0 + 3.5))
				break
		if punto != Vector3.ZERO:
			break
	J.hora = 23.0
	J.dinero = 0
	J.modo_volar = false
	jugador.global_position = punto + Vector3(0, 3.0, cara * 13.0)
	jugador._giro = 0.0 if cara > 0.0 else PI
	jugador._inclinacion = -0.15
	await get_tree().create_timer(6.0).timeout
	var m: Maton = Maton.new()
	m.position = punto + Vector3(-2.5, 0.5, cara * 4.0)
	escena.add_child(m)
	var m2: Maton = Maton.new()
	m2.position = punto + Vector3(2.0, 0.5, cara * 2.0)
	escena.add_child(m2)
	await get_tree().create_timer(0.3).timeout
	J.proteccion_hasta_dia = J.dia   # Protegido: se quedan quietos para la foto.
	m.recibir_dano(55.0)
	m2.recibir_dano(20.0)
	J.rep_hampa = 12
	J.rep_ley = 6
	J.hambre = 30.0
	J.resistencia = 40.0
	J.cambio.emit()
	await get_tree().create_timer(0.4).timeout
	await _foto("com_1_matones_barras_y_banda")
	# Jefe de barrio con dos reclutas tuyos (azules) peleando.
	J.proteccion_hasta_dia = 0
	for n in get_tree().get_nodes_in_group("matones"):
		n.queue_free()
	await get_tree().process_frame
	var jefe: Maton = Maton.new()
	jefe.jefe = true
	jefe.territorio = "0,0"
	jefe.position = punto + Vector3(0.0, 0.5, cara * 5.0)
	escena.add_child(jefe)
	for i in 2:
		var a: Maton = Maton.new()
		a.aliado = true
		a.position = punto + Vector3(-2.0 + i * 4.0, 0.5, cara * 8.5)
		escena.add_child(a)
	J.reclutas = 2
	jefe.recibir_dano(70.0)
	jefe._enfado = false
	J.proteccion_hasta_dia = J.dia
	await get_tree().create_timer(0.5).timeout
	await _foto("com_2_jefe_y_reclutas")
	get_tree().quit()
