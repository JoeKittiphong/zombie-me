# Play / Community dummy prototype

Launch from the main menu with Play. Left-click ground to set a movement destination; the mint ring marks the destination. Escape returns to the Lab. The two citizens wander slowly, flee from nearby zombies, and preserve their clothing when infected.

Play immediately applies the current Lab quantities. The scientist begins human and visibly turns green after a short incubation, without a displayed countdown. Incubation is provisionally 2.5 + stabilizer units × 0.2 seconds. Once transformed, entering a 5-unit hunt radius triggers automatic pursuit and contact infection. Pursuit consumes stamina; exhaustion cancels the chase, and walking/resting recovers it. A new click interrupts pursuit briefly, allowing repositioning. Infected citizens turn into AI zombies and pursue remaining humans. Infecting both ends the round and saves its formula, duration and result into Experiment History.

The scene is a flat, unobstructed test area. Decorative buildings lie beyond the walking area; pathfinding around obstacles, real models, vaccine/death rules, host switching, day/night simulation and full formula mechanics are future work. The current human threat detection is proximity-based.

Files: game/world/community/outbreak.tscn + outbreak.gd; reusable dummy body under game/characters/dummy/dummy_actor.gd. Integration in game/app/main.gd and game/data/research_state.gd.

Validation: -- --play-test --capture-preview checks screen-space mouse raycast and movement, human-to-zombie transition, stamina exhaustion/recovery, pursuit/contact infection, victory, persistence/reload, Records, fresh replay and Escape. -- --smoke-test checks menu/submenu regression. Tests use their own save file.
