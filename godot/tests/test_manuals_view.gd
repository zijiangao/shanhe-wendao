extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	var game_state: Node = root.get_node("GameState")
	main_scene.get_window().size = Vector2i(1280, 720)
	game_state.new_game()
	game_state.data.location = "luoyang"
	game_state.data.silver = 100
	main_scene.screen = "location"
	main_scene._rebuild()
	for frame in range(2):
		await process_frame
	main_scene._location_action_requested("market")
	for frame in range(2):
		await process_frame
	main_scene._resolve_choice("manuals")
	for frame in range(3):
		await process_frame
	var top_prompt_ok: bool = "100" in str(main_scene.choice_prompt) and str(main_scene.choice_event) == "market_manuals"

	# 100 silver affords none of the six manuals (cheapest is 150) -- every
	# "学习" row should be disabled, proving the gating really reflects
	# WuxueRules' affordability check rather than always being open.
	var learn_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return b.text.begins_with("学习"))
	var poor_gating_ok: bool = learn_buttons.size() == 6
	for button in learn_buttons:
		poor_gating_ok = poor_gating_ok and (button as Button).disabled

	game_state.data.silver = 1000
	main_scene._show_market_manuals()
	for frame in range(3):
		await process_frame
	var stone_fist_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return "学习 · 裂石拳" in b.text)
	var rich_afford_ok: bool = stone_fist_buttons.size() == 1 and not (stone_fist_buttons[0] as Button).disabled
	(stone_fist_buttons[0] as Button).pressed.emit()
	for frame in range(3):
		await process_frame
	var stone_fist_unequip_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return "卸下 · 裂石拳" in b.text)
	var learn_ok: bool = "stone_splitting_fist" in Array(game_state.data.learned_moves) and "stone_splitting_fist" in Array(game_state.data.equipped_moves) and int(game_state.data.silver) == 850 and stone_fist_unequip_buttons.size() == 1 and main_scene.screen == "choice" and str(main_scene.choice_event) == "market_manuals"

	# A learned move should also offer a direct "升级" (level-up) row, spending
	# silver in place to raise its level rather than requiring a separate
	# training minigame -- this is the actual leveling UI the player uses.
	var stone_fist_upgrade_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return "升级 · 裂石拳" in b.text)
	var upgrade_button_ok: bool = stone_fist_upgrade_buttons.size() == 1 and not (stone_fist_upgrade_buttons[0] as Button).disabled
	(stone_fist_upgrade_buttons[0] as Button).pressed.emit()
	for frame in range(2):
		await process_frame
	var upgrade_ok: bool = int(game_state.data.move_levels.get("stone_splitting_fist", 1)) == 2 and int(game_state.data.silver) == 790

	# Learning a second internal art must replace the first, exactly like
	# weapons/armor auto-equip -- unlike moves, internal arts have no capacity
	# concept, so there should never be an "already equipped, can't learn more"
	# state to gate against.
	var purple_mist_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return "学习 · 紫霞神功" in b.text)
	(purple_mist_buttons[0] as Button).pressed.emit()
	for frame in range(2):
		await process_frame
	var five_elements_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return "学习 · 五行归元功" in b.text)
	(five_elements_buttons[0] as Button).pressed.emit()
	for frame in range(2):
		await process_frame
	var replace_ok: bool = str(game_state.data.equipped_internal) == "five_elements_art" and "purple_mist_art" in Array(game_state.data.learned_internal)

	# "返回" from the manuals submenu must land back on the top-level market
	# menu, not exit the shop entirely -- this is the exact class of node this
	# session's _with_item_icons() padding bug hit before (the icon landing in
	# the "leave" row's disabled slot), so it must be explicitly re-verified
	# for this newest shop submenu rather than assumed safe by similarity.
	var leave_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return (b as Button).text.begins_with("返回"))
	var back_ok := false
	if leave_buttons.size() == 1:
		(leave_buttons[0] as Button).pressed.emit()
		for frame in range(2):
			await process_frame
		back_ok = str(main_scene.choice_event) == "market" and main_scene.screen == "choice"

	var valid: bool = top_prompt_ok and poor_gating_ok and rich_afford_ok and learn_ok and upgrade_button_ok and upgrade_ok and replace_ok and back_ok
	if not valid:
		push_error("Manuals screen regression: top_prompt_ok=%s poor_gating_ok=%s rich_afford_ok=%s learn_ok=%s upgrade_button_ok=%s upgrade_ok=%s replace_ok=%s back_ok=%s" % [top_prompt_ok, poor_gating_ok, rich_afford_ok, learn_ok, upgrade_button_ok, upgrade_ok, replace_ok, back_ok])
	quit(0 if valid else 19)
