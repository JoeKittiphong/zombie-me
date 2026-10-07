extends Control

signal section_requested(section: String)

const BUTTON := preload("res://game/ui/components/lab_button/lab_button.gd")
const ART := preload("res://assets/textures/ui/lab/lab_elements.png")
const BACKGROUND := preload("res://assets/textures/ui/lab/lab_background.png")
var buttons: Dictionary = {}
var artboard: Control

func _ready() -> void:
	artboard = Control.new()
	artboard.size = Vector2(1280, 720)
	add_child(artboard)
	resized.connect(fit_artboard)
	fit_artboard()
	var background := TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artboard.add_child(background)
	var title := Label.new()
	title.text = "I MADE\nZOMBIES"
	title.position = Vector2(928, 58)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("efe8ce"))
	title.add_theme_color_override("font_shadow_color", Color("111b22"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	artboard.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "CONTAINMENT ROOM  /  01"
	subtitle.position = Vector2(930, 176)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("aec5bc"))
	artboard.add_child(subtitle)
	var entries := ["STAGES", "LAB", "COLLECTION", "RECORDS", "PLAY"]
	# Measured regions preserve each complete silhouette in the generated atlas.
	var regions := [Rect2(0, 100, 480, 510), Rect2(480, 130, 380, 470), Rect2(865, 100, 390, 500), Rect2(10, 630, 450, 530), Rect2(465, 640, 400, 500)]
	for index in range(entries.size()):
		var atlas := AtlasTexture.new()
		atlas.atlas = ART
		atlas.region = regions[index]
		atlas.filter_clip = true
		var button := Button.new()
		button.set_script(BUTTON)
		button.position = Vector2(915, 225 + index * 87)
		button.size = Vector2(325, 74)
		artboard.add_child(button)
		button.configure(entries[index], atlas, index == 4)
		button.activated.connect(func(section: String): section_requested.emit(section))
		buttons[entries[index]] = button
	var caption := Label.new()
	caption.text = "RESEARCH DIVISION  /  I MADE ZOMBIES"
	caption.position = Vector2(34, 680)
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("ced8ce"))
	caption.add_theme_color_override("font_shadow_color", Color("15222b"))
	caption.add_theme_constant_override("shadow_offset_y", 2)
	artboard.add_child(caption)

func fit_artboard() -> void:
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	artboard.scale = Vector2.ONE * factor
	artboard.position = (size - Vector2(1280, 720) * factor) / 2.0


