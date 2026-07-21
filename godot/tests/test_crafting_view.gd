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
	game_state.data.materials = {"herbs": 4, "ore": 5}
	game_state.data.consumables.healing_powder = 2
	game_state.data.mining = 10
	main_scene._location_action_requested("workshop")
	for frame in range(4):
		await process_frame
	var discount_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(button: Button): return "挖矿大成减免" in button.text)
	var craft_weapon_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(button: Button): return "自铸铁刃" in button.text)
	game_state.data.tutorial = {"map": true, "location": true, "battle": true, "battle_tactics": true}
	game_state.start_blackreed_battle()
	game_state.data.hp = 24
	main_scene.screen = "battle"
	main_scene._rebuild()
	for frame in range(4):
		await process_frame
	var powder_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(button: Button): return "回春散" in button.text)
	var valid: bool = powder_buttons.size() == 1 and craft_weapon_buttons.size() == 1 and discount_buttons.size() > 0

	# A brand-new save has zero herbs/ore, so every real recipe starts
	# disabled. Confirm the workshop still offers a working way out instead
	# of stranding the player on an all-disabled choice screen.
	game_state.new_game()
	main_scene.screen = "location"
	main_scene._rebuild()
	for frame in range(2):
		await process_frame
	main_scene._location_action_requested("workshop")
	for frame in range(3):
		await process_frame
	var leave_button: Button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("离开工坊"):
			leave_button = b
	var leave_reachable := leave_button != null and not leave_button.disabled
	if leave_reachable:
		leave_button.pressed.emit()
		for frame in range(2):
			await process_frame
	valid = valid and leave_reachable and main_scene.screen == "location"

	if not valid:
		push_error("Crafting view regression: powder_buttons=%s craft_weapon_buttons=%s discount_buttons=%s leave_reachable=%s" % [powder_buttons.size(), craft_weapon_buttons.size(), discount_buttons.size(), leave_reachable])
	quit(0 if valid else 17)
