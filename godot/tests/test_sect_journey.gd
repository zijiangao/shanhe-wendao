extends "res://tests/test_prepared_journey.gd"

# Real progression only: construction materials and money come from the market,
# gathering, and weekly work. Scores model scripted training outcomes, not human
# timing. Run in a copied project with a separate APPDATA directory.
const SECT := preload("res://scripts/progression/sect_building_rules.gd")
const CRAFT := preload("res://scripts/progression/crafting_rules.gd")
const TRAINING := preload("res://scripts/progression/training_minigame_rules.gd")
var plan := ""
var audit: Array = []
var summaries: Array = []
var checks := 0
var failures: Array = []
var deadline_checkpoint: Dictionary = {}
var upgrade_spend := {"silver": 0, "herbs": 0, "ore": 0}
var garden_harvest := 0
var earning_weeks := 0
var purchase_spend := 0
var manual_savings := 0
var ore_savings := 0

func _run() -> void:
	if str(ProjectSettings.get_setting("application/config/name")) != "ShanheWendao-iteration-tests":
		push_error("Use an isolated acceptance project.")
		quit(2)
		return
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	state = root.get_node("GameState")
	await process_frame
	main.enemy_turn_active = true
	profile = "balanced"
	for construction in ["none", "all_three_levels"]:
		plan = construction
		current_run = "standard_" + plan + "_0"
		root.get_node("SettingsManager").data.difficulty = "standard"
		rng.seed = 0
		seed(0)
		state.new_game()
		main.screen = "location"
		upgrade_spend = {"silver": 0, "herbs": 0, "ore": 0}
		garden_harvest = 0
		earning_weeks = 0
		purchase_spend = 0
		manual_savings = 0
		ore_savings = 0
		_rejected_upgrade("training_ground", "new_game_chapter_lock")
		_rejected_upgrade("unknown_building", "unknown_building")
		var completed := await _sect_journey()
		summaries.append({"run": current_run, "completed": completed, "week": state.data.week, "silver": state.data.silver, "xp": state.data.xp, "materials": state.data.materials.duplicate(true), "buildings": state.data.sect.buildings.duplicate(true), "upgrade_spend": upgrade_spend.duplicate(true), "purchase_spend": purchase_spend, "manual_savings": manual_savings, "ore_savings": ore_savings, "garden_harvest": garden_harvest, "earning_weeks": earning_weeks, "ending": state.data.ending.id if completed else ""})
		_write_results()
		_check(completed, "Standard journey must reach all final choices: " + plan)
		await process_frame
	await _deadline_probe()
	_write_results()
	print("SECT_JOURNEY_RESULTS ", JSON.stringify(summaries))
	print("Sect journey integration passed: %d checks, %d failures." % [checks, failures.size()])
	quit(0)

