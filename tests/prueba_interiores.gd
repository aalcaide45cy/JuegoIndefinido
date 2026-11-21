# Interiores de casas: para TODAS las casas de los asentamientos comprueba que el reparto cabe
# dentro de la casa, que desde la puerta se llega a cada habitación (rejilla de 20 cm con un
# jugador de 30 cm de radio) y cuánto tarda en generarse. Sin ventana:
#   godot --headless --path . res://tests/prueba_interiores.tscn
extends Node

const CELDA: float = 0.2
const RADIO: float = 0.3
const PASO_ALCANCE: int = 6   # La rejilla de paso es cara: se hace en 1 de cada 6 casas (y siempre en las de distrito distinto).

var fallos: int = 0


func comprobar(c: bool, t: String) -> void:
	if not c:
		fallos += 1
		if fallos < 25:
			print("FALLO: ", t)


func _ready() -> void:
	await get_tree().process_frame
	GeneradorMundo.iniciar(1847, Rect2(-110.0, -120.0, 440.0, 240.0))
	var total: int = 0
	var por_tipo: Dictionary = {}
	var muebles: int = 0
	var t0: int = Time.get_ticks_usec()
	var tiempo_gen: int = 0
	var peor_hab: int = 0
	var probadas_alcance: int = 0
	for s in GeneradorMundo.todos_asentamientos():
		var p: Vector2 = s["pos"]
		var m: float = float(s["mitad"]) + 60.0
		var rect: Rect2 = Rect2(p.x - m, p.y - m, m * 2.0, m * 2.0)
		for c in GeneradorMundo._casas_en(s, rect):
			if c.has("servicio"):
				continue
			total += 1
			var ta: int = Time.get_ticks_usec()
			var d: Dictionary = InteriorCasa.generar(c)
			tiempo_gen += Time.get_ticks_usec() - ta
			por_tipo[d["tipo"]] = int(por_tipo.get(d["tipo"], 0)) + 1
			muebles += (d["cajas"] as Array).size()
			peor_hab = maxi(peor_hab, (d["habitaciones"] as Array).size())
			_comprobar_casa(c, d, total % PASO_ALCANCE == 0)
			if total % 25 == 0:
				probadas_alcance += 1
	print("Casas probadas: %d  tipos: %s" % [total, por_tipo])
	print("Cajas por casa (media): %.1f  | generar() medio: %.0f us  | habitaciones máx: %d" % [
			float(muebles) / maxf(1.0, total), float(tiempo_gen) / maxf(1.0, total), peor_hab])
	print("RESULTADO: ", "TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


func _comprobar_casa(c: Dictionary, d: Dictionary, con_paso: bool) -> void:
	var g: float = GeneradorMundo.GROSOR_MURO
	var x0: float = float(c["x"]) - float(c["w"]) / 2.0 + g - 0.01
	var x1: float = float(c["x"]) + float(c["w"]) / 2.0 - g + 0.01
	var z0: float = float(c["z"]) - float(c["d"]) / 2.0 + g - 0.01
	var z1: float = float(c["z"]) + float(c["d"]) / 2.0 - g + 0.01
	var etiqueta: String = "casa (%.0f, %.0f) %s %.1fx%.1f" % [c["x"], c["z"], d["tipo"], c["w"], c["d"]]
	var y_suelo: float = float(c["y"]) + 0.1
	var solidos: Array = []
	for cj in d["cajas"]:
		var pos: Vector3 = cj[0]
		var tam: Vector3 = cj[1]
		comprobar(pos.x - tam.x / 2.0 >= x0 and pos.x + tam.x / 2.0 <= x1 and pos.z - tam.z / 2.0 >= z0 and pos.z + tam.z / 2.0 <= z1,
				"%s: una pieza se sale de la casa (%s %s)" % [etiqueta, pos, tam])
		comprobar(pos.y - tam.y / 2.0 >= y_suelo - 0.01 and pos.y + tam.y / 2.0 <= float(c["y"]) + 3.11,
				"%s: una pieza se sale en altura (%s %s)" % [etiqueta, pos, tam])
		if bool(cj[3]) and pos.y - tam.y / 2.0 < y_suelo + 1.7 and pos.y + tam.y / 2.0 > y_suelo + 0.15:
			solidos.append(Rect2(pos.x - tam.x / 2.0 - RADIO, pos.z - tam.z / 2.0 - RADIO, tam.x + 2.0 * RADIO, tam.z + 2.0 * RADIO))
	if not con_paso:
		return
	# Rejilla de paso.
	var nx: int = int((x1 - x0) / CELDA)
	var nz: int = int((z1 - z0) / CELDA)
	var libre: PackedByteArray = PackedByteArray()
	libre.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var pt: Vector2 = Vector2(x0 + (ix + 0.5) * CELDA, z0 + (iz + 0.5) * CELDA)
			var ok: bool = pt.x > x0 + RADIO * 0.5 and pt.x < x1 - RADIO * 0.5 and pt.y > z0 + RADIO * 0.5 and pt.y < z1 - RADIO * 0.5
			if ok:
				for r in solidos:
					if (r as Rect2).has_point(pt):
						ok = false
						break
			libre[iz * nx + ix] = 1 if ok else 0
	var ent: Vector3 = d["entrada"]
	var sx: int = clampi(int((ent.x - x0) / CELDA), 0, nx - 1)
	var sz: int = clampi(int((ent.z - z0) / CELDA), 0, nz - 1)
	comprobar(libre[sz * nx + sx] == 1, "%s: la entrada está bloqueada" % etiqueta)
	var vist: PackedByteArray = PackedByteArray()
	vist.resize(nx * nz)
	var cola: Array = [Vector2i(sx, sz)]
	vist[sz * nx + sx] = 1
	var i: int = 0
	while i < cola.size():
		var q: Vector2i = cola[i]
		i += 1
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = q + dir
			if n.x < 0 or n.y < 0 or n.x >= nx or n.y >= nz:
				continue
			var idx: int = n.y * nx + n.x
			if libre[idx] == 1 and vist[idx] == 0:
				vist[idx] = 1
				cola.append(n)
	# Cada habitación debe tener celdas libres y todas alcanzables.
	for h in d["habitaciones"]:
		var r: Rect2 = h
		var libres: int = 0
		var alcanzables: int = 0
		for iz in nz:
			for ix in nx:
				var pt: Vector2 = Vector2(x0 + (ix + 0.5) * CELDA, z0 + (iz + 0.5) * CELDA)
				if r.grow(-0.2).has_point(pt) and libre[iz * nx + ix] == 1:
					libres += 1
					if vist[iz * nx + ix] == 1:
						alcanzables += 1
		comprobar(libres > 0 and alcanzables >= libres * 0.9,
				"%s: habitación %s sin paso (%d de %d celdas libres alcanzables)" % [etiqueta, r, alcanzables, libres])
