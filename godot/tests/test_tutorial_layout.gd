extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(str(ProjectSettings.get_setting("application/config/name")).ends_with("-tests"))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var state = root.get_node("GameState")
	state.new_game()
	state.data.agility = 100
	state.data.tutorial = {"map": true, "location": true, "battle": true, "battle_tactics": true}
	assert(state.start_blackreed_battle())
	main.get_window().size = Vector2i(1280, 720)
	for step in ["battle_arts", "battle_defense"]:
		main._rebuild()
		for frame in range(4): await process_frame
		assert(main.active_tutorial_step == step)
		var buttons: Array = main.content.find_children("*", "Button", true, false).filter(func(button): return button.text in ["我知道了 · 继续", "跳过全部新手引导"])
		assert(buttons.size() == 2)
		for button in buttons:
			assert(button.get_global_rect().end.y <= main.toast_label.get_global_rect().position.y, "Long tutorial text must leave both navigation buttons above the footer.")
		if step == "battle_arts" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("user://tutorial_layout.png") == OK)
		main._dismiss_tutorial()
	print("Tutorial layout tests passed.")
	quit()
