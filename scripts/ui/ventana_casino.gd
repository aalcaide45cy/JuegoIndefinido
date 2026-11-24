# ventana_casino.gd
# -----------------------------------------------------------------------------
# El casino: ruleta europea y blackjack con dinero del juego (nunca real).
# La lógica y los pagos están en datos/casino.gd; aquí solo se dibuja.
# Si ganas demasiado en una noche, seguridad te acompaña a la puerta.
# -----------------------------------------------------------------------------
class_name VentanaCasino
extends Ventana

const Casino = preload("res://scripts/datos/casino.gd")

static var neto_noche: int = 0
static var dia_vetado: int = -1

var _estado: Label
var _resultado: Label
var _ficha: int = 10
var _fichas: HBoxContainer
var _valor_pleno: SpinBox
var _mano_j: Array = []
var _mano_c: Array = []
var _apuesta_bj: int = 0
var _bj_activo: bool = false
var _texto_mano: Label
var _btn_pedir: Button
var _btn_plantar: Button
var _btn_repartir: Button
var _botones_ficha: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func construir() -> void:
	_rng.randomize()
	var caja: VBoxContainer = marco("Casino", "Solo dinero del juego. La casa gana a la larga: juega con cabeza.", Vector2(840, 600))
	_estado = UI.etiqueta("", "Dinero")
	caja.add_child(_estado)
	_fichas = HBoxContainer.new()
	_fichas.add_theme_constant_override("separation", 8)
	caja.add_child(_fichas)
	for f in Casino.FICHAS:
		var b: Button = UI.boton("Ficha %d $" % f, _elegir_ficha.bind(int(f)), "Chip")
		b.toggle_mode = true
		_botones_ficha[int(f)] = b
		_fichas.add_child(b)
	var pestanas: UI.Pestanas = UI.Pestanas.new()
	caja.add_child(pestanas)
	# --- Ruleta ---
	var ruleta: VBoxContainer = VBoxContainer.new()
	ruleta.add_theme_constant_override("separation", 10)
	pestanas.anadir("Ruleta", ruleta)
	ruleta.add_child(UI.nota("Un solo cero. Elige una apuesta: se juega la ficha elegida arriba."))
	var fila1: HBoxContainer = HBoxContainer.new()
	fila1.add_theme_constant_override("separation", 6)
	ruleta.add_child(fila1)
	for par in [["Rojo", "rojo"], ["Negro", "negro"], ["Par", "par"], ["Impar", "impar"], ["1-18", "falta"], ["19-36", "pasa"]]:
		fila1.add_child(UI.boton(par[0], _girar.bind(par[1], 0)))
	var fila2: HBoxContainer = HBoxContainer.new()
	fila2.add_theme_constant_override("separation", 6)
	ruleta.add_child(fila2)
	for par in [["1ª docena", "docena1"], ["2ª docena", "docena2"], ["3ª docena", "docena3"]]:
		fila2.add_child(UI.boton(par[0], _girar.bind(par[1], 0)))
	_valor_pleno = SpinBox.new()
	_valor_pleno.min_value = 0
	_valor_pleno.max_value = 36
	fila2.add_child(_valor_pleno)
	fila2.add_child(UI.boton("Pleno (x35)", func() -> void: _girar("pleno", int(_valor_pleno.value))))
	# --- Blackjack ---
	var mesa: VBoxContainer = VBoxContainer.new()
	mesa.add_theme_constant_override("separation", 10)
	pestanas.anadir("Blackjack", mesa)
	mesa.add_child(UI.nota("3:2 con blackjack natural; el crupier se planta en 17."))
	_texto_mano = UI.etiqueta("Pulsa «Repartir» para apostar la ficha elegida.", "", Tema.TEXTO, 18)
	mesa.add_child(_texto_mano)
	var fila3: HBoxContainer = HBoxContainer.new()
	fila3.add_theme_constant_override("separation", 8)
	mesa.add_child(fila3)
	_btn_repartir = UI.boton("Repartir", _repartir, "BotonPrimario")
	_btn_pedir = UI.boton("Pedir carta", _pedir)
	_btn_plantar = UI.boton("Plantarse", _plantarse)
	fila3.add_child(_btn_repartir)
	fila3.add_child(_btn_pedir)
	fila3.add_child(_btn_plantar)
	_resultado = UI.etiqueta("", "", Tema.BRUMA, 20)
	caja.add_child(_resultado)
	Juego.cambio.connect(_refrescar)
	_refrescar()


