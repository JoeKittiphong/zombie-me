extends RefCounted

# Shared synchronous service: one reusable candidate buffer and ray query for the crowd.
const MAX_RAYS_PER_TICK := 48
const MAX_CUES := 24
var candidates: Array[CharacterBody3D] = []
var cues: Array[Dictionary] = []
var ray_query := PhysicsRayQueryParameters3D.new()
var rays_left := MAX_RAYS_PER_TICK
var ray_count := 0
var deferred_count := 0
var last_alarm_time := -100.0

func begin_tick() -> void:
	rays_left = MAX_RAYS_PER_TICK

func emit_cue(pos: Vector3, now: float, radius: float, alarming: bool) -> void:
	if cues.size() >= MAX_CUES:
		cues.pop_front()
	cues.append({"position": pos, "expires": now+1.5, "radius": radius, "alarming": alarming})

func alarm(body: CharacterBody3D, world: Node3D) -> void:
	# Prevent a thousand simultaneously frightened people allocating audio/events.
	if world.elapsed-last_alarm_time < 0.4:
		return
	last_alarm_time = world.elapsed
	emit_cue(body.position,world.elapsed,12.0,true)
	world.human_feedback.show_cue(body,body.human_profile.alarm_line,true)
	world.human_alerted.emit(body)

func sample(human: RefCounted) -> void:
	var body: CharacterBody3D = human.actor
	var world: Node3D = human.world
	var profile: Resource = human.profile
	human.seen_threat = null
	human.smell_intensity = 0.0
	human.heard_alarm = false
	human.heard_noise = false
	human.sense_deferred = false
	var radius: float = maxf(profile.vision_range,maxf(profile.smell_range*world.actor_grid.maximum_odor_strength,profile.hearing_range*0.4*world.actor_grid.maximum_noise_strength))
	world.actor_grid.collect_zombies(body.position,radius,candidates)
	var forward: Vector3 = -body.visual.basis.z
	forward.y = 0
	var cone: float = cos(deg_to_rad(profile.vision_half_angle))
	var first: CharacterBody3D
	var second: CharacterBody3D
	var third: CharacterBody3D
	var d1 := INF
	var d2 := INF
	var d3 := INF
	var odor_pos := Vector3.ZERO
	var escape_sum := Vector3.ZERO
	for zombie in candidates:
		var offset: Vector3 = zombie.position-body.position
		offset.y = 0
		var distance_sq := offset.length_squared()
		var distance := sqrt(distance_sq)
		var odor_radius: float = profile.smell_range*clampf(zombie.odor_strength,0.0,2.0)
		if odor_radius > 0.0 and distance < odor_radius:
			var intensity := 1.0-distance/odor_radius
			if intensity > human.smell_intensity:
				human.smell_intensity = intensity
				odor_pos = zombie.position
		if distance_sq < 100.0:
			escape_sum -= offset/maxf(distance_sq,0.25)
		if distance < profile.hearing_range*0.4*zombie.noise_strength and (zombie.busy or Vector2(zombie.velocity.x,zombie.velocity.z).length_squared() > 0.25):
			human.heard_noise = true
			human.noise_position = zombie.position
		if distance_sq > profile.vision_range*profile.vision_range:
			continue
		# Very close bodies are noticed even just outside the view cone.
		if distance > 1.2 and forward.dot(offset) < cone*distance:
			continue
		if distance_sq < d1:
			third = second
			d3 = d2
			second = first
			d2 = d1
			first = zombie
			d1 = distance_sq
		elif distance_sq < d2:
			third = second
			d3 = d2
			second = zombie
			d2 = distance_sq
		elif distance_sq < d3:
			third = zombie
			d3 = distance_sq
	# At most three occlusion rays per sample; retain uncertainty if the shared budget runs out.
	if is_instance_valid(first) and visible(body,first,world,human):
		human.seen_threat = first
	elif is_instance_valid(second) and visible(body,second,world,human):
		human.seen_threat = second
	elif is_instance_valid(third) and visible(body,third,world,human):
		human.seen_threat = third
	if human.smell_intensity > 0.0:
		human.odor_position = odor_pos
	if escape_sum.length_squared() > 0.001:
		human.escape_direction = escape_sum.normalized()
	for index in range(cues.size()-1,-1,-1):
		var cue: Dictionary = cues[index]
		if float(cue.expires) < world.elapsed:
			cues.remove_at(index)
			continue
		var audible: float = minf(profile.hearing_range,float(cue.radius))
		if body.position.distance_squared_to(cue.position) <= audible*audible:
			human.heard_alarm = human.heard_alarm or bool(cue.alarming)
			human.heard_noise = true
			human.noise_position = cue.position

func visible(observer: CharacterBody3D, target: CharacterBody3D, world: Node3D, human: RefCounted) -> bool:
	if rays_left <= 0:
		human.sense_deferred = true
		deferred_count += 1
		return false
	rays_left -= 1
	ray_count += 1
	ray_query.from = observer.position+Vector3(0,1.35,0)
	ray_query.to = target.position+Vector3(0,1.15,0)
	ray_query.collision_mask = world.vision_collision_mask
	return world.get_world_3d().direct_space_state.intersect_ray(ray_query).is_empty()
