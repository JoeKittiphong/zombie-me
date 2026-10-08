extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var world: Node3D = load("res://game/world/community/outbreak.tscn").instantiate()
	world.population = 8
	root.add_child(world)
	world.set_physics_process(false)
	world.set_process(false)
	world.player.position = Vector3(-7,0,7)
	for index in range(8):
		world.citizens[index].position = Vector3(30,0,20)
	var roles := ["bat_guard","armed_police","vaccine_medic"]
	for index in range(3):
		var actor: CharacterBody3D = world.citizens[index]
		actor.position = Vector3(-4+index*4,0,0)
		actor.human_profile = load("res://game/gameplay/ai/humans/profiles/"+roles[index]+".tres")
		world.brains[index].configure(actor,world,actor.position,731+index)
		actor.human_state = "treating" if index == 2 else "fighting"
		actor.combat_locked = true
		actor.combat_pose = 0.5
		actor.pose_equipment()
		var target: CharacterBody3D = world.citizens[index+3]
		target.position = actor.position+Vector3(0,0,-2)
		target.zombie = true
		target.infected = true
		if target.equipment != null:
			target.equipment.hide()
		target.skin.albedo_color = target.zombie_skin_color
	world.refresh_perception()
	world.camera.position = Vector3(10,10,15)
	world.camera.look_at(Vector3(0,0,-1))
	world.camera.size = 14
	await process_frame
	world.combat_effects.tracer(world.citizens[1].position+Vector3(0.4,1.2,-0.5),world.citizens[4].position+Vector3(0,1,0))
	world.combat_effects.flash(world.citizens[5].position+Vector3(0,1,0),Color("57e2d7"))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Zylaah/programmer/godot/Zobies me/combat-preview.png")
	world.queue_free()
	await process_frame
	print("Combat equipment visual captured.")
	quit()
