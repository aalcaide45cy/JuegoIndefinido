# servicio_mundo.gd
# -----------------------------------------------------------------------------
# Un servicio de las ciudades y pueblos del mundo grande (lo crea gestor_trozos.gd a
# partir de generador_mundo.gd) y también la gasolinera de la ciudad original. Se usa
# con E; los precios están en datos/economia.gd.
#   gasolinera  E rellena el vehículo más cercano (a 15 m); Mayús+E compra un bidón.
#   taller      E repara el vehículo más cercano.
#   hospital    E te cura del todo y quita los efectos malos.
#   taberna     E tomas algo: algo de vida y baja la sospecha.
#   comisaria / bomberos   E ficha (policía / bombero) y entra o sale de servicio. En el
#               hospital y el taller, Mayús+E ficha (médico / mecánico) y hace turno.
#   banco       E ingresa casi todo tu dinero (a salvo de multas y de la muerte, con
#               interés diario); Mayús+E lo retira.
# Si "con_visual" es true dibuja él mismo el edificio (para la ciudad original).
# SIN PROBAR a mano en Godot.
# -----------------------------------------------------------------------------
class_name ServicioMundo
extends Interactuable

const Economia = preload("res://scripts/datos/economia.gd")
const Casino = preload("res://scripts/datos/casino.gd")
const Locales = preload("res://scripts/datos/locales.gd")

const NOMBRES: Dictionary = {"banco": "Banco", "taberna": "Taberna", "hospital": "Hospital",
		"taller": "Taller", "gasolinera": "Gasolinera", "comisaria": "Comisaría", "bomberos": "Bomberos",
		"discoteca": "Discoteca", "tragaperras": "Tragaperras", "casino": "Casino", "club": "Club de Copas", "timba": "Timba",
		"prestamista": "Préstamos", "mercado_negro": "Mercado negro",
		"peluqueria": "Peluquería", "barberia": "Barbería",
		"restaurante": "Restaurante", "bar": "Bar", "cafeteria": "Cafetería", "panaderia": "Panadería"}

var servicio: String = "gasolinera"
var con_visual: bool = false
var _neon: MeshInstance3D = null
var _neon2: Node3D = null
var _luces: Array = []
var _t_noche: float = 0.0
var _local: LocalMundo = null   # Interior visitable (negocios de datos/locales.gd).
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
static var _tiradas_seguidas: int = 0


func _ready() -> void:
	distancia = 3.0
	var rotulo: Label3D = Construir.texto(self, Vector3(0, 2.6 if servicio != "gasolinera" else 4.2, 0),
			str(NOMBRES.get(servicio, servicio)).to_upper(), 48, Color(1.0, 0.95, 0.7))
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.no_depth_test = false
	# Negocios con interior: decoración, mostrador y persona que atiende (ver local_mundo.gd).
	if Locales.existe(servicio):
		_local = LocalMundo.crear(self, servicio)
		rotulo.text = _local.nombre.to_upper()
	if con_visual and servicio == "gasolinera":
		_dibujar_gasolinera()
	_rng.randomize()
	if Casino.HORARIOS.has(servicio):
		_montar_local_nocturno()
		set_process(true)
	else:
		set_process(false)


# Neón sobre la puerta y focos de colores. Solo brillan mientras el local está abierto.
func _montar_local_nocturno() -> void:
	var disco: bool = servicio == "discoteca"
	var color: Color = Color(0.95, 0.15, 0.75) if disco else Color(1.0, 0.8, 0.15)
	_neon = Construir.caja(self, Vector3(0, 4.3, 0.0), Vector3(7.0, 0.5, 0.12), color, false, 3.0) as MeshInstance3D
	_neon2 = Construir.caja(self, Vector3(0, 3.6, 0.0), Vector3(5.0, 0.12, 0.1), Color(0.2, 0.9, 1.0) if disco else Color(0.95, 0.2, 0.2), false, 2.5)
	var colores: Array = [Color(1.0, 0.1, 0.6), Color(0.2, 0.6, 1.0), Color(0.6, 0.2, 1.0)] if disco \
			else [Color(1.0, 0.75, 0.2), Color(1.0, 0.3, 0.2)]
	var i: int = 0
	for c in colores:
		var foco: OmniLight3D = Construir.luz(self, Vector3(-2.5 + i * 2.5, 3.0, 1.5), c, 0.0, 12.0)
		_luces.append(foco)
		i += 1


