extends SceneTree

const SHOP_RULES := preload("res://scripts/progression/shop_rules.gd")
const WUXUE_RULES := preload("res://scripts/progression/wuxue_rules.gd")

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

	# Learn both moves (auto-equipping to fill the two-slot cap) and both
	# internal arts / lightness skills in catalog order -- the second learn of
	# each single-slot category auto-replaces the first, leaving the first as
	# a learned-but-unequipped row so both new backpack sections render.
	WUXUE_RULES.learn_move(game_state.data, "stone_splitting_fist")
	WUXUE_RULES.learn_move(game_state.data, "night_triple_blade")
	WUXUE_RULES.learn_internal(game_state.data, "purple_mist_art")
	WUXUE_RULES.learn_internal(game_state.data, "five_elements_art")
	WUXUE_RULES.learn_lightness(game_state.data, "ripple_steps")
	WUXUE_RULES.learn_lightness(game_state.data, "wind_walk")

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

	# The last goods row (thunder stones, last in GOODS declaration order) is
	# the trailing content most likely to be clipped by a fixed-height panel.
	var labels: Array = main_scene.find_children("*", "Label", true, false)
	var last_good_title: String = str(SHOP_RULES.GOODS[SHOP_RULES.GOODS.keys().back()].title)
	var trailing_label: Label = null
	for label in labels:
		if last_good_title in str((label as Label).text):
			trailing_label = label
			break
	var trailing_label_found := trailing_label != null
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

	# Wuxue: both equipped moves, the active internal art/lightness skill, and
	# the bumped-out (learned-but-unequipped) internal art/lightness skill
	# should all render in their respective new sections.
	var stone_fist_shown := labels.any(func(l): return "【当前装备】" in str((l as Label).text) and "裂石拳" in str((l as Label).text))
	var night_blade_shown := labels.any(func(l): return "【当前装备】" in str((l as Label).text) and "暗夜三刀" in str((l as Label).text))
	var active_internal_shown := labels.any(func(l): return "【当前装备】" in str((l as Label).text) and "五行归元功" in str((l as Label).text))
	var bumped_internal_shown := labels.any(func(l): return "紫霞神功" in str((l as Label).text) and "【当前装备】" not in str((l as Label).text))
	var active_lightness_shown := labels.any(func(l): return "【当前装备】" in str((l as Label).text) and "神行百变" in str((l as Label).text))
	var bumped_lightness_shown := labels.any(func(l): return "凌波微步" in str((l as Label).text) and "【当前装备】" not in str((l as Label).text))

	# The bumped-out internal art must be directly re-equippable from the
	# backpack, exactly like owned-but-unequipped gear.
	var bumped_internal_label: Label = null
	for label in labels:
		if "紫霞神功" in str((label as Label).text) and "【当前装备】" not in str((label as Label).text):
			bumped_internal_label = label
			break
	var wuxue_equip_ok := false
	if bumped_internal_label != null:
		var row: Node = bumped_internal_label.get_parent().get_parent()
		var row_buttons: Array = row.find_children("*", "Button", true, false)
		if row_buttons.size() == 1:
			(row_buttons[0] as Button).pressed.emit()
			for frame in range(2):
				await process_frame
			wuxue_equip_ok = str(game_state.data.equipped_internal) == "purple_mist_art"

	# Owned-but-unequipped gear must be directly switchable from here, not
	# just viewable -- find the one "装备" button that isn't attached to the
	# already-equipped rows (they have none) and confirm pressing it actually
	# re-equips, without requiring a trip back to 西市.
	var equip_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text == "装备")
	var equip_button_count := equip_buttons.size()
	var equip_switch_ok := false
	if equip_button_count > 0:
		(equip_buttons[0] as Button).pressed.emit()
		for frame in range(2):
			await process_frame
		# One of the two catalogs' first still-owned, now-equipped id should
		# have changed away from weapon_ids[0]/armor_ids[0] -- whichever
		# button happened to be first in the tree (weapon or armor row).
		equip_switch_ok = str(game_state.data.equipped_weapon) != weapon_ids[0] or str(game_state.data.equipped_armor) != armor_ids[0]

	var valid := bare_ok and has_scroll and trailing_label_found and reachable
	valid = valid and equipped_weapon_shown and equipped_armor_shown and other_weapon_shown
	valid = valid and equip_button_count > 0 and equip_switch_ok
	valid = valid and stone_fist_shown and night_blade_shown and active_internal_shown and bumped_internal_shown and active_lightness_shown and bumped_lightness_shown and wuxue_equip_ok
	if not valid:
		push_error("Backpack screen regression: trailing_label_found=%s bare_ok=%s has_scroll=%s reachable=%s equipped_weapon_shown=%s equipped_armor_shown=%s other_weapon_shown=%s equip_button_count=%s equip_switch_ok=%s stone_fist_shown=%s night_blade_shown=%s active_internal_shown=%s bumped_internal_shown=%s active_lightness_shown=%s bumped_lightness_shown=%s wuxue_equip_ok=%s" % [trailing_label_found, bare_ok, has_scroll, reachable, equipped_weapon_shown, equipped_armor_shown, other_weapon_shown, equip_button_count, equip_switch_ok, stone_fist_shown, night_blade_shown, active_internal_shown, bumped_internal_shown, active_lightness_shown, bumped_lightness_shown, wuxue_equip_ok])
	quit(0 if valid else 20)
