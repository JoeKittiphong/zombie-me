extends SceneTree

func _initialize() -> void:
	call_deferred("run_benchmark")

func run_benchmark() -> void:
	var world := Node3D.new()
	world.set_script(load("res://tests/performance/benchmark_world.gd"))
	world.population = 1000
	root.add_child(world)
	world.set_physics_process(false)
	for index in range(1000):
		var actor: CharacterBody3D = world.citizens[index]
		var pos := Vector3(-32+(index%32)*2,0,-23+int(index/32)*1.5)
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
	for frame in range(180 if long_run else 18):
		await physics_frame
		var start := Time.get_ticks_usec()
		world._physics_process(1.0/60)
		if not long_run or frame >= 30:
			samples.append((Time.get_ticks_usec()-start)/1000.0)
	var mean := 0.0
	for value in samples:
		mean += value
	mean /= samples.size()
	samples.sort()
	var mode := "infection wave" if "--infection-wave" in OS.get_cmdline_user_args() else "mixed actors"
	print("Crowd 1000 ",mode,": mean simulation ms=",snappedf(mean,0.01)," p95 ms=",snappedf(samples[int(samples.size()*0.95)],0.01)," (simulation timing only; attacks disabled; excludes rendering and spawn)")
	if DisplayServer.get_name() != "headless":
		print("Graphics FPS=",Engine.get_frames_per_second()," draw calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	world.queue_free()
	await process_frame
	quit()
