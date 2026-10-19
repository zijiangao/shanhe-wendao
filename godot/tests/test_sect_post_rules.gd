extends SceneTree

const RULES := preload("res://scripts/progression/sect_post_rules.gd")

func _initialize() -> void:
	# 门派职守 (0.175.0)：四岗位、预测公式与结算必须一一对应。
	assert(RULES.POSTS.size() == 4, "门派职守 should ship four posts.")
	assert(RULES.title("train") == "传功长老" and RULES.title("earn") == "掌柜")
	assert(RULES.title("gather") == "总管" and RULES.title("envoy") == "知客")
	assert(RULES.title("missing") == "闲置", "An unknown post must degrade to a safe label, not crash.")

	# 传功长老：1 + insight/12，封顶 4。
	assert(int(RULES.forecast("train", {"insight": 4}).xp) == 1)
	assert(int(RULES.forecast("train", {"insight": 12}).xp) == 2)
	assert(int(RULES.forecast("train", {"insight": 120}).xp) == 4)

	# 掌柜：25 + insight/4，封顶 60%。
	assert(int(RULES.forecast("earn", {"insight": 0}).earn_percent) == 25)
	assert(int(RULES.forecast("earn", {"insight": 4}).earn_percent) == 26)
	assert(int(RULES.forecast("earn", {"insight": 400}).earn_percent) == 60)

	# 总管：1 + strength/15，封顶 3。
	assert(int(RULES.forecast("gather", {"strength": 5}).herbs) == 1)
	assert(int(RULES.forecast("gather", {"strength": 30}).herbs) == 3)

	# 知客：30 级后额外 +1 声望。
	assert(int(RULES.forecast("envoy", {"level": 1}).renown) == 0)
	assert(int(RULES.forecast("envoy", {"level": 30}).renown) == 1)

	# 结算：掌柜按基础收益的百分比给银两。
	var state := {"silver": 100, "materials": {"herbs": 0, "ore": 0}, "renown": 0, "xp": 0, "character_level": 1}
	var stats := {"name": "周慕白", "level": 1, "strength": 5, "agility": 4, "insight": 4, "constitution": 5}
	var earn := RULES.apply_bonus(state, "earn", stats, {"silver": 20})
	assert(int(earn.silver) == 5 and int(state.silver) == 105, "20 silver at 26% should add 5.")
	assert("5 两" in str(earn.text) and "周慕白" in str(earn.text), "The weekly log line should name the companion and the exact bonus.")

	# 结算：采集额外给药材与矿石。
	var gather := RULES.apply_bonus(state, "gather", stats, {})
	assert(int(gather.herbs) == 1 and int(gather.ore) == 1 and int(state.materials.herbs) == 1 and int(state.materials.ore) == 1)

	# 结算：传功给沈羽修为（走 GrowthRules.grant_xp）。
	var train := RULES.apply_bonus(state, "train", stats, {})
	assert(int(train.xp) == 1 and int(state.xp) == 1, "传功长老 should credit hero xp.")

	# 结算：知客在 30 级后额外给声望。
	var veteran_stats := {"name": "周慕白", "level": 30, "strength": 5, "agility": 4, "insight": 4, "constitution": 5}
	var envoy := RULES.apply_bonus(state, "envoy", veteran_stats, {})
	assert(int(envoy.renown) == 1 and int(state.renown) == 1)

	# 无效岗位/无基础收益时安全返回。
	assert(RULES.apply_bonus(state, "missing", stats, {}).is_empty(), "Unknown posts must be a no-op.")
	assert(RULES.apply_bonus(state, "earn", stats, {"silver": 0}).is_empty(), "A zero base payout must not create a phantom bonus.")
	assert(RULES.forecast_text("gather", stats).contains("药材"), "Forecast text should describe the resource gain.")

	print("Sect post rules tests passed.")
	quit()
