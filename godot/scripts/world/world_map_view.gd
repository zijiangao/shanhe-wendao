class_name WorldMapView
extends Control

const UI_THEME := preload("res://scripts/ui/ui_theme.gd")

signal destination_requested(id: String)
signal enter_requested
signal rest_requested

const PLACE_NAMES := {"qingyun": "青云门", "blackreed": "黑苇渡", "luoyang": "洛阳城", "huashan": "华山", "emei": "峨眉山"}
const MARKERS := {
	"qingyun": Vector2(205, 150),
	"blackreed": Vector2(280, 410),
	"luoyang": Vector2(585, 245),
	"huashan": Vector2(735, 105),
	"emei": Vector2(510, 400)
}

func setup(map_texture: Texture2D, state: Dictionary, objective_text: String, available_places: Array[String]) -> void:
	var art := TextureRect.new()
	art.texture = map_texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)

	var side_panel := PanelContainer.new()
	side_panel.position = Vector2(855, 30)
	side_panel.size = Vector2(390, 500)
	side_panel.add_theme_stylebox_override("panel", UI_THEME.panel_box(UI_THEME.DARK_TINT))
	add_child(side_panel)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	side_panel.add_child(side)
	var location := Label.new()
	location.text = "当前所在 · %s" % PLACE_NAMES.get(str(state.location), str(state.location))
	location.add_theme_font_size_override("font_size", 27)
	location.add_theme_color_override("font_color", Color("#f2dfb3"))
	side.add_child(location)
	var objective := Label.new()
	objective.text = "主线：%s\n\n行动点：%d/3\n气血：%d/%d\n修为：%d\n声望：%d" % [objective_text, state.energy, state.hp, state.max_hp, state.xp, state.renown]
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_theme_font_size_override("font_size", 18)
	objective.add_theme_color_override("font_color", Color("#f6f0e4"))
	side.add_child(objective)
	var enter := _action_button("进入%s" % PLACE_NAMES.get(str(state.location), "当前地点"), Color("#315746"))
	enter.pressed.connect(func(): enter_requested.emit())
	side.add_child(enter)
	var rest := _action_button("调息一周", Color("#6c604c"))
	rest.pressed.connect(func(): rest_requested.emit())
	side.add_child(rest)

	for id in available_places:
		_add_marker(PLACE_NAMES.get(id, id), MARKERS.get(id, Vector2.ZERO), id, id == str(state.location))

	var chronicle := Label.new()
	var chronicle_height: float = minf(175.0, 58.0 + float(state.log.size()) * 26.0)
	chronicle.anchor_top = 1.0
	chronicle.anchor_bottom = 1.0
	chronicle.offset_left = 35
	chronicle.offset_top = -10.0 - chronicle_height
	chronicle.offset_right = 795
	chronicle.offset_bottom = -10
	chronicle.z_index = 1
	chronicle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chronicle.text = "江湖纪事\n· " + "\n· ".join(PackedStringArray(state.log))
	chronicle.add_theme_font_size_override("font_size", 18)
	chronicle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chronicle.clip_text = true
	chronicle.add_theme_stylebox_override("normal", _box(Color("#172820e8")))
	chronicle.add_theme_color_override("font_color", Color("#f6f0e4"))
	add_child(chronicle)

const MARKER_WIDTH := 78.0

func _add_marker(label_text: String, at: Vector2, id: String, current: bool) -> void:
	var texture: Texture2D = UI_THEME.map_marker("current" if current else "visited")
	var marker_size := Vector2(texture.get_width(), texture.get_height()) * (MARKER_WIDTH / float(texture.get_width()))
	var origin := at - Vector2(marker_size.x / 2.0, marker_size.y * 0.08)

	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.position = origin
	art.size = marker_size
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.z_index = 2
	add_child(art)

	var name_label := Label.new()
	name_label.text = "%s\n当前所在" % label_text if current else label_text
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(at.x - 65, origin.y + marker_size.y * 0.34)
	name_label.size = Vector2(130, 46)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color("#fff6df") if current else Color("#e8e2d2"))
	name_label.add_theme_color_override("font_shadow_color", Color("#0000009f"))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.z_index = 3
	add_child(name_label)

	var button := Button.new()
	button.flat = true
	button.position = origin
	button.size = marker_size
	button.z_index = 4
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = label_text
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.mouse_entered.connect(func(): art.modulate = Color("#ffe9b8"))
	button.mouse_exited.connect(func(): art.modulate = Color.WHITE)
	button.pressed.connect(func(): destination_requested.emit(id))
	add_child(button)

func _action_button(text_value: String, color: Color) -> Button:
	return UI_THEME.action_button(text_value, color)

func _box(color: Color) -> StyleBoxFlat:
	return UI_THEME.box(color)
