# juego.gd  (se carga solo al arrancar, con el nombre "Juego")
# -----------------------------------------------------------------------------
# El "cerebro" de la partida: dinero, vida, hora del día, inventario por
# casillas y la estantería de casa. Como está en Autoload, cualquier script
# puede escribir, por ejemplo, Juego.dinero o Juego.avisar("Hola").
#
# INVENTARIO: es una lista de casillas. Cada casilla es null (vacía) o un
# diccionario {"id": "tierra", "cantidad": 5} (algunas llevan datos extra,
# como "agua" en la jarra). Las 9 primeras son la barra rápida (teclas 1-9).
# Cuántas cosas caben por casilla lo dice "pila" en scripts/datos/objetos.gd.
#
# También crea los controles (teclas) para no tener que configurarlos a mano.
# -----------------------------------------------------------------------------
extends Node

# Datos de objetos y habilidades (se cargan con preload para no depender de
# que el editor haya registrado los nombres de clase).
const DatosObjetos = preload("res://scripts/datos/objetos.gd")
const DatosHabilidades = preload("res://scripts/datos/habilidades.gd")
const DatosAspecto = preload("res://scripts/jugador/aspecto.gd")

signal cambio                     # Dinero, vida o inventario han cambiado.
signal mensaje(texto: String)     # Mostrar un mensaje en pantalla.
signal dia_nuevo                  # Ha empezado un día nuevo del juego (lo usan los negocios).

const TAM_BARRA: int = 9
const TAM_INVENTARIO: int = 63    # 9 de la barra + 54 de la mochila.
const TAM_ESTANTERIA: int = 36
const VIDA_MAX: float = 100.0
# Cuánto dura un día entero del juego, en minutos reales (se cambia en F1).
const DURACION_DIA_POR_DEFECTO: float = 60.0

var dinero: int = 0
var vida: float = VIDA_MAX
var hora: float = 20.0               # De 0 a 24. Empieza al anochecer.
var dia: int = 1
var duracion_dia_min: float = DURACION_DIA_POR_DEFECTO   # Minutos reales por día.
var velocidad_tiempo: float = 1.0    # 0 = pausa, 1 = normal, 10 = rápido...
var ha_ganado: bool = false
var alerta: float = 0.0              # 0-100: cuánto te buscan los guardias (100 = te están viendo).
var motivo_alerta: String = ""       # Por qué te persiguen (se muestra en pantalla).
var policia_activa: bool = true     # Se cambia desde el panel admin (F1).
var sospecha: float = 0.0           # 0-100: sube si llevas ilegal, corres con ello o vendes; baja con el tiempo. Sube la prob. de cacheo y registro.
var _t_sospecha: float = 0.0
var delito_visto: float = 0.0       # Segundos que quedan de "te vieron vender ilegal en la calle".
var enfriamiento_cacheo: float = 0.0  # Segundos hasta que te puedan cachear otra vez.
var huertos: Dictionary = {}          # id_huerto -> true (alquilado o comprado).
var en_propiedad: Dictionary = {}     # id -> true: casas y huertos COMPRADOS (se pueden vender).
var granja: Dictionary = {}           # corrales y árboles: id -> estado (animales, producción, nivel).
var parcelas: Dictionary = {}         # id_huerto -> {semilla, t, total}: cultivo en curso.
var limites_mundo: Rect2 = Rect2(-47, -111, 354, 222)   # Lo fija mundo.gd al cerrar la ciudad.
var interiores: int = 0              # Cuántos edificios con interior pisas ahora (0 = estás en la calle).
var viviendas: Dictionary = {}      # id_vivienda -> true si la tienes alquilada.
var nivel: int = 1
var xp: int = 0                      # Experiencia hacia el siguiente nivel.
var reputacion: int = 0              # -50..100: sube al entregar encargos, baja si dejas plantado.
var encargos: Array = []             # Encargos del móvil (ver scripts/encargos.gd).
var pedidos_material: Array = []     # Pedidos de materiales en camino.
var avisos: Array = []               # Últimos avisos del móvil (más nuevo primero).
var personal: Array = []             # Empleados contratados (ver scripts/datos/personal.gd).
var almacen: Dictionary = {}         # Lo que produce el personal: id_objeto -> cantidad.
var almacen_ultima_semilla: Dictionary = {}   # id_huerto -> última semilla (para volver a sembrar).
var dia_pago: int = 1                # Último día en que se pagó al personal.
var negocio: Dictionary = {}         # Licencias, cartera, mercado y clientes de tus negocios (ver scripts/negocios.gd).
var vehiculos: Dictionary = {}       # id -> {tipo, pos, giro, gas, salud}: vehículos tuyos (ver vehiculo.gd).
var _contador_vehiculos: int = 0
var aspecto: Dictionary = {}         # Cómo se ve el jugador (ver scripts/jugador/aspecto.gd).
var habilidades: Dictionary = {}     # id_habilidad -> true (ver scripts/datos/habilidades.gd)

