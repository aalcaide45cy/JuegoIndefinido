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
const DatosPropiedades = preload("res://scripts/datos/propiedades.gd")
const DatosMetas = preload("res://scripts/datos/metas.gd")
const Economia = preload("res://scripts/datos/economia.gd")
const DatosPolicia = preload("res://scripts/datos/policia.gd")
const DatosObjetos = preload("res://scripts/datos/objetos.gd")
const DatosHabilidades = preload("res://scripts/datos/habilidades.gd")
const DatosAspecto = preload("res://scripts/jugador/aspecto.gd")
const DatosEfectos = preload("res://scripts/datos/efectos.gd")
const DatosOficios = preload("res://scripts/datos/oficios.gd")
const Mezclas = preload("res://scripts/datos/mezclas.gd")

signal cambio                     # Dinero, vida o inventario han cambiado.
signal mensaje(texto: String)     # Mostrar un mensaje en pantalla.
signal dia_nuevo                  # Ha empezado un día nuevo del juego (lo usan los negocios).
signal efectos_cambiados          # Se ha añadido o quitado un efecto temporal.

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
var impagos: Dictionary = {}          # id de propiedad alquilada -> días seguidos sin pagar.
var metas_cobradas: Dictionary = {}   # id de meta -> true (ver datos/metas.gd).
# Oficios (ver datos/oficios.gd): el actual, la experiencia en cada uno y si estás de servicio.
var oficio: String = ""
var oficios_xp: Dictionary = {}       # id de oficio -> experiencia de oficio.
var en_turno: bool = false
var turno_pago: float = 0.0           # Sueldo acumulado en este turno (se cobra al terminarlo).
var texto_aviso_oficio: String = ""  # Lo escribe gestor_oficio.gd para el HUD.
var sin_correr: float = 0.0           # Segundos de convalecencia: tras curarte no puedes correr.
var _t_metas: float = 0.0
var _t_aviso_regen: float = 0.0
var reloj: float = 0.0               # Segundos de juego acumulados (reloj absoluto para granja y macetas).
var duracion_dia_min: float = DURACION_DIA_POR_DEFECTO   # Minutos reales por día.
var velocidad_tiempo: float = 1.0    # 0 = pausa, 1 = normal, 10 = rápido...
var ha_ganado: bool = false
var alerta: float = 0.0              # 0-100: cuánto te buscan los guardias (100 = te están viendo).
var motivo_alerta: String = ""       # Por qué te persiguen (se muestra en pantalla).
# Modo volar (panel admin F1). La rueda del ratón cambia la velocidad de vuelo.
const VELOCIDAD_VUELO_NORMAL: float = 25.0   # m/s
const VELOCIDAD_VUELO_MIN: float = 2.0
const VELOCIDAD_VUELO_MAX: float = 3000.0
var modo_volar: bool = false
var velocidad_vuelo: float = VELOCIDAD_VUELO_NORMAL
var policia_activa: bool = true     # Se cambia desde el panel admin (F1).
var sospecha: float = 0.0           # 0-100: sube si llevas ilegal, corres con ello o vendes; baja con el tiempo. Sube la prob. de cacheo y registro.
var _t_sospecha: float = 0.0
var atropello_visto: float = 0.0    # Segundos que quedan de "has atropellado a alguien a la vista".
var multa_trafico_enfriamiento: float = 0.0   # Evita multar una y otra vez por lo mismo.
var delito_visto: float = 0.0       # Segundos que quedan de "te vieron vender ilegal en la calle".
var estrellas: int = 0               # 0-5: nivel de búsqueda de la policía (ver datos/policia.gd).
var _t_estrella: float = 0.0        # Segundos fuera de vista hacia la siguiente bajada de estrellas.
var distrito_actual: Dictionary = {}   # El distrito donde estás (lo pone gestor_policia.gd; ver GeneradorMundo.distrito_en).
var banco: int = 0                  # Dinero ingresado en el banco (a salvo de multas y de la muerte).
var enfriamiento_cacheo: float = 0.0  # Segundos hasta que te puedan cachear otra vez.
var huertos: Dictionary = {}          # id_huerto -> true (alquilado o comprado).
var en_propiedad: Dictionary = {}     # id -> true: casas y huertos COMPRADOS (se pueden vender).
var granja: Dictionary = {}           # corrales y árboles: id -> estado (animales, producción, nivel).
var parcelas: Dictionary = {}         # id_huerto -> {semilla, t, total}: cultivo en curso.
var limites_mundo: Rect2 = Rect2(-5000, -5000, 10000, 10000)   # Todo el mapa (lo fija mundo.gd).
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
var plazas_tomadas: Dictionary = {}  # Coches aparcados ("amb_N") que ya robaste: no vuelven a aparecer aunque los vendas.
var aspecto: Dictionary = {}         # Cómo se ve el jugador (ver scripts/jugador/aspecto.gd).
var habilidades: Dictionary = {}     # id_habilidad -> true (ver scripts/datos/habilidades.gd)
var recetario: Dictionary = {}       # Recetas generadas que ya has descubierto: id -> veces preparada.
var efectos_activos: Dictionary = {} # Efectos temporales: id -> {"t": segundos que quedan, "f": fuerza}.

