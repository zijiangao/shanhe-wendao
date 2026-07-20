extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	main_scene.screen = "achievements"
	main_scene._rebuild()
	for frame in range(4):
		await process_frame
	var scrolls: Array = main_scene.find_children("*", "ScrollContainer", true, false)
	if not scrolls.is_empty():
		(scrolls[0] as ScrollContainer).scroll_vertical = 9999
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var output_path := "user://achievements_preview.png"
	var result := main_scene.get_viewport().get_texture().get_image().save_png(output_path)
	var labels: Array = main_scene.find_children("*", "Label", true, false)
	var texts: Array[String] = []
	for label in labels:
		texts.append(str((label as Label).text))
	var expected_total := "/%d" % SteamService.definitions.size()
	var valid := result == OK and texts.any(func(value: String): return "江 湖 成 就" in value and expected_total in value)
	valid = valid and texts.any(func(value: String): return "一艺通神" in value)
	valid = valid and texts.any(func(value: String): return "百草入谱" in value)
	print("Achievement preview saved to: %s" % ProjectSettings.globalize_path(output_path))
	quit(0 if valid else 20)