func _refrescar() -> void:
	if not is_instance_valid(_estado):
		return
	for f in _botones_ficha:
		(_botones_ficha[f] as Button).set_pressed_no_signal(int(f) == _ficha)
	var noche: String = "Esta noche: %s%d $" % ["+" if neto_noche >= 0 else "", neto_noche]
	_estado.text = "%s   ·   Ficha %d $   ·   %s" % [UI.dinero(Juego.dinero), _ficha, noche]
	_btn_pedir.disabled = not _bj_activo
	_btn_plantar.disabled = not _bj_activo
	_btn_repartir.disabled = _bj_activo


func _elegir_ficha(f: int) -> void:
	_ficha = f
	_refrescar()


# Control de ganancia: si sales muy ganador, seguridad te lleva a la puerta.
func _revisar_seguridad() -> void:
	if neto_noche >= Casino.LIMITE_GANANCIA_NOCHE:
		dia_vetado = Juego.dia
		Juego.avisar("Seguridad te acompaña amablemente a la puerta. Hoy no vuelves a entrar.")
		cerrar()


func _registrar(pago: int, apuesta: int) -> void:
	if pago > 0:
		Juego.cobrar(pago)
	neto_noche += pago - apuesta
	_refrescar()
	_revisar_seguridad()


func _girar(tipo: String, valor: int) -> void:
	if _bj_activo:
		_resultado.text = "Termina primero la mano de blackjack."
		return
	if not Juego.gastar(_ficha):
		_resultado.text = "No tienes %d $." % _ficha
		return
	var r: Dictionary = Casino.ruleta(tipo, valor, _ficha, _rng)
	var n: int = int(r["numero"])
	var color: String = "verde" if n == 0 else ("rojo" if Casino.es_rojo(n) else "negro")
	var pago: int = int(r["pago"])
	_resultado.text = "Sale el %d (%s). %s" % [n, color, ("¡Ganas %d $!" % (pago - _ficha)) if pago > 0 else "Pierdes %d $." % _ficha]
	_registrar(pago, _ficha)


func _repartir() -> void:
	if not Juego.gastar(_ficha):
		_resultado.text = "No tienes %d $." % _ficha
		return
	_apuesta_bj = _ficha
	_mano_j = [1 + _rng.randi() % 13, 1 + _rng.randi() % 13]
	_mano_c = [1 + _rng.randi() % 13]
	_bj_activo = true
	_resultado.text = ""
	_mostrar_mano(false)
	if Casino.es_blackjack(_mano_j):
		_plantarse()
	_refrescar()


func _pedir() -> void:
	_mano_j.append(1 + _rng.randi() % 13)
	_mostrar_mano(false)
	if Casino.total_mano(_mano_j) >= 21:
		_plantarse()


func _plantarse() -> void:
	if not _bj_activo:
		return
	_bj_activo = false
	if Casino.total_mano(_mano_j) <= 21:
		_mano_c = Casino.jugar_crupier(_mano_c, _rng)
	else:
		_mano_c.append(1 + _rng.randi() % 13)
	var pago: int = Casino.pago_blackjack(_mano_j, _mano_c, _apuesta_bj)
	_mostrar_mano(true)
	if pago > _apuesta_bj:
		_resultado.text = "¡Ganas %d $!" % (pago - _apuesta_bj)
	elif pago == _apuesta_bj:
		_resultado.text = "Empate: te devuelven la apuesta."
	else:
		_resultado.text = "Pierdes %d $." % _apuesta_bj
	_registrar(pago, _apuesta_bj)


func _mostrar_mano(final: bool) -> void:
	var tuyo: Array = []
	for c in _mano_j:
		tuyo.append(Casino.nombre_carta(int(c)))
	var suyo: Array = []
	for c in _mano_c:
		suyo.append(Casino.nombre_carta(int(c)))
	if not final:
		suyo.append("?")
	_texto_mano.text = "Tú: %s (%d)    Crupier: %s%s" % [" ".join(tuyo), Casino.total_mano(_mano_j), " ".join(suyo),
			(" (%d)" % Casino.total_mano(_mano_c)) if final else ""]


# Al salir con buenas ganancias, alguien puede seguirte hasta la calle.
func cerrar() -> void:
	var ganancia: int = neto_noche
	super()
	if ganancia >= 500 and randf() < 0.4:
		seguir_al_jugador(get_tree())


static func seguir_al_jugador(arbol: SceneTree) -> void:
	Juego.sospecha = minf(100.0, Juego.sospecha + 8.0)
	GestorMatones.enviar_cobrador(arbol, "Unos tipos te vieron ganar y te siguen hasta la calle. ¡Cuidado!")