func _process(delta: float) -> void:
	_t_noche += delta
	var abierto: bool = Casino.abierto(servicio, Juego.hora)
	if _neon != null:
		_neon.visible = abierto
		_neon2.visible = abierto
	for i in _luces.size():
		var foco: OmniLight3D = _luces[i]
		var pulso: float = 0.5 + 0.5 * sin(_t_noche * (4.0 if servicio == "discoteca" else 2.0) + i * 2.1)
		foco.light_energy = (1.5 + 3.0 * pulso) if abierto else 0.0


func _dibujar_gasolinera() -> void:
	var rojo: Color = Color(0.9, 0.2, 0.1)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Construir.caja(self, Vector3(sx * 6.5, 2.3, sz * 3.5), Vector3(0.5, 4.6, 0.5), Color(0.8, 0.8, 0.78))
	Construir.caja(self, Vector3(0, 4.8, 0), Vector3(14.5, 0.5, 8.5), rojo, false)
	Construir.caja(self, Vector3(0, 0.1, 0), Vector3(10.0, 0.2, 1.4), Color(0.35, 0.35, 0.37), false)
	for sx in [-2.5, 2.5]:
		Construir.caja(self, Vector3(sx, 0.95, 0), Vector3(0.8, 1.7, 0.6), Color(0.85, 0.15, 0.12))
		Construir.caja(self, Vector3(sx, 1.3, 0.32), Vector3(0.5, 0.35, 0.05), Color(0.15, 0.15, 0.18), false)
	# La tienda detrás de los surtidores (al otro lado de la carretera).
	Construir.caja(self, Vector3(0, 1.8, 8.0), Vector3(8.0, 3.6, 6.0), Color(0.82, 0.82, 0.78))
	Construir.caja(self, Vector3(0, 3.4, 4.95), Vector3(7.0, 0.9, 0.12), rojo, false)
	Construir.luz_noche(self, Vector3(0, 4.2, 0), Color(1.0, 0.95, 0.8), 2.0, 14.0)


# El vehículo (no remolque) más cercano a "pos" dentro de "radio" metros, o null.
static func vehiculo_cercano(arbol: SceneTree, pos: Vector3, radio: float):
	var mejor = null
	var d_mejor: float = radio
	for v in arbol.get_nodes_in_group("vehiculos"):
		if v.has_method("clase") and v.clase() == "remolque":
			continue
		var d: float = (v as Node3D).global_position.distance_to(pos)
		if d < d_mejor:
			d_mejor = d
			mejor = v
	return mejor


