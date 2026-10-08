extends RefCounted

const COMBAT := preload("res://game/gameplay/ai/humans/human_combat.gd")
var combat := COMBAT.new()

# Owns one human's memory and state. Perception and feedback remain crowd services.
var actor: CharacterBody3D
var world: Node3D
var profile: Resource
var home: Vector3
var random := RandomNumberGenerator.new()
var state := "wandering"
var state_time := 0.0
var suspicion := 0.0
var stamina := 5.0
var evidence_age := 100.0
var sample_age := 0.0
var sense_clock := 0.0
var danger_confirmed := false
var seen_threat: CharacterBody3D
var smell_intensity := 0.0
var heard_alarm := false
var heard_noise := false
var sense_deferred := false
var odor_position := Vector3.ZERO
var interest_position := Vector3.ZERO
var noise_position := Vector3.ZERO
var danger_position := Vector3.ZERO
var escape_direction := Vector3.ZERO
var destination := Vector3.ZERO
var has_destination := false
var pause := 0.0
var escape_clock := 0.0
var alarm_clock := 0.0
var boundary_memory := 0.0
var boundary_direction := Vector3.ZERO

func configure(body: CharacterBody3D, scene: Node3D, origin: Vector3, parameters: Resource, seed_value: int) -> void:
	actor = body
	actor.set_meta("human_controller",weakref(self))
	world = scene
	home = origin
	profile = parameters
	random.seed = seed_value+1741
	sense_clock = float(seed_value%17)*0.017
	stamina = profile.stamina_capacity
	combat.configure(body,scene,self)

func step(delta: float, perception_interval: float) -> void:
	state_time += delta
	evidence_age += delta
	sample_age += delta
	sense_clock -= delta
	alarm_clock -= delta
	boundary_memory -= delta
	if sense_clock <= 0.0:
		world.human_perception.sample(self)
		interpret(sample_age)
		sample_age = 0.0
		sense_clock = perception_interval
		if sense_deferred:
			sense_clock = minf(sense_clock,0.08)
	if combat.step(delta):
		actor.human_state = state
		return
	if state in ["fighting","reloading","treating","researching","assessing"]:
		change_state("fleeing" if evidence_age < profile.danger_memory else "wandering")
	if state == "startled":
		actor.travel(actor.position,0.0,delta)
		face(danger_position,delta)
		if state_time >= profile.reaction_delay:
			change_state("fleeing")
	elif state == "fleeing" or state == "catching_breath":
		flee(delta)
	elif state == "suspicious":
		actor.travel(actor.position,0.0,delta)
		face(interest_position,delta)
		stamina = minf(stamina+profile.stamina_recovery*delta,profile.stamina_capacity)
		if state_time > 0.8 and profile.investigates_smell:
			change_state("investigating")
		elif evidence_age > 2.5:
			change_state("wandering")
	elif state == "investigating":
		var point := interest_position
		if actor.position.distance_squared_to(point) > 4.0:
			actor.travel(point,profile.walk_speed*0.7,delta)
		else:
			actor.travel(actor.position,0.0,delta)
			face(point,delta)
		if evidence_age > 3.5:
			change_state("wandering")
	else:
		wander(delta)
	actor.human_state = state

func interpret(delta: float) -> void:
	if not world.outbreak_progress.recognizes(self):
		if is_instance_valid(seen_threat) or smell_intensity > 0.0 or heard_noise:
			interest_position = seen_threat.position if is_instance_valid(seen_threat) else (odor_position if smell_intensity > 0.0 else noise_position)
			evidence_age = 0.0
			suspicion = minf(suspicion+delta*0.4,0.65)
			if state == "wandering" or (is_instance_valid(seen_threat) and state != "researching"):
				change_state("suspicious")
		else:
			suspicion = maxf(suspicion-delta*0.2,0.0)
		return
	if is_instance_valid(seen_threat):
		danger_position = seen_threat.position
		escape_direction = (actor.position-danger_position).normalized()
		evidence_age = 0.0
		suspicion = 1.0
		if state not in ["startled","fleeing","catching_breath","fighting","reloading","treating","assessing"]:
			change_state("startled")
		if alarm_clock <= 0.0:
			world.human_perception.alarm(actor,world)
			alarm_clock = 8.0
		return
	if heard_alarm or (profile.flees_from_smell and smell_intensity > 0.08):
		danger_position = odor_position if smell_intensity > 0.08 else noise_position
		evidence_age = 0.0
		suspicion = 1.0
		if state not in ["startled","fleeing","catching_breath","fighting","reloading","treating","assessing"]:
			change_state("startled")
		return
	if smell_intensity > 0.0 or heard_noise:
		interest_position = odor_position if smell_intensity > 0.0 else noise_position
		evidence_age = 0.0
		suspicion = minf(suspicion+delta*(profile.smell_suspicion_rate*smell_intensity+(0.3 if heard_noise else 0.0)),1.0)
		if suspicion >= 0.2 and state == "wandering":
			change_state("suspicious")
		if suspicion >= 0.9 and not profile.investigates_smell and state in ["suspicious","investigating"]:
			danger_position = odor_position if smell_intensity > 0.0 else noise_position
			change_state("startled")
	elif not sense_deferred:
		suspicion = maxf(suspicion-delta*0.2,0.0)

