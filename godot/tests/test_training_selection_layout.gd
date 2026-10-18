extends SceneTree

const WUXUE := preload("res://scripts/progression/wuxue_rules.gd")
const HOME_IDS := ["swordsmanship", "bladesmanship", "fistsmanship", "staffsmanship", "qingyun_spar", "wuxue_training"]
const CATEGORY_IDS := ["move", "internal", "lightness"]
var main: Control
var game: Node
var checks := 0
var failures: Array[String] = []
var capture := false
var return_positions := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var project_name := str(ProjectSettings.get_setting("application/config/name"))
	var test_data := OS.get_environment("APPDATA").replace("\\", "/").to_lower()
	if project_name not in ["ShanheWendao-iteration-tests", "山河问道"] or "/acceptance-" not in test_data:
		push_error("Use an isolated acceptance APPDATA for training selection tests.")
		quit(2)
		return
	capture = "--capture-training-selection" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	game = root.get_node("GameState")
	var settings := root.get_node("SettingsManager")
	settings.data = settings.defaults()
	settings.apply_settings()
	_new_game()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _settle()
	for scale in [1.0, 1.15, 1.3]:
		settings.data.ui_scale = scale
		settings.apply_settings()
		await _settle()
		_new_game()
		main._show_training_menu()
		await _settle()
		_check_home(scale, false)
		if capture:
			await _snapshot("training-home-%d.png" % roundi(scale * 100))
		await _press_option("wuxue_training")
		_check(main.choice_event == "wuxue_training", "The home entry opens martial arts practice")
		await _press_category("move")
		_check(_practice_buttons().is_empty(), "A new hero's empty move category does not offer invented arts")
		_check_layout("empty category at %d%%" % roundi(scale * 100))
		_check(_option_button("leave") != null and not _option_button("leave").disabled, "An empty category always has an enabled return")
		_check(not bool(game.data.acted_this_week), "Browsing an empty category does not spend the weekly action")
		if capture:
			await _snapshot("training-empty-%d.png" % roundi(scale * 100))
		await _press_option("leave")
		_check(main.choice_event == "training", "An empty category returns to the home menu")
		await _press_option("qingyun_spar")
		_check(main.choice_event == "spar_focus", "The sparring entry opens the weapon choice")
		_check_layout("sparring at %d%%" % roundi(scale * 100))
		for id in ["swordsmanship", "bladesmanship", "leave"]:
			var button := _option_button(id)
			_check(button != null and not button.disabled, "Sparring choice %s is reachable" % id)
		if capture:
			await _snapshot("training-sparring-%d.png" % roundi(scale * 100))
		await _press_option("leave")
		_check(main.choice_event == "training" and not bool(game.data.acted_this_week), "Sparring return does not reserve an action")
		for id in HOME_IDS.slice(0, 4):
			await _press_option(str(id))
			_check(main.screen == "training" and main.training_discipline == id, "Home route %s opens its actual discipline minigame" % id)
			_check(not bool(game.data.acted_this_week), "Opening a minigame does not spend an action before completion")
			# Close the unplayed preview through the existing result-return handler.
			# The one completed training action is tested in the real art browser.
			main._finish_training_screen()
			main._show_training_menu()
			await _settle()
		await _press_option("leave")
		_check(main.screen == "location", "The fixed home return reaches the sect")

		# Starter silver purchases every real catalog entry; no fabricated moves,
		# experience, or resources are inserted into this gameplay fixture.
		for id in WUXUE.MOVES:
			_check(WUXUE.learn_move(game.data, str(id)), "Learn real move " + str(id))
		for id in WUXUE.INTERNAL:
			if id not in game.data.learned_internal:
				_check(WUXUE.learn_internal(game.data, str(id)), "Learn real internal art " + str(id))
		for id in WUXUE.LIGHTNESS:
			if id not in game.data.learned_lightness:
				_check(WUXUE.learn_lightness(game.data, str(id)), "Learn real lightness art " + str(id))
		main._show_training_menu()
		await _settle()
		await _press_option("wuxue_training")
		var last_move := await _browse_catalog(scale)
		_check(not last_move.is_empty(), "Move pagination exposes a real practice action")
		if last_move.is_empty():
			continue
		var pager_before := _page_text()
		var week_before := int(game.data.week)
		var silver_before := int(game.data.silver)
		var move_id := last_move.trim_prefix("train_move_")
		var xp_before := WUXUE.wuxue_xp(game.data, move_id)
		await _press_option(last_move)
		_check(main.choice_event == "wuxue_training", "A practice action refreshes its own browser")
		_check(_page_text() == pager_before, "Practicing an art preserves its selected page")
		_check(int(game.data.week) == week_before and bool(game.data.acted_this_week), "One practice consumes one action without advancing the week")
		_check(WUXUE.wuxue_xp(game.data, move_id) > xp_before and int(game.data.silver) == silver_before, "Practice grants actual art experience without a silver cost")
		_check_layout("spent action at %d%%" % roundi(scale * 100))
		for button in _practice_buttons():
			_check(button.disabled, "Practice cards visibly disable after the weekly action is spent")
		var saved_xp := WUXUE.wuxue_xp(game.data, move_id)
		_check(root.get_node("SaveManager").load_auto(), "Training writes a loadable production autosave")
		_check(bool(game.data.acted_this_week) and int(game.data.week) == week_before and WUXUE.wuxue_xp(game.data, move_id) == saved_xp, "Autosave preserves the consumed action and exact training experience")
		var before_rejected: Dictionary = game.data.duplicate(true)
		_check(not game.train_wuxue("move", move_id).get("ok", false), "A second same-week practice is rejected")
		_check(game.data == before_rejected, "A rejected repeat preserves all resources and progress")
		await _press_option("leave")
		_check_home(scale, true)
		await _press_option("leave")
		main._end_week_requested()
		_check(int(game.data.week) == week_before + 1 and not bool(game.data.acted_this_week), "Ending the week restores exactly one available action")
		main._show_training_menu()
		await _settle()
		_check_home(scale, false)
		await _press_option("leave")
	await _small_window_layout()
	print("Training selection layout: %d checks, %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 29)

func _small_window_layout() -> void:
	var settings := root.get_node("SettingsManager")
	settings.data.ui_scale = 1.3
	settings.apply_settings()
	# Stress actual available content rather than the normal reference viewport.
	root.content_scale_size = Vector2i.ZERO
	for window_size in [Vector2i(1000, 720), Vector2i(1280, 600)]:
		root.size = window_size
		return_positions.clear()
		await _settle()
		_new_game()
		main._show_training_menu()
		await _settle()
		_check_home(1.3, false)
		if capture:
			await _snapshot("training-small-%dx%d-home.png" % [window_size.x, window_size.y])
		await _press_option("wuxue_training")
		await _press_category("move")
		_check_layout("empty category in %s" % window_size)
		if capture:
			await _snapshot("training-small-%dx%d-empty.png" % [window_size.x, window_size.y])
		await _press_option("leave")
		await _press_option("qingyun_spar")
		_check_layout("sparring in %s" % window_size)
		if capture:
			await _snapshot("training-small-%dx%d-sparring.png" % [window_size.x, window_size.y])
		await _press_option("leave")
		await _press_option("leave")
		for id in WUXUE.MOVES:
			_check(WUXUE.learn_move(game.data, str(id)), "Small-window fixture learns real move " + str(id))
		main._show_training_menu()
		await _settle()
		await _press_option("wuxue_training")
		await _browse_catalog(1.3, "small-%dx%d-" % [window_size.x, window_size.y])
		_check(not bool(game.data.acted_this_week), "Small-window browsing does not consume the weekly action")
		if capture:
			await _snapshot("training-small-%dx%d-moves-last-page.png" % [window_size.x, window_size.y])
		await _press_option("leave")
		await _press_option("leave")
		_check(main.screen == "location", "Small-window fixed return reaches the sect")

func _new_game() -> void:
	game.new_game()
	game.data.tutorial.location = true
	game.data.tutorial.map = true

func _check_home(scale: float, spent: bool) -> void:
	_check(main.screen == "choice" and main.choice_event == "training", "The training home remains the production choice flow")
	_check_layout("home at %d%%" % roundi(scale * 100))
	for id in HOME_IDS:
		var button := _option_button(id)
		_check(button != null, "Home retains action " + id)
		if button != null and id != "wuxue_training":
			_check(button.disabled == spent, "Home weekly availability is accurate for " + id)
	var leave := _option_button("leave")
	_check(leave != null and not leave.disabled, "The home return stays enabled before and after training")

func _browse_catalog(scale: float, capture_prefix: String = "") -> String:
	var seen := {}
	var last_move := ""
	for category in CATEGORY_IDS:
		await _press_category(category)
		var pages := 0
		while pages < 10:
			pages += 1
			_check_layout("%s page %d at %d%%" % [category, pages, roundi(scale * 100)])
			for button in _practice_buttons():
				var id := str(button.get_meta("option_id", ""))
				seen[id] = true
				_check(not button.disabled, "Every unmastered art is available before training")
				if category == "move":
					last_move = id
			if capture:
				await _snapshot("training-%s%s-%d-page%d.png" % [capture_prefix, category, roundi(scale * 100), pages])
			var next := _named_button("TrainingNextPage")
			if next == null or next.disabled:
				break
			var before := _page_text()
			next.pressed.emit()
			await _settle()
			_check(_page_text() != before, "The next-page button changes the displayed page")
		_check(pages < 10, "Pagination terminates for the real catalog")
	for option in WUXUE.options_training(game.data):
		if str(option[2]) != "leave":
			_check(seen.has(str(option[2])), "Category and page navigation reaches " + str(option[2]))
	# Return to the final move page so the action tests retain that exact page.
	await _press_category("move")
	var guard := 0
	var next := _named_button("TrainingNextPage")
	while next != null and not next.disabled and guard < 10:
		next.pressed.emit()
		await _settle()
		guard += 1
		next = _named_button("TrainingNextPage")
	return last_move

func _view() -> Control:
	for child in main.content.get_children():
		if child is Control and child.get_script() != null and str(child.get_script().resource_path).ends_with("training_selection_view.gd"):
			return child
	return null

func _option_button(id: String) -> Button:
	var view := _view()
	if view == null:
		return null
	for button in view.find_children("*", "Button", true, false):
		if str(button.get_meta("option_id", "")) == id:
			return button
	return null

func _practice_buttons() -> Array:
	var view := _view()
	if view == null:
		return []
	return view.find_children("*", "Button", true, false).filter(func(button): return str(button.get_meta("option_id", "")).begins_with("train_"))

func _named_button(node_name: String) -> Button:
	var view := _view()
	return view.find_child(node_name, true, false) as Button if view != null else null

func _page_text() -> String:
	var view := _view()
	var label := view.find_child("TrainingPageLabel", true, false) as Label if view != null else null
	return label.text if label != null else ""

func _press_category(id: String) -> void:
	var view := _view()
	var tab: Button
	if view != null:
		for button in view.find_children("*", "Button", true, false):
			if str(button.get_meta("category_id", "")) == id:
				tab = button
	_check(tab != null and not tab.disabled, "Category tab %s is available" % id)
	if tab != null and not tab.disabled:
		tab.pressed.emit()
		await _settle()
		_check(str(_view().active_category) == id and int(_view().current_page) == 0, "Changing categories selects the requested group and its first page")

func _press_option(id: String) -> void:
	var button := _option_button(id)
	_check(button != null and not button.disabled, "Enabled training option " + id)
	if button != null and not button.disabled:
		button.pressed.emit()
		await _settle()

func _check_layout(context: String) -> void:
	var view := _view()
	_check(view != null, "Dedicated training selection view at " + context)
	if view == null:
		return
	_check(view.find_children("*", "ScrollContainer", true, false).is_empty(), "Training selection has no scrolling container at " + context)
	var area: Rect2 = main.content.get_global_rect().intersection(root.get_visible_rect()).grow(1)
	var buttons: Array = view.find_children("*", "Button", true, false)
	for button in buttons:
		if button.is_visible_in_tree():
			_check(area.encloses(button.get_global_rect()), "Visible training control %s fits at %s" % [button.name, context])
	var leave := _named_button("TrainingReturn")
	_check(leave != null and area.encloses(leave.get_global_rect()), "The fixed return is visible at " + context)
	if leave != null:
		var scale_key := str(root.get_node("SettingsManager").data.ui_scale)
		var position := leave.get_global_rect().get_center()
		if return_positions.has(scale_key):
			_check(position.distance_to(return_positions[scale_key]) <= 1.0, "Return stays in a fixed position across categories, pages, and modes")
		else:
			return_positions[scale_key] = position
	for left_index in range(buttons.size()):
		for right_index in range(left_index + 1, buttons.size()):
			var left := buttons[left_index] as Button
			var right := buttons[right_index] as Button
			if left.is_visible_in_tree() and right.is_visible_in_tree():
				_check(not left.get_global_rect().grow(-0.5).intersects(right.get_global_rect().grow(-0.5)), "Training controls have separate click targets at " + context)

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
