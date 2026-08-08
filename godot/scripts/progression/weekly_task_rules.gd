class_name WeeklyTaskRules
extends RefCounted

const GROWTH_RULES := preload("res://scripts/progression/growth_rules.gd")

## 分派任务 (0.115.0) -- an additive, parallel system alongside the existing
## 演武场/后山 minigames, NOT a replacement: those keep their scoring/combo/
## timing mechanics exactly as before. This is a simpler no-minigame path
## for 沈羽 (an alternative way to spend his one weekly action) and the
## FIRST-EVER way for companions (who have no weekly action budget at all)
## to do anything productive between battles.
##
## 沈羽's assignment is one-shot: picking a task spends his weekly action
## immediately (mutually exclusive with演武场/后山/炼药坊/etc that week),
## but the actual reward is deferred until GameState.end_week() runs --
## "只要本周休息，就会根据各自选择自动结算收益". Companion assignments are
## persistent instead (no action-budget concept exists for them): once set,
## the same task resolves every time end_week() runs until changed/cleared.
const TASKS := {
	"earn": {"title": "赚钱", "description": "外出跑一趟买卖，凭本事挣一笔银两。"},
	"train": {"title": "修炼", "description": "闭门修炼，稳步提升根基。"},
	"gather": {"title": "采集", "description": "上山下乡，采回药材矿石。"},
}
const FOCUS_ROTATION := ["strength", "insight", "constitution"]
const COMPANION_ATTACK_GROWTH_CAP := 10

static func is_valid_task(task_id: String) -> bool:
	return TASKS.has(task_id)

static func options_hero(state: Dictionary) -> Array:
	var options := []
	var current := str(state.get("weekly_task_hero", ""))
	for task_id in TASKS:
		var item: Dictionary = TASKS[task_id]
		options.append(["%s%s" % [str(item.title), "（本周已分派）" if current == task_id else ""], str(item.description), "assign_hero_%s" % task_id, current == task_id])
	options.append(["返回", "不消耗行动点，返回人物信息。", "leave"])
	return options

static func options_companion(state: Dictionary, id: String) -> Array:
	var options := []
	var current := str(Dictionary(state.get("companion_tasks", {})).get(id, ""))
	options.append(["不分派任务", "取消这位同伴的持续任务。", "assign_companion_", current == ""])
	for task_id in TASKS:
		var item: Dictionary = TASKS[task_id]
		options.append(["%s%s" % [str(item.title), "（持续进行中）" if current == task_id else ""], str(item.description), "assign_companion_%s" % task_id, current == task_id])
	options.append(["返回", "不消耗行动点，返回同伴信息。", "leave"])
	return options

## GameState.end_week() 调用，结算沈羽本周分派的任务并清空 weekly_task_hero
## （一次性，需要下周重新选择）。返回空字典表示本周没有分派任务。
static func resolve_hero(state: Dictionary, roll: int = -1) -> Dictionary:
	var task_id := str(state.get("weekly_task_hero", ""))
	if not is_valid_task(task_id):
		return {}
	var bonus := roll if roll >= 0 else randi_range(0, 10)
	var result := {"task": task_id}
	match task_id:
		"earn":
			var silver := 15 + int(state.get("strength", 0)) + int(state.get("insight", 0)) / 2 + bonus
			state.silver = int(state.get("silver", 0)) + silver
			result.silver = silver
			result.text = "沈羽跑了一趟买卖，赚回%d两银子。" % silver
		"train":
			var focus := str(FOCUS_ROTATION[posmod(int(state.get("week", 1)), FOCUS_ROTATION.size())])
			GROWTH_RULES.apply_training(state, focus)
			result.focus = focus
			result.text = {"strength": "沈羽闭门锻体，臂力与修为提升。", "insight": "沈羽闭门参悟，悟性与修为提升。", "constitution": "沈羽闭门筑基，根骨、气血与修为提升。"}[focus]
		"gather":
			var herbs := 1 + bonus / 6
			var ore := 1 + bonus / 6
			state.materials.herbs = int(state.materials.get("herbs", 0)) + herbs
			state.materials.ore = int(state.materials.get("ore", 0)) + ore
			result.herbs = herbs
			result.ore = ore
			result.text = "沈羽上山下乡，采回%d份药材、%d份矿石。" % [herbs, ore]
	state.weekly_task_hero = ""
	return result

## 同伴那份的等价物 -- companion_id 必须已加入门派 (COMPANION_RULES.roster())
## 才会被 GameState.end_week() 结算，避免离队同伴还在偷偷挣钱。
static func resolve_companion(state: Dictionary, id: String, companion_attack: int, roll: int = -1) -> Dictionary:
	var task_id := str(Dictionary(state.get("companion_tasks", {})).get(id, ""))
	if not is_valid_task(task_id):
		return {}
	var bonus := roll if roll >= 0 else randi_range(0, 8)
	var result := {"task": task_id}
	match task_id:
		"earn":
			var silver := 10 + companion_attack + bonus
			state.silver = int(state.get("silver", 0)) + silver
			result.silver = silver
		"train":
			if not state.has("companion_growth") or typeof(state.companion_growth) != TYPE_DICTIONARY:
				state.companion_growth = {}
			if not state.companion_growth.has(id) or typeof(state.companion_growth[id]) != TYPE_DICTIONARY:
				state.companion_growth[id] = {"attack_bonus": 0}
			var current_bonus := int(state.companion_growth[id].get("attack_bonus", 0))
			if current_bonus < COMPANION_ATTACK_GROWTH_CAP:
				state.companion_growth[id].attack_bonus = current_bonus + 1
				result.attack_bonus_gained = 1
			else:
				result.attack_bonus_gained = 0
		"gather":
			var herbs := 1 + bonus / 5
			var ore := 1 + bonus / 5
			state.materials.herbs = int(state.materials.get("herbs", 0)) + herbs
			state.materials.ore = int(state.materials.get("ore", 0)) + ore
			result.herbs = herbs
			result.ore = ore
	return result

## CompanionRules.apply_gear_and_move() 叠加这个持续修炼加成到 ally.attack。
static func companion_attack_growth(state: Dictionary, id: String) -> int:
	return int(Dictionary(state.get("companion_growth", {})).get(id, {}).get("attack_bonus", 0))
