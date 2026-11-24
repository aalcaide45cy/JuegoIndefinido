# Prueba de los ajustes gráficos: mide el coste de cada opción y saca capturas.
# Ventana fuera de pantalla (nunca a pantalla completa):
#   godot --path . --windowed --position -20000,-20000 --resolution 1920x1080 res://tests/prueba_graficos.tscn -- <carpeta> <modo> [sitios]
# modo: presets | opciones | menu | humo      sitios: lista de números separados por comas (0 ciudad, 1 ciudad grande, 2 montaña)
extends Node

var carpeta: String = "."
var jugador: Node3D
var vida: Node
var etiqueta_render: String = ""


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _ir(pos: Vector3, giro: float, incl: float) -> void:
	jugador.global_position = pos
	jugador.velocity = Vector3.ZERO
	jugador._giro = giro
	jugador._inclinacion = incl


func _medir(frames: int = 150) -> Array:
	var t0: int = Time.get_ticks_usec()
	var peor: int = 0
	var ult: int = t0
	var gpu: float = 0.0
	var rid: RID = get_tree().root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for i in frames:
		await get_tree().process_frame
		var t: int = Time.get_ticks_usec()
		peor = maxi(peor, t - ult)
		ult = t
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	return [float(ult - t0) / 1000.0 / frames, peor / 1000.0, gpu / frames]


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg("%s/%s.jpg" % [carpeta, nombre], 0.9)


