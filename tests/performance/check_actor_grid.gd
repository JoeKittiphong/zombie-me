extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var world := Node3D.new()
	world.set_script(load("res://tests/performance/benchmark_world.gd"))
	world.population = 1000
	root.add_child(world)
	world.set_physics_process(false)
	world.player.zombie = true
	world.player.infected = true
	for index in range(world.citizens.size()):
		world.citizens[index].zombie = index%2 == 0
		world.citizens[index].infected = index%2 == 0
	world.refresh_perception()
	var random := RandomNumberGenerator.new()
	random.seed = 42071
	for sample in range(100):
		var pos := Vector3(random.randf_range(-34,34),0,random.randf_range(-24,24))
		for zombies in [true,false]:
			var actual: CharacterBody3D = world.actor_grid.nearest(pos,6,zombies)
			var best: CharacterBody3D
			var distance := 36.0
			for actor in [world.player]+world.citizens:
				if actor.zombie != zombies or (not zombies and (actor.infected or actor.busy)):
					continue
				var candidate: float = pos.distance_squared_to(actor.position)
				if candidate < distance:
					distance = candidate
					best = actor
			assert(actual == best)
	var detailed := 0
	for actor in world.citizens:
		if actor.detailed_visual:
			detailed += 1
	assert(detailed <= world.detailed_actor_budget and world.crowd_visuals.multimesh.instance_count == 1000)
	assert(world.actor_grid.candidate_checks < 200000)
	print("Grid correctness passed: 200 queries match brute-force, bounded detail budget, 1000 proxy slots. Candidate checks=",world.actor_grid.candidate_checks)
	var distant: CharacterBody3D
	for actor in world.citizens:
		if not actor.detailed_visual:
			distant = actor
			break
	assert(is_instance_valid(distant.model) and distant.model.get_parent() == null)
	world.player.position = distant.position
	world.refresh_perception()
	assert(distant.detailed_visual and distant.model.get_parent() == distant.visual)
	for index in range(6):
		world.player.position = Vector3(30 if index%2 == 0 else -30,0,20 if index%2 == 0 else -20)
		world.refresh_perception()
		for actor in world.citizens:
			assert(actor.model.get_parent() == actor.visual if actor.detailed_visual else actor.model.get_parent() == null)
	print("Crowd GLB LOD passed: detached models restore and cycle without duplicate children.")
	world.queue_free()
	await process_frame
	quit()
