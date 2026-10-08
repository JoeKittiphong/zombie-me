# Expanded Community and bite sequence

Normal Play now uses a 72 × 52 ground with 24 citizens, following isometric camera, and wheel zoom (18–38). Click ground to move; Escape returns to the lab. The controller clamps all actors to the expanded playable bounds. Buildings remain decorative perimeter props; no obstacle pathfinding is introduced.

Contact pursuit starts a coordinated tackle: reserve the victim immediately, lock both actors, jump forward, fall together, pulse the biting pose, then let the attacker stand. The victim remains still for 2.8 seconds, convulses for 2.5 seconds while skin turns green, and rises over 1.8 seconds with lowered head. Only after rising can it move and spread infection as AI. Zombie walking uses smaller limb swings, raised arms and body sway. Clicking during an attack cannot cancel or overwrite it; Escape can leave the scene safely.

Durations are Inspector exports on dummy_actor.tscn (still_duration, convulsion_duration, rise_duration) and outbreak.tscn (bite_hold_duration, population). Animation uses the existing GLB limb pivots; no new skeleton rig is added. Coordinated attacks are owned Tweens, so leaving the scene cancels them.

Validation: tests/gameplay/check_bite.gd checks 24 citizens, jump height, both prone bodies, repeated attack rejection, movement lock, every infection phase, lowered head, skin state, restored movement, expanded click bounds, and scene exit during another attack. The normal --play-test uses a compact two-person scenario to verify victory and result persistence.

