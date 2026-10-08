extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var world: Node3D = load("res://game/world/community/outbreak.tscn").instantiate()
	world.population = 2
	root.add_child(world)
	world.set_physics_process(false)
	world.outbreak_progress.enabled = false
	world.player.position = Vector3(-25,0,20)
	world.player.start_mutation()
	world.serum_injected = true
	world.outbreak_started = true
	await create_timer(0.9).timeout
	var victim: CharacterBody3D = world.citizens[0]
	victim.start_mutation()
	await create_timer(0.9).timeout
	assert(world.transformed_count == 1)
	victim.begin_cure(0.05,0.1)
	await create_timer(0.1).timeout
	world.refresh_perception()
	assert(world.transformed_count == 0 and not world.finished)
	victim.tick_conditions(0.2)
	victim.start_mutation()
	await create_timer(0.9).timeout
	assert(world.transformed_count == 1 and not world.finished)
	world.player.begin_cure(0.05,8.0)
	victim.begin_cure(0.05,8.0)
	await create_timer(0.1).timeout
	world.refresh_perception()
	assert(world.finished and world.transformed_count == 0)
	assert(world.status.text == "The outbreak was contained.")
	world._physics_process(10.0)
	assert(not world.player.infected)
	world.queue_free()
	await process_frame
	print("Cure round passed: count rollback, reinfection, no early vaccine loss, all cured loss, and no automatic serum reinjection.")
	quit()
