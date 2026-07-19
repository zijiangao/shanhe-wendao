extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	main_scene._show_settings()
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var check_buttons := main_scene.find_children("*", "CheckButton", true, false)
	var output_path := "user://settings_preview.png"
	var result := main_scene.get_viewport().get_texture().get_image().save_png(output_path)
	var valid: bool = result == OK and check_buttons.size() >= 3
	print("Settings preview saved to: %s" % ProjectSettings.globalize_path(output_path))
	quit(0 if valid else 10)
