# gestor_personal.gd
# -----------------------------------------------------------------------------
# Hace trabajar al personal contratado (Juego.personal) y les paga cada día:
#   - Agricultor: cuando el huerto asignado madura, cosecha al almacén
#     (Juego.almacen) y vuelve a sembrar (con semillas del almacén o comprándolas).
#   - Ganadero: pasa la producción del corral asignado al almacén.
#   - Guardaespaldas: baja la sospecha.
# Si no hay dinero el día de pago, el empleado se marcha. SIN PROBAR en Godot.
# -----------------------------------------------------------------------------
class_name GestorPersonal
extends Node

const DatosPersonal = preload("res://scripts/datos/personal.gd")
const DatosObjetos = preload("res://scripts/datos/objetos.gd")
const Propiedades = preload("res://scripts/datos/propiedades.gd")

var _t: float = 0.0


func _process(delta: float) -> void:
	if Juego.personal.is_empty():
		Juego.dia_pago = Juego.dia
		return
	for e in Juego.personal:
		if e["oficio"] == "guardaespaldas":
			Juego.sospecha = maxf(0.0, Juego.sospecha - 0.5 * int(e["nivel"]) * delta)
	_t += delta
	if _t >= 4.0:
		_t = 0.0
		for e in Juego.personal:
			_trabajar(e)
	if Juego.dia > Juego.dia_pago:
		_pagar(Juego.dia - Juego.dia_pago)
		Juego.dia_pago = Juego.dia


func _pagar(dias: int) -> void:
	var se_van: Array = []
	for e in Juego.personal:
		var total: int = int(e["sueldo"]) * dias
		if not Juego.gastar(total):
			se_van.append(e)
			Juego.avisar("%s se marcha: no pudiste pagarle %d $." % [e["nombre"], total])
	for e in se_van:
		Juego.personal.erase(e)
	if Juego.personal.size() > 0 and se_van.is_empty():
		Juego.avisar("Día de pago: personal pagado.")
	Juego.cambio.emit()


func _trabajar(e: Dictionary) -> void:
	var destino: String = str(e["destino"])
	if destino == "":
		return
	var rend: float = 0.7 + 0.15 * int(e["nivel"])
	match e["oficio"]:
		"agricultor":
			_cosechar(destino, rend)
		"ganadero":
			var g: Dictionary = Juego.granja.get(destino, {})
			var prod: int = int(g.get("prod", 0))
			if prod > 0 and Corral.ESPECIES.has(_especie(destino)):
				var producto: String = Corral.ESPECIES[_especie(destino)]["producto"]
				_al_almacen(producto, prod)
				g["prod"] = 0


func _especie(id_corral: String) -> String:
	return "gallina" if id_corral == "gallinero" else "vaca"


func _al_almacen(id_obj: String, cantidad: int) -> void:
	Juego.almacen[id_obj] = int(Juego.almacen.get(id_obj, 0)) + cantidad


func _m2(id_huerto: String) -> int:
	for p in Propiedades.LISTA:
		if p["id"] == id_huerto:
			return int(p["m2"])
	return 144


func _cosechar(id_huerto: String, rend: float) -> void:
	if not Juego.huertos.has(id_huerto):
		return
	var e = Juego.parcelas.get(id_huerto, null)
	var m2: int = _m2(id_huerto)
	var semillas_n: int = clampi(int(ceil(m2 / 50.0)), 1, 20)
	if e != null and float(e["t"]) > 0.0:
		return   # Todavía crece.
	var semilla: String = ""
	if e != null:
		semilla = str(e["semilla"])
		var unidades: int = int(clampi(m2 / 12, 1, 60) * rend)
		_al_almacen(Parcela.CULTIVOS[semilla]["cosecha"], maxi(1, unidades))
		Juego.ganar_xp(maxi(1, unidades / 2))
		Juego.parcelas.erase(id_huerto)
	else:
		semilla = str(Juego.almacen_ultima_semilla.get(id_huerto, ""))
	if semilla == "" or not Parcela.CULTIVOS.has(semilla):
		return
	Juego.almacen_ultima_semilla[id_huerto] = semilla
	# Siembra de nuevo: primero con semillas del almacén, si no las compra.
	var en_almacen: int = int(Juego.almacen.get(semilla, 0))
	if en_almacen >= semillas_n:
		Juego.almacen[semilla] = en_almacen - semillas_n
	else:
		var coste: int = int(DatosObjetos.datos(semilla)["precio"]) * semillas_n
		if not Juego.gastar(coste):
			return
	var total: float = Parcela.CULTIVOS[semilla]["tiempo"]
	Juego.parcelas[id_huerto] = {"semilla": semilla, "t": total, "total": total}
