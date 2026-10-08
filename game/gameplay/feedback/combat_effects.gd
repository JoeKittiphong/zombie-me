extends Node3D

const POOL_SIZE := 24
var beams: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var beam_life := PackedFloat32Array()
var spark_life := PackedFloat32Array()
var beam_cursor := 0
var spark_cursor := 0

func _ready() -> void:
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.025,0.025,1.0)
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.13
	spark_mesh.height = 0.26
	spark_mesh.radial_segments = 8
	spark_mesh.rings = 4
	beam_life.resize(POOL_SIZE)
	spark_life.resize(POOL_SIZE)
	for index in range(POOL_SIZE):
		beams.append(make_mesh(beam_mesh,Color("ffe6a0")))
		sparks.append(make_mesh(spark_mesh,Color.WHITE))
	set_process(false)

func make_mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.hide()
	return node

func tracer(from: Vector3, to: Vector3) -> void:
	var node := beams[beam_cursor]
	node.position = (from+to)*0.5
	node.look_at(to)
	node.scale = Vector3(1,1,from.distance_to(to))
	node.show()
	beam_life[beam_cursor] = 0.09
	beam_cursor = (beam_cursor+1)%POOL_SIZE
	set_process(true)

func flash(at: Vector3, color: Color) -> void:
	var node := sparks[spark_cursor]
	node.position = at
	node.material_override.albedo_color = color
	node.show()
	spark_life[spark_cursor] = 0.15
	spark_cursor = (spark_cursor+1)%POOL_SIZE
	set_process(true)

func _process(delta: float) -> void:
	var active := false
	for index in range(POOL_SIZE):
		if beam_life[index] > 0.0:
			beam_life[index] -= delta
			beams[index].visible = beam_life[index] > 0.0
			active = active or beams[index].visible
		if spark_life[index] > 0.0:
			spark_life[index] -= delta
			sparks[index].visible = spark_life[index] > 0.0
			active = active or sparks[index].visible
	if not active:
		set_process(false)
