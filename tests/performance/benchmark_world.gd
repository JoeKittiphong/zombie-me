extends "res://game/world/community/outbreak.gd"

func start_pounce(attacker: CharacterBody3D, target: CharacterBody3D) -> void:
	if "--combat" in OS.get_cmdline_user_args():
		super.start_pounce(attacker,target)

func finish_round(_won := true, _reason := "All citizens infected.") -> void:
	pass
