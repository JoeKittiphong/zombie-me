extends "res://game/ui/components/research_page/research_page.gd"

var details: Label
var active_entries: Array = []
var history_mode := false
var rows: Array[Button] = []
var tabs: Array[Button] = []
var list: VBoxContainer
var empty: Label

func build_page() -> void:
	heading("RECORDS", "Research notes, saved formulas, and experiment history.",3)
	tabs.append(action(content,"SAVED FORMULAS",Rect2(54,207,260,45),true))
	tabs.append(action(content,"EXPERIMENT HISTORY",Rect2(330,207,275,45)))
	tabs[0].pressed.connect(show_formulas)
	tabs[1].pressed.connect(show_experiments)
	var left := panel(content,Rect2(54,272,650,380))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(18,18)
	scroll.size = Vector2(614,344)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	empty = label(left,"",Rect2(30,70,585,245),22,Color("c2d1c4"))
	var right := panel(content,Rect2(738,272,487,380))
	art(right,3,Rect2(27,24,116,120))
	details = label(right,"",Rect2(26,167,435,186),19)
	show_formulas()

func clear_rows() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	rows.clear()

func show_formulas() -> void:
	history_mode = false
	active_entries = state.formulas
	set_tab(0)
	clear_rows()
	empty.visible = state.formulas.is_empty()
	empty.text = "No formulas saved yet.\n\nCreate your first formula in the Lab."
	details.text = "Select a saved formula to inspect its ingredients.\n\nPrepared formulas are separate from completed experiments."
	for index in range(state.formulas.size()):
		var entry: Dictionary = state.formulas[index]
		var button := action(list,entry.name + "\n" + entry.date.replace("T","  "),Rect2(0,0,600,74))
		button.custom_minimum_size = Vector2(590,74)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(inspect.bind(index))
		rows.append(button)
	if not rows.is_empty():
		inspect(0)

func inspect(index: int) -> void:
	var entry: Dictionary = active_entries[index]
	details.text = "%s\n\nBase serum: %s units\nCatalyst: %s units\nStabilizer: %s units\n\nPrepared for: %s" % [entry.name,entry.dose[0],entry.dose[1],entry.dose[2],entry.get("stage","COMMUNITY")]

	if history_mode:
		details.text = "%s\n%s\n\nDose: %s / %s / %s\nStage: %s\nTime: %s seconds\nInfected: %s" % [entry.name,entry.get("outcome","Completed"),entry.dose[0],entry.dose[1],entry.dose[2],entry.get("stage","COMMUNITY"),entry.get("duration",0),entry.get("infected",0)]

func show_experiments() -> void:
	history_mode = true
	active_entries = state.experiments
	set_tab(1)
	clear_rows()
	empty.visible = state.experiments.is_empty()
	empty.text = "No experiments recorded.\n\nComplete an experiment to add your first research record."
	details.text = "EXPERIMENT HISTORY\n\nNo outbreak results or mutation discoveries have been recorded yet."


	for index in range(state.experiments.size()):
		var entry: Dictionary = state.experiments[index]
		var button := action(list,entry.name + "\n" + entry.date.replace("T","  "),Rect2(0,0,600,74))
		button.custom_minimum_size = Vector2(590,74)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(inspect.bind(index))
		rows.append(button)
	if not rows.is_empty():
		inspect(0)

func set_tab(selected: int) -> void:
	for index in range(tabs.size()):
		tabs[index].add_theme_stylebox_override("normal",box(Color("3c6254") if index == selected else Color("273e48")))


