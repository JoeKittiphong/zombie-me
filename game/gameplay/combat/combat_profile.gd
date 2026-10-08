extends Resource

@export_enum("none", "bat", "gun", "vaccine") var equipment := "none"
@export var attack_range := 1.9
@export var preferred_distance := 1.5
@export var damage := 20.0
@export var windup := 0.18
@export var recovery := 0.28
@export var cooldown := 1.1
@export var knockback := 0.7
@export var stun_duration := 0.35
@export var magazine_size := 6
@export var reload_duration := 2.4
@export var vaccine_doses := 3
@export var cure_duration := 1.0
@export var immunity_duration := 8.0
