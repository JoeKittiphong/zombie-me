# Human combat and shared zombie captures

Community now mixes five existing civilian perception profiles with `bat_guard`, `armed_police`, `vaccine_medic` and `armed_civilian`. At the default 24 citizens, each of nine profiles occurs two or three times. Awareness and medicine are staged as described in [OUTBREAK_PROGRESSION.md](OUTBREAK_PROGRESSION.md). Population=2 keeps the two original civilian/elder fixtures. The scientist still enters human, mutates after serum incubation, and uses click-to-move plus automatic close-range hunting.

## Behavior and prototype values

| Equipment | Behavior | Initial tuning |
| --- | --- | --- |
| Baseball bat | Attacks a seen zombie; a forward swing can hit up to three nearby zombies. Knockback and stun interrupt a grapple. | 1.9 range, 30 damage, 0.18 s windup, 1.1 s cooldown, 1.1 push, 0.55 s stun |
| Pistol | Faces a seen zombie, retreats inside its preferred distance, pauses to shoot, reloads an empty magazine while retreating. Retreat uses human stamina. | 10 range, 5 preferred distance, 28 damage, 2.4 s cooldown, 0.35 s windup, 6 rounds, 3.2 s reload |
| Vaccine syringe | Searches locally for a living infected person, approaches and administers a dose. Can treat latent infection or a transformed zombie after grappling ends. | 6 search range, 1.7 injection range, 3 doses, 1 s cure, 8 s temporary immunity |

These values are prototype tuning, not numbers confirmed by the design chat. The chat establishes police retreat/fire behavior and vaccination returning infected people to humans. Merely having a vaccine or curing one person does not end a round.

Every character has 100 health. Human weapons damage zombies only. Death leaves a prone corpse and removes it from perception/hunt/cure indexes. If Patient Zero dies, the experiment ends. If no living infected person remains after the outbreak starts, containment ends the experiment. A cured player does not automatically receive serum again. Success requires every living citizen to be a zombie, with Patient Zero alive and transformed. Saved results include the corresponding outcome.

Treatment kills an in-progress serum Tween or infection timeline, restores the human appearance and equipment, resets human danger memory, and decrements the transformed count when appropriate. Ammunition and doses persist through infection/cure; they are not reset by treatment. Immunity prevents bites until it expires. Multi-body research and a production delay now gate medicine; see [OUTBREAK_PROGRESSION.md](OUTBREAK_PROGRESSION.md). Host switching, physical hospital/lab facilities and supply logistics remain future systems.

## Shared victim ownership

`swarm_attacks.gd` owns one Capture per victim and one membership per attacker. The first attacker freezes the victim; nearby zombie AI can continue selecting that same victim while the capture accepts joins. Up to eight attackers take distinct ring slots and jump inward. A capture accepts joins for at most two seconds; later arrivals extend the hold so they can complete the bite.

The victim is exposed only when an attacker reaches biting contact, approximately 0.72 seconds after its jump begins. Interrupting all attackers before contact releases a healthy victim. After contact, stopping the attackers releases the victim into one incubation timeline. Joining attackers never restart that timeline. All members recover upright and unlock movement after the shared bite ends. Capacity and time limits stop indefinite dogpiles. Remaining zombies can pursue another eligible target.

The coordinator runs once per physics tick. It uses shared math-based pose timelines instead of an individual Tween chain per biting zombie. Corpse/cure/interruption paths release memberships, and round completion stops outstanding captures.

## Files to extend

- `game/gameplay/combat/combat_profile.gd` and `profiles/*.tres`: range, damage, windup, cooldown, knockback, magazine, reload, doses and treatment/immunity values.
- `game/gameplay/ai/humans/profiles/*.tres`: mix civilian senses with a combat profile; `outbreak.gd` exposes the spawn profile list in the Inspector.
- `game/gameplay/ai/humans/human_combat.gd`: one person's target, windup, ammunition, doses and action state. Uses a WeakRef to its human controller to avoid a reference cycle.
- `game/gameplay/combat/combat_system.gd`: validates range and sight, applies melee/gun hits or treatment, and interrupts shared captures.
- `game/gameplay/combat/swarm_attacks.gd`: capture ownership, ring slots, shared bite timeline and rescue/cleanup.
- `game/characters/equipment/{bat,gun,vaccine}.tscn`: editable low-poly props attached to the GLB hand pivot. They park with the detached GLB branch when a distant actor uses a proxy. No prop creates a physics body.
- `game/characters/dummy/dummy_actor.gd`: health, stun, immunity, death, infection/cure and equipment composition. `dummy_locomotion.gd` invokes equipment poses.
- `game/gameplay/feedback/combat_effects.gd`: reusable tracer/impact/treatment visuals. The underlying dummy GLB remains unchanged.

