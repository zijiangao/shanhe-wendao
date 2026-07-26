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
	grant_xp(state, 12)
	return true

## Character level (0.93.0) is a separate, independent progression track
## from the 境界 rank above (which only ever gives an abstract combat_bonus)
## -- it shares the same 修为/xp resource, so every xp gain (training,
## sparring, chapter rewards) feeds it automatically, but leveling up grants
## a real, permanent +1 to all four base attributes instead of a rank name.
## No cap: attribute growth from other sources (pills, training) is already
## uncapped, so capping the level would be an inconsistent restriction.
const LEVEL_XP_STEP := 25

static func character_level(xp: int) -> int:
	return 1 + maxi(0, int(xp)) / LEVEL_XP_STEP

static func xp_into_level(xp: int) -> int:
	return maxi(0, int(xp)) % LEVEL_XP_STEP

## Adds xp to state and applies any character-level-ups this gain crosses,
## each one granting +1 strength/agility/insight/constitution (and the same
## +3 max/current hp constitution always grants elsewhere). Returns how many
## levels were gained (0 if the gain wasn't enough to cross a level).
##
## state.character_level tracks how many levels have already been PAID OUT
## in attributes, separate from character_level(xp) (a pure display function
## of total xp). This matters for saves from before this feature existed:
## defaulting a missing field to the level the NEW xp total already implies
## (not to 1) means an old save with a lot of already-accumulated xp is never
## retroactively back-paid a pile of free attribute points the first time it
## gains xp after this patch -- it simply starts tracking from here forward.
static func grant_xp(state: Dictionary, amount: int) -> int:
	if amount <= 0:
		return 0
	state.xp = int(state.get("xp", 0)) + amount
	var target := character_level(int(state.xp))
	var current := int(state.get("character_level", target))
	var gained := target - current
	if gained > 0:
		state.strength = int(state.get("strength", 0)) + gained
		state.agility = int(state.get("agility", 0)) + gained
		state.insight = int(state.get("insight", 0)) + gained
		state.constitution = int(state.get("constitution", 0)) + gained
		state.max_hp = int(state.get("max_hp", 0)) + gained * 3
		state.hp = mini(int(state.max_hp), int(state.get("hp", 0)) + gained * 3)
	state.character_level = target
	return gained

