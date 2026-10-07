extends "res://game/ui/components/research_page/research_page.gd"

var detail_name: Label
var detail_text: Label
var item_buttons: Array[Button] = []

func build_page() -> void:
	heading("COLLECTION", "Your available compounds and future discoveries.",2)
	for index in range(3):
		var card := panel(content,Rect2(54+index*248,218,228,296))
		art(card,1,Rect2(40,20,148,143))
		label(card,state.COMPOUNDS[index].name,Rect2(16,176,196,42),19,Color(state.COMPOUNDS[index].color))
		var button := action(card,"INSPECT",Rect2(16,235,196,43))
		button.pressed.connect(inspect.bind(index))
		item_buttons.append(button)
	var detail := panel(content,Rect2(822,218,403,434))
	art(detail,2,Rect2(132,20,140,152))
	detail_name = label(detail,"",Rect2(24,191,355,42),24)
	detail_text = label(detail,"",Rect2(24,253,355,157),18,Color("b7cbc3"))
	var locked := panel(content,Rect2(54,540,724,112))
	label(locked,"MUTATIONS  /  UNDISCOVERED",Rect2(22,18,670,35),22)
	label(locked,"Run experiments to discover new mutations.",Rect2(22,63,680,30),16,Color("a6b9b9"))
	inspect(0)

func inspect(index: int) -> void:
	detail_name.text = state.COMPOUNDS[index].name
	detail_name.add_theme_color_override("font_color",Color(state.COMPOUNDS[index].color))
	detail_text.text = state.COMPOUNDS[index].description + "\n\nAvailable in the Lab."

