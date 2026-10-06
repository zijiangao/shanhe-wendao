extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	var settings := root.get_node("SettingsManager")
	var valid := true
	for scale in [1.0, 1.15, 1.3]:
		for difficulty in settings.DIFFICULTIES:
			settings.data = settings.defaults()
			settings.data.ui_scale = scale
			settings.data.difficulty = difficulty
			settings.apply_settings()
			main_scene.previous_screen = "pause"
			main_scene.screen = "settings"
			main_scene._rebuild()
			await _settle()
			var case_valid := await _check_reachable_settings(main_scene)
			valid = case_valid and valid
			print("Settings layout scale=%s difficulty=%s: %s" % [scale, difficulty, "passed" if case_valid else "FAILED"])
	settings.data = settings.defaults()
	settings.apply_settings()
	main_scene.screen = "settings"
	main_scene._rebuild()
	await _settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var output_path := "user://settings_preview.png"
		valid = main_scene.get_viewport().get_texture().get_image().save_png(output_path) == OK and valid
		print("Settings preview saved to: %s" % ProjectSettings.globalize_path(output_path))
	quit(0 if valid else 10)

func _check_reachable_settings(main_scene: Control) -> bool:
	var frame := main_scene.content.find_child("SettingsPanel", true, false) as Control
	var scroll := main_scene.content.find_child("SettingsScroll", true, false) as ScrollContainer
	var buttons: Array = main_scene.content.find_children("*", "Button", true, false)
	var controls: Button
	var tutorial: Button
	var back: Button
	for button in buttons:
		match button.text:
			"键位设置": controls = button
			"重新显示新手引导": tutorial = button
			"返回": back = button
	if frame == null or scroll == null or controls == null or tutorial == null or back == null:
		return false
	var valid: bool = main_scene.content.find_children("*", "CheckButton", true, false).size() >= 3
	valid = main_scene.get_viewport_rect().grow(1).encloses(frame.get_global_rect()) and valid
	valid = main_scene.content.get_global_rect().grow(1).encloses(frame.get_global_rect()) and valid
	# Focusing the bottom actions must scroll them into view for keyboard /
	# controller users, while the exit remains on screen throughout.
	for button in [controls, tutorial]:
		button.grab_focus()
		await _settle()
		valid = scroll.get_global_rect().grow(1).encloses(button.get_global_rect()) and valid
		valid = main_scene.get_viewport_rect().grow(1).encloses(back.get_global_rect()) and valid
	valid = scroll.get_v_scroll_bar().value > 0 and valid
	back.pressed.emit()
	valid = main_scene.screen == "pause" and valid
	await _settle()
	return valid

func _settle() -> void:
	for frame in range(5):
		await process_frame
