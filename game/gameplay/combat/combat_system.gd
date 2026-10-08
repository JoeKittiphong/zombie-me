extends RefCounted

const MAX_ACTION_RAYS := 24
var world: Node3D
var enabled := true
var rays_left := MAX_ACTION_RAYS
var candidates: Array[CharacterBody3D] = []
var ray_query := PhysicsRayQueryParameters3D.new()
var shots := 0
var melee_hits := 0
var cures := 0

func configure(scene: Node3D) -> void:
	world = scene

func begin_tick() -> void:
	rays_left = MAX_ACTION_RAYS

func clear_line(source: CharacterBody3D, target: CharacterBody3D) -> bool:
	if rays_left <= 0:
		return false
	rays_left -= 1
	ray_query.from = source.position+Vector3(0,1.2,0)
	ray_query.to = target.position+Vector3(0,0.9,0)
	ray_query.collision_mask = world.vision_collision_mask
	return world.get_world_3d().direct_space_state.intersect_ray(ray_query).is_empty()

func strike(source: CharacterBody3D, target: CharacterBody3D, profile: Resource) -> bool:
	if not enabled or world.finished or not is_instance_valid(target) or not target.is_combat_target() or source.infected or source.dead:
		return false
	if profile.equipment == "vaccine" and not world.outbreak_progress.can_treat():
		return false
	if profile.equipment != "vaccine" and world.outbreak_progress.enabled:
		var controller_reference: WeakRef = source.get_meta("human_controller",null)
		if controller_reference == null or controller_reference.get_ref() == null:
			return false
		var controller: RefCounted = controller_reference.get_ref()
		if not world.outbreak_progress.can_defend(source,controller):
			return false
	if source.position.distance_squared_to(target.position) > pow(profile.attack_range+0.2,2) or not clear_line(source,target):
		return false
	if profile.equipment == "vaccine":
		if not target.can_be_cured():
			return false
		world.swarm_attacks.interrupt_actor(target)
		target.begin_cure(profile.cure_duration,profile.immunity_duration)
		world.combat_effects.flash(target.position+Vector3(0,1,0),Color("57e2d7"))
		world.human_feedback.show_cue(source,"Vaccine administered!",false)
		cures += 1
		return true
	if not target.zombie:
		return false
	if profile.equipment == "gun":
		apply_hit(source,target,profile)
		world.combat_effects.tracer(source.position+Vector3(0,1.2,0),target.position+Vector3(0,0.8,0))
		world.human_perception.emit_cue(source.position,world.elapsed,14.0,true)
		shots += 1
		return true
	apply_hit(source,target,profile)
	world.actor_grid.collect_zombies(source.position,profile.attack_range,candidates)
	var forward := (target.position-source.position).normalized()
	var hits := 1
	for body in candidates:
		if body == target or not body.is_combat_target() or not body.zombie:
			continue
		var offset: Vector3 = body.position-source.position
		if offset.length_squared() < profile.attack_range*profile.attack_range and forward.dot(offset.normalized()) > 0.25 and clear_line(source,body):
			apply_hit(source,body,profile)
			hits += 1
			if hits >= 3:
				break
	melee_hits += hits
	return true

func apply_hit(source: CharacterBody3D, target: CharacterBody3D, profile: Resource) -> void:
	world.swarm_attacks.interrupt_actor(target)
	var away := target.position-source.position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.01 else Vector3.RIGHT
	target.take_damage(profile.damage,away*profile.knockback,profile.stun_duration)
	world.combat_effects.flash(target.position+Vector3(0,0.8,0),Color("f59162"))
