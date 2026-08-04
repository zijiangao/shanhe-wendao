extends SceneTree

# 同行侠客面板 (0.110.0): the quest screen now shows the same panel as the
# character screen, listing 林清霜 (story companion) and whichever 客栈
# disciple is currently active -- not just a one-off mention baked into the
# 华山 quest stage's own text.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	var game_state: Node = root.get_node("GameState")
	main_scene.get_window().size = Vector2i(1280, 720)
	game_state.new_game()
	main_scene.screen = "quests"
	main_scene._rebuild()
	for frame in range(3):
		await process_frame
	var labels: Array = main_scene.find_children("*", "Label", true, false)
	var solo_shows_none := labels.any(func(l): return "同行侠客：暂无" in str((l as Label).text))

	game_state.data.silver = 1000
	var companion_rules = load("res://scripts/progression/companion_rules.gd")
	companion_rules.recruit(game_state.data, "zhou_mubai")
	main_scene._rebuild()
	for frame in range(3):
		await process_frame
	labels = main_scene.find_children("*", "Label", true, false)
	var recruited_shown := labels.any(func(l): return "同行侠客：周慕白" in str((l as Label).text))

	var valid: bool = solo_shows_none and recruited_shown
	if not valid:
		push_error("Quest view regression: solo_shows_none=%s recruited_shown=%s" % [solo_shows_none, recruited_shown])
	quit(0 if valid else 12)
