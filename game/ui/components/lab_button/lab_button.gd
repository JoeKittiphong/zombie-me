extends Button

signal activated(section: String)

var section := ""
var illustration: TextureRect
var motion: Tween
var hovered := false
var busy := false

func configure(title: String, art: Texture2D, accent: bool = false) -> void:
	section = title
	text = "     " + title
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_size_override("font_size", 21)
	add_theme_color_override("font_color", Color("f4edd6"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("314e50") if accent else Color("1e303c")
		if state == "hover" or state == "focus":
			box.bg_color = Color("46655a")
		if state == "pressed":
			box.bg_color = Color("17282b")
		box.border_color = Color("a2c59a") if accent else Color("667c78")
		box.set_border_width_all(2)
		box.set_corner_radius_all(12)
		box.content_margin_left = 46
		add_theme_stylebox_override(state, box)
	illustration = TextureRect.new()
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.texture = art
	illustration.position = Vector2(9, 5)
	illustration.size = Vector2(64, 64)
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	illustration.pivot_offset = Vector2(32, 32)
	add_child(illustration)
	pivot_offset = size / 2
	resized.connect(func(): pivot_offset = size / 2)
	mouse_entered.connect(func(): animate_hover(true))
	mouse_exited.connect(func(): animate_hover(false))
	focus_entered.connect(func(): animate_hover(true))
	focus_exited.connect(func(): animate_hover(false))
	pressed.connect(animate_click)

func animate_hover(value: bool) -> void:
	hovered = value
	if busy:
		return
	if motion:
		motion.kill()
	motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.tween_property(self, "scale", Vector2.ONE * (1.035 if value else 1.0), 0.18)
	motion.tween_property(illustration, "rotation", -0.12 if value else 0.0, 0.2)
	motion.tween_property(illustration, "scale", Vector2.ONE * (1.12 if value else 1.0), 0.2)

func animate_click() -> void:
	if busy:
		return
	busy = true
	if motion:
		motion.kill()
	motion = create_tween()
	motion.tween_property(self, "scale", Vector2(0.95, 0.91), 0.07)
	motion.tween_property(self, "scale", Vector2.ONE * 1.04, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.tween_callback(func():
		busy = false
		activated.emit(section)
		animate_hover(hovered)
	)

