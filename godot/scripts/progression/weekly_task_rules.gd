class_name WeeklyTaskRules
extends RefCounted

const GROWTH_RULES := preload("res://scripts/progression/growth_rules.gd")
const SECT_BUILDING_RULES := preload("res://scripts/progression/sect_building_rules.gd")
const SECT_POST_RULES := preload("res://scripts/progression/sect_post_rules.gd")

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
	"envoy": {"title": "游历", "description": "走访江湖，替门派扬名。"},
}
const FOCUS_ROTATION := ["strength", "insight", "constitution"]
## 侠客升级 (0.116.0)：修炼任务每次结算发放的经验，跟沈羽自己
## apply_training() 发放的12点修为一致，共用 GrowthRules.LEVEL_XP_STEP=25
## 的升级节奏，让两条成长线的速度感保持一致。
const COMPANION_TRAIN_XP := 12
const COMPANION_GROWTH_KEYS := ["strength", "agility", "insight", "constitution"]

static func is_valid_task(task_id: String) -> bool:
	return TASKS.has(task_id)

static func options_hero(state: Dictionary) -> Array:
	var options := []
	var current := str(state.get("weekly_task_hero", ""))
	var unavailable := bool(state.get("acted_this_week", false)) or not current.is_empty()
	for task_id in TASKS:
		var item: Dictionary = TASKS[task_id]
		var note := " 本周行动已用完，请结束本周后再分派。" if unavailable else " 占用本周行动，结束本周时结算。"
		var sect_bonus := SECT_BUILDING_RULES.training_xp_bonus(state) if task_id == "train" else 0
		if sect_bonus > 0:
			note += " 演武场结算时额外修为 +%d。" % sect_bonus
		options.append(["%s%s" % [str(item.title), "（本周已分派）" if current == task_id else ""], str(item.description) + note, "assign_hero_%s" % task_id, unavailable])
	options.append(["返回", "不消耗行动点，返回人物信息。", "leave"])
	return options

static func options_companion(state: Dictionary, id: String, stats: Dictionary = {}) -> Array:
	var options := []
	var current := str(Dictionary(state.get("companion_tasks", {})).get(id, ""))
	options.append(["不任职守", "取消这位同伴的持续职守。", "assign_companion_", current == ""])
	for task_id in TASKS:
		var post_title := SECT_POST_RULES.title(task_id)
		var forecast := SECT_POST_RULES.forecast_text(task_id, stats)
		var text := "%s\n%s" % [SECT_POST_RULES.summary(task_id), forecast]
		options.append(["%s%s" % [post_title, "（当前职守）" if current == task_id else ""], text, "assign_companion_%s" % task_id, current == task_id])
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
			var sect_bonus := SECT_BUILDING_RULES.training_xp_bonus(state)
			GROWTH_RULES.grant_xp(state, sect_bonus)
			result.focus = focus
			result.xp_gained = 12 + sect_bonus
			result.sect_training_bonus = sect_bonus
			result.text = {"strength": "沈羽闭门锻体，臂力与修为提升。", "insight": "沈羽闭门参悟，悟性与修为提升。", "constitution": "沈羽闭门筑基，根骨、气血与修为提升。"}[focus]
			if sect_bonus > 0:
				result.text += "演武场额外修为 +%d。" % sect_bonus
		"gather":
			var herbs := 1 + bonus / 6
			var ore := 1 + bonus / 6
			state.materials.herbs = int(state.materials.get("herbs", 0)) + herbs
			state.materials.ore = int(state.materials.get("ore", 0)) + ore
			result.herbs = herbs
			result.ore = ore
			result.text = "沈羽上山下乡，采回%d份药材、%d份矿石。" % [herbs, ore]
		"envoy":
			var renown := 1 + bonus / 6
			state.renown = int(state.get("renown", 0)) + renown
			result.renown = renown
			result.text = "沈羽走访江湖，为青云门扬名，声望 +%d。" % renown
	state.weekly_task_hero = ""
	return result

