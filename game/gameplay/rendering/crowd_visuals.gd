extends MultiMeshInstance3D

func configure(count: int) -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.28
	mesh.height = 1.7
	mesh.radial_segments = 6
	mesh.rings = 2
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	mesh.material = material
	multimesh.mesh = mesh
	multimesh.instance_count = count
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func update_actor(index: int, actor: CharacterBody3D) -> void:
	var detailed: bool = actor.detailed_visual
	actor.visual.visible = detailed
	var pose := Basis.from_euler(actor.visual.rotation)
	var transform := Transform3D(pose,actor.position+actor.visual.position+pose*Vector3(0,0.85,0))
	if detailed:
		transform.basis = Basis.IDENTITY.scaled(Vector3.ZERO)
	multimesh.set_instance_transform(index,transform)
	multimesh.set_instance_color(index,actor.zombie_skin_color if actor.zombie else actor.coat_color)

