extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var scene := load("res://game/characters/dummy/dummy_actor.tscn") as PackedScene
	var first := scene.instantiate()
	var second := scene.instantiate()
	root.add_child(first)
	root.add_child(second)
	assert(first.limbs.size() == 4 and first.coat_meshes.size() == 3 and first.hair_meshes.size() == 1)
	assert(first.skin != second.skin)
	var skin_meshes := 0
	for mesh in first.visual.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override == first.skin:
			skin_meshes += 1
	assert(skin_meshes == 3)
	first.start_mutation()
	await create_timer(1.0).timeout
	assert(first.zombie and not second.zombie)
	assert(first.skin.albedo_color.is_equal_approx(first.zombie_skin_color))
	assert(second.skin.albedo_color.is_equal_approx(second.human_skin_color))
	print("GLB actor verified: named pivots, appearance materials and isolated infection.")
	quit()
