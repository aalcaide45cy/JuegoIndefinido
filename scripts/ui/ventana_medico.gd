# ventana_medico.gd
# -----------------------------------------------------------------------------
# La consulta del médico: tratamientos de pago para curarte. Los precios y
# efectos están en TRATAMIENTOS (todo en datos, para ajustar la economía sin
# tocar el código). El precio de curar depende de la vida que te falta.
# -----------------------------------------------------------------------------
class_name VentanaMedico
extends Ventana

# Dólares por cada punto de vida que falta, y mínimo que se cobra por curar.
const PRECIO_POR_PUNTO: float = 0.8
const PRECIO_MINIMO: int = 8
const PRECIO_DESINTOXICAR: int = 45
const PRECIO_REFUERZO: int = 90
const NIVEL_REFUERZO: int = 3
const DURACION_REFUERZO: float = 300.0
const DURACION_REGENERACION: float = 60.0

var _estado: Label
var _lista: VBoxContainer
var _barra_vida: ProgressBar


func construir() -> void:
	var caja: VBoxContainer = marco("Consulta del médico", "«Sin preguntas, sin recetas y sin facturas.»", Vector2(720, 520))
	_estado = UI.etiqueta("", "Dinero")
	caja.add_child(_estado)
	_barra_vida = UI.barra(Juego.vida, Juego.vida_max(), Tema.PELIGRO, 14, "")
	caja.add_child(_barra_vida)
	caja.add_child(UI.seccion("Tratamientos"))
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 8)
	caja.add_child(_lista)
	Juego.cambio.connect(_refrescar)
	_refrescar()


static func precio_curar() -> int:
	var falta: float = Juego.vida_max() - Juego.vida
	if falta < 1.0:
		return 0
	return maxi(PRECIO_MINIMO, int(ceil(falta * PRECIO_POR_PUNTO)))


static func tiene_efectos_malos() -> bool:
	for id in Juego.efectos_activos:
		if not Juego.DatosEfectos.es_bueno(id):
			return true
	return false


func _refrescar() -> void:
	if not is_instance_valid(_lista):
		return
	_estado.text = "Vida %d/%d   ·   %s" % [int(Juego.vida), int(Juego.vida_max()), UI.dinero(Juego.dinero)]
	_barra_vida.max_value = Juego.vida_max()
	_barra_vida.value = Juego.vida
	for hijo in _lista.get_children():
		_lista.remove_child(hijo)
		hijo.queue_free()
	var curar: int = precio_curar()
	var malos: bool = tiene_efectos_malos()
	_fila("Curar heridas", "Te deja con la vida completa.", curar, curar > 0, _curar)
	_fila("Desintoxicar", "Quita el veneno, el mareo y los demás efectos malos.", PRECIO_DESINTOXICAR, malos, _desintoxicar)
	var completa: int = int(round(float(curar + PRECIO_DESINTOXICAR) * 0.85))
	_fila("Revisión completa", "Cura todo, desintoxica y deja un minuto de regeneración.", completa,
			curar > 0 or malos, _revision)
	var refuerzo_ok: bool = Juego.nivel >= NIVEL_REFUERZO
	_fila("Refuerzo de hierro", "Resistencia al daño durante 5 minutos. Requiere nivel %d." % NIVEL_REFUERZO,
			PRECIO_REFUERZO, refuerzo_ok, _refuerzo)


func _fila(titulo: String, descripcion: String, precio: int, util: bool, accion: Callable) -> void:
	var t: PanelContainer = UI.tarjeta()
	_lista.add_child(t)
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	t.add_child(fila)
	var textos: VBoxContainer = VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 2)
	fila.add_child(textos)
	textos.add_child(UI.etiqueta(titulo, "", Tema.TEXTO if util else Tema.TEXTO_SUAVE, 17))
	textos.add_child(UI.nota(descripcion))
	var p: Label = UI.etiqueta(UI.dinero(precio), "Dinero")
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(p)
	var boton: Button = UI.boton("Pagar", accion.bind(precio), "BotonPrimario")
	boton.disabled = not util or Juego.dinero < precio
	boton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(boton)


func _cobrar(precio: int) -> bool:
	if not Juego.gastar(precio):
		Juego.avisar("No te llega el dinero.")
		return false
	return true


func _curar(precio: int) -> void:
	if precio > 0 and _cobrar(precio):
		Juego.vida = Juego.vida_max()
		Juego.avisar("El médico te cose, te venda y te cobra %d $. Vida completa." % precio)
		Juego.cambio.emit()
		Juego.empezar_convalecencia(Juego.DatosOficios.CONVALECENCIA_MEDICO)


func _desintoxicar(precio: int) -> void:
	if _cobrar(precio):
		Juego.quitar_efectos_malos()
		Juego.avisar("Te dan un brebaje asqueroso y se te pasan los males.")


func _revision(precio: int) -> void:
	if _cobrar(precio):
		Juego.vida = Juego.vida_max()
		Juego.quitar_efectos_malos()
		Juego.aplicar_efecto("regeneracion", DURACION_REGENERACION, 1.0)
		Juego.avisar("Revisión completa por %d $: como nuevo." % precio)
		Juego.cambio.emit()
		Juego.empezar_convalecencia(Juego.DatosOficios.CONVALECENCIA_MEDICO)


func _refuerzo(precio: int) -> void:
	if _cobrar(precio):
		Juego.aplicar_efecto("resistencia", DURACION_REFUERZO, 1.0)
		Juego.avisar("Te inyectan «algo». Durante 5 minutos aguantas mucho mejor los golpes.")
