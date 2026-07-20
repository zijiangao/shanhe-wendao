extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var game_state = root.get_node("GameState")
	game_state.new_game()
	game_state.data.energy = 3
	assert(game_state.start_blackreed_battle(), "The defense tutorial preview needs a live tactical battle.")
	game_state.data.tutorial = {"map": true, "location": true, "battle": true, "battle_tactics": true, "battle_defense": false}
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	main_scene.screen = "battle"
	main_scene._rebuild()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var output_path := "user://defense_tutorial_preview.png"
	var result := main_scene.get_viewport().get_texture().get_image().save_png(output_path)
	var labels: Array = main_scene.find_children("*", "Label", true, false)
	var texts: Array[String] = []
	for label in labels:
		texts.append(str((label as Label).text))
	var valid: bool = result == OK and str(main_scene.active_tutorial_step) == "battle_defense"
	valid = valid and texts.any(func(value: String): return "攻 守 有 度" in value)
	valid = valid and texts.any(func(value: String): return "运气护体" in value and "恢复3点真气" in value)
	print("Defense tutorial preview saved to: %s" % ProjectSettings.globalize_path(output_path))
	quit(0 if valid else 21)
