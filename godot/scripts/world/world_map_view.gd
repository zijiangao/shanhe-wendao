class_name WorldMapView
extends Control

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
	side_panel.add_theme_stylebox_override("panel", _box(Color("#172820e8")))
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

func _add_marker(label_text: String, at: Vector2, id: String, current: bool) -> void:
	var button := Button.new()
	button.text = "%s\n当前所在" % label_text if current else label_text
	button.position = at
	button.size = Vector2(132, 58)
	button.z_index = 2
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("#fff6df"))
	button.add_theme_stylebox_override("normal", _box(Color("#9f4032ee") if current else Color("#263f34ee")))
	button.add_theme_stylebox_override("hover", _box(Color("#b15443")))
	button.pressed.connect(func(): destination_requested.emit(id))
	add_child(button)

func _action_button(text_value: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("#f5ecd9"))
	button.add_theme_stylebox_override("normal", _box(color))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.12)))
	return button

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
