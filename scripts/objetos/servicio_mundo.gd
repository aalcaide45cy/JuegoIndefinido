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

const NOMBRES: Dictionary = {"banco": "Banco", "taberna": "Taberna", "hospital": "Hospital",
		"taller": "Taller", "gasolinera": "Gasolinera", "comisaria": "Comisaría", "bomberos": "Bomberos"}

var servicio: String = "gasolinera"
var con_visual: bool = false


func _ready() -> void:
	distancia = 3.0
	var rotulo: Label3D = Construir.texto(self, Vector3(0, 2.6 if servicio != "gasolinera" else 4.2, 0),
			str(NOMBRES.get(servicio, servicio)).to_upper(), 48, Color(1.0, 0.95, 0.7))
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.no_depth_test = false
	if con_visual and servicio == "gasolinera":
		_dibujar_gasolinera()


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
		"taberna":
			return "Tomar algo (%d $): algo de vida y menos sospecha" % Economia.TABERNA_PRECIO
		"banco":
			return "Banco (%d $ ingresados): E ingresar  ·  Mayús+E retirar todo" % Juego.banco
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
		"taberna": _usar_taberna()
		"banco": _usar_banco(mayus)


func _precio_gasolina(v) -> int:
	return maxi(1, int(ceil((100.0 - float(v.get("gasolina"))) * Economia.GASOLINA_POR_PORCENTAJE * float(Vehiculo.TIPOS[v.tipo].get("gasto", 1.0)))))


func _precio_reparacion(v) -> int:
	var base: int = maxi(1, int(ceil((100.0 - float(v.get("salud"))) * Economia.REPARACION_POR_PORCENTAJE)))
	return maxi(1, int(round(base * (1.0 - Juego.descuento_servicio("taller")))))


func _precio_cura() -> int:
	var base: int = maxi(Economia.CURA_MINIMA, int(ceil((Juego.vida_max() - Juego.vida) * Economia.CURA_POR_PUNTO)))
	return maxi(1, int(round(base * (1.0 - Juego.descuento_servicio("hospital")))))


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
