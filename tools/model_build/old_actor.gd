extends CharacterBody3D

var zombie := false
var infected := false
var skin: StandardMaterial3D
var visual: Node3D
var limbs: Array[Node3D] = []
var phase := 0.0
var turning := false

func setup(coat: Color, scientist := false) -> void:
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.65
	collision.shape = capsule
	collision.position.y = 0.83
	add_child(collision)
	visual = Node3D.new()
	add_child(visual)
	skin = material(Color("dcb99b"))
	part(Vector3(0,1.48,0),Vector3(0.45,0.48,0.43),skin)
	part(Vector3(0,1.74,0),Vector3(0.48,0.12,0.46),material(Color("65372f") if scientist else Color("30363a")))
	part(Vector3(0,0.97,0),Vector3(0.6,0.67,0.35),material(coat))
	for side in [-1.0,1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side*0.17,0.65,0)
		visual.add_child(leg)
		part(Vector3(0,-0.29,0),Vector3(0.21,0.58,0.23),material(Color("293b4a")),leg)
		part(Vector3(0,-0.56,-0.07),Vector3(0.25,0.16,0.37),material(Color("1d252e")),leg)
		limbs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(side*0.4,1.23,0)
		visual.add_child(arm)
		part(Vector3(0,-0.22,0),Vector3(0.18,0.45,0.2),material(coat),arm)
		part(Vector3(0,-0.48,0),Vector3(0.18,0.17,0.2),skin,arm)
		limbs.append(arm)
	# Eyes face local -Z, matching look direction.
	for side in [-1.0,1.0]:
		part(Vector3(side*0.1,1.51,-0.225),Vector3(0.065,0.06,0.018),material(Color("19252a")))

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	return result

func part(pos: Vector3, dimensions: Vector3, mat: Material, parent: Node3D = null) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = dimensions
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.position = pos
	(visual if parent == null else parent).add_child(mesh)

func travel(destination: Vector3, speed: float, delta: float) -> void:
	var offset := destination-position
	offset.y = 0
	var moving := offset.length() > 0.12
	velocity = offset.normalized()*minf(speed,offset.length()/delta) if moving else Vector3.ZERO
	velocity.y = -2.0
	move_and_slide()
	position.x = clampf(position.x,-10,10)
	position.z = clampf(position.z,-7,7)
	if moving:
		visual.rotation.y = lerp_angle(visual.rotation.y,atan2(-offset.x,-offset.z),minf(delta*10,1))
	phase += delta*speed*3
	for index in range(limbs.size()):
		limbs[index].rotation.x = sin(phase+index*PI)*0.4 if moving else 0.0
		if zombie and index%2 == 1:
			limbs[index].rotation.x -= 0.65
	visual.position.y = absf(sin(phase))*0.04 if moving else 0.0

func start_mutation() -> void:
	if turning or zombie:
		return
	infected = true
	turning = true
	var tween := create_tween()
	tween.tween_property(skin,"albedo_color",Color("86b96a"),0.8)
	tween.tween_callback(func():
		zombie = true
		turning = false
	)
