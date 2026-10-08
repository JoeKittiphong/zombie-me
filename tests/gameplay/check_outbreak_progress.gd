extends SceneTree

var world: Node3D

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	world = load("res://game/world/community/outbreak.tscn").instantiate()
	world.outbreak_pacing = world.outbreak_pacing.duplicate()
	root.add_child(world)
	world.set_physics_process(false)
	world.player.position = Vector3(30,0,20)
	var progress: RefCounted = world.outbreak_progress
	var zombie: CharacterBody3D = world.citizens[0]
	zombie.position = Vector3(0,0,-4)
	zombie.zombie = true
	zombie.infected = true
	var police: RefCounted = world.brains[6].human
	police.actor.position = Vector3.ZERO
	police.seen_threat = zombie
	police.heard_alarm = false
	police.interpret(0.2)
	assert(police.state == "suspicious" and not police.danger_confirmed)
	assert(not police.combat.step(0.1) and world.combat_system.shots == 0)
	assert(not world.combat_system.strike(police.actor,zombie,police.combat.profile))
	var victim: CharacterBody3D = world.citizens[1]
	victim.position = Vector3(0,0,-4.8)
	assert(world.swarm_attacks.join(zombie,victim))
	assert(progress.attack_victims.size() == 1 and not progress.civilians_alerted)
	police.interpret(0.2)
	assert(police.danger_confirmed)
	world.actor_grid.rebuild(world.player,world.citizens)
	world.human_perception.begin_tick()
	police.sense_clock = 0.0
	police.step(0.2,0.2)
	assert(police.seen_threat == zombie and police.state == "assessing")
	assert(police.combat.step(0.5) and police.state == "assessing" and not police.actor.combat_locked)
	assert(police.combat.step(0.5) and police.state == "assessing" and not police.actor.combat_locked)
	assert(police.combat.step(0.3) and police.actor.combat_locked)
	world.combat_system.begin_tick()
	police.combat.tick(0.2)
	assert(world.combat_system.shots == 0)
	police.combat.tick(0.16)
	assert(world.combat_system.shots == 1)
	police.combat.tick(0.4)
	police.combat.step(0.5)
	assert(not police.actor.combat_locked and world.combat_system.shots == 1)
	assert(police.combat.profile.cooldown == 2.4)
	world.swarm_attacks.stop_all()
	var civilian: RefCounted = world.brains[8].human
	civilian.actor.position = Vector3(2,0,0)
	civilian.seen_threat = zombie
	assert(civilian.actor.equipment_kind == "none")
	assert(not civilian.combat.step(0.2))
	var guard: RefCounted = world.brains[5].human
	guard.actor.position = Vector3(1,0,0)
	guard.seen_threat = zombie
	guard.danger_confirmed = true
	assert(not guard.combat.step(0.2))
	world.elapsed = 21.0
	progress.tick(0.1)
	assert(not progress.civilians_alerted)
	progress.record_attack(victim)
	assert(progress.attack_victims.size() == 1)
	progress.record_attack(world.citizens[2])
	progress.record_attack(world.citizens[3])
	progress.tick(0.1)
	assert(progress.civilians_alerted and progress.can_defend(guard.actor,guard))
	civilian.combat.step(0.2)
	assert(civilian.actor.equipment_kind == "gun")
	var medic: RefCounted = world.brains[7].human
	medic.actor.position = Vector3.ZERO
	medic.seen_threat = null
	medic.combat.research.search_clock = 0.0
	assert(medic.actor.equipment_kind == "sample_kit" and medic.combat.doses == 0)
	assert(not progress.can_treat())
	world.combat_system.begin_tick()
	assert(not world.combat_system.strike(medic.actor,zombie,medic.combat.profile))
	var second_medic: CharacterBody3D = world.citizens[15]
	var bodies: Array[CharacterBody3D] = []
	for index in range(8,13):
		var corpse: CharacterBody3D = world.citizens[index]
		corpse.zombie = true
		corpse.infected = true
		corpse.position = Vector3(0.8,0,float(index-8)*0.1)
		corpse.take_damage(100.0,Vector3.ZERO,0.0)
		bodies.append(corpse)
	world.actor_grid.rebuild(world.player,world.citizens)
	await physics_frame
	# Real medic AI claims a nearby corpse, spends time studying it, and submits once.
	assert(medic.combat.step(0.1))
	var first: CharacterBody3D = medic.combat.research.patient
	assert(is_instance_valid(first))
	assert(not progress.claim(first,second_medic))
	assert(not progress.claim(zombie,medic.actor))
	world.combat_system.begin_tick()
	medic.combat.step(5.0)
	assert(progress.researched_bodies.is_empty())
	world.combat_system.begin_tick()
	medic.combat.step(1.0)
	assert(progress.researched_bodies.size() == 1 and not progress.can_treat())
	assert(not progress.claim(first,medic.actor) and not progress.submit_sample(first,medic.actor))
	for body in bodies:
		if body == first:
			continue
		medic.combat.research.search_clock = 0.0
		world.combat_system.begin_tick()
		assert(medic.combat.step(0.1))
		world.combat_system.begin_tick()
		medic.combat.step(6.0)
	assert(progress.researched_bodies.size() == 5)
	assert(progress.production_clock == 12.0 and not progress.can_treat() and medic.combat.doses == 0)
	progress.tick(11.0)
	assert(not progress.can_treat())
	progress.tick(1.0)
	assert(progress.can_treat())
	medic.combat.step(0.016)
	assert(medic.actor.equipment_kind == "vaccine" and medic.combat.doses == 3)
	medic.combat.doses = 0
	medic.combat.step(0.016)
	assert(medic.combat.doses == 0)
	# Infection cancels work and makes the corpse available to another researcher.
	var spare: CharacterBody3D = world.citizens[13]
	spare.zombie = true
	spare.infected = true
	spare.take_damage(100.0,Vector3.ZERO,0.0)
	assert(progress.claim(spare,medic.actor))
	medic.combat.research.patient = spare
	medic.actor.infected = true
	medic.combat.tick(0.1)
	assert(progress.claim(spare,second_medic))
	civilian = null
	police = null
	guard = null
	medic = null
	progress = null
	world.queue_free()
	await process_frame
	print("Outbreak progression passed: unfamiliar body suspicion, police confirmation/aim/slow fire, delayed civilian defense, distinct corpse claims and timed research, five bodies + production before medicine, interrupted research and no dose refill.")
	quit()
