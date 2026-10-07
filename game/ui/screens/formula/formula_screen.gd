extends "res://game/ui/components/research_page/research_page.gd"

var values: Array[Label] = []
var plus_buttons: Array[Button] = []
var minus_buttons: Array[Button] = []
var total: Label
var status: Label
var formula_name: LineEdit
var save_button: Button

func build_page() -> void:
	heading("LAB / SERUM FORMULA", "Prepare and save a formula before your next experiment.",1)
	for index in range(3):
		var row := panel(content,Rect2(54,218+index*126,700,108))
		label(row,state.COMPOUNDS[index].name,Rect2(22,16,330,32),21,Color(state.COMPOUNDS[index].color))
		label(row,state.COMPOUNDS[index].description,Rect2(22,52,430,45),15,Color("acc0bf"))
		var minus := action(row,"-",Rect2(477,29,48,48))
		minus.pressed.connect(adjust.bind(index,-1))
		minus_buttons.append(minus)
		values.append(label(row,str(state.quantities[index]),Rect2(545,36,50,40),26))
		var plus := action(row,"+",Rect2(617,29,48,48))
		plus.pressed.connect(adjust.bind(index,1))
		plus_buttons.append(plus)
	var summary := panel(content,Rect2(788,218,437,434))
	art(summary,1,Rect2(131,20,175,180))
	total = label(summary,"",Rect2(28,210,390,42),24)
	label(summary,"FORMULA NAME",Rect2(28,270,370,28),13,Color("b9cec4"))
	formula_name = LineEdit.new()
	formula_name.position = Vector2(28,305)
	formula_name.size = Vector2(381,44)
	formula_name.placeholder_text = "Experiment 001"
	formula_name.max_length = 40
	summary.add_child(formula_name)
	save_button = action(summary,"SAVE FORMULA",Rect2(28,368,381,44),true)
	save_button.pressed.connect(save_formula)
	status = label(content,"Saved formulas appear in Records.",Rect2(54,620,700,65),16,Color("abc3bb"))
	refresh()

func adjust(index: int, amount: int) -> void:
	var sum := int(state.quantities[0]+state.quantities[1]+state.quantities[2])
	if amount > 0 and sum >= 10:
		return
	state.quantities[index] = clampi(state.quantities[index]+amount,0,10)
	refresh()

func refresh() -> void:
	var sum := int(state.quantities[0]+state.quantities[1]+state.quantities[2])
	for index in range(3):
		values[index].text = str(state.quantities[index])
		minus_buttons[index].disabled = state.quantities[index] == 0
		plus_buttons[index].disabled = sum >= 10
	total.text = "TOTAL DOSE  /  %d of 10 units" % sum
	save_button.disabled = sum == 0

func save_formula() -> void:
	var title := formula_name.text.strip_edges()
	if title.is_empty():
		title = "Experiment %03d" % (state.formulas.size()+1)
	var result: Error = state.save_formula(title)
	status.text = "Saved: " + title + "\nOpen Records to inspect this formula." if result == OK else "Could not save the formula. Please try again."

