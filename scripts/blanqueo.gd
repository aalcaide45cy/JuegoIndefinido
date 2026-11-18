# blanqueo.gd
# -----------------------------------------------------------------------------
# La lógica de "blanquear" dinero negro a través de tus negocios (mecánica de
# ficción del juego). Todo son funciones estáticas; el estado vive en
# Negocios.estado()["blanqueo"] (se guarda con la partida) y en Juego
# (dinero_negro, vigilancia_fiscal). Los números están en datos/blanqueo.gd.
# Multijugador (docs/DINERO_LIMPIO_NEGRO.md): dinero, dinero_negro, banco y este
# estado son "la cartera"; en modo cooperativo viven en el equipo.
# -----------------------------------------------------------------------------
class_name Blanqueo
extends RefCounted

const Datos = preload("res://scripts/datos/blanqueo.gd")
const DatosNegocios = preload("res://scripts/datos/negocios.gd")


static func _estado() -> Dictionary:
	var e: Dictionary = Negocios.estado()
	if not e.has("blanqueo"):
		e["blanqueo"] = {"dia": Juego.dia, "hoy": {}, "total": 0}
	var b: Dictionary = e["blanqueo"]
	if int(b["dia"]) != Juego.dia:   # Nuevo día: se renueva el límite de cada frente.
		b["dia"] = Juego.dia
		b["hoy"] = {}
	return b


static func tiene_frente(id: String) -> bool:
	return Datos.FRENTES.has(id) and Negocios.tiene_licencia(id)


# Límite diario de un frente (crece con las propiedades/vehículos que tengas de su tipo).
static func limite(id: String) -> int:
	if not tiene_frente(id):
		return 0
	var f: Dictionary = Datos.FRENTES[id]
	var n: int = 0
	for a in Negocios.estado()["activos"]:
		if DatosNegocios.cat_de(str(a["tipo"])) in f["cats"]:
			n += 1
	return int(round(float(f["cap"]) * (1.0 + Datos.CRECE_POR_ACTIVO * float(mini(n, Datos.MAX_ACTIVOS_CUENTAN)))))


static func usado_hoy(id: String) -> int:
	return int(_estado()["hoy"].get(id, 0))


static func disponible(id: String) -> int:
	return maxi(0, limite(id) - usado_hoy(id))


static func total_blanqueado() -> int:
	return int(_estado()["total"])


# Lo que recibirías limpio si pasas "cantidad" por ese frente.
static func neto(id: String, cantidad: int) -> int:
	return cantidad - int(ceil(float(cantidad) * float(Datos.FRENTES[id]["comision"])))


# Blanquea "cantidad" de dinero negro por el frente. Devuelve el texto para el jugador.
static func blanquear(id: String, cantidad: int) -> String:
	if not Datos.FRENTES.has(id):
		return ""
	if not tiene_frente(id):
		return "Necesitas la licencia de %s." % str(DatosNegocios.LICENCIAS[id]["nombre"])
	cantidad = mini(cantidad, mini(Juego.dinero_negro, disponible(id)))
	if cantidad <= 0:
		if Juego.dinero_negro <= 0:
			return "No tienes dinero negro."
		return "Ese negocio ya no puede mover más dinero hoy."
	var f: Dictionary = Datos.FRENTES[id]
	var limpio: int = neto(id, cantidad)
	Juego.dinero_negro -= cantidad
	Juego.dinero += limpio
	var b: Dictionary = _estado()
	b["hoy"][id] = usado_hoy(id) + cantidad
	b["total"] = int(b["total"]) + cantidad
	# La vigilancia sube según la parte del límite que uses; los guardias también sospechan.
	var cap: float = maxf(1.0, float(f["cap"]))
	Juego.vigilancia_fiscal = minf(100.0, Juego.vigilancia_fiscal + Datos.VIGILANCIA_POR_LIMITE * float(f["riesgo"]) * float(cantidad) / cap)
	Juego.sospecha = minf(100.0, Juego.sospecha + Datos.SOSPECHA_POR_MIL * float(cantidad) / 1000.0)
	Negocios._tocar()
	Juego.cambio.emit()
	return "Has pasado %d $ de dinero negro por %s: te quedan %d $ limpios (comisión %d $)." % [
			cantidad, str(DatosNegocios.LICENCIAS[id]["nombre"]), limpio, cantidad - limpio]


# Cada día baja la vigilancia; si sigue muy alta, puede haber inspección.
# Devuelve el texto de la inspección ("" si no hubo).
static func nuevo_dia() -> String:
	var v: float = maxf(0.0, Juego.vigilancia_fiscal - Datos.VIGILANCIA_BAJA_DIA)
	var texto: String = ""
	if Juego.vigilancia_fiscal >= Datos.VIGILANCIA_INSPECCION and randf() < Datos.INSPECCION_PROB:
		texto = inspeccion()
		v = Datos.INSPECCION_VIGILANCIA_TRAS
	Juego.vigilancia_fiscal = v
	return texto


# Hacienda se interesa por tus negocios: te quitan parte del dinero negro, multan
# sobre el limpio y la policía te busca.
static func inspeccion() -> String:
	var quitado: int = int(Juego.dinero_negro * Datos.INSPECCION_CONFISCA_NEGRO)
	var multa: int = int(Juego.dinero * Datos.INSPECCION_MULTA_LIMPIO)
	Juego.dinero_negro -= quitado
	Juego.dinero -= multa
	var t: String = "¡Inspección! Revisan tus negocios: confiscan %d $ de dinero negro y te multan con %d $." % [quitado, multa]
	Juego.subir_estrellas(Datos.INSPECCION_ESTRELLAS, "Inspección de tus negocios")
	Juego.nuevo_aviso(t)
	Juego.cambio.emit()
	return t
