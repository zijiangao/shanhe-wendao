extends SceneTree

const SECT := preload("res://scripts/progression/sect_building_rules.gd")
const PORTRAITS := preload("res://scripts/ui/character_portraits.gd")
# Ground positions authored against qingyun-estate.png, independent of the view's
# layout metadata so a return to evenly spaced screen cards cannot pass.
const ESTATE_GROUND_ANCHORS := {
	"library": Vector2(450, 435),
	"workshop": Vector2(1240, 435),
	"train": Vector2(255, 645),
	"forge": Vector2(1215, 645),
	"gathering": Vector2(495, 645),
	"herb_garden": Vector2(1450, 645),
	"master": Vector2(860, 330),
	"qingyun_tavern": Vector2(865, 695),
}
const ESTATE_WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1264, 706), Vector2i(1280, 800), Vector2i(1280, 960), Vector2i(1280, 1024)]
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
	# Stress different available content areas directly. The shipping window
	# normally keeps a 1280x720 reference viewport when its outer size changes.
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	game = root.get_node("GameState")
	var settings := root.get_node("SettingsManager")
	settings.data = settings.defaults()
	game.new_game()
	game.data.tutorial = {"location": true, "map": true}
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _settle()
	for window_size in ESTATE_WINDOW_SIZES:
		root.size = window_size
		await _settle()
		if window_size != ESTATE_WINDOW_SIZES[0]:
			# The previous courtyard remains open: resize must move it without
			# requiring the player to leave and enter the sect again.
			_check_estate(3, 1.3)
		for scale in [1.0, 1.15, 1.3]:
			settings.data.ui_scale = scale
			settings.apply_settings()
			# Applying windowed settings may restore the desktop window size.
			# Set the requested dimensions afterwards so each case is exercised.
			root.size = window_size
			await _settle()
			for level in [0, 1, 2, 3]:
				for id in SECT.BUILDING_IDS:
					game.data.sect.buildings[id] = level
				await _location()
				_check(root.size == window_size, "Requested window %s remains active at scale %s level %d (actual %s)" % [window_size, scale, level, root.size])
				_check_estate(level, scale)
				if capture and window_size == ESTATE_WINDOW_SIZES[0] and (level == 0 or level == 3):
					await _snapshot("sect-%d-%d.png" % [int(scale * 100), level])
				elif capture and window_size == Vector2i(1280, 1024) and scale == 1.0 and level == 3:
					await _snapshot("sect-tall-100-3.png")
	root.size = ESTATE_WINDOW_SIZES[0]
	settings.data.ui_scale = 1.0
	settings.apply_settings()
	game.new_game()
	game.data.tutorial = {"location": true, "map": true}
	game.data.materials = {"herbs": 100, "ore": 100}
	_check(str(game.data.quest_stage) == "explore", "Fresh games enter free exploration without starting a story quest")
	await _location()
	var silver_before := int(game.data.silver)
	await _click("Building_herb_garden")
	_check(main.screen == "choice" and main.choice_event == "sect_building" and main.sect_building_selection == "herb_garden", "Herb plot opens its own construction details")
	_check(main.choice_options.size() == 2, "Herb plot details contain only its upgrade and return")
	main._resolve_choice("upgrade_herb_garden")
	await _settle()
	_check(SECT.level(game.data, "herb_garden") == 1 and int(game.data.silver) == silver_before - 300 and bool(game.data.acted_this_week), "Actual construction charges one weekly action and resources")
	_check(str(game.data.quest_stage) == "explore", "Opening construction keeps story quests optional")
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
	if capture:
		await _snapshot("sect-construction.png")
	await _location()
	await _click("Estate_map")
	_check(main.screen == "map", "Sect gate returns to world map")
	game.new_game()
	game.data.tutorial = {"location": true, "map": true}
	await _location()
	await _click("Building_master")
	_check(main.screen == "choice" and main.choice_event == "sect_hall", "The hall opens the master's interior meeting screen")
	_check(str(game.data.quest_stage) == "explore", "Entering the hall does not automatically start a quest")
	_check(not bool(game.data.acted_this_week), "Entering the hall leaves this week's action available")
	main._resolve_choice("leave")
	await _settle()
	_check(main.screen == "location" and _building("master") != null, "Leaving the hall returns to the courtyard and preserves its entrance")
	_check(str(game.data.quest_stage) == "explore" and not bool(game.data.acted_this_week), "Leaving the hall keeps quests optional and does not spend an action")
	await _click("Building_master")
	var has_master_portrait := false
	for option in main.choice_options:
		if str(option[2]) == "talk_master":
			has_master_portrait = option.size() == 5 and option[4] == PORTRAITS.for_speaker("顾长风")
	_check(has_master_portrait, "The hall shows Gu Changfeng's portrait on the voluntary conversation option")
	var hall_master_button: Button
	for button in main.content.find_children("*", "Button", true, false):
		if button.icon == PORTRAITS.for_speaker("顾长风"):
			hall_master_button = button
	_check(hall_master_button != null and not hall_master_button.disabled, "The master is visibly available as a conversation inside the hall")
	if capture:
		await _snapshot("hall-gu-changfeng.png")
	if hall_master_button != null:
		hall_master_button.pressed.emit()
	else:
		main._resolve_choice("talk_master")
	await _settle()
	_check(main.screen == "dialogue", "Choosing to talk to the master starts the story dialogue")
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
	_check(main.screen == "map" and str(game.data.quest_stage) == "investigate", "Voluntarily accepting the master's commission starts the investigation")
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
	var context := "window %s scale %s level %d" % [root.size, scale, level]
	_check(buttons.size() == 10, "Ten sect entrances at %s" % context)
	for button in buttons:
		_check(area.encloses(button.get_global_rect()), "Visible entrance %s at %s" % [button.name, context])
		_check(button.focus_mode == Control.FOCUS_ALL, "Keyboard focus on %s" % button.name)
	for left_index in range(buttons.size()):
		for right_index in range(left_index + 1, buttons.size()):
			var left := buttons[left_index] as Button
			var right := buttons[right_index] as Button
			_check(not left.get_global_rect().grow(-0.5).intersects(right.get_global_rect().grow(-0.5)), "Separate entrances %s and %s at %s" % [left.name, right.name, context])
	_check_ground_alignment(view, context)
	for id in ["library", "train", "forge", "herb_garden"]:
		var button := _building(id)
		var image := button.get_node("BuildingImage") as TextureRect
		_check(int(button.get_meta("building_level")) == level and image.texture != null, "Saved construction level reflected on %s" % id)
		_check(image.visible == (id != "herb_garden" or level > 0), "Garden image only after construction")
	_check(view.find_child("SectMaster", true, false) == null and view.find_child("MasterPortrait", true, false) == null, "The master appears inside the hall without a separate courtyard card")
	_check(str(_building("master").get_node("BuildingPlaque/BuildingStatus").text) == "拜见师父 · 委托", "The hall explains its meeting and commission function")

