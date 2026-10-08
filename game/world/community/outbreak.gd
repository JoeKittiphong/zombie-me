extends Node3D

signal exited
signal completed(result: Dictionary)

const ACTOR := preload("res://game/characters/dummy/dummy_actor.tscn")
@export_range(2, 2000, 1) var population := 24
@export var detailed_actor_budget := 64
@export var half_bounds := Vector2(35,25)
@export var bite_hold_duration := 1.4
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
	var colors := [Color("df9b58"), Color("769fbd"), Color("b8829a"), Color("8fa56b")]
	for index in range(spawn_points.size()):
		citizens.append(make_actor(spawn_points[index],colors[index%colors.size()]))
		var brain := BRAIN.new()
		brain.configure(citizens[index],self,spawn_points[index],index+731)
		brains.append(brain)
		citizens[index].became_zombie.connect(func():
			transformed_count += 1
			if transformed_count == citizens.size() and not finished:
				finish_round()
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
	if player.busy:
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
	manual_grace = maxf(manual_grace-delta,0)
	bite_time = maxf(bite_time-delta,0)
	# Provisional incubation linked to formula, communicated through the body rather than a timer.
	if elapsed >= 2.5+float(formula[2])*0.2 and not player.infected:
		player.start_mutation()
		status.text = "The serum is taking effect..."
	if player.zombie and not player.busy and not exhausted and not has_move_order and manual_grace <= 0:
		if not is_instance_valid(hunt_target) or hunt_target.infected:
			hunt_target = nearest_human(player.position,5.0)
	if exhausted or not player.zombie:
		hunt_target = null
	var chasing: bool = is_instance_valid(hunt_target) and not hunt_target.infected
	if player.busy:
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
	if target.infected or target.busy or attacker.busy:
		return
	attack_count += 1
	attacker.busy = true
	attacker.velocity = Vector3.ZERO
	target.begin_bitten()
	var direction := target.position-attacker.position
	direction.y = 0
	direction = direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD
	var side := Vector3(-direction.z,0,direction.x)
	var landing := target.position-direction*0.45+side*0.4
	landing.y = 0
	var yaw := atan2(-direction.x,-direction.z)
	attacker.visual.rotation.y = yaw
	target.visual.rotation.y = yaw
	if attacker == player:
		hunt_target = null
		marker.hide()
		status.text = "Tackle!"
	var sequence := create_tween()
	sequence.tween_property(attacker,"position",landing,0.32)
	sequence.parallel().tween_property(attacker.visual,"position:y",0.9,0.16)
	sequence.tween_property(attacker.visual,"position:y",0.17,0.16)
	sequence.tween_property(attacker.visual,"rotation:x",-PI/2,0.24)
	sequence.parallel().tween_property(target.visual,"rotation:x",-PI/2,0.24)
	sequence.parallel().tween_property(target.visual,"position:y",0.17,0.24)
	# Both bodies are down. Small forward pulses communicate the bite.
	for pulse in range(4):
		sequence.tween_property(attacker.visual,"rotation:x",-PI/2+0.1,0.12)
		sequence.tween_property(attacker.visual,"rotation:x",-PI/2,0.18)
	sequence.tween_interval(maxf(bite_hold_duration-1.2,0))
	sequence.tween_callback(target.begin_incubation)
	sequence.tween_property(attacker.visual,"rotation:x",0.0,0.65)
	sequence.parallel().tween_property(attacker.visual,"position:y",0.0,0.65)
	sequence.tween_callback(func():
		attacker.busy = false
		if attacker == player:
			destination = player.position
			has_move_order = false
			bite_time = 0.6
			status.text = "The infection is taking hold..."
	)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var focus := Vector3(player.position.x,0,player.position.z)
	camera.position = camera.position.lerp(focus+Vector3(16,18,20),minf(delta*4,1))
	camera.look_at(focus)
func finish_round() -> void:
	finished = true
	marker.hide()
	status.text = "Outbreak complete."
	var result := {"name": "Community outbreak", "date": Time.get_datetime_string_from_system(), "dose": formula.duplicate(), "stage": "COMMUNITY", "duration": snappedf(elapsed,0.1), "infected": citizens.size(), "outcome": "All citizens infected"}
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
	title.text = "OUTBREAK COMPLETE\n\nAll citizens infected.\n" + ("Experiment recorded." if record_saved else "Record could not be saved.")
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
