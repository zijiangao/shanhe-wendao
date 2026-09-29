extends "res://tests/test_full_journey.gd"

const WUXUE = preload("res://scripts/progression/wuxue_rules.gd")
var profile := ""

func _run() -> void:
	if str(ProjectSettings.get_setting("application/config/name")) != "ShanheWendao-iteration-tests":
		quit(2)
		return
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	state = root.get_node("GameState")
	await process_frame
	main.enemy_turn_active = true
	for difficulty in ["story", "standard", "master"]:
		for plan in ["rush", "merchant", "balanced", "training", "crafting"]:
			profile = plan
			for seed_value in range(3):
				root.get_node("SettingsManager").data.difficulty = difficulty
				rng.seed = seed_value
				seed(seed_value)
				state.new_game()
				main.screen = "location"
				current_run = "%s_%s_%d" % [difficulty, plan, seed_value]
				var ok: bool = await journey(false, seed_value)
				records.append({"run": current_run, "profile": plan, "difficulty": difficulty, "completed": ok, "week": state.data.week, "silver": state.data.silver, "xp": state.data.xp, "stage": state.data.quest_stage})
				# Let queued UI cleanup finish between runs, as it does in real play.
				await process_frame
	var file := FileAccess.open("user://prepared_journey_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "  "))
	file.close()
	print("PREPARED_RESULTS ", JSON.stringify(records))
	assert(records.filter(func(row): return row.has("completed")).size() == 45)
	for row in records:
		if not row.has("completed"): continue
		if row.profile in ["balanced", "training", "crafting"]:
			assert(row.completed and int(row.week) <= 14, "Ten productive preparation weeks must support each tested full journey: " + str(row.run))
		elif row.profile == "rush" and row.difficulty == "standard":
			assert(not row.completed, "Untrained, unequipped basic attacks should not trivialize the standard finale.")
		elif row.profile == "merchant" and row.difficulty == "story":
			assert(row.completed, "Casual difficulty should allow gear and learned moves to replace the tested training schedule.")
	print("Prepared journey tests passed.")
	quit()

func prepare_chapter(chapter: int) -> void:
	if profile == "rush": return
	if chapter == 0:
		travel("luoyang")
		if profile == "merchant":
			assert(SHOP.buy_weapon(state.data, "masterwork_sword"))
			assert(SHOP.buy_armor(state.data, "masterwork_armor"))
		elif profile != "crafting":
			assert(SHOP.buy_weapon(state.data, "cold_crow_blade"))
			assert(SHOP.buy_armor(state.data, "dark_iron_armor"))
		assert(WUXUE.learn_move(state.data, "cloud_sword"))
		assert(WUXUE.learn_move(state.data, "stone_splitting_fist"))
		assert(WUXUE.learn_internal(state.data, "purple_mist_art"))
		assert(SHOP.buy_good(state.data, "healing_powder", 8))
		return
	if profile == "merchant": return
	var location := str(state.data.location)
	travel("qingyun")
	var weeks := 4 if chapter == 1 else 6
	for week in range(weeks):
		if profile == "crafting" and chapter == 1 and week < 4:
			if week < 2:
				assert(not state.complete_training("mining", 300, 99).is_empty())
			else:
				# Supplement cheap ore at the market, then spend actual crafting
				# weeks; no materials or gear are inserted into the test state.
				travel("luoyang")
				assert(SHOP.buy_good(state.data, "ore", 5))
				travel("qingyun")
				assert(state.craft("forged_iron_blade" if week == 2 else "rattan_guard"))
		elif profile == "training" and week % 3 == 2:
			assert(not state.complete_training("swordsmanship", 210, 99).is_empty())
		else:
			assert(state.assign_hero_task("train"))
		assert(state.end_week())
	if chapter == 2:
		travel("luoyang")
		assert(SHOP.buy_good(state.data, "healing_powder", 4))
	travel(location)

func tactical_action(b: Dictionary) -> bool:
	if profile == "rush": return false
	var active := str(b.active_unit)
	if active == "hero" and int(state.data.hp) <= int(state.data.max_hp) - ENGINE.healing_amount(state.data) and int(state.data.consumables.healing_powder) > 0:
		return bool(ENGINE.player_action(b, state.data, "heal", Vector2i.ZERO, rng).ok)
	for enemy in b.enemies:
		if int(enemy.hp) <= 0: continue
		var target := Vector2i(enemy.x, enemy.y)
		if active == "ally":
			if RULES.can_frost_dash(b, target, ENGINE.ally_dash_qi_cost(b), ENGINE.ally_dash_bonus_range(b)):
				return bool(ENGINE.player_action(b, state.data, "frost_dash", target, rng).ok)
		elif RULES.can_attack_cell(b, target, true, state.data.qi):
			return bool(ENGINE.player_action(b, state.data, "skill", target, rng).ok)
	return false
