# arboles_ia.gd
# -----------------------------------------------------------------------------
# Los árboles de comportamiento de cada tipo de personaje. Se leen de arriba abajo: lo de
# arriba tiene prioridad (un coche que te va a atropellar importa más que charlar).
#
# PEATÓN
#   1. ¿Me va a pillar un coche?        -> salto a un lado (o me quedo clavado si soy torpe)
#   2. ¿Hay una amenaza? (me han pegado, disparos, me apuntan, te ven con estrellas...)
#        elige la MEJOR reacción según su carácter y emociones:
#        huir · pelear a puñetazos · sacar la pistola · cubrirse agachado · suplicar (atraco)
#        · alejarse y llamar a la policía
#   3. ¿Ha pasado algo cerca? (herido, cadáver, pelea, atropello)
#        socorrer al herido · acercarse a mirar (curiosos) · alejarse
#   4. Social: quejarse si le empujas · apartarse si llevas un arma a la vista · saludarte ·
#      pararse a charlar con otro peatón · acompañar a su pareja
#   5. Si estaba fuera de su acera, volver a ella. Si no, pasear (la rutina de VidaUrbana:
#      aceras, pasos de cebra, semáforos), esquivando a los demás.
#
# VECINO (persona dentro de una casa, despierta)
#   1. Amenaza (el intruso): huir por la puerta · pelear (puños u objeto) · disparar ·
#      esconderse en otra habitación y llamar · suplicar si le apuntas · cubrirse
#   2. Rutina: ir de una habitación a otra y quedarse un rato (cocina, salón, dormitorio...)
# -----------------------------------------------------------------------------
class_name ArbolesIA
extends RefCounted

static func construir(tipo: String) -> ArbolIA.Nodo:
	if tipo == "vecino":
		return _vecino()
	return _peaton()


static func _reaccion_amenaza(con_llamar: bool, con_esconderse: bool) -> ArbolIA.Nodo:
	var opciones: Array = [
		[func(p, _bb): return p.p_huir(),
				ArbolIA.hacer("huir", func(p, bb, d): return p.a_huir(bb, d))],
		[func(p, _bb): return p.p_pelear(),
				ArbolIA.hacer("pelear", func(p, bb, d): return p.a_pelear(bb, d))],
		[func(p, _bb): return p.p_disparar(),
				ArbolIA.hacer("disparar", func(p, bb, d): return p.a_disparar(bb, d), func(p, bb): p.cortar_anim(bb))],
		[func(p, _bb): return p.p_cubrirse(),
				ArbolIA.hacer("cubrirse", func(p, bb, d): return p.a_cubrirse(bb, d), func(p, bb): p.cortar_anim(bb))],
		[func(p, _bb): return p.p_suplicar(),
				ArbolIA.hacer("suplicar", func(p, bb, d): return p.a_suplicar(bb, d), func(p, bb): p.cortar_anim(bb))],
	]
	if con_llamar:
		opciones.append([func(p, _bb): return p.p_llamar(),
				ArbolIA.hacer("llamar", func(p, bb, d): return p.a_llamar(bb, d), func(p, bb): p.cortar_anim(bb))])
	if con_esconderse:
		opciones.append([func(p, _bb): return p.p_esconderse(),
				ArbolIA.hacer("esconderse", func(p, bb, d): return p.a_esconderse(bb, d), func(p, bb): p.cortar_escondite(bb))])
	return ArbolIA.utilidad("reaccion", opciones, 0.2)


static func _peaton() -> ArbolIA.Nodo:
	return ArbolIA.selector("peaton", [
		ArbolIA.secuencia("coche", [
			ArbolIA.si("coche_encima", func(p, _bb): return p.hay_coche_encima()),
			ArbolIA.hacer("esquivar_coche", func(p, bb, d): return p.a_saltar_aparte(bb, d)),
		]),
		ArbolIA.secuencia("amenaza", [
			ArbolIA.si("hay_amenaza", func(p, _bb): return p.hay_amenaza()),
			_reaccion_amenaza(true, false),
		]),
		ArbolIA.secuencia("incidente", [
			ArbolIA.si("hay_incidente", func(p, _bb): return p.hay_incidente()),
			ArbolIA.utilidad("ante_incidente", [
				[func(p, _bb): return p.p_socorrer(),
						ArbolIA.hacer("socorrer", func(p, bb, d): return p.a_socorrer(bb, d), func(p, bb): p.cortar_socorro(bb))],
				[func(p, _bb): return p.p_mirar(),
						ArbolIA.hacer("mirar", func(p, bb, d): return p.a_mirar(bb, d))],
				[func(p, _bb): return p.p_alejarse(),
						ArbolIA.hacer("alejarse", func(p, bb, d): return p.a_alejarse(bb, d))],
			]),
		]),
		ArbolIA.secuencia("empujon", [
			ArbolIA.si("empujado", func(p, _bb): return p.empujado),
			ArbolIA.enfriar(4.0, ArbolIA.hacer("quejarse", func(p, bb, d): return p.a_quejarse(bb, d))),
		]),
		ArbolIA.secuencia("arma_cerca", [
			ArbolIA.si("nervioso", func(p, _bb): return p.quiere_nervioso()),
			ArbolIA.hacer("nervioso", func(p, bb, d): return p.a_nervioso(bb, d)),
		]),
		ArbolIA.secuencia("acompanar", [
			ArbolIA.si("tiene_lider", func(p, _bb): return p.acompana()),
			ArbolIA.hacer("acompanar", func(p, bb, d): return p.a_acompanar(bb, d)),
		]),
		ArbolIA.enfriar(30.0, ArbolIA.secuencia("saludo", [
			ArbolIA.si("quiere_saludar", func(p, _bb): return p.quiere_saludar()),
			ArbolIA.quiza(0.35, ArbolIA.hacer("saludar", func(p, bb, d): return p.a_saludar(bb, d)), 12.0),
		])),
		ArbolIA.secuencia("charla", [
			ArbolIA.si("charla_libre", func(p, bb): return float(bb.get("reloj", 0.0)) > float(bb.get("charla_enfr", 0.0))),
			ArbolIA.si("busca_charla", func(p, _bb): return p.busca_charla()),
			ArbolIA.hacer("charlar", func(p, bb, d): return p.a_charlar(bb, d), func(p, bb): p.cortar_charla(bb)),
		]),
		ArbolIA.secuencia("volver", [
			ArbolIA.si("fuera_de_rutina", func(p, _bb): return p.fuera_de_rutina()),
			ArbolIA.hacer("volver", func(p, bb, d): return p.a_volver(bb, d)),
		]),
		ArbolIA.hacer("pasear", func(p, bb, d): return p.a_pasear(bb, d)),
	])


static func _vecino() -> ArbolIA.Nodo:
	return ArbolIA.selector("vecino", [
		ArbolIA.secuencia("amenaza", [
			ArbolIA.si("hay_amenaza", func(p, _bb): return p.hay_amenaza()),
			_reaccion_amenaza(false, true),
		]),
		ArbolIA.secuencia("incidente", [
			ArbolIA.si("hay_incidente", func(p, _bb): return p.hay_incidente() and p.herido != null),
			ArbolIA.hacer("socorrer", func(p, bb, d): return p.a_socorrer(bb, d), func(p, bb): p.cortar_socorro(bb)),
		]),
		ArbolIA.hacer("rutina_casa", func(p, bb, d): return p.a_rutina_casa(bb, d)),
	])
