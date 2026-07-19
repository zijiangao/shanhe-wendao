extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	main_scene._start_training("swordsmanship")
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var play_path := "user://training_combo_preview.png"
	var play_result := main_scene.get_viewport().get_texture().get_image().save_png(play_path)
	main_scene._start_training("mining")
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var timing_path := "user://training_timing_preview.png"
	var timing_result := main_scene.get_viewport().get_texture().get_image().save_png(timing_path)
	main_scene.training_result = {
		"discipline": "mining", "grade": "S", "specialty_gain": 3,
		"xp": 12, "silver": 12, "item": "", "score": 285
	}
	main_scene._rebuild()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var result_path := "user://training_result_preview.png"
	var result_result := main_scene.get_viewport().get_texture().get_image().save_png(result_path)
	var buttons := main_scene.find_children("*", "Button", true, false)
	var valid: bool = play_result == OK and timing_result == OK and result_result == OK and buttons.size() >= 1
	print("Training previews saved to: %s, %s and %s" % [ProjectSettings.globalize_path(play_path), ProjectSettings.globalize_path(timing_path), ProjectSettings.globalize_path(result_path)])
	quit(0 if valid else 15)
