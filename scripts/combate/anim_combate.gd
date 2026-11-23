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
	for candidato in [nombre, "CharacterArmature|" + nombre]:
		if not r.has_animation(candidato):
			continue
		var anim: Animation = r.get_animation(candidato)
		anim.loop_mode = Animation.LOOP_NONE
		r.stop()
		r.play(candidato)
		var dur: float = anim.length
		if volver_a != "":
			r.get_tree().create_timer(dur).timeout.connect(func() -> void:
				if is_instance_valid(modelo):
					Assets.poner_animacion(modelo, volver_a))
		return dur
	return 0.0