The open arena still uses direct steering. There is no obstacle navigation or general crowd separation. Ring slots organize the capture itself; the rest of the crowd can overlap. Gunshots use hitscan plus a visual tracer, without ballistic projectiles. Props and animations remain dummy assets; separate gun/melee sound samples and a rigged animation system are future asset work.

## Work bounds

Combat reuses the human sight samples and staggered near/far AI updates. Medics query an infected spatial bucket at most every 0.35 seconds, including when no patient is available. Exact target eligibility is checked again when an action lands. Combat shares a maximum of 24 occlusion rays per physics tick, in addition to the existing 48 perception rays. If that action budget is exhausted, the action does not land; the normal cooldown schedules a later retry.

Bat cleaves inspect the bounded spatial candidate sample and cap hits at three. The VFX service preallocates 24 tracers and 24 flashes, reuses their meshes, and stops processing when idle. NPC floor collisions remain disabled. Existing 32-model GLB budget, detached distant branches and a MultiMesh proxy batch remain active. Infection/cure processing is enabled only for an active timeline.

The benchmark with `--combat` enables actual weapons, doses, captures and deaths. Its population evolves, so comparisons with the older attacks-disabled benchmark do not measure an identical workload. Simulation timing surrounds the world physics method and excludes spawn, rendering and separate infection/cure callbacks; observed graphics FPS includes those costs. Normal end-of-round checks are suppressed only in the benchmark world.

## Verification

```text
godot --headless --path . --script res://tests/gameplay/check_combat.gd
godot --headless --path . --script res://tests/gameplay/check_cure_round.gd
godot --headless --path . --script res://tests/gameplay/check_swarm.gd
godot --headless --path . --script res://tests/gameplay/check_bite.gd
godot --path . --script res://tests/gameplay/check_swarm.gd -- --capture-preview
godot --path . --script res://tests/gameplay/check_combat_visual.gd
godot --path . -- --play-test
godot --path . --script res://tests/performance/benchmark_crowd.gd -- --long --combat
godot --headless --path . --script res://tests/performance/benchmark_crowd.gd -- --long --combat --dense
```

Combat tests cover delayed hits, knockback/stun, ammunition/reload/retreat, a real occluding wall, latent/zombie treatment, immunity, dose consumption and primary death. Cure-round tests cover count rollback, reinfection, partial treatment continuing a round, containment, and serum not being injected again. Swarm tests cover eight joins, a rejected ninth, shared target eligibility, actual AI joining the same victim, jumps/prone biting, exactly one transformation, and rescue before/after contact. Existing human, zombie, player, grid, model, paired-bite and full play/persistence checks remain applicable.

## Historical measurement on 2026-10-08 (before staged awareness/research)

Godot 4.7.2 Compatibility, NVIDIA GTX 1660 Ti; 1000 actors, initially half zombies/half humans; 600 simulation steps, first 120 excluded. Final graphical active-combat run: mean world simulation **10.04 ms**, p95 **20.42 ms**, observed **49 FPS**, **943 draw calls**. During the run: 106 shots, 133 bat hits, 44 vaccine doses, 1146 pounce participants, largest capture 8. No deferred perception rays and no cleanup leak warning in that run.

An earlier dense-start headless run of the combat build measured mean **9.24 ms**, p95 **19.05 ms**, with 186 shots, 393 bat hits, 116 doses and 1508 pounce participants. This was before the final no-target medic search throttle; it is a separate evolving workload rather than an equal-state comparison. Earlier graphical combat samples observed 54–59 FPS. CPU spikes, active population, frame timing and equipment targets vary between runs. These samples do not establish a guaranteed 60 FPS or a production worst case; spawn cost, memory, other machines and crowded obstacle navigation still need profiling.