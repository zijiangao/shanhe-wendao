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
	await RenderingServer.frame_post_draw
	var workshop_path := "user://crafting_workshop_preview.png"
	var workshop_result := main_scene.get_viewport().get_texture().get_image().save_png(workshop_path)
	var discount_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(button: Button): return "挖矿大成减免" in button.text and "银两 5" in button.text)
	game_state.data.tutorial = {"map": true, "location": true, "battle": true, "battle_tactics": true}
	game_state.start_blackreed_battle()
	game_state.data.hp = 24
	main_scene.screen = "battle"
	main_scene._rebuild()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var battle_path := "user://crafting_battle_preview.png"
	var battle_result := main_scene.get_viewport().get_texture().get_image().save_png(battle_path)
	var powder_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(button: Button): return "回春散" in button.text)
	var valid: bool = workshop_result == OK and battle_result == OK and powder_buttons.size() == 1 and discount_buttons.size() == 1

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
	await RenderingServer.frame_post_draw
	var empty_path := "user://crafting_workshop_empty_preview.png"
	var empty_result := main_scene.get_viewport().get_texture().get_image().save_png(empty_path)
	var leave_button: Button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("离开工坊"):
			leave_button = b
	var leave_reachable := leave_button != null and not leave_button.disabled
	if leave_reachable:
		leave_button.pressed.emit()
		for frame in range(2):
			await process_frame
	valid = valid and empty_result == OK and leave_reachable and main_scene.screen == "location"

	print("Crafting previews saved to: %s, %s, and %s" % [ProjectSettings.globalize_path(workshop_path), ProjectSettings.globalize_path(battle_path), ProjectSettings.globalize_path(empty_path)])
	quit(0 if valid else 17)
