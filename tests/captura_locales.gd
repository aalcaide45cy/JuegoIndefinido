# Capturas de locales nocturnos. Con xvfb:
#   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/captura_locales.tscn -- /carpeta
extends Node

var carpeta: String = "."
var jugador: Node3D


func _foto(nombre: String) -> void:
	for i in 6:
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)
	print("FOTO ", nombre)


func _mirar(punto: Vector3, dist: float, altura: float, ang: float) -> void:
	var dir: Vector2 = Vector2(cos(ang), sin(ang))
	jugador.global_position = punto + Vector3(dir.x * dist, altura, dir.y * dist)
	jugador.velocity = Vector3.ZERO
	jugador._giro = atan2(dir.x, dir.y)
	jugador._inclinacion = -atan2(altura - 1.5, dist)


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
	jugador = hud.jugador
	J.velocidad_tiempo = 0.0
	J.modo_volar = true
	var elegido: Dictionary = {}
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if int(s["tipo"]) == 2 and not bool(s.get("montana", false)):
			elegido = s
			break
	var n: int = 1
	for par in [["discoteca", Vector2i(-3, -1)], ["tragaperras", Vector2i(1, -2)], ["casino", Vector2i(3, 2)], ["club", Vector2i(-4, -3)], ["prestamista", Vector2i(0, 3)], ["mercado_negro", Vector2i(3, -3)]]:
		var c: Dictionary = GeneradorMundo.casa(elegido, par[1].x, par[1].y, 0)
		var punto: Vector3 = GeneradorMundo._punto_servicio(c)
		for hora in [23.0, 12.0]:
			J.hora = hora
			_mirar(punto, 9.0, 3.0, 0.0 if float(c["puerta"]) < 0.0 else PI)
			jugador.global_position = Vector3(punto.x, punto.y + 4.0, punto.z + float(c["puerta"]) * 18.0)
			jugador._giro = 0.0 if float(c["puerta"]) > 0.0 else PI
			jugador._inclinacion = -0.12
			await get_tree().create_timer(5.0).timeout
			for sv in get_tree().get_nodes_in_group("interactuable"):
				if sv is ServicioMundo and sv.servicio == par[0]:
					print("SERV ", par[0], " en ", sv.global_position, " jugador ", jugador.global_position, " neon ", sv._neon != null)
			await _foto("loc_%02d_%s_%s" % [n, par[0], "noche" if hora > 20.0 else "dia"])
			n += 1
	# Zona chunga: el bidón con fuego de la zona industrial, de noche.
	J.hora = 23.0
	var zonas: Array = []
	var industrial: Vector3 = Vector3.ZERO
	var cara_i: float = 1.0
	for k in range(-4, 0):
		for l in range(1, 4):
			var cz: Dictionary = GeneradorMundo.casa(elegido, k, l, 0)
			if not cz.is_empty() and str(cz.get("distrito", "")) == "industrial":
				cara_i = float(cz["puerta"])
				industrial = Vector3(float(cz["x"]) + float(cz["w"]) * 0.3, cz["y"], float(cz["z"]) + cara_i * (float(cz["d"]) / 2.0 + 3.5))
				break
		if industrial != Vector3.ZERO:
			break
	jugador.global_position = industrial + Vector3(0, 3.5, cara_i * 9.0)
	jugador._giro = 0.0 if cara_i > 0.0 else PI
	jugador._inclinacion = -0.22
	J.dinero = 0   # Sin dinero no hay atraco que tape la captura.
	await get_tree().create_timer(6.0).timeout
	await _foto("loc_90_zona_chunga_noche")
	# Ventana del casino con una mano de blackjack y una vuelta de ruleta.
	hud.abrir_casino()
	await get_tree().process_frame
	var v = hud._menu
	if v != null and v.has_method("_girar"):
		J.dinero = 500
		v._girar("rojo", 0)
		v._repartir()
		await _foto("loc_91_casino_ventana")
	get_tree().quit()
