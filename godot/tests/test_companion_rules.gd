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

	# 人物界面左右分栏浏览器 (0.111.0) -- roster()/companion_entry()/
	# is_valid_companion() feed that screen's left-column roster and each
	# selected companion's static display panel.
	var empty_roster: Array = RULES.roster(_state())
	assert(empty_roster.is_empty(), "A hero with no companions joined should have an empty roster.")
	assert(RULES.is_valid_companion("lin_qingshuang") and RULES.is_valid_companion("zhou_mubai") and not RULES.is_valid_companion("nobody"), "is_valid_companion() should recognize both the story companion and recruitable disciples.")
	var full_roster := _state()
	full_roster.silver = 1000
	full_roster.companions = ["lin_qingshuang"]
	RULES.recruit(full_roster, "zhou_mubai")
	RULES.recruit(full_roster, "liu_ruyan")
	var roster_ids: Array = RULES.roster(full_roster)
	assert(roster_ids == ["lin_qingshuang", "zhou_mubai", "liu_ruyan"], "roster() should list 林清霜 first (if joined), then every recruited disciple in join order -- not just the currently active one.")
	var lin_entry: Dictionary = RULES.companion_entry("lin_qingshuang")
	assert(str(lin_entry.title) == "林清霜" and int(lin_entry.strength) > 0, "companion_entry() should resolve the story companion's display stats from STORY_COMPANIONS.")
	var zhou_entry: Dictionary = RULES.companion_entry("zhou_mubai")
	assert(str(zhou_entry.title) == "周慕白" and int(zhou_entry.strength) > 0, "companion_entry() should resolve a recruited disciple's display stats from DISCIPLES.")
	assert(RULES.companion_entry("nobody").is_empty(), "An unknown id should resolve to an empty entry rather than crash.")

	# 同伴换装备/换武学 (0.113.0) -- companions share the hero's own
	# owned_weapons/owned_armors pool; equipping requires the hero to
	# actually own the item, mirroring 秘籍阁/西市's own ownership checks.
	var gear_state := _state()
	gear_state.companions = ["zhou_mubai"]
	gear_state.active_disciple = "zhou_mubai"
	gear_state.owned_weapons = ["cold_crow_blade"]
	gear_state.owned_armors = ["cold_jade_armor"]
	gear_state.learned_moves = ["cloud_sword"]
	assert(not RULES.equip_companion_weapon(gear_state, "zhou_mubai", "dragon_etched_sword"), "Equipping a weapon the hero doesn't own must be rejected.")
	assert(RULES.equip_companion_weapon(gear_state, "zhou_mubai", "cold_crow_blade"), "Equipping a weapon the hero owns should succeed.")
	assert(RULES.companion_weapon(gear_state, "zhou_mubai") == "cold_crow_blade", "companion_weapon() should report the just-equipped weapon.")
	assert(RULES.equip_companion_armor(gear_state, "zhou_mubai", "cold_jade_armor"), "Equipping an owned armor should succeed.")
	assert(RULES.equip_companion_move(gear_state, "zhou_mubai", "cloud_sword"), "Equipping a move the hero has learned should succeed.")
	assert(not RULES.equip_companion_move(gear_state, "zhou_mubai", "blade_technique"), "Equipping a move the hero has NOT learned must be rejected.")
	assert(RULES.equip_companion_weapon(gear_state, "zhou_mubai", ""), "Unequipping (empty id) should always succeed regardless of ownership.")
	assert(RULES.companion_weapon(gear_state, "zhou_mubai") == "", "After unequipping, companion_weapon() should report empty.")
	# The same weapon can accompany multiple people at once (a shared pool,
	# not exclusive ownership) -- 林清霜 equipping it must not disturb 周慕白.
	assert(RULES.equip_companion_weapon(gear_state, "lin_qingshuang", "cold_crow_blade"), "A second companion should be able to equip the same shared weapon.")

	var equipped_ally := RULES.active_disciple_ally(gear_state)
	assert(int(equipped_ally.attack) == int(RULES.DISCIPLES.zhou_mubai.attack) and int(equipped_ally.armor) == 3, "active_disciple_ally() should fold in the armor bonus but not a weapon that was unequipped again.")
	assert(str(equipped_ally.move_id) == "cloud_sword", "active_disciple_ally() should surface the companion's chosen move id for battle_engine.gd to read.")

	# options_companion_weapons()/armors()/moves() must reflect current
	# ownership + equip state for the roster-panel UI.
	var weapon_options: Array = RULES.options_companion_weapons(gear_state, "zhou_mubai")
	var bare_hand_row := weapon_options.filter(func(o): return str(o[0]).begins_with("赤手"))
	assert(bare_hand_row.size() == 1 and bool(bare_hand_row[0][3]), "赤手 should be the currently-equipped (disabled) row after unequipping.")
	var move_options: Array = RULES.options_companion_moves(gear_state, "zhou_mubai")
	var cloud_row := move_options.filter(func(o): return str(o[0]).begins_with("流云剑法"))
	assert(cloud_row.size() == 1 and bool(cloud_row[0][3]), "The equipped move's row should show as currently selected (disabled).")

	print("Companion rules tests passed.")
	quit()

func _state() -> Dictionary:
	return {"silver": 50, "companions": [], "active_disciple": ""}
