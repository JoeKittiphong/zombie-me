extends SceneTree

var world: Node3D
var fighter: CharacterBody3D
var threat: CharacterBody3D
var brain: RefCounted

func _initialize() -> void:
	call_deferred("verify")

func role(name: String) -> void:
	fighter.human_profile = load("res://game/gameplay/ai/humans/profiles/"+name+".tres")
	brain.configure(fighter,world,Vector3.ZERO,731)
	brain.human.seen_threat = threat
	brain.human.sense_clock = 100.0
	fighter.position = Vector3.ZERO
	threat.position = Vector3(0,0,-1.4)
	threat.zombie = true
	threat.infected = true
	threat.busy = false
	threat.dead = false
	threat.health = 100.0
	threat.stun_time = 0.0
	threat.infection_phase = "zombie"
	world.actor_grid.rebuild(world.player,world.citizens)

func action_tick(delta: float) -> void:
	world.combat_system.begin_tick()
	brain.human.combat.tick(delta)

func verify() -> void:
	world = load("res://game/world/community/outbreak.tscn").instantiate()
	world.population = 2
	root.add_child(world)
	world.set_physics_process(false)
	world.outbreak_progress.enabled = false
	world.player.position = Vector3(30,0,20)
	fighter = world.citizens[0]
	threat = world.citizens[1]
	brain = world.brains[0]
	await physics_frame
	role("bat_guard")
	assert(fighter.equipment_kind == "bat" and fighter.equipment.get_parent() == fighter.limbs[3])
	brain.human.combat.step(0.016)
	assert(threat.health == 100.0 and fighter.combat_locked)
	action_tick(0.2)
	assert(threat.health == 70.0 and threat.stun_time > 0.0)
	assert(threat.position.z < -2.0)
	action_tick(0.3)
	assert(not fighter.combat_locked)
	role("armed_police")
	threat.position = Vector3(0,0,-5)
	var gun: RefCounted = brain.human.combat
	gun.step(0.016)
	action_tick(0.36)
	assert(threat.health == 72.0 and gun.ammo == 5 and world.combat_system.shots == 1)
	action_tick(0.4)
	gun.ammo = 0
	gun.cooldown = 0.0
	gun.step(0.016)
	assert(gun.reload_clock > 0.0)
	var before := fighter.position
	gun.step(0.1)
	assert(fighter.position.distance_squared_to(threat.position) > before.distance_squared_to(threat.position))
	action_tick(3.3)
	assert(gun.ammo == 6 and gun.reload_clock == 0.0)
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	wall.position = Vector3(0,1,-2.5)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5,3,0.3)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	world.combat_system.begin_tick()
	assert(not world.combat_system.strike(fighter,threat,gun.profile))
	wall.queue_free()
	await physics_frame
	await physics_frame
	role("vaccine_medic")
	var medic: RefCounted = brain.human.combat
	var cure_signals := [0]
	threat.cured.connect(func(_was_zombie): cure_signals[0] += 1)
	medic.step(0.016)
	action_tick(0.13)
	assert(threat.infection_phase == "curing" and medic.doses == 2)
	assert(not threat.can_be_hunted() and not threat.can_be_cured())
	await create_timer(1.1).timeout
	assert(not threat.infected and not threat.zombie and not threat.busy)
	assert(threat.immunity_time > 0.0 and not threat.can_be_hunted() and cure_signals[0] == 1)
	threat.tick_conditions(9.0)
	assert(threat.can_be_hunted())
	threat.begin_bitten()
	threat.begin_incubation()
	world.actor_grid.rebuild(world.player,world.citizens)
	medic.cooldown = 0.0
	medic.cancel_action()
	medic.step(0.016)
	action_tick(0.13)
	assert(threat.infection_phase == "curing" and medic.doses == 1)
	await create_timer(1.1).timeout
	assert(not threat.infected and cure_signals[0] == 2)
	var search_before: int = world.actor_grid.queries
	for index in range(20):
		action_tick(0.016)
		medic.step(0.016)
	assert(world.actor_grid.queries-search_before <= 1)
	role("armed_police")
	world.player.zombie = true
	world.player.infected = true
	world.player.health = 20.0
	world.player.position = Vector3(0,0,-4)
	world.combat_system.begin_tick()
	assert(world.combat_system.strike(fighter,world.player,brain.human.combat.profile))
	assert(world.player.dead and world.finished and world.back_button != null)
	assert(world.swarm_attacks.captures.is_empty())
	brain = null
	gun = null
	medic = null
	world.queue_free()
	await process_frame
	print("Combat passed: windup, bat knockback/stun, gun damage/ammo/retreat/reload/LOS, latent and zombie cure, immunity, primary death loss.")
	quit()
