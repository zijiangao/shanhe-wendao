extends SceneTree

# Production callbacks only: resources come from normal market purchases,
# and stories begin through their local encounters rather than seeded stages.
const QUESTS := preload("res://scripts/progression/quest_rules.gd")
var main: Control
var game: Node
var checks := 0
var failures: Array[String] = []
var capture := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if str(ProjectSettings.get_setting("application/config/name")) != "ShanheWendao-iteration-tests":
		push_error("Use an isolated project and APPDATA for free exploration acceptance.")
		quit(2)
		return
	capture = "--capture-exploration" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	game = root.get_node("GameState")
	var settings := root.get_node("SettingsManager")
	settings.data = settings.defaults()
	settings.apply_settings()
	game.new_game()
	# Tutorials are presentation overlays; their dismissal does not advance play.
	game.data.tutorial.map = true
	game.data.tutorial.location = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _settle()
	for place in ["emei", "huashan", "luoyang", "blackreed", "qingyun"]:
		await _travel(place)
		_check(game.data.quest_states == QUESTS.DEFAULT_STAGES and str(game.data.quest_stage) == "explore", "Travel to %s leaves all quests unstarted" % place)
		_check(int(game.data.week) == 1 and not bool(game.data.acted_this_week), "Travel preserves the starting week and action")
	await _action("master")
	_check(main.screen == "choice" and main.choice_event == "sect_hall", "The master is visited inside the hall")
	await _choice("leave")
	_check(game.data.quest_states == QUESTS.DEFAULT_STAGES, "Leaving the hall does not accept its commission")
	await _action("sect_building")
	_check(main.choice_event == "sect_building", "Construction is accessible before any quest")
	await _choice("leave")
	await _travel("luoyang")
	await _action("market")
	await _choice("goods")
	await _choice("buy_herbs")
	await _choice("buy_ore")
	await _choice("buy_ore")
	await _travel("qingyun")
	await _action("sect_building")
	await _choice("upgrade_training_ground")
	_check(int(game.data.sect.buildings.training_ground) == 1 and bool(game.data.acted_this_week), "Real market supplies fund construction in the first week")
	_check(game.data.quest_states == QUESTS.DEFAULT_STAGES and str(game.data.quest_stage) == "explore", "Construction neither accepts nor completes any quest")
	await _choice("leave")
	await _round_trip("Unstarted quests and first-week construction")
	await _journal_layout("unstarted")
	main.screen = "location"
	main._rebuild()
	main._end_week_requested()
	_check(int(game.data.week) == 2 and not bool(game.data.acted_this_week), "Construction uses exactly the first week's action")

	# Start Emei while Blackreed, Luoyang, and Huashan remain untouched.
	await _travel("emei")
	await _action("emei_gate")
	_check(main.choice_event == "emei_entry", "Emei can be investigated without earlier chapters or reputation")
	await _choice("inquire")
	await _action("meet_su")
	_check(game.quest_progress("emei") == "emei_investigate", "Emei's local dialogue starts its own investigation")
	for id in ["blackreed", "luoyang", "huashan", "finale"]:
		_check(game.quest_progress(id) == "available", "Emei-first leaves %s optional" % id)
	await _round_trip("Emei-first progress")
	if capture:
		main.screen = "location"
		main._rebuild()
		await _snapshot("emei-first.png")

	await _travel("huashan")
	await _action("huashan_gate")
	await _action("meet_lin")
	_check(game.quest_progress("huashan") == "huashan_trial" and "lin_qingshuang" in game.data.companions, "Huashan recruits Lin before Blackreed or Luoyang starts")
	_check(game.quest_progress("emei") == "emei_investigate" and game.quest_progress("blackreed") == "available" and game.quest_progress("luoyang") == "available", "Starting Huashan preserves Emei and untouched earlier quests")
	await _travel("emei")
	await _action("elephant_pool")
	_check(game.quest_progress("emei") == "emei_trial" and game.quest_progress("huashan") == "huashan_trial", "Returning to Emei resumes its own next step")
	_check(game.quest_progress("finale") == "available", "The Emei trial does not automatically accept the finale")

	await _travel("luoyang")
	await _action("temple")
	await _choice("heroism")
	await _action("palace")
	main._palace_event("witness")
	await _dialogue()
	main._palace_event("ledger")
	await _dialogue()
	main._confront_li_wujiu()
	await _dialogue()
	await _choice("public")
	_check(game.quest_progress("luoyang") == "chapter2_complete" and game.quest_progress("blackreed") == "available", "Luoyang can complete before accepting the Blackreed commission")
	_check(game.quest_progress("huashan") == "huashan_trial" and game.quest_progress("emei") == "emei_trial", "Completing Luoyang preserves both concurrent investigations")
	await _travel("blackreed")
	await _action("fisher")
	await _action("tracks")
	_check(game.quest_progress("blackreed") == "investigate" and game.data.investigations.size() == 2, "Blackreed can be triggered locally after other regions, without visiting the master")
	_check(game.quest_progress("luoyang") == "chapter2_complete" and game.quest_progress("huashan") == "huashan_trial" and game.quest_progress("emei") == "emei_trial" and game.quest_progress("finale") == "available", "All interleaved regions retain their own progress")
	await _round_trip("Interleaved regional progress, companion, clues, and construction")
	await _journal_layout("interleaved")
	await _postgame_fixture()
	print("Free exploration integration: %d checks, %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 28)

func _postgame_fixture() -> void:
	# This deliberately enters the production ending endpoint as a regression
	# fixture. Combat completion is covered by the separate full-game journeys.
	game.new_game()
	game.data.tutorial.map = true
	game.data.tutorial.location = true
	game.complete_game("preserve")
	_check(game.quest_progress("finale") == "game_complete" and main._screen_after_load() == "ending", "The ending fixture establishes completed finale progress")
	await _travel("qingyun")
	await _action("workshop")
	await _choice("leave")
	_check(main.screen == "location", "Leaving an ordinary workshop choice after the finale returns to the location")
	await _travel("luoyang")
	await _action("temple")
	await _choice("heroism")
	_check(main.screen == "location", "Accepting an optional Baima route after the finale returns to its location")
	await _travel("blackreed")
	await _action("fisher")
	_check(game.quest_progress("blackreed") == "investigate" and game.quest_progress("luoyang") == "luoyang_investigate", "Still-optional quests remain playable after the finale")
	_check(game.quest_progress("finale") == "game_complete" and main._screen_after_load() == "ending", "Starting another quest must preserve the completed finale and ending recovery")
	await _round_trip("Completed finale with new optional investigations")
	_check(main._screen_after_load() == "ending", "A postgame save restores the ending despite a different scalar focus")

func _travel(place: String) -> void:
	main.screen = "map"
	main._rebuild()
	await _settle()
	var markers: Array = main.content.find_children("*", "Button", true, false).filter(func(button): return str(button.tooltip_text) == game.place_name(place))
	if markers.size() != 1 or markers[0].disabled:
		_check(false, "Enabled map marker for %s" % place)
		return
	markers[0].pressed.emit()
	await _settle()
	_check(str(game.data.location) == place and main.screen == "location", "Map marker reaches %s" % place)

func _action(id: String) -> void:
	var entries: Array = main._location_actions(str(game.data.location))
	var enabled := entries.any(func(entry): return str(entry.id) == id and not bool(entry.get("disabled", false)))
	_check(enabled, "Local action %s is available in %s" % [id, game.data.location])
	if not enabled:
		return
	main._location_action_requested(id)
	await _dialogue()
	await _settle()

func _choice(id: String) -> void:
	var enabled: bool = main.choice_options.any(func(row): return str(row[2]) == id and (row.size() < 4 or not bool(row[3])))
	_check(main.screen == "choice" and enabled, "Choice %s is available in %s" % [id, main.choice_event])
	if main.screen != "choice" or not enabled:
		return
	main._resolve_choice(id)
	await _dialogue()
	await _settle()

func _dialogue() -> void:
	var steps := 0
	while main.screen == "dialogue" and steps < 20:
		main._advance_dialogue()
		steps += 1
	_check(steps < 20, "Dialogue completes without looping")
	await _settle()

func _round_trip(label: String) -> void:
	var before: Dictionary = game.data.duplicate(true)
	var saves := root.get_node("SaveManager")
	_check(saves.save_auto() and saves.load_auto(), label + " autosave round trip")
	_check(saves.save_slot(3) and saves.load_slot(3), label + " manual-save round trip")
	for field in ["quest_states", "companions", "investigations", "flags"]:
		_check(game.data[field] == before[field], label + " preserves " + field)
	for field in ["week", "silver", "acted_this_week", "quest_stage"]:
		_check(str(game.data[field]) == str(before[field]), label + " preserves " + field)
	for id in before.sect.buildings:
		_check(int(game.data.sect.buildings[id]) == int(before.sect.buildings[id]), label + " preserves building " + id)
	for id in ["herbs", "ore"]:
		_check(int(game.data.materials[id]) == int(before.materials[id]), label + " preserves material " + id)

func _journal_layout(label: String) -> void:
	var settings := root.get_node("SettingsManager")
	for scale in [1.0, 1.15, 1.3]:
		settings.data.ui_scale = scale
		settings.apply_settings()
		main.screen = "quests"
		main._rebuild()
		await _settle()
		var panel := main.content.find_child("QuestPanel", true, false) as Control
		var scroll := main.content.find_child("QuestScroll", true, false) as ScrollContainer
		_check(panel != null and scroll != null, "Journal exposes a panel and scroll area")
		if panel == null or scroll == null:
			continue
		var area: Rect2 = main.content.get_global_rect().intersection(root.get_visible_rect()).grow(1)
		_check(area.encloses(panel.get_global_rect()), "Journal panel fits at %d%% (%s)" % [roundi(scale * 100), label])
		for id in QUESTS.REGION_IDS:
			var row := main.content.find_child("Quest_%s" % id, true, false) as Label
			_check(row != null, "Journal retains regional row " + str(id))
			if row == null:
				continue
			var progress: String = game.quest_progress(id)
			var status := "已完成" if progress == QUESTS.REGION_STAGES[id].back() else ("待触发" if progress in ["available", "meet_master"] else "进行中")
			_check(status in row.text, "Journal displays actual independent status for " + str(id))
			scroll.ensure_control_visible(row)
			await _settle()
			_check(scroll.get_global_rect().grow(1).encloses(row.get_global_rect()), "Every journal row is reachable at %d%%: %s" % [roundi(scale * 100), id])
			_check(area.encloses(row.get_global_rect()), "Scrolled journal row stays in the visible content area")
		if capture:
			scroll.scroll_vertical = 0
			await _snapshot("quests-%s-%d.png" % [label, roundi(scale * 100)])
	settings.data.ui_scale = 1.0
	settings.apply_settings()
	await _settle()

func _settle() -> void:
	for frame in range(5):
		await process_frame

func _snapshot(filename: String) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("user://" + filename) == OK, "Capture " + filename)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
