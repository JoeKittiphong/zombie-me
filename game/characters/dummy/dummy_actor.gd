extends CharacterBody3D

@export var human_profile: Resource = preload("res://game/gameplay/ai/humans/profiles/civilian.tres")
@export_range(0.0,2.0) var odor_strength := 1.0
@export_range(0.0,2.0) var noise_strength := 1.0
var human_state := "wandering"

signal defeated(actor: CharacterBody3D)
signal cured(was_zombie: bool)
@export var maximum_health := 100.0
var health := 100.0
var dead := false
var stun_time := 0.0
var immunity_time := 0.0
var grappled := false
var swarm_joinable := false
var combat_locked := false
var combat_pose := 0.0
var equipment_kind := "none"
var equipment: Node3D
var mutation_tween: Tween
var cure_was_zombie := false
var cure_duration := 1.0
var cure_immunity := 8.0
var cure_start_color := Color.WHITE
var cure_start_rotation := 0.0

signal became_zombie
static var appearance_materials: Dictionary = {}

@export var use_flat_movement := false
var animation_interval := 0.0
var detailed_visual := true
@export var movement_bounds := Vector2(35, 25)
@export var still_duration := 2.8
@export var convulsion_duration := 2.5
@export var rise_duration := 1.8
@export var coat_color := Color("d9e2d0")
@export var scientist := false
@export var human_skin_color := Color("dcb99b")
@export var zombie_skin_color := Color("86b96a")

var busy := false
var infection_phase := "human"
var infection_elapsed := 0.0
var infection_visual_clock := 0.0
var head: Node3D
const MOTOR := preload("res://game/gameplay/movement/actor_motor.gd")
var motor := MOTOR.new()
var zombie := false
var infected := false
var skin: StandardMaterial3D
var visual: Node3D
var model: Node3D
var limbs: Array[Node3D] = []
var turning := false
var coat_meshes: Array[MeshInstance3D] = []
var hair_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	set_process(false)
	visual = $Visual
	model = $Visual/Model
	head = model.find_child("Head", true, false)
	skin = StandardMaterial3D.new()
	skin.albedo_color = human_skin_color
	skin.roughness = 0.9
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var imported := mesh.get_active_material(0) as StandardMaterial3D
		if imported == null:
			continue
		var material_name := imported.resource_name.to_lower()
		if material_name.begins_with("skin"):
			mesh.material_override = skin
		elif material_name.begins_with("coat"):
			coat_meshes.append(mesh)
		elif material_name.begins_with("hair"):
			hair_meshes.append(mesh)
	for part_name in ["LeftLeg", "LeftArm", "RightLeg", "RightArm"]:
		var limb := model.find_child(part_name, true, false) as Node3D
		assert(limb != null, "Missing model pivot: " + part_name)
		limbs.append(limb)
	health = maximum_health
	setup(coat_color, scientist)

func setup(coat: Color, is_scientist := false) -> void:
	coat_color = coat
	scientist = is_scientist
	for mesh in coat_meshes:
		mesh.material_override = material(coat_color)
	for mesh in hair_meshes:
		mesh.material_override = material(Color("65372f") if scientist else Color("30363a"))

func material(color: Color) -> StandardMaterial3D:
	var key := color.to_rgba32()
	if appearance_materials.has(key):
		return appearance_materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	appearance_materials[key] = result
	return result

func travel(destination: Vector3, speed: float, delta: float) -> void:
	motor.travel(self,destination,speed,delta)

func start_mutation() -> void:
	if turning or zombie or dead:
		return
	infected = true
	turning = true
	for limb in limbs:
		limb.rotation.z = 0.0
	infection_phase = "serum"
	if equipment != null:
		equipment.hide()
	mutation_tween = create_tween()
	mutation_tween.tween_property(skin,"albedo_color",zombie_skin_color,0.8)
	mutation_tween.tween_callback(func():
		zombie = true
		turning = false
		became_zombie.emit()
	)


func begin_bitten() -> void:
	infected = true
	turning = true
	for limb in limbs:
		limb.rotation.z = 0.0
	busy = true
	infection_phase = "bitten"
	if equipment != null:
		equipment.hide()
	infection_elapsed = 0.0
	velocity = Vector3.ZERO

func begin_incubation() -> void:
	set_process(true)
	infection_phase = "still"
	infection_elapsed = 0.0
	visual.position.y = 0.17
	visual.rotation.x = -PI / 2

func _process(delta: float) -> void:
	if infection_phase == "curing":
		process_cure(delta)
		return
	if infection_phase not in ["still", "convulsing", "rising"]:
		return
	infection_elapsed += delta
	infection_visual_clock += delta
	if not visual.visible and infection_visual_clock < 0.1:
		return
	infection_visual_clock = 0
	if infection_phase == "still":
		if infection_elapsed >= still_duration:
			infection_phase = "convulsing"
			infection_elapsed = 0.0
	elif infection_phase == "convulsing":
		var t := minf(infection_elapsed / convulsion_duration, 1.0)
		skin.albedo_color = human_skin_color.lerp(zombie_skin_color, t * 0.85)
		visual.rotation.x = -PI / 2 + sin(infection_elapsed * 28) * 0.075
		visual.rotation.z = sin(infection_elapsed * 21) * 0.045
		for index in range(limbs.size()):
			limbs[index].rotation.x = sin(infection_elapsed * 23 + index) * 0.22
		if t >= 1:
			infection_phase = "rising"
			infection_elapsed = 0.0
			visual.rotation.z = 0
	else:
		var t := minf(infection_elapsed / rise_duration, 1.0)
		var eased := t * t * (3 - 2 * t)
		visual.rotation.x = lerpf(-PI / 2, 0, eased)
		visual.position.y = lerpf(0.17, 0.0, eased)
		head.rotation.x = 0.4
		for index in range(limbs.size()):
			limbs[index].rotation.x = 0.65 if index % 2 == 1 else 0.0
		skin.albedo_color = skin.albedo_color.lerp(zombie_skin_color, t)
		if t >= 1:
			zombie = true
			turning = false
			became_zombie.emit()
			busy = false
			infection_phase = "zombie"
			set_process(false)
			skin.albedo_color = zombie_skin_color
			visual.rotation = Vector3(0, visual.rotation.y, 0)

