extends SceneTree

# Integration playthrough: production story handlers and combat rules, no seeded
# quest flags, XP, money, enemies, or victories. Run in an isolated project only.
const ENGINE = preload("res://scripts/battle/battle_engine.gd")
const RULES = preload("res://scripts/battle/battle_rules.gd")
const SHOP = preload("res://scripts/progression/shop_rules.gd")
var main
var state
var rng := RandomNumberGenerator.new()
var records: Array = []
var capture_enabled := false
var current_run := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if str(ProjectSettings.get_setting("application/config/name")) != "ShanheWendao-iteration-tests":
		push_error("Use an isolated acceptance project.")
		quit(2)
		return
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	state = root.get_node("GameState")
	await process_frame
	# The probe owns turn execution; keep the view from scheduling enemy turns.
	main.enemy_turn_active = true
	capture_enabled = "--capture-journey" in OS.get_cmdline_user_args()
	for difficulty in ["story", "standard", "master"]:
		for equipped in [false, true]:
			for seed_value in range(3):
				root.get_node("SettingsManager").data.difficulty = difficulty
				rng.seed = seed_value
				state.new_game()
				main.screen = "location"
				current_run = "%s_%s_%d" % [difficulty, "equipped" if equipped else "bare", seed_value]
				var ok: bool = await journey(equipped, seed_value)
				records.append({"difficulty_requested": difficulty, "equipped": equipped, "seed": seed_value, "completed": ok, "week": state.data.week, "silver": state.data.silver, "xp": state.data.xp, "stage": state.data.quest_stage})
				await process_frame
	probe_defeat_and_deadline()
	current_run = "standard_bare_0"
	await capture("deadline")
	var file := FileAccess.open("user://full_journey_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "  "))
	file.close()
	print("JOURNEY_RESULTS ", JSON.stringify(records))
	# Completion rate is a balance observation, not a requirement that untrained
	# characters must always win. Inspect the JSON when tuning combat later.
	assert(records.filter(func(row): return row.has("completed")).size() == 18, "Every configured journey must produce a result.")
	quit()

func dialogue() -> void:
	var limit := 0
	while main.screen == "dialogue" and limit < 20:
		main._advance_dialogue()
		limit += 1
	assert(limit < 20)

func action(id: String) -> void:
	var available := false
	for entry in main._location_actions(str(state.data.location)):
		if str(entry.id) == id and not bool(entry.get("disabled", false)):
			available = true
	assert(available, "Journey attempted unavailable location action: " + id)
	main._location_action_requested(id)
	dialogue()

func travel(place: String) -> void:
	assert(state.travel(place))
	main.screen = "location"

func journey(equipped: bool, route_index: int) -> bool:
	action("master")
	prepare_chapter(0)
	if equipped:
		travel("luoyang")
		assert(SHOP.buy_weapon(state.data, "dragon_etched_sword"))
		assert(SHOP.buy_armor(state.data, "cold_jade_armor"))
		for i in range(5):
			assert(SHOP.buy_good(state.data, "healing_powder"))
	travel("blackreed")
	action("fisher")
	action("tracks")
	action("fight")
	if not await battle(): return false
	main._claim_battle_reward("temper")
	travel("qingyun")
	action("master")
	travel("luoyang")
	action("temple")
	assert(main.choice_event == "baima_route")
	main._resolve_choice(["heroism", "strategy", "authority"][route_index])
	action("palace")
	main._palace_event("witness")
	dialogue()
	main._palace_event("ledger")
	dialogue()
	main._confront_li_wujiu()
	dialogue()
	assert(main.choice_event == "chapter2_end")
	main._resolve_choice(["public", "master", "keep"][route_index])
	assert(state.end_week())
	prepare_chapter(1)
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
	if route_index == 2:
		assert(state.end_week())
	main._resolve_choice("aid" if route_index == 2 else "recommend")
	action("meet_su")
	action("elephant_pool")
	action("emei_peak")
	assert(state.end_week())
	prepare_chapter(2)
	action("emei_peak")
	if not await battle(): return false
	main._claim_battle_reward("temper")
	var before: Dictionary = state.data.duplicate(true)
	for ending in ["destroy", "seal", "preserve"]:
		assert(state.import_data(before))
		main.screen = main._screen_after_load()
		assert(main.screen == "final_choice")
		main._show_final_choice()
		main._resolve_choice(ending)
		assert(state.data.ending.id == ending and main.screen == "ending")
		assert(root.get_node("SaveManager").save_slot(1))
		assert(root.get_node("SaveManager").load_slot(1))
		assert(main._screen_after_load() == "ending")
		await capture("ending_" + ending)
	return true

func battle() -> bool:
	assert(not state.data.battle.is_empty())
	var b: Dictionary = state.data.battle
	var count := 0
	var start_hp: int = state.data.hp
	var meds: int = state.data.consumables.healing_powder
	await capture(str(b.battle_id) + "_start")
	while not ENGINE.is_victory(b) and int(state.data.hp) > 0 and count < 500:
		count += 1
		if count == 12:
			var checkpoint: Dictionary = state.data.duplicate(true)
			assert(root.get_node("SaveManager").save_slot(2))
			assert(root.get_node("SaveManager").load_slot(2))
			assert(equivalent(checkpoint, state.data), "A real mid-battle save/load must preserve existing run values (JSON numbers and added migration defaults are allowed).")
			b = state.data.battle
		var active := str(b.active_unit)
		if active.begins_with("enemy:"):
			var outcome: Dictionary = ENGINE.resolve_enemy_turn(b, int(active.split(":")[1]), state.data.hp, rng, SHOP.armor_defense_bonus(state.data))
			state.data.hp = outcome.hero_hp
			if int(state.data.hp) > 0: ENGINE.advance_turn(b)
			continue
		if int(b.action_points) <= 0:
			ENGINE.advance_turn(b)
			continue
		if tactical_action(b): continue
		if active == "hero" and int(state.data.hp) <= int(state.data.max_hp) - 12 and int(state.data.consumables.healing_powder) > 0:
			if ENGINE.player_action(b, state.data, "heal", Vector2i.ZERO, rng).ok: continue
		var acted := false
		for enemy in b.enemies:
			if int(enemy.hp) <= 0: continue
			var target := Vector2i(enemy.x, enemy.y)
			if RULES.can_attack_cell(b, target, false, state.data.qi):
				assert(ENGINE.player_action(b, state.data, "attack", target, rng).ok)
				acted = true
				break
		if acted: continue
		var origin: Vector2i = RULES.active_position(b)
		var best := origin
		var best_distance := 999
		for y in range(b.height):
			for x in range(b.width):
				var cell := Vector2i(x, y)
				var move_bonus: int = 0 if active == "ally" else main.WUXUE_RULES.lightness_move_bonus(state.data)
				if not RULES.can_move_to(b, cell, move_bonus): continue
				for enemy in b.enemies:
					if int(enemy.hp) <= 0: continue
					var path := RULES.find_path(b, cell, Vector2i(enemy.x, enemy.y), true)
					if path.size() > 0 and path.size() < best_distance:
						best_distance = path.size()
						best = cell
		if best != origin:
			assert(ENGINE.player_action(b, state.data, "move", best, rng).ok)
		else:
			ENGINE.advance_turn(b)
	var victory: bool = int(state.data.hp) > 0 and ENGINE.is_victory(b)
	records.append({"run": current_run, "battle": b.battle_id, "difficulty": b.get("difficulty", ""), "week": state.data.week, "start_hp": start_hp, "end_hp": state.data.hp, "turns": b.turn, "actions": count, "medicines_used": meds - int(state.data.consumables.healing_powder), "victory": victory})
	if victory:
		assert(main._check_tactical_victory(b))
		await capture(str(b.battle_id) + "_victory")
	else:
		state.finish_battle(false)
	return victory

func prepare_chapter(_chapter: int) -> void:
	pass

func tactical_action(_battle: Dictionary) -> bool:
	return false

func capture(label: String) -> void:
	if not capture_enabled or current_run != "standard_bare_0": return
	main._rebuild()
	main._skip_all_tutorials()
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("user://journey_" + label + ".png") == OK)

