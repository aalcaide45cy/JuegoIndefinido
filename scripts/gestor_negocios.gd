# gestor_negocios.gd
# -----------------------------------------------------------------------------
# Hace avanzar tus negocios: cada vez que pasa un día del juego cobra los
# alquileres, paga los gastos, estropea lo que se usa y trae clientes y ofertas
# nuevas (la lógica está en negocios.gd). Lo añade mundo.gd.
# -----------------------------------------------------------------------------
class_name GestorNegocios
extends Node


func _ready() -> void:
	add_to_group("gestor_negocios")
	Juego.dia_nuevo.connect(_al_cambiar_el_dia)
	Negocios.ponerse_al_dia()   # Al cargar partida o al empezar.


func _al_cambiar_el_dia() -> void:
	Negocios.ponerse_al_dia()
	Blanqueo.nuevo_dia()
