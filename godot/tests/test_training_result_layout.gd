extends SceneTree

var capture := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	capture = "--capture-training-result" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	var game := root.get_node("GameState")
	var settings := root.get_node("SettingsManager")
	settings.data = settings.defaults()
	settings.apply_settings()
	game.new_game()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _settle()
	for scale in [1.0, 1.3]:
		settings.data.ui_scale = scale
		settings.apply_settings()
		await _settle()
		game.new_game()
		main.training_discipline = "herbalism"
		main.training_round = 3
		main.training_scores = [85, 105, 0]
		main.training_challenge = {}
		main.training_started_ms = 1
		main.training_result = _result()
		main.screen = "training"
		main._rebuild()
		await _settle()
		var view: Control = main.active_training_view
		assert(view != null, "The training view must exist.")
		var scroll := view.find_child("TrainingResultScroll", true, false) as ScrollContainer
		assert(scroll != null, "A tall result needs a scrollable detail area.")
		var done := _done_button(view)
		assert(done != null and done.is_visible_in_tree() and not done.disabled, "The result must always expose an enabled 收功 button.")
		var area: Rect2 = view.get_viewport_rect().grow(1)
		assert(area.encloses(done.get_global_rect()), "The 收功 button must remain inside the visible viewport at scale %.1f." % scale)
		assert(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "The long result content should actually overflow and be scrollable.")
		if capture:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://training-result-%d.png" % roundi(scale * 100))
		done.pressed.emit()
		await _settle()
		assert(main.screen == "location", "Pressing 收功 must leave the result screen.")
	print("Training result layout tests passed.")
	quit()

func _done_button(view: Control) -> Button:
	for button in view.find_children("*", "Button", true, false):
		if (button as Button).text.begins_with("收功"):
			return button
	return null

func _result() -> Dictionary:
	return {
		"discipline": "herbalism",
		"grade": "B",
		"score": 190,
		"best_streak": 2,
		"specialty_rank": "初学",
		"rank_up": false,
		"weekly_focus": false,
		"specialty_gain": 1,
		"xp": 6,
		"herbs": 1,
		"silver": 0,
		"item": "",
		"record": {"new_best": true, "best_score": 190},
		"round_details": [
			{"elapsed_ms": 2370, "feedback": "辨识正确", "score": 85},
			{"elapsed_ms": 1480, "feedback": "辨识正确", "score": 105},
			{"elapsed_ms": 1050, "feedback": "失误", "score": 0}
		],
		"herb_discovery": {
			"name": "凝露草",
			"rarity": "寻常",
			"description": "晨露未散时采下，可止血生肌。",
			"gather_level": 1,
			"catches_to_next_level": 2,
			"first_discovery": true,
			"xp": 2
		},
		"event": {
			"title": "就地制药",
			"body": "新采的药性正盛，你当场调成一包可用于战斗的回春散。",
			"reward": "回春散 +1"
		}
	}

func _settle() -> void:
	for frame in range(5):
		await process_frame
