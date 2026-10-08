extends Node

const LOADING_SCREEN := preload("res://game/ui/screens/loading/loading_screen.tscn")
const LAB_SCREEN := preload("res://game/ui/screens/lab/lab_screen.tscn")
const RESEARCH_STATE := preload("res://game/data/research_state.gd")
const PAGES := {
	"STAGES": preload("res://game/ui/screens/stages/stages_screen.tscn"),
	"LAB": preload("res://game/ui/screens/formula/formula_screen.tscn"),
	"COLLECTION": preload("res://game/ui/screens/collection/collection_screen.tscn"),
	"RECORDS": preload("res://game/ui/screens/records/records_screen.tscn")
}
const OUTBREAK := preload("res://game/world/community/outbreak.tscn")
var game: Node3D
var research := RESEARCH_STATE.new()
var page: Control
var return_section := "STAGES"
var layer: CanvasLayer
var loading: Control
var menu: Control
var progress: ProgressBar
var dialog: AcceptDialog
var elapsed := 0.0
var ready_to_enter := false

func _ready() -> void:
	if "--smoke-test" in OS.get_cmdline_user_args() or "--play-test" in OS.get_cmdline_user_args():
		research.save_path = "user://research_ui_smoke.json"
	else:
		research.load_data()
	layer = CanvasLayer.new()
	add_child(layer)
	menu = LAB_SCREEN.instantiate()
	layer.add_child(menu)
	menu.section_requested.connect(open_section)
	menu.hide()
	dialog = AcceptDialog.new()
	dialog.min_size = Vector2i(520, 190)
	layer.add_child(dialog)
	loading = LOADING_SCREEN.instantiate()
	layer.add_child(loading)
	progress = loading.get_node("Track/Progress")
	if "--smoke-test" in OS.get_cmdline_user_args() or "--play-test" in OS.get_cmdline_user_args():
		if "--play-test" in OS.get_cmdline_user_args():
			run_play_test()
		else:
			run_smoke_test()

func open_section(section: String) -> void:
	if section == "PLAY":
		start_play()
		return
	if is_instance_valid(page):
		return
	return_section = section
	menu.hide()
	page = PAGES[section].instantiate()
	page.state = research
	page.back_requested.connect(close_page)
	layer.add_child(page)

func start_play() -> void:
	if is_instance_valid(game):
		return
	menu.hide()
	game = OUTBREAK.instantiate()
	game.formula = research.quantities.duplicate()
	if "--play-test" in OS.get_cmdline_user_args():
		game.population = 2
	game.exited.connect(stop_play)
	game.completed.connect(func(result: Dictionary):
		var error := research.record_experiment(result)
		game.record_saved = error == OK
		if error != OK:
			game.status.text = "Outbreak complete. Record could not be saved."
	)
	add_child(game)

func stop_play() -> void:
	if is_instance_valid(game):
		game.queue_free()
		game = null
	menu.show()
	menu.buttons["PLAY"].grab_focus()

func close_page() -> void:
	if not is_instance_valid(page):
		return
	page.hide()
	page.queue_free()
	page = null
	menu.show()
	menu.buttons[return_section].grab_focus()
func _process(delta: float) -> void:
	if ready_to_enter:
		return
	elapsed += delta
	# Intro transition; connect resource loading here when gameplay content is added.
	progress.value = minf(elapsed / 2.4 * 100, 100)
	if elapsed >= 2.4:
		ready_to_enter = true
		menu.show()
		var tween := create_tween()
		tween.tween_property(loading, "modulate:a", 0.0, 0.5)
		tween.tween_callback(loading.hide)

