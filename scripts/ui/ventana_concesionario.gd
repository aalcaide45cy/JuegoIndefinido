# ventana_concesionario.gd
# -----------------------------------------------------------------------------
# Lista de vehículos a la venta (Vehiculo.TIPOS). Al comprar, el vehículo
# aparece en el punto de entrega. SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name VentanaConcesionario
extends Ventana

var punto: Vector3 = Vector3.ZERO
var giro: float = 0.0


func construir() -> void:
	var caja: VBoxContainer = panel_centrado(Vector2(760, 560))
	cabecera(caja, "Concesionario")
	subtitulo(caja, "Gasolina: bidón en la ferretería. Los vehículos se guardan donde los dejes.")
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(scroll)
	var lista: VBoxContainer = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)
	for id_t in Vehiculo.TIPOS:
		var t: Dictionary = Vehiculo.TIPOS[id_t]
		var fila: HBoxContainer = HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		lista.add_child(fila)
		var info: Label = Hud.crear_label(17)
		info.custom_minimum_size.x = 400.0
		info.text = "%s  ·  %d km/h" % [t["nombre"], int(float(t["vmax"]) * 3.6)]
		fila.add_child(info)
		fila.add_child(Hud.crear_boton("Comprar %d $" % t["precio"], _comprar.bind(id_t)))


func _comprar(id_t: String) -> void:
	var t: Dictionary = Vehiculo.TIPOS[id_t]
	var gestor: GestorVehiculos = get_tree().get_first_node_in_group("gestor_vehiculos") as GestorVehiculos
	if gestor == null:
		return
	if not Juego.gastar(int(t["precio"])):
		Juego.avisar("No te llega para comprar: %s." % t["nombre"])
		return
	gestor.entregar(id_t, punto, giro)
	Juego.avisar("¡Compraste %s! Está en la plaza de entrega del concesionario." % t["nombre"])
	Juego.cambio.emit()
