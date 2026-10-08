extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var world: Node3D = load("res://game/world/community/outbreak.tscn").instantiate()
	root.add_child(world)
	await create_timer(0.2).timeout
	world.player.zombie = true
	world.player.infected = true
	world.manual_grace = 100
	for actor in world.citizens:
		actor.position = Vector3(25,0,-20)
	world.refresh_perception()
	var start: Vector3 = world.player.position
	await create_timer(1.2).timeout
	assert(not world.has_move_order and world.player.position.distance_to(start) > 0.5)
	var point: Vector3 = world.player.position+Vector3(3,0,0)
	world.command_move(point)
	assert(world.has_move_order)
	world.citizens[0].position = world.player.position+Vector3(0,0,3)
	world.refresh_perception()
	await create_timer(0.9).timeout
	assert(world.has_move_order and world.player.position.distance_to(point) < 2.5)
	assert(world.hunt_target == null)
	world.citizens[0].position = Vector3(25,0,-20)
	world.refresh_perception()
	world.manual_grace = 100
	await create_timer(0.8).timeout
	assert(not world.has_move_order)
	start = world.player.position
	await create_timer(1.2).timeout
	assert(world.player.position.distance_to(start) > 0.3)
	world.player.busy = true
	start = world.player.position
	await create_timer(0.3).timeout
	assert(world.player.position == start)
	world.queue_free()
	await process_frame
	print("Player idle test passed: autonomous shuffle, click priority, resumed roaming and bite lock.")
	quit()
