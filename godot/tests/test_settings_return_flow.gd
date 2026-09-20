extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	for origin in ["pause", "menu", "location"]:
		main.previous_screen = origin
		main.screen = "settings"
		main._rebuild()
		await process_frame
		for button in main.find_children("*", "Button", true, false):
			if button.text == "键位设置":
				button.pressed.emit()
				break
		assert(main.screen == "controls" and main.previous_screen == origin)
		var cancel := InputEventAction.new()
		cancel.action = "ui_cancel"
		cancel.pressed = true
		main._unhandled_input(cancel)
		assert(main.screen == "settings")
		main._unhandled_input(cancel)
		assert(main.screen == origin, "Settings must retain its source after editing controls.")
	print("Settings return flow tests passed.")
	quit()
