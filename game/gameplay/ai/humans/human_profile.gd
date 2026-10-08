extends Resource

@export var combat_profile: Resource

@export var role := "civilian"
@export var alarm_line := "Zombie! Run!"
@export var vision_range := 8.0
@export var vision_half_angle := 65.0
@export var smell_range := 5.0
@export var hearing_range := 10.0
@export var smell_suspicion_rate := 0.6
@export var flees_from_smell := false
@export var investigates_smell := false
@export var reaction_delay := 0.35
@export var walk_speed := 0.8
@export var run_speed := 2.8
@export var stamina_capacity := 5.0
@export var stamina_drain := 1.0
@export var stamina_recovery := 1.5
@export var danger_memory := 4.0
