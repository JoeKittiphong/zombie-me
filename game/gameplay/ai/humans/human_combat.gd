extends RefCounted

const RESEARCH := preload("res://game/gameplay/ai/humans/medical_research.gd")
var research: RefCounted
var treatment_stocked := false
var response_clock := 0.0

var actor: CharacterBody3D
var world: Node3D
var human_reference: WeakRef
var human: RefCounted:
	get: return human_reference.get_ref()
var profile: Resource
var target: CharacterBody3D
var action_target: CharacterBody3D
var cooldown := 0.0
var reload_clock := 0.0
var ammo := 0
var doses := 0
var action_clock := 0.0
var action_length := 0.0
var action_pending := false
var search_clock := 0.0

func configure(body: CharacterBody3D, scene: Node3D, controller: RefCounted) -> void:
	actor = body
	world = scene
	human_reference = weakref(controller)
	profile = body.human_profile.combat_profile
	search_clock = controller.sense_clock
	if profile != null:
		ammo = profile.magazine_size
		doses = 0 if profile.equipment == "vaccine" else profile.vaccine_doses
		if profile.equipment == "vaccine":
			research = RESEARCH.new()
			research.configure(body,scene,controller.sense_clock)
			actor.equip("sample_kit")
		else:
			actor.equip("none" if body.human_profile.role == "armed_civilian" and world.outbreak_progress.enabled else profile.equipment)

func tick(delta: float) -> void:
	if profile == null:
		return
	cooldown = maxf(cooldown-delta,0.0)
	search_clock -= delta
	if actor.dead or actor.infected or actor.grappled or world.finished:
		cancel_action()
		if research != null:
			research.cancel()
		return
	if reload_clock > 0.0:
		reload_clock = maxf(reload_clock-delta,0.0)
		if reload_clock == 0.0:
			ammo = profile.magazine_size
	if action_clock > 0.0:
		action_clock = maxf(action_clock-delta,0.0)
		actor.combat_pose = 1.0-action_clock/action_length
		if action_pending and action_clock <= profile.recovery:
			action_pending = false
			if world.combat_system.strike(actor,action_target,profile):
				if profile.equipment == "gun":
					ammo -= 1
				elif profile.equipment == "vaccine":
					doses -= 1
		if action_clock == 0.0:
			actor.combat_locked = false
			actor.combat_pose = 0.0

func step(delta: float) -> bool:
	if profile == null or not world.combat_system.enabled or world.finished or actor.dead or actor.infected:
		return false
	if profile.equipment == "vaccine":
		if not world.outbreak_progress.can_treat():
			return research.step(human,delta)
		research.cancel()
		if not treatment_stocked:
			treatment_stocked = true
			doses = profile.vaccine_doses
			actor.equip("vaccine")
		if doses <= 0:
			return false
		if search_clock <= 0.0:
			target = world.actor_grid.nearest_infected(actor.position,6.0)
			search_clock = 0.35
	else:
		if not world.outbreak_progress.can_defend(actor,human):
			response_clock = 0.0
			return false
		if profile.equipment == "gun" and actor.equipment_kind == "none":
			actor.equip("gun")
		target = human.seen_threat
		if profile.equipment == "gun" and world.outbreak_progress.enabled:
			if not is_instance_valid(target):
				response_clock = 0.0
				return false
			response_clock += delta
			if response_clock < world.outbreak_progress.settings.police_response_delay:
				human.change_state("assessing")
				actor.travel(actor.position,0.0,delta)
				human.face(target.position,delta)
				return true
	if not is_instance_valid(target) or not target.is_combat_target():
		return false
	if profile.equipment == "gun" and reload_clock > 0.0:
		human.change_state("reloading")
		human.danger_position = target.position
		human.escape_direction = (actor.position-target.position).normalized()
		human.choose_escape()
		actor.travel(human.destination,human.profile.walk_speed,delta)
		human.face(target.position,delta)
		return true
	if profile.equipment == "gun" and ammo <= 0:
		reload_clock = profile.reload_duration
		world.human_feedback.show_cue(actor,"Reloading!",false)
		return true
	human.change_state("treating" if profile.equipment == "vaccine" else "fighting")
	var distance: float = actor.position.distance_squared_to(target.position)
	if actor.combat_locked:
		actor.travel(actor.position,0.0,delta)
	elif profile.equipment == "gun" and distance < profile.preferred_distance*profile.preferred_distance:
		var away := actor.position-target.position
		away.y = 0.0
		human.stamina = maxf(human.stamina-human.profile.stamina_drain*delta,0.0)
		actor.travel(human.bounded(actor.position+away.normalized()*2.0),human.profile.run_speed if human.stamina > 0.0 else human.profile.walk_speed,delta)
	elif distance > profile.attack_range*profile.attack_range:
		actor.travel(target.position,human.profile.walk_speed,delta)
	else:
		actor.travel(actor.position,0.0,delta)
		human.stamina = minf(human.stamina+human.profile.stamina_recovery*delta,human.profile.stamina_capacity)
	var aim: Vector3 = target.position-actor.position
	actor.visual.rotation.y = atan2(-aim.x,-aim.z)
	if distance <= profile.attack_range*profile.attack_range and cooldown <= 0.0 and not actor.combat_locked:
		action_length = profile.windup+profile.recovery
		action_clock = action_length
		action_pending = true
		action_target = target
		actor.combat_locked = true
		cooldown = profile.cooldown
	return true

func cancel_action() -> void:
	action_clock = 0.0
	action_pending = false
	actor.combat_locked = false
	actor.combat_pose = 0.0
