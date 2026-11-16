# menus.gd
# -----------------------------------------------------------------------------
# Las tres ventanas del juego, cada una como clase interna:
#   Menus.Tienda      -> comprar en la herboristería.
#   Menus.Inventario  -> lo que llevas encima (se abre con TAB).
#   Menus.Almacen     -> guardar y sacar cosas de la estantería de casa.
# Todas heredan de MenuBase (fondo, panel, título y botón de cerrar).
# -----------------------------------------------------------------------------
class_name Menus
extends RefCounted


class Tienda extends MenuBase:
	func _init() -> void:
		titulo = "Herboristería La Mandrágora Honrada"
		tamano = Vector2(720, 560)

	func rellenar(caja: VBoxContainer) -> void:
		fila(caja, "Tienes %d $" % Juego.dinero, [], 20)
		for id_objeto in GameData.OBJETOS:
			var datos: Dictionary = GameData.OBJETOS[id_objeto]
			var texto: String = "%s  —  %d $\n%s" % [datos["nombre"], datos["precio"], datos["descripcion"]]
			if Juego.objetos[id_objeto] > 0:
				texto += "  (tienes %d)" % Juego.objetos[id_objeto]
			var boton: Button = Hud.crear_boton("Comprar", _comprar.bind(id_objeto))
			boton.disabled = (datos["unico"] and Juego.objetos[id_objeto] > 0) or Juego.dinero < datos["precio"]
			fila(caja, texto, [boton], 15)
			caja.add_child(HSeparator.new())

	func _comprar(id_objeto: String) -> void:
		Juego.avisar(Juego.comprar(id_objeto))


class Inventario extends MenuBase:
	func _init() -> void:
		titulo = "Inventario (TAB)"
		tamano = Vector2(560, 520)

	func rellenar(caja: VBoxContainer) -> void:
		fila(caja, "Dinero: %d $   (alquiler del Prefecto: %d $)" % [Juego.dinero, GameData.OBJETIVO_DINERO], [], 20)
		caja.add_child(HSeparator.new())
		fila(caja, "Objetos", [], 19)
		var vacio: bool = true
		for id_objeto in GameData.OBJETOS:
			var cantidad: int = Juego.objetos[id_objeto]
			if cantidad <= 0:
				continue
			vacio = false
			var texto: String = "   %s: %d" % [GameData.OBJETOS[id_objeto]["nombre"], cantidad]
			if id_objeto == "jarra":
				texto = "   Jarra de agua: %d/%d riegos" % [Juego.agua_jarra, GameData.CARGAS_JARRA]
			fila(caja, texto)
		if vacio:
			fila(caja, "   (nada; compra en la herboristería)")
		fila(caja, "Hierbas cosechadas (Q elige la que llevas en la mano)", [], 19)
		for id_hierba in GameData.HIERBAS:
			var marca: String = "  > " if id_hierba == Juego.hierba_seleccionada() else "     "
			fila(caja, "%s%s: %d" % [marca, GameData.HIERBAS[id_hierba]["nombre"], Juego.hierbas[id_hierba]])
		fila(caja, "Pociones", [], 19)
		for id_pocion in GameData.POCIONES:
			fila(caja, "   %s: %d" % [GameData.POCIONES[id_pocion]["nombre"], Juego.pociones[id_pocion]])
		if Juego.casa_alquilada:
			fila(caja, "Casa: alquilada (estantería con %d cosas guardadas)" % _total_almacen(), [], 15)

	func _total_almacen() -> int:
		var total: int = 0
		for id_objeto in Juego.almacen:
			total += Juego.almacen[id_objeto]
		return total


class Almacen extends MenuBase:
	func _init() -> void:
		titulo = "Estantería de casa"
		tamano = Vector2(640, 520)

	func rellenar(caja: VBoxContainer) -> void:
		fila(caja, "Guarda aquí lo que no necesites llevar encima.", [], 16)
		caja.add_child(HSeparator.new())
		for id_objeto in GameData.OBJETOS:
			if id_objeto == "jarra":
				continue  # La jarra es una herramienta: siempre la llevas tú.
			var encima: int = Juego.objetos[id_objeto]
			var guardado: int = Juego.almacen[id_objeto]
			if encima == 0 and guardado == 0:
				continue
			var guardar: Button = Hud.crear_boton("Guardar 1", Juego.guardar_en_almacen.bind(id_objeto))
			guardar.disabled = encima <= 0
			var sacar: Button = Hud.crear_boton("Sacar 1", Juego.sacar_de_almacen.bind(id_objeto))
			sacar.disabled = guardado <= 0
			fila(caja, "%s\n   llevas %d · en la estantería %d" % [GameData.OBJETOS[id_objeto]["nombre"],
					encima, guardado], [guardar, sacar], 16)
