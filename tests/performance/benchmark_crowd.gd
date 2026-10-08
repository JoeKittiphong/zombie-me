extends SceneTree

func _initialize() -> void:
	call_deferred("run_benchmark")

func run_benchmark() -> void:
	var world := Node3D.new()
	world.set_script(load("res://tests/performance/benchmark_world.gd"))
	world.population = 1000
	root.add_child(world)
	world.set_physics_process(false)
	world.combat_system.enabled = "--combat" in OS.get_cmdline_user_args()
	world.human_feedback.enabled = "--no-feedback" not in OS.get_cmdline_user_args()
	for index in range(1000):
		var actor: CharacterBody3D = world.citizens[index]
		var pos := Vector3(-32+(index%32)*2,0,-23+int(index/32)*1.5)
		if "--dense" in OS.get_cmdline_user_args():
			pos = Vector3(-3+(index%32)*0.18,0,-3+int(index/32)*0.18)
		actor.position = pos
		actor.zombie = index%2 == 0
		actor.infected = actor.zombie
		world.brains[index].home = pos
	if "--infection-wave" in OS.get_cmdline_user_args():
		for actor in world.citizens:
			actor.zombie = false
			actor.still_duration = 0.05
			actor.convulsion_duration = 10.0
			actor.begin_bitten()
			actor.begin_incubation()
	await physics_frame
	var samples: Array[float] = []
	var long_run := "--long" in OS.get_cmdline_user_args()
	for frame in range(600 if long_run else 18):
		await physics_frame
		var start := Time.get_ticks_usec()
		world._physics_process(1.0/60)
		if not long_run or frame >= 120:
			samples.append((Time.get_ticks_usec()-start)/1000.0)
	var mean := 0.0
	for value in samples:
		mean += value
	mean /= samples.size()
	samples.sort()
	var mode := "infection wave" if "--infection-wave" in OS.get_cmdline_user_args() else "mixed actors"
	print("Crowd 1000 ",mode,": mean simulation ms=",snappedf(mean,0.01)," p95 ms=",snappedf(samples[int(samples.size()*0.95)],0.01)," (simulation timing only; excludes rendering and spawn)")
	print("Combat enabled=",world.combat_system.enabled," shots=",world.combat_system.shots," bat hits=",world.combat_system.melee_hits," cures=",world.combat_system.cures," pounces=",world.attack_count," max swarm=",world.swarm_attacks.peak_group_size)
	print("Human perception: rays=",world.human_perception.ray_count," deferred=",world.human_perception.deferred_count)
	if DisplayServer.get_name() != "headless":
		print("Graphics FPS=",Engine.get_frames_per_second()," draw calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," process ms=",Performance.get_monitor(Performance.TIME_PROCESS)*1000.0," engine physics ms=",Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	world.queue_free()
	await process_frame
	quit()
