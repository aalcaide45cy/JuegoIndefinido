# Capturas de salud y oficios: hospital, comisaría, bomberos, taller, avisos de cada oficio y el
# HUD con convalecencia y rango. Ventana fuera de pantalla:
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_oficios.tscn -- /carpeta
extends Node

var carpeta: String = "."
var jugador: Node3D
var escena: Node
var J


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.88)
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
	for nombre in ["hospital", "comisaria", "bomberos", "taller"]:
		var sv = _servicio(nombre)
		if sv == null:
			print("No encontrado: ", nombre)
			continue
		_mirar(sv.global_position, 14.0, 5.0, 1.0)
		await get_tree().create_timer(2.0).timeout
		await _foto("%02d_edificio_%s" % [n, nombre])
		n += 1
	# Convalecencia tras el hospital + fichar de médico (HUD con rango y texto).
	var hosp = _servicio("hospital")
	J.dinero = 400
	J.vida = 35.0
	_mirar(hosp.global_position, 9.0, 1.6, 1.0)
	jugador.global_position.y = hosp.global_position.y + 1.2
	J.modo_volar = false
	await get_tree().create_timer(1.0).timeout
	hosp.usar(jugador)
	Input.action_press("correr")
	hosp._usar_oficio()
	J.empezar_turno()
	await get_tree().create_timer(1.0).timeout
	await _foto("%02d_hospital_convalecencia_y_medico_de_servicio" % n)
	n += 1
	Input.action_release("correr")
	# Un aviso de cada oficio.
	var gestor = escena.find_children("*", "GestorOficio", true, false)[0]
	J.modo_volar = true
	for of in ["medico", "bombero", "policia", "mecanico"]:
		J.terminar_turno()
		J.oficio = of
		J.estrellas = 0
		J.empezar_turno()
		if gestor.aviso != null and is_instance_valid(gestor.aviso):
			gestor.aviso.queue_free()
			gestor.aviso = null
		jugador.global_position = Vector3(p.x, h + 20.0, p.y)
		await get_tree().create_timer(1.5).timeout
		var ok: bool = gestor.crear_aviso()
		if not ok:
			print("sin aviso para ", of)
			continue
		var a: Node3D = gestor.aviso
		_mirar(a.global_position, 7.0, 9.0, 0.7)
		await get_tree().create_timer(1.5).timeout
		await _foto("%02d_aviso_%s" % [n, of])
		n += 1
	get_tree().quit()
