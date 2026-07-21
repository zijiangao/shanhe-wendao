extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	var game_state: Node = root.get_node("GameState")
	main_scene.get_window().size = Vector2i(1280, 720)
	main_scene.screen = "location"
	main_scene._rebuild()
	for frame in range(2):
		await process_frame

	# The training menu (like the workshop) is built on the generic "choice"
	# screen, which NAVIGATION_RULES.back_action() blocks from any back
	# action. Confirm it ships its own always-enabled way out instead of
	# forcing the player to commit a week to training.
	main_scene._location_action_requested("train")
	for frame in range(3):
		await process_frame

	var leave_button: Button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("暂不修炼"):
			leave_button = b
	var leave_reachable := leave_button != null and not leave_button.disabled
	var menu_valid: bool = main_scene.screen == "choice" and main_scene.choice_event == "training" and leave_reachable
	# 采药/挖矿 were split out into their own 后山 hotspot -- confirm neither
	# leaks into 演武场's own option list.
	var no_gathering_in_training := not main_scene.find_children("*", "Button", true, false).any(func(b): return "采药" in (b as Button).text or "挖矿" in (b as Button).text)

	# 武学修炼 must stay disabled with no manuals learned yet -- it would
	# otherwise open a sub-menu with nothing but a "返回" row in it.
	var wuxue_training_button: Button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("武学修炼"):
			wuxue_training_button = b
	var wuxue_disabled_when_unlearned := wuxue_training_button != null and wuxue_training_button.disabled

	# Learn one move, then confirm 武学修炼 opens, lists it, trains it (spending
	# a week/energy like every other training action), and returns cleanly.
	game_state.data.silver = 1000
	var wuxue_rules = load("res://scripts/progression/wuxue_rules.gd")
	wuxue_rules.learn_move(game_state.data, "stone_splitting_fist")
	main_scene._show_training_menu()
	for frame in range(2):
		await process_frame
	wuxue_training_button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("武学修炼"):
			wuxue_training_button = b
	var wuxue_enabled_when_learned := wuxue_training_button != null and not wuxue_training_button.disabled
	var week_before_wuxue_training := int(game_state.data.week)
	var energy_before_wuxue_training := int(game_state.data.energy)
	if wuxue_training_button != null:
		wuxue_training_button.pressed.emit()
		for frame in range(2):
			await process_frame
	var wuxue_menu_open: bool = main_scene.screen == "choice" and main_scene.choice_event == "wuxue_training"
	var stone_fist_training_button: Button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if "裂石拳" in (b as Button).text:
			stone_fist_training_button = b
	var wuxue_training_ok := false
	if stone_fist_training_button != null:
		stone_fist_training_button.pressed.emit()
		for frame in range(2):
			await process_frame
		wuxue_training_ok = int(game_state.data.week) == week_before_wuxue_training + 1 and int(game_state.data.energy) == energy_before_wuxue_training - 1 and int(wuxue_rules.wuxue_xp(game_state.data, "stone_splitting_fist")) > 0 and main_scene.screen == "choice" and main_scene.choice_event == "wuxue_training"
	var wuxue_training_back_button: Button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("返回"):
			wuxue_training_back_button = b
	var wuxue_training_back_ok := false
	if wuxue_training_back_button != null:
		wuxue_training_back_button.pressed.emit()
		for frame in range(2):
			await process_frame
		wuxue_training_back_ok = main_scene.screen == "choice" and main_scene.choice_event == "training"

	# The nested sparring weapon-choice sub-menu needs its own way back to
	# the training menu, not just out of the training flow entirely.
	var spar_button: Button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if "实战切磋" in (b as Button).text:
			spar_button = b
	var spar_focus_valid := false
	if spar_button != null:
		spar_button.pressed.emit()
		for frame in range(3):
			await process_frame
		var back_button: Button = null
		for b in main_scene.find_children("*", "Button", true, false):
			if (b as Button).text.begins_with("返回"):
				back_button = b
		var back_reachable := back_button != null and not back_button.disabled
		if back_reachable:
			back_button.pressed.emit()
			for frame in range(3):
				await process_frame
		spar_focus_valid = back_reachable and main_scene.screen == "choice" and main_scene.choice_event == "training"

	# Now confirm the top-level leave option actually exits to location.
	leave_button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("暂不修炼"):
			leave_button = b
	var leave_works := false
	if leave_button != null and not leave_button.disabled:
		leave_button.pressed.emit()
		for frame in range(3):
			await process_frame
		leave_works = main_scene.screen == "location"

	# 采药/挖矿 were split out of 演武场 into their own 后山 hotspot -- confirm
	# neither combat discipline leaks into it, neither gathering discipline
	# leaks back into 演武场, and 后山's own leave button still works.
	main_scene._location_action_requested("gathering")
	for frame in range(3):
		await process_frame
	var gathering_menu_open: bool = main_scene.screen == "choice" and main_scene.choice_event == "gathering"
	var gathering_buttons: Array = main_scene.find_children("*", "Button", true, false)
	var has_herbalism_button := gathering_buttons.any(func(b): return "采药" in (b as Button).text)
	var has_mining_button := gathering_buttons.any(func(b): return "挖矿" in (b as Button).text)
	var no_combat_in_gathering := not gathering_buttons.any(func(b): return "剑法" in (b as Button).text or "刀法" in (b as Button).text)
	var gathering_leave_button: Button = null
	for b in gathering_buttons:
		if (b as Button).text.begins_with("暂不采集"):
			gathering_leave_button = b
	var gathering_leave_works := false
	if gathering_leave_button != null and not gathering_leave_button.disabled:
		gathering_leave_button.pressed.emit()
		for frame in range(2):
			await process_frame
		gathering_leave_works = main_scene.screen == "location"

	var valid: bool = menu_valid and wuxue_disabled_when_unlearned and wuxue_enabled_when_learned and wuxue_menu_open and wuxue_training_ok and wuxue_training_back_ok and spar_focus_valid and leave_works
	valid = valid and no_gathering_in_training and gathering_menu_open and has_herbalism_button and has_mining_button and no_combat_in_gathering and gathering_leave_works
	if not valid:
		push_error("Training menu regression: menu_valid=%s wuxue_disabled_when_unlearned=%s wuxue_enabled_when_learned=%s wuxue_menu_open=%s wuxue_training_ok=%s wuxue_training_back_ok=%s spar_focus_valid=%s leave_works=%s no_gathering_in_training=%s gathering_menu_open=%s has_herbalism_button=%s has_mining_button=%s no_combat_in_gathering=%s gathering_leave_works=%s" % [menu_valid, wuxue_disabled_when_unlearned, wuxue_enabled_when_learned, wuxue_menu_open, wuxue_training_ok, wuxue_training_back_ok, spar_focus_valid, leave_works, no_gathering_in_training, gathering_menu_open, has_herbalism_button, has_mining_button, no_combat_in_gathering, gathering_leave_works])
	quit(0 if valid else 18)