var inventario: Array = []
var estanteria: Array = []
var seleccion: int = 0               # Casilla de la barra que tienes en la mano.

# true mientras hay un menú abierto (tienda, inventario, minijuego...):
# el jugador no se mueve y el ratón se puede usar para hacer clic.
var menu_abierto: bool = false


func _ready() -> void:
	dia_nuevo.connect(_interes_banco)
	randomize()
	_crear_controles()
	reiniciar()


func reiniciar() -> void:
	dinero = GameData.DINERO_INICIAL
	vida = VIDA_MAX
	hora = 20.0
	dia = 1
	reloj = 0.0
	impagos.clear()
	metas_cobradas.clear()
	oficio = ""
	oficios_xp = {}
	en_turno = false
	turno_pago = 0.0
	sin_correr = 0.0
	duracion_dia_min = DURACION_DIA_POR_DEFECTO
	velocidad_tiempo = 1.0
	modo_volar = false
	velocidad_vuelo = VELOCIDAD_VUELO_NORMAL
	ha_ganado = false
	viviendas.clear()
	huertos.clear()
	en_propiedad.clear()
	parcelas.clear()
	granja.clear()
	alerta = 0.0
	estrellas = 0
	banco = 0
	motivo_alerta = ""
	nivel = 1
	xp = 0
	habilidades.clear()
	aspecto = DatosAspecto.POR_DEFECTO.duplicate()
	vehiculos.clear()
	plazas_tomadas.clear()
	personal.clear()
	almacen.clear()
	almacen_ultima_semilla.clear()
	dia_pago = 1
	negocio = {}
	_contador_vehiculos = 0
	recetario.clear()
	efectos_activos.clear()
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
	reloj += delta * velocidad_tiempo
	_t_metas += delta
	if _t_metas >= 2.0:
		_t_metas = 0.0
		revisar_metas()
	# La búsqueda baja sola con el tiempo: más rápido si te escondes dentro de un edificio.
	_t_sospecha += delta
	if _t_sospecha >= 1.0:
		var dt: float = _t_sospecha
		_t_sospecha = 0.0
		var delta_s: float = -0.6   # Baja con el tiempo.
		if lleva_ilegal():
			delta_s += 0.9 * (0.7 if habilidades.has("sigilo") else 1.0)
			if Input.is_action_pressed("correr"):
				delta_s += 0.6
		if delito_visto > 0.0:
			delta_s += 3.0
		delta_s -= 1.5 * mod("calma")   # Efecto "Calma": la sospecha baja más rápido.
		sospecha = clampf(sospecha + delta_s * dt, 0.0, 100.0)
	delito_visto = maxf(0.0, delito_visto - delta)
	sin_correr = maxf(0.0, sin_correr - delta)
	atropello_visto = maxf(0.0, atropello_visto - delta)
	multa_trafico_enfriamiento = maxf(0.0, multa_trafico_enfriamiento - delta)
	enfriamiento_cacheo = maxf(0.0, enfriamiento_cacheo - delta)
	_avanzar_estrellas(delta)
	if alerta > 0.0:
		var bajada: float = 30.0 if interiores > 0 else 6.0
		alerta = maxf(0.0, alerta - delta * bajada / (1.0 + mod("alerta")))   # Paranoia: baja más despacio.
	if not efectos_activos.is_empty():
		_avanzar_efectos(delta)
	hora += delta * 24.0 / (maxf(1.0, duracion_dia_min) * 60.0) * velocidad_tiempo
	if hora >= 24.0:
		hora -= 24.0
		dia += 1
		DatosPropiedades.cobrar_dia()
		dia_nuevo.emit()


