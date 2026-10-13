extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var settings := root.get_node("SettingsManager")
	settings.data = settings.defaults()
	settings.apply_settings()
	var game := root.get_node("GameState")
	game.new_game()
	game.data.tutorial.location = true
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _settle()
	var valid := true
	for scale in [1.0, 1.15, 1.3]:
		settings.data.ui_scale = scale
		settings.apply_settings()
		for stage in ["available", "chapter_complete"]:
			game.new_game()
			game.data.tutorial.location = true
			assert(game.set_quest_progress("blackreed", stage))
			game.data.silver = 10000
			game.data.materials = {"herbs": 100, "ore": 100}
			main._show_sect_building()
			await _settle()
			var view := main.content.get_child(0) as Control
			var case_valid := await _check_options(view, main.content.get_global_rect(), 5)
			var buttons: Array = view.find_children("*", "Button", true, false)
			if buttons.size() == 5:
				for index in range(4):
					case_valid = not buttons[index].disabled and case_valid
				buttons[-1].pressed.emit()
				case_valid = main.screen == "location" and case_valid
			await _settle()
			valid = case_valid and valid
			print("Sect choice layout scale=%s stage=%s: %s" % [scale, stage, "passed" if case_valid else "FAILED"])
		# A shared ChoiceView also renders item icons and longer shop lists.
		main._show_market_weapons()
		await _settle()
		var shop := main.content.get_child(0) as Control
		var shop_valid := await _check_options(shop, main.content.get_global_rect(), main.choice_options.size())
		var shop_buttons: Array = shop.find_children("*", "Button", true, false)
		shop_buttons[-1].pressed.emit()
		shop_valid = main.screen == "choice" and main.choice_event == "market" and shop_valid
		await _settle()
		valid = shop_valid and valid
		print("Shop choice layout scale=%s: %s" % [scale, "passed" if shop_valid else "FAILED"])
		# Two-option story choices must retain both choices and their callbacks.
		main._clear_content()
		await _settle()
		var story: Control = load("res://scenes/ui/choice_view.tscn").instantiate()
		main.content.add_child(story)
		var selected := {"id": ""}
		story.option_selected.connect(func(id: String): selected.id = id)
		story.setup(null, "选择入山方式", [["循正门", "向守门弟子说明来意。", "front"], ["走小径", "沿山间小路前行。", "path"]])
		await _settle()
		var story_valid := await _check_options(story, main.content.get_global_rect(), 2)
		story.find_children("*", "Button", true, false)[-1].pressed.emit()
		story_valid = selected.id == "path" and story_valid
		valid = story_valid and valid
		print("Story choice layout scale=%s: %s" % [scale, "passed" if story_valid else "FAILED"])
		main._clear_content()
		await _settle()
	quit(0 if valid else 25)

func _check_options(view: Control, area: Rect2, expected_count: int) -> bool:
	var panel := view.find_child("ChoicePanel", true, false) as Control
	var scroll := view.find_child("ChoiceScroll", true, false) as ScrollContainer
	var buttons: Array = view.find_children("*", "Button", true, false)
	if panel == null or scroll == null or buttons.size() != expected_count:
		return false
	var valid := view.get_viewport_rect().grow(1).encloses(panel.get_global_rect())
	valid = area.grow(1).encloses(panel.get_global_rect()) and valid
	for button in buttons:
		if button.disabled:
			view.get_viewport().gui_release_focus()
			scroll.ensure_control_visible(button)
		else:
			button.grab_focus()
		await _settle()
		valid = scroll.get_global_rect().grow(1).encloses(button.get_global_rect()) and valid
		valid = area.grow(1).encloses(button.get_global_rect()) and valid
		valid = view.get_viewport_rect().grow(1).encloses(button.get_global_rect()) and valid
	return valid

func _settle() -> void:
	for frame in range(5):
		await process_frame
