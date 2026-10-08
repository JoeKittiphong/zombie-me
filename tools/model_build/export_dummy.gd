extends SceneTree

func _initialize() -> void:
	var source := load("res://assets/models/dummy/dummy_model_source.tscn") as PackedScene
	var root := source.instantiate()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(root,state)
	if error == OK:
		error = document.write_to_filesystem(state,"res://assets/models/dummy/dummy_model.glb")
	root.free()
	if error != OK:
		push_error("Dummy GLB export failed: " + error_string(error))
	else:
		print("Dummy model GLB updated from editable source scene.")

	quit(error)

