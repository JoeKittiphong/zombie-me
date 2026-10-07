# Lab menu prototype

The current laboratory menu uses a generated painted background and a transparent 3 × 2 illustration atlas, pending production 3D models. Source image outputs are retained in the Codex generated_images directory; runtime assets are copied into assets/textures/ui/lab.

Scenes: game/ui/screens/lab/lab_screen.tscn and game/ui/screens/loading/loading_screen.tscn.
Reusable button: game/ui/components/lab_button/lab_button.gd.

Hover/focus: the button grows and the illustration tilts and grows. Click: squash, rebound, then emit section_requested. Repeated clicks during the click tween are ignored. Leaving hover restores the resting state.

Stages, Lab, Collection, Records and Play currently open descriptive placeholders. Gameplay and persistent research records remain future work.

Validation: launch Godot with -- --smoke-test --capture-preview to check loading transition, inject mouse hover/click events into all five menu buttons, and capture resting and hover previews.