# Sube el nivel de búsqueda (nunca pasa de 5). Solo cuenta si la policía está activa.
func subir_estrellas(cantidad: int, motivo: String = "") -> void:
	if not policia_activa or cantidad <= 0:
		return
	var antes: int = estrellas
	estrellas = mini(DatosPolicia.MAX_ESTRELLAS, estrellas + cantidad)
	_t_estrella = 0.0
	if motivo != "":
		motivo_alerta = motivo
	if estrellas > antes:
		avisar("Búsqueda policial: %s" % DatosPolicia.texto_estrellas(estrellas))
		cambio.emit()


# Cada día el banco paga un interés sobre lo ingresado.
func _interes_banco() -> void:
	if banco > 0:
		banco += int(ceil(banco * Economia.BANCO_INTERES_DIARIO))


# Garantiza al menos "minimo" estrellas (sin pasarse si ya tienes más).
func exigir_estrellas(minimo: int, motivo: String = "") -> void:
	if estrellas < minimo:
		subir_estrellas(minimo - estrellas, motivo)
	elif motivo != "":
		motivo_alerta = motivo
	_t_estrella = 0.0


# Mientras te buscan (alerta > 0) no baja. Cuando te pierden de vista pierdes una
# estrella cada cierto tiempo; con la policía desactivada se quitan de golpe.
func _avanzar_estrellas(delta: float) -> void:
	if estrellas <= 0:
		_t_estrella = 0.0
		return
	if not policia_activa:
		estrellas = 0
		return
	if alerta > 0.0:
		_t_estrella = 0.0
		return
	_t_estrella += delta * (3.0 if interiores > 0 else 1.0)
	if _t_estrella >= float(DatosPolicia.SEGUNDOS_PARA_BAJAR[estrellas]):
		_t_estrella = 0.0
		estrellas -= 1
		avisar("Te han perdido la pista." if estrellas == 0 else "Búsqueda policial: %s" % DatosPolicia.texto_estrellas(estrellas))
		cambio.emit()


# Pasa tiempo de golpe (calabozo, taxi): mueve la hora y el día, cobra el día si cambia
# y adelanta el reloj absoluto (cultivos, corrales, macetas).
func avanzar_horas(horas: float) -> void:
	hora += horas
	while hora >= 24.0:
		hora -= 24.0
		dia += 1
		DatosPropiedades.cobrar_dia()
		dia_nuevo.emit()
	reloj += horas * maxf(1.0, duracion_dia_min) * 60.0 / 24.0


# Te detienen: pierdes dinero (multa), lo ilegal, unas horas, y apareces en la comisaría
# (la plaza). Devuelve el texto para el aviso.
func detener() -> String:
	var n: int = maxi(1, estrellas)
	var multa: int = mini(dinero, maxi(int(DatosPolicia.MULTA_DETENCION[n]), int(dinero * DatosPolicia.MULTA_DETENCION_PORCENTAJE * n)))
	dinero -= multa
	var confiscado: int = 0
	for i in inventario.size():
		var casilla = inventario[i]
		if casilla == null:
			continue
		var tipo: String = DatosObjetos.datos(casilla["id"])["tipo"]
		if tipo == "pocion" or tipo == "paquete" or tipo == "hierba" or tipo == "arma_fuego" or tipo == "explosivo":
			confiscado += int(casilla["cantidad"])
			inventario[i] = null
	var horas: float = float(DatosPolicia.HORAS_CARCEL[n])
	avanzar_horas(horas)
	estrellas = 0
	alerta = 0.0
	sospecha = maxf(0.0, sospecha - 40.0)
	vida = maxf(vida, VIDA_MAX * 0.5)
	cambio.emit()
	return "Detenido. Multa de %d $, %d objetos ilegales confiscados y %d horas en el calabozo." % [multa, confiscado, int(horas)]


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
	return Economia.xp_para_subir(nivel)


