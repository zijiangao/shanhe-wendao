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
	# _next_training_target() resets training_started_ms to the "pending
	# start" sentinel (0) that TRAINING_READY_DELAY relies on in normal play.
	# This test calls it directly instead of going through
	# _show_training_round_ready(), so nothing would ever clear the sentinel
	# on its own -- these previews are meant to depict a live, already-active
	# round, not the disabled pre-start state, so force it forward.
	main_scene.training_started_ms = Time.get_ticks_msec()
	main_scene._rebuild()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var play_path := "user://training_combo_preview.png"
	var play_result := main_scene.get_viewport().get_texture().get_image().save_png(play_path)
	main_scene._start_training("mining")
	main_scene.training_round = 1
	main_scene._next_training_target()
	main_scene.training_started_ms = Time.get_ticks_msec()
	main_scene._rebuild()
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var timing_path := "user://training_timing_preview.png"
	var timing_result := main_scene.get_viewport().get_texture().get_image().save_png(timing_path)
	main_scene.training_result = {
		"discipline": "mining", "grade": "S", "specialty_gain": 3,
		"xp": 12, "silver": 12, "item": "", "herbs": 0, "ore": 3,
		"score": 315, "best_streak": 3,
		"specialty_level": 6, "specialty_rank": "精通", "rank_up": true,
		"record": {"new_best": true, "best_score": 315, "best_grade": "S", "best_streak": 3, "attempts": 2},
		"mineral_discovery": {"id": "star_marrow", "name": "星陨髓", "rarity": "奇珍", "description": "陨铁深处凝成的银蓝结晶，落锤时声如清钟。", "first_discovery": true, "count": 1, "silver": 2},
		"event": {"title": "古炉残火", "body": "你沿着热流掘开石壁，发现一座尚有余温的旧炉。", "reward": "额外矿石 +2"}
	}
	main_scene.training_discipline = "mining"
	main_scene._rebuild()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var result_path := "user://training_result_preview.png"
	var result_result := main_scene.get_viewport().get_texture().get_image().save_png(result_path)
	var buttons := main_scene.find_children("*", "Button", true, false)
	var labels := main_scene.find_children("*", "Label", true, false)
	var found_specimen := false
	var found_record := false
	var found_rank_up := false
	for label in labels:
		if "新收录 矿谱" in str((label as Label).text) and "星陨髓" in str((label as Label).text):
			found_specimen = true
		if "个人新纪录" in str((label as Label).text):
			found_record = true
		if "技艺突破 · 精通" in str((label as Label).text):
			found_rank_up = true
	var valid: bool = play_result == OK and timing_result == OK and result_result == OK and buttons.size() >= 1 and found_specimen and found_record and found_rank_up
	print("Training previews saved to: %s, %s and %s" % [ProjectSettings.globalize_path(play_path), ProjectSettings.globalize_path(timing_path), ProjectSettings.globalize_path(result_path)])
	quit(0 if valid else 15)