var inventario: Array = []
var estanteria: Array = []
var seleccion: int = 0               # Casilla de la barra que tienes en la mano.

# true mientras hay un menú abierto (tienda, inventario, minijuego...):
# el jugador no se mueve y el ratón se puede usar para hacer clic.
var menu_abierto: bool = false


func _ready() -> void:
	randomize()
	_crear_controles()
	reiniciar()


func reiniciar() -> void:
	dinero = GameData.DINERO_INICIAL
	vida = VIDA_MAX
	hora = 20.0
	dia = 1
	duracion_dia_min = DURACION_DIA_POR_DEFECTO
	velocidad_tiempo = 1.0
	ha_ganado = false
	viviendas.clear()
	huertos.clear()
	en_propiedad.clear()
	parcelas.clear()
	granja.clear()
	alerta = 0.0
	motivo_alerta = ""
	nivel = 1
	xp = 0
	habilidades.clear()
	aspecto = DatosAspecto.POR_DEFECTO.duplicate()
	vehiculos.clear()
	personal.clear()
	almacen.clear()
	almacen_ultima_semilla.clear()
	dia_pago = 1
	negocio = {}
	_contador_vehiculos = 0
	reputacion = 0
	sospecha = 0.0
	encargos.clear()
	pedidos_material.clear()
	avisos.clear()
	inventario.clear()
	inventario.resize(TAM_INVENTARIO)
	estanteria.clear()
	estanteria.resize(TAM_ESTANTERIA)
	seleccion = 0
	cambio.emit()


func _process(delta: float) -> void:
	# La búsqueda baja sola con el tiempo: más rápido si te escondes dentro de un edificio.
	_t_sospecha += delta
	if _t_sospecha >= 1.0:
		var dt: float = _t_sospecha
		_t_sospecha = 0.0
		var delta_s: float = -0.6   # Baja con el tiempo.
		if lleva_ilegal():
			delta_s += 0.9
			if Input.is_action_pressed("correr"):
				delta_s += 0.6
		if delito_visto > 0.0:
			delta_s += 3.0
		sospecha = clampf(sospecha + delta_s * dt, 0.0, 100.0)
	delito_visto = maxf(0.0, delito_visto - delta)
	enfriamiento_cacheo = maxf(0.0, enfriamiento_cacheo - delta)
	if alerta > 0.0:
		alerta = maxf(0.0, alerta - delta * (30.0 if interiores > 0 else 6.0))
	hora += delta * 24.0 / (maxf(1.0, duracion_dia_min) * 60.0) * velocidad_tiempo
	if hora >= 24.0:
		hora -= 24.0
		dia += 1
		dia_nuevo.emit()


func siguiente_vehiculo() -> int:
	_contador_vehiculos += 1
	return _contador_vehiculos


# Lista de lo ilegal que llevas, para decírtelo en pantalla.
func motivos_ilegales() -> PackedStringArray:
	var tipos: Dictionary = {}
	for casilla in inventario:
		if casilla != null:
			tipos[DatosObjetos.datos(casilla["id"])["tipo"]] = true
	var lista: PackedStringArray = []
	if tipos.has("pocion") or tipos.has("paquete"):
		lista.append("pociones prohibidas")
	if tipos.has("hierba"):
		lista.append("hierbas prohibidas")
	if tipos.has("arma_fuego"):
		lista.append("armas de fuego")
	if tipos.has("explosivo"):
		lista.append("explosivos")
	return lista


