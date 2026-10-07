# Research submenus

Stages, Lab formula preparation, Collection, and Records are separate scenes under game/ui/screens. They share research_page.gd for layout, styling, navigation, transitions, and illustration assets. Back and Escape return to the originating menu button.

Stages currently offers Community; the other planned locations remain locked. Lab allows allocation of up to ten units across three provisional compounds. Save Formula stores named preparation records locally in user://research_ui.json. On restart, formulas and the last saved quantities are restored. Records separates saved preparations from completed experiment history. No completed experiment results are fabricated. Play is unchanged.

Compound names and the ten-unit dose are provisional UI data pending gameplay design. No mutation mechanics or outbreak simulation are implemented by this change.

Validation: -- --smoke-test --capture-preview checks menu mouse events, navigation, Escape, allocation limit, formula save and reload, collection inspection, records tabs, and captures all four pages. Smoke data uses a separate file and is removed after testing.