func _sect_journey() -> bool:
	action("master")
	_initial_market()
	travel("blackreed")
	action("fisher")
	action("tracks")
	action("fight")
	if not await battle(): return false
	main._claim_battle_reward("temper")
	travel("qingyun")
	action("master")
	_check(str(state.data.quest_stage) == "chapter_complete", "First tier must be unlocked by the actual chapter completion.")
	_finish_week()
	if plan != "none":
		_rejected_upgrade("library", "unaffordable_materials")
	# Exercise both real gathering specialties before buying any shortfall.
	await _training_week("herbalism", "initial_herb_supply")
	await _training_week("mining", "initial_ore_supply")
	await _tier(1)
	await _effect_weeks(1)
	travel("luoyang")
	action("temple")
	main._resolve_choice("heroism")
	action("palace")
	main._palace_event("witness")
	dialogue()
	main._palace_event("ledger")
	dialogue()
	main._confront_li_wujiu()
	dialogue()
	main._resolve_choice("public")
	_check(str(state.data.quest_stage) == "chapter2_complete", "Second-tier unlock must follow the actual palace resolution.")
	travel("qingyun")
	await _tier(2)
	await _effect_weeks(2)
	await _weekly_training(4)
	travel("huashan")
	action("huashan_gate")
	action("meet_lin")
	action("huashan_trial")
	if not await battle(): return false
	main._claim_battle_reward("temper")
	main.screen = "location"
	action("huashan_cliff")
	travel("emei")
	action("emei_gate")
	main._resolve_choice("recommend")
	action("meet_su")
	action("elephant_pool")
	action("emei_peak")
	_finish_week()
	travel("qingyun")
	await _tier(3)
	await _effect_weeks(3)
	await _weekly_training(6)
	if plan != "none":
		_rejected_upgrade("forge", "maximum_level")
	await _ensure_supply({"silver": 60})
	travel("luoyang")
	_buy_good("healing_powder", 4)
	travel("emei")
	action("emei_peak")
	if not await battle(): return false
	main._claim_battle_reward("temper")
	var before: Dictionary = state.data.duplicate(true)
	for ending in ["destroy", "seal", "preserve"]:
		_check(state.import_data(before), "Reload real final-choice checkpoint.")
		main.screen = main._screen_after_load()
		_check(main.screen == "final_choice", "Reload must restore final choice.")
		main._show_final_choice()
		main._resolve_choice(ending)
		_check(str(state.data.ending.id) == ending and main.screen == "ending", "Final choice must produce " + ending)
		_check(root.get_node("SaveManager").save_slot(1), "Save actual ending.")
		_check(root.get_node("SaveManager").load_slot(1), "Load actual ending.")
		_check(equivalent(before.sect, state.data.sect), "Construction must survive the final choice and ending save/load.")
		_check(main._screen_after_load() == "ending", "Ending screen must restore.")
	return true

func _initial_market() -> void:
	travel("luoyang")
	_market_choice("weapons", "buy_cold_crow_blade")
	_market_choice("armor", "buy_dark_iron_armor")
	_market_choice("manuals", "learn_move_cloud_sword")
	_market_choice("manuals", "learn_move_stone_splitting_fist")
	_market_choice("manuals", "learn_internal_purple_mist_art")
	_buy_good("healing_powder", 8)

func _market_choice(category: String, route: String) -> void:
	var before := int(state.data.silver)
	main.screen = "location"
	action("market")
	main._resolve_choice(category)
	_choice(route)
	purchase_spend += before - int(state.data.silver)
	main.screen = "location"

func _buy_good(id: String, quantity: int) -> void:
	if quantity <= 0: return
	var before := int(state.data.silver)
	main.screen = "location"
	action("market")
	main._resolve_choice("goods")
	_check(SHOP.buy_good(state.data, id, quantity), "Purchase actual market goods: %s x%d" % [id, quantity])
	_check(root.get_node("SaveManager").save_auto(), "Save market batch purchase.")
	purchase_spend += before - int(state.data.silver)
	audit.append({"run": current_run, "event": "market_goods", "week": state.data.week, "id": id, "quantity": quantity, "silver_spent": before - int(state.data.silver)})
	main.screen = "location"

func _choice(route: String) -> void:
	var available := false
	for row in main.choice_options:
		if str(row[2]) == route and (row.size() < 4 or not bool(row[3])):
			available = true
	_check(available, "Production choice must be available: " + route)
	main._resolve_choice(route)

