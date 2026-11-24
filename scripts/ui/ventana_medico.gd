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


func construir() -> void:
	var caja: VBoxContainer = panel_centrado(Vector2(720, 460))
	cabecera(caja, "Consulta del médico")
	_estado = Hud.crear_label(17, Color(1, 0.92, 0.6))
	caja.add_child(_estado)
	subtitulo(caja, "«Sin preguntas, sin recetas y sin facturas.» Elige un tratamiento:")
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
	_estado.text = "Vida %d/%d  ·  Dinero %d $" % [int(Juego.vida), int(Juego.vida_max()), Juego.dinero]
	for hijo in _lista.get_children():
		hijo.queue_free()
	var curar: int = precio_curar()
	var malos: bool = tiene_efectos_malos()
	_fila("Curar heridas", "Te deja con la vida completa.", curar, curar > 0, _curar)
	_fila("Desintoxicar", "Quita el veneno, el mareo y los demás efectos malos.", PRECIO_DESINTOXICAR, malos, _desintoxicar)
	var completa: int = int(round(float(curar + PRECIO_DESINTOXICAR) * 0.85))
	_fila("Revisión completa", "Cura todo, desintoxica y deja un minuto de regeneración.", completa,
			curar > 0 or malos, _revision)
	var refuerzo_ok: bool = Juego.nivel >= NIVEL_REFUERZO
	_fila("Refuerzo de hierro (nivel %d)" % NIVEL_REFUERZO, "Resistencia al daño durante 5 minutos.",
			PRECIO_REFUERZO, refuerzo_ok, _refuerzo)


func _fila(titulo: String, descripcion: String, precio: int, util: bool, accion: Callable) -> void:
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	_lista.add_child(fila)
	var texto: Label = Hud.crear_label(16)
	texto.text = "%s   —   %d $\n%s" % [titulo, precio, descripcion]
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(texto)
	var boton: Button = Hud.crear_boton("Pagar", accion.bind(precio))
	boton.disabled = not util or Juego.dinero < precio
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
