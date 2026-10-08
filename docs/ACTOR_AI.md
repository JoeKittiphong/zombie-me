# Actor movement and citizen AI

Responsibility boundaries:

- game/gameplay/ai/citizen_brain.gd: per-citizen decisions. Human wandering/fleeing; zombie recovering, roaming and hunting. Chooses bounded random waypoints, short pauses and a new waypoint if stuck. Nearby eligible humans take priority over roaming.
- game/gameplay/movement/actor_motor.gd: velocity, floor collision, world bounds and facing; also invokes locomotion. Respects the actor busy lock.
- game/characters/dummy/dummy_locomotion.gd: human walk and zombie shuffle poses for current GLB pivots. Owns animation phase per actor. Replace this layer with AnimationTree when a rigged model is available.
- game/characters/dummy/dummy_actor.gd + dummy_actor.tscn: appearance, infection timeline, body/collider and composition of the movement driver.
- game/world/community/outbreak.gd: round orchestration, population, player input, shared swarm captures, result recording and camera. Owns one citizen brain per NPC, including after the result screen so surviving zombie visuals keep walking.

Zombie roaming is 1.15 units/second with 3–7-unit waypoints. Hunt speed remains 3.6 and detection radius 6. Busy/infection recovery prevents AI movement until the rise completes. Infected/busy humans are normally excluded; a shared capture explicitly remains eligible during its join window. Dead and temporarily immune actors are excluded. Parameters currently live at the top of citizen_brain.gd. The flat world still uses direct steering, not obstacle navigation.

Regression: tests/gameplay/check_zombie_ai.gd verifies actual physics movement after infection, pursuit and target loss, animation updates, busy lock, boundary recovery and post-round movement. Existing --play-test checks complete rounds and persistence; check_bite.gd checks attack/infection timing.


Crowd scheduling, spatial queries, player roaming, rendering budgets and measured benchmarks: see [CROWD_PERFORMANCE.md](CROWD_PERFORMANCE.md). NPC motor uses flat-ground direct motion; only the player keeps floor physics. Runtime NPC updates enter through brain.tick(delta), which schedules brain.step(delta).

Human routine, senses, suspicion, role profiles, flight and warning behavior: [HUMAN_BEHAVIOR.md](HUMAN_BEHAVIOR.md).

Human weapons, treatment and shared captures: [COMBAT_AND_SWARM.md](COMBAT_AND_SWARM.md).
