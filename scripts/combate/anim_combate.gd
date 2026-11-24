# anim_combate.gd
# -----------------------------------------------------------------------------
# Animaciones de pelea para los muñecos de Quaternius (Punch, HitReact, Death,
# Jump, Duck). Se reproducen UNA vez y, si se pide, vuelve a otra en bucle.
#   AnimCombate.una_vez(modelo, "HitReact", "Idle")
# Devuelve la duración en segundos (0 si el modelo no tiene esa animación).
# -----------------------------------------------------------------------------
class_name AnimCombate
extends RefCounted


static func una_vez(modelo: Node3D, nombre: String, volver_a: String = "") -> float:
	if modelo == null or not is_instance_valid(modelo) or not modelo.has_meta("animaciones"):
		return 0.0
	var r: AnimationPlayer = modelo.get_meta("animaciones") as AnimationPlayer
	if r == null or not is_instance_valid(r):
		return 0.0
	var esq: Skeleton3D = Cuerpo.esqueleto(modelo)
	if esq != null and Cuerpo._simulador(esq) != null:
		return 0.0   # Está en el suelo con física: nada de animaciones.
	for candidato in Assets.nombres_anim(nombre):
		if not r.has_animation(candidato):
			continue
		var anim: Animation = r.get_animation(candidato)
		anim.loop_mode = Animation.LOOP_NONE
		r.play(candidato, 0.08)
		var dur: float = anim.length
		if volver_a != "":
			var mod: Node3D = modelo
			Cuerpo.luego(r, maxf(dur - 0.1, 0.05), func() -> void:
				if r.current_animation == candidato or not r.is_playing():
					Assets.poner_animacion(mod, volver_a))
		return dur
	return 0.0
