# Prueba de los ajustes del administrador y los presets (sin ventana):
#   godot --headless --path . res://tests/prueba_ajustes.tscn
extends Node

var fallos: int = 0


func comprobar(condicion: bool, texto: String) -> void:
	if not condicion:
		fallos += 1
		print("FALLO: ", texto)


func _ready() -> void:
	await get_tree().process_frame
	var raiz: Node = get_tree().root
	var escena: Node = load("res://scenes/mundo.tscn").instantiate()
	raiz.add_child(escena)
	for i in 4:
		await get_tree().process_frame
	var hud = escena.find_children("*", "Hud", true, false)[0]
	if hud._menu != null:
		hud._menu.cerrar()
	var J = raiz.get_node("Juego")
	J.reiniciar()
	var jug = hud.jugador
	var luz: SpotLight3D = jug._linterna
	# Limpio: sin presets previos.
	if FileAccess.file_exists(AjustesMundo.RUTA):
		DirAccess.remove_absolute(AjustesMundo.RUTA)
	comprobar(AjustesMundo.nombres() == PackedStringArray(["Predeterminado"]), "solo el preset fijo al empezar")
	comprobar(is_equal_approx(luz.light_energy, 5.0), "linterna de serie 5")

	# Cambios en vivo.
	AjustesMundo.aplicar({"linterna_energia": 12.0, "linterna_alcance": 60.0, "linterna_angulo": 45.0,
			"linterna_color": "80c0ff", "fov": 90.0, "vel_andar": 2.0, "clima": "tormenta", "hora": 3.5})
	comprobar(is_equal_approx(luz.light_energy, 12.0), "intensidad aplicada")
	comprobar(is_equal_approx(luz.spot_range, 60.0), "alcance aplicado")
	comprobar(is_equal_approx(luz.spot_angle, 45.0), "angulo aplicado")
	comprobar(luz.light_color.to_html(false) == "80c0ff", "color aplicado")
	comprobar(is_equal_approx(jug._camara.fov, 90.0), "fov aplicado")
	comprobar(Clima.actual == "tormenta", "clima aplicado")
	comprobar(is_equal_approx(J.hora, 3.5), "hora aplicada")
	comprobar(is_equal_approx(AjustesMundo.valor("vel_andar"), 2.0), "vel_andar")
	# Valores fuera de rango se recortan.
	AjustesMundo.aplicar({"linterna_energia": 999.0})
	comprobar(is_equal_approx(luz.light_energy, 16.0), "recorta al maximo")
	AjustesMundo.aplicar({"linterna_energia": 12.0})

	# Guardar, cambiar, cargar.
	comprobar(AjustesMundo.guardar("Noche dura") == "", "guardar ok")
	comprobar(AjustesMundo.guardar("") != "", "nombre vacio rechazado")
	comprobar(AjustesMundo.guardar("Predeterminado") != "", "el fijo no se sobrescribe")
	comprobar(AjustesMundo.nombres() == PackedStringArray(["Predeterminado", "Noche dura"]), "lista con el nuevo")
	AjustesMundo.aplicar({"linterna_energia": 2.0, "clima": "despejado", "fov": 70.0})
	comprobar(AjustesMundo.cargar("Noche dura"), "cargar ok")
	comprobar(is_equal_approx(luz.light_energy, 12.0), "preset: intensidad vuelve")
	comprobar(Clima.actual == "tormenta", "preset: clima vuelve")
	comprobar(is_equal_approx(jug._camara.fov, 90.0), "preset: fov vuelve")
	# Sobrescribir.
	AjustesMundo.aplicar({"linterna_energia": 7.0})
	comprobar(AjustesMundo.guardar("Noche dura") == "", "sobrescribir ok")
	AjustesMundo.aplicar({"linterna_energia": 1.0})
	AjustesMundo.cargar("Noche dura")
	comprobar(is_equal_approx(luz.light_energy, 7.0), "sobrescrito")
	# Persistencia: el archivo está en disco y se lee de nuevo.
	comprobar(FileAccess.file_exists(AjustesMundo.RUTA), "archivo en disco")
	comprobar(AjustesMundo.existe("Noche dura"), "se lee del disco")
	# Predeterminado y borrar.
	AjustesMundo.cargar("Predeterminado")
	comprobar(is_equal_approx(luz.light_energy, 5.0) and is_equal_approx(jug._camara.fov, 70.0)
			and Clima.actual == "despejado", "predeterminado restaura")
	comprobar(not AjustesMundo.borrar("Predeterminado"), "el fijo no se borra")
	comprobar(AjustesMundo.borrar("Noche dura"), "borrar ok")
	comprobar(not AjustesMundo.existe("Noche dura") and not AjustesMundo.cargar("Noche dura"), "ya no existe")

	# La ventana se abre y muestra los controles.
	var v: VentanaAjustes = VentanaAjustes.new()
	hud.add_child(v)
	await get_tree().process_frame
	comprobar(v._sliders.size() == AjustesMundo.DEFINICION.size(), "un slider por ajuste")
	v._nombre.text = "Mi preset"
	v._guardar()
	comprobar(AjustesMundo.existe("Mi preset") and v._lista.item_count == 2, "boton Guardar")
	v._guardar()   # Mismo nombre otra vez: pide confirmar.
	v._lista.select(1)
	v._borrar()
	comprobar(AjustesMundo.existe("Mi preset"), "borrar pide confirmacion")
	v._borrar()
	comprobar(not AjustesMundo.existe("Mi preset"), "borrar confirmado")
	v.queue_free()

	if FileAccess.file_exists(AjustesMundo.RUTA):
		DirAccess.remove_absolute(AjustesMundo.RUTA)
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit()
