extends RefCounted

# One brain per citizen: no movement state shared between NPCs.
var actor: CharacterBody3D
var world: Node3D
var home: Vector3
var waypoint := Vector3.ZERO
var mode := "human"
var pause := 0.0
var stuck_time := 0.0
var last_position := Vector3.ZERO
var has_waypoint := false
var random := RandomNumberGenerator.new()
var cached_target: CharacterBody3D
var cached_threat: CharacterBody3D
var perception_clock := 0.0
var perception_interval := 0.2
var movement_interval := 0.0
var accumulated_delta := 0.0
var roam_speed := 1.15
var hunt_speed := 3.6
var hunt_radius := 6.0

func configure(body: CharacterBody3D, scene: Node3D, origin: Vector3, seed_value: int) -> void:
	actor = body
	world = scene
	home = origin
	last_position = actor.position
	random.seed = seed_value
	perception_clock = float(seed_value % 10) * 0.02

func tick(delta: float) -> void:
	accumulated_delta += delta
	if accumulated_delta < movement_interval:
		return
	var step_delta := accumulated_delta
	accumulated_delta = 0.0
	step(step_delta)

func step(delta: float) -> void:
	perception_clock -= delta
	if actor.busy or actor.turning:
		mode = "recovering"
		has_waypoint = false
		pause = 0
		return
	if actor.zombie:
		if perception_clock <= 0 or (is_instance_valid(cached_target) and (cached_target.infected or cached_target.busy)):
			cached_target = world.nearest_human(actor.position,hunt_radius)
			perception_clock = perception_interval
		var target: CharacterBody3D = cached_target
		if is_instance_valid(target) and not target.infected and not target.busy:
			mode = "hunting"
			has_waypoint = false
			actor.travel(target.position,hunt_speed,delta)
			if actor.position.distance_squared_to(target.position) < 1.0:
				world.start_pounce(actor,target)
		else:
			if mode != "roaming":
				has_waypoint = false
				pause = 0
			mode = "roaming"
			roam(delta)
		return
	mode = "human"
	if perception_clock <= 0:
		cached_threat = world.nearest_zombie(actor.position,4.0)
		perception_clock = perception_interval
	var threat: CharacterBody3D = cached_threat
	if is_instance_valid(threat) and threat.zombie:
		var away: Vector3 = actor.position-threat.position
		away.y = 0
		if away.length() < 0.1:
			away = Vector3.RIGHT
		actor.travel(actor.position+away.normalized()*2,2.0,delta)
	else:
		var index_time: float = world.elapsed+home.x*0.17
		actor.travel(home+Vector3(sin(index_time*0.5)*0.7,0,cos(index_time*0.4)*0.5),0.6,delta)

func roam(delta: float) -> void:
	if pause > 0:
		pause -= delta
		actor.travel(actor.position,0,delta)
		return
	if not has_waypoint:
		choose_waypoint()
	actor.travel(waypoint,roam_speed,delta)
	var progress: float = actor.position.distance_to(last_position)
	stuck_time = stuck_time+delta if progress < 0.01 else 0.0
	last_position = actor.position
	if actor.position.distance_squared_to(waypoint) < 0.0625:
		has_waypoint = false
		pause = random.randf_range(0.25,0.8)
	elif stuck_time >= 1.5:
		# Choose an inward waypoint instead of remaining pinned to an edge.
		has_waypoint = false
		stuck_time = 0

func choose_waypoint() -> void:
	var angle := random.randf_range(0,TAU)
	var distance := random.randf_range(3.0,7.0)
	waypoint = actor.position+Vector3(cos(angle),0,sin(angle))*distance
	waypoint.x = clampf(waypoint.x,-actor.movement_bounds.x+1,actor.movement_bounds.x-1)
	waypoint.z = clampf(waypoint.z,-actor.movement_bounds.y+1,actor.movement_bounds.y-1)
	waypoint.y = 0
	if waypoint.distance_to(actor.position) < 1:
		waypoint = actor.position.move_toward(Vector3.ZERO,4)
		waypoint.y = 0
	has_waypoint = true
	last_position = actor.position
	stuck_time = 0

