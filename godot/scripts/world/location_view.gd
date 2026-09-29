class_name LocationView
extends Control

const UI_THEME := preload("res://scripts/ui/ui_theme.gd")

signal action_requested(id: String)

func setup(background: Texture2D, heading_text: String, objective_text: String, actions: Array) -> void:
	var art := TextureRect.new()
	art.texture = background
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var shade := ColorRect.new()
	shade.color = Color("#07110d42")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var heading_panel := PanelContainer.new()
	heading_panel.position = Vector2(28, 16)
	heading_panel.size = Vector2(650, 112)
	heading_panel.add_theme_stylebox_override("panel", UI_THEME.box(Color("#07130ed1")))
	add_child(heading_panel)
	var accent := ColorRect.new()
	accent.position = Vector2(28, 16)
	accent.size = Vector2(5, 112)
	accent.color = Color("#dfbf74")
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent.z_index = 2
	add_child(accent)
	var heading := Label.new()
	heading.position = Vector2(48, 28)
	heading.text = heading_text
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color("#fff0cf"))
	add_child(heading)
	var objective := Label.new()
	objective.position = Vector2(50, 77)
	objective.text = objective_text
	objective.add_theme_font_size_override("font_size", 17)
	objective.add_theme_color_override("font_color", Color("#f5ecda"))
	add_child(objective)
	for action in actions:
		var button := UI_THEME.action_button(str(action.get("text", "事件")), Color("#263f34"))
		button.position = Vector2(float(action.get("x", 0)), float(action.get("y", 0)))
		button.size = Vector2(260, 58)
		button.disabled = bool(action.get("disabled", false))
		button.pressed.connect(_emit_action.bind(str(action.get("id", ""))))
		add_child(button)

func _emit_action(id: String) -> void:
	action_requested.emit(id)

func _box(color: Color) -> StyleBoxFlat:
	return UI_THEME.box(color)
