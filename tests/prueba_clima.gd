# Prueba del clima, la música y los iconos. Abre el mundo de verdad (sin ventana):
#   godot --headless --path . res://tests/prueba_clima.tscn
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
	for i in 3:
		await get_tree().process_frame
	var J = raiz.get_node("Juego")
	J.reiniciar()
	var musica: Musica = escena.find_children("*", "Musica", true, false)[0]
	var clima: Clima = escena.find_children("*", "Clima", true, false)[0]
	# Las capas se crean una por fotograma.
	for i in 12:
		await get_tree().process_frame
	comprobar(musica._capas.size() == 8, "8 capas de sonido, hay %d" % musica._capas.size())
	for k in musica._capas:
		comprobar(musica._capas[k].stream.get_length() > 1.0, "capa %s con audio" % k)
	# Tormenta: forzamos los valores como si hubieran pasado 25 s.
	Clima.poner("tormenta", 6.0)
	for i in 4000:
		clima._process(0.05)
		if i == 0:
			continue
	comprobar(is_equal_approx(Clima.lluvia, 1.0), "tormenta: lluvia 1 (%f)" % Clima.lluvia)
	comprobar(Clima.sigilo() < 0.8, "tormenta reduce la vision de guardias")
	comprobar(Clima.crecimiento() > 1.4, "lluvia acelera cultivos")
	comprobar(Clima.velocidad() < 1.0, "tormenta frena")
	J.interiores = 0
	musica._mezclar(10.0)
	comprobar(musica._capas["lluvia"].volume_db > -30.0, "suena la lluvia (%f)" % musica._capas["lluvia"].volume_db)
	comprobar(musica._capas["campo_dia"].volume_db < -40.0, "sin pajaros en plaza")
	# Niebla y despejado.
	Clima.poner("niebla", 6.0)
	for i in 1000:
		clima._process(0.05)
	comprobar(Clima.niebla > 0.99 and Clima.lluvia < 0.01, "niebla sin lluvia")
	Clima.poner("despejado", 6.0)
	for i in 1000:
		clima._process(0.05)
	comprobar(Clima.sigilo() == 1.0, "despejado: sigilo normal")
	# Guardado y carga del clima.
	Clima.poner("lluvia", 3.0)
	var d: Dictionary = Clima.exportar()
	Clima.poner("despejado", 1.0)
	Clima.importar(JSON.parse_string(JSON.stringify(d)))
	comprobar(Clima.actual == "lluvia", "clima se restaura")
	# Cambios aleatorios no dan error durante muchos ciclos.
	for i in 200:
		clima._elegir_siguiente()
		comprobar(Clima.TIPOS.has(Clima.actual), "clima valido")
	# Recipientes llenados por la lluvia.
	Clima.poner("lluvia", 6.0)
	for i in 4000:
		clima._process(0.05)
	J.anadir("jarra", 1)
	var c = J.inventario[J.inventario.find_custom(func(x): return x != null and x["id"] == "jarra")]
	c["agua"] = 0
	clima._t_recipientes = 0.0
	clima._llenar_recipientes(0.1)
	comprobar(c["agua"] == 1, "lluvia llena jarra")
	# Iconos: todos los tipos de objeto tienen color de fondo (dibujar solo se puede dentro de _draw).
	var DatosObjetos = load("res://scripts/datos/objetos.gd")
	var n: int = 0
	for id in DatosObjetos.LISTA:
		comprobar(Iconos.FONDOS.has(String(DatosObjetos.LISTA[id].get("tipo", ""))), "icono con fondo: " + id)
		n += 1
	print("Iconos probados: ", n)
	print("RESULTADO CLIMA: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)
