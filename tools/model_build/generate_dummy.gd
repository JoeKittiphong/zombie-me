extends SceneTree

const OLD_ACTOR := preload("res://tools/model_build/old_actor.gd")

func _initialize() -> void:
	var actor := CharacterBody3D.new()
	actor.set_script(OLD_ACTOR)
	actor.setup(Color("d9e2d0"),true)
	var model: Node3D = actor.visual
	actor.remove_child(model)
	model.name = "DummyModel"
	var names := ["Head","Hair","Torso","LeftLeg","LeftArm","RightLeg","RightArm","LeftEye","RightEye"]
	for index in range(model.get_child_count()):
		model.get_child(index).name = names[index]
	for node in model.find_children("*","MeshInstance3D",true,false):
		var mat: StandardMaterial3D = node.material_override
		if mat == actor.skin:
			mat.resource_name = "Skin"
		elif mat.albedo_color.is_equal_approx(Color("d9e2d0")):
			mat.resource_name = "Coat"
		elif mat.albedo_color.is_equal_approx(Color("65372f")):
			mat.resource_name = "Hair"
		else:
			mat.resource_name = "Detail"
	set_owners(model,model)
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed,"res://assets/models/dummy/dummy_model_source.tscn") == OK)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_scene(model,state) == OK)
	assert(doc.write_to_filesystem(state,"res://assets/models/dummy/dummy_model.glb") == OK)
	model.free()
	actor.free()
	print("Editable source scene and GLB exported.")
	quit()

func set_owners(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		set_owners(child,owner_node)
