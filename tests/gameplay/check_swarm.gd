extends SceneTree

var world: Node3D
var drive := false

func _initialize() -> void:
	call_deferred("verify")

func _process(delta: float) -> bool:
	if drive and is_instance_valid(world):
		world.swarm_attacks.step(delta)
	return false

func verify() -> void:
	world = load("res://game/world/community/outbreak.tscn").instantiate()
	world.population = 10
	root.add_child(world)
	world.set_physics_process(false)
	world.combat_system.enabled = false
	world.player.position = Vector3(-7,0,5)
	var victim: CharacterBody3D = world.citizens[0]
	victim.position = Vector3.ZERO
	victim.still_duration = 0.3
	victim.convulsion_duration = 0.3
	victim.rise_duration = 0.3
	var attackers: Array[CharacterBody3D] = []
	for index in range(1,10):
		var body: CharacterBody3D = world.citizens[index]
		body.zombie = true
		body.infected = true
		body.skin.albedo_color = body.zombie_skin_color
		for limb_index in [1,3]:
			body.limbs[limb_index].rotation.x = 0.65
		if body.equipment != null:
			body.equipment.hide()
		body.position = Vector3(cos(index*TAU/9),0,sin(index*TAU/9))*2.0
		attackers.append(body)
	world.refresh_perception()
	assert(world.swarm_attacks.join(attackers[0],victim))
	assert(victim.can_be_hunted() and not victim.infected)
	assert(world.nearest_human(attackers[1].position,6.0) == victim)
	for index in range(1,8):
		assert(world.swarm_attacks.join(attackers[index],victim))
	assert(not world.swarm_attacks.join(attackers[8],victim))
	assert(world.swarm_attacks.peak_group_size == 8 and world.attack_count == 8)
	var transitions := [0]
	victim.became_zombie.connect(func(): transitions[0] += 1)
	drive = true
	await create_timer(0.22).timeout
	for body in attackers.slice(0,8):
		assert(body.busy and body.visual.position.y > 0.5)
	if "--capture-preview" in OS.get_cmdline_user_args():
		world.player.position = Vector3(-2,0,2)
		world.camera.size = 13
		world.camera.position = Vector3(9,11,13)
		world.camera.look_at(Vector3.ZERO)
		world.set_process(false)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Zylaah/programmer/godot/Zobies me/swarm-preview.png")
	await create_timer(0.6).timeout
	assert(victim.infected and victim.grappled)
	for body in attackers.slice(0,8):
		assert(absf(body.visual.rotation.x) > 1.4)
	if "--capture-preview" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Zylaah/programmer/godot/Zobies me/swarm-ground-preview.png")
	await create_timer(2.6).timeout
	assert(transitions[0] == 1 and victim.zombie and not victim.busy)
	assert(world.swarm_attacks.captures.is_empty() and world.swarm_attacks.memberships.is_empty())
	for body in attackers.slice(0,8):
		assert(not body.busy and absf(body.visual.rotation.x) < 0.01)
	drive = false
	victim.begin_cure(0.05,0.0)
	await create_timer(0.1).timeout
	assert(world.swarm_attacks.join(attackers[0],victim))
	world.swarm_attacks.interrupt_actor(attackers[0])
	assert(not victim.infected and not victim.busy and not victim.grappled)
	world.swarm_attacks.step(0.7)
	assert(world.swarm_attacks.captures.is_empty())
	assert(world.swarm_attacks.join(attackers[0],victim))
	assert(world.swarm_attacks.join(attackers[1],victim))
	world.swarm_attacks.step(0.8)
	world.swarm_attacks.interrupt_actor(attackers[0])
	assert(victim.grappled)
	world.swarm_attacks.interrupt_actor(attackers[1])
	assert(victim.infection_phase == "still" and not victim.grappled)
	world.swarm_attacks.step(0.7)
	assert(world.swarm_attacks.captures.is_empty())
	victim.begin_cure(0.05,0.0)
	await create_timer(0.1).timeout
	for index in range(3):
		attackers[index].position = victim.position+Vector3(cos(index*TAU/3),0,sin(index*TAU/3))*0.9
	world.actor_grid.rebuild(world.player,world.citizens)
	for index in range(3):
		world.brains[index+1].cached_target = null
		world.brains[index+1].perception_clock = 0.0
		world.brains[index+1].step(0.016)
	assert(world.swarm_attacks.captures[victim.get_instance_id()].attackers.size() == 3)
	world.swarm_attacks.stop_all()
	world.queue_free()
	await process_frame
	print("Swarm passed: 8 shared attackers, unique landing slots, jump and prone bite, one incubation/transform, release, and interrupted rescue.")
	quit()
