extends SceneTree

var world: Node3D
var actor: CharacterBody3D
var zombie: CharacterBody3D
var human: RefCounted

func _initialize() -> void:
	call_deferred("verify")

func reset(role: String, threat := Vector3(0,0,-4)) -> void:
	actor.position = Vector3.ZERO
	actor.visual.rotation = Vector3.ZERO
	actor.busy = false
	actor.zombie = false
	actor.infected = false
	zombie.position = threat
	zombie.zombie = true
	zombie.infected = true
	zombie.busy = true
	zombie.odor_strength = 1.0
	zombie.noise_strength = 0.0
	actor.human_profile = load("res://game/gameplay/ai/humans/profiles/"+role+".tres")
	world.brains[0].configure(actor,world,Vector3.ZERO,731)
	human = world.brains[0].human
	human.sense_clock = 0.0
	world.human_perception.cues.clear()
	world.human_perception.last_alarm_time = -100.0
	world.refresh_perception()

func advance(seconds: float) -> void:
	for index in range(ceili(seconds/0.05)):
		world.elapsed += 0.05
		world.human_perception.begin_tick()
		human.step(0.05,0.2)

func sample() -> void:
	world.human_perception.begin_tick()
	world.human_perception.sample(human)

func verify() -> void:
	world = Node3D.new()
	world.set_script(load("res://tests/performance/benchmark_world.gd"))
	world.population = 2
	root.add_child(world)
	world.set_physics_process(false)
	world.outbreak_progress.enabled = false
	world.player.position = Vector3(-30,0,20)
	actor = world.citizens[0]
	zombie = world.citizens[1]
	await physics_frame
	reset("civilian")
	zombie.zombie = false
	world.refresh_perception()
	advance(2.0)
	assert(human.state == "wandering" and actor.position.length() > 0.5)
	reset("civilian",Vector3(0,0,-10))
	sample()
	assert(human.seen_threat == null)
	reset("police",Vector3(0,0,-10))
	sample()
	assert(human.seen_threat == zombie)
	reset("civilian",Vector3(0,0,4))
	zombie.odor_strength = 0.0
	sample()
	assert(human.seen_threat == null)
	actor.visual.rotation.y = PI
	sample()
	assert(human.seen_threat == zombie)
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	wall.collision_mask = 0
	wall.position = Vector3(0,1.5,-2)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4,3,0.4)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	reset("doctor")
	sample()
	assert(human.seen_threat == null and human.smell_intensity > 0.0)
	advance(2.0)
	assert(human.state == "investigating" and actor.position.z < -0.1)
	reset("timid")
	advance(1.0)
	assert(human.state == "fleeing" and actor.position.z > 1.0)
	wall.queue_free()
	await physics_frame
	await physics_frame
	reset("civilian")
	human.step(0.05,0.2)
	assert(human.state == "startled" and world.human_perception.cues.size() == 1)
	var listener: CharacterBody3D = world.make_actor(Vector3(6,0,0),Color.WHITE)
	listener.visual.rotation.y = -PI/2
	var listener_brain: RefCounted = load("res://game/gameplay/ai/citizen_brain.gd").new()
	listener_brain.configure(listener,world,listener.position,743)
	listener_brain.human.sense_clock = 0.0
	zombie.odor_strength = 0.0
	listener_brain.human.step(0.05,0.2)
	assert(listener_brain.human.heard_alarm and listener_brain.human.state == "startled")
	assert(world.human_perception.cues.size() == 1) # Hearing alone must not amplify alarm chains.
	advance(1.0)
	assert(human.state == "fleeing" and actor.position.z > 0.5)
	human.stamina = 0.01
	human.step(0.05,0.2)
	assert(human.state == "catching_breath")
	advance(2.0)
	assert(human.stamina > 0.0)
	zombie.zombie = false
	world.human_perception.cues.clear()
	world.refresh_perception()
	advance(10.0)
	assert(human.state == "wandering" and human.suspicion < 0.2)
	reset("civilian")
	actor.position = Vector3(34,0,24)
	human.state = "fleeing"
	human.danger_position = Vector3(30,0,20)
	human.escape_direction = Vector3(1,0,1).normalized()
	human.suspicion = 1.0
	human.evidence_age = 0.0
	human.sense_clock = 100.0
	var start: Vector3 = actor.position
	advance(1.0)
	assert(actor.position.distance_to(start) > 1.0 and actor.position.x <= 35 and actor.position.z <= 25)
	reset("civilian")
	world.human_perception.rays_left = 0
	world.human_perception.sample(human)
	assert(human.sense_deferred and human.seen_threat == null)
	world.human_perception.cues.clear()
	zombie.odor_strength = 0.0
	zombie.position = Vector3(0,0,-3.5)
	world.refresh_perception()
	zombie.noise_strength = 1.0
	zombie.busy = true
	actor.visual.rotation.y = PI
	sample()
	assert(human.heard_noise and not human.heard_alarm and human.seen_threat == null)
	world.queue_free()
	await process_frame
	print("Human behavior passed: daily wander, varied sight, view cone, wall occlusion, smell investigation, timid flight, startle, shared alarm, stamina recovery, calm return, edge escape, ray budget and hearing.")
	quit()
