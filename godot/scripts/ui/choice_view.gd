class_name ChoiceView
extends Control

const UI_THEME := preload("res://scripts/ui/ui_theme.gd")

signal option_selected(id: String)

func setup(background: Texture2D, prompt_text: String, options: Array, title_text: String = "抉 择") -> void:
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
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#f2dfb3"))
	panel.add_child(title)
	var prompt := Label.new()
	prompt.text = prompt_text
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override("font_size", 21)
	prompt.add_theme_color_override("font_color", Color("#f6f0e4"))
	panel.add_child(prompt)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	for option in options:
		var button := UI_THEME.action_button("%s\n%s" % [option[0], option[1]], Color("#294438"))
		button.custom_minimum_size.y = 82
		button.add_theme_font_size_override("font_size", 18)
		button.disabled = option.size() > 3 and bool(option[3])
		button.pressed.connect(_emit_option.bind(str(option[2])))
		list.add_child(button)

func _emit_option(id: String) -> void:
	option_selected.emit(id)

func _box(color: Color) -> StyleBoxFlat:
	return UI_THEME.box(color)
