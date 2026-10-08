# Outbreak awareness and medical research

Initial encounters no longer give people automatic knowledge that a green/shuffling body is hostile. They become suspicious of unfamiliar appearance, smell and noise. Witnessing a visible swarm attack (through the existing sight/cone/occlusion sample) or hearing a genuine danger alarm establishes personal danger awareness; they can warn and flee. Public awareness still requires both elapsed incident time and multiple distinct victims.

## Default pacing

| Stage | Condition | Behavior |
| --- | --- | --- |
| Unaware | Before violent evidence | Suspicion/investigation; no shooting at an unfamiliar body |
| Local incidents | Witnessed attack or danger alarm | Police assess a visible threat for 1.25 s before responding; civilians can warn/flee but do not attack yet |
| Recognized outbreak | At least 20 s since the first attack AND 3 distinct attacked victims | Bat users defend themselves; armed civilians bring out their concealed pistols and can respond |
| Research | Dead zombie bodies become available | Medics carry a sample kit, approach unclaimed corpses, and study each for 6 s within 1.6 units |
| Producing medicine | 5 distinct bodies successfully studied | Shared production runs for another 12 s; no cure is usable during this period |
| Treatment available | Production completes | Surviving medics replace their kit with a syringe and receive their initial 3 doses once |

Pistols now fire at most once per 2.4 s action cooldown (previously 0.9 s), with 0.35 s windup, 0.35 s recovery and a 3.2 s magazine reload. Police and civilians require sight of a valid target; early police assessment holds facing toward it rather than accidentally fleeing out of sight. Civilians' pistol models stay hidden until public awareness. The existing unarmed police profile remains unarmed; `armed_police` carries the gun.

Numbers are prototype tuning for the requested behavior, not fixed design requirements. Change `game/gameplay/progression/default_pacing.tres` in the Inspector: awareness delay/victim count, initial response delay, required body count, study time, study/search range and production time. Gun pacing lives separately in `game/gameplay/combat/profiles/gun.tres`.

Each body can contribute only once globally, even if multiple medics study it or a person was attacked repeatedly. A claim prevents simultaneous work on the same corpse. Study starts only after arrival and a clear line to the corpse, rather than receiving research credit automatically on death. Leaving study range, losing the clear line, nearby danger, infection or death stops/resets that attempt and releases its claim. A different medic can then collect it. Living zombies and dead humans cannot supply samples. Researchers can work on different bodies concurrently.

No researcher means no further samples; merely waiting never unlocks medicine. Completing production does not end a round, and ordinary cure/containment rules still apply. The doses do not refill by repeating the unlock check. Research and stocks are per round. The shared production clock is a prototype for a later staffed lab/factory; there is no modeled building, logistics, genetic variation or persistent research tree yet.

## Ownership and bounded work

- `outbreak_progress.gd`: event-driven distinct victim/body sets, corpse claims, public awareness and one production timer. It does not scan all actors every frame.
- `pacing_settings.gd` / `default_pacing.tres`: editable pacing values, exposed as `outbreak_pacing` on Community.
- `medical_research.gd`: per-medic movement, claim and uninterrupted study time. Idle body search is limited to once per 0.5 s; study occlusion checks run every 0.25 s using the existing 24-ray combat budget.
- `actor_grid.gd`: separate dead-zombie buckets, checked center outward with at most 64 sampled bodies and 16 per cell; rotating offsets approximate target selection in dense piles. Existing hunt/cure indexes still exclude corpses.
- `human_behavior.gd`: separate personal danger knowledge from seeing an unfamiliar zombie.
- `human_combat.gd`: police assessment, delayed civilian armament, research before treatment, and one-time initial dose stock.
- `sample_kit.tscn`: editable hand attachment, parked with the GLB branch at distant visual LOD.

Community now has nine profiles; the default 24 citizens include 2–3 of each. Two-citizen play smoke keeps its original civilian/elder fixtures. The progression service uses `enabled=false` only in isolated tests of previously established combat/cure/senses, while the normal game and the dedicated progression test use real gates.

## Verify

```text
godot --headless --path . --script res://tests/gameplay/check_outbreak_progress.gd
godot --headless --path . --script res://tests/gameplay/check_combat.gd
godot --headless --path . --script res://tests/gameplay/check_human_behavior.gd
godot --headless --path . --script res://tests/gameplay/check_swarm.gd
godot --headless --path . --script res://tests/performance/check_actor_grid.gd
godot --path . -- --play-test
```

The progression test verifies initial suspicion without shooting, police confirmation/assessment and delayed shot, real perception while assessing, civilian phase requiring BOTH elapsed time and distinct victims, hidden civilian pistols before the phase, zero medicine beforehand, a real medic walking/studying through the timed routine, exclusive corpse claims, no duplicate/living-body credit, five samples plus production, interrupted research claim release, and no dose refill.