func set_detailed_visual(enabled: bool) -> void:
	if visual.visible == enabled:
		return
	visual.visible = enabled
	if enabled:
		visual.add_child(model)
	else:
		# Detached GLB branches retain editable assets without scene-tree transform overhead.
		visual.remove_child(model)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(model) and model.get_parent() == null:
		model.free()
func can_be_hunted() -> bool:
	return not dead and not zombie and immunity_time <= 0.0 and ((grappled and swarm_joinable) or (not infected and not busy and not turning))

func can_be_cured() -> bool:
	return not dead and infected and not grappled and infection_phase != "curing"

func is_combat_target() -> bool:
	return not dead and infected and infection_phase != "curing"

func begin_grapple() -> void:
	combat_locked = false
	combat_pose = 0.0
	for limb in limbs:
		limb.rotation.z = 0.0
	grappled = true
	swarm_joinable = true
	busy = true
	infection_phase = "bitten"
	velocity = Vector3.ZERO

func tick_conditions(delta: float) -> void:
	stun_time = maxf(stun_time-delta,0.0)
	immunity_time = maxf(immunity_time-delta,0.0)

func take_damage(amount: float, push: Vector3, stun: float) -> void:
	if dead or not zombie or infection_phase == "curing":
		return
	health = maxf(health-amount,0.0)
	stun_time = maxf(stun_time,stun)
	position += push
	position.x = clampf(position.x,-movement_bounds.x,movement_bounds.x)
	position.z = clampf(position.z,-movement_bounds.y,movement_bounds.y)
	velocity = Vector3.ZERO
	if health <= 0.0:
		dead = true
		busy = true
		turning = false
		if mutation_tween != null and mutation_tween.is_valid():
			mutation_tween.kill()
		set_process(false)
		visual.rotation.x = -PI/2
		visual.position.y = 0.17
		skin.albedo_color = Color("626858")
		defeated.emit(self)

func begin_cure(duration: float, immunity: float) -> void:
	if not can_be_cured():
		return
	if mutation_tween != null and mutation_tween.is_valid():
		mutation_tween.kill()
	cure_was_zombie = zombie
	cure_duration = maxf(duration,0.05)
	cure_immunity = immunity
	cure_start_color = skin.albedo_color
	cure_start_rotation = visual.rotation.x
	infection_elapsed = 0.0
	infection_phase = "curing"
	busy = true
	turning = true
	velocity = Vector3.ZERO
	set_process(true)

func process_cure(delta: float) -> void:
	infection_elapsed += delta
	var t := minf(infection_elapsed/cure_duration,1.0)
	if detailed_visual or t >= 1.0:
		skin.albedo_color = cure_start_color.lerp(human_skin_color,t)
		visual.rotation.x = lerpf(cure_start_rotation,0.0,t)
		visual.position.y = lerpf(0.17,0.0,t)
	if t < 1.0:
		return
	zombie = false
	infected = false
	busy = false
	turning = false
	grappled = false
	swarm_joinable = false
	infection_phase = "human"
	health = maxf(health,60.0)
	immunity_time = cure_immunity
	stun_time = 0.0
	visual.rotation = Vector3(0,visual.rotation.y,0)
	visual.position.y = 0.0
	head.rotation = Vector3.ZERO
	for limb in limbs:
		limb.rotation = Vector3.ZERO
	if equipment != null:
		equipment.show()
	cured.emit(cure_was_zombie)
	set_process(false)

func equip(kind: String) -> void:
	if equipment != null:
		equipment.free()
		equipment = null
	equipment_kind = kind
	if kind == "none":
		return
	equipment = load("res://game/characters/equipment/"+kind+".tscn").instantiate()
	limbs[3].add_child(equipment)
	equipment.position = Vector3(0,-0.48,0)
	if kind == "gun":
		equipment.rotation.x = -PI/2

func pose_equipment() -> void:
	if equipment == null or infected or dead:
		return
	limbs[3].rotation.z = 0.0
	if equipment_kind == "gun":
		limbs[3].rotation.x = 1.4 if human_state in ["fighting","reloading"] else 0.25
		if combat_locked:
			limbs[3].rotation.x -= sin(combat_pose*PI)*0.18
	elif equipment_kind == "bat":
		limbs[3].rotation.x = -0.35
		if combat_locked:
			limbs[3].rotation.x = -1.8+combat_pose*2.4
			limbs[3].rotation.z = sin(combat_pose*PI)*0.7
	elif equipment_kind in ["vaccine","sample_kit"]:
		limbs[3].rotation.x = 1.3 if human_state in ["treating","researching"] else 0.25
