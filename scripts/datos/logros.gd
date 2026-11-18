# logros.gd (datos)
# -----------------------------------------------------------------------------
# La lista de logros. Cada uno tiene:
#   nombre, desc  -> lo que ve el jugador.
#   tipo, valor   -> la condición: se cumple cuando la cuenta de "tipo" llega a "valor"
#                    (los tipos están en Logros.cuenta()). Sin tipo = solo se
#                    desbloquea llamando a Logros.desbloquear("id") desde el juego.
#   steam         -> nombre del logro en Steamworks (se crea con ese mismo nombre al publicar).
# Para añadir uno: copia una línea. El orden de aquí es el de la lista.
# -----------------------------------------------------------------------------
extends RefCounted

const LISTA: Dictionary = {
	"primer_dia": {"nombre": "Una noche más", "desc": "Sobrevive hasta el día 2.", "tipo": "dia", "valor": 2, "steam": "ACH_PRIMER_DIA"},
	"una_semana": {"nombre": "Una semana en la sombra", "desc": "Llega al día 8.", "tipo": "dia", "valor": 8, "steam": "ACH_UNA_SEMANA"},
	"un_mes": {"nombre": "Veterano de la calle", "desc": "Llega al día 31.", "tipo": "dia", "valor": 31, "steam": "ACH_UN_MES"},
	"dinero_1k": {"nombre": "Primeros ahorros", "desc": "Ten 1.000 $ a la vez.", "tipo": "dinero", "valor": 1000, "steam": "ACH_DINERO_1K"},
	"dinero_10k": {"nombre": "Bolsillos llenos", "desc": "Ten 10.000 $ a la vez.", "tipo": "dinero", "valor": 10000, "steam": "ACH_DINERO_10K"},
	"dinero_100k": {"nombre": "Pequeña fortuna", "desc": "Ten 100.000 $ a la vez.", "tipo": "dinero", "valor": 100000, "steam": "ACH_DINERO_100K"},
	"dinero_1m": {"nombre": "Millonario clandestino", "desc": "Ten 1.000.000 $ a la vez.", "tipo": "dinero", "valor": 1000000, "steam": "ACH_DINERO_1M"},
	"nivel_3": {"nombre": "Aprendiz", "desc": "Llega al nivel 3.", "tipo": "nivel", "valor": 3, "steam": "ACH_NIVEL_3"},
	"nivel_5": {"nombre": "Oficial", "desc": "Llega al nivel 5.", "tipo": "nivel", "valor": 5, "steam": "ACH_NIVEL_5"},
	"nivel_10": {"nombre": "Maestro", "desc": "Llega al nivel 10.", "tipo": "nivel", "valor": 10, "steam": "ACH_NIVEL_10"},
	"primera_receta": {"nombre": "Primer brebaje", "desc": "Prepara tu primera poción en el caldero.", "steam": "ACH_PRIMERA_RECETA"},
	"recetas_10": {"nombre": "Alquimista", "desc": "Descubre 10 recetas distintas.", "tipo": "recetas", "valor": 10, "steam": "ACH_RECETAS_10"},
	"recetas_50": {"nombre": "Libro de hechizos", "desc": "Descubre 50 recetas distintas.", "tipo": "recetas", "valor": 50, "steam": "ACH_RECETAS_50"},
	"estudiante": {"nombre": "Siempre aprendiendo", "desc": "Aprende una habilidad.", "tipo": "habilidades", "valor": 1, "steam": "ACH_ESTUDIANTE"},
	"polivalente": {"nombre": "Todoterreno", "desc": "Aprende 4 habilidades.", "tipo": "habilidades", "valor": 4, "steam": "ACH_POLIVALENTE"},
	"con_techo": {"nombre": "Techo propio", "desc": "Alquila o compra una vivienda.", "tipo": "viviendas", "valor": 1, "steam": "ACH_CON_TECHO"},
	"terrateniente": {"nombre": "Terrateniente", "desc": "Ten 3 huertos o viviendas.", "tipo": "propiedades", "valor": 3, "steam": "ACH_TERRATENIENTE"},
	"granjero": {"nombre": "Granjero", "desc": "Ten tu primer animal de granja.", "tipo": "granja", "valor": 1, "steam": "ACH_GRANJERO"},
	"conductor": {"nombre": "Con ruedas", "desc": "Ten un vehículo propio.", "tipo": "vehiculos", "valor": 1, "steam": "ACH_CONDUCTOR"},
	"flota": {"nombre": "Flota", "desc": "Ten 5 vehículos propios.", "tipo": "vehiculos", "valor": 5, "steam": "ACH_FLOTA"},
	"jefe": {"nombre": "El jefe", "desc": "Contrata a tu primer empleado.", "tipo": "personal", "valor": 1, "steam": "ACH_JEFE"},
	"plantilla": {"nombre": "Plantilla", "desc": "Ten 5 empleados a la vez.", "tipo": "personal", "valor": 5, "steam": "ACH_PLANTILLA"},
	"empresario": {"nombre": "Empresario", "desc": "Consigue una licencia de negocio.", "tipo": "licencias", "valor": 1, "steam": "ACH_EMPRESARIO"},
	"buena_fama": {"nombre": "Buena fama", "desc": "Alcanza 50 de reputación.", "tipo": "reputacion", "valor": 50, "steam": "ACH_BUENA_FAMA"},
}
