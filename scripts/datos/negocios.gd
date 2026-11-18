# negocios.gd  (datos)
# -----------------------------------------------------------------------------
# Todo lo que se puede comprar, vender y alquilar en los negocios del jugador,
# y las licencias que hay que comprar para abrir cada negocio. Para añadir algo
# nuevo (un barco, un local, una licencia...) basta con copiar una entrada:
# el resto del código (scripts/negocios.gd y las ventanas) lo leerá solo.
#
# CATEGORIAS: grupos de cosas con las que se negocia. "tasa" es lo que rinde
# el alquiler cada día, como fracción del valor (0.02 = 2% al día); "gasto" lo
# que cuesta mantenerlo cada día (impuestos, seguro, aparcamiento), alquilado o
# no, como fracción del valor; y "desgaste" lo que se estropea cada día que
# está alquilado (de 0 a 100). Un día del juego dura 60 min reales.
# Además cada licencia cobra una cuota diaria (CUOTA_LICENCIA x su precio).
#
# CATALOGO: "cat" categoría, "nombre", "precio" (valor base en perfecto estado),
# "desc" frase corta. Opcionales: "renta" (alquiler diario fijo, si no se usa la
# tasa de su categoría) y "vehiculo": id de un vehículo conducible de
# scripts/vehiculos/vehiculo.gd (TIPOS). Si existe, el precio se toma de allí y
# se puede sacar a la calle para conducirlo desde el concesionario.
# Lo que no tiene "vehiculo" (helicópteros, aviones, excavadoras, tráileres...)
# es un objeto de negocio genérico: se compra, se vende y se alquila, pero aún
# no se conduce. Cuando existan sus modelos, basta con añadir "vehiculo".
#
# LICENCIAS: cada negocio se abre pagando su licencia. "cats" lo que permite
# tratar, "ops" qué se puede hacer ("comprar", "vender", "alquilar") y
# "capacidad" cuántas propiedades o vehículos caben en tu cartera a la vez.
# -----------------------------------------------------------------------------
extends RefCounted

const CATEGORIAS: Dictionary = {
	"piso": {"nombre": "Pisos y locales", "tasa": 0.02, "gasto": 0.0035, "desgaste": 0.15, "color": Color(0.5, 0.75, 1.0)},
	"coche": {"nombre": "Coches", "tasa": 0.035, "gasto": 0.004, "desgaste": 0.9, "color": Color(1.0, 0.7, 0.4)},
	"pesado": {"nombre": "Camiones y maquinaria", "tasa": 0.028, "gasto": 0.004, "desgaste": 0.6, "color": Color(0.9, 0.85, 0.4)},
	"aire": {"nombre": "Helicópteros y aviones", "tasa": 0.022, "gasto": 0.006, "desgaste": 0.4, "color": Color(0.7, 0.9, 1.0)},
}

