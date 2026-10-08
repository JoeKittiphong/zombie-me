extends RefCounted

var world: Node3D
var settings: Resource
var enabled := true
var first_attack_time := -1.0
var attack_victims: Dictionary = {}
var researched_bodies: Dictionary = {}
var claims: Dictionary = {}
var civilians_alerted := false
var vaccine_ready := false
var production_clock := -1.0
var phase := "unaware"

func configure(scene: Node3D) -> void:
	world = scene
	settings = scene.outbreak_pacing

func record_attack(victim: CharacterBody3D) -> void:
	if first_attack_time < 0.0:
		first_attack_time = world.elapsed
		phase = "incidents"
	attack_victims[victim.get_instance_id()] = true

func tick(delta: float) -> void:
	if not enabled:
		return
	if not civilians_alerted and first_attack_time >= 0.0 and world.elapsed-first_attack_time >= settings.civilian_awareness_delay and attack_victims.size() >= settings.minimum_attack_victims:
		civilians_alerted = true
		if researched_bodies.is_empty():
			phase = "recognized_outbreak"
		world.human_feedback.show_cue(world.player,"People are preparing to defend themselves.",false)
	if production_clock >= 0.0 and not vaccine_ready:
		production_clock = maxf(production_clock-delta,0.0)
		if production_clock == 0.0:
			vaccine_ready = true
			phase = "treatment_available"
			world.human_feedback.show_cue(world.player,"Treatment is ready after studying the samples.",false)

func recognizes(human: RefCounted) -> bool:
	if not enabled or civilians_alerted or human.danger_confirmed:
		return true
	var seen: CharacterBody3D = human.seen_threat
	# Sight has already passed the cone and occlusion checks. A visible attack is evidence.
	if is_instance_valid(seen) and world.swarm_attacks.memberships.has(seen.get_instance_id()):
		human.danger_confirmed = true
		return true
	if human.heard_alarm:
		human.danger_confirmed = true
		return true
	return false

func can_defend(actor: CharacterBody3D, human: RefCounted) -> bool:
	if not enabled:
		return true
	if actor.human_profile.role in ["armed_police","police"]:
		return recognizes(human)
	return civilians_alerted

func can_treat() -> bool:
	return not enabled or vaccine_ready

func can_study(body: CharacterBody3D, researcher: CharacterBody3D) -> bool:
	if not is_instance_valid(body) or not body.dead or not body.zombie or researcher.dead or researcher.infected:
		return false
	var key := body.get_instance_id()
	return not researched_bodies.has(key) and (not claims.has(key) or claims[key] == researcher.get_instance_id())

func claim(body: CharacterBody3D, researcher: CharacterBody3D) -> bool:
	if not can_study(body,researcher):
		return false
	claims[body.get_instance_id()] = researcher.get_instance_id()
	return true

func release(body: CharacterBody3D, researcher: CharacterBody3D) -> void:
	if is_instance_valid(body) and claims.get(body.get_instance_id(),-1) == researcher.get_instance_id():
		claims.erase(body.get_instance_id())

func submit_sample(body: CharacterBody3D, researcher: CharacterBody3D) -> bool:
	if not can_study(body,researcher) or claims.get(body.get_instance_id(),-1) != researcher.get_instance_id():
		return false
	var key := body.get_instance_id()
	researched_bodies[key] = true
	claims.erase(key)
	phase = "researching"
	world.human_feedback.show_cue(researcher,"Sample studied: %d / %d" % [researched_bodies.size(),settings.required_research_bodies],false)
	if researched_bodies.size() >= settings.required_research_bodies and production_clock < 0.0:
		production_clock = settings.production_duration
		phase = "producing_treatment"
	return true
