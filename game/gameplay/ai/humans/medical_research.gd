extends RefCounted

var actor: CharacterBody3D
var world: Node3D
var patient: CharacterBody3D
var study_clock := 0.0
var search_clock := 0.0
var sight_clock := 0.0
var clear_sight := false

func configure(body: CharacterBody3D, scene: Node3D, stagger: float) -> void:
	actor = body
	world = scene
	search_clock = stagger

func step(human: RefCounted, delta: float) -> bool:
	var progress: RefCounted = world.outbreak_progress
	var settings: Resource = progress.settings
	search_clock -= delta
	sight_clock -= delta
	if actor.dead or actor.infected or actor.grappled or progress.can_treat() or progress.production_clock >= 0.0:
		cancel()
		return false
	if is_instance_valid(human.seen_threat) and human.seen_threat.position.distance_squared_to(actor.position) < 9.0:
		cancel()
		return false
	if is_instance_valid(patient) and not progress.can_study(patient,actor):
		cancel()
	if not is_instance_valid(patient) and search_clock <= 0.0:
		patient = world.actor_grid.nearest_research_body(actor.position,settings.sample_search_range,progress,actor)
		search_clock = 0.5
		if is_instance_valid(patient):
			progress.claim(patient,actor)
	if not is_instance_valid(patient):
		return false
	human.change_state("researching")
	human.face(patient.position,delta)
	if actor.position.distance_squared_to(patient.position) > settings.sample_range*settings.sample_range:
		study_clock = 0.0
		actor.travel(patient.position,human.profile.walk_speed,delta)
		return true
	actor.travel(actor.position,0.0,delta)
	if sight_clock <= 0.0:
		clear_sight = world.combat_system.clear_line(actor,patient)
		sight_clock = 0.25
	if not clear_sight:
		study_clock = 0.0
		return true
	study_clock += delta
	if study_clock >= settings.sample_duration:
		progress.submit_sample(patient,actor)
		cancel()
	return true

func cancel() -> void:
	if is_instance_valid(patient):
		world.outbreak_progress.release(patient,actor)
	patient = null
	study_clock = 0.0
	clear_sight = false
	sight_clock = 0.0
