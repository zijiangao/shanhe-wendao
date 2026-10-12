class_name DialogueView
extends Control

const UI_THEME := preload("res://scripts/ui/ui_theme.gd")
const CHARACTER_PORTRAITS := preload("res://scripts/ui/character_portraits.gd")

signal continue_requested

var portrait_frame: PanelContainer
var dialogue_panel: PanelContainer
var has_portrait := false

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(dialogue_panel):
		_layout_panels()

func setup(background: Texture2D, speaker_name: String, line: String, index: int, total: int) -> void:
	var art := TextureRect.new()
	art.name = "DialogueBackground"
	art.texture = background
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var shade := ColorRect.new()
	shade.color = Color("#06100b8c")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var portrait_texture := CHARACTER_PORTRAITS.for_speaker(speaker_name)
	has_portrait = portrait_texture != null
	portrait_frame = PanelContainer.new()
	portrait_frame.name = "PortraitFrame"
	portrait_frame.visible = has_portrait
	var portrait_style := UI_THEME.box(Color("#20352ff2"))
	portrait_style.border_color = Color("#bba873")
	portrait_style.set_border_width_all(2)
	portrait_style.content_margin_left = 6
	portrait_style.content_margin_right = 6
	portrait_style.content_margin_top = 6
	portrait_style.content_margin_bottom = 6
	portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	add_child(portrait_frame)
	var portrait := TextureRect.new()
	portrait.name = "SpeakerPortrait"
	portrait.texture = portrait_texture
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)

	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "DialoguePanel"
	var panel_style := UI_THEME.panel_box(UI_THEME.DARK_TINT)
	# Texture slicing margins are not text margins. Reserve the painted
	# border with our own container so small UI viewports keep readable space.
	panel_style.content_margin_left = 0
	panel_style.content_margin_right = 0
	panel_style.content_margin_top = 0
	panel_style.content_margin_bottom = 0
	dialogue_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(dialogue_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 42)
	dialogue_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	var speaker := Label.new()
	speaker.name = "SpeakerName"
	speaker.text = speaker_name
	speaker.add_theme_font_size_override("font_size", 29)
	speaker.add_theme_color_override("font_color", Color("#dfbf74"))
	content.add_child(speaker)
	var divider := HSeparator.new()
	var divider_style := StyleBoxLine.new()
	divider_style.color = Color("#aa976566")
	divider_style.thickness = 1
	divider.add_theme_stylebox_override("separator", divider_style)
	content.add_child(divider)
	var scroll := ScrollContainer.new()
	scroll.name = "DialogueScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	content.add_child(scroll)
	var dialogue_box := Label.new()
	dialogue_box.name = "DialogueText"
	dialogue_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_box.text = line
	dialogue_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_box.add_theme_font_size_override("font_size", 23)
	dialogue_box.add_theme_constant_override("line_spacing", 8)
	dialogue_box.add_theme_color_override("font_color", Color("#f6f0e4"))
	scroll.add_child(dialogue_box)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(footer)
	var next := UI_THEME.action_button("继续  %d/%d" % [index + 1, total], Color("#8b493b"))
	next.name = "ContinueButton"
	next.custom_minimum_size = Vector2(210, 52)
	next.size_flags_horizontal = Control.SIZE_SHRINK_END
	next.add_theme_font_size_override("font_size", 18)
	next.pressed.connect(func(): continue_requested.emit())
	footer.add_child(next)
	_layout_panels()

func _layout_panels() -> void:
	# The main shell can have a wider minimum size than a 130% UI viewport.
	# Fit within the portion of its content that is actually visible.
	var available := get_viewport_rect().size - global_position
	var visible_size := Vector2(minf(size.x, available.x), minf(size.y, available.y))
	var inset := Vector2(clampf(visible_size.x * 0.032, 24.0, 40.0), clampf(visible_size.y * 0.05, 18.0, 30.0))
	var inner_size := visible_size - inset * 2.0
	if has_portrait:
		var portrait_width := inner_size.x * 0.28
		var gap := clampf(visible_size.x * 0.021, 18.0, 28.0)
		portrait_frame.position = inset
		portrait_frame.size = Vector2(portrait_width, inner_size.y)
		dialogue_panel.position = Vector2(inset.x + portrait_width + gap, inset.y)
		dialogue_panel.size = Vector2(inner_size.x - portrait_width - gap, inner_size.y)
	else:
		var panel_width := minf(inner_size.x, 860.0)
		dialogue_panel.position = Vector2((visible_size.x - panel_width) / 2.0, inset.y)
		dialogue_panel.size = Vector2(panel_width, inner_size.y)
