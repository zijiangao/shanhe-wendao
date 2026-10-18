extends SceneTree

const WUXUE := preload("res://scripts/progression/wuxue_rules.gd")
const SECT := preload("res://scripts/progression/sect_building_rules.gd")
const WORKSHOP_IDS := ["healing_powder", "insight_pill", "strength_pill", "agility_pill", "constitution_pill", "vitality_pill"]
const FORGE_IDS := ["forged_iron_blade", "twin_edge_saber", "star_marrow_blade", "rattan_guard", "layered_iron_armor", "star_marrow_armor"]

var main: Control
var game: Node
var checks := 0
var failures: Array[String] = []
var capture := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var project_name := str(ProjectSettings.get_setting("application/config/name"))
	var test_data := OS.get_environment("APPDATA").replace("\\", "/").to_lower()
	if project_name not in ["ShanheWendao-iteration-tests", "山河问道"] or "/acceptance-" not in test_data:
		push_error("Use an isolated acceptance APPDATA for building selection tests.")
		quit(2)
		return
	capture = "--capture-building-selection" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	game = root.get_node("GameState")
	var settings := root.get_node("SettingsManager")
	settings.data = settings.defaults()
	settings.apply_settings()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _settle()
	for scale in [1.0, 1.3]:
		settings.data.ui_scale = scale
		settings.apply_settings()
		await _settle()
		_new_game()
		main._show_sect_hall()
		await _settle()
		_check_screen("sect_hall", 1, "正殿")
		if capture:
			await _snapshot("building-hall-%d.png" % roundi(scale * 100))
		main._show_sect_building()
		await _settle()
		_check_screen("sect_building", 4, "营造图")
		if capture:
			await _snapshot("building-sect-%d.png" % roundi(scale * 100))
		main._show_sect_building("herb_garden")
		await _settle()
		_check_screen("sect_building", 1, "药圃详情")
		if capture:
			await _snapshot("building-herb-%d.png" % roundi(scale * 100))
		await _open_location_action("workshop")
		_check_screen("workshop", WORKSHOP_IDS.size(), "炼药坊")
		_check_card_text("回春散", "炼药坊包含回春散")
		if capture:
			await _snapshot("building-workshop-%d.png" % roundi(scale * 100))
		await _open_location_action("forge")
		_check_screen("forge", FORGE_IDS.size(), "锻造坊")
		_check_card_text("自铸铁刃", "锻造坊包含自铸铁刃")
		if capture:
			await _snapshot("building-forge-%d.png" % roundi(scale * 100))
		main._show_qingyun_tavern()
		await _settle()
		_check_screen("qingyun_tavern", 3, "客栈")
		_check_card_text("招募 · 周慕白", "客栈包含周慕白招募")
		if capture:
			await _snapshot("building-tavern-%d.png" % roundi(scale * 100))
		await _open_location_action("gathering")
		_check_screen("gathering", 2, "后山")
		_check_card_text("采药", "后山包含采药")
		_check_card_text("挖矿", "后山包含挖矿")
		if capture:
			await _snapshot("building-gathering-%d.png" % roundi(scale * 100))
		main.screen = "location"
		main._rebuild()
		await _settle()
		main._location_action_requested("library")
		await _settle()
		await _check_library("拳掌", 1)
		await _check_library("剑法", 1)
		await _check_library("刀法", 2)
		if capture:
			await _snapshot("building-library-%d.png" % roundi(scale * 100))
	await _small_window_layout()
	print("Building selection layout: %d checks, %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 31)

func _new_game() -> void:
	game.new_game()
	game.data.tutorial = {"location": true, "map": true}
	game.data.silver = 5000
	game.data.materials = {"herbs": 20, "ore": 20}
	WUXUE.learn_move(game.data, "stone_splitting_fist")
	WUXUE.learn_move(game.data, "cloud_sword")
	WUXUE.learn_move(game.data, "blade_technique")
	WUXUE.learn_move(game.data, "night_triple_blade")
	WUXUE.learn_move(game.data, "armor_splitting_spear")
	game.data.acted_this_week = false

func _open_location_action(id: String) -> void:
	main.screen = "location"
	main._rebuild()
	await _settle()
	main._location_action_requested(id)
	await _settle()

func _check_screen(event: String, expected_cards: int, context: String) -> void:
	_check(str(main.choice_event) == event, context + " opens the production choice flow")
	_check_layout(context, expected_cards)

func _check_library(category_name: String, expected_cards: int) -> void:
	var tab := _category_button(category_name)
	_check(tab != null and not tab.disabled, "Library tab %s exists" % category_name)
	if tab == null:
		return
	tab.pressed.emit()
	await _settle()
	_check(str(main.library_category) == _category_id(category_name), "Library switches to %s" % category_name)
	_check_layout("藏经阁 · " + category_name, expected_cards)

func _category_id(category_name: String) -> String:
	match category_name:
		"拳掌": return "fist"
		"剑法": return "sword"
		"刀法": return "blade"
		"枪棍": return "staff"
		"内功": return "internal"
		"轻功": return "lightness"
	return ""

func _view() -> Control:
	for child in main.content.get_children():
		if child.get_script() != null and str(child.get_script().resource_path).ends_with("building_selection_view.gd"):
			return child
	return null

func _category_button(category_name: String) -> Button:
	var view := _view()
	if view == null:
		return null
	for button in view.find_children("*", "Button", true, false):
		if (button as Button).text == category_name:
			return button
	return null

func _option_button(id: String) -> Button:
	var view := _view()
	if view == null:
		return null
	for button in view.find_children("*", "Button", true, false):
		if str(button.get_meta("option_id", "")) == id:
			return button
	return null

func _card_buttons() -> Array:
	var view := _view()
	if view == null:
		return []
	return view.find_children("*", "Button", true, false).filter(func(button: Button): return str(button.get_meta("option_id", "")) not in ["", "leave"] and not button.has_meta("category_id"))

func _check_layout(context: String, expected_cards: int) -> void:
	var view := _view()
	_check(view != null, "Dedicated building selection view at " + context)
	if view == null:
		return
	_check(view.find_children("*", "ScrollContainer", true, false).is_empty(), "Building selection has no scrolling container at " + context)
	_check(_card_buttons().size() == expected_cards, "Expected %d cards at %s, got %d" % [expected_cards, context, _card_buttons().size()])
	var area: Rect2 = main.content.get_global_rect().intersection(root.get_visible_rect()).grow(1)
	var buttons: Array = view.find_children("*", "Button", true, false)
	for button in buttons:
		if button.is_visible_in_tree():
			_check(area.encloses(button.get_global_rect()), "Visible building control %s fits at %s" % [button.name, context])
	var leave := _option_button("leave")
	_check(leave != null and not leave.disabled and area.encloses(leave.get_global_rect()), "The fixed return is visible at " + context)
	for left_index in range(buttons.size()):
		for right_index in range(left_index + 1, buttons.size()):
			var left := buttons[left_index] as Button
			var right := buttons[right_index] as Button
			if left.is_visible_in_tree() and right.is_visible_in_tree():
				_check(not left.get_global_rect().grow(-0.5).intersects(right.get_global_rect().grow(-0.5)), "Building controls have separate click targets at " + context)

func _check_card_text(fragment: String, message: String) -> void:
	var found := false
	for button in _card_buttons():
		if fragment in button.text:
			found = true
			break
	_check(found, message)

func _small_window_layout() -> void:
	var settings := root.get_node("SettingsManager")
	settings.data.ui_scale = 1.3
	settings.apply_settings()
	root.content_scale_size = Vector2i.ZERO
	for window_size in [Vector2i(1000, 720), Vector2i(1280, 600)]:
		root.size = window_size
		await _settle()
		_new_game()
		await _open_location_action("workshop")
		_check_layout("炼药坊 %s" % window_size, WORKSHOP_IDS.size())
		main._show_sect_building()
		await _settle()
		_check_layout("营造图 %s" % window_size, 4)
	main.screen = "location"
	main._rebuild()
	_check(main.screen == "location", "Small-window screens return to the location flow")

func _settle() -> void:
	for frame in range(5):
		await process_frame

func _snapshot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("user://" + filename) == OK, "Capture " + filename)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
