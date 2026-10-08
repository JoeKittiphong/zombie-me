extends Node3D

signal human_alerted(actor: CharacterBody3D)
signal exited
signal completed(result: Dictionary)

const PROGRESS := preload("res://game/gameplay/progression/outbreak_progress.gd")
@export var outbreak_pacing: Resource = preload("res://game/gameplay/progression/default_pacing.tres")
var outbreak_progress := PROGRESS.new()

const SWARM := preload("res://game/gameplay/combat/swarm_attacks.gd")
const COMBAT_SYSTEM := preload("res://game/gameplay/combat/combat_system.gd")
const COMBAT_EFFECTS := preload("res://game/gameplay/feedback/combat_effects.gd")
var swarm_attacks := SWARM.new()
var combat_system := COMBAT_SYSTEM.new()
var combat_effects: Node3D
var serum_injected := false
var outbreak_started := false

const ACTOR := preload("res://game/characters/dummy/dummy_actor.tscn")
@export_range(2, 2000, 1) var population := 24
@export_range(1,128,1) var detailed_actor_budget := 32
@export var half_bounds := Vector2(35,25)
@export var bite_hold_duration := 1.4
@export_flags_3d_physics var vision_collision_mask := 2
const HUMAN_PERCEPTION := preload("res://game/gameplay/ai/humans/human_perception.gd")
const HUMAN_FEEDBACK := preload("res://game/gameplay/feedback/human_feedback.gd")
@export var human_profiles: Array[Resource] = [
	preload("res://game/gameplay/ai/humans/profiles/civilian.tres"),
	preload("res://game/gameplay/ai/humans/profiles/elder.tres"),
	preload("res://game/gameplay/ai/humans/profiles/timid.tres"),
	preload("res://game/gameplay/ai/humans/profiles/doctor.tres"),
	preload("res://game/gameplay/ai/humans/profiles/police.tres"),
	preload("res://game/gameplay/ai/humans/profiles/bat_guard.tres"),
	preload("res://game/gameplay/ai/humans/profiles/armed_police.tres"),
	preload("res://game/gameplay/ai/humans/profiles/vaccine_medic.tres"),
	preload("res://game/gameplay/ai/humans/profiles/armed_civilian.tres")
]
var human_perception := HUMAN_PERCEPTION.new()
var human_feedback: Node3D
const GRID := preload("res://game/gameplay/ai/actor_grid.gd")
const CROWD_VISUALS := preload("res://game/gameplay/rendering/crowd_visuals.gd")
var actor_grid := GRID.new()
var spatial_clock := 0.0
var transformed_count := 0
var player_roaming: RefCounted
var has_move_order := false
var crowd_visuals: MultiMeshInstance3D
const BRAIN := preload("res://game/gameplay/ai/citizen_brain.gd")
var brains: Array = []
var spawn_points: Array[Vector3] = []
var attack_count := 0
var player: CharacterBody3D
var citizens: Array[CharacterBody3D] = []
var camera: Camera3D
var destination := Vector3(-5,0,3)
var marker: MeshInstance3D
var status: Label3D
var elapsed := 0.0
var stamina := 5.0
var exhausted := false
var manual_grace := 0.0
var bite_time := 0.0
var hunt_target: CharacterBody3D
var finished := false
var record_saved := true
var formula: Array = [4,3,3]
var ui: CanvasLayer
var back_button: Button

func _ready() -> void:
	outbreak_progress.configure(self)
	swarm_attacks.configure(self)
	combat_system.configure(self)
	combat_effects = Node3D.new()
	combat_effects.set_script(COMBAT_EFFECTS)
	add_child(combat_effects)
	build_world()
	if population == 2:
		destination = Vector3(-5,0,3)
		spawn_points = [Vector3(2,0,0), Vector3(5,0,-3)]
	else:
		destination = Vector3(-20,0,14)
		for index in range(population):
			var columns := maxi(6,ceili(sqrt(population*1.4)))
			var rows := ceili(float(population)/columns)
			spawn_points.append(Vector3(lerpf(-half_bounds.x+4,half_bounds.x-4,float(index%columns)/maxi(columns-1,1)),0,lerpf(-half_bounds.y+4,half_bounds.y-4,float(int(index/columns))/maxi(rows-1,1))))
		spawn_points[0] = Vector3(-14,0,12)
	player = make_actor(destination,Color("d9e2d0"),true)
	player.defeated.connect(func(_actor): finish_round(false,"Patient Zero eliminated."))
	human_feedback = Node3D.new()
	human_feedback.set_script(HUMAN_FEEDBACK)
	add_child(human_feedback)
	human_feedback.configure(player)
	var colors := [Color("df9b58"), Color("769fbd"), Color("b8829a"), Color("8fa56b")]
	for index in range(spawn_points.size()):
		citizens.append(make_actor(spawn_points[index],colors[index%colors.size()]))
		if not human_profiles.is_empty():
			citizens[index].human_profile = human_profiles[index%human_profiles.size()]
		var brain := BRAIN.new()
		brain.configure(citizens[index],self,spawn_points[index],index+731)
		brains.append(brain)
		citizens[index].defeated.connect(func(body):
			if body.zombie:
				transformed_count = maxi(transformed_count-1,0)
			check_victory()
		)
		citizens[index].cured.connect(func(was_zombie):
			if was_zombie:
				transformed_count = maxi(transformed_count-1,0)
			brain.human.change_state("wandering")
			brain.human.seen_threat = null
			brain.human.suspicion = 0.0
			brain.human.danger_confirmed = false
			brain.human.evidence_age = 100.0
		)
		citizens[index].became_zombie.connect(func():
			transformed_count += 1
			check_victory()
		)
	player_roaming = BRAIN.new()
	player_roaming.configure(player,self,destination,99173)
	crowd_visuals = MultiMeshInstance3D.new()
	crowd_visuals.set_script(CROWD_VISUALS)
	add_child(crowd_visuals)
	crowd_visuals.configure(population)
	refresh_perception()
	camera.position = destination+Vector3(16,18,20)
	camera.look_at(destination)
	status = Label3D.new()
	status.position = destination+Vector3(0,3,-6)
	status.font_size = 48
	status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status.pixel_size = 0.012
	status.text = "COMMUNITY\nClick the ground to move  /  Esc: return to lab"
	status.modulate = Color("eee6c9")
	add_child(status)
	ui = CanvasLayer.new()
	add_child(ui)

