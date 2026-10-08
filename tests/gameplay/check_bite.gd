extends SceneTree

var world: Node3D

func _initialize() -> void:
	call_deferred("verify")

func capture(name: String) -> void:
	if "--capture-preview" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Zylaah/programmer/godot/Zobies me/"+name+".png")

func verify() -> void:
	world = load("res://game/world/community/outbreak.tscn").instantiate()
	root.add_child(world)
	await create_timer(0.2).timeout
	assert(world.citizens.size() == 24)
	world.set_physics_process(false)
	world.player.zombie = true
	world.player.infected = true
	world.player.skin.albedo_color = world.player.zombie_skin_color
	world.manual_grace = 100
	var victim: CharacterBody3D = world.citizens[0]
	victim.position = world.player.position+Vector3(1.4,0,0)
	world.start_pounce(world.player,victim)
	assert(world.player.busy and victim.infection_phase == "bitten")
	world.start_pounce(world.player,victim)
	assert(world.attack_count == 1)
	var command_before: Vector3 = world.destination
	world.command_move(Vector3.ZERO)
	assert(world.destination == command_before)
	await create_timer(0.15).timeout
	assert(world.player.visual.position.y > 0.25)
	await capture("bite-jump")
	await create_timer(0.7).timeout
	assert(absf(victim.visual.rotation.x) > 1.4 and absf(world.player.visual.rotation.x) > 1.4 and world.player.busy)
	await capture("bite-ground")
	await create_timer(2.1).timeout
	assert(victim.infection_phase == "still" and victim.busy and not victim.zombie)
	assert(not world.player.busy)
	await capture("bite-still")
	await create_timer(2.8).timeout
	assert(victim.infection_phase == "convulsing" and not victim.zombie)
	await capture("bite-convulsing")
	await create_timer(2.5).timeout
	assert(victim.infection_phase == "rising" and not victim.zombie)
	assert(victim.head.rotation.x > 0.3)
	await capture("bite-rising")
	await create_timer(1.8).timeout
	assert(victim.zombie and not victim.busy and not victim.turning)
	assert(victim.skin.albedo_color.is_equal_approx(victim.zombie_skin_color))
	var old_position := victim.position
	victim.travel(victim.position+Vector3(1,0,0),1.0,0.1)
	assert(victim.position != old_position)
	await capture("bite-zombie")
	world.command_move(Vector3(34,0,24))
	assert(world.destination.x > 10 and world.destination.z > 7)
	world.start_pounce(world.player,world.citizens[2])
	assert(world.player.busy)
	world.queue_free()
	await process_frame
	print("Bite test passed: 24 citizens, jump, paired knockdown, lockout, stillness, convulsion, rising and zombie movement.")
	quit()