# Suma experiencia (plantar, cosechar, preparar y vender dan XP) y sube de nivel.
func ganar_xp(cantidad: int) -> void:
	if nivel >= Economia.NIVEL_MAX:
		return
	xp += int(round(float(cantidad) * (1.0 + mod("xp"))))
	while nivel < Economia.NIVEL_MAX and xp >= xp_necesaria():
		xp -= xp_necesaria()
		nivel += 1
		avisar("¡Subes al nivel %d! Hay objetos nuevos en las tiendas." % nivel)
	if nivel >= Economia.NIVEL_MAX:
		xp = 0
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


# Cobra el premio de las metas del móvil que ya cumpliste (una vez cada una).
func revisar_metas() -> void:
	for m in DatosMetas.LISTA:
		if not metas_cobradas.has(m["id"]) and DatosMetas.cumplida(m["id"]):
			metas_cobradas[m["id"]] = true
			cobrar(int(m["premio"]))
			nuevo_aviso("Meta cumplida: %s  +%d $" % [m["texto"], m["premio"]])
			avisar("¡Meta cumplida! +%d $" % int(m["premio"]))


# ¿Tienes el carnet de conducir? (Se aprende con un instructor: habilidad "conduccion".)
func tiene_carnet() -> bool:
	return habilidades.has("conduccion")


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


func cambiar_vida(cantidad: float) -> void:
	if cantidad < 0.0:
		# Los efectos de resistencia (o debilidad) cambian el daño que recibes.
		cantidad *= clampf(1.0 + mod("dano_recibido"), 0.1, 2.0)
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


# Usa lo que llevas en la mano con el clic izquierdo: comida y medicinas curan
# y las pociones se beben (dan efectos temporales; ver scripts/datos/efectos.gd).
func usar_en_mano() -> void:
	var casilla = en_mano()
	if casilla == null:
		return
	var id: String = casilla["id"]
	var datos: Dictionary = DatosObjetos.datos(id)
	var cura: float = float(datos.get("cura", 0))
	var efectos: Array = []
	var secundarios: Array = []
	var quita: Array = datos.get("quita", [])
	if datos["tipo"] == "pocion":
		var info: Dictionary = Mezclas.info(id.trim_prefix("pocion_"))
		if info.is_empty():
			return
		efectos = info["efectos"]
		secundarios = info["secundarios"]
	else:
		efectos = datos.get("efectos", [])
	if cura <= 0.0 and efectos.is_empty() and quita.is_empty():
		return   # No se puede usar (armas, semillas...).
	var cura_util: bool = cura > 0.0 and vida < VIDA_MAX
	var quita_util: bool = false
	for q in quita:
		if efectos_activos.has(q):
			quita_util = true
	if not cura_util and not quita_util and efectos.is_empty():
		avisar("Ya tienes la vida completa.")
		return
	casilla["cantidad"] -= 1
	if casilla["cantidad"] <= 0:
		inventario[seleccion] = null
	var partes: PackedStringArray = []
	if cura > 0.0:
		var antes: float = vida
		cambiar_vida(cura)
		partes.append("+%d de vida" % int(round(vida - antes)))
	for q in quita:
		if efectos_activos.erase(q):
			partes.append("quita %s" % DatosEfectos.nombre(q).to_lower())
	for e in efectos:
		aplicar_efecto(str(e["id"]), float(e["dur"]), float(e.get("f", 1.0)))
		partes.append(DatosEfectos.nombre(str(e["id"])))
	for e in secundarios:
		if randf() < float(e.get("prob", 1.0)):
			aplicar_efecto(str(e["id"]), float(e["dur"]), float(e.get("f", 1.0)))
			partes.append("¡efecto secundario: %s!" % DatosEfectos.nombre(str(e["id"])).to_lower())
	avisar("Usas %s (%s)." % [datos["nombre"], ", ".join(partes)])
	efectos_cambiados.emit()
	cambio.emit()


