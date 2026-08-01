extends SceneTree

# 藏经阁 (0.91.0) used to be a fixed one-off story dialogue about 玄铁令; it
# then became a read-only flat list of every learned wuxue. As of 0.103.0
# it's a dedicated left/right category browser (screen == "library"): left
# column has 拳掌/剑法/刀法/枪棍/内功/轻功 buttons, right side shows the
# selected category's learned wuxue. Confirm the hotspot opens it, the
# default category shows a learned move, clicking another category switches
# the right panel, and 返回 leaves cleanly back to location.

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
	wuxue_rules.learn_move(game_state.data, "cloud_sword")

	main_scene.screen = "location"
	main_scene._rebuild()
	for frame in range(2):
		await process_frame
	main_scene._location_action_requested("library")
	for frame in range(3):
		await process_frame
	var library_open: bool = main_scene.screen == "library"

	var buttons: Array = main_scene.find_children("*", "Button", true, false)
	var move_label: Label = null
	for l in main_scene.find_children("*", "Label", true, false):
		if "裂石拳" in (l as Label).text:
			move_label = l
	var fist_shown: bool = move_label != null and "已装备" in move_label.text

	var sword_button: Button = null
	for b in buttons:
		if (b as Button).text == "剑法":
			sword_button = b
	var category_switched := false
	if sword_button != null:
		sword_button.pressed.emit()
		for frame in range(2):
			await process_frame
		category_switched = main_scene.library_category == "sword"
		var cloud_label: Label = null
		for l in main_scene.find_children("*", "Label", true, false):
			if "流云剑法" in (l as Label).text:
				cloud_label = l
		category_switched = category_switched and cloud_label != null

	buttons = main_scene.find_children("*", "Button", true, false)
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

	var valid: bool = library_open and fist_shown and category_switched and leave_works
	if not valid:
		push_error("Library view regression: library_open=%s fist_shown=%s category_switched=%s leave_works=%s" % [library_open, fist_shown, category_switched, leave_works])
	quit(0 if valid else 23)
