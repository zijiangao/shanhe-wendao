extends SceneTree

const RULES := preload("res://scripts/progression/companion_rules.gd")

func _initialize() -> void:
	var state := _state()
	assert(not RULES.recruit(state, "zhou_mubai"), "50 silver should be unaffordable against 周慕白's 300-silver price.")
	assert(int(state.silver) == 50 and state.companions.is_empty(), "A failed recruit must not touch silver or the roster.")

	state.silver = 1000
	assert(RULES.recruit(state, "zhou_mubai"), "1000 silver should easily afford 周慕白.")
	assert(int(state.silver) == 700 and "zhou_mubai" in Array(state.companions) and str(state.active_disciple) == "zhou_mubai", "Recruiting should charge the price, join the roster, and become the active disciple immediately.")
	assert(not RULES.recruit(state, "zhou_mubai"), "Recruiting an already-joined disciple must be rejected, not double-charge.")

	assert(RULES.recruit(state, "liu_ruyan"), "A second disciple should be independently recruitable.")
	assert("zhou_mubai" in Array(state.companions) and "liu_ruyan" in Array(state.companions), "Both recruited disciples should stay on the roster -- recruiting a second must not evict the first.")
	assert(str(state.active_disciple) == "liu_ruyan", "The most recently recruited disciple should become the one who actually accompanies the hero.")

	assert(not RULES.recruit(state, "invalid_disciple"), "Recruiting an unknown disciple id must be rejected.")

	# options_inn() must reflect affordability and current roster state for the choice-menu UI.
	var poor := _state()
	var poor_options: Array = RULES.options_inn(poor)
	assert(poor_options.size() == RULES.DISCIPLES.size() + 1, "Every catalog entry plus one leave row should always be listed.")
	for option in poor_options.slice(0, poor_options.size() - 1):
		assert(bool(option[3]), "Every unrecruited disciple should be disabled when the hero has no silver.")
	var leave_row: Array = poor_options.back()
	assert(str(leave_row[2]) == "leave" and not (leave_row.size() > 3 and bool(leave_row[3])), "Leaving the tavern must always stay enabled.")

	var rich_options: Array = RULES.options_inn(state)
	var zhou_row := rich_options.filter(func(o): return str(o[2]) == "none" and str(o[0]).begins_with("已招募 · 周慕白"))
	assert(zhou_row.size() == 1 and "已加入门派" in str(zhou_row[0][0]), "A recruited-but-not-active disciple should show a read-only joined row.")
	var liu_row := rich_options.filter(func(o): return str(o[2]) == "none" and str(o[0]).begins_with("已招募 · 柳如烟"))
	assert(liu_row.size() == 1 and "当前随行" in str(liu_row[0][0]), "The active disciple's row should be marked as currently accompanying the hero.")

	# active_disciple_ally() feeds GameState.start_qingyun_spar_battle()'s
	# battle.ally construction -- same field shape as 林清霜's hardcoded dict.
	var empty_ally := RULES.active_disciple_ally(_state())
	assert(empty_ally.is_empty(), "A hero with no active disciple should get no spar ally at all.")
	var liu_ally := RULES.active_disciple_ally(state)
	assert(str(liu_ally.name) == "柳如烟" and int(liu_ally.hp) == int(liu_ally.max_hp) and int(liu_ally.hp) == int(RULES.DISCIPLES.liu_ruyan.hp), "The active disciple's ally dict should start at full hp matching the catalog.")

	print("Companion rules tests passed.")
	quit()

func _state() -> Dictionary:
	return {"silver": 50, "companions": [], "active_disciple": ""}