# ---------------------------- Efectos temporales --------------------------------

# Activa un efecto. Si ya lo tenías, se queda el que dure más y sea más fuerte.
func aplicar_efecto(id: String, duracion: float, fuerza: float = 1.0) -> void:
	if not DatosEfectos.existe(id):
		return
	var actual: Dictionary = efectos_activos.get(id, {})
	efectos_activos[id] = {
		"t": maxf(duracion, float(actual.get("t", 0.0))),
		"total": maxf(duracion, float(actual.get("total", 0.0))),
		"f": maxf(fuerza, float(actual.get("f", 0.0))),
	}
	efectos_cambiados.emit()


func quitar_efecto(id: String) -> void:
	if efectos_activos.erase(id):
		efectos_cambiados.emit()


func quitar_efectos_malos() -> void:
	for id in efectos_activos.keys():
		if not DatosEfectos.es_bueno(id):
			efectos_activos.erase(id)
	efectos_cambiados.emit()


# Suma de un modificador de todos los efectos activos. Por ejemplo
# mod("velocidad") = 0.35 con "Velocidad" activa: multiplica la velocidad por 1.35.
func mod(clave: String) -> float:
	var total: float = 0.0
	if clave == "dano_recibido" and oficio == "bombero" and en_turno:
		total -= float(DatosOficios.REDUCCION_DANO_BOMBERO[rango_oficio()])   # Equipo ignífugo.
	for id in efectos_activos:
		var m: Dictionary = DatosEfectos.LISTA[id].get("mods", {})
		if m.has(clave):
			total += float(m[clave]) * float(efectos_activos[id]["f"])
	return total


# ------------------------------ Oficios y convalecencia ------------------------

# Tras un tratamiento médico no puedes correr durante unos segundos.
func empezar_convalecencia(segundos: float) -> void:
	sin_correr = maxf(sin_correr, segundos)
	avisar("Estás convaleciente: no podrás correr durante %d s." % int(segundos))


func xp_oficio(id: String = "") -> int:
	return int(oficios_xp.get(oficio if id == "" else id, 0))


func rango_oficio() -> int:
	return DatosOficios.indice_rango(oficio, xp_oficio())


func es_policia_activo() -> bool:
	return oficio == "policia" and (en_turno or rango_oficio() >= 1)


# Multiplicador de precio en servicios para quien trabaja en ellos (hospital: médico, taller: mecánico).
func descuento_servicio(servicio: String) -> float:
	if oficio == "medico" and servicio == "hospital":
		return float(DatosOficios.DESCUENTO_HOSPITAL[rango_oficio()])
	if oficio == "mecanico" and servicio == "taller":
		return float(DatosOficios.DESCUENTO_TALLER[rango_oficio()])
	return 0.0


# Suma experiencia de oficio y avisa si asciendes.
func ganar_xp_oficio(cantidad: int) -> void:
	if oficio == "":
		return
	var antes: int = rango_oficio()
	oficios_xp[oficio] = xp_oficio() + cantidad
	var ahora: int = rango_oficio()
	if ahora > antes:
		avisar("¡Ascenso! Ahora eres %s (sueldo x%.1f)." % [DatosOficios.nombre_rango(oficio, xp_oficio()),
				DatosOficios.multiplicador(oficio, xp_oficio())])
	cambio.emit()


# Ficha en un oficio (si hacía otro, lo deja; conserva su rango en cada uno). Devuelve el aviso a mostrar.
func fichar(id: String) -> String:
	if not DatosOficios.existe(id):
		return ""
	if id == "policia" and (estrellas > 0 or sospecha >= 40.0):
		return "La policía no te acepta: te buscan o das mala espina."
	if oficio == id:
		return ""
	if en_turno:
		terminar_turno()
	oficio = id
	cambio.emit()
	return "Te contratan como %s (%s)." % [DatosOficios.nombre(id), DatosOficios.nombre_rango(id, xp_oficio())]