func _tier(tier: int) -> void:
	if plan == "none": return
	travel("qingyun")
	var needed := {"silver": 0, "herbs": 0, "ore": 0}
	for id in SECT.BUILDING_IDS:
		var cost: Dictionary = SECT.BUILDINGS[id].costs[tier]
		for resource in ["silver", "herbs", "ore"]:
			needed[resource] += int(cost[resource])
	await _ensure_supply(needed)
	if tier == 3:
		deadline_checkpoint = state.data.duplicate(true)
	# Wrong location and chapter locks are tested with enough real resources.
	travel("luoyang")
	_rejected_upgrade("training_ground", "wrong_location")
	travel("qingyun")
	for id in SECT.BUILDING_IDS:
		var before: Dictionary = state.data.duplicate(true)
		action("sect_building")
		_choice("upgrade_" + id)
		var cost: Dictionary = SECT.BUILDINGS[id].costs[tier]
		_check(int(state.data.sect.buildings[id]) == tier, "Actual building upgrade must reach requested tier.")
		_check(bool(state.data.acted_this_week) and int(state.data.week) == int(before.week), "Construction must spend exactly this week's action.")
		_check(int(before.silver) - int(state.data.silver) == int(cost.silver), "Construction silver deduction.")
		for resource in ["herbs", "ore"]:
			_check(int(before.materials[resource]) - int(state.data.materials[resource]) == int(cost[resource]), "Construction material deduction: " + resource)
		for resource in ["silver", "herbs", "ore"]:
			upgrade_spend[resource] += int(cost[resource])
		_rejected_upgrade(id, "second_action_same_week")
		var checkpoint: Dictionary = state.data.duplicate(true)
		_check(root.get_node("SaveManager").load_auto(), "Load construction autosave written by the production UI.")
		_check(equivalent(checkpoint, state.data), "Autosave must preserve construction, resources, and consumed action.")
		_check(root.get_node("SaveManager").save_slot(3) and root.get_node("SaveManager").load_slot(3), "Construction manual-save round trip.")
		_check(equivalent(checkpoint, state.data), "Manual save must preserve complete construction state.")
		audit.append({"run": current_run, "event": "upgrade", "id": id, "level": tier, "week": state.data.week, "cost": cost.duplicate(true)})
		main._resolve_choice("leave")
		_finish_week()
		await process_frame
	if tier < 3:
		var next: Dictionary = SECT.BUILDINGS.training_ground.costs[tier + 1]
		await _ensure_supply(next)
		_rejected_upgrade("training_ground", "next_chapter_lock")
	_write_results()

func _ensure_supply(needed: Dictionary) -> void:
	var herbs_needed := maxi(0, int(needed.get("herbs", 0)) - int(state.data.materials.herbs))
	var ore_needed := maxi(0, int(needed.get("ore", 0)) - int(state.data.materials.ore))
	var total := int(needed.get("silver", 0)) + herbs_needed * 5 + ore_needed * 6
	while int(state.data.silver) < total:
		_check(int(state.data.week) < 100, "Legitimate earning must finance this plan before the deadline.")
		await _task_week("earn")
		earning_weeks += 1
	travel("luoyang")
	_buy_good("herbs", herbs_needed)
	_buy_good("ore", ore_needed)
	travel("qingyun")

func _effect_weeks(tier: int) -> void:
	travel("qingyun")
	await _training_week("swordsmanship", "training_ground_effect")
	var wuxue_before := _total_move_xp("cloud_sword")
	var bonus := tier * 2 if plan != "none" else 0
	var insight_bonus := int(state.data.insight) / 2
	seed(100 + tier)
	var rolled := randi_range(WUXUE.TRAIN_XP_MIN, WUXUE.TRAIN_XP_MAX)
	seed(100 + tier)
	action("train")
	_choice("wuxue_training")
	_choice("train_move_cloud_sword")
	var gained := _total_move_xp("cloud_sword") - wuxue_before
	_check(gained == rolled + insight_bonus + bonus, "Real martial practice must include the training-ground bonus.")
	audit.append({"run": current_run, "event": "wuxue_training", "tier": tier, "week": state.data.week, "xp_gain": gained, "random_base": rolled, "insight_bonus": insight_bonus, "sect_bonus": bonus})
	main.screen = "location"
	_finish_week()
	await process_frame
	await _task_week("train")
	# One repeatable equipment recipe isolates all three forge tiers without
	# injecting rare specimens or replacing market gear used in the story.
	var forge_level := tier if plan != "none" else 0
	var expected_ore := maxi(0, 5 - TRAINING.craft_ore_discount(int(state.data.mining)) - forge_level)
	await _ensure_supply({"ore": expected_ore})
	var ore_before := int(state.data.materials.ore)
	var owned_before := int(state.data.owned_weapons.get("forged_iron_blade", 0))
	action("forge")
	var forge_label := ""
	for row in main.choice_options:
		if str(row[2]) == "forged_iron_blade": forge_label = str(row[0])
	if forge_level > 0:
		_check(forge_label.contains("门派建设减免%d" % forge_level), "Forge choice must attribute the real sect discount to construction.")
		_check(not forge_label.contains("挖矿专精"), "This real novice miner must not be credited with a mastery discount.")
	_choice("forged_iron_blade")
	_check(ore_before - int(state.data.materials.ore) == expected_ore, "Forge must consume the displayed discounted ore cost.")
	_check(int(state.data.owned_weapons.forged_iron_blade) == owned_before + 1, "Forging must add actual equipment.")
	ore_savings += forge_level
	audit.append({"run": current_run, "event": "forge_effect", "tier": tier, "week": state.data.week, "ore_spent": expected_ore, "sect_ore_saved": forge_level, "choice_label": forge_label})
	_check(SHOP.equip_weapon(state.data, "cold_crow_blade"), "Return to the original comparison weapon after the forge probe.")
	main.screen = "location"
	_finish_week()
	await process_frame
	travel("luoyang")
	var route: String
	var base_cost: int
	if tier == 1:
		route = "learn_move_blade_technique"
		base_cost = 120
	elif tier == 2:
		route = "learn_lightness_ripple_steps"
		base_cost = 150
	else:
		route = "upgrade_move_cloud_sword"
		base_cost = 35 * (WUXUE.move_level(state.data, "cloud_sword") + 1)
	var expected_discount := int(floor(float(base_cost) * (tier if plan != "none" else 0) * 0.05))
	await _ensure_supply({"silver": base_cost - expected_discount})
	travel("luoyang")
	var before := int(state.data.silver)
	_market_choice("manuals", route)
	var paid := before - int(state.data.silver)
	_check(paid == base_cost - expected_discount, "Actual manual purchase/upgrade must use the library price.")
	manual_savings += expected_discount
	audit.append({"run": current_run, "event": "library_effect", "tier": tier, "week": state.data.week, "base_cost": base_cost, "paid": paid, "saved": expected_discount})
	travel("qingyun")
	_write_results()

