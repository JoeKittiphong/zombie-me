extends RefCounted

const HUMAN := preload("res://game/gameplay/ai/humans/human_behavior.gd")
var human: RefCounted

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
var perception_clock := 0.0
var perception_interval := 0.2
var movement_interval := 0.0
var accumulated_delta := 0.0
var movement_clock := 0.0
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
	movement_clock = float(seed_value%13)*0.015
	human = HUMAN.new()
	human.configure(body,scene,origin,body.human_profile,seed_value)

func tick(delta: float) -> void:
	accumulated_delta += delta
	movement_clock -= delta
	if movement_interval > 0.0 and movement_clock > 0.0:
		return
	var step_delta := accumulated_delta
	accumulated_delta = 0.0
	movement_clock = movement_clock+movement_interval if movement_interval > 0.0 else 0.0
	step(step_delta)

func step(delta: float) -> void:
	actor.tick_conditions(delta)
	human.combat.tick(delta)
	perception_clock -= delta
	if actor.busy or actor.turning or actor.dead or actor.stun_time > 0.0:
		mode = "recovering"
		has_waypoint = false
		pause = 0
		return
	if actor.zombie:
		if perception_clock <= 0 or (is_instance_valid(cached_target) and not cached_target.can_be_hunted()):
			cached_target = world.nearest_human(actor.position,hunt_radius)
			perception_clock = perception_interval
		var target: CharacterBody3D = cached_target
		if is_instance_valid(target) and target.can_be_hunted():
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
	human.step(delta,perception_interval)
	mode = human.state

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