func change_state(next: String) -> void:
	if state == next:
		return
	state = next
	state_time = 0.0
	has_destination = false
	pause = 0.0
	escape_clock = 0.0
	actor.human_state = state
	if state == "suspicious":
		world.human_feedback.show_cue(actor,"What's that smell?" if smell_intensity > 0 else "What was that?",false)
	elif state == "startled":
		world.human_feedback.show_cue(actor,"!",false)

func face(point: Vector3, delta: float) -> void:
	var offset := point-actor.position
	if offset.length_squared() > 0.01:
		actor.visual.rotation.y = lerp_angle(actor.visual.rotation.y,atan2(-offset.x,-offset.z),minf(delta*5.0,1.0))

func flee(delta: float) -> void:
	if evidence_age > profile.danger_memory and suspicion < 0.7:
		change_state("wandering")
		return
	if state == "fleeing":
		stamina = maxf(stamina-profile.stamina_drain*delta,0.0)
		if stamina <= 0.0:
			change_state("catching_breath")
	else:
		stamina = minf(stamina+profile.stamina_recovery*delta,profile.stamina_capacity)
		if stamina >= profile.stamina_capacity*0.45:
			change_state("fleeing")
	escape_clock -= delta
	if not has_destination or escape_clock <= 0.0 or actor.position.distance_squared_to(destination) < 0.64:
		choose_escape()
		escape_clock = 0.35
	actor.travel(destination,profile.run_speed if state == "fleeing" else profile.walk_speed,delta)

func choose_escape() -> void:
	var away := escape_direction
	if away.length_squared() < 0.01:
		away = actor.position-danger_position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.01 else Vector3.RIGHT
	if boundary_memory > 0.0:
		away = boundary_direction
	else:
		var redirected := false
		if absf(actor.position.x) > actor.movement_bounds.x-2.0 and away.x*actor.position.x > 0.0:
			away.x = 0.0
			redirected = true
		if absf(actor.position.z) > actor.movement_bounds.y-2.0 and away.z*actor.position.z > 0.0:
			away.z = 0.0
			redirected = true
		if redirected:
			if away.length_squared() < 0.01:
				away = Vector3(-signf(actor.position.x),0,0)
			away = away.normalized()
			boundary_direction = away
			boundary_memory = 1.5
	var side := Vector3(-away.z,0,away.x)
	var best := actor.position
	var best_score := -INF
	# Tangential options prevent the old outward movement from pinning humans to boundaries.
	for index in range(5):
		var direction: Vector3
		match index:
			0: direction = away
			1: direction = (away+side*1.5).normalized()
			2: direction = (away-side*1.5).normalized()
			3: direction = side
			4: direction = -side
		var point := bounded(actor.position+direction*6.0)
		var progress := point.distance_squared_to(actor.position)
		if progress < 1.0:
			continue
		var score := point.distance_squared_to(danger_position)+progress*0.1
		if boundary_memory > 0.0:
			score += (point-actor.position).dot(boundary_direction)*20.0
		if score > best_score:
			best_score = score
			best = point
	if best_score == -INF:
		best = actor.position.move_toward(Vector3.ZERO,4.0)
	destination = best
	has_destination = true

func wander(delta: float) -> void:
	stamina = minf(stamina+profile.stamina_recovery*delta,profile.stamina_capacity)
	if pause > 0.0:
		pause -= delta
		actor.travel(actor.position,0.0,delta)
		return
	if not has_destination:
		var angle := random.randf_range(0.0,TAU)
		destination = bounded(home+Vector3(cos(angle),0,sin(angle))*random.randf_range(2.0,6.0))
		has_destination = true
	actor.travel(destination,profile.walk_speed,delta)
	if actor.position.distance_squared_to(destination) < 0.0625:
		has_destination = false
		pause = random.randf_range(0.8,2.5)

func bounded(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x,-actor.movement_bounds.x+0.8,actor.movement_bounds.x-0.8),0,clampf(point.z,-actor.movement_bounds.y+0.8,actor.movement_bounds.y-0.8))
