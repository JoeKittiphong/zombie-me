# Crowd performance and player roaming

When the controlled actor is a zombie and has no movement order, it uses the same bounded shuffle and random pauses as infected NPCs. Clicking overrides roaming until arrival; automatic hunting resumes afterward. Bite/recovery locks still stop movement.

## Ownership

- `game/gameplay/ai/actor_grid.gd`: shared spatial hash for nearby human/zombie queries. Refresh every 0.15 seconds; query margin covers movement between refreshes. Exact squared distance and eligibility checks filter candidates.
- `game/gameplay/ai/citizen_brain.gd`: cached perception, staggered initial checks, autonomous roaming and pursuit. Near actors move every physics tick, middle actors every 0.066 seconds, far actors every 0.2 seconds. Perception runs every 0.2 or 0.5 seconds.
- `game/gameplay/movement/actor_motor.gd`: NPCs use direct flat-ground motion with physics collisions disabled. Player keeps floor physics. This assumes the current flat arena; slopes, obstacles and crowd avoidance require a different motor/navigation solution.
- `game/gameplay/rendering/crowd_visuals.gd`: one low-poly MultiMesh proxy batch for distant actors. Closest NPCs within 28 units retain GLB visuals, capped at 64 by default. Distant falling/rising poses are simplified and refreshed with the spatial index. Player always retains GLB visuals.
- `game/characters/dummy/dummy_actor.gd`: processing enabled only during infection, shared clothing materials, throttled hidden infection poses. Zombie completion signals replace whole-population victory scans.
- `game/characters/dummy/dummy_locomotion.gd`: throttled pose updates; hidden GLB models skip locomotion pose work.

Set `population` (default 24, inspector range 2–2000) and `detailed_actor_budget` on the Community world. Detailed nodes remain allocated behind proxies: this reduces CPU and draw work but does not eliminate per-actor node/memory costs. Dense groups in one spatial cell can still make nearby searches expensive. No crowd separation is implemented yet.

## Measurements: 2026-10-08

Godot 4.7.2 Compatibility, NVIDIA GTX 1660 Ti, 1000 evenly distributed actors, half humans/half zombies. Benchmark disables attacks and excludes spawn/loading from timing.

| Run | Mean simulation | p95 simulation | Observed graphics FPS |
| --- | ---: | ---: | ---: |
| Before optimization, headless 18 samples | 514.60 ms | 625.82 ms | — |
| After optimization, headless 18 samples | 8.84 ms | 25.18 ms | — |
| After optimization, graphics 180 steps; 30 warmup | 9.76 ms | 19.66 ms | 57 |
| All 1000 incubating/convulsing, graphics; same warmup | 1.98 ms | 7.66 ms | 60 |

Simulation timing surrounds only the world physics method; graphics FPS also reflects rendering and infection callbacks. Graphics runs reported 1762 draw calls. FPS is a short sample on this machine, not a guaranteed minimum. Attacks, spawn cost, memory and dense clustering need separate profiling before production scale.

## Reproduce

From the project directory, using your Godot executable:

```text
godot --headless --path . --script res://tests/performance/benchmark_crowd.gd
godot --path . --script res://tests/performance/benchmark_crowd.gd -- --long
godot --path . --script res://tests/performance/benchmark_crowd.gd -- --long --infection-wave
godot --headless --path . --script res://tests/performance/check_actor_grid.gd
godot --headless --path . --script res://tests/gameplay/check_player_idle.gd
godot --headless --path . --script res://tests/gameplay/check_zombie_ai.gd
godot --headless --path . --script res://tests/gameplay/check_bite.gd
godot --path . -- --play-test
```

Grid regression compares 200 indexed queries against brute-force results and checks the visual budget. Player regression verifies roaming, click priority with a nearby target, resumed roaming and movement lock. Play smoke needs a graphical window for screen-coordinate input.
