class_name CompanionRules
extends RefCounted

## 客栈招募的门下弟子 (0.109.0) -- distinct from the story companion 林清霜
## (who joins for free at a fixed quest beat and fights in 华山论剑试炼/
## 武库天门终战). Recruited disciples are a separate, silver-bought roster
## that only accompanies the hero in repeatable 青云门切磋 (qingyun_spar)
## sparring battles, never the story battles -- keeps this feature additive
## and never touches 林清霜's hardcoded quest integration.
const DISCIPLES := {
	"zhou_mubai": {"title": "周慕白", "description": "青云新晋剑客，出手稳健，长于协同守御。", "price": 300, "hp": 28, "max_qi": 14, "attack": 5, "guard": 0},
	"liu_ruyan": {"title": "柳如烟", "description": "身法灵动的女弟子，擅长游走牵制。", "price": 380, "hp": 24, "max_qi": 16, "attack": 6, "guard": 0},
}

static func is_valid_disciple(id: String) -> bool:
	return DISCIPLES.has(id)

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
