extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(str(ProjectSettings.get_setting("application/config/name")).ends_with("-tests"))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var game := root.get_node("GameState")
	game.new_game()
	game.data.learned_moves = ["cloud_sword"]
	game.data.move_levels = {"cloud_sword": 5}
	game.data.owned_weapons = {"iron_sword": 1}
	game.data.equipped_weapon = "iron_sword"
	game.data.swordsmanship = 12
	var saved_power: int = game.power()
	assert(root.get_node("SaveManager").save_slot(1))
	game.data.strength += 20
	var before: Dictionary = game.data.duplicate(true)
	main.screen = "save"
	main._rebuild()
	await process_frame
	var found := false
	for label in main.content.find_children("*", "Label", true, false):
		if ("战力 %d    气血" % saved_power) in label.text:
			found = true
	assert(found, "The save card must include equipment, specialties and martial arts from the saved journey.")
	assert(game.data == before, "Previewing a save must not replace the current journey.")
	print("Save power flow tests passed.")
	quit()
