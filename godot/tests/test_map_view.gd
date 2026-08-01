extends SceneTree

# Every location -- including Huashan and Emei, previously gated behind
# main-story progress via _huashan_unlocked()/_emei_unlocked() -- is meant to
# be reachable from the very start of a playthrough. This test guards
# specifically against those gates ever creeping back onto the map
# (_show_map() must NOT call _huashan_unlocked()/_emei_unlocked() to decide
# whether to list "huashan"/"emei" in its available places), while confirming
# _huashan_unlocked()/_emei_unlocked() (and _luoyang_unlocked()) still gate the
# quest-journal chapter-text ladder as before (that meaning must not collapse
# into "always true" along with the map fix).

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

	var labels: Array = main_scene.find_children("*", "Label", true, false)
	var shown := func(place_name: String) -> bool:
		return labels.any(func(l): return place_name in str((l as Label).text))
	var luoyang_shown: bool = shown.call("洛阳城")
	var huashan_shown: bool = shown.call("华山")
	var emei_shown: bool = shown.call("峨眉山")

	# The map's side panel (title, 主线/本周/气血 status text, and the
	# 进入/调息/江湖纪事 buttons) was removed entirely (0.100.0) -- the map
	# now only shows the art and its clickable location markers.
	var no_current_location_title: bool = not shown.call("当前所在 ·")
	var no_objective_text: bool = not shown.call("主线：") and not shown.call("气血：")
	# 调息 moved to the persistent header nav bar (visible on every screen,
	# not just the map), so it's deliberately excluded from this check.
	var no_side_buttons: bool = not main_scene.find_children("*", "Button", true, false).any(func(b): return (b as Button).text.begins_with("进入") or (b as Button).text.ends_with("江湖纪事"))

	var buttons: Array = main_scene.find_children("*", "Button", true, false)
	var huashan_button_ok: bool = buttons.any(func(b): return str((b as Button).tooltip_text) == "华山")
	var emei_button_ok: bool = buttons.any(func(b): return str((b as Button).tooltip_text) == "峨眉山")

	# Clicking the current-location marker itself now enters that location
	# directly (destination_requested with the hero's own current location,
	# which _map_destination_requested() already treats as "enter").
	var current_marker: Array = buttons.filter(func(b): return str((b as Button).tooltip_text) == "青云门")
	var enter_via_marker_ok := false
	if current_marker.size() == 1:
		(current_marker[0] as Button).pressed.emit()
		for frame in range(2):
			await process_frame
		enter_via_marker_ok = main_scene.screen == "location"
		main_scene.screen = "map"
		main_scene._rebuild()
		for frame in range(2):
			await process_frame

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

	# 江湖纪事 (0.100.0) moved from the map's side panel into the quest
	# journal screen, still collapsed by default.
	var chronicle_toggle: Button = null
	for b in main_scene.find_children("*", "Button", true, false):
		if (b as Button).text.ends_with("江湖纪事"):
			chronicle_toggle = b
	var chronicle_label: Label = null
	for l in quest_labels:
		if str((l as Label).text).begins_with("· "):
			chronicle_label = l
	var chronicle_starts_collapsed := chronicle_toggle != null and chronicle_toggle.text.begins_with("▸") and chronicle_label != null and not chronicle_label.visible
	var chronicle_expands := false
	if chronicle_toggle != null:
		chronicle_toggle.pressed.emit()
		for frame in range(2):
			await process_frame
		chronicle_expands = chronicle_toggle.text.begins_with("▾") and chronicle_label.visible

	# 调息 (0.100.0) moved to a persistent header button next to 结束本周,
	# usable from any screen -- confirm it works and syncs its disabled
	# state with acted_this_week just like 结束本周 already does.
	game_state.new_game()
	main_scene.screen = "map"
	main_scene._rebuild()
	for frame in range(2):
		await process_frame
	var rest_before_ok: bool = main_scene.rest_button != null and not main_scene.rest_button.disabled
	var hp_before := int(game_state.data.hp)
	game_state.data.hp = hp_before - 10
	main_scene.rest_button.pressed.emit()
	for frame in range(2):
		await process_frame
	var rest_worked: bool = int(game_state.data.hp) == int(game_state.data.max_hp) and bool(game_state.data.acted_this_week)
	var rest_disabled_after: bool = main_scene.rest_button.disabled

	var valid := luoyang_shown and huashan_shown and emei_shown and huashan_button_ok and emei_button_ok and luoyang_button.size() == 1 and travel_ok and quest_text_correct and not quest_text_wrong
	valid = valid and no_current_location_title and no_objective_text and no_side_buttons and enter_via_marker_ok and chronicle_starts_collapsed and chronicle_expands
	valid = valid and rest_before_ok and rest_worked and rest_disabled_after
	if not valid:
		push_error("Map unlock regression: luoyang_shown=%s huashan_shown=%s emei_shown=%s huashan_button_ok=%s emei_button_ok=%s travel_ok=%s quest_text_correct=%s quest_text_wrong(should be false)=%s no_current_location_title=%s no_objective_text=%s no_side_buttons=%s enter_via_marker_ok=%s chronicle_starts_collapsed=%s chronicle_expands=%s rest_before_ok=%s rest_worked=%s rest_disabled_after=%s" % [luoyang_shown, huashan_shown, emei_shown, huashan_button_ok, emei_button_ok, travel_ok, quest_text_correct, quest_text_wrong, no_current_location_title, no_objective_text, no_side_buttons, enter_via_marker_ok, chronicle_starts_collapsed, chronicle_expands, rest_before_ok, rest_worked, rest_disabled_after])
	quit(0 if valid else 22)
