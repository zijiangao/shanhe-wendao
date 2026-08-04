extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	main_scene.screen = "character"
	main_scene._rebuild()
	for frame in range(4):
		await process_frame

	var scrolls: Array = main_scene.find_children("*", "ScrollContainer", true, false)
	var has_scroll := not scrolls.is_empty()
	var scroll: ScrollContainer = scrolls[0] if has_scroll else null
	if scroll != null:
		scroll.scroll_vertical = 9999
	for frame in range(3):
		await process_frame

	# The trailing mastery label is the content that was silently clipped
	# outside the 1280x720 viewport before the info panel became scrollable.
	# Require it to actually be within the scroll container's visible rect,
	# not merely present somewhere in the node tree.
	var labels: Array = main_scene.find_children("*", "Label", true, false)
	var mastery_label: Label = null
	for label in labels:
		if "每使用3次" in str((label as Label).text):
			mastery_label = label
			break
	var mastery_label_found := mastery_label != null
	var reachable := false
	if scroll != null and mastery_label != null:
		var visible_rect := scroll.get_global_rect()
		var label_rect := mastery_label.get_global_rect()
		reachable = visible_rect.intersects(Rect2(label_rect.position, Vector2(1, 1)))

	# 行囊 (0.108.0 removed) duplicated 背包 -- equipped gear/materials/items
	# must no longer appear here at all, only on the dedicated backpack
	# screen. 修炼战绩/实战切磋 (0.108.0 removed) likewise must be gone from
	# 江湖技艺.
	var no_inventory_shown := not labels.any(func(l): return "行 囊" in str((l as Label).text) or "已装备：" in str((l as Label).text) or "剧情物品" in str((l as Label).text))
	var no_records_shown := not labels.any(func(l): return "修炼战绩" in str((l as Label).text) or "实战切磋" in str((l as Label).text))
	# 淬炼/forge_level was removed entirely (0.94.0) -- it must never
	# reappear anywhere on the character sheet.
	var no_tempering_shown := not labels.any(func(l): return "淬炼" in str((l as Label).text))

	var valid := has_scroll and mastery_label_found and reachable
	valid = valid and no_inventory_shown and no_records_shown and no_tempering_shown

	# 人物界面左右分栏浏览器 (0.111.0): a solo hero should show exactly one
	# roster button ("沈羽"), no companions to browse yet.
	var solo_roster_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return (b as Button).text in ["沈羽", "林清霜", "周慕白", "柳如烟"])
	var solo_roster_ok := solo_roster_buttons.size() == 1 and (solo_roster_buttons[0] as Button).text == "沈羽"

	var game_state: Node = root.get_node("GameState")
	game_state.data.silver = 1000
	game_state.data.companions.append("lin_qingshuang")
	var companion_rules = load("res://scripts/progression/companion_rules.gd")
	companion_rules.recruit(game_state.data, "zhou_mubai")
	main_scene._rebuild()
	for frame in range(3):
		await process_frame
	var full_roster_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b: Button): return (b as Button).text in ["沈羽", "林清霜", "周慕白"])
	var full_roster_ok := full_roster_buttons.size() == 3

	var zhou_button: Button = null
	for b in full_roster_buttons:
		if (b as Button).text == "周慕白":
			zhou_button = b
	var switch_ok := false
	if zhou_button != null:
		zhou_button.pressed.emit()
		for frame in range(3):
			await process_frame
		labels = main_scene.find_children("*", "Label", true, false)
		# The same panel shape as 沈羽's own (基础属性/武学/装备), but reading
		# 周慕白's fixed catalog stats instead of live save data.
		switch_ok = main_scene.character_roster_selection == "zhou_mubai" and labels.any(func(l): return "周慕白 · 概览" in str((l as Label).text)) and labels.any(func(l): return "霜华刺" in str((l as Label).text)) and labels.any(func(l): return "随身青锋" in str((l as Label).text))

	valid = valid and solo_roster_ok and full_roster_ok and switch_ok

	if not valid:
		push_error("Character screen regression: has_scroll=%s mastery_label_found=%s reachable=%s no_inventory_shown=%s no_records_shown=%s no_tempering_shown=%s solo_roster_ok=%s full_roster_ok=%s switch_ok=%s" % [has_scroll, mastery_label_found, reachable, no_inventory_shown, no_records_shown, no_tempering_shown, solo_roster_ok, full_roster_ok, switch_ok])
	quit(0 if valid else 11)
