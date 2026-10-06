extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	var settings: Node = root.get_node("SettingsManager")
	settings.data = settings.defaults()
	settings.data.key_bindings = settings.DEFAULT_KEY_BINDINGS.duplicate(true)
	settings.set_key_binding("ui_up", KEY_I, false)
	var valid := true
	for scale in [1.0, 1.15, 1.3]:
		settings.data.ui_scale = scale
		settings.apply_settings()
		main_scene.screen = "controls"
		main_scene.previous_screen = "settings"
		main_scene._rebuild()
		await _settle()
		var case_valid := await _check_reachable_controls(main_scene)
		valid = case_valid and valid
		print("Controls layout scale=%s: %s" % [scale, "passed" if case_valid else "FAILED"])
	settings.data.ui_scale = 1.0
	settings.apply_settings()
	main_scene.screen = "controls"
	main_scene._rebuild()
	await _settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var output_path := "user://controls_preview.png"
		valid = main_scene.get_viewport().get_texture().get_image().save_png(output_path) == OK and valid
		print("Controls preview saved to: %s" % ProjectSettings.globalize_path(output_path))
	settings.reset_key_bindings(false)
	quit(0 if valid else 21)

func _check_reachable_controls(main_scene: Control) -> bool:
	var frame := main_scene.content.find_child("ControlsPanel", true, false) as Control
	var scroll := main_scene.content.find_child("SettingsScroll", true, false) as ScrollContainer
	var buttons: Array = main_scene.content.find_children("*", "Button", true, false)
	var labels: Array[String] = []
	var reset: Button
	var back: Button
	for button in buttons:
		labels.append(str(button.text))
		if button.text == "恢复 WASD 默认键位":
			reset = button
		elif button.text == "返回设置":
			back = button
	if frame == null or scroll == null or reset == null or back == null:
		return false
	var valid := "I" in labels and "D" in labels and "S" in labels and "A" in labels
	valid = main_scene.get_viewport_rect().grow(1).encloses(frame.get_global_rect()) and valid
	valid = main_scene.content.get_global_rect().grow(1).encloses(frame.get_global_rect()) and valid
	reset.grab_focus()
	await _settle()
	valid = scroll.get_global_rect().grow(1).encloses(reset.get_global_rect()) and valid
	valid = main_scene.get_viewport_rect().grow(1).encloses(back.get_global_rect()) and valid
	back.pressed.emit()
	valid = main_scene.screen == "settings" and valid
	await _settle()
	return valid

func _settle() -> void:
	for frame in range(5):
		await process_frame