func texto_accion() -> String:
	var v = vehiculo_cercano(get_tree(), global_position, 15.0)
	match servicio:
		"gasolinera":
			if v == null:
				return "Gasolinera (acerca un vehículo a menos de 15 m)  ·  Mayús+E: bidón %d $" % Economia.BIDON_EN_SURTIDOR
			var falta: float = 100.0 - float(v.get("gasolina"))
			return "Repostar %s: %d $  ·  Mayús+E: bidón %d $" % [Vehiculo.TIPOS[v.tipo]["nombre"],
					_precio_gasolina(v), Economia.BIDON_EN_SURTIDOR] if falta > 0.5 else "El depósito está lleno"
		"taller":
			if v == null:
				return "Taller (acerca un vehículo a menos de 15 m)  ·  Mayús+E: " + _texto_oficio()
			return "Reparar %s: %d $" % [Vehiculo.TIPOS[v.tipo]["nombre"], _precio_reparacion(v)] \
					if float(v.get("salud")) < 99.5 else "No necesita reparación"
		"hospital":
			return "Hospital: curarte (%d $)  ·  Mayús+E: %s" % [_precio_cura(), _texto_oficio()]
		"comisaria", "bomberos":
			return _texto_oficio()
		"peluqueria", "barberia":
			return "%s: cambiar de peinado  ·  Mayús+E: %s" % [NOMBRES[servicio], _texto_oficio()]
		"restaurante", "bar", "cafeteria", "panaderia":
			return _texto_local()
		"taberna":
			return "Tomar algo (%d $): algo de vida y menos sospecha  ·  o entra y pide en el mostrador" % Economia.TABERNA_PRECIO
		"banco":
			return "Banco (%d $ ingresados): E ingresar  ·  Mayús+E retirar todo" % Juego.banco
		"discoteca":
			if not Casino.abierto("discoteca", Juego.hora):
				return "Discoteca cerrada (abre %s)" % Casino.texto_horario("discoteca")
			return "Entrar a la discoteca (%d $ y copas)  ·  Mayús+E: copa (%d $)" % [Casino.ENTRADA_DISCOTECA, Casino.COPA_DISCOTECA]
		"club":
			if not Casino.abierto("club", Juego.hora):
				return "Club de Copas cerrado (abre %s)" % Casino.texto_horario("club")
			return "Club de Copas: tomar una copa (%d $) y escuchar rumores" % Casino.COPA_CLUB
		"timba":
			if not Casino.abierto("timba", Juego.hora):
				return "Timba clandestina cerrada (abre %s)" % Casino.texto_horario("timba")
			return "Timba: E apuesta %d $  ·  Mayús+E apuesta %d $  (hay quien hace trampas)" % [Casino.TIMBA_APUESTAS[0], Casino.TIMBA_APUESTAS[1]]
		"prestamista":
			if Juego.deuda > 0:
				return "Prestamista: debes %d $ (+30 %% al día)  ·  E: pagar todo" % Juego.deuda
			return "Prestamista: pedir %d $ (30 %% de interés al día; a los 3 días sin pagar, mandan un cobrador)" % Casino.PRESTAMO
		"mercado_negro":
			if not Casino.abierto("mercado_negro", Juego.hora):
				return "Mercado negro cerrado (abre %s)" % Casino.texto_horario("mercado_negro")
			var of: Array = Casino.oferta_mercado(Juego.dia)
			return "Mercado negro: %s por %d $ (solo esta noche)" % [Juego.DatosObjetos.datos(of[0])["nombre"], _precio_mercado(of)]
		"casino":
			if not Casino.abierto("casino", Juego.hora):
				return "Casino cerrado (abre %s)" % Casino.texto_horario("casino")
			if VentanaCasino.dia_vetado == Juego.dia:
				return "Seguridad no te deja entrar hoy"
			return "Entrar al casino: ruleta y blackjack (dinero del juego)"
		"tragaperras":
			if not Casino.abierto("tragaperras", Juego.hora):
				return "Salón cerrado (abre %s)" % Casino.texto_horario("tragaperras")
			return "Tragaperras: E apuesta %d $  ·  Mayús+E apuesta %d $  (la casa gana a la larga)" % [Casino.APUESTAS[0], Casino.APUESTAS[1]]
	return ""


func usar(_jugador: Node) -> void:
	var mayus: bool = Input.is_action_pressed("correr")
	match servicio:
		"gasolinera": _usar_gasolinera(mayus)
		"taller":
			if mayus:
				_usar_oficio()
			else:
				_usar_taller()
		"hospital":
			if mayus:
				_usar_oficio()
			else:
				_usar_hospital()
		"comisaria", "bomberos": _usar_oficio()
		"peluqueria", "barberia":
			if mayus:
				_usar_oficio()
			elif _jugador != null and "hud" in _jugador and _jugador.hud != null:
				var v: VentanaPeluqueria = VentanaPeluqueria.new()
				v.local = servicio
				_jugador.hud.abrir_ventana(v)
		"restaurante", "bar", "cafeteria", "panaderia":
			Juego.avisar("Pasa dentro y pide en el mostrador.")
		"taberna": _usar_taberna()
		"banco": _usar_banco(mayus)
		"discoteca": _usar_discoteca(mayus)
		"tragaperras": _usar_tragaperras(mayus)
		"casino": _usar_casino(_jugador)
		"club": _usar_club()
		"timba": _usar_timba(mayus)
		"prestamista": _usar_prestamista()
		"mercado_negro": _usar_mercado()


func _precio_gasolina(v) -> int:
	return maxi(1, int(ceil((100.0 - float(v.get("gasolina"))) * Economia.GASOLINA_POR_PORCENTAJE * float(Vehiculo.TIPOS[v.tipo].get("gasto", 1.0)))))


