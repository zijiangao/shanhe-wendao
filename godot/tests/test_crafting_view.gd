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
	# 专精改为等级制、100级满 (0.105.0) -- 大成门槛从10级放大到100级。
	game_state.data.mining = 100

	# 炼药坊 (alchemy) offers the herb-based recipes only -- no forged gear,
	# no ore-discount rows (those belong to 锻造坊 now).
	main_scene._location_action_requested("workshop")
	for frame in range(4):
		await process_frame
	var powder_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(button: Button): return "回春散" in button.text)
	var no_gear_in_alchemy := not main_scene.find_children("*", "Button", true, false).any(func(b): return "自铸铁刃" in (b as Button).text or "挖矿专精减免" in (b as Button).text or "门派建设减免" in (b as Button).text)

	# 锻造坊 (forge) offers the ore-based gear recipes (霹雳石 was removed
	# 0.88.0 -- still buyable at 西市's 杂货铺, just not forged here).
	main_scene.screen = "location"
	main_scene._rebuild()
	for frame in range(2):
		await process_frame
	main_scene._location_action_requested("forge")
	for frame in range(4):
		await process_frame
	var discount_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(button: Button): return "挖矿专精减免" in button.text)
	var craft_weapon_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(button: Button): return "自铸铁刃" in button.text)
	var no_pills_in_forge := not main_scene.find_children("*", "Button", true, false).any(func(b): return "悟性丹" in (b as Button).text or "回春散" in (b as Button).text)
	var mining_source_valid: bool = craft_weapon_buttons.size() == 1 and "矿石2" in craft_weapon_buttons[0].text and "挖矿专精减免3" in craft_weapon_buttons[0].text and not "门派建设" in craft_weapon_buttons[0].text

	# These are explicit UI fixtures, separate from the unmodified-state story
	# journey. Exercise each discount source and the zero-cost clamp through the
	# actual craft buttons, including the amount deducted and equipment received.
	game_state.data.mining = 0
	game_state.data.sect.buildings.forge = 2
	main_scene._location_action_requested("forge")
	for frame in range(3): await process_frame
	var sect_button := _forged_blade_button(main_scene)
	var sect_source_valid: bool = sect_button != null and "矿石3" in sect_button.text and "门派建设减免2" in sect_button.text and not "挖矿专精" in sect_button.text and not sect_button.disabled
	if sect_source_valid:
		sect_button.pressed.emit()
		for frame in range(2): await process_frame
	sect_source_valid = sect_source_valid and int(game_state.data.materials.ore) == 2 and int(game_state.data.owned_weapons.get("forged_iron_blade", 0)) == 1 and bool(game_state.data.acted_this_week)
	game_state.end_week()
	game_state.data.mining = 100
	game_state.data.sect.buildings.forge = 3
	main_scene._location_action_requested("forge")
	for frame in range(3): await process_frame
	var combined_button := _forged_blade_button(main_scene)
	var combined_sources_valid: bool = combined_button != null and "矿石0" in combined_button.text and "挖矿专精减免3" in combined_button.text and "门派建设减免2" in combined_button.text and not "门派建设减免3" in combined_button.text and not combined_button.disabled
	if combined_sources_valid:
		combined_button.pressed.emit()
		for frame in range(2): await process_frame
	combined_sources_valid = combined_sources_valid and int(game_state.data.materials.ore) == 2 and int(game_state.data.owned_weapons.get("forged_iron_blade", 0)) == 2 and bool(game_state.data.acted_this_week)
	game_state.end_week()

	game_state.data.tutorial = {"map": true, "location": true, "battle": true, "battle_tactics": true}
	game_state.start_blackreed_battle()
	game_state.data.hp = 24
	main_scene.screen = "battle"
	main_scene._rebuild()
	for frame in range(4):
		await process_frame
	var battle_powder_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(button: Button): return "回春散" in button.text)
	var valid: bool = powder_buttons.size() == 1 and craft_weapon_buttons.size() == 1 and discount_buttons.size() > 0 and mining_source_valid and sect_source_valid and combined_sources_valid and no_gear_in_alchemy and no_pills_in_forge and battle_powder_buttons.size() == 1

	# A brand-new save has zero herbs/ore, so every real recipe starts
	# disabled. Confirm both buildings still offer a working way out instead
	# of stranding the player on an all-disabled choice screen.
	game_state.new_game()
	main_scene.screen = "location"
	main_scene._rebuild()
	for frame in range(2):
		await process_frame
	main_scene._location_action_requested("workshop")
	for frame in range(3):
		await process_frame
	var alchemy_leave_button: Button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("离开炼药坊"):
			alchemy_leave_button = b
	var alchemy_leave_reachable := alchemy_leave_button != null and not alchemy_leave_button.disabled
	if alchemy_leave_reachable:
		alchemy_leave_button.pressed.emit()
		for frame in range(2):
			await process_frame
	valid = valid and alchemy_leave_reachable and main_scene.screen == "location"

	main_scene._location_action_requested("forge")
	for frame in range(3):
		await process_frame
	var forge_leave_button: Button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("离开锻造坊"):
			forge_leave_button = b
	var forge_leave_reachable := forge_leave_button != null and not forge_leave_button.disabled
	if forge_leave_reachable:
		forge_leave_button.pressed.emit()
		for frame in range(2):
			await process_frame
	valid = valid and forge_leave_reachable and main_scene.screen == "location"

	# Crafting now spends the week's one action too (0.92.0) -- confirm a
	# real craft blocks re-entering either building until end_week().
	game_state.new_game()
	game_state.data.materials = {"herbs": 4, "ore": 5}
	main_scene.screen = "location"
	main_scene._rebuild()
	for frame in range(2):
		await process_frame
	main_scene._location_action_requested("workshop")
	for frame in range(3):
		await process_frame
	var powder_craft_button: Button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("炼制 · 回春散"):
			powder_craft_button = b
	var craft_reachable := powder_craft_button != null and not powder_craft_button.disabled
	if craft_reachable:
		powder_craft_button.pressed.emit()
		for frame in range(2):
			await process_frame
	var acted_after_craft: bool = bool(game_state.data.get("acted_this_week", false))
	main_scene._location_action_requested("forge")
	for frame in range(2):
		await process_frame
	var forge_blocked_same_week: bool = main_scene.screen == "location"
	game_state.end_week()
	main_scene._location_action_requested("forge")
	for frame in range(3):
		await process_frame
	var forge_open_after_end_week: bool = main_scene.screen == "choice" and main_scene.choice_event == "forge"
	valid = valid and craft_reachable and acted_after_craft and forge_blocked_same_week and forge_open_after_end_week

	if not valid:
		push_error("Forge discount source regression: mining_only=%s sect_only=%s combined_zero_cost=%s" % [mining_source_valid, sect_source_valid, combined_sources_valid])
		push_error("Crafting view regression: powder_buttons=%s craft_weapon_buttons=%s discount_buttons=%s no_gear_in_alchemy=%s no_pills_in_forge=%s battle_powder_buttons=%s alchemy_leave_reachable=%s forge_leave_reachable=%s craft_reachable=%s acted_after_craft=%s forge_blocked_same_week=%s forge_open_after_end_week=%s" % [powder_buttons.size(), craft_weapon_buttons.size(), discount_buttons.size(), no_gear_in_alchemy, no_pills_in_forge, battle_powder_buttons.size(), alchemy_leave_reachable, forge_leave_reachable, craft_reachable, acted_after_craft, forge_blocked_same_week, forge_open_after_end_week])
	quit(0 if valid else 17)

func _forged_blade_button(main_scene: Control) -> Button:
	for node in main_scene.find_children("*", "Button", true, false):
		if "自铸铁刃" in (node as Button).text:
			return node as Button
	return null
