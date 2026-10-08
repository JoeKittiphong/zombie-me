extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var world: Node3D = load("res://game/world/community/outbreak.tscn").instantiate()
	root.add_child(world)
	await create_timer(0.2).timeout
	world.set_physics_process(false)
	world.player.position = Vector3(-30,0,20)
	for index in range(world.citizens.size()):
		world.citizens[index].position = Vector3(-25+index*0.3,0,-20)
	var actor: CharacterBody3D = world.citizens[0]
	var brain: RefCounted = world.brains[0]
	actor.position = Vector3.ZERO
	actor.still_duration = 0.05
	actor.convulsion_duration = 0.05
	actor.rise_duration = 0.05
	actor.begin_bitten()
	actor.begin_incubation()
	await create_timer(0.3).timeout
	assert(actor.zombie and not actor.busy)
	world.refresh_perception()
	brain.perception_clock = 0.0
	var start := actor.position
	for step in range(90):
		await physics_frame
		brain.step(1.0/60)
	assert(brain.mode == "roaming" and actor.position.distance_to(start) > 1.0)
	assert(actor.head.rotation.x > 0.3 and actor.motor.locomotion.phase > 0)
	var victim: CharacterBody3D = world.citizens[1]
	victim.position = actor.position+Vector3(3,0,0)
	world.refresh_perception()
	brain.perception_clock = 0.0
	brain.step(1.0/60)
	assert(brain.mode == "hunting")
	victim.infected = true
	brain.step(1.0/60)
	assert(brain.mode == "roaming")
	actor.busy = true
	start = actor.position
	for step in range(15):
		await physics_frame
		brain.step(1.0/60)
	assert(actor.position == start and brain.mode == "recovering")
	actor.busy = false
	actor.position = Vector3(35,0,25)
	brain.has_waypoint = false
	brain.mode = "recovering"
	for step in range(90):
		await physics_frame
		brain.step(1.0/60)
	assert(actor.position.x < 34.8 and actor.position.z < 24.8)
	world.finished = true
	start = actor.position
	for step in range(90):
		await physics_frame
		world._physics_process(1.0/60)
	assert(actor.position.distance_to(start) > 0.5)
	world.queue_free()
	await process_frame
	print("Zombie AI passed: movement after infection, roaming, target detection, target loss, busy lock, edge recovery and post-round walking.")
	quit()
