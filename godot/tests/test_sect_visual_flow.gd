extends SceneTree

const SECT := preload("res://scripts/progression/sect_building_rules.gd")
const PORTRAITS := preload("res://scripts/ui/character_portraits.gd")
var main: Control
var game: Node
var failures: Array[String] = []
var capture := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if str(ProjectSettings.get_setting("application/config/name")) != "ShanheWendao-iteration-tests":
		push_error("Use an isolated project and APPDATA for the sect flow test.")
		quit(2)
		return
	capture = "--capture-sect" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	game = root.get_node("GameState")
	var settings := root.get_node("SettingsManager")
	settings.data = settings.defaults()
	game.new_game()
	game.data.tutorial = {"location": true, "map": true}
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _settle()
	for scale in [1.0, 1.15, 1.3]:
		settings.data.ui_scale = scale
		settings.apply_settings()
		for level in [0, 1, 2, 3]:
			for id in SECT.BUILDING_IDS:
				game.data.sect.buildings[id] = level
			await _location()
			_check_estate(level, scale)
			if capture and (level == 0 or level == 3):
				await _snapshot("sect-%d-%d.png" % [int(scale * 100), level])
	settings.data.ui_scale = 1.0
	settings.apply_settings()
	game.new_game()
	game.data.tutorial = {"location": true, "map": true}
	game.data.quest_stage = "chapter_complete"
	game.data.materials = {"herbs": 100, "ore": 100}
	await _location()
	var silver_before := int(game.data.silver)
	await _click("Building_herb_garden")
	_check(main.screen == "choice" and main.choice_event == "sect_building" and main.sect_building_selection == "herb_garden", "Herb plot opens its own construction details")
	_check(main.choice_options.size() == 2, "Herb plot details contain only its upgrade and return")
	main._resolve_choice("upgrade_herb_garden")
	await _settle()
	_check(SECT.level(game.data, "herb_garden") == 1 and int(game.data.silver) == silver_before - 300 and bool(game.data.acted_this_week), "Actual construction charges one weekly action and resources")
	main._resolve_choice("leave")
	await _settle()
	_check(main.screen == "location", "Return from construction enters the sect")
	_check(_building("herb_garden").get_node("BuildingImage").visible, "Built garden immediately appears on the estate")
	var saved := root.get_node("SaveManager")
	_check(saved.save_slot(3), "Save constructed estate")
	game.new_game()
	_check(saved.load_slot(3), "Load constructed estate")
	await _location()
	_check(SECT.level(game.data, "herb_garden") == 1 and _building("herb_garden").get_node("BuildingImage").visible, "Loaded garden preserves its visible construction")
	game.data.acted_this_week = false
	for route in [["train", "choice", "training"], ["workshop", "choice", "workshop"], ["forge", "choice", "forge"], ["library", "library", ""], ["gathering", "choice", "gathering"], ["qingyun_tavern", "choice", "qingyun_tavern"]]:
		await _location()
		await _click("Building_%s" % route[0])
		_check(main.screen == route[1] and (str(route[2]).is_empty() or main.choice_event == route[2]), "Building %s reaches its actual function" % route[0])
	await _location()
	await _click("Estate_sect_building")
	_check(main.choice_event == "sect_building" and main.sect_building_selection.is_empty() and main.choice_options.size() == 5, "Construction pavilion opens all four buildings")
	await _location()
	await _click("Estate_map")
	_check(main.screen == "map", "Sect gate returns to world map")
	game.data.quest_stage = "meet_master"
	await _location()
	await _click("SectMaster")
	_check(main.screen == "dialogue", "Master portrait starts the story dialogue")
	_check(_speaker_texture() == PORTRAITS.for_speaker("顾长风"), "Master dialogue displays Gu Changfeng")
	if capture:
		await _snapshot("dialogue-gu-changfeng.png")
	main._advance_dialogue()
	await _settle()
	_check(main.screen == "dialogue" and _speaker_texture() == PORTRAITS.for_speaker("沈羽"), "Next speaker switches to Shen Yu")
	if capture:
		await _snapshot("dialogue-shen-yu.png")
	main._advance_dialogue()
	await _settle()
	_check(main.screen == "map" and str(game.data.quest_stage) == "investigate", "Portrait dialogue preserves mission progression")
	main._show_qingyun_tavern()
	await _settle()
	for option in main.choice_options:
		var id := str(option[2]).trim_prefix("recruit_")
		if id in ["zhou_mubai", "liu_ruyan"]:
			var title := "周慕白" if id == "zhou_mubai" else "柳如烟"
			_check(option.size() == 5 and option[4] == PORTRAITS.for_speaker(title), "Recruitment card has %s's own portrait" % title)
	if capture:
		await _snapshot("disciples-inn.png")
	main._resolve_choice("recruit_zhou_mubai")
	main._resolve_choice("recruit_liu_ruyan")
	for id in ["zhou_mubai", "liu_ruyan"]:
		main.character_roster_selection = id
		main.screen = "character"
		main._rebuild()
		await _settle()
		var title := "周慕白" if id == "zhou_mubai" else "柳如烟"
		var image := main.content.find_child("CharacterPortrait", true, false) as TextureRect
		_check(image != null and image.texture == PORTRAITS.for_speaker(title), "Character sheet uses %s's own identity" % title)
		if capture:
			await _snapshot("character-%s.png" % id)
	print("Sect visual flow: %s (%d failures)." % ["passed" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 27)

func _check_estate(level: int, scale: float) -> void:
	var view := main.content.get_child(main.content.get_child_count() - 1) as Control
	var area: Rect2 = main.content.get_global_rect().intersection(root.get_visible_rect()).grow(1)
	var buttons := view.find_children("*", "Button", true, false)
	_check(buttons.size() == 11, "Eleven sect entrances at scale %s level %d" % [scale, level])
	for button in buttons:
		_check(area.encloses(button.get_global_rect()), "Visible entrance %s at scale %s" % [button.name, scale])
		_check(button.focus_mode == Control.FOCUS_ALL, "Keyboard focus on %s" % button.name)
	for left_right in [["library", "workshop"], ["train", "forge"], ["gathering", "herb_garden"]]:
		var left := _building(str(left_right[0])).get_global_rect()
		var right := _building(str(left_right[1])).get_global_rect()
		_check(is_equal_approx(left.position.y, right.position.y) and is_equal_approx(left.get_center().x + right.get_center().x, area.get_center().x * 2), "Symmetric building pair %s at scale %s" % [left_right, scale])
	for id in ["library", "train", "forge", "herb_garden"]:
		var button := _building(id)
		var image := button.get_node("BuildingImage") as TextureRect
		_check(int(button.get_meta("building_level")) == level and image.texture != null, "Saved construction level reflected on %s" % id)
		_check(image.visible == (id != "herb_garden" or level > 0), "Garden image only after construction")
	var master_image := view.find_child("MasterPortrait", true, false) as TextureRect
	_check(master_image != null and master_image.texture == PORTRAITS.for_speaker("顾长风"), "Correct master portrait on estate")

func _building(id: String) -> Button:
	return main.content.find_child("Building_%s" % id, true, false) as Button

func _speaker_texture() -> Texture2D:
	var image := main.content.find_child("SpeakerPortrait", true, false) as TextureRect
	return image.texture if image != null else null

func _location() -> void:
	main.screen = "location"
	main._rebuild()
	await _settle()

func _click(node_name: String) -> void:
	var button := main.content.find_child(node_name, true, false) as Button
	if button == null or button.disabled:
		_check(false, "Missing enabled entrance %s" % node_name)
		return
	button.pressed.emit()
	await _settle()

func _settle() -> void:
	for frame in range(6):
		await process_frame

func _snapshot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("user://" + filename)
	_check(error == OK, "Save screenshot %s" % filename)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
