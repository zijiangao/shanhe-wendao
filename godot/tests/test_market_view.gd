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
	game_state.data.silver = 20
	main_scene.screen = "location"
	main_scene._rebuild()
	for frame in range(2):
		await process_frame
	main_scene._location_action_requested("market")
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var top_path := "user://market_top_preview.png"
	var top_result := main_scene.get_viewport().get_texture().get_image().save_png(top_path)
	var top_prompt_ok: bool = "20" in str(main_scene.choice_prompt) and str(main_scene.choice_event) == "market"

	main_scene._resolve_choice("weapons")
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var poor_path := "user://market_weapons_poor_preview.png"
	var poor_result := main_scene.get_viewport().get_texture().get_image().save_png(poor_path)
	var cheapest_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return "购买并装备 · 铁胎剑" in b.text)
	var priciest_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return "购买并装备 · 龙纹古剑" in b.text)
	# Twenty silver affords the thirty-silver sword? No -- both should be
	# disabled at this budget, proving the choice-menu disabled state really
	# reflects ShopRules' affordability check rather than always being open.
	var poor_gating_ok: bool = cheapest_buttons.size() == 1 and (cheapest_buttons[0] as Button).disabled and priciest_buttons.size() == 1 and (priciest_buttons[0] as Button).disabled

	game_state.data.silver = 500
	main_scene._show_market_weapons()
	for frame in range(3):
		await process_frame
	var rich_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return "购买并装备 · 铁胎剑" in b.text)
	var rich_afford_ok: bool = rich_buttons.size() == 1 and not (rich_buttons[0] as Button).disabled
	(rich_buttons[0] as Button).pressed.emit()
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var bought_path := "user://market_weapons_equipped_preview.png"
	var bought_result := main_scene.get_viewport().get_texture().get_image().save_png(bought_path)
	var sell_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return "卖出 · 铁胎剑" in b.text)
	var purchase_ok: bool = str(game_state.data.equipped_weapon) == "iron_sword" and int(game_state.data.silver) == 470 and sell_buttons.size() == 1 and main_scene.screen == "choice" and str(main_scene.choice_event) == "market_weapons"

	# "返回" from the weapons submenu must land back on the top-level market
	# menu, not exit the shop entirely -- mirrors the training menu's
	# spar_focus sub-menu precedent.
	var leave_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return (b as Button).text.begins_with("返回"))
	var back_ok := false
	if leave_buttons.size() == 1:
		(leave_buttons[0] as Button).pressed.emit()
		for frame in range(2):
			await process_frame
		back_ok = str(main_scene.choice_event) == "market" and main_scene.screen == "choice"

	var valid: bool = top_result == OK and top_prompt_ok and poor_result == OK and poor_gating_ok and rich_afford_ok and bought_result == OK and purchase_ok and back_ok
	print("Market previews saved to: %s, %s, and %s" % [ProjectSettings.globalize_path(top_path), ProjectSettings.globalize_path(poor_path), ProjectSettings.globalize_path(bought_path)])
	quit(0 if valid else 18)