const CATALOGO: Dictionary = {
	# ----------------------------- Pisos y locales -----------------------------
	"garaje": {"cat": "piso", "nombre": "Plaza de garaje", "precio": 3500, "desc": "Pequeña, pero siempre hay quien busca aparcar."},
	"estudio": {"cat": "piso", "nombre": "Estudio de 25 m²", "precio": 6000, "desc": "Una habitación con cocina. Ideal para el primer inquilino."},
	"piso_1": {"cat": "piso", "nombre": "Piso de 1 habitación", "precio": 11000, "desc": "Céntrico y fácil de alquilar."},
	"piso_2": {"cat": "piso", "nombre": "Piso de 2 habitaciones", "precio": 18000, "desc": "Para parejas y compañeros de piso."},
	"piso_3": {"cat": "piso", "nombre": "Piso de 3 habitaciones", "precio": 27000, "desc": "Familias con ganas de quedarse años."},
	"solar": {"cat": "piso", "nombre": "Solar para construir", "precio": 22000, "renta": 120, "desc": "Terreno sin edificar. Rinde poco, pero se revende bien."},
	"local": {"cat": "piso", "nombre": "Local comercial", "precio": 38000, "desc": "Con escaparate a la calle principal."},
	"atico": {"cat": "piso", "nombre": "Ático con terraza", "precio": 52000, "desc": "Vistas a toda la ciudad. Inquilinos con dinero."},
	"nave": {"cat": "piso", "nombre": "Nave industrial", "precio": 60000, "desc": "Para talleres y almacenes."},
	"chalet": {"cat": "piso", "nombre": "Chalet con jardín", "precio": 85000, "desc": "El sueño de cualquier inmobiliario."},
	# --------------------------------- Coches ----------------------------------
	"moto": {"cat": "coche", "nombre": "Moto", "precio": 1800, "desc": "Rápida y barata de mantener."},
	"hatchback": {"cat": "coche", "nombre": "Utilitario deportivo", "precio": 2400, "vehiculo": "hatchback", "desc": "Compacto y ágil."},
	"sedan": {"cat": "coche", "nombre": "Sedán", "precio": 3000, "vehiculo": "sedan", "desc": "El coche de siempre."},
	"taxi": {"cat": "coche", "nombre": "Taxi", "precio": 3200, "vehiculo": "taxi", "desc": "Con su cartel y su taxímetro."},
	"furgoneta": {"cat": "coche", "nombre": "Furgoneta", "precio": 4200, "vehiculo": "furgoneta", "desc": "Mucho sitio para cargar."},
	"suv": {"cat": "coche", "nombre": "Todoterreno", "precio": 5200, "vehiculo": "suv", "desc": "Aguanta cualquier camino."},
	"deportivo": {"cat": "coche", "nombre": "Deportivo de carreras", "precio": 12000, "vehiculo": "deportivo", "desc": "Para quien no mira el consumo."},
	"limusina": {"cat": "coche", "nombre": "Limusina", "precio": 15000, "desc": "Bodas, bautizos y políticos."},
	"clasico": {"cat": "coche", "nombre": "Coche clásico de coleccionista", "precio": 30000, "desc": "Cada año vale más."},
	# ------------------------- Camiones y maquinaria ---------------------------
	"remolque_carga": {"cat": "pesado", "nombre": "Remolque de carga", "precio": 1800, "vehiculo": "remolque_carga", "desc": "Se engancha a casi cualquier cosa."},
	"remolque_grande": {"cat": "pesado", "nombre": "Semirremolque (tráiler)", "precio": 5500, "vehiculo": "remolque_grande", "desc": "Para el tráiler de largas distancias."},
	"tractor": {"cat": "pesado", "nombre": "Tractor", "precio": 6000, "vehiculo": "tractor", "desc": "Imprescindible en el campo."},
	"camion": {"cat": "pesado", "nombre": "Camión", "precio": 7500, "vehiculo": "camion", "desc": "Carga media."},
	"volquete": {"cat": "pesado", "nombre": "Camión volquete", "precio": 22000, "desc": "Obras y canteras."},
	"trailer": {"cat": "pesado", "nombre": "Cabeza tractora (tráiler)", "precio": 12000, "vehiculo": "trailer", "desc": "Largas distancias."},
	"portacoches": {"cat": "pesado", "nombre": "Portacoches", "precio": 8500, "vehiculo": "portacoches", "desc": "Transporta hasta ocho coches de una vez."},
	"grua": {"cat": "pesado", "nombre": "Camión grúa", "precio": 38000, "desc": "Levanta lo que haga falta."},
	"excavadora": {"cat": "pesado", "nombre": "Excavadora", "precio": 9000, "vehiculo": "excavadora", "desc": "Cava zanjas y cimientos."},
	"cosechadora": {"cat": "pesado", "nombre": "Cosechadora", "precio": 70000, "desc": "Recoge un campo entero en una tarde."},
	# ------------------------ Helicópteros y aviones ---------------------------
	"avioneta": {"cat": "aire", "nombre": "Avioneta", "precio": 150000, "vehiculo": "avion", "desc": "Dos plazas y mucha libertad."},
	"helicoptero": {"cat": "aire", "nombre": "Helicóptero", "precio": 90000, "vehiculo": "helicoptero", "desc": "Despega desde cualquier azotea."},
	"helicoptero_carga": {"cat": "aire", "nombre": "Helicóptero de transporte", "precio": 380000, "desc": "Mueve carga y personas."},
	"jet": {"cat": "aire", "nombre": "Jet privado", "precio": 750000, "desc": "El lujo definitivo."},
	"avion_regional": {"cat": "aire", "nombre": "Avión regional", "precio": 1200000, "desc": "Para montar tu propia aerolínea."},
}

