class_name ChoiceView
extends Control

signal option_selected(id: String)

func setup(background: Texture2D, prompt_text: String, options: Array) -> void:
	var art := TextureRect.new()
	art.texture = background
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var shade := ColorRect.new()
	shade.color = Color("#07110dd9")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := VBoxContainer.new()
	panel.position = Vector2(225, 70)
	panel.size = Vector2(830, 470)
	panel.add_theme_constant_override("separation", 14)
	add_child(panel)
	var title := Label.new()
	title.text = "抉 择"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#f2dfb3"))
	panel.add_child(title)
	var prompt := Label.new()
	prompt.text = prompt_text
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 21)
	prompt.add_theme_color_override("font_color", Color("#f6f0e4"))
	panel.add_child(prompt)
	for option in options:
		var button := Button.new()
		button.text = "%s\n%s" % [option[0], option[1]]
		button.custom_minimum_size.y = 82
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color("#f5ecd9"))
		button.add_theme_stylebox_override("normal", _box(Color("#294438")))
		button.add_theme_stylebox_override("hover", _box(Color("#3b604f")))
		button.add_theme_stylebox_override("focus", _box(Color("#5b8f76")))
		button.pressed.connect(_emit_option.bind(str(option[2])))
		panel.add_child(button)

func _emit_option(id: String) -> void:
	option_selected.emit(id)

func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = color.lightened(0.18)
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
