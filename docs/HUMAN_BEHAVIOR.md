# Human behavior

Reviewed the original **ไอเดียเกมซอมบี้** conversation on 2026-10-08:
https://chatgpt.com/g/g-p-6ac5b0dbe7c08191ac7e4f871801e8e8-ai-ediiyekms-channiiaehla-khnsraangch-mbii/c/6ac5b0dd-6c38-83ec-bf33-638fa2155ce9

The player's design specifies different sight ranges and zombie odor that can cause suspicion or flight through cover. The conversation additionally describes elderly/timid/doctor/police examples, hearing, suspicion stages, investigating smells, warning others, and communicating through characters rather than HUD. These are now the human behavior foundation in the prototype. Values below are tuning defaults, not locked design numbers.

## Responsibilities

- `game/gameplay/ai/humans/human_profile.gd`: shared editable Resource data, not mutable per-person state.
- `game/gameplay/ai/humans/profiles/*.tres`: civilian, elder, timid, doctor and police presets. Edit these in Godot. Community's exported `human_profiles` list selects the population mix; an empty list uses the actor's default profile.
- `game/gameplay/ai/humans/human_behavior.gd`: per-person state, suspicion, remembered interest/danger, stamina, routine destinations, flight decisions and recovery.
- `game/gameplay/ai/humans/human_perception.gd`: crowd-wide spatial candidate buffer, sight-cone checks, limited occlusion rays, independent odor/movement hearing, bounded warning events and ray budget.
- `game/gameplay/feedback/human_feedback.gd`: six reusable world-space text/audio slots. A generated two-note alarm is a placeholder for voiced clips. Events still affect AI outside audible/viewable feedback distance.
- `citizen_brain.gd`: dispatches humans to their behavior controller; preserves zombie roaming/hunting and the busy lock. It staggers movement as well as perception.
- `dummy_locomotion.gd`: sniff/look-around, startled/flight arm posture and tired head movement, using current dummy pivots.

No per-human Label3D, AudioStreamPlayer, timer node or frame callback is added. Profile Resources are shared; memory and RNG belong to each controller.

## Behavior

Normal people choose local walking destinations and pause. Smell or unexplained movement sounds increase suspicion. Suspicious people stop and look/sniff; doctors approach the remembered source slowly, stopping short. Timid people can flee on scent alone. Confirmed sight causes a brief startled response, an alarm, then flight. Hearing an alarm also causes flight, but does not rebroadcast another alarm, avoiding recursive warning storms.

Sight uses a facing cone and an occlusion ray; smell ignores occlusion. Sight range is 8 for civilians, 5 for elders, 7 for timid people, 8 for doctors and 12 for police. Elders have stronger smell perception, timid people have quicker panic, and police have a wider view cone, faster response and distinct warning text. Zombie actor `odor_strength` and `noise_strength` expose future serum integration; the current formula does not yet set those values.

Flight remembers danger when sight is lost. It periodically chooses an escape direction, considers alternative directions, and remembers a boundary detour instead of oscillating at corners. Running consumes stamina; tired people walk while catching their breath, then resume running. Once evidence disappears and suspicion decays, normal walking returns. A busy/turning actor cannot run AI movement during a bite or incubation. Transformed actors use zombie AI.

## Occluders and extension points

Community's `vision_collision_mask` defaults to layer 2. Add StaticBody3D/CollisionShape3D to actual sight-blocking level geometry on that layer; the floor stays on layer 1. The current decorative houses are outside the movement arena. Sight-blocking geometry is covered by a real physics-wall test. The motor still assumes the flat open arena: navigation around walk-blocking walls and crowd separation remain separate level systems.

`human_alerted(actor)` is available for a later dispatcher/reinforcement system. Police here perceive/respond/warn; doctors investigate/react. Combat-enabled variants (`bat_guard`, `armed_police`, `vaccine_medic`) now add weapons and treatment through [COMBAT_AND_SWARM.md](COMBAT_AND_SWARM.md). Original police/doctor profiles retain their existing unarmed behavior. Staged awareness and multi-body research are now implemented through OUTBREAK_PROGRESSION.md. Reinforcements, evacuation facilities and medicine supply logistics remain future world systems.

## Performance bounds and tests

Senses return at most 64 candidates, sample at most 16 entries per grid cell with a rotating offset, and test the nearest three in-cone candidates for visibility. This intentionally approximates awareness in very dense cells; exact nearest queries remain for hunting. Occlusion is limited to 48 rays per physics tick. A deferred ray never confirms sight and is retried later. Odor queries use the strongest actual indexed odor, avoiding permanently searching for hypothetical doubled range.

Warnings keep at most 24 short-lived cues; global alarm interval is at least 0.4 seconds, with per-person cooldown. Near/far perception runs every 0.2/0.5 seconds. Movement retains the existing distance rates, now with staggered phases to avoid simultaneous far updates. Default detailed NPC budget is 32; all 24 NPCs in the normal round can still use GLB when close. Distant GLB branches leave the scene tree, retain their pose/resource references, and reattach when close. They are explicitly freed with their actor.

Tests:

```text
godot --headless --path . --script res://tests/gameplay/check_human_behavior.gd
godot --headless --path . --script res://tests/performance/check_actor_grid.gd
godot --headless --path . --script res://tests/gameplay/check_zombie_ai.gd
godot --headless --path . --script res://tests/gameplay/check_player_idle.gd
godot --headless --path . --script res://tests/gameplay/check_bite.gd
godot --path . -- --play-test
```

Human tests cover normal movement, sight differences, rear-facing exclusion, real wall occlusion, smell through cover, doctor investigation, timid flight, startle, warning listeners without recursive alarm propagation, fatigue/recovery, calm return, boundary escape, ray-budget uncertainty and movement hearing. Grid tests additionally cycle GLB detachment/restoration. Play smoke sets up capture inside hunt range; humans can now legitimately escape before that range, which is verified separately.

Latest controlled benchmark (Godot 4.7.2 Compatibility, GTX 1660 Ti; 1000 actors; 600 steps, first 120 excluded; attacks/spawn excluded): mixed population simulation mean **11.40 ms**, p95 **18.19 ms**, observed graphics **59 FPS**, **934 draw calls**, zero deferred rays. Dense starting layout headless: mean **11.74 ms**, p95 **24.31 ms**. These are short machine-specific measurements; attacks, loading and other hardware need separate measurements.

```text
godot --path . --script res://tests/performance/benchmark_crowd.gd -- --long
godot --headless --path . --script res://tests/performance/benchmark_crowd.gd -- --long --dense
```