func _sitios() -> Array:
	var out: Array = [[ "ciudad_original", Vector3(0, 0.5, 8), 0.0, -0.15 ]]
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if int(s["tipo"]) == 2 and not bool(s.get("montana", false)):
			var p: Vector2 = s["pos"]
			out.append(["ciudad_grande", Vector3(p.x + 4.0, GeneradorMundo.altura(p.x, p.y) + 1.0, p.y + 40.0), 0.3, -0.1])
			break
	for clave in GeneradorMundo._asentamientos:
		var s: Dictionary = GeneradorMundo._asentamientos[clave]
		if bool(s.get("montana", false)):
			var p: Vector2 = s["pos"]
			out.append(["montana", Vector3(p.x + 2.0, GeneradorMundo.altura(p.x, p.y) + 1.0, p.y + 18.0), 0.6, -0.12])
			break
	return out


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	var modo: String = args[1] if args.size() > 1 else "humo"
	var idx: Array = []
	if args.size() > 2:
		for t in args[2].split(","):
			idx.append(int(t))
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
	vida = escena.find_children("*", "VidaUrbana", true, false)[0]
	J.hora = 12.0
	J.velocidad_tiempo = 0.0
	Graficos.poner("vsync", 0, false)
	Graficos.poner("fps_max", 0, false)
	etiqueta_render = Graficos.nombre_renderizador()
	print("RENDER ", etiqueta_render, " ventana ", get_window().size, " args ", OS.get_cmdline_args())
	var sitios: Array = _sitios()
	if idx.is_empty():
		for i in sitios.size():
			idx.append(i)

	if modo == "escape":
		# Recorrido real: Esc -> menú de pausa -> botón Gráficos… -> ventana de gráficos.
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = true
		Input.parse_input_event(ev)
		await _esperar(1.0)
		print("ESC menu abierto: ", hud._menu != null, " tipo ", hud._menu.get_script().get_global_name() if hud._menu != null else "-")
		await _foto("escape_1_pausa")
		var boton: Button = null
		for b in hud._menu.find_children("*", "Button", true, false):
			if b.text.begins_with("Gráficos"):
				boton = b
		print("ESC boton Graficos encontrado: ", boton != null)
		if boton != null:
			boton.pressed.emit()
			await _esperar(1.0)
			print("ESC ventana graficos presente: ", hud._menu.find_children("*", "VentanaGraficos", true, false).size() > 0)
			var vg = hud._menu.find_children("*", "VentanaGraficos", true, false)[0]
			print("ESC lista hijos: ", vg._lista.get_child_count(), " scroll tam ", vg._scroll.size, " lista tam ", vg._lista.size)
			await _esperar(2.0)
			await _foto("escape_2_graficos")
	elif modo == "menu":
		hud._abrir_menu(VentanaGraficos.new())
		await _esperar(1.0)
		await _foto("menu_graficos_1")
		var v: ScrollContainer = hud._menu.find_children("*", "ScrollContainer", true, false)[0]
		v.scroll_vertical = 600
		await _esperar(0.5)
		await _foto("menu_graficos_2")
		v.scroll_vertical = 2000
		await _esperar(0.5)
		await _foto("menu_graficos_3")
	elif modo == "humo":
		var s: Array = sitios[idx[0]]
		_ir(s[1], s[2], s[3])
		await _esperar(6.0)
		var r: Array = await _medir()
		print("FPS humo %s %.2f ms peor %.1f" % [s[0], r[0], r[1]])
		await _foto("humo")
	elif modo == "presets":
		for i in idx:
			var s: Array = sitios[i]
			for p in ["Bajo", "Medio", "Alto", "Ultra"]:
				Graficos.aplicar_preset(p)
				Graficos.recargar_mundo()
				_ir(s[1], s[2], s[3])
				await _esperar(7.0)
				_ir(s[1], s[2], s[3])
				await _esperar(1.0)
				var r: Array = await _medir()
				print("FPS|%s|%s|%s|%.2f|%d|%.1f|gpu %.2f|pe %d co %d|dc %d" % [etiqueta_render, s[0], p, r[0], int(1000.0 / r[0]), r[1], r[2],
						vida._peatones.size(), vida._coches.size(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
				await _foto("preset_%s_%s_%s" % [etiqueta_render.replace("+", "mas"), s[0], p])
	elif modo == "opciones":
		# Base: preset Alto; cada opción se cambia sola y se mide.
		var pruebas: Array = [
			["base", "sombras", 3], ["sombras", "sombras", 0], ["sombras", "sombras", 1], ["sombras", "sombras", 2], ["sombras", "sombras", 4],
			["dist_dibujado", "dist_dibujado", 0], ["dist_dibujado", "dist_dibujado", 1], ["dist_dibujado", "dist_dibujado", 3], ["dist_dibujado", "dist_dibujado", 4],
			["trozos", "trozos", 0], ["trozos", "trozos", 1], ["trozos", "trozos", 3],
			["vegetacion", "vegetacion", 0], ["vegetacion", "vegetacion", 2],
			["peatones", "peatones", 0], ["peatones", "peatones", 4], ["trafico", "trafico", 0], ["trafico", "trafico", 4],
			["aa", "aa", 0], ["aa", "aa", 2], ["aa", "aa", 3], ["aa", "aa", 4], ["aa", "aa", 5],
			["ssao", "ssao", true], ["ssr", "ssr", true], ["glow", "glow", false], ["niebla_vol", "niebla_vol", true], ["sdfgi", "sdfgi", true],
			["escala 50%", "escala", 0.5], ["escala 75%", "escala", 0.75], ["escala 150%", "escala", 1.5],
			["fsr1 75%", "escalado", 1], ["fsr2 75%", "escalado", 2],
		]
		for i in idx:
			var s: Array = sitios[i]
			for pr in pruebas:
				Graficos.aplicar_preset("Alto")
				Graficos.poner("aa", 0)
				Graficos.poner("ssao", false)
				if str(pr[1]) == "escalado":
					Graficos.poner("escala", 0.75)
				Graficos.poner(str(pr[1]), pr[2])
				Graficos.recargar_mundo()
				_ir(s[1], s[2], s[3])
				await _esperar(6.0 if str(pr[1]) in ["vegetacion", "trozos", "dist_dibujado"] else 3.0)
				_ir(s[1], s[2], s[3])
				await _esperar(0.7)
				var r: Array = await _medir(120)
				print("OPC|%s|%s|%s=%s|%.2f|%d|%.1f|gpu %.2f" % [etiqueta_render, s[0], pr[1], str(pr[2]), r[0], int(1000.0 / r[0]), r[1], r[2]])
	print("FIN")
	get_tree().quit()
