extends RefCounted

const LOCOMOTION := preload("res://game/characters/dummy/dummy_locomotion.gd")
var locomotion := LOCOMOTION.new()

func travel(actor: CharacterBody3D, destination: Vector3, speed: float, delta: float) -> void:
	if actor.busy or actor.dead or actor.stun_time > 0.0:
		actor.velocity = Vector3.ZERO
		return
	var offset: Vector3 = destination-actor.position
	offset.y = 0
	var distance_sq := offset.length_squared()
	var moving: bool = distance_sq > 0.0144
	actor.velocity = offset*minf(speed/sqrt(distance_sq),1.0/delta) if moving else Vector3.ZERO
	actor.velocity.y = -2.0
	if actor.use_flat_movement:
		actor.position += Vector3(actor.velocity.x,0,actor.velocity.z)*delta
		actor.position.y = 0
	else:
		actor.move_and_slide()
	actor.position.x = clampf(actor.position.x,-actor.movement_bounds.x,actor.movement_bounds.x)
	actor.position.z = clampf(actor.position.z,-actor.movement_bounds.y,actor.movement_bounds.y)
	if moving:
		actor.visual.rotation.y = lerp_angle(actor.visual.rotation.y,atan2(-offset.x,-offset.z),minf(delta*10,1))
	locomotion.animate(actor,moving,speed,delta)

