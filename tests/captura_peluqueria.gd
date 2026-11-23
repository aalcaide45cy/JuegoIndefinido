# Capturas de la peluquería y la barbería: edificios, ventana, catálogo de peinados y barbas
# y el cliente del oficio. Ventana fuera de pantalla:
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_peluqueria.tscn -- /carpeta
extends Node

var carpeta: String = "."
var jugador: Node3D
var escena: Node
var J


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.88)
	print("FOTO ", nombre)


func _mirar(punto: Vector3, dist: float, altura: float, ang: float) -> void:
	var dir: Vector2 = Vector2(cos(ang), sin(ang))
	jugador.global_position = punto + Vector3(dir.x * dist, altura, dir.y * dist)
	jugador.velocity = Vector3.ZERO
	jugador._giro = atan2(dir.x, dir.y)
	jugador._inclinacion = -atan2(altura - 1.5, dist)


func _servicio(nombre: String):
	for n in get_tree().get_nodes_in_group("interactuable"):
		if n is ServicioMundo and n.servicio == nombre:
			return n
	return null


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	var raiz: Node = get_tree().root
	escena = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	J = raiz.get_node("Juego")
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	jugador = hud.jugador
	J.hora = 12.0
	J.velocidad_tiempo = 0.0
	J.modo_volar = true
	var elegido: Dictionary = {}
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if int(s["tipo"]) == 2 and not bool(s.get("montana", false)):
			elegido = s
			break
	var p: Vector2 = elegido["pos"]
	var h: float = GeneradorMundo.altura(p.x, p.y)
	jugador.global_position = Vector3(p.x, h + 20.0, p.y)
	await get_tree().create_timer(6.0).timeout
	var n: int = 1
	for nombre in ["peluqueria", "barberia"]:
		var sv = _servicio(nombre)
		if sv == null:
			print("No encontrado: ", nombre)
			continue
		_mirar(sv.global_position, 14.0, 5.0, 1.0)
		await get_tree().create_timer(2.0).timeout
		await _foto("%02d_edificio_%s" % [n, nombre])
		n += 1
	# Catálogo: peinados y barbas en fila, en el aire sobre la ciudad.
	var Aspecto = J.DatosAspecto
	var centro: Vector3 = Vector3(p.x, h + 60.0, p.y)
	var fila: Node3D = Node3D.new()
	escena.add_child(fila)
	fila.global_position = centro
	var luz: DirectionalLight3D = DirectionalLight3D.new()
	luz.rotation = Vector3(-0.6, 0.4, 0)
	fila.add_child(luz)
	var i: int = 0
	for peinado in Aspecto.PEINADOS.size():
		var m: Node3D = Node3D.new()
		m.position = Vector3((peinado - 2.5) * 1.1, 0, 0)
		fila.add_child(m)
		var a: Dictionary = Aspecto.POR_DEFECTO.duplicate()
		a["peinado"] = peinado
		a["pelo"] = [1, 2, 3, 0, 6, 7][peinado]
		a["piel"] = peinado % 5
		a["sombrero"] = 3
		Aspecto.vestir(m, a)
	for barba in Aspecto.BARBAS.size():
		var m2: Node3D = Node3D.new()
		m2.position = Vector3((barba - 2.0) * 1.1, 0, 3.0)
		fila.add_child(m2)
		var b: Dictionary = Aspecto.POR_DEFECTO.duplicate()
		b["barba"] = barba
		b["pelo"] = [0, 1, 4, 3, 0][barba]
		b["peinado"] = 0 if barba < 3 else 2
		b["sombrero"] = 3
		Aspecto.vestir(m2, b)
	jugador.global_position = centro + Vector3(0, 1.0, -5.0)
	jugador.velocity = Vector3.ZERO
	jugador._giro = PI
	jugador._inclinacion = 0.0
	hud.visible = false
	await get_tree().create_timer(1.5).timeout
	await _foto("%02d_catalogo_peinados" % n)
	n += 1
	jugador.global_position = centro + Vector3(0, 1.0, -2.0)
	jugador.velocity = Vector3.ZERO
	await get_tree().create_timer(1.0).timeout
	await _foto("%02d_catalogo_barbas" % n)
	n += 1
	hud.visible = true
	fila.queue_free()
	# Ventanas.
	jugador.global_position = Vector3(p.x, h + 20.0, p.y)
	J.dinero = 150
	J.anadir("hierba_bruma", 1)
	for local in ["peluqueria", "barberia"]:
		var v: VentanaPeluqueria = VentanaPeluqueria.new()
		v.local = local
		hud.abrir_ventana(v)
		await get_tree().create_timer(0.5).timeout
		v._cambiar("peinado", 3)
		v._cambiar("barba" if local == "barberia" else "pelo", 2 if local == "barberia" else -2)
		await get_tree().create_timer(0.5).timeout
		await _foto("%02d_ventana_%s" % [n, local])
		n += 1
		v.cerrar()
		await get_tree().process_frame
	# Cliente del oficio (peluquero).
	J.oficio = "peluquero"
	J.empezar_turno()
	var gestor = escena.find_children("*", "GestorOficio", true, false)[0]
	await get_tree().create_timer(1.0).timeout
	if gestor.aviso != null and is_instance_valid(gestor.aviso):
		gestor.aviso.queue_free()
		gestor.aviso = null
	if gestor.crear_aviso():
		_mirar(gestor.aviso.global_position, 5.0, 3.0, 0.6)
		await get_tree().create_timer(1.5).timeout
		await _foto("%02d_cliente_peluquero" % n)
	get_tree().quit()
