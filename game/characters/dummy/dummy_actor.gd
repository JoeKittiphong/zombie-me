extends CharacterBody3D

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
var limbs: Array[Node3D] = []
var turning := false
var coat_meshes: Array[MeshInstance3D] = []
var hair_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	set_process(false)
	visual = $Visual
	var model := $Visual/Model
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
	if turning or zombie:
		return
	infected = true
	turning = true
	infection_phase = "serum"
	var tween := create_tween()
	tween.tween_property(skin,"albedo_color",zombie_skin_color,0.8)
	tween.tween_callback(func():
		zombie = true
		turning = false
		became_zombie.emit()
	)


func begin_bitten() -> void:
	infected = true
	turning = true
	busy = true
	infection_phase = "bitten"
	infection_elapsed = 0.0
	velocity = Vector3.ZERO

func begin_incubation() -> void:
	set_process(true)
	infection_phase = "still"
	infection_elapsed = 0.0
	visual.position.y = 0.17
	visual.rotation.x = -PI / 2

func _process(delta: float) -> void:
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
			limbs[index].rotation.x = -0.65 if index % 2 == 1 else 0.0
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