## 同伴那份的等价物 -- companion_id 必须已加入门派 (COMPANION_RULES.roster())
## 才会被 GameState.end_week() 结算，避免离队同伴还在偷偷挣钱。
static func resolve_companion(state: Dictionary, id: String, companion_attack: int, roll: int = -1, companion_stats: Dictionary = {}) -> Dictionary:
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
			result.levels_gained = grant_companion_xp(state, id, COMPANION_TRAIN_XP)
			result.xp_gained = COMPANION_TRAIN_XP
		"gather":
			var herbs := 1 + bonus / 5
			var ore := 1 + bonus / 5
			state.materials.herbs = int(state.materials.get("herbs", 0)) + herbs
			state.materials.ore = int(state.materials.get("ore", 0)) + ore
			result.herbs = herbs
			result.ore = ore
		"envoy":
			var renown := 1
			state.renown = int(state.get("renown", 0)) + renown
			result.renown = renown
	# 岗位额外收益 (0.175.0)：只有调用方传入同伴属性时才结算，保证老调用
	# 方式（测试/旧逻辑）行为不变；GameState.end_week() 永远传真实属性。
	if not companion_stats.is_empty():
		var post_bonus := SECT_POST_RULES.apply_bonus(state, task_id, companion_stats, result)
		if not post_bonus.is_empty():
			result.post_bonus = post_bonus
			result.post_text = str(post_bonus.get("text", ""))
	return result

static func _companion_growth_bucket(state: Dictionary, id: String) -> Dictionary:
	if not state.has("companion_growth") or typeof(state.companion_growth) != TYPE_DICTIONARY:
		state.companion_growth = {}
	if not state.companion_growth.has(id) or typeof(state.companion_growth[id]) != TYPE_DICTIONARY:
		state.companion_growth[id] = {}
	var bucket: Dictionary = state.companion_growth[id]
	bucket.xp = _growth_number(bucket.get("xp", 0))
	bucket.level = GROWTH_RULES.character_level(int(bucket.xp))
	for key in COMPANION_GROWTH_KEYS:
		bucket[key] = _growth_number(bucket.get(key, 0))
	return bucket

static func _growth_number(value: Variant) -> int:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return maxi(0, int(value))
	return 0

## 侠客升级 (0.116.0)：跟沈羽共用同一套 GrowthRules.character_level() 公式，
## 每升一级四维属性各+1，攻击随 strength 成长、气血随 constitution 成长
## (companion_attack_growth()/companion_hp_growth())，跟沈羽自己 grant_xp()
## 的效果一一对应，只是数据分开存放在 companion_growth[id] 里，不影响沈羽
## 自己的 xp/character_level。经验来源有两处：分派任务的"修炼"
## (COMPANION_TRAIN_XP，见上) 与随沈羽出战获胜 (GameState.finish_battle())。
static func grant_companion_xp(state: Dictionary, id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var bucket := _companion_growth_bucket(state, id)
	bucket.xp = int(bucket.xp) + amount
	var target := GROWTH_RULES.character_level(int(bucket.xp))
	var current := int(bucket.get("level", 1))
	var gained := target - current
	if gained > 0:
		for key in COMPANION_GROWTH_KEYS:
			bucket[key] = int(bucket[key]) + gained
	bucket.level = target
	return gained

static func companion_level(state: Dictionary, id: String) -> int:
	return int(_companion_growth_bucket(state, id).get("level", 1))

static func companion_xp(state: Dictionary, id: String) -> int:
	return int(_companion_growth_bucket(state, id).get("xp", 0))

static func companion_xp_into_level(state: Dictionary, id: String) -> int:
	return GROWTH_RULES.xp_into_level(companion_xp(state, id))

## CompanionRules.apply_gear_and_move() 叠加这两项持续成长到 ally.attack/hp。
static func companion_attack_growth(state: Dictionary, id: String) -> int:
	return int(_companion_growth_bucket(state, id).get("strength", 0))

static func companion_hp_growth(state: Dictionary, id: String) -> int:
	return int(_companion_growth_bucket(state, id).get("constitution", 0)) * 3

static func companion_attribute_growth(state: Dictionary, id: String, key: String) -> int:
	return int(_companion_growth_bucket(state, id).get(key, 0))

## 门人职守 (0.175.0)：把固定目录里的基础属性与存档里的成长值合成一份
## 只读属性快照，供 SectPostRules 计算岗位收益、供 UI 显示预测。
## 不 preload CompanionRules，避免 WeeklyTaskRules -> CompanionRules ->
## WeeklyTaskRules 的循环依赖；调用方把 companion_entry() 的结果传进来。
static func companion_stats(state: Dictionary, id: String, entry: Dictionary) -> Dictionary:
	return {
		"name": str(entry.get("title", id)),
		"level": companion_level(state, id),
		"strength": int(entry.get("strength", 0)) + companion_attribute_growth(state, id, "strength"),
		"agility": int(entry.get("agility", 0)) + companion_attribute_growth(state, id, "agility"),
		"insight": int(entry.get("insight", 0)) + companion_attribute_growth(state, id, "insight"),
		"constitution": int(entry.get("constitution", 0)) + companion_attribute_growth(state, id, "constitution"),
		"attack": int(entry.get("attack", 0)) + companion_attack_growth(state, id),
	}
