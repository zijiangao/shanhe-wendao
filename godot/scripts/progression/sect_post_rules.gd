class_name SectPostRules
extends RefCounted

const GROWTH_RULES := preload("res://scripts/progression/growth_rules.gd")

## 门派职守 (0.175.0) -- 把 0.115.0 的"分派任务"升级成有身份的岗位。
##
## 金书江湖2 的九职位是"每名弟子按属性给全门派加成"；山河问道只有
## 林清霜 + 两名可招募弟子，且每周只有沈羽一次行动，所以这里做的是
## 轻量版：每名同伴选一个职守，职守仍然对应原来那三种持续任务，
## 额外给一份随属性成长的"岗位收益"，并在周四结算时单独写日志。
##
## 刻意保持纯规则、零依赖（只 preload GrowthRules）：职守数据既被
## WeeklyTaskRules 用来结算，也被 UI 用来显示预测，避免循环 preload。
const POSTS := {
	"train": {
		"title": "传功长老",
		"summary": "坐镇演武场，指点沈羽与同门。",
		"effect": "沈羽每周额外获得修为，悟性越高越多。",
	},
	"earn": {
		"title": "掌柜",
		"summary": "打理门派买卖，为门派多挣一份银两。",
		"effect": "该同伴赚钱时银两收益提高，悟性越高越多。",
	},
	"gather": {
		"title": "总管",
		"summary": "统筹后山采集与库房。",
		"effect": "该同伴采集时额外带回药材与矿石，力量越高越多。",
	},
	"envoy": {
		"title": "知客",
		"summary": "行走江湖，替青云门结交四方。",
		"effect": "该同伴游历时每周带回声望，30 级后更多。",
	},
}

const TRAIN_XP_CAP := 4
const EARN_PERCENT_CAP := 60
const GATHER_BONUS_CAP := 3
const ENVOY_EXTRA_LEVEL := 30

static func is_valid_post(post_id: String) -> bool:
	return POSTS.has(post_id)

static func title(post_id: String) -> String:
	return str(POSTS.get(post_id, {}).get("title", "闲置"))

static func summary(post_id: String) -> String:
	return str(POSTS.get(post_id, {}).get("summary", "这位同伴暂时没有职守。"))

static func effect_text(post_id: String) -> String:
	return str(POSTS.get(post_id, {}).get("effect", ""))

## 职守与持续任务共用同一套 id（train/earn/gather/envoy），这样老存档的
## companion_tasks 不需要迁移；如果以后要拆成两套 id，只改这两个函数。
static func post_for_task(task_id: String) -> String:
	return task_id if POSTS.has(task_id) else ""

## 预测值只描述"岗位额外收益"，不含任务本身的基础产出：
## - train: 沈羽额外修为
## - earn: 银两收益百分比
## - gather: 额外药材/矿石
## - envoy: 额外声望
static func forecast(post_id: String, stats: Dictionary = {}) -> Dictionary:
	var result := {"xp": 0, "earn_percent": 0, "herbs": 0, "ore": 0, "renown": 0}
	match post_id:
		"train":
			result.xp = clampi(1 + int(stats.get("insight", 0)) / 12, 1, TRAIN_XP_CAP)
		"earn":
			result.earn_percent = clampi(25 + int(stats.get("insight", 0)) / 4, 25, EARN_PERCENT_CAP)
		"gather":
			var amount := clampi(1 + int(stats.get("strength", 0)) / 15, 1, GATHER_BONUS_CAP)
			result.herbs = amount
			result.ore = amount
		"envoy":
			result.renown = 1 if int(stats.get("level", 1)) >= ENVOY_EXTRA_LEVEL else 0
	return result

static func forecast_text(post_id: String, stats: Dictionary = {}) -> String:
	var value := forecast(post_id, stats)
	match post_id:
		"train":
			return "沈羽修为 +%d/周" % int(value.xp)
		"earn":
			return "银两收益 +%d%%" % int(value.earn_percent)
		"gather":
			return "药材 +%d、矿石 +%d/周" % [int(value.herbs), int(value.ore)]
		"envoy":
			if int(value.renown) <= 0:
				return "声望 +1/周（30 级后额外 +1）"
			return "声望 +1/周，另额外 +%d" % int(value.renown)
	return ""

## 结算岗位额外收益。base_result 是 WeeklyTaskRules.resolve_companion()
## 已完成基础产出后的结果字典（earn 用它算百分比；其余职守不需要）。
## stats 至少包含 name/level/strength/insight，由 WeeklyTaskRules 填充。
static func apply_bonus(state: Dictionary, post_id: String, stats: Dictionary, base_result: Dictionary) -> Dictionary:
	if not is_valid_post(post_id):
		return {}
	var value := forecast(post_id, stats)
	var name := str(stats.get("name", "同伴"))
	var result := {"post": post_id, "title": title(post_id), "text": ""}
	match post_id:
		"train":
			var xp := int(value.xp)
			if xp <= 0:
				return {}
			var levels := GROWTH_RULES.grant_xp(state, xp)
			result.xp = xp
			result.levels_gained = levels
			result.text = "%s以传功长老之道指点沈羽，修为 +%d。" % [name, xp]
			if levels > 0:
				result.text += "沈羽升至 %d 级。" % GROWTH_RULES.character_level(int(state.get("xp", 0)))
		"earn":
			var base_silver := maxi(0, int(base_result.get("silver", 0)))
			if base_silver <= 0:
				return {}
			var bonus := maxi(1, roundi(float(base_silver) * float(value.earn_percent) / 100.0))
			state.silver = int(state.get("silver", 0)) + bonus
			result.silver = bonus
			result.earn_percent = int(value.earn_percent)
			result.text = "%s以掌柜之道多赚了 %d 两。" % [name, bonus]
		"gather":
			var herbs := int(value.herbs)
			var ore := int(value.ore)
			if herbs <= 0 and ore <= 0:
				return {}
			state.materials.herbs = int(state.materials.get("herbs", 0)) + herbs
			state.materials.ore = int(state.materials.get("ore", 0)) + ore
			result.herbs = herbs
			result.ore = ore
			result.text = "%s以总管之道多带回药材 %d、矿石 %d。" % [name, herbs, ore]
		"envoy":
			var renown := int(value.renown)
			if renown <= 0:
				return {}
			state.renown = int(state.get("renown", 0)) + renown
			result.renown = renown
			result.text = "%s以知客之道为门派扬名，声望 +%d。" % [name, renown]
	return result