const LICENCIAS: Dictionary = {
	"inmobiliaria": {"nombre": "Inmobiliaria", "precio": 2500, "nivel": 1, "cats": ["piso"],
			"ops": ["comprar", "vender", "alquilar"], "capacidad": 6,
			"desc": "Compra pisos y locales, véndelos o alquílalos a inquilinos que pagan cada día."},
	"concesionario": {"nombre": "Concesionario", "precio": 4000, "nivel": 2, "cats": ["coche", "pesado"],
			"ops": ["comprar", "vender"], "capacidad": 6,
			"desc": "Compra y vende coches, camiones, tractores y remolques."},
	"alquiler_coches": {"nombre": "Alquiler de coches", "precio": 3500, "nivel": 2, "cats": ["coche"],
			"ops": ["comprar", "vender", "alquilar"], "capacidad": 6,
			"desc": "Una flota de coches que alquilas por días."},
	"alquiler_maquinaria": {"nombre": "Alquiler de maquinaria", "precio": 6000, "nivel": 4, "cats": ["pesado"],
			"ops": ["comprar", "vender", "alquilar"], "capacidad": 4,
			"desc": "Excavadoras, grúas, tráileres y remolques para obras y transportistas."},
	"aerodromo": {"nombre": "Aeródromo", "precio": 40000, "nivel": 6, "cats": ["aire"],
			"ops": ["comprar", "vender", "alquilar"], "capacidad": 3,
			"desc": "Helicópteros y aviones: compra, venta y alquiler."},
	"oficina": {"nombre": "Oficina grande", "precio": 8000, "nivel": 3, "cats": [], "ops": [], "capacidad": 8,
			"desc": "Más sitio en tu cartera: 8 propiedades o vehículos más."},
}

# Cuota diaria de cada licencia, como fracción de su precio.
const CUOTA_LICENCIA: float = 0.004
# Gastos de compraventa: impuesto al comprar y comisión al vender (fracción del precio).
const IMPUESTO_COMPRA: float = 0.03
const COMISION_VENTA: float = 0.04

const NOMBRES_PERSONAS: Array = ["Marta", "Ismael", "Rosario", "Dani", "Lola", "Chema", "Vera", "Nico", "Paco", "Inés",
		"Ramiro", "Elena", "Guille", "Sofía", "Tomás", "Aurora", "Bruno", "Clara", "Hugo", "Pilar"]
const APELLIDOS: Array = ["Ortega", "Salas", "Vidal", "Roca", "Cano", "Marín", "Pons", "Lara", "Soler", "Prieto"]


static func cat_de(tipo: String) -> String:
	return str(CATALOGO[tipo]["cat"]) if CATALOGO.has(tipo) else ""


static func nombre(tipo: String) -> String:
	return str(CATALOGO[tipo]["nombre"]) if CATALOGO.has(tipo) else tipo


# Precio base en perfecto estado. Si es un vehículo conducible, el del concesionario.
static func precio_base(tipo: String) -> int:
	if not CATALOGO.has(tipo):
		return 0
	var d: Dictionary = CATALOGO[tipo]
	if d.has("vehiculo") and Vehiculo.TIPOS.has(str(d["vehiculo"])):
		return int(Vehiculo.TIPOS[str(d["vehiculo"])]["precio"])
	return int(d["precio"])


# Alquiler diario en perfecto estado.
static func renta_base(tipo: String) -> int:
	if not CATALOGO.has(tipo):
		return 0
	var d: Dictionary = CATALOGO[tipo]
	if d.has("renta"):
		return int(d["renta"])
	var tasa: float = float(CATEGORIAS[str(d["cat"])]["tasa"])
	return maxi(5, int(round(precio_base(tipo) * tasa)))


static func tipos_de(cat: String) -> Array:
	var r: Array = []
	for id in CATALOGO:
		if str(CATALOGO[id]["cat"]) == cat:
			r.append(id)
	return r


# El id del catálogo que corresponde a un vehículo conducible (tipo de Vehiculo.TIPOS), o "".
static func catalogo_de_vehiculo(tipo_v: String) -> String:
	for id in CATALOGO:
		if str(CATALOGO[id].get("vehiculo", "")) == tipo_v:
			return str(id)
	return ""
