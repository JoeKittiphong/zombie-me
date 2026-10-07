extends Control

signal back_requested

const BACKGROUND := preload("res://assets/textures/ui/lab/lab_background.png")
const ICONS := preload("res://assets/textures/ui/lab/lab_elements.png")
const REGIONS := [Rect2(0,100,480,510), Rect2(480,130,380,470), Rect2(865,100,390,500), Rect2(10,630,450,530)]
var state: RefCounted
var canvas: Control
var content: Control
var back_button: Button

func _ready() -> void:
	canvas = Control.new()
	canvas.size = Vector2(1280, 720)
	add_child(canvas)
	resized.connect(fit_canvas)
	fit_canvas()
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = BACKGROUND
	image.size = canvas.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(image)
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.055,0.075,0.85)
	shade.size = canvas.size
	canvas.add_child(shade)
	back_button = action(canvas, "<  BACK TO LAB", Rect2(54, 35, 180, 42))
	back_button.pressed.connect(func(): back_requested.emit())
	content = Control.new()
	canvas.add_child(content)
	build_page()
	modulate.a = 0.0
	create_tween().tween_property(self,"modulate:a",1.0,0.2)
	back_button.grab_focus()

func build_page() -> void:
	pass

func fit_canvas() -> void:
	var factor := minf(size.x/1280.0, size.y/720.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - canvas.size * factor)/2

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()

func heading(title: String, subtitle: String, icon_index: int) -> void:
	art(content, icon_index, Rect2(54, 96, 74, 74))
	label(content,title,Rect2(146,98,1000,52),34)
	label(content,subtitle,Rect2(148,152,1020,32),16,Color("abc3bb"))

func box(color := Color("203540"), border := Color("526d70")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style

func panel(parent: Control, rect: Rect2) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel",box())
	parent.add_child(node)
	return node

func label(parent: Control, text: String, rect: Rect2, font_size := 20, color := Color("f0ead6")) -> Label:
	var node := Label.new()
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func action(parent: Control, text: String, rect: Rect2, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.pivot_offset = rect.size / 2
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size",16)
	button.add_theme_color_override("font_color",Color("f0ead6"))
	button.add_theme_stylebox_override("normal",box(Color("3c6254") if primary else Color("273e48")))
	button.add_theme_stylebox_override("hover",box(Color("4d7162"),Color("b5dca7")))
	button.add_theme_stylebox_override("pressed",box(Color("172d32")))
	button.add_theme_stylebox_override("focus",box(Color("3f5d58"),Color("b5dca7")))
	button.add_theme_stylebox_override("disabled",box(Color("202e35")))
	button.mouse_entered.connect(func(): create_tween().tween_property(button,"scale",Vector2.ONE*1.025,0.1))
	button.mouse_exited.connect(func(): create_tween().tween_property(button,"scale",Vector2.ONE,0.1))
	button.button_down.connect(func(): create_tween().tween_property(button,"scale",Vector2.ONE*0.97,0.06))
	button.button_up.connect(func(): create_tween().tween_property(button,"scale",Vector2.ONE,0.1))
	parent.add_child(button)
	return button

func art(parent: Control, index: int, rect: Rect2) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = ICONS
	atlas.region = REGIONS[index]
	atlas.filter_clip = true
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = atlas
	image.position = rect.position
	image.size = rect.size
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)

