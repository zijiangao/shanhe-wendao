extends SceneTree

const SHOP_RULES := preload("res://scripts/progression/shop_rules.gd")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.get_window().size = Vector2i(1280, 720)
	var game_state: Node = root.get_node("GameState")
	game_state.new_game()

	# Empty state: a fresh save should read as bare-handed/unarmored rather
	# than an empty or broken screen.
	main_scene.screen = "backpack"
	main_scene._rebuild()
	for frame in range(3):
		await process_frame
	var empty_labels: Array = main_scene.find_children("*", "Label", true, false)
	var bare_ok := empty_labels.any(func(l): return "赤手" in str((l as Label).text)) and empty_labels.any(func(l): return "无护具" in str((l as Label).text))

	# Own every weapon, every armor, and every good so the screen renders its
	# longest realistic content -- both to check the scroll reachability that
	# bit the character sheet before, and to exercise every code path
	# (equipped row, owned-but-unequipped row, goods row) at once.
	game_state.data.silver = 5000
	for id in SHOP_RULES.WEAPONS:
		SHOP_RULES.buy_weapon(game_state.data, id)
	for id in SHOP_RULES.ARMORS:
		SHOP_RULES.buy_armor(game_state.data, id)
	for id in SHOP_RULES.GOODS:
		SHOP_RULES.buy_good(game_state.data, id, 3)
	# Buying each weapon/armor in catalog order leaves the LAST one equipped;
	# equip the first one back so an "other weapons" row is guaranteed to
	# exist and be tested, not just the equipped-slot rows.
	var weapon_ids: Array = SHOP_RULES.WEAPONS.keys()
	SHOP_RULES.equip_weapon(game_state.data, weapon_ids[0])
	var armor_ids: Array = SHOP_RULES.ARMORS.keys()
	SHOP_RULES.equip_armor(game_state.data, armor_ids[0])

	main_scene._rebuild()
	for frame in range(3):
		await process_frame

	var scrolls: Array = main_scene.find_children("*", "ScrollContainer", true, false)
	var has_scroll := not scrolls.is_empty()
	var scroll: ScrollContainer = scrolls[0] if has_scroll else null
	if scroll != null:
		scroll.scroll_vertical = 9999
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw

	# The last goods row (thunder stones, last in GOODS declaration order) is
	# the trailing content most likely to be clipped by a fixed-height panel.
	var labels: Array = main_scene.find_children("*", "Label", true, false)
	var last_good_title: String = str(SHOP_RULES.GOODS[SHOP_RULES.GOODS.keys().back()].title)
	var trailing_label: Label = null
	for label in labels:
		if last_good_title in str((label as Label).text):
			trailing_label = label
			break
	var reachable := false
	if scroll != null and trailing_label != null:
		var visible_rect := scroll.get_global_rect()
		var label_rect := trailing_label.get_global_rect()
		reachable = visible_rect.intersects(Rect2(label_rect.position, Vector2(1, 1)))

	var equipped_weapon_title: String = str(SHOP_RULES.WEAPONS[weapon_ids[0]].title)
	var equipped_armor_title: String = str(SHOP_RULES.ARMORS[armor_ids[0]].title)
	var other_weapon_title: String = str(SHOP_RULES.WEAPONS[weapon_ids[1]].title)
	var equipped_weapon_shown := labels.any(func(l): return "【当前装备】" in str((l as Label).text) and equipped_weapon_title in str((l as Label).text))
	var equipped_armor_shown := labels.any(func(l): return "【当前装备】" in str((l as Label).text) and equipped_armor_title in str((l as Label).text))
	var other_weapon_shown := labels.any(func(l): return other_weapon_title in str((l as Label).text) and "【当前装备】" not in str((l as Label).text))

	var output_path := "user://backpack_preview.png"
	var result := main_scene.get_viewport().get_texture().get_image().save_png(output_path)
	var valid := result == OK and bare_ok and has_scroll and trailing_label != null and reachable
	valid = valid and equipped_weapon_shown and equipped_armor_shown and other_weapon_shown
	print("Backpack preview saved to: %s" % ProjectSettings.globalize_path(output_path))
	if not valid:
		push_error("Backpack screen regression: bare_ok=%s has_scroll=%s reachable=%s equipped_weapon_shown=%s equipped_armor_shown=%s other_weapon_shown=%s" % [bare_ok, has_scroll, reachable, equipped_weapon_shown, equipped_armor_shown, other_weapon_shown])
	quit(0 if valid else 20)
