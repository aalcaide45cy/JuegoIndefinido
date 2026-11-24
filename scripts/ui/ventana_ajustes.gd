# ventana_ajustes.gd
# -----------------------------------------------------------------------------
# Ajustes del juego en UNA sola ventana con pestañas: Gráficos, Sonido y juego y
# Controles. Tiene un buscador que filtra las opciones de todas las pestañas a la
# vez ("sombras", "volumen", "mando"...) y salta a la primera que tenga resultados.
# Se abre desde el menú de inicio y el de pausa.
# -----------------------------------------------------------------------------
class_name VentanaAjustes
extends Ventana

var _pestanas: UI.Pestanas
var _paginas: Array = []
var _resultado: Label
var _campo: LineEdit


func construir() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pistas_extra = [["pestanas", "Cambiar pestaña"]]
	var cuerpo: VBoxContainer = marco("Ajustes", "", Vector2(1040, 680))
	_pestanas = UI.Pestanas.new()
	cuerpo.add_child(_pestanas)
	for par in [["Gráficos", VentanaGraficos.new(), "gear"], ["Sonido y juego", VentanaSonido.new(), "audioOn"],
			["Controles", VentanaControles.new(), "gamepad"]]:
		var pagina: VentanaOpciones = par[1]
		pagina.incrustada = true
		_paginas.append(pagina)
		_pestanas.anadir(par[0], pagina, par[2])
	_resultado = UI.nota("", false)
	_campo = UI.buscador("Buscar un ajuste…", _buscar)
	_campo.custom_minimum_size.x = 260
	var extra: HBoxContainer = _pestanas.hueco_extra()
	extra.add_child(_resultado)
	extra.add_child(_campo)


func _buscar(texto: String) -> void:
	var total: int = 0
	var primera: int = -1
	for i in _paginas.size():
		var p: VentanaOpciones = _paginas[i]
		p.filtrar(texto)
		if texto != "":
			var n: int = p.coincidencias()
			total += n
			if n > 0 and primera < 0:
				primera = i
	if texto == "":
		_resultado.text = ""
		return
	_resultado.text = "%d resultados" % total if total != 1 else "1 resultado"
	if primera >= 0 and _paginas[_pestanas.actual].coincidencias() == 0:
		_pestanas.elegir(primera)
