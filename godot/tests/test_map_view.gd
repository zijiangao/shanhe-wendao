extends SceneTree

# Luoyang's West Market (shop + backpack economy) is meant to be reachable
# from the very start of a playthrough, unlike every other location, which
# stays gated behind main-story progress via _luoyang_unlocked(). This test
# guards specifically against that gate ever creeping back onto the map
# (_show_map() must NOT call _luoyang_unlocked() to decide whether to list
# "luoyang" in its available places), while confirming the *other* locations
# correctly remain locked on a fresh save, and that _luoyang_unlocked()
# itself still gates the quest-journal chapter-text ladder as before (that
# meaning must not collapse into "always true" along with the map fix).

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	var game_state: Node = root.get_node("GameState")
	main_scene.get_window().size = Vector2i(1280, 720)
	game_state.new_game()
	main_scene.screen = "map"
	main_scene._rebuild()
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var output_path := "user://map_fresh_preview.png"
	var result := main_scene.get_viewport().get_texture().get_image().save_png(output_path)

	var labels: Array = main_scene.find_children("*", "Label", true, false)
	var shown := func(place_name: String) -> bool:
		return labels.any(func(l): return place_name in str((l as Label).text))
	var luoyang_shown: bool = shown.call("洛阳城")
	var huashan_shown: bool = shown.call("华山")
	var emei_shown: bool = shown.call("峨眉山")

	var luoyang_button: Array = main_scene.find_children("*", "Button", true, false).filter(func(b): return str((b as Button).tooltip_text) == "洛阳城")
	var travel_ok := false
	if luoyang_button.size() == 1:
		(luoyang_button[0] as Button).pressed.emit()
		for frame in range(2):
			await process_frame
		travel_ok = str(game_state.data.location) == "luoyang"

	# The quest journal's chapter-text ladder must still read this fresh save
	# as being in the Blackreed investigation, not skip ahead to "Luoyang
	# storyline" just because the map itself is now open early.
	main_scene.screen = "quests"
	main_scene._rebuild()
	for frame in range(2):
		await process_frame
	var quest_labels: Array = main_scene.find_children("*", "Label", true, false)
	var quest_text_correct := quest_labels.any(func(l): return "黑苇疑云" in str((l as Label).text))
	var quest_text_wrong := quest_labels.any(func(l): return "洛阳风云" in str((l as Label).text))

	var valid := result == OK and luoyang_shown and not huashan_shown and not emei_shown and luoyang_button.size() == 1 and travel_ok and quest_text_correct and not quest_text_wrong
	print("Map preview saved to: %s" % ProjectSettings.globalize_path(output_path))
	if not valid:
		push_error("Map unlock regression: luoyang_shown=%s huashan_shown(should be false)=%s emei_shown(should be false)=%s travel_ok=%s quest_text_correct=%s quest_text_wrong(should be false)=%s" % [luoyang_shown, huashan_shown, emei_shown, travel_ok, quest_text_correct, quest_text_wrong])
	quit(0 if valid else 22)
