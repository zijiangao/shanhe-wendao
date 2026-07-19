extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	var game_state: Node = root.get_node("GameState")
	game_state.new_game()
	game_state.data.location = "qingyun"
	main_scene.screen = "location"
	main_scene._rebuild()
	main_scene._open_pause()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var output_path := "user://pause_menu_preview.png"
	var result := main_scene.get_viewport().get_texture().get_image().save_png(output_path)
	var buttons: Array = main_scene.find_children("*", "Button", true, false)
	var required := ["继续江湖", "设置", "保存并返回主菜单", "保存并退出游戏"]
	var valid: bool = result == OK and required.all(func(label: String): return buttons.any(func(button: Button): return button.text == label))
	print("Pause preview saved to: %s" % ProjectSettings.globalize_path(output_path))
	quit(0 if valid else 19)
