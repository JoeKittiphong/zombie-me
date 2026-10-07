extends "res://game/ui/components/research_page/research_page.gd"

var selection: Label
var choose: Button
var stage_buttons: Array[Button] = []

func build_page() -> void:
	heading("STAGES", "Choose the location of your next outbreak.", 0)
	var locations := ["COMMUNITY", "SHOPPING MALL", "SCHOOL", "HOSPITAL", "TRAIN STATION"]
	for index in range(locations.size()):
		var button := action(content, locations[index] + ("   /   SELECTED" if index == 0 else "   /   LOCKED"), Rect2(54,218+index*82,448,66), index == 0)
		button.disabled = index > 0
		button.tooltip_text = "This location is not unlocked yet." if index > 0 else "Select Community"
		button.pressed.connect(select_community)
		stage_buttons.append(button)
	var details := panel(content,Rect2(535,218,690,394))
	art(details,0,Rect2(30,32,190,205))
	label(details,"COMMUNITY",Rect2(246,35,400,44),28)
	label(details,"The first outbreak site.\n\nA neighborhood where everyday life continues until your experiment begins.",Rect2(246,100,390,176),20)
	label(details,"FIRST OUTBREAK SITE",Rect2(32,280,630,35),16,Color("b7d5ac"))
	selection = label(details,"Current selection: " + state.selected_stage,Rect2(32,330,620,35),18)
	choose = action(content,"SELECT COMMUNITY",Rect2(935,636,290,48),true)
	choose.pressed.connect(select_community)

func select_community() -> void:
	state.selected_stage = "COMMUNITY"
	selection.text = "Community selected for the next experiment."

