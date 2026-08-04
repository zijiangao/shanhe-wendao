class_name CompanionRules
extends RefCounted

## 客栈招募的门下弟子 (0.109.0) -- distinct from the story companion 林清霜
## (who joins for free at a fixed quest beat and fights in 华山论剑试炼/
## 武库天门终战). Recruited disciples are a separate, silver-bought roster
## that only accompanies the hero in repeatable 青云门切磋 (qingyun_spar)
## sparring battles, never the story battles -- keeps this feature additive
## and never touches 林清霜's hardcoded quest integration.
## strength/agility/insight/constitution and skills_text/gear_text (0.111.0)
## are display-only flavor for 人物界面's roster browser -- they feed no
## growth/shopping system of their own (companions don't train or shop),
## they just let every roster member show the same panel shape (基础属性/
## 武学/装备) as 沈羽's own panel, filled with fixed catalog values instead
## of live save data.
const DISCIPLES := {
	"zhou_mubai": {"title": "周慕白", "description": "青云新晋剑客，出手稳健，长于协同守御。", "price": 300, "hp": 28, "max_qi": 14, "attack": 5, "guard": 0, "strength": 5, "agility": 4, "insight": 4, "constitution": 5, "skills_text": "霜华刺 · 突进两格攻击\n寒锋守势 · 获得护卫并回气", "gear_text": "随身青锋 · 稳健守御路数"},
	"liu_ruyan": {"title": "柳如烟", "description": "身法灵动的女弟子，擅长游走牵制。", "price": 380, "hp": 24, "max_qi": 16, "attack": 6, "guard": 0, "strength": 4, "agility": 6, "insight": 5, "constitution": 3, "skills_text": "霜华刺 · 突进两格攻击\n寒锋守势 · 获得护卫并回气", "gear_text": "软剑轻装 · 游走牵制路数"},
}

## 林清霜是免费的剧情同伴 (0.74.0起)，在华山剧情固定加入，只在华山论剑试炼/
## 武库天门终战出战 -- 这里的数值纯粹是人物界面的展示用途，不影响那两场
## 战斗里 game_state.gd 各自硬编码的 battle.ally 数值。
const STORY_COMPANIONS := {
	"lin_qingshuang": {"title": "林清霜", "description": "华山女侠，剑法凌厉，与沈羽并肩闯荡江湖。", "hp": 34, "max_qi": 15, "attack": 6, "guard": 0, "strength": 5, "agility": 6, "insight": 5, "constitution": 4, "skills_text": "霜华刺 · 突进两格攻击\n寒锋守势 · 获得护卫并回气", "gear_text": "华山佩剑 · 凌厉剑路"},
}

static func is_valid_disciple(id: String) -> bool:
	return DISCIPLES.has(id)

## 人物界面左右分栏浏览器 (0.111.0) 统一读取入口，覆盖 STORY_COMPANIONS 和
## DISCIPLES 两个目录 -- 沈羽本人不在这里，由 main.gd 单独处理（他是玩家
## 实时成长的存档数据，不是固定目录）。
static func is_valid_companion(id: String) -> bool:
	return DISCIPLES.has(id) or STORY_COMPANIONS.has(id)

static func companion_entry(id: String) -> Dictionary:
	return STORY_COMPANIONS.get(id, DISCIPLES.get(id, {}))

## 已加入门派的同伴列表 (0.111.0)，用于人物界面左侧名单 -- 林清霜(若已加入)
## 排在最前，其后是全部已招募弟子（不只是当前随行的那一个）。
static func roster(state: Dictionary) -> Array:
	var ids := []
	if "lin_qingshuang" in Array(state.get("companions", [])):
		ids.append("lin_qingshuang")
	for id in Array(state.get("companions", [])):
		if is_valid_disciple(str(id)):
			ids.append(str(id))
	return ids

static func is_recruited(state: Dictionary, id: String) -> bool:
	return id in Array(state.get("companions", []))

static func recruit(state: Dictionary, id: String) -> bool:
	if not is_valid_disciple(id) or is_recruited(state, id) or int(state.get("silver", 0)) < int(DISCIPLES[id].price):
		return false
	state.silver = int(state.get("silver", 0)) - int(DISCIPLES[id].price)
	state.companions.append(id)
	state.active_disciple = id
	return true

## 客栈选项列表：已招募的弟子显示为可选为"随行弟子"的只读行（招募即自动
## 随行，无需额外装备步骤，跟 0.104.0 招式取消装备槽的简化思路一致）；
## 未招募的显示招募价格，银两不足则禁用。
static func options_inn(state: Dictionary) -> Array:
	var options := []
	var silver := int(state.get("silver", 0))
	for id in DISCIPLES:
		var item: Dictionary = DISCIPLES[id]
		if is_recruited(state, id):
			var active_note := "（当前随行）" if str(state.get("active_disciple", "")) == id else "（已加入门派）"
			options.append(["已招募 · %s%s" % [str(item.title), active_note], str(item.description), "none", true])
		else:
			options.append(["招募 · %s · %d 银" % [str(item.title), int(item.price)], str(item.description), "recruit_%s" % id, silver < int(item.price)])
	options.append(["返回", "不消耗行动点，返回舆图。", "leave"])
	return options

## start_qingyun_spar_battle() (game_state.gd) uses this to build a
## battle.ally-shaped dict for whichever disciple is currently active, same
## field shape as 林清霜's hardcoded ally dict in the story battles.
static func active_disciple_ally(state: Dictionary) -> Dictionary:
	var id := str(state.get("active_disciple", ""))
	if not is_recruited(state, id) or not is_valid_disciple(id):
		return {}
	var item: Dictionary = DISCIPLES[id]
	return {"name": str(item.title), "hp": int(item.hp), "max_hp": int(item.hp), "qi": int(item.max_qi), "max_qi": int(item.max_qi), "attack": int(item.attack), "guard": int(item.guard), "x": 1, "y": 4}
