extends Node3D

signal exited
signal completed(result: Dictionary)

const ACTOR := preload("res://game/characters/dummy/dummy_actor.gd")
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
	player = make_actor(destination,Color("d9e2d0"),true)
	citizens.append(make_actor(Vector3(2,0,0),Color("df9b58")))
	citizens.append(make_actor(Vector3(5,0,-3),Color("769fbd")))
	status = Label3D.new()
	status.position = Vector3(-1,3,-6.5)
	status.font_size = 48
	status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status.pixel_size = 0.012
	status.text = "COMMUNITY\nClick the ground to move  /  Esc: return to lab"
	status.modulate = Color("eee6c9")
	add_child(status)
	ui = CanvasLayer.new()
	add_child(ui)

func make_actor(pos: Vector3, color: Color, scientist := false) -> CharacterBody3D:
	var actor := CharacterBody3D.new()
	actor.set_script(ACTOR)
	add_child(actor)
	actor.position = pos
	actor.setup(color,scientist)
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
	box.size = Vector3(22,0.3,16)
	shape.shape = box
	shape.position.y = -0.15
	ground.add_child(shape)
	add_child(ground)
	block(Vector3(0,-0.15,0),Vector3(22,0.3,16),Color("647c6d"))
	block(Vector3(0,0.005,0),Vector3(20,0.01,7),Color("53606a"))
	for index in range(-4,5):
		block(Vector3(index*2,0.018,0),Vector3(1,0.012,0.12),Color("e3d9b5"))
	for z in [-4.5,4.5]:
		block(Vector3(0,0.04,z),Vector3(20,0.08,1.8),Color("bbc2ad"))
	for x in [-8,-3,3,8]:
		block(Vector3(x,1.35,-7.5),Vector3(3,2.7,1),Color("698b99"))
		block(Vector3(x,2.8,-7.5),Vector3(3.25,0.25,1.2),Color("9e6956"))
		block(Vector3(x,1.4,-6.98),Vector3(1.4,0.8,0.04),Color("d8d2a3"))
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not finished:
		var origin := camera.project_ray_origin(event.position)
		var end := origin+camera.project_ray_normal(event.position)*100
		var query := PhysicsRayQueryParameters3D.create(origin,end,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			command_move(hit.position)
		get_viewport().set_input_as_handled()

func command_move(point: Vector3) -> void:
	destination = Vector3(clampf(point.x,-9.5,9.5),0,clampf(point.z,-6.5,6.5))
	hunt_target = null
	manual_grace = 0.65
	marker.position = destination+Vector3(0,0.04,0)
	marker.show()

func nearest_human(pos: Vector3, radius: float) -> CharacterBody3D:
	var best: CharacterBody3D
	var distance := radius
	for citizen in citizens:
		if citizen.infected:
			continue
		var candidate := pos.distance_to(citizen.position)
		if candidate < distance:
			distance = candidate
			best = citizen
	return best

func _physics_process(delta: float) -> void:
	if finished or not is_instance_valid(player):
		return
	elapsed += delta
	manual_grace = maxf(manual_grace-delta,0)
	bite_time = maxf(bite_time-delta,0)
	# Provisional incubation linked to formula, communicated through the body rather than a timer.
	if elapsed >= 2.5+float(formula[2])*0.2 and not player.infected:
		player.start_mutation()
		status.text = "The serum is taking effect..."
	if player.zombie and not exhausted and manual_grace <= 0:
		if not is_instance_valid(hunt_target) or hunt_target.infected:
			hunt_target = nearest_human(player.position,5.0)
	if exhausted or not player.zombie:
		hunt_target = null
	var chasing: bool = is_instance_valid(hunt_target) and not hunt_target.infected
	if chasing:
		player.travel(hunt_target.position,4.5,delta)
		stamina = maxf(stamina-delta*1.6,0)
		status.text = "Hunting..."
		if player.position.distance_to(hunt_target.position) < 1.05 and bite_time <= 0:
			bite(hunt_target)
		if stamina <= 0:
			exhausted = true
			hunt_target = null
			destination = player.position
			status.text = "Out of breath. Walk to recover."
	else:
		player.travel(destination,2.2,delta)
		stamina = minf(stamina+delta*1.1,5)
		if exhausted and stamina >= 2.5:
			exhausted = false
		if player.position.distance_to(destination) < 0.2:
			marker.hide()
	for index in range(citizens.size()):
		update_citizen(citizens[index],index,delta)
	if citizens.all(func(actor): return actor.zombie):
		finish_round()

func update_citizen(citizen: CharacterBody3D, index: int, delta: float) -> void:
	if citizen.turning:
		citizen.travel(citizen.position,0,delta)
		return
	if citizen.zombie:
		var target := nearest_human(citizen.position,6)
		if target:
			citizen.travel(target.position,3.6,delta)
			if citizen.position.distance_to(target.position) < 1.0:
				target.start_mutation()
		else:
			citizen.travel(citizen.position,0,delta)
		return
	var threat: CharacterBody3D
	var closest := 4.0
	for actor in [player]+citizens:
		if actor.zombie and citizen.position.distance_to(actor.position) < closest:
			closest = citizen.position.distance_to(actor.position)
			threat = actor
	if threat:
		var away := citizen.position-threat.position
		away.y = 0
		if away.length() < 0.1:
			away = Vector3.RIGHT
		citizen.travel(citizen.position+away.normalized()*2,2.0,delta)
	else:
		var home := Vector3(2,0,0) if index == 0 else Vector3(5,0,-3)
		citizen.travel(home+Vector3(sin(elapsed*0.5+index)*0.7,0,cos(elapsed*0.4)*0.5),0.6,delta)

func bite(target: CharacterBody3D) -> void:
	if target.infected:
		return
	target.start_mutation()
	bite_time = 0.65
	hunt_target = null
	destination = player.position
	status.text = "Infection spreads."

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




