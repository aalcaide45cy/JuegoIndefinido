# Saca una captura de CADA menú del juego (sirve para comparar "antes" y "después"):
#   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 res://tests/captura_menus.tscn -- /carpeta [prefijo] [solo1,solo2]
# Si algún menú no se puede abrir, lo apunta como FALLO y sigue con el siguiente.
extends Node

const DatosObjetos = preload("res://scripts/datos/objetos.gd")

var carpeta: String = "."
var prefijo: String = "menu"
var hud: Hud
var fallos: PackedStringArray = []
var n: int = 0
var solo: PackedStringArray = []   # Si no está vacío, solo se fotografían los menús cuyo nombre contenga alguno.


func _foto(nombre: String) -> void:
	if not solo.is_empty():
		var vale: bool = false
		for t in solo:
			vale = vale or nombre.contains(t)
		if not vale:
			return
	for i in 4:
		await get_tree().process_frame
	n += 1
	get_viewport().get_texture().get_image().save_jpg("%s/%s_%02d_%s.jpg" % [carpeta, prefijo, n, nombre], 0.9)


# Abre una ventana como menú principal, la fotografía y la cierra.
func _ventana(nombre: String, v: Control, antes: Callable = Callable()) -> void:
	if v == null:
		fallos.append("No se pudo crear: " + nombre)
		return
	hud._abrir_menu(v)
	if antes.is_valid():
		antes.call(v)
	await _foto(nombre)
	if is_instance_valid(v) and v.has_method("cerrar"):
		v.cerrar()
	else:
		hud._al_cerrar_menu()
	await get_tree().process_frame


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	if args.size() > 1:
		prefijo = args[1]
	if args.size() > 2:
		solo = args[2].split(",")
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	await get_tree().process_frame
	await get_tree().process_frame
	hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	Juego.reiniciar()
	Juego.hora = 20.5
	Juego.nivel = 7
	Juego.dinero = 3400
	for id in ["hierba_bruma", "hierba_raiz_ardiente", "hierba_musgo_dulce", "aditivo_miel", "aditivo_sal", "hierba_flor_sol", "botiquin", "cafe",
			"pistola", "municion_pistola", "cuchillo", "bate", "ganzua", "semilla_bruma", "semilla_trigo", "trigo", "pan", "empanada", "antidoto",
			"aditivo_azufre", "granada", "maceta", "jarra", "regadera", "venda", "tomate", "manzana"]:
		if DatosObjetos.existe(id):
			Juego.anadir(id, 4)
	await get_tree().create_timer(3.0).timeout
	await _foto("hud_juego")

	var inicio: Ventanas.Inicio = Ventanas.Inicio.new()
	inicio.jugador = hud.jugador
	await _ventana("inicio", inicio)
	var pausa: Ventanas.Pausa = Ventanas.Pausa.new()
	pausa.jugador = hud.jugador
	hud._abrir_menu(pausa)
	await _foto("pausa")
	var ajustes: VentanaAjustes = VentanaAjustes.new()
	pausa.add_child(ajustes)
	for i in 3:
		ajustes._pestanas.elegir(i)
		await _foto("ajustes_%d" % i)
	ajustes._campo.text = "volumen"
	ajustes._campo.text_changed.emit("volumen")
	await _foto("ajustes_buscar")
	ajustes.cerrar()
	await get_tree().process_frame
	var partidas: VentanaPartidas = VentanaPartidas.new()
	partidas.modo = VentanaPartidas.Modo.INICIO
	pausa.add_child(partidas)
	await _foto("partidas")
	partidas.cerrar()
	pausa.cerrar()
	await get_tree().process_frame

	await _ventana("inventario", Ventanas.Inventario.new())
	var tienda: Ventanas.Tienda = Ventanas.Tienda.new()
	tienda.tienda = "botica"
	tienda.nombre_tienda = "Botica"
	await _ventana("tienda", tienda)
	var arm: Ventanas.Tienda = Ventanas.Tienda.new()
	arm.tienda = "armeria"
	arm.nombre_tienda = "Armería"
	await _ventana("tienda_armeria_vender", arm, func(v) -> void:
		v._pestanas.elegir(1)
		v._detalle.mostrar("pistola", 1))
	await _ventana("caldero", Ventanas.VentanaCaldero.new())
	await _ventana("estanteria", Ventanas.Estanteria.new())
	await _ventana("instructor", Ventanas.Instructor.new())
	var admin: Ventanas.Admin = Ventanas.Admin.new()
	admin.jugador = hud.jugador
	hud._abrir_menu(admin)
	for i in 6:
		admin._pestanas.elegir(i)
		await _foto("admin_%d" % i)
	admin._campo.text = "hora"
	admin._campo.text_changed.emit("hora")
	await _foto("admin_buscar")
	admin.cerrar()
	await get_tree().process_frame
	for p in 6:
		var tel: Telefono = Telefono.new()
		tel._pestana = p
		await _ventana("telefono_%d" % p, tel)
	var mapa: MapaGrande = MapaGrande.new()
	mapa.jugador = hud.jugador
	await _ventana("mapa_grande", mapa)
	await _ventana("logros", VentanaLogros.new())
	await _ventana("aspecto", VentanaAspecto.new())
	var pel: VentanaPeluqueria = VentanaPeluqueria.new()
	await _ventana("peluqueria", pel)
	await _ventana("grimorio", VentanaGrimorio.new())
	await _ventana("casino", VentanaCasino.new())
	await _ventana("medico", VentanaMedico.new())
	await _ventana("cacheo", Cacheo.new())
	var mach: MinijuegoMachacar = MinijuegoMachacar.new()
	mach.hierba = "hierba_bruma"
	await _ventana("minijuego_mortero", mach)
	await _ventana("inmobiliaria", Inmobiliaria.new())
	await _ventana("bolsa_trabajo", BolsaTrabajo.new())
	var conc: VentanaConcesionario = VentanaConcesionario.new()
	conc.punto = hud.jugador.global_position
	await _ventana("concesionario", conc)
	await _ventana("negocios", VentanaNegocios.new())
	var locales: Array = escena.find_children("*", "LocalMundo", true, false)
	if not locales.is_empty():
		var vl: VentanaLocal = VentanaLocal.new()
		vl.local_mundo = locales[0]
		await _ventana("local", vl)
	else:
		fallos.append("No hay LocalMundo en el mundo")
	for f in fallos:
		print("FALLO: ", f)
	print("CAPTURAS: ", n)
	get_tree().quit()