func _training_week(discipline: String, reason: String) -> void:
	var before_xp := int(state.data.xp)
	var week := int(state.data.week)
	action("gathering" if discipline in ["herbalism", "mining"] else "train")
	_choice(discipline)
	var outcome: Dictionary = state.complete_training(discipline, 210, 99)
	_check(not outcome.is_empty(), "Production training completion must consume the current action.")
	var base_xp := 6
	var focus_bonus := TRAINING.WEEKLY_FOCUS_XP_BONUS if discipline == TRAINING.weekly_focus(week) else 0
	var sect_bonus := int(state.data.sect.buildings.training_ground) * 2
	var discovery_xp := int(Dictionary(outcome.get("herb_discovery", {})).get("xp", 0))
	_check(int(state.data.xp) - before_xp == base_xp + focus_bonus + sect_bonus + discovery_xp, "Real specialty training must grant expected base/focus/sect/discovery XP.")
	audit.append({"run": current_run, "event": reason, "discipline": discipline, "week": week, "score": 210, "xp_gain": int(state.data.xp) - before_xp, "focus_bonus": focus_bonus, "sect_bonus": sect_bonus, "outcome": outcome.duplicate(true)})
	main._finish_training_screen()
	_finish_week()
	await process_frame

func _total_move_xp(id: String) -> int:
	var total := WUXUE.wuxue_xp(state.data, id)
	for level in range(1, WUXUE.move_level(state.data, id)):
		total += 20 * (level + 1)
	return total

func _weekly_training(weeks: int) -> void:
	for week in range(weeks): await _task_week("train")