func make_actor(pos: Vector3, color: Color, scientist := false) -> CharacterBody3D:
	var actor := ACTOR.instantiate()
	add_child(actor)
	actor.position = pos
	actor.setup(color,scientist)
	actor.movement_bounds = half_bounds
	# Ground-click rays must not hit the controlled actor itself.
	actor.collision_layer = 4
	actor.collision_mask = 1
	if not scientist:
		actor.use_flat_movement = true
		actor.collision_layer = 0
		actor.collision_mask = 0
		actor.get_node("CollisionShape3D").disabled = true
	return actor

func block(pos: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material_override = mat
	add_child(mesh)

func build_world() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("7c9faa")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cad6c5")
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-32,0)
	sun.light_color = Color("fff0cf")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24
	camera.position = Vector3(16,18,20)
	add_child(camera)
	camera.look_at(Vector3(0,0,0))
	camera.current = true
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(72,0.3,52)
	shape.shape = box
	shape.position.y = -0.15
	ground.add_child(shape)
	add_child(ground)
	block(Vector3(0,-0.15,0),Vector3(72,0.3,52),Color("647c6d"))
	block(Vector3(0,0.005,0),Vector3(70,0.01,7),Color("53606a"))
	for index in range(-17,18):
		block(Vector3(index*2,0.018,0),Vector3(1,0.012,0.12),Color("e3d9b5"))
	for z in [-4.5,4.5]:
		block(Vector3(0,0.04,z),Vector3(70,0.08,1.8),Color("bbc2ad"))
	block(Vector3(0,0.008,0),Vector3(7,0.015,50),Color("53606a"))
	for row in [-25,25]:
		for x in range(-30,31,10):
			var z := float(row)
			block(Vector3(x,1.35,z),Vector3(5,2.7,1),Color("698b99"))
			block(Vector3(x,2.8,z),Vector3(5.25,0.25,1.2),Color("9e6956"))
			block(Vector3(x,1.4,z + (0.52 if row < 0 else -0.52)),Vector3(2.4,0.8,0.04),Color("d8d2a3"))
	marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.31
	ring.outer_radius = 0.4
	marker.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("a2e0a4")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = mat
	marker.position = destination+Vector3(0,0.04,0)
	marker.hide()
	add_child(marker)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		exited.emit()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		camera.size = clampf(camera.size + (-2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 2),18,38)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not finished:
		var origin := camera.project_ray_origin(event.position)
		var end := origin+camera.project_ray_normal(event.position)*100
		var query := PhysicsRayQueryParameters3D.create(origin,end,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			command_move(hit.position)
		get_viewport().set_input_as_handled()

func command_move(point: Vector3) -> void:
	if player.busy or player.dead:
		return
	has_move_order = true
	player_roaming.has_waypoint = false
	destination = Vector3(clampf(point.x,-half_bounds.x+0.5,half_bounds.x-0.5),0,clampf(point.z,-half_bounds.y+0.5,half_bounds.y-0.5))
	hunt_target = null
	manual_grace = 0.65
	marker.position = destination+Vector3(0,0.04,0)
	marker.show()

func nearest_human(pos: Vector3, radius: float) -> CharacterBody3D:
	return actor_grid.nearest(pos,radius,false)

func nearest_zombie(pos: Vector3, radius: float) -> CharacterBody3D:
	return actor_grid.nearest(pos,radius,true)

func refresh_perception() -> void:
	actor_grid.rebuild(player,citizens)
	if outbreak_started and not finished:
		var active := 1 if player.infected and not player.dead else 0
		for actor in citizens:
			if actor.infected and not actor.dead:
				active += 1
		if active == 0:
			finish_round(false,"The outbreak was contained.")
	var detail_candidates: Array[Vector2] = []
	for index in range(brains.size()):
		var actor: CharacterBody3D = citizens[index]
		var distance: float = player.position.distance_squared_to(actor.position)
		var near := distance < 324
		var middle := distance < 900
		brains[index].movement_interval = 0.0 if near else (0.066 if middle else 0.2)
		brains[index].perception_interval = 0.2 if near else 0.5
		actor.animation_interval = 0.033 if near else 0.1
		actor.detailed_visual = false
		if distance < 784:
			detail_candidates.append(Vector2(distance,index))
	detail_candidates.sort_custom(func(a: Vector2,b: Vector2): return a.x < b.x)
	for index in range(mini(detailed_actor_budget,detail_candidates.size())):
		citizens[int(detail_candidates[index].y)].detailed_visual = true
	for index in range(citizens.size()):
		crowd_visuals.update_actor(index,citizens[index])
func _physics_process(delta: float) -> void:
	human_perception.begin_tick()
	combat_system.begin_tick()
	swarm_attacks.step(delta)
	player.tick_conditions(delta)
	if player.infected:
		serum_injected = true
		outbreak_started = true
	spatial_clock -= delta
	if spatial_clock <= 0:
		refresh_perception()
		spatial_clock = 0.15
	if finished:
		for brain in brains:
			brain.tick(delta)
		return
	if not is_instance_valid(player):
		return
	elapsed += delta
	outbreak_progress.tick(delta)
	manual_grace = maxf(manual_grace-delta,0)
	bite_time = maxf(bite_time-delta,0)
	# Provisional incubation linked to formula, communicated through the body rather than a timer.
	if elapsed >= 2.5+float(formula[2])*0.2 and not player.infected and not serum_injected:
		serum_injected = true
		player.start_mutation()
		status.text = "The serum is taking effect..."
	if player.zombie and not player.busy and not exhausted and not has_move_order and manual_grace <= 0:
		if not is_instance_valid(hunt_target) or not hunt_target.can_be_hunted():
			hunt_target = nearest_human(player.position,5.0)
	if exhausted or not player.zombie:
		hunt_target = null
	var chasing: bool = is_instance_valid(hunt_target) and hunt_target.can_be_hunted()
	if player.busy or player.stun_time > 0.0:
		stamina = minf(stamina + delta * 0.4, 5)
	elif chasing:
		player.travel(hunt_target.position,4.5,delta)
		stamina = maxf(stamina-delta*1.6,0)
		status.text = "Hunting..."
		if player.position.distance_to(hunt_target.position) < 1.05 and bite_time <= 0:
			bite(hunt_target)
		if stamina <= 0:
			exhausted = true
			hunt_target = null
			destination = player.position
			has_move_order = false
			status.text = "Out of breath. Walk to recover."
	else:
		if has_move_order:
			player.travel(destination,2.2,delta)
			if player.position.distance_squared_to(destination) < 0.04:
				has_move_order = false
				marker.hide()
		elif player.zombie:
			player_roaming.roam(delta)
		else:
			player.travel(player.position,0,delta)
		stamina = minf(stamina+delta*1.1,5)
		if exhausted and stamina >= 2.5:
			exhausted = false
		if player.position.distance_to(destination) < 0.2:
			marker.hide()
	for brain in brains:
		brain.tick(delta)

func bite(target: CharacterBody3D) -> void:
	start_pounce(player,target)

func start_pounce(attacker: CharacterBody3D, target: CharacterBody3D) -> void:
	if not finished:
		swarm_attacks.join(attacker,target)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var focus := Vector3(player.position.x,0,player.position.z)
	camera.position = camera.position.lerp(focus+Vector3(16,18,20),minf(delta*4,1))
	camera.look_at(focus)
func finish_round(won := true, reason := "All citizens infected.") -> void:
	if finished:
		return
	finished = true
	swarm_attacks.stop_all()
	marker.hide()
	status.text = "Outbreak complete." if won else reason
	var result := {"name": "Community outbreak", "date": Time.get_datetime_string_from_system(), "dose": formula.duplicate(), "stage": "COMMUNITY", "duration": snappedf(elapsed,0.1), "infected": transformed_count, "outcome": "All citizens infected" if won else reason}
	completed.emit(result)
	var panel := Panel.new()
	panel.position = Vector2(425,190)
	panel.size = Vector2(430,320)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("203540")
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel",style)
	ui.add_child(panel)
	var title := Label.new()
	title.text = ("OUTBREAK COMPLETE" if won else "EXPERIMENT ENDED")+"\n\n"+reason+"\n" + ("Experiment recorded." if record_saved else "Record could not be saved.")
	title.position = Vector2(28,30)
	title.add_theme_font_size_override("font_size",23)
	panel.add_child(title)
	back_button = Button.new()
	back_button.text = "RETURN TO LAB"
	back_button.position = Vector2(28,220)
	back_button.size = Vector2(374,55)
	back_button.pressed.connect(func(): exited.emit())
	panel.add_child(back_button)
	back_button.grab_focus()

func check_victory() -> void:
	if finished or not player.zombie or player.dead:
		return
	for actor in citizens:
		if not actor.dead and (not actor.zombie or actor.infection_phase == "curing"):
			return
	finish_round()