func run_smoke_test() -> void:
	if "--capture-loading" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.8).timeout
		await capture("loading-preview.png")
	await get_tree().create_timer(3.2).timeout
	assert(ready_to_enter and menu.visible and not loading.visible)
	if "--capture-preview" in OS.get_cmdline_user_args():
		await capture("main-menu-preview.png")
	for section in ["STAGES", "LAB", "COLLECTION", "RECORDS", "PLAY"]:
		var button: Button = menu.buttons[section]
		var move := InputEventMouseMotion.new()
		move.position = button.global_position + button.size / 2
		Input.parse_input_event(move)
		await get_tree().create_timer(0.3).timeout
		assert(button.hovered and button.scale.x > 1.0)
		if section == "LAB" and "--capture-preview" in OS.get_cmdline_user_args():
			await capture("lab-hover-preview.png")
		var click := InputEventMouseButton.new()
		click.position = move.position
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		Input.parse_input_event(click)
		click = click.duplicate()
		click.pressed = false
		Input.parse_input_event(click)
		await get_tree().create_timer(0.3).timeout
		if section == "PLAY":
			assert(is_instance_valid(game) and not menu.visible)
			stop_play()
		else:
			assert(is_instance_valid(page) and page.visible and not menu.visible)
			if section == "LAB":
				assert(page.plus_buttons[0].disabled)
				page.adjust(0, 1)
				assert(research.quantities[0] == 4)
				page.minus_buttons[0].pressed.emit()
				assert(research.quantities[0] == 3)
				page.formula_name.text = "Smoke formula"
				page.save_button.pressed.emit()
				assert(research.formulas.size() == 1)
				var restored := RESEARCH_STATE.new()
				restored.save_path = research.save_path
				restored.load_data()
				assert(restored.formulas.size() == 1 and restored.quantities[0] == 3)
			if section == "COLLECTION":
				page.item_buttons[1].pressed.emit()
				assert(page.detail_name.text == "CATALYST")
			if section == "RECORDS":
				assert(page.rows.size() == 1)
				page.tabs[1].pressed.emit()
				assert(page.empty.visible and page.rows.is_empty())
				page.tabs[0].pressed.emit()
			if "--capture-preview" in OS.get_cmdline_user_args():
				await get_tree().create_timer(0.25).timeout
				await capture(section.to_lower() + "-preview.png")
			if section == "COLLECTION":
				var escape := InputEventKey.new()
				escape.keycode = KEY_ESCAPE
				escape.pressed = true
				Input.parse_input_event(escape)
			else:
				page.back_button.pressed.emit()
			await get_tree().process_frame
			assert(not is_instance_valid(page) and menu.visible)
	DirAccess.remove_absolute(research.save_path)
	print("Research UI smoke test passed: four pages, navigation, formula adjustments, save/reload, collection inspection and record tabs.")
	get_tree().quit()

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Users/Zylaah/programmer/godot/Zobies me/" + filename)



func run_play_test() -> void:
	await get_tree().create_timer(3.2).timeout
	open_section("PLAY")
	await get_tree().create_timer(0.2).timeout
	var point := Vector3(-3,0,2)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.camera.unproject_position(point)
	Input.parse_input_event(click)
	await get_tree().create_timer(0.1).timeout
	assert(game.destination.distance_to(point) < 0.15)
	var before: float = game.player.position.distance_to(point)
	await get_tree().create_timer(0.6).timeout
	assert(game.player.position.distance_to(point) < before)
	await get_tree().create_timer(3.5).timeout
	assert(game.player.zombie)
	if "--capture-preview" in OS.get_cmdline_user_args():
		await capture("play-preview.png")
	# Force a nearly empty chase to verify the stop/recovery branch, then perform normal clicks.
	game.stamina = 0.01
	game.hunt_target = game.citizens[0]
	game.manual_grace = 0
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(game.exhausted and game.hunt_target == null)
	await get_tree().create_timer(2.5).timeout
	assert(game.stamina > 0)
	for index in range(2):
		if game.finished:
			break
		if game.citizens[index].infected:
			continue
		for recovery in range(100):
			if not game.player.busy:
				break
			await get_tree().create_timer(0.1).timeout
		assert(not game.player.busy)
		# Humans now detect danger beyond hunt range; isolate capture from escape here.
		# Dedicated human tests exercise escape, perception and investigation.
		game.player.position = game.citizens[index].position.move_toward(Vector3.ZERO,2.0)
		game.hunt_target = null
		game.stamina = 5.0
		game.exhausted = false
		game.manual_grace = 1.0
		game._process(1.0)
		click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = game.camera.unproject_position(game.citizens[index].position)
		Input.parse_input_event(click)
		for step in range(20):
			await get_tree().create_timer(0.5).timeout
			if game.citizens[index].infected or game.finished:
				break
		if not game.citizens[index].infected:
			print("Capture fixture: player=",game.player.position," target=",game.citizens[index].position," destination=",game.destination," move=",game.has_move_order," stamina=",game.stamina," exhausted=",game.exhausted," busy=",game.player.busy," human_state=",game.brains[index].human.state)
		assert(game.citizens[index].infected)
	for step in range(24):
		if game.finished:
			break
		await get_tree().create_timer(0.5).timeout
	assert(game.finished and research.experiments.size() == 1)
	var restored := RESEARCH_STATE.new()
	restored.save_path = research.save_path
	restored.load_data()
	assert(restored.experiments.size() == 1)
	if "--capture-preview" in OS.get_cmdline_user_args():
		await capture("play-result-preview.png")
	game.back_button.pressed.emit()
	await get_tree().process_frame
	assert(not is_instance_valid(game) and menu.visible)
	open_section("RECORDS")
	page.show_experiments()
	assert(page.rows.size() == 1)
	if "--capture-preview" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.25).timeout
		await capture("experiment-preview.png")
	close_page()
	open_section("PLAY")
	await get_tree().create_timer(0.2).timeout
	assert(game.citizens.size() == 2 and not game.player.infected and game.stamina == 5.0)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await get_tree().process_frame
	assert(not is_instance_valid(game) and menu.visible)
	DirAccess.remove_absolute(research.save_path)
	print("Play test passed: projected mouse ray, movement, mutation, exhaustion/recovery, infection, victory, persisted result and return to Lab.")
	get_tree().quit()