# ¿Llevas algo ilegal? (pociones, hierbas, armas de fuego o explosivos.) Los
# guardias solo te persiguen si es así.
func lleva_ilegal() -> bool:
	for casilla in inventario:
		if casilla == null:
			continue
		var tipo: String = DatosObjetos.datos(casilla["id"])["tipo"]
		if tipo == "pocion" or tipo == "paquete" or tipo == "hierba" or tipo == "arma_fuego" or tipo == "explosivo":
			return true
	return false


# Experiencia que hace falta para pasar del nivel actual al siguiente.
func xp_necesaria() -> int:
	return 100 * nivel


# Suma experiencia (plantar, cosechar, preparar y vender dan XP) y sube de nivel.
func ganar_xp(cantidad: int) -> void:
	xp += cantidad
	while xp >= xp_necesaria():
		xp -= xp_necesaria()
		nivel += 1
		avisar("¡Subes al nivel %d! Hay objetos nuevos en las tiendas." % nivel)
	cambio.emit()


# Aprende una habilidad pagando a un instructor. Devuelve lo que ha pasado.
func aprender(id_hab: String) -> String:
	var datos: Dictionary = DatosHabilidades.LISTA[id_hab]
	if habilidades.has(id_hab):
		return "Ya sabes %s." % datos["nombre"]
	if nivel < datos["nivel"]:
		return "Necesitas nivel %d para aprender %s." % [datos["nivel"], datos["nombre"]]
	if not gastar(datos["precio"]):
		return "No te llega: cuesta %d $." % datos["precio"]
	habilidades[id_hab] = true
	cambio.emit()
	return "¡Has aprendido %s!" % datos["nombre"]


# Texto de la hora, por ejemplo "21:05".
func texto_hora() -> String:
	var minutos: int = int(hora * 60.0) % (24 * 60)
	return "%02d:%02d" % [minutos / 60, minutos % 60]


# ¿Tienes alquilada esa vivienda? (Cada casa de la ciudad tiene su identificador.)
func alquilada(id_casa: String) -> bool:
	return viviendas.has(id_casa)


func tiene_vivienda() -> bool:
	return not viviendas.is_empty()


func es_de_noche() -> bool:
	return hora < 7.0 or hora >= 20.0


# ------------------------------ Dinero y vida ---------------------------------

func gastar(cantidad: int) -> bool:
	if dinero < cantidad:
		return false
	dinero -= cantidad
	cambio.emit()
	return true


func cobrar(cantidad: int) -> void:
	dinero += cantidad
	cambio.emit()
	if not ha_ganado and dinero >= GameData.OBJETIVO_DINERO:
		ha_ganado = true
		avisar("¡Has reunido %d $ para el Prefecto! Prototipo superado." % GameData.OBJETIVO_DINERO)


func cambiar_vida(cantidad: float) -> void:
	vida = clampf(vida + cantidad, 0.0, VIDA_MAX)
	cambio.emit()


# -------------------------------- Inventario ----------------------------------

# Mete objetos en el inventario. Primero rellena montones que ya existan;
# luego usa casillas vacías. Devuelve lo que NO ha cabido.
func anadir(id: String, cantidad: int = 1) -> int:
	var sobra: int = _anadir_en(inventario, id, cantidad, 0)
	cambio.emit()
	return sobra


func _nueva_casilla(id: String, cantidad: int) -> Dictionary:
	var casilla: Dictionary = {"id": id, "cantidad": cantidad}
	var datos: Dictionary = DatosObjetos.datos(id)
	if datos.has("agua_max"):
		casilla["agua"] = datos["agua_max"]   # Las jarras se compran llenas.
	return casilla


# Cuántos hay en total de un objeto.
func cuenta(id: String) -> int:
	var total: int = 0
	for casilla in inventario:
		if casilla != null and casilla["id"] == id:
			total += casilla["cantidad"]
	return total


