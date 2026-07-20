extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var game_state = root.get_node("GameState")
	game_state.new_game()
	game_state.data.energy = 3
	assert(game_state.start_qingyun_spar_battle("bladesmanship"), "The sparring preview needs a live blade lesson.")
	game_state.data.tutorial = {"map": true, "location": true, "sparring": true, "battle": true, "battle_tactics": true, "battle_defense": true}
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	main_scene.screen = "battle"
	main_scene._rebuild()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var output_path := "user://qingyun_spar_preview.png"
	var result := main_scene.get_viewport().get_texture().get_image().save_png(output_path)
	var texts: Array[String] = []
	for label in main_scene.find_children("*", "Label", true, false):
		texts.append(str((label as Label).text))
	var buttons: Array[String] = []
	for button in main_scene.find_children("*", "Button", true, false):
		buttons.append(str((button as Button).text))
	var valid: bool = result == OK and str(game_state.data.battle.battle_id) == "qingyun_spar"
	valid = valid and texts.any(func(value: String): return "青云演武场" in value and "第 1 回合" in value)
	valid = valid and texts.any(func(value: String): return "演武课题" in value and "兵器方向：刀法" in value)
	valid = valid and texts.any(func(value: String): return "青云快剑" in value)
	valid = valid and buttons.any(func(value: String): return "断岳刀法" in value and "6真气" in value)
	print("Qingyun sparring preview saved to: %s" % ProjectSettings.globalize_path(output_path))
	quit(0 if valid else 22)
