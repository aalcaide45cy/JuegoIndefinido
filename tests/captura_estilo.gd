# Capturas del aspecto del juego (mundo e interfaces) y medida de FPS.
# Ventana fuera de pantalla, nunca a pantalla completa:
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 --disable-vsync res://tests/captura_estilo.tscn -- <carpeta> <modo>
# modo: mundo | ui | todo
extends Node

var carpeta: String = "."
var jugador: Node3D
var hud
var J


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)


func _ir(pos: Vector3, giro: float, incl: float) -> void:
	jugador.global_position = pos
	jugador.velocity = Vector3.ZERO
	jugador._giro = giro
	jugador._inclinacion = incl


func _medir(frames: int = 150) -> Array:
	var t0: int = Time.get_ticks_usec()
	var peor: int = 0
	var ult: int = t0
	for i in frames:
		await get_tree().process_frame
		var t: int = Time.get_ticks_usec()
		peor = maxi(peor, t - ult)
		ult = t
	return [float(ult - t0) / 1000.0 / frames, peor / 1000.0]


func _sitios() -> Array:
	var out: Array = [
		["01_plaza", Vector3(0, 0.5, 8), 0.0, -0.15],
		["02_plaza_alta", Vector3(0, 9, 22), 0.0, -0.45],
		["03_calle", Vector3(30, 0.5, 30), 0.8, -0.1],
	]
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if int(s["tipo"]) == 2 and not bool(s.get("montana", false)):
			var p: Vector2 = s["pos"]
			var h: float = GeneradorMundo.altura(p.x, p.y)
			out.append(["04_ciudad_grande", Vector3(p.x + 4.0, h + 1.0, p.y + 40.0), 0.3, -0.1])
			out.append(["05_ciudad_grande_alta", Vector3(p.x + 4.0, h + 45.0, p.y + 90.0), 0.3, -0.5])
			break
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if int(s["tipo"]) == 1:
			var p: Vector2 = s["pos"]
			out.append(["06_pueblo", Vector3(p.x + 3.0, GeneradorMundo.altura(p.x, p.y) + 1.0, p.y + 25.0), 0.4, -0.1])
			break
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if int(s["tipo"]) == 0 and not bool(s.get("montana", false)):
			var p: Vector2 = s["pos"]
			out.append(["07_aldea", Vector3(p.x + 3.0, GeneradorMundo.altura(p.x, p.y) + 1.0, p.y + 18.0), 0.4, -0.1])
			break
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if bool(s.get("montana", false)):
			var p: Vector2 = s["pos"]
			out.append(["08_montana", Vector3(p.x + 2.0, GeneradorMundo.altura(p.x, p.y) + 1.0, p.y + 18.0), 0.6, -0.12])
			break
	return out


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	var modo: String = args[1] if args.size() > 1 else "todo"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	J = raiz.get_node("Juego")
	hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	J.reiniciar()
	jugador = hud.jugador
	J.hora = 12.0
	J.velocidad_tiempo = 0.0
	J.nivel = 9
	J.dinero = 4200
	for id in ["hierba_bruma", "hierba_raiz_ardiente", "hierba_musgo_dulce", "aditivo_miel", "aditivo_sal", "aditivo_azufre", "hierba_flor_sol", "hierba_lirio_lunar"]:
		J.anadir(id, 4)
	J.anadir("botiquin", 2)
	J.anadir("cafe", 3)
	J.vida = 70.0
	print("RENDER ", Graficos.nombre_renderizador(), " ventana ", get_window().size)
	if modo == "mundo" or modo == "todo":
		await _mundo()
	if modo == "ui" or modo == "todo":
		await _ui()
	print("FIN")
	get_tree().quit()


func _mundo() -> void:
	J.hora = 12.0
	var sitios: Array = _sitios()
	var suma: float = 0.0
	for s in sitios:
		_ir(s[1], s[2], s[3])
		await _esperar(5.0)
		_ir(s[1], s[2], s[3])
		await _esperar(1.0)
		var r: Array = await _medir()
		suma += r[0]
		print("FPS|%s|%.2f ms|%d fps|peor %.1f|dc %d|tri %d" % [s[0], r[0], int(1000.0 / r[0]), r[1],
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
		await _foto("mundo_" + s[0])
	print("FPS_MEDIA|%.2f ms" % (suma / sitios.size()))
	J.hora = 22.0
	_ir(sitios[0][1], sitios[0][2], sitios[0][3])
	await _esperar(2.0)
	await _foto("mundo_09_plaza_noche")
	J.hora = 12.0


func _abrir(nombre: String, v: Control, extra: Callable = Callable()) -> void:
	if hud._menu != null:
		hud._menu.cerrar()
		await get_tree().process_frame
	hud._abrir_menu(v)
	await _esperar(0.6)
	if extra.is_valid():
		extra.call()
		await _esperar(0.4)
	await _foto("ui_" + nombre)


func _ui() -> void:
	_ir(Vector3(0, 0.5, 8), 0.0, -0.15)
	J.aplicar_efecto("velocidad", 70.0)
	J.aplicar_efecto("regeneracion", 30.0)
	await _esperar(1.0)
	await _foto("ui_00_hud")
	await _abrir("01_inventario", Ventanas.Inventario.new())
	await _abrir("02_pausa", Ventanas.Pausa.new())
	await _abrir("03_inicio", Ventanas.Inicio.new())
	await _abrir("04_tienda", _tienda("botica", "Botica de prueba"))
	await _abrir("05_caldero", Ventanas.VentanaCaldero.new())
	await _abrir("06_estanteria", Ventanas.Estanteria.new())
	await _abrir("07_instructor", Ventanas.Instructor.new())
	await _abrir("08_admin", Ventanas.Admin.new())
	await _abrir("09_graficos", VentanaGraficos.new())
	await _abrir("10_medico", VentanaMedico.new())
	await _abrir("11_partidas", VentanaPartidas.new())
	await _abrir("12_logros", VentanaLogros.new())
	await _abrir("13_aspecto", VentanaAspecto.new())
	await _abrir("14_concesionario", VentanaConcesionario.new())
	await _abrir("15_inmobiliaria", Inmobiliaria.new())
	await _abrir("16_bolsa", BolsaTrabajo.new())
	await _abrir("17_cacheo", Cacheo.new())
	var mapa: MapaGrande = MapaGrande.new()
	mapa.jugador = jugador
	await _abrir("18_mapa", mapa)
	for i in 6:
		var tel: Telefono = Telefono.new()
		await _abrir("19_movil_%d" % i, tel, tel._cambiar_pestana.bind(i))


func _tienda(id: String, nombre: String) -> Control:
	var t: Ventanas.Tienda = Ventanas.Tienda.new()
	t.tienda = id
	t.nombre_tienda = nombre
	return t