func _check_ground_alignment(view: Control, context: String) -> void:
	var background := view.get_node("EstateBackground") as TextureRect
	_check(background != null and background.texture != null, "Estate background texture at %s" % context)
	if background == null or background.texture == null:
		return
	var source_size := background.texture.get_size()
	_check(source_size == Vector2(1672, 941), "Ground anchors match source art dimensions at %s" % context)
	# Independently derive the displayed image from TextureRect's actual mode.
	# Tall windows fit all platforms; wider windows cover the courtyard area.
	var width_scale := background.size.x / source_size.x
	var height_scale := background.size.y / source_size.y
	var stretch_mode := background.stretch_mode
	_check(stretch_mode in [TextureRect.STRETCH_KEEP_ASPECT_CENTERED, TextureRect.STRETCH_KEEP_ASPECT_COVERED], "Estate background uses a proportional centered mode at %s" % context)
	if stretch_mode not in [TextureRect.STRETCH_KEEP_ASPECT_CENTERED, TextureRect.STRETCH_KEEP_ASPECT_COVERED]:
		return
	var expected_stretch_mode: int = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if width_scale < height_scale else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_check(stretch_mode == expected_stretch_mode, "Estate background fits tall windows and covers wider windows at %s" % context)
	var draw_scale := minf(width_scale, height_scale) if stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED else maxf(width_scale, height_scale)
	var draw_offset := (background.size - source_size * draw_scale) * 0.5
	for id in ESTATE_GROUND_ANCHORS:
		var button := _building(str(id))
		var expected: Vector2 = background.get_global_transform() * (draw_offset + ESTATE_GROUND_ANCHORS[id] * draw_scale)
		var image := button.get_node("BuildingImage") as TextureRect
		var image_rect := image.get_global_rect()
		var image_ground := Vector2(image_rect.get_center().x, image_rect.end.y)
		_check(image_ground.distance_to(expected) <= 1.0, "Building %s rests on its source platform at %s (actual %s expected %s)" % [id, context, image_ground, expected])
		if image.texture != null:
			var texture_size := image.texture.get_size()
			_check(absf(image.size.x / texture_size.x - image.size.y / texture_size.y) <= 0.001, "Building %s preserves image proportions at %s" % [id, context])
		if button.has_node("ReservedHerbPlot"):
			var plot := button.get_node("ReservedHerbPlot") as Control
			var plot_rect := plot.get_global_rect()
			var plot_ground := Vector2(plot_rect.get_center().x, plot_rect.end.y)
			_check(plot_ground.distance_to(expected) <= 1.0, "Unbuilt herb plot stays on the garden platform at %s" % context)

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
	var screenshot := root.get_texture().get_image()
	_check(screenshot.get_size() == root.size, "Screenshot %s dimensions match active window %s (actual %s)" % [filename, root.size, screenshot.get_size()])
	var error := screenshot.save_png("user://" + filename)
	_check(error == OK, "Save screenshot %s" % filename)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
