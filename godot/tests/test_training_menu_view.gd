extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	main_scene.screen = "location"
	main_scene._rebuild()
	for frame in range(2):
		await process_frame

	# The training menu (like the workshop) is built on the generic "choice"
	# screen, which NAVIGATION_RULES.back_action() blocks from any back
	# action. Confirm it ships its own always-enabled way out instead of
	# forcing the player to commit a week to training.
	main_scene._location_action_requested("train")
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	main_scene.get_viewport().get_texture().get_image().save_png("user://training_menu_preview.png")

	var leave_button: Button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("暂不修炼"):
			leave_button = b
	var leave_reachable := leave_button != null and not leave_button.disabled
	var menu_valid: bool = main_scene.screen == "choice" and main_scene.choice_event == "training" and leave_reachable

	# The nested sparring weapon-choice sub-menu needs its own way back to
	# the training menu, not just out of the training flow entirely.
	var spar_button: Button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if "实战切磋" in (b as Button).text:
			spar_button = b
	var spar_focus_valid := false
	if spar_button != null:
		spar_button.pressed.emit()
		for frame in range(3):
			await process_frame
		var back_button: Button = null
		for b in main_scene.find_children("*", "Button", true, false):
			if (b as Button).text.begins_with("返回"):
				back_button = b
		var back_reachable := back_button != null and not back_button.disabled
		if back_reachable:
			back_button.pressed.emit()
			for frame in range(3):
				await process_frame
		spar_focus_valid = back_reachable and main_scene.screen == "choice" and main_scene.choice_event == "training"

	# Now confirm the top-level leave option actually exits to location.
	leave_button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("暂不修炼"):
			leave_button = b
	var leave_works := false
	if leave_button != null and not leave_button.disabled:
		leave_button.pressed.emit()
		for frame in range(3):
			await process_frame
		leave_works = main_scene.screen == "location"

	var valid: bool = menu_valid and spar_focus_valid and leave_works
	if not valid:
		push_error("Training menu regression: menu_valid=%s spar_focus_valid=%s leave_works=%s" % [menu_valid, spar_focus_valid, leave_works])
	print("Training menu preview saved to: %s" % ProjectSettings.globalize_path("user://training_menu_preview.png"))
	quit(0 if valid else 18)