func tiene(id: String, cantidad: int = 1) -> bool:
	return cuenta(id) >= cantidad


# Quita objetos (empezando por el final, para no vaciar la barra).
func quitar(id: String, cantidad: int = 1) -> bool:
	if cuenta(id) < cantidad:
		return false
	for i in range(inventario.size() - 1, -1, -1):
		var casilla = inventario[i]
		if cantidad <= 0:
			break
		if casilla != null and casilla["id"] == id:
			var saca: int = mini(cantidad, casilla["cantidad"])
			casilla["cantidad"] -= saca
			cantidad -= saca
			if casilla["cantidad"] <= 0:
				inventario[i] = null
	cambio.emit()
	return true


# La casilla de la barra que tienes en la mano (o null).
func en_mano():
	return inventario[seleccion]


func id_en_mano() -> String:
	var casilla = en_mano()
	return "" if casilla == null else casilla["id"]


func seleccionar(indice: int) -> void:
	seleccion = posmod(indice, TAM_BARRA)
	cambio.emit()


# Busca la mejor herramienta para regar: la de la mano si riega y tiene agua;
# si no, la primera que tenga agua. Devuelve la casilla o null.
func recipiente_de_agua():
	var mano = en_mano()
	if mano != null and mano.has("agua") and mano["agua"] > 0:
		return mano
	for casilla in inventario:
		if casilla != null and casilla.has("agua") and casilla["agua"] > 0:
			return casilla
	return null


# ¿Llevas algo donde guardar agua (jarra, regadera...)?
func tiene_recipiente() -> bool:
	for casilla in inventario:
		if casilla != null and casilla.has("agua"):
			return true
	return false


# Rellena todos tus recipientes en el grifo. Devuelve cuántos había.
func rellenar_agua() -> int:
	var total: int = 0
	for casilla in inventario:
		if casilla != null and casilla.has("agua"):
			casilla["agua"] = DatosObjetos.datos(casilla["id"])["agua_max"]
			total += 1
	cambio.emit()
	return total


# ¿Caben "cantidad" unidades de "id" en tu inventario?
func cabe(id: String, cantidad: int = 1) -> bool:
	var maximo: int = DatosObjetos.pila(id)
	var hueco: int = 0
	for casilla in inventario:
		if casilla == null:
			hueco += maximo
		elif casilla["id"] == id and not casilla.has("agua"):
			hueco += maximo - casilla["cantidad"]
	return hueco >= cantidad


# Intercambia (o junta, si son del mismo objeto) dos casillas. Sirve para
# mover cosas dentro del inventario o entre el inventario y la estantería.
func mover(lista_a: Array, i: int, lista_b: Array, j: int) -> void:
	if is_same(lista_a, lista_b) and i == j:
		return
	var a = lista_a[i]
	var b = lista_b[j]
	var juntar: bool = a != null and b != null and a["id"] == b["id"] and not a.has("agua") \
			and b["cantidad"] < DatosObjetos.pila(b["id"])
	if juntar:
		var maximo: int = DatosObjetos.pila(a["id"])
		var pasa: int = mini(a["cantidad"], maximo - b["cantidad"])
		b["cantidad"] += pasa
		a["cantidad"] -= pasa
		if a["cantidad"] <= 0:
			lista_a[i] = null
	else:
		lista_a[i] = b
		lista_b[j] = a
	cambio.emit()


# Parte un montón por la mitad y deja la otra mitad en una casilla vacía.
func dividir(lista: Array, i: int) -> void:
	var casilla = lista[i]
	if casilla == null or casilla["cantidad"] < 2:
		return
	var hueco: int = lista.find(null)
	if hueco == -1:
		return
	var mitad: int = casilla["cantidad"] / 2
	casilla["cantidad"] -= mitad
	lista[hueco] = {"id": casilla["id"], "cantidad": mitad}
	cambio.emit()