func _precio_reparacion(v) -> int:
	var base: int = maxi(1, int(ceil((100.0 - float(v.get("salud"))) * Economia.REPARACION_POR_PORCENTAJE)))
	return maxi(1, int(round(base * (1.0 - Juego.descuento_servicio("taller")))))


func _precio_cura() -> int:
	var base: int = maxi(Economia.CURA_MINIMA, int(ceil((Juego.vida_max() - Juego.vida) * Economia.CURA_POR_PUNTO)))
	return maxi(1, int(round(base * (1.0 - Juego.descuento_servicio("hospital")))))


func _texto_local() -> String:
	var nom: String = _local.nombre if _local != null else str(NOMBRES.get(servicio, servicio))
	if not Locales.abierto(servicio, Juego.hora):
		return "%s: cerrado (abre %s)" % [nom, Locales.texto_horario(servicio)]
	return "%s: entra y pide en el mostrador" % nom


# Lo que hace Mayús+E (o E) aquí con el oficio de este lugar.
func _texto_oficio() -> String:
	var id: String = Juego.DatosOficios.oficio_de_lugar(servicio)
	if id == "":
		return ""
	var nombre: String = Juego.DatosOficios.nombre(id)
	if Juego.oficio != id:
		return "hacerte %s" % nombre.to_lower()
	return "terminar turno (cobras %d $)" % int(round(Juego.turno_pago)) if Juego.en_turno else "entrar de servicio (%s)" % nombre.to_lower()


func _usar_oficio() -> void:
	var id: String = Juego.DatosOficios.oficio_de_lugar(servicio)
	if id == "":
		return
	if Juego.oficio != id:
		var msg: String = Juego.fichar(id)
		if msg != "":
			Juego.avisar(msg)
		return
	if Juego.en_turno:
		Juego.terminar_turno()
	else:
		Juego.empezar_turno()


func _usar_gasolinera(comprar_bidon: bool) -> void:
	if comprar_bidon:
		if not Juego.cabe("bidon_gasolina", 1):
			Juego.avisar("No te cabe el bidón.")
		elif not Juego.gastar(Economia.BIDON_EN_SURTIDOR):
			Juego.avisar("Un bidón cuesta %d $." % Economia.BIDON_EN_SURTIDOR)
		else:
			Juego.anadir("bidon_gasolina", 1)
			Juego.avisar("Compras un bidón de gasolina (%d $)." % Economia.BIDON_EN_SURTIDOR)
		return
	var v = vehiculo_cercano(get_tree(), global_position, 15.0)
	if v == null:
		Juego.avisar("No hay ningún vehículo cerca del surtidor.")
		return
	if float(v.get("gasolina")) >= 99.5:
		Juego.avisar("El depósito ya está lleno.")
		return
	var precio: int = _precio_gasolina(v)
	if not Juego.gastar(precio):
		Juego.avisar("Llenar el depósito cuesta %d $." % precio)
		return
	v.set("gasolina", 100.0)
	v.guardar_estado()
	Juego.avisar("Depósito lleno por %d $." % precio)


func _usar_taller() -> void:
	var v = vehiculo_cercano(get_tree(), global_position, 15.0)
	if v == null:
		Juego.avisar("No hay ningún vehículo cerca del taller.")
		return
	if float(v.get("salud")) >= 99.5:
		Juego.avisar("No necesita reparación.")
		return
	var precio: int = _precio_reparacion(v)
	if not Juego.gastar(precio):
		Juego.avisar("La reparación cuesta %d $." % precio)
		return
	v.set("salud", 100.0)
	v.guardar_estado()
	Juego.avisar("Vehículo reparado por %d $." % precio)


func _usar_hospital() -> void:
	if Juego.vida >= Juego.vida_max() - 0.5:
		Juego.avisar("Estás sano. No hace falta.")
		return
	var precio: int = _precio_cura()
	if not Juego.gastar(precio):
		Juego.avisar("El tratamiento cuesta %d $." % precio)
		return
	Juego.vida = Juego.vida_max()
	Juego.quitar_efectos_malos()
	Juego.cambio.emit()
	Juego.avisar("Te curan del todo por %d $." % precio)
	Juego.empezar_convalecencia(Juego.DatosOficios.CONVALECENCIA_HOSPITAL * (0.5 if Juego.oficio == "medico" else 1.0))


