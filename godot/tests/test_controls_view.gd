extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	var settings: Node = root.get_node("SettingsManager")
	settings.data.key_bindings = settings.DEFAULT_KEY_BINDINGS.duplicate(true)
	settings.set_key_binding("ui_up", KEY_I, false)
	main_scene.screen = "controls"
	main_scene.previous_screen = "settings"
	main_scene._rebuild()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var output_path := "user://controls_preview.png"
	var result := main_scene.get_viewport().get_texture().get_image().save_png(output_path)
	var buttons: Array = main_scene.find_children("*", "Button", true, false)
	var labels: Array[String] = []
	for button in buttons:
		labels.append(str((button as Button).text))
	var valid := result == OK and "I" in labels and "D" in labels and "S" in labels and "A" in labels
	valid = valid and "恢复 WASD 默认键位" in labels and "返回设置" in labels
	settings.reset_key_bindings(false)
	print("Controls preview saved to: %s" % ProjectSettings.globalize_path(output_path))
	quit(0 if valid else 21)