# Junta montones iguales y ordena por tipo y nombre las casillas desde "desde"
# hasta el final (en el inventario, desde 9 para no tocar la barra rápida).
func ordenar(lista: Array, desde: int = 0) -> void:
	var cosas: Array = []
	for i in range(desde, lista.size()):
		if lista[i] != null:
			cosas.append(lista[i])
		lista[i] = null
	cosas.sort_custom(func(a, b) -> bool:
		var da: Dictionary = DatosObjetos.datos(a["id"])
		var db: Dictionary = DatosObjetos.datos(b["id"])
		if da["tipo"] != db["tipo"]:
			return da["tipo"] < db["tipo"]
		return da["nombre"] < db["nombre"])
	var i: int = desde
	for casilla in cosas:
		# ¿Se puede juntar con la anterior?
		if i > desde and not casilla.has("agua"):
			var previa = lista[i - 1]
			if previa["id"] == casilla["id"]:
				var maximo: int = DatosObjetos.pila(casilla["id"])
				var pasa: int = mini(casilla["cantidad"], maximo - previa["cantidad"])
				previa["cantidad"] += pasa
				casilla["cantidad"] -= pasa
				if casilla["cantidad"] <= 0:
					continue
		lista[i] = casilla
		i += 1
	cambio.emit()


# Mueve una casilla entera a otra lista (clic con Mayúsculas). Devuelve true si cupo.
func mover_rapido(origen: Array, i: int, destino: Array, desde: int = 0) -> void:
	var casilla = origen[i]
	if casilla == null:
		return
	if casilla.has("agua"):
		var hueco: int = destino.find(null, desde)
		if hueco != -1:
			destino[hueco] = casilla
			origen[i] = null
	else:
		var sobra: int = _anadir_en(destino, casilla["id"], casilla["cantidad"], desde)
		if sobra <= 0:
			origen[i] = null
		else:
			casilla["cantidad"] = sobra
	cambio.emit()


# Como anadir(), pero empezando en la casilla "desde" y sin avisar.
func _anadir_en(lista: Array, id: String, cantidad: int, desde: int) -> int:
	var maximo: int = DatosObjetos.pila(id)
	for k in range(desde, lista.size()):
		var c = lista[k]
		if cantidad > 0 and c != null and c["id"] == id and c["cantidad"] < maximo:
			var cabe: int = mini(cantidad, maximo - c["cantidad"])
			c["cantidad"] += cabe
			cantidad -= cabe
	for k in range(desde, lista.size()):
		if cantidad > 0 and lista[k] == null:
			var cabe: int = mini(cantidad, maximo)
			lista[k] = _nueva_casilla(id, cabe)
			cantidad -= cabe
	return cantidad


# Devuelve "" si el jugador puede comprar el objeto, o el motivo si no.
func motivo_no_compra(id: String) -> String:
	var datos: Dictionary = DatosObjetos.datos(id)
	if nivel < datos["nivel"]:
		return "Necesitas nivel %d" % datos["nivel"]
	if datos["habilidad"] != "" and not habilidades.has(datos["habilidad"]):
		return "Necesitas la habilidad: %s" % DatosHabilidades.nombre(datos["habilidad"])
	return ""


# Usa lo que llevas en la mano con el clic izquierdo (comida y medicinas curan).
func usar_en_mano() -> void:
	var casilla = en_mano()
	if casilla == null:
		return
	var datos: Dictionary = DatosObjetos.datos(casilla["id"])
	if not datos.has("cura"):
		return
	if vida >= VIDA_MAX:
		avisar("Ya tienes la vida completa.")
		return
	cambiar_vida(datos["cura"])
	casilla["cantidad"] -= 1
	if casilla["cantidad"] <= 0:
		inventario[seleccion] = null
	avisar("Usas %s (+%d de vida)." % [datos["nombre"], datos["cura"]])
	cambio.emit()


# Vende una casilla entera a una tienda por la mitad de su precio.
func vender(lista: Array, i: int) -> String:
	var casilla = lista[i]
	if casilla == null:
		return ""
	var datos: Dictionary = DatosObjetos.datos(casilla["id"])
	if datos["precio"] <= 0:
		return "Aquí no compran %s." % datos["nombre"]
	var pago: int = maxi(1, datos["precio"] / 2) * casilla["cantidad"]
	lista[i] = null
	cobrar(pago)
	# Revender a una tienda no da experiencia: si no, comprar y vender sin parar
	# subiría de nivel. La XP sale de plantar, cosechar, preparar y vender pociones.
	return "Has vendido %d %s por %d $." % [casilla["cantidad"], datos["nombre"], pago]


