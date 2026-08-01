class_name WorldMapView
extends Control

const UI_THEME := preload("res://scripts/ui/ui_theme.gd")

signal destination_requested(id: String)

const PLACE_NAMES := {"qingyun": "青云门", "blackreed": "黑苇渡", "luoyang": "洛阳城", "huashan": "华山", "emei": "峨眉山"}
const MARKERS := {
	"qingyun": Vector2(205, 150),
	"blackreed": Vector2(280, 410),
	"luoyang": Vector2(585, 245),
	"huashan": Vector2(735, 105),
	"emei": Vector2(510, 400)
}

func setup(map_texture: Texture2D, state: Dictionary, available_places: Array[String]) -> void:
	var art := TextureRect.new()
	art.texture = map_texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)

	# The side panel (进入.../调息/江湖纪事) was removed entirely (0.100.0) --
	# entering the current location now happens by clicking its own map
	# marker below (destination_requested with the same id the hero is
	# already at, which _map_destination_requested() already treats as
	# "enter" rather than "travel"). 江湖纪事 moved into the quest journal
	# screen; 调息 was removed outright (0.101.0), not relocated -- ending
	# the week now restores hp/qi automatically instead.
	for id in available_places:
		_add_marker(PLACE_NAMES.get(id, id), MARKERS.get(id, Vector2.ZERO), id, id == str(state.location))

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