func _task_week(task: String) -> void:
	var before: Dictionary = state.data.duplicate(true)
	var before_xp := int(state.data.xp)
	var before_silver := int(state.data.silver)
	main.previous_screen = "location"
	main._show_hero_tasks()
	_choice("assign_hero_" + task)
	_check(bool(state.data.acted_this_week) and str(state.data.weekly_task_hero) == task, "A weekly task must reserve the hero's action.")
	_check(int(state.data.xp) == before_xp and int(state.data.silver) == before_silver, "Weekly task rewards must wait for week-end settlement.")
	_finish_week()
	var row := {"run": current_run, "event": "hero_weekly_task", "task": task, "week": int(state.data.week) - 1, "xp_gain": int(state.data.xp) - before_xp, "silver_gain": int(state.data.silver) - before_silver, "training_ground_level": state.data.sect.buildings.training_ground}
	if task == "train":
		var sect_bonus := int(state.data.sect.buildings.training_ground) * 2
		_check(int(row.xp_gain) == 12 + sect_bonus, "Weekly training must include the building's advertised XP bonus.")
		var levels := int(state.data.character_level) - int(before.character_level)
		var focus: String = ["strength", "insight", "constitution"][posmod(int(before.week), 3)]
		for attribute in ["strength", "agility", "insight", "constitution"]:
			_check(int(state.data[attribute]) - int(before[attribute]) == levels + (1 if attribute == focus else 0), "Sect XP must not repeat the base training attribute reward: " + attribute)
		_check(int(state.data.max_hp) - int(before.max_hp) == 3 * (levels + (1 if focus == "constitution" else 0)), "Sect training may grant HP only for actual level-ups and one base constitution reward.")
		row.applied_sect_bonus = int(row.xp_gain) - 12
	audit.append(row)
	await process_frame

func _finish_week() -> void:
	var week := int(state.data.week)
	var herbs := int(state.data.materials.herbs)
	var garden_level := int(state.data.sect.buildings.herb_garden)
	main._end_week_requested()
	_check(int(state.data.week) == week + 1 and not bool(state.data.acted_this_week), "Week-end button must advance the week and restore the action.")
	_check(int(state.data.materials.herbs) - herbs == garden_level, "Actual week-end settlement must produce exactly the garden's advertised herbs.")
	garden_harvest += garden_level
	audit.append({"run": current_run, "event": "week_end", "week": week, "garden_level": garden_level, "herbs_gained": int(state.data.materials.herbs) - herbs})

func _rejected_upgrade(id: String, reason: String) -> void:
	var before: Dictionary = state.data.duplicate(true)
	var result: Dictionary = state.upgrade_sect_building(id)
	_check(not bool(result.get("ok", false)), "Reject invalid construction: " + reason)
	_check(equivalent(before, state.data), "Rejected construction must preserve every resource and action: " + reason)
	audit.append({"run": current_run, "event": "rejected_upgrade", "reason": reason, "id": id, "week": state.data.week, "stage": state.data.quest_stage, "unchanged": true})

func _deadline_probe() -> void:
	_check(not deadline_checkpoint.is_empty(), "Deadline probe requires an actual pre-upgrade story checkpoint.")
	_check(state.import_data(deadline_checkpoint), "Restore actual chapter-three checkpoint without altering its values.")
	current_run = "natural_construction_deadline"
	main.screen = "location"
	travel("qingyun")
	while int(state.data.week) < 103: await _task_week("earn")
	action("sect_building")
	_choice("upgrade_training_ground")
	_check(int(state.data.sect.buildings.training_ground) == 3, "Construction remains legal in week 103.")
	main._resolve_choice("leave")
	_finish_week()
	_check(state.deadline_reached() and int(state.data.week) == 104, "Only actual weekly settlement may reach the deadline.")
	_rejected_upgrade("library", "week_104_deadline_with_ready_materials")
	_check(not state.end_week(), "Expired journey cannot generate repeated garden harvests.")
	_check(root.get_node("SaveManager").save_slot(3) and root.get_node("SaveManager").load_slot(3), "Deadline construction checkpoint save/load.")
	_check(main._screen_after_load() == "deadline", "An expired construction journey must load to the deadline screen.")
	audit.append({"run": current_run, "event": "deadline", "week": state.data.week, "buildings": state.data.sect.buildings.duplicate(true), "silver": state.data.silver, "materials": state.data.materials.duplicate(true)})

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition: return
	failures.append({"run": current_run, "message": message, "week": state.data.get("week", 0), "stage": state.data.get("quest_stage", ""), "screen": main.screen})
	_write_results()
	push_error("SECT_JOURNEY_FAILURE: " + message)
	quit(1)
	assert(condition, message)

func _write_results() -> void:
	var file := FileAccess.open("user://sect_journey_results.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"method": "Scripted production-handler journey; no inserted stats/materials/stages; isolated APPDATA", "checks": checks, "failures": failures, "summaries": summaries, "battle_records": records, "audit": audit}, "  "))
		file.close()
