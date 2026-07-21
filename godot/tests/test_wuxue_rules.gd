extends SceneTree

const RULES := preload("res://scripts/progression/wuxue_rules.gd")

func _initialize() -> void:
	var state := _state()
	assert(int(RULES.internal_damage_bonus(state)) == 0 and int(RULES.internal_healing_bonus(state)) == 0 and int(RULES.lightness_move_bonus(state)) == 0, "An untrained hero should have zero wuxue bonuses.")

	assert(not RULES.learn_move(state, "stone_splitting_fist"), "150 silver should be unaffordable with only 100.")
	assert(int(state.silver) == 100 and state.learned_moves.is_empty(), "A failed manual purchase must not touch silver or the learned list.")

	state.silver = 1000
	assert(RULES.learn_move(state, "stone_splitting_fist"), "1000 silver should easily afford the cheaper move.")
	assert(int(state.silver) == 850 and "stone_splitting_fist" in Array(state.learned_moves) and "stone_splitting_fist" in Array(state.equipped_moves), "Learning a move with a free slot should charge its price and auto-equip it.")
	assert(not RULES.learn_move(state, "stone_splitting_fist"), "Learning an already-known move must be rejected, not double-charge.")

	assert(RULES.learn_move(state, "night_triple_blade"), "The second move should also be affordable and learnable.")
	assert(Array(state.equipped_moves).size() == RULES.MAX_EQUIPPED_MOVES, "Both moves should now be auto-equipped, filling the two-slot cap.")

	assert(RULES.unequip_move(state, "stone_splitting_fist"), "Unequipping a currently-equipped move should succeed.")
	assert(not ("stone_splitting_fist" in Array(state.equipped_moves)) and "stone_splitting_fist" in Array(state.learned_moves), "Unequipping must leave the move learned but no longer active.")
	assert(not RULES.unequip_move(state, "stone_splitting_fist"), "Unequipping a move that is already unequipped must fail.")
	assert(RULES.equip_move(state, "stone_splitting_fist"), "Re-equipping a learned move with a free slot should succeed.")
	assert(not RULES.equip_move(state, "stone_splitting_fist"), "Equipping an already-equipped move must fail.")
	assert(not RULES.equip_move(state, "wind_walk"), "Equipping a move id that belongs to a different category (lightness) must fail.")

	# Internal arts: learning auto-replaces, exactly like weapons/armor in ShopRules.
	var internal_state := _state()
	internal_state.silver = 1000
	assert(not RULES.equip_internal(internal_state, "purple_mist_art"), "Equipping an internal art that has not been learned must fail.")
	assert(RULES.learn_internal(internal_state, "purple_mist_art"), "Purple Mist Art should be learnable when affordable.")
	assert(int(RULES.internal_damage_bonus(internal_state)) == 2, "The equipped internal art should grant its damage bonus.")
	assert(str(internal_state.equipped_internal) == "purple_mist_art", "Learning an internal art should auto-equip it immediately.")
	assert(RULES.learn_internal(internal_state, "five_elements_art"), "A second internal art should be independently learnable.")
	assert(str(internal_state.equipped_internal) == "five_elements_art", "Learning a new internal art should replace the previously equipped one.")
	assert(int(RULES.internal_damage_bonus(internal_state)) == 0 and int(RULES.internal_healing_bonus(internal_state)) == 5, "Switching internal arts should switch which bonus applies.")
	assert(RULES.equip_internal(internal_state, "purple_mist_art"), "Re-equipping a previously learned internal art should succeed.")
	assert(int(RULES.internal_damage_bonus(internal_state)) == 2, "Re-equipping should restore that art's bonus.")
	assert(RULES.unequip_internal(internal_state, "purple_mist_art"), "Unequipping the active internal art should succeed.")
	assert(str(internal_state.equipped_internal) == "" and int(RULES.internal_damage_bonus(internal_state)) == 0, "Unequipping should zero out the bonus and clear the active slot.")
	assert(not RULES.unequip_internal(internal_state, "five_elements_art"), "Unequipping an art that is not currently active must fail.")

	# Lightness mirrors internal arts exactly.
	var lightness_state := _state()
	lightness_state.silver = 1000
	assert(RULES.learn_lightness(lightness_state, "ripple_steps"), "Ripple Steps should be learnable when affordable.")
	assert(int(RULES.lightness_move_bonus(lightness_state)) == 1, "The equipped lightness skill should grant its move bonus.")
	assert(RULES.learn_lightness(lightness_state, "wind_walk"), "A second lightness skill should be independently learnable.")
	assert(int(RULES.lightness_move_bonus(lightness_state)) == 2, "Learning a stronger lightness skill should replace the equipped one.")
	assert(RULES.equip_lightness(lightness_state, "ripple_steps"), "Switching back to a previously learned lightness skill should succeed.")
	assert(int(RULES.lightness_move_bonus(lightness_state)) == 1, "Switching lightness skills should switch the active bonus.")
	assert(not RULES.equip_lightness(lightness_state, "unknown_id"), "Equipping an unrecognized lightness id must fail.")

	# options_manuals must reflect affordability and current learn/equip state for the choice-menu UI.
	var poor := _state()
	var poor_options: Array = RULES.options_manuals(poor)
	assert(poor_options.size() == RULES.MOVES.size() + RULES.INTERNAL.size() + RULES.LIGHTNESS.size() + 1, "Every catalog entry plus one leave row should always be listed.")
	for option in poor_options.slice(0, poor_options.size() - 1):
		assert(bool(option[3]), "Every unlearned entry should be disabled when the hero has no silver.")
	var leave_row: Array = poor_options.back()
	assert(str(leave_row[2]) == "leave" and not (leave_row.size() > 3 and bool(leave_row[3])), "Leaving the manuals shop must always stay enabled.")

	var rich := _state()
	rich.silver = 1000
	RULES.learn_move(rich, "stone_splitting_fist")
	var rich_options: Array = RULES.options_manuals(rich)
	var equipped_row := rich_options.filter(func(o): return str(o[2]) == "unequip_move_stone_splitting_fist")
	assert(equipped_row.size() == 1, "A learned-and-auto-equipped move should offer an unequip action, not a learn action.")

	print("Wuxue rules tests passed.")
	quit()

func _state() -> Dictionary:
	return {
		"silver": 100,
		"learned_moves": [], "equipped_moves": [],
		"learned_internal": [], "equipped_internal": "",
		"learned_lightness": [], "equipped_lightness": "",
	}
