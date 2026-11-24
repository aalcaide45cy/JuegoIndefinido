# Prueba de las opciones nuevas: teclas reasignables, mando, volúmenes, autoguardado y copia de
# seguridad del guardado. Se ejecuta con:
#   godot --headless --path . res://tests/prueba_opciones.tscn
# Deja como estaban user://controles.cfg, user://opciones.cfg y la ranura 5.
extends Node

var fallos: Array = []


func comprobar(condicion: bool, texto: String) -> void:
	if not condicion:
		fallos.append(texto)
		print("FALLO: ", texto)
	else:
		print("  ok: ", texto)


func _copia(r: String) -> Variant:
	return FileAccess.get_file_as_bytes(r) if FileAccess.file_exists(r) else null


func _restaurar(r: String, datos: Variant) -> void:
	if datos == null:
		if FileAccess.file_exists(r):
			DirAccess.remove_absolute(r)
	else:
		var f: FileAccess = FileAccess.open(r, FileAccess.WRITE)
		f.store_buffer(datos)
		f.close()


func _ready() -> void:
	await get_tree().process_frame
	var guardar_cfg: Dictionary = {}
	for r in ["user://controles.cfg", "user://opciones.cfg", Guardado.ruta(5), Guardado.ruta(5) + ".bak", Guardado.RUTA_ULTIMA]:
		guardar_cfg[r] = _copia(r)
	var ranura_antes: int = Guardado.ranura
	await _probar()
	for r in guardar_cfg:
		_restaurar(r, guardar_cfg[r])
	Guardado.ranura = ranura_antes
	Controles.cargar()
	print("RESULTADO: ", "TODO BIEN" if fallos.is_empty() else "FALLO " + str(fallos))
	get_tree().quit()