func _usar_taberna() -> void:
	if not Juego.gastar(Economia.TABERNA_PRECIO):
		Juego.avisar("Una copa cuesta %d $." % Economia.TABERNA_PRECIO)
		return
	Juego.cambiar_vida(10.0)
	Juego.beber(35.0)
	Juego.comer(10.0)
	Juego.sospecha = maxf(0.0, Juego.sospecha - 15.0)
	Juego.avisar("Te tomas algo en la barra. Te relajas.")


func _usar_discoteca(solo_copa: bool) -> void:
	if not Casino.abierto("discoteca", Juego.hora):
		Juego.avisar("La discoteca está cerrada. Abre de %s." % Casino.texto_horario("discoteca"))
		return
	if solo_copa:
		if not Juego.gastar(Casino.COPA_DISCOTECA):
			Juego.avisar("Una copa cuesta %d $." % Casino.COPA_DISCOTECA)
			return
		Juego.beber(25.0)
		Juego.cambiar_vida(4.0)
		Juego.avisar("Te tomas una copa en la barra. La música retumba.")
		return
	if not Juego.gastar(Casino.ENTRADA_DISCOTECA):
		Juego.avisar("La entrada cuesta %d $." % Casino.ENTRADA_DISCOTECA)
		return
	Juego.beber(40.0)
	Juego.sospecha = maxf(0.0, Juego.sospecha - 10.0)
	# Un encuentro al azar: la noche siempre trae algo.
	var r: float = _rng.randf()
	if r < 0.3 and Juego.dinero >= 30:
		Juego.gastar(25)
		Juego.avisar("Bailas toda la noche... y alguien te aligera la cartera (-25 $).")
	elif r < 0.6:
		Juego.reputacion = mini(100, Juego.reputacion + 3)
		Juego.avisar("Conoces a gente interesante en la pista. Tu fama sube un poco.")
	else:
		Juego.avisar("Una buena noche de música y luces. Te sienta bien.")


func _precio_mercado(oferta: Array) -> int:
	return int(round(float(Juego.DatosObjetos.datos(oferta[0])["precio"]) * float(oferta[1])))


func _usar_club() -> void:
	if not Casino.abierto("club", Juego.hora):
		Juego.avisar("El Club de Copas está cerrado. Abre de %s." % Casino.texto_horario("club"))
		return
	if not Juego.gastar(Casino.COPA_CLUB):
		Juego.avisar("Una copa cuesta %d $." % Casino.COPA_CLUB)
		return
	Juego.beber(30.0)
	Juego.cambiar_vida(5.0)
	Juego.cambiar_rep("hampa", 1)
	Juego.avisar(Casino.RUMORES[_rng.randi() % Casino.RUMORES.size()])


func _usar_timba(grande: bool) -> void:
	if not Casino.abierto("timba", Juego.hora):
		Juego.avisar("La timba está cerrada. Abre de %s." % Casino.texto_horario("timba"))
		return
	var apuesta: int = int(Casino.TIMBA_APUESTAS[1] if grande else Casino.TIMBA_APUESTAS[0])
	if not Juego.gastar(apuesta):
		Juego.avisar("No tienes %d $ para sentarte a esta mesa." % apuesta)
		return
	match Casino.timba(_rng, Juego.atributo("ojo")):
		"gana":
			Juego.cobrar(apuesta * 2)
			Juego.avisar("Ganas la mano: +%d $." % apuesta)
		"trampa":
			Juego.cobrar(apuesta)
			Juego.cambiar_rep("hampa", 2)
			Juego.avisar("Notas las cartas marcadas. Lo dices en voz baja y recuperas tu apuesta. Te miran con respeto.")
		_:
			Juego.avisar("Pierdes la mano (-%d $)." % apuesta)


