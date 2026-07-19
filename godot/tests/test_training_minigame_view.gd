extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	main_scene._start_training("swordsmanship")
	main_scene.training_round = 1
	main_scene._next_training_target()
	main_scene._rebuild()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var play_path := "user://training_combo_preview.png"
	var play_result := main_scene.get_viewport().get_texture().get_image().save_png(play_path)
	main_scene._start_training("mining")
	main_scene.training_round = 1
	main_scene._next_training_target()
	main_scene._rebuild()
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var timing_path := "user://training_timing_preview.png"
	var timing_result := main_scene.get_viewport().get_texture().get_image().save_png(timing_path)
	main_scene.training_result = {
		"discipline": "herbalism", "grade": "S", "specialty_gain": 3,
		"xp": 12, "silver": 0, "item": "", "herbs": 3, "ore": 0,
		"score": 315, "best_streak": 3,
		"herb_discovery": {"id": "sevenstar_lotus", "name": "七星莲", "rarity": "奇珍", "description": "七瓣映星，只在灵气充盈处短暂开放。", "first_discovery": true, "count": 1, "xp": 2},
		"event": {"title": "石隙灵苗", "body": "你循着异香找到一簇罕见药苗，完整保住了根须。", "reward": "额外药材 +2"}
	}
	main_scene.training_discipline = "herbalism"
	main_scene._rebuild()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var result_path := "user://training_result_preview.png"
	var result_result := main_scene.get_viewport().get_texture().get_image().save_png(result_path)
	var buttons := main_scene.find_children("*", "Button", true, false)
	var labels := main_scene.find_children("*", "Label", true, false)
	var found_specimen := false
	for label in labels:
		if "新收录 药谱" in str((label as Label).text) and "七星莲" in str((label as Label).text):
			found_specimen = true
	var valid: bool = play_result == OK and timing_result == OK and result_result == OK and buttons.size() >= 1 and found_specimen
	print("Training previews saved to: %s, %s and %s" % [ProjectSettings.globalize_path(play_path), ProjectSettings.globalize_path(timing_path), ProjectSettings.globalize_path(result_path)])
	quit(0 if valid else 15)
