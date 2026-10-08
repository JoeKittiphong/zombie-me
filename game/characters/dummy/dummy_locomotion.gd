extends RefCounted

var phase := 0.0
var sway := 0.0
var visual_clock := 0.0

func animate(actor: CharacterBody3D, moving: bool, speed: float, delta: float) -> void:
	phase += delta*speed*(2.0 if actor.zombie else 3.0)
	sway += delta*3.0
	visual_clock += delta
	if not actor.visual.visible or visual_clock < actor.animation_interval:
		return
	visual_clock = 0
	if actor.zombie:
		actor.visual.rotation.z = sin(sway)*0.045
		actor.head.rotation.x = 0.4
	var swing := sin(phase)*(0.22 if actor.zombie else 0.4) if moving else 0.0
	for index in range(actor.limbs.size()):
		actor.limbs[index].rotation.x = swing if index%2 == 0 else -swing
		if actor.zombie and index%2 == 1:
			actor.limbs[index].rotation.x -= 0.65
	actor.visual.position.y = absf(sin(phase))*0.04 if moving else 0.0


