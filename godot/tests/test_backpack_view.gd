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
	# than an empty or broken screen, AND (背包网格改版 0.120.0) the
	# 材料与药品 section must be entirely absent since every count is 0 --
	# this is the direct regression test for unifying "hide if empty" across
	# every section, not just the equipment ones.
	main_scene.screen = "backpack"
	main_scene._rebuild()
	for frame in range(3):
		await process_frame
	var bare_weapon_cell: Button = main_scene.find_child("backpack_cell_weapon_none", true, false)
	var bare_armor_cell: Button = main_scene.find_child("backpack_cell_armor_none", true, false)
	var bare_ok := bare_weapon_cell != null and "赤手" in str(bare_weapon_cell.text) and bare_armor_cell != null and "无护具" in str(bare_armor_cell.text)
	var goods_section_hidden := main_scene.find_children("backpack_cell_good_*", "Button", true, false).is_empty()
	var materials_title_hidden := not main_scene.find_children("*", "Label", true, false).any(func(l): return str((l as Label).text) == "材料与药品")

	# Own every weapon, every armor, and every good so the screen renders its
	# longest realistic content -- both to check the scroll reachability that
	# bit the character sheet before, and to exercise every code path
	# (equipped cell, owned-but-unequipped cell, goods cell) at once.
	game_state.data.silver = 5000
	for id in SHOP_RULES.WEAPONS:
		SHOP_RULES.buy_weapon(game_state.data, id)
	for id in SHOP_RULES.ARMORS:
		SHOP_RULES.buy_armor(game_state.data, id)
	for id in SHOP_RULES.GOODS:
		SHOP_RULES.buy_good(game_state.data, id, 3)
	# Buying each weapon/armor in catalog order leaves the LAST one equipped;
	# equip the first one back so an "other weapons" cell is guaranteed to
	# exist and be tested, not just the equipped-slot cells.
	var weapon_ids: Array = SHOP_RULES.WEAPONS.keys()
	SHOP_RULES.equip_weapon(game_state.data, weapon_ids[0])
	var armor_ids: Array = SHOP_RULES.ARMORS.keys()
	SHOP_RULES.equip_armor(game_state.data, armor_ids[0])

	# Learn both moves (usable immediately, no equip step -- 0.104.0) and both
	# internal arts / lightness skills in catalog order -- the second learn of
	# each single-slot category auto-replaces the first, leaving the first as
	# a learned-but-unequipped cell so both new backpack sections render.
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

	# The last goods cell (thunder stones, last in GOODS declaration order) is
	# the trailing content most likely to be clipped by a fixed-height panel.
	var trailing_cell: Button = main_scene.find_child("backpack_cell_good_%s" % SHOP_RULES.GOODS.keys().back(), true, false)
	var trailing_cell_found := trailing_cell != null
	var reachable := false
	if scroll != null and trailing_cell != null:
		var visible_rect := scroll.get_global_rect()
		var cell_rect := trailing_cell.get_global_rect()
		reachable = visible_rect.intersects(Rect2(cell_rect.position, Vector2(1, 1)))

	var equipped_weapon_cell := main_scene.find_child("backpack_cell_weapon_%s" % weapon_ids[0], true, false)
	var equipped_armor_cell := main_scene.find_child("backpack_cell_armor_%s" % armor_ids[0], true, false)
	var other_weapon_cell := main_scene.find_child("backpack_cell_weapon_%s" % weapon_ids[1], true, false)
	var equipped_weapon_shown := equipped_weapon_cell != null
	var equipped_armor_shown := equipped_armor_cell != null
	var other_weapon_shown := other_weapon_cell != null

	# Wuxue: both learned moves (always shown as usable, no equip step --
	# 0.104.0), the active internal art/lightness skill, and the bumped-out
	# (learned-but-unequipped) internal art/lightness skill should all render
	# as grid cells.
	var stone_fist_shown := main_scene.find_child("backpack_cell_move_stone_splitting_fist", true, false) != null
	var night_blade_shown := main_scene.find_child("backpack_cell_move_night_triple_blade", true, false) != null
	var active_internal_shown := main_scene.find_child("backpack_cell_internal_five_elements_art", true, false) != null
	var bumped_internal_cell: Button = main_scene.find_child("backpack_cell_internal_purple_mist_art", true, false)
	var bumped_internal_shown := bumped_internal_cell != null
	var active_lightness_shown := main_scene.find_child("backpack_cell_lightness_wind_walk", true, false) != null
	var bumped_lightness_shown := main_scene.find_child("backpack_cell_lightness_ripple_steps", true, false) != null

	# Clicking a cell selects it and rebuilds the detail panel with its full
	# (autowrap-capable) description -- this is where the 0.119.0 text-
	# clipping bug that prompted this redesign is actually fixed.
	var select_ok := false
	var detail_action_button: Button = null
	if bumped_internal_cell != null:
		bumped_internal_cell.pressed.emit()
		for frame in range(2):
			await process_frame
		var detail_labels: Array = main_scene.find_children("*", "Label", true, false)
		select_ok = detail_labels.any(func(l): return "紫霞神功" in str((l as Label).text))
		# The bumped-out internal art must be directly re-equippable from the
		# detail panel's single action button.
		var candidate_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b): return str((b as Button).text) == "装备")
		detail_action_button = candidate_buttons[0] if candidate_buttons.size() == 1 else null
	var wuxue_equip_ok := false
	if detail_action_button != null:
		detail_action_button.pressed.emit()
		for frame in range(2):
			await process_frame
		wuxue_equip_ok = str(game_state.data.equipped_internal) == "purple_mist_art"

	# Owned-but-unequipped gear must be directly switchable via the detail
	# panel too, not just viewable -- select the other-weapon cell and use
	# its action button. Re-query the cell fresh: the internal-art equip step
	# above triggered a full _show_backpack() rebuild, which tore down and
	# recreated every Control, so any earlier-captured node reference
	# (including other_weapon_cell) is now stale/freed.
	var equip_switch_ok := false
	var fresh_other_weapon_cell: Button = main_scene.find_child("backpack_cell_weapon_%s" % weapon_ids[1], true, false)
	if fresh_other_weapon_cell != null:
		fresh_other_weapon_cell.pressed.emit()
		for frame in range(2):
			await process_frame
		var switch_buttons: Array = main_scene.find_children("*", "Button", true, false).filter(func(b): return str((b as Button).text) == "装备")
		if switch_buttons.size() == 1:
			switch_buttons[0].pressed.emit()
			for frame in range(2):
				await process_frame
			equip_switch_ok = str(game_state.data.equipped_weapon) == weapon_ids[1]

	# A workshop-crafted weapon (an id never in SHOP_RULES.WEAPONS at all) must
	# show its bare item name here, not the workshop action-button label
	# ("打造 · 自铸铁刃") that CraftingRules.RECIPES.title is actually meant for.
	game_state.data.owned_weapons["forged_iron_blade"] = 1
	game_state.data.equipped_weapon = "forged_iron_blade"
	main_scene._rebuild()
	for frame in range(3):
		await process_frame
	var crafted_cell: Button = main_scene.find_child("backpack_cell_weapon_forged_iron_blade", true, false)
	var crafted_weapon_shown := crafted_cell != null and "自铸铁刃" in str(crafted_cell.text)
	var crafted_weapon_not_showing_verb := crafted_cell != null and "打造" not in str(crafted_cell.text)

	var valid := bare_ok and goods_section_hidden and materials_title_hidden
	valid = valid and has_scroll and trailing_cell_found and reachable
	valid = valid and equipped_weapon_shown and equipped_armor_shown and other_weapon_shown
	valid = valid and select_ok and equip_switch_ok
	valid = valid and stone_fist_shown and night_blade_shown and active_internal_shown and bumped_internal_shown and active_lightness_shown and bumped_lightness_shown and wuxue_equip_ok
	valid = valid and crafted_weapon_shown and crafted_weapon_not_showing_verb
	if not valid:
		push_error("Backpack screen regression: bare_ok=%s goods_section_hidden=%s materials_title_hidden=%s has_scroll=%s trailing_cell_found=%s reachable=%s equipped_weapon_shown=%s equipped_armor_shown=%s other_weapon_shown=%s select_ok=%s equip_switch_ok=%s stone_fist_shown=%s night_blade_shown=%s active_internal_shown=%s bumped_internal_shown=%s active_lightness_shown=%s bumped_lightness_shown=%s wuxue_equip_ok=%s crafted_weapon_shown=%s crafted_weapon_not_showing_verb=%s" % [bare_ok, goods_section_hidden, materials_title_hidden, has_scroll, trailing_cell_found, reachable, equipped_weapon_shown, equipped_armor_shown, other_weapon_shown, select_ok, equip_switch_ok, stone_fist_shown, night_blade_shown, active_internal_shown, bumped_internal_shown, active_lightness_shown, bumped_lightness_shown, wuxue_equip_ok, crafted_weapon_shown, crafted_weapon_not_showing_verb])
	quit(0 if valid else 20)