func _probar() -> void:
	var C: Node = get_tree().root.get_node("Controles")
	# --- Teclas
	C.restablecer()
	comprobar(KEY_E in C.teclas_de("usar"), "usar empieza en E")
	var quitada: String = C.cambiar_tecla("usar", KEY_J)
	comprobar(C.teclas_de("usar") == [KEY_J], "usar pasa a J")
	comprobar(quitada == "", "J no la usaba nadie")
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = KEY_J
	ev.pressed = true
	comprobar(InputMap.event_is_action(ev, "usar"), "pulsar J cuenta como usar")
	quitada = C.cambiar_tecla("saltar", KEY_J)
	comprobar(quitada != "" and C.teclas_de("usar").is_empty(), "si otra acción coge J, usar se queda sin tecla")
	C.cambiar_tecla("usar", KEY_Q)
	C.sensibilidad_raton = 1.7
	C.invertir_y = true
	C.guardar()
	C.sensibilidad_raton = 1.0
	C.invertir_y = false
	C.cargar()
	comprobar(C.teclas_de("usar") == [KEY_Q] and C.teclas_de("saltar") == [KEY_J], "las teclas se guardan y se cargan")
	comprobar(absf(C.sensibilidad_raton - 1.7) < 0.01 and C.invertir_y, "sensibilidad e invertir se guardan")
	C.restablecer()
	comprobar(KEY_E in C.teclas_de("usar") and KEY_SPACE in C.teclas_de("saltar"), "restablecer vuelve a las teclas de siempre")
	# --- Mando
	var tiene_mando: bool = false
	for e in InputMap.action_get_events("saltar"):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			tiene_mando = true
	comprobar(tiene_mando, "saltar tiene el botón A del mando")
	var eje: bool = false
	for e in InputMap.action_get_events("adelante"):
		if e is InputEventJoypadMotion and (e as InputEventJoypadMotion).axis == JOY_AXIS_LEFT_Y:
			eje = true
	comprobar(eje, "adelante tiene el stick izquierdo")
	# --- Sonido
	Musica.volumen_efectos = 0.5
	Musica.volumen_general = 0.8
	Musica.aplicar_buses()
	var bus: int = AudioServer.get_bus_index("Efectos")
	comprobar(bus != -1, "existe el bus de efectos")
	comprobar(absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.5)) < 0.1, "volumen de efectos aplicado")
	comprobar(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.8)) < 0.1, "volumen general aplicado")
	Musica.guardar_opciones()
	Musica.volumen_efectos = 0.9
	Musica.cargar_opciones()
	comprobar(absf(Musica.volumen_efectos - 0.5) < 0.01, "volumen de efectos se guarda")
	Musica.volumen_general = 1.0
	Musica.volumen_efectos = 0.9
	Musica.aplicar_buses()
	# --- Cambio de nombre del juego: se copian las partidas de la carpeta antigua.
	var viejo: String = ProjectSettings.globalize_path("user://_prueba_viejo")
	var nuevo: String = ProjectSettings.globalize_path("user://_prueba_nuevo")
	DirAccess.make_dir_recursive_absolute(viejo)
	DirAccess.make_dir_recursive_absolute(nuevo)
	for n in ["partida_1.json", "partida_1.json.bak", "controles.cfg", "otra_cosa.png"]:
		var fv: FileAccess = FileAccess.open(viejo.path_join(n), FileAccess.WRITE)
		fv.store_string("x")
		fv.close()
	var CD = load("res://scripts/carpeta_datos.gd")
	comprobar(CD.copiar_de_carpeta_antigua(viejo, nuevo) == 3, "se copian partidas, copias y opciones de la carpeta antigua")
	comprobar(CD.copiar_de_carpeta_antigua(viejo, nuevo) == 0, "si ya hay partidas en la carpeta nueva no se copia nada")
	for d in [viejo, nuevo]:
		for n in DirAccess.get_files_at(d):
			DirAccess.remove_absolute(d.path_join(n))
		DirAccess.remove_absolute(d)
	# --- Mundo, ventanas y guardado
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	Juego.reiniciar()
	var jugador = hud.jugador
	var A: Node = raiz.get_node("Autoguardado")
	comprobar(not A._jugando(), "el autoguardado no actúa en las pruebas (la escena principal no es el mundo)")
	A.poner_minutos(10)
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load("user://opciones.cfg")
	comprobar(int(cfg.get_value("juego", "autoguardado_min", 0)) == 10 and cfg.has_section_key("sonido", "efectos"),
			"autoguardado y volúmenes conviven en opciones.cfg")
	for clase in [VentanaSonido, VentanaControles]:
		var v: Control = clase.new()
		hud._abrir_menu(v)
		await get_tree().process_frame
		await get_tree().process_frame
		comprobar(is_instance_valid(v) and (v as VentanaOpciones).lista.get_child_count() > 4, "se abre %s con sus opciones" % v.get_script().get_global_name())
		v.cerrar()
		await get_tree().process_frame
	var pausa = Ventanas.Pausa.new()
	pausa.jugador = jugador
	hud._abrir_menu(pausa)
	await get_tree().process_frame
	var textos: Array = []
	for b in pausa.find_children("*", "Button", true, false):
		textos.append(b.text)
	comprobar("Sonido y juego…" in textos and "Controles…" in textos, "el menú de pausa tiene Sonido y Controles")
	pausa.cerrar()
	await get_tree().process_frame
	# Copia de seguridad: se guarda dos veces, se rompe la buena y se carga la .bak.
	Juego.dinero = 1234
	comprobar(Guardado.guardar(get_tree(), jugador, 5), "guardar en la ranura 5")
	Juego.dinero = 5678
	Guardado.guardar(get_tree(), jugador, 5)
	comprobar(FileAccess.file_exists(Guardado.ruta(5) + ".bak"), "queda la copia .bak")
	var f: FileAccess = FileAccess.open(Guardado.ruta(5), FileAccess.WRITE)
	f.store_string("{roto")
	f.close()
	comprobar(Guardado.cargar(get_tree(), jugador, 5), "carga aunque la partida esté rota")
	comprobar(Juego.dinero == 1234, "se cargó la copia anterior (dinero %d)" % Juego.dinero)
	Guardado.borrar(5)
	escena.queue_free()
	await get_tree().process_frame