func equivalent(expected: Variant, actual: Variant) -> bool:
	if expected is Dictionary:
		if not actual is Dictionary: return false
		for key in expected:
			if not actual.has(key) or not equivalent(expected[key], actual[key]): return false
		return true
	if expected is Array:
		if not actual is Array or expected.size() != actual.size(): return false
		for index in range(expected.size()):
			if not equivalent(expected[index], actual[index]): return false
		return true
	if (expected is int or expected is float) and (actual is int or actual is float):
		return float(expected) == float(actual)
	return expected == actual

func probe_defeat_and_deadline() -> void:
	root.get_node("SettingsManager").data.difficulty = "standard"
	state.new_game()
	main.screen = "location"
	action("master")
	travel("blackreed")
	action("fisher")
	action("tracks")
	action("fight")
	var opening: Dictionary = state.data.duplicate(true)
	var b: Dictionary = state.data.battle
	for turn in range(300):
		if int(state.data.hp) <= 0: break
		if str(b.active_unit).begins_with("enemy:"):
			var outcome: Dictionary = ENGINE.resolve_enemy_turn(b, int(str(b.active_unit).split(":")[1]), state.data.hp, rng)
			state.data.hp = outcome.hero_hp
		if int(state.data.hp) > 0: ENGINE.advance_turn(b)
	assert(int(state.data.hp) <= 0, "Passing every turn must eventually lose this battle.")
	state.finish_battle(false)
	var loss: int = int(opening.silver) - int(state.data.silver)
	assert(state.retry_last_battle())
	for key in ["week", "hp", "qi", "silver", "consumables"]:
		assert(equivalent(opening[key], state.data[key]), "Retry must restore " + key)
	records.append({"probe": "defeat_retry", "loss_on_accept": loss, "retry_restored": true})
	state.new_game()
	main.screen = "location"
	for week in range(103):
		assert(state.assign_hero_task("earn"))
		main._end_week_requested()
	assert(state.deadline_reached())
	assert(not state.travel("blackreed"))
	assert(root.get_node("SaveManager").save_slot(3))
	assert(root.get_node("SaveManager").load_slot(3))
	assert(main._screen_after_load() == "deadline", "An expired journey needs a clear recovery screen on reload.")
	main._switch_screen("map")
	assert(main.screen == "deadline", "Header navigation must not leave the player on an unusable map.")
	main._switch_screen("save")
	assert(main.screen == "save" and main.previous_screen == "deadline")
	main._switch_screen("location")
	assert(main.screen == "deadline")
	records.append({"probe": "deadline", "week": state.data.week, "ending": state.data.ending, "screen_after_load": main._screen_after_load(), "stage": state.data.quest_stage})
