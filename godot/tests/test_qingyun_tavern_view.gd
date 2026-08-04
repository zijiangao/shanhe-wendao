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
	game_state.data.silver = 50
	main_scene.screen = "location"
	main_scene._rebuild()
	for frame in range(2):
		await process_frame
	main_scene._location_action_requested("qingyun_tavern")
	for frame in range(3):
		await process_frame
	var top_prompt_ok: bool = "50" in str(main_scene.choice_prompt) and str(main_scene.choice_event) == "qingyun_tavern"

	# 50 silver affords neither disciple (cheapest is 300) -- every "招募"
	# row should be disabled, proving the gating reflects CompanionRules'
	# affordability check rather than always being open.
	var recruit_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return b.text.begins_with("招募"))
	var poor_gating_ok: bool = recruit_buttons.size() == 2
	for button in recruit_buttons:
		poor_gating_ok = poor_gating_ok and (button as Button).disabled

	game_state.data.silver = 1000
	main_scene._show_qingyun_tavern()
	for frame in range(3):
		await process_frame
	var zhou_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return "招募 · 周慕白" in b.text)
	var rich_afford_ok: bool = zhou_buttons.size() == 1 and not (zhou_buttons[0] as Button).disabled
	(zhou_buttons[0] as Button).pressed.emit()
	for frame in range(3):
		await process_frame
	var zhou_joined_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return "已招募 · 周慕白" in b.text and "当前随行" in b.text)
	var recruit_ok: bool = "zhou_mubai" in Array(game_state.data.companions) and str(game_state.data.active_disciple) == "zhou_mubai" and int(game_state.data.silver) == 700 and zhou_joined_buttons.size() == 1 and main_scene.screen == "choice" and str(main_scene.choice_event) == "qingyun_tavern"

	# Recruiting must not spend the week's one action -- it's a pure silver
	# transaction, unlike training/gathering/crafting/battles.
	var no_action_spent_ok: bool = not bool(game_state.data.acted_this_week)

	# "返回" from the tavern must land back on the location screen, not exit
	# to the world map -- the exact class of leave-button regression this
	# session has repeatedly caught for other new shop-style screens.
	var leave_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return (b as Button).text.begins_with("返回"))
	var back_ok := false
	if leave_buttons.size() == 1:
		(leave_buttons[0] as Button).pressed.emit()
		for frame in range(2):
			await process_frame
		back_ok = main_scene.screen == "location"

	var valid: bool = top_prompt_ok and poor_gating_ok and rich_afford_ok and recruit_ok and no_action_spent_ok and back_ok
	if not valid:
		push_error("Qingyun tavern screen regression: top_prompt_ok=%s poor_gating_ok=%s rich_afford_ok=%s recruit_ok=%s no_action_spent_ok=%s back_ok=%s" % [top_prompt_ok, poor_gating_ok, rich_afford_ok, recruit_ok, no_action_spent_ok, back_ok])
	quit(0 if valid else 19)