# Compra un objeto. Devuelve un texto con lo que ha pasado.
func comprar(id: String) -> String:
	var datos: Dictionary = DatosObjetos.datos(id)
	var motivo: String = motivo_no_compra(id)
	if motivo != "":
		return motivo + " para comprar %s." % datos["nombre"]
	if dinero < datos["precio"]:
		return "No te llega: %s cuesta %d $." % [datos["nombre"], datos["precio"]]
	if not cabe(id):
		return "No te cabe nada más en el inventario."
	gastar(datos["precio"])
	anadir(id)
	return "Has comprado %s por %d $." % [datos["nombre"], datos["precio"]]


# La policía entra en una casa con la puerta abierta y registra la estantería:
# confisca lo ilegal y cobra una multa. Devuelve un texto para el aviso.
func registrar_casa() -> String:
	var tipos_ilegales: Array = ["pocion", "paquete", "hierba", "arma_fuego", "explosivo"]
	var montones: int = 0
	var unidades: int = 0
	for i in estanteria.size():
		var c = estanteria[i]
		if c != null and DatosObjetos.datos(c["id"])["tipo"] in tipos_ilegales:
			montones += 1
			unidades += int(c["cantidad"])
			estanteria[i] = null
	if montones == 0:
		return "La policía ha entrado en tu casa por la puerta abierta, no ha encontrado nada y se ha ido."
	var multa: int = mini(dinero, 30 * montones + 5 * unidades)
	dinero -= multa
	cambio.emit()
	return "¡La policía ha registrado tu casa (puerta abierta)! Confiscado lo ilegal de tu estantería y multa de %d $." % multa


func avisar(texto: String) -> void:
	mensaje.emit(texto)


# Aviso del móvil: sale en pantalla y queda guardado en la pestaña "Avisos".
func nuevo_aviso(texto: String) -> void:
	avisos.push_front("Día %d, %s  ·  %s" % [dia, texto_hora(), texto])
	if avisos.size() > 25:
		avisos.resize(25)
	avisar(texto)
	cambio.emit()


# ------------------------------ Controles -------------------------------------
# Usamos "physical_keycode": la tecla por su posición en el teclado.

func _crear_controles() -> void:
	_accion("adelante", [KEY_W, KEY_UP])
	_accion("atras", [KEY_S, KEY_DOWN])
	_accion("izquierda", [KEY_A, KEY_LEFT])
	_accion("derecha", [KEY_D, KEY_RIGHT])
	_accion("telefono", [KEY_P])   # Sacar el móvil.
	_accion("mapa_grande", [KEY_N])   # Mapa de la ciudad a pantalla completa.
	_accion("mapa", [KEY_M])   # Cambia el zoom del minimapa.
	_accion("correr", [KEY_SHIFT])
	_accion("saltar", [KEY_SPACE])
	_accion("usar", [KEY_E])
	_accion("cambiar_camara", [KEY_V])
	_accion("inventario", [KEY_TAB])
	_accion("admin", [KEY_F1])
	_accion("recargar", [KEY_R])
	_accion("enganchar", [KEY_H])   # Enganchar o soltar un remolque.
	_accion("aspecto", [KEY_O])   # Cambiar de ropa y peinado.
	_accion("colocar", [KEY_G])   # Montar el objeto que llevas en la mano.
	_accion("agacharse", [KEY_C, KEY_CTRL])
	_accion("liberar_raton", [KEY_ESCAPE])
	for i in TAM_BARRA:
		_accion("barra_%d" % (i + 1), [KEY_1 + i])


func _accion(nombre: String, teclas: Array) -> void:
	if InputMap.has_action(nombre):
		return
	InputMap.add_action(nombre)
	for tecla in teclas:
		var evento: InputEventKey = InputEventKey.new()
		evento.physical_keycode = tecla
		InputMap.action_add_event(nombre, evento)