func empezar_turno() -> void:
	if oficio == "" or en_turno:
		return
	en_turno = true
	turno_pago = 0.0
	avisar("Entras de servicio como %s. Saldrán avisos por la calle." % DatosOficios.nombre(oficio))
	cambio.emit()


func terminar_turno() -> void:
	if not en_turno:
		return
	en_turno = false
	var cobro: int = int(round(turno_pago))
	turno_pago = 0.0
	if cobro > 0:
		cobrar(cobro)
	avisar("Terminas el turno. Cobras %d $ de sueldo." % cobro)
	cambio.emit()


# Fuerza de los efectos en pantalla: "ondas" y "vineta" (0..1), "tinte" (Color).
func visual(clave: String) -> float:
	var total: float = 0.0
	for id in efectos_activos:
		var v: Dictionary = DatosEfectos.LISTA[id].get("visual", {})
		if v.has(clave) and v[clave] is float:
			total = maxf(total, float(v[clave]) * minf(1.0, float(efectos_activos[id]["f"])))
	return total


func tinte() -> Color:
	var c: Color = Color(0, 0, 0, 0)
	for id in efectos_activos:
		var v: Dictionary = DatosEfectos.LISTA[id].get("visual", {})
		if v.has("tinte"):
			var t: Color = v["tinte"]
			c.r += t.r * t.a
			c.g += t.g * t.a
			c.b += t.b * t.a
			c.a += t.a
	if c.a > 0.0:
		c.r /= c.a
		c.g /= c.a
		c.b /= c.a
		c.a = minf(c.a, 0.2)
	return c


func _avanzar_efectos(delta: float) -> void:
	var caducados: Array = []
	var regen: float = 0.0
	for id in efectos_activos:
		var e: Dictionary = efectos_activos[id]
		e["t"] = float(e["t"]) - delta
		regen += float(DatosEfectos.LISTA[id].get("regen", 0.0)) * float(e["f"])
		if float(e["t"]) <= 0.0:
			caducados.append(id)
	# La vida cambia cada fotograma, pero se avisa a la interfaz solo unas 4 veces por segundo.
	_t_aviso_regen += delta
	var avisar_ui: bool = _t_aviso_regen >= 0.25
	if avisar_ui:
		_t_aviso_regen = 0.0
	if regen > 0.0 and vida < VIDA_MAX:
		vida = minf(VIDA_MAX, vida + regen * delta)
		if avisar_ui:
			cambio.emit()
	elif regen < 0.0 and vida > 1.0:
		vida = maxf(1.0, vida + regen * delta)   # El veneno baja la vida pero nunca mata.
		if avisar_ui:
			cambio.emit()
	for id in caducados:
		efectos_activos.erase(id)
		avisar("Se acaba el efecto: %s." % DatosEfectos.nombre(id))
	if not caducados.is_empty():
		efectos_cambiados.emit()


# Apunta una receta nueva en el recetario. Devuelve true si es la primera vez.
func descubrir_receta(id_pocion: String) -> bool:
	Logros.desbloquear("primera_receta")   # Vale también para las pociones clásicas.
	if GameData.POCIONES.has(id_pocion):
		return false
	var primera: bool = not recetario.has(id_pocion)
	recetario[id_pocion] = int(recetario.get(id_pocion, 0)) + 1
	return primera


# Vende una casilla entera a una tienda por la mitad de su precio.
func vender(lista: Array, i: int) -> String:
	var casilla = lista[i]
	if casilla == null:
		return ""
	var datos: Dictionary = DatosObjetos.datos(casilla["id"])
	if datos["precio"] <= 0:
		return "Aquí no compran %s." % datos["nombre"]
	var factor: float = Economia.VENTA_COSECHA if datos["tipo"] == "cosecha" else Economia.VENTA_TIENDA
	var pago: int = maxi(1, int(datos["precio"] * factor)) * casilla["cantidad"]
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
	var multa: int = mini(dinero, 30 * montones + 5 * unidades + int(dinero * Economia.MULTA_REGISTRO_PORCENTAJE))
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
	_accion("logros", [KEY_L])   # Lista de logros.
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
