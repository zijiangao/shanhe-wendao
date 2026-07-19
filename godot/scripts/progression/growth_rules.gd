class_name GrowthRules
extends RefCounted

const RANKS := [
	{"xp": 0, "name": "初窥门径"},
	{"xp": 30, "name": "登堂入室"},
	{"xp": 70, "name": "融会贯通"},
	{"xp": 120, "name": "炉火纯青"},
	{"xp": 180, "name": "返璞归真"}
]
const TRAINING_OPTIONS := [
	["锻体 · 臂力", "臂力 +1 · 普攻与流云剑法伤害提高", "strength"],
	["参悟 · 悟性", "悟性 +1 · 每2点悟性提高1点流云剑法伤害", "insight"],
	["筑基 · 根骨", "根骨 +1 · 最大气血与当前气血 +3", "constitution"]
]

static func rank_index(xp: int) -> int:
	var result := 0
	for index in range(RANKS.size()):
		if xp >= int(RANKS[index].xp):
			result = index
	return result

static func rank_name(xp: int) -> String:
	return str(RANKS[rank_index(xp)].name)

static func combat_bonus(xp: int) -> int:
	return rank_index(xp)

static func next_rank_xp(xp: int) -> int:
	var current := rank_index(xp)
	return int(RANKS[current + 1].xp) if current + 1 < RANKS.size() else -1

static func apply_training(state: Dictionary, focus: String) -> bool:
	match focus:
		"strength": state.strength = int(state.strength) + 1
		"insight": state.insight = int(state.insight) + 1
		"constitution":
			state.constitution = int(state.constitution) + 1
			state.max_hp = int(state.max_hp) + 3
			state.hp = mini(int(state.max_hp), int(state.hp) + 3)
		_: return false
	state.xp = int(state.xp) + 12
	return true

