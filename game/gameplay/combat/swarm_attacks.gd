extends RefCounted

class Participant extends RefCounted:
	var actor: CharacterBody3D
	var start := Vector3.ZERO
	var landing := Vector3.ZERO
	var joined := 0.0
	var slot := 0
	var yaw := 0.0

class Capture extends RefCounted:
	var target: CharacterBody3D
	var attackers: Array[Participant] = []
	var elapsed := 0.0
	var release_at := 2.2
	var yaw := 0.0
	var base_angle := 0.0
	var center := Vector3.ZERO
	var next_slot := 0
	var exposed := false
	var released := false

const JOIN_WINDOW := 2.0
var world: Node3D
var captures: Dictionary = {}
var memberships: Dictionary = {}
var maximum_attackers := 8
var peak_group_size := 0

func configure(scene: Node3D) -> void:
	world = scene

func join(attacker: CharacterBody3D, target: CharacterBody3D) -> bool:
	if not is_instance_valid(target) or attacker.dead or not attacker.zombie or attacker.busy or attacker.stun_time > 0.0 or not target.can_be_hunted():
		return false
	var key := target.get_instance_id()
	var capture: Capture = captures.get(key)
	if capture == null:
		capture = Capture.new()
		capture.target = target
		var direction := target.position-attacker.position
		direction.y = 0.0
		direction = direction.normalized() if direction.length_squared() > 0.01 else Vector3.FORWARD
		capture.yaw = atan2(-direction.x,-direction.z)
		capture.center = target.position+direction*0.7
		capture.center.x = clampf(capture.center.x,-target.movement_bounds.x+0.2,target.movement_bounds.x-0.2)
		capture.center.z = clampf(capture.center.z,-target.movement_bounds.y+0.2,target.movement_bounds.y-0.2)
		capture.base_angle = atan2(attacker.position.z-capture.center.z,attacker.position.x-capture.center.x)
		capture.release_at = 0.8+world.bite_hold_duration
		captures[key] = capture
		world.outbreak_progress.record_attack(target)
		target.begin_grapple()
		target.visual.rotation.y = capture.yaw
		world.human_perception.emit_cue(target.position,world.elapsed,10.0,true)
	if capture.released or capture.elapsed > JOIN_WINDOW or capture.attackers.size() >= maximum_attackers:
		return false
	var member := Participant.new()
	member.actor = attacker
	member.start = attacker.position
	member.joined = capture.elapsed
	member.slot = capture.next_slot
	capture.next_slot += 1
	var angle := capture.base_angle+member.slot*TAU/maximum_attackers
	var radius := 1.0+float(member.slot%2)*0.15
	member.landing = capture.center+Vector3(cos(angle),0,sin(angle))*radius
	member.landing.x = clampf(member.landing.x,-attacker.movement_bounds.x,attacker.movement_bounds.x)
	member.landing.z = clampf(member.landing.z,-attacker.movement_bounds.y,attacker.movement_bounds.y)
	var aim := capture.center-member.landing
	member.yaw = atan2(-aim.x,-aim.z)
	capture.attackers.append(member)
	memberships[attacker.get_instance_id()] = capture
	capture.release_at = maxf(capture.release_at,capture.elapsed+0.8+world.bite_hold_duration)
	target.swarm_joinable = capture.next_slot < maximum_attackers
	attacker.busy = true
	attacker.velocity = Vector3.ZERO
	world.attack_count += 1
	peak_group_size = maxi(peak_group_size,capture.attackers.size())
	if attacker == world.player:
		world.hunt_target = null
		world.marker.hide()
		world.status.text = "Swarm tackle!"
	return true

func step(delta: float) -> void:
	for key in captures.keys():
		var capture: Capture = captures[key]
		capture.elapsed += delta
		var target: CharacterBody3D = capture.target
		if not is_instance_valid(target) or target.dead:
			finish_capture(key,capture)
			continue
		if capture.elapsed >= JOIN_WINDOW:
			target.swarm_joinable = false
		if not capture.released:
			var fall := clampf((capture.elapsed-0.48)/0.24,0.0,1.0)
			target.visual.rotation.x = -PI/2*fall
			target.visual.position.y = 0.17*fall
			if capture.elapsed >= capture.release_at or capture.attackers.is_empty():
				release_target(capture)
		for member in capture.attackers:
			animate_member(member,capture)
		if capture.released and capture.elapsed >= capture.release_at+0.65:
			finish_capture(key,capture)

func animate_member(member: Participant, capture: Capture) -> void:
	var body: CharacterBody3D = member.actor
	if not is_instance_valid(body) or body.dead:
		return
	var age := capture.elapsed-member.joined
	body.visual.rotation.y = member.yaw
	if capture.released:
		var rise := clampf((capture.elapsed-capture.release_at)/0.65,0.0,1.0)
		body.visual.rotation.x = lerpf(-PI/2,0.0,rise)
		body.visual.position.y = lerpf(0.17,0.0,rise)
	elif age < 0.48:
		var t := age/0.48
		body.position = member.start.lerp(member.landing,t)
		body.visual.position.y = sin(t*PI)*0.95
	elif age < 0.72:
		body.position = member.landing
		var t := (age-0.48)/0.24
		body.visual.position.y = 0.17*t
		body.visual.rotation.x = -PI/2*t
	else:
		if not capture.exposed:
			capture.exposed = true
			capture.target.begin_bitten()
		body.visual.rotation.x = -PI/2+sin(age*21.0+member.slot*0.7)*0.08
		body.visual.position.y = 0.17
		for index in range(body.limbs.size()):
			body.limbs[index].rotation.x = sin(age*17+index+member.slot)*0.12

func release_target(capture: Capture) -> void:
	var target: CharacterBody3D = capture.target
	capture.released = true
	capture.release_at = capture.elapsed
	if is_instance_valid(target) and not target.dead:
		target.grappled = false
		target.swarm_joinable = false
		if capture.exposed:
			target.begin_incubation()
		else:
			target.busy = false
			target.visual.rotation.x = 0.0
			target.visual.position.y = 0.0
			target.infection_phase = "human"

func interrupt_actor(body: CharacterBody3D) -> void:
	var key := body.get_instance_id()
	var capture: Capture = memberships.get(key)
	if capture == null:
		return
	for index in range(capture.attackers.size()-1,-1,-1):
		if capture.attackers[index].actor == body:
			capture.attackers.remove_at(index)
	memberships.erase(key)
	reset_attacker(body)
	if capture.attackers.is_empty() and not capture.released:
		release_target(capture)

func reset_attacker(body: CharacterBody3D) -> void:
	if not is_instance_valid(body) or body.dead:
		return
	body.busy = false
	body.visual.rotation.x = 0.0
	body.visual.rotation.z = 0.0
	body.visual.position.y = 0.0
	if body == world.player:
		world.destination = body.position
		world.has_move_order = false
		world.bite_time = 0.6

func finish_capture(key: int, capture: Capture) -> void:
	if not capture.released:
		release_target(capture)
	for member in capture.attackers:
		if is_instance_valid(member.actor):
			memberships.erase(member.actor.get_instance_id())
			reset_attacker(member.actor)
	captures.erase(key)

func stop_all() -> void:
	for key in captures.keys():
		finish_capture(key,captures[key])
