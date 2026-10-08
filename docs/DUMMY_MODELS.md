# Dummy GLB / editable scenes

- assets/models/dummy/dummy_model.glb: runtime visual model, interchangeable with a Blender-exported GLB.
- assets/models/dummy/dummy_model_source.tscn: editable source for the current box dummy. Open this scene in Godot to adjust meshes, proportions, material colors and limb pivots.
- game/characters/dummy/dummy_actor.tscn: gameplay wrapper with CharacterBody3D, editable capsule collision and Visual/Model instance. Adjust exported coat/skin colors and scientist flag in the Inspector.
- game/characters/dummy/dummy_actor.gd: movement, procedural pivot animation and infection state, separate from model construction.

To update the GLB after editing the source scene, save it and run Godot:

    Godot --headless --path <project-directory> --script res://tools/model_build/export_dummy.gd

Godot imports the updated GLB on the next editor scan. Do not make permanent changes inside its generated .godot import cache. The actor wrapper and collider remain intact when the visual GLB is replaced.

The current model uses named rigid limb pivots (LeftLeg, LeftArm, RightLeg, RightArm), not a skinned skeleton. Keep those names for the existing animation driver. Materials named Skin, Coat and Hair drive per-instance appearance; skin materials are duplicated per actor so infection does not change everyone at once. A future skeleton rig will need an AnimationPlayer or AnimationTree driver.

tools/model_build/generate_dummy.gd and old_actor.gd preserve the original migration recipe; use export_dummy.gd for subsequent source edits. The source scene is a Godot model source, not a Blender .blend file.
