extends RefCounted

var save_path := "user://research_ui.json"
const COMPOUNDS := [
	{"name": "BASE SERUM", "description": "The foundation of every formula.", "color": "a2d39a"},
	{"name": "CATALYST", "description": "An experimental additive for future mutation research.", "color": "e9b86c"},
	{"name": "STABILIZER", "description": "A balancing agent for future serum experiments.", "color": "94c7db"}
]
var selected_stage := "COMMUNITY"
var quantities := [4, 3, 3]
var formulas: Array = []
var experiments: Array = []

func load_data() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary or parsed.get("version") != 1:
		return
	var saved_quantities: Variant = parsed.get("quantities", [])
	if saved_quantities is Array and saved_quantities.size() == 3:
		var candidate: Array = []
		for value in saved_quantities:
			if not (value is int or value is float):
				return
			candidate.append(clampi(int(value), 0, 10))
		if candidate[0] + candidate[1] + candidate[2] <= 10:
			quantities = candidate
	var saved_formulas: Variant = parsed.get("formulas", [])
	if saved_formulas is Array:
		for entry in saved_formulas:
			if entry is Dictionary and entry.get("name") is String and entry.get("dose") is Array and entry.dose.size() == 3 and entry.get("date") is String:
				formulas.append(entry)

	var saved_experiments: Variant = parsed.get("experiments", [])
	if saved_experiments is Array:
		for entry in saved_experiments:
			if entry is Dictionary and entry.get("name") is String and entry.get("dose") is Array and entry.dose.size() == 3 and entry.get("date") is String:
				experiments.append(entry)

func persist() -> Error:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 1, "quantities": quantities, "formulas": formulas, "experiments": experiments}, "\t"))
	return file.get_error()

func save_formula(formula_name: String) -> Error:
	var entry := {"name": formula_name.strip_edges(), "dose": quantities.duplicate(), "date": Time.get_datetime_string_from_system(), "stage": selected_stage}
	formulas.push_front(entry)
	var result := persist()
	if result != OK:
		formulas.pop_front()
	return result


func record_experiment(result: Dictionary) -> Error:
	experiments.push_front(result.duplicate(true))
	var error := persist()
	if error != OK:
		experiments.pop_front()
	return error