func _usar_prestamista() -> void:
	if Juego.deuda > 0:
		if not Juego.gastar(Juego.deuda):
			Juego.avisar("Debes %d $ y no te llega. El interés sigue corriendo." % Juego.deuda)
			return
		Juego.avisar("Pagas tu deuda de %d $. El prestamista sonríe." % Juego.deuda)
		Juego.deuda = 0
		Juego.dias_deuda = 0
		Juego.cambio.emit()
		return
	Juego.cobrar(Casino.PRESTAMO)
	Juego.deuda = Casino.PRESTAMO
	Juego.dias_deuda = 0
	Juego.avisar("Te dan %d $ sin preguntas. Mañana deberás %d $." % [Casino.PRESTAMO, Casino.deuda_tras_dia(Casino.PRESTAMO)])


func _usar_mercado() -> void:
	if not Casino.abierto("mercado_negro", Juego.hora):
		Juego.avisar("El mercado negro está cerrado. Abre de %s." % Casino.texto_horario("mercado_negro"))
		return
	var of: Array = Casino.oferta_mercado(Juego.dia)
	var precio: int = _precio_mercado(of)
	if not Juego.gastar(precio):
		Juego.avisar("Cuesta %d $." % precio)
		return
	if Juego.anadir(of[0], 1) > 0:
		Juego.cobrar(precio)
		Juego.avisar("No te cabe en la mochila.")
		return
	Juego.cambiar_rep("hampa", 1)
	Juego.sospecha = minf(100.0, Juego.sospecha + 3.0)
	Juego.avisar("Compras %s por %d $ y te vas sin mirar atrás." % [Juego.DatosObjetos.datos(of[0])["nombre"], precio])
	if _rng.randf() < 0.1:
		Juego.exigir_estrellas(1, "Redada en el mercado negro")


func _usar_casino(jugador: Node) -> void:
	if not Casino.abierto("casino", Juego.hora):
		Juego.avisar("El casino está cerrado. Abre de %s." % Casino.texto_horario("casino"))
		return
	if VentanaCasino.dia_vetado == Juego.dia:
		Juego.avisar("Seguridad te recuerda que hoy ya has ganado bastante.")
		return
	if jugador != null and "hud" in jugador and jugador.hud != null:
		VentanaCasino.neto_noche = 0
		jugador.hud.abrir_casino()


func _usar_tragaperras(grande: bool) -> void:
	if not Casino.abierto("tragaperras", Juego.hora):
		Juego.avisar("El salón está cerrado. Abre de %s." % Casino.texto_horario("tragaperras"))
		return
	var apuesta: int = int(Casino.APUESTAS[1] if grande else Casino.APUESTAS[0])
	if not Juego.gastar(apuesta):
		Juego.avisar("No tienes %d $ para apostar." % apuesta)
		return
	_tiradas_seguidas += 1
	var t: Dictionary = Casino.tirada(_rng.randf(), _rng)
	var mult: float = float(t["multiplicador"])
	var texto: String = "[ %s | %s | %s ]" % [t["rodillos"][0], t["rodillos"][1], t["rodillos"][2]]
	var premio: int = int(round(apuesta * mult))
	if premio > 0:
		Juego.cobrar(premio)
		Juego.avisar("%s  ¡Premio de %d $!" % [texto, premio])
	else:
		Juego.avisar("%s  Nada esta vez (-%d $)." % [texto, apuesta])
	if _tiradas_seguidas % 20 == 0:
		Juego.avisar("Llevas %d tiradas seguidas. La casa siempre gana a la larga: ¿no será hora de parar?" % _tiradas_seguidas)


func _usar_banco(retirar: bool) -> void:
	if retirar:
		if Juego.banco <= 0:
			Juego.avisar("No tienes nada ingresado.")
			return
		var comision: int = maxi(1, int(Juego.banco * Economia.BANCO_COMISION))
		var cantidad: int = maxi(0, Juego.banco - comision)
		Juego.banco = 0
		Juego.cobrar(cantidad)
		Juego.avisar("Retiras %d $ (comisión %d $)." % [cantidad, comision])
		return
	var libre: int = Juego.dinero - 20   # Te quedas con 20 $ en el bolsillo.
	if libre < 20:
		Juego.avisar("No llevas dinero suficiente para ingresar.")
		return
	var com: int = maxi(1, int(libre * Economia.BANCO_COMISION))
	Juego.dinero -= libre
	Juego.banco += libre - com
	Juego.cambio.emit()
	Juego.avisar("Ingresas %d $ (comisión %d $). Ahora tienes %d $ en el banco." % [libre, com, Juego.banco])
