class_name DialogueView
extends Control

signal continue_requested

func setup(background: Texture2D, speaker_name: String, line: String, index: int, total: int) -> void:
	var art := TextureRect.new()
	art.texture = background
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var shade := ColorRect.new()
	shade.color = Color("#06100bd0")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var speaker := Label.new()
	speaker.position = Vector2(120, 315)
	speaker.text = speaker_name
	speaker.add_theme_font_size_override("font_size", 27)
	speaker.add_theme_color_override("font_color", Color("#dfbf74"))
	add_child(speaker)
	var dialogue_box := Label.new()
	dialogue_box.position = Vector2(105, 360)
	dialogue_box.size = Vector2(1070, 145)
	dialogue_box.text = line
	dialogue_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_box.add_theme_font_size_override("font_size", 21)
	dialogue_box.add_theme_color_override("font_color", Color("#f6f0e4"))
	dialogue_box.add_theme_stylebox_override("normal", _box(Color("#172820f2")))
	add_child(dialogue_box)
	var next := Button.new()
	next.text = "继续  %d/%d" % [index + 1, total]
	next.position = Vector2(935, 520)
	next.size = Vector2(240, 52)
	next.add_theme_font_size_override("font_size", 16)
	next.add_theme_color_override("font_color", Color("#f5ecd9"))
	next.add_theme_stylebox_override("normal", _box(Color("#8b493b")))
	next.add_theme_stylebox_override("hover", _box(Color("#a45a4b")))
	next.pressed.connect(func(): continue_requested.emit())
	add_child(next)

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

