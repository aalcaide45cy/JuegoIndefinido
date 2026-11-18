# Dinero limpio y negro: cobro ilegal, blanqueo, límites, comisión, vigilancia, policía y guardado.
#   godot --headless --path . res://tests/prueba_dinero_negro.tscn
extends Node

var fallos: int = 0


func _ok(cond: bool, texto: String) -> void:
	if not cond:
		fallos += 1
		print("FALLO: ", texto)


func _ready() -> void:
	await get_tree().process_frame
	var raiz: Node = get_tree().root
	raiz.add_child(load("res://scenes/mundo.tscn").instantiate())
	await get_tree().process_frame
	await get_tree().process_frame
	var J = raiz.get_node("Juego")
	J.reiniciar()
	J.nivel = 10
	_ok(J.dinero == 200 and J.dinero_negro == 0, "empieza con 200 limpios y 0 negro")
	# Cobrar ilegal = negro
	J.cobrar_negro(1000)
	_ok(J.dinero == 200 and J.dinero_negro == 1000, "cobrar_negro no toca el limpio")
	# Compras serias solo limpio
	_ok(not J.gastar(500), "gastar() solo acepta limpio")
	_ok(J.gastar_con_negro(300) and J.dinero_negro == 700 and J.dinero == 200, "gastar_con_negro gasta primero negro")
	_ok(J.gastar_con_negro(800) and J.dinero_negro == 0 and J.dinero == 100, "gastar_con_negro completa con limpio")
	_ok(not J.gastar_con_negro(1000), "no gasta si no llega")
	# Sin licencia no se puede
	J.dinero_negro = 1000
	_ok(Blanqueo.blanquear("tienda", 100).begins_with("Necesitas"), "sin licencia no blanquea")
	Negocios.estado()["licencias"]["tienda"] = true
	# Límite y comisión (25 %)
	_ok(Blanqueo.limite("tienda") == 300, "limite tienda 300")
	var limpio0: int = J.dinero
	Blanqueo.blanquear("tienda", 200)
	_ok(J.dinero == limpio0 + 150 and J.dinero_negro == 800, "200 negro -> 150 limpio (comisión 25 %%): %d" % J.dinero)
	Blanqueo.blanquear("tienda", 500)   # solo caben 100 más
	_ok(Blanqueo.usado_hoy("tienda") == 300 and J.dinero_negro == 700, "tope diario respetado")
	_ok(Blanqueo.blanquear("tienda", 50).find("no puede mover") >= 0, "tope agotado avisa")
	_ok(J.vigilancia_fiscal > 20.0, "sube la vigilancia: %f" % J.vigilancia_fiscal)
	_ok(J.sospecha > 0.5, "sube la sospecha")
	# Nuevo día: se renueva el tope y baja la vigilancia
	var v0: float = J.vigilancia_fiscal
	J.dia += 1
	Blanqueo.nuevo_dia()
	_ok(Blanqueo.disponible("tienda") == 300, "tope renovado al día siguiente")
	_ok(J.vigilancia_fiscal < v0, "la vigilancia baja de un día a otro")
	# Crece con activos
	Negocios.estado()["licencias"]["inmobiliaria"] = true
	_ok(Blanqueo.limite("inmobiliaria") == 1800, "inmobiliaria sin pisos 1800")
	Negocios.estado()["activos"].append({"uid": 99, "tipo": "estudio", "estado": 100.0, "compra": 1, "venta": false, "alq_anuncio": false, "alq": {}})
	_ok(Blanqueo.limite("inmobiliaria") == 2250, "un piso sube el limite un 25 %%")
	# Inspección
	J.vigilancia_fiscal = 100.0
	J.dinero_negro = 1000
	J.dinero = 1000
	J.estrellas = 0
	var antes_est: int = J.estrellas
	Blanqueo.inspeccion()
	_ok(J.dinero_negro == 750 and J.dinero == 950, "inspección: -25 %% negro, -5 %% limpio")
	_ok(J.estrellas > antes_est, "inspección sube estrellas")
	# Detención con 3 estrellas: 0,4+0,36 = 76 % del negro
	J.dinero_negro = 1000
	J.estrellas = 3
	J.vigilancia_fiscal = 0.0   # (la cárcel pasa horas y podría haber inspección)
	J.detener()
	_ok(J.dinero_negro == 240, "detención con 3 estrellas quita el 76 %% del negro: %d" % J.dinero_negro)
	# Sospecha por llevar mucho negro
	_ok(J.DatosBlanqueo.sospecha_por_segundo(100) == 0.0, "poco negro no sospecha")
	_ok(J.DatosBlanqueo.sospecha_por_segundo(4000) >= 1.0, "mucho negro sospecha")
	# Guardado y partidas antiguas
	J.dinero_negro = 777
	J.vigilancia_fiscal = 33.0
	var jug: Node3D = raiz.get_tree().get_first_node_in_group("jugador")
	_ok(Guardado.guardar(raiz.get_tree(), jug, 5), "guarda")
	J.dinero_negro = 0
	J.vigilancia_fiscal = 0.0
	Negocios.estado()["blanqueo"] = {"dia": 1, "hoy": {}, "total": 0}
	_ok(Guardado.cargar(raiz.get_tree(), jug, 5), "carga")
	_ok(J.dinero_negro == 777 and int(J.vigilancia_fiscal) == 33, "el negro y la vigilancia se guardan")
	_ok(Blanqueo.total_blanqueado() == 300, "el estado de blanqueo se guarda: %d" % Blanqueo.total_blanqueado())
	var ruta: String = "user://partida_5.json"
	var f = FileAccess.open(ruta, FileAccess.READ)
	var datos: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	datos.erase("dinero_negro")
	datos.erase("vigilancia_fiscal")
	datos["negocio"].erase("blanqueo")
	var g = FileAccess.open(ruta, FileAccess.WRITE)
	g.store_string(JSON.stringify(datos))
	g.close()
	_ok(Guardado.cargar(raiz.get_tree(), jug, 5), "carga partida antigua")
	_ok(J.dinero_negro == 0 and J.vigilancia_fiscal == 0.0, "partida antigua: negro 0")
	Blanqueo.blanquear("tienda", 1)   # no debe fallar sin estado
	DirAccess.remove_absolute(ruta)
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)
