extends SceneTree

# 藏经阁 (0.91.0) used to be a fixed one-off story dialogue about 玄铁令;
# it now shows a read-only list of every learned wuxue instead. Confirm the
# hotspot opens the new choice screen, lists a learned move with its
# equipped state, and its leave button returns cleanly to location.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	var game_state: Node = root.get_node("GameState")
	main_scene.get_window().size = Vector2i(1280, 720)
	game_state.new_game()
	game_state.data.silver = 1000
	var wuxue_rules = load("res://scripts/progression/wuxue_rules.gd")
	wuxue_rules.learn_move(game_state.data, "stone_splitting_fist")

	main_scene.screen = "location"
	main_scene._rebuild()
	for frame in range(2):
		await process_frame
	main_scene._location_action_requested("library")
	for frame in range(3):
		await process_frame
	var library_open: bool = main_scene.screen == "choice" and main_scene.choice_event == "library"
	var buttons: Array = main_scene.find_children("*", "Button", true, false)
	var move_button: Button = null
	for b in buttons:
		if "裂石拳" in (b as Button).text:
			move_button = b
	var move_shown_disabled := move_button != null and move_button.disabled and "已装备" in move_button.text

	var leave_button: Button = null
	for b in buttons:
		if (b as Button).text.begins_with("返回"):
			leave_button = b
	var leave_reachable := leave_button != null and not leave_button.disabled
	if leave_reachable:
		leave_button.pressed.emit()
		for frame in range(2):
			await process_frame
	var leave_works: bool = leave_reachable and main_scene.screen == "location"

	var valid: bool = library_open and move_shown_disabled and leave_works
	if not valid:
		push_error("Library view regression: library_open=%s move_shown_disabled=%s leave_works=%s" % [library_open, move_shown_disabled, leave_works])
	quit(0 if valid else 23)
