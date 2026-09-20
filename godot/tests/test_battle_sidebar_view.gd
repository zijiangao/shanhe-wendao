extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(str(ProjectSettings.get_setting("application/config/name")).ends_with("-tests"), "Run UI tests in an isolated test project.")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var state = root.get_node("GameState")
	state.new_game()
	state.data.agility = 100
	state.data.learned_moves = ["cloud_sword", "blade_technique", "stone_splitting_fist", "night_triple_blade", "armor_splitting_spear"]
	for step in state.data.tutorial:
		state.data.tutorial[step] = true
	assert(state.start_blackreed_battle())
	for frame in range(4):
		await process_frame
	var side: Control = main.active_battle_view.get_node("BattleSidebar")
	var scroll: ScrollContainer = side.get_node("BattleSidebarScroll")
	assert(side.size.y <= 540 and side.size.x <= 400, "The fully learned battle panel must stay inside its assigned bounds.")
	assert(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "Long battle content must scroll rather than stretch the panel.")
	var end_buttons: Array = side.find_children("*", "Button", true, false).filter(func(button: Button): return button.text == "结束回合")
	assert(end_buttons.size() == 1)
	end_buttons[0].grab_focus()
	for frame in range(4):
		await process_frame
	var button_rect: Rect2 = end_buttons[0].get_global_rect()
	var viewport_rect := scroll.get_global_rect()
	assert(button_rect.position.y >= viewport_rect.position.y - 1 and button_rect.end.y <= viewport_rect.end.y + 1, "Keyboard focus must scroll the entire end-turn button into view.")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://battle_sidebar_preview.png")
	print("Battle sidebar tests passed.")
	quit()
