class_name HerbariumRules
extends RefCounted

const SPECIMENS := {
	"dewgrass": {
		"name": "凝露草",
		"rarity": "寻常",
		"description": "晨露未散时采下，可止血生肌。"
	},
	"cloudleaf": {
		"name": "云纹叶",
		"rarity": "少见",
		"description": "叶脉如流云，晒干后可调和药性。"
	},
	"sunroot": {
		"name": "赤阳参",
		"rarity": "珍稀",
		"description": "根须温热，善补行功后损耗的气血。"
	},
	"sevenstar_lotus": {
		"name": "七星莲",
		"rarity": "奇珍",
		"description": "七瓣映星，只在灵气充盈处短暂开放。"
	}
}

const GRADE_POOLS := {
	"C": ["dewgrass"],
	"B": ["dewgrass", "cloudleaf"],
	"A": ["dewgrass", "cloudleaf", "sunroot"],
	"S": ["dewgrass", "cloudleaf", "sunroot", "sevenstar_lotus"]
}

## 采药等级 (0.117.0) -- 独立于 TrainingMinigameRules 的采药"专精"（那个是
## 采药人本身的0-100级熟练度，影响小游戏难度/产量），这个是药材本身的
## 1-10级"图鉴"进度：每采到一份药材（不论品级）累积一次，每 CATCHES_PER_LEVEL
## 次升一级，无需额外存档字段——直接从 herbarium 收藏字典的数量总和推算，
## 天然对旧存档兼容。未到对应等级门槛的稀有品级，即使单局小游戏打出S级，
## 也绝对采不到（LEVEL_UNLOCK 是硬门槛，不是概率加成）。
const MAX_GATHER_LEVEL := 10
const CATCHES_PER_LEVEL := 3
const LEVEL_UNLOCK := {
	"dewgrass": 1,
	"cloudleaf": 4,
	"sunroot": 7,
	"sevenstar_lotus": 10,
}

static func total_catches(collection: Variant) -> int:
	var safe_collection: Dictionary = collection if typeof(collection) == TYPE_DICTIONARY else {}
	var total := 0
	for specimen_id in safe_collection:
		total += int(safe_collection[specimen_id])
	return total

static func gather_level(collection: Variant, lifetime: int = -1) -> int:
	return mini(MAX_GATHER_LEVEL, 1 + maxi(total_catches(collection), lifetime) / CATCHES_PER_LEVEL)

static func catches_to_next_level(collection: Variant, lifetime: int = -1) -> int:
	var level := gather_level(collection, lifetime)
	if level >= MAX_GATHER_LEVEL:
		return 0
	return level * CATCHES_PER_LEVEL - maxi(total_catches(collection), lifetime)

static func lifetime_catches(state: Dictionary) -> int:
	return maxi(total_catches(state.get("herbarium", {})), int(state.get("herbarium_catches", 0)))

static func record(state: Dictionary, grade: String, roll: int = 0) -> Dictionary:
	if not GRADE_POOLS.has(grade):
		return {}
	if typeof(state.get("herbarium", {})) != TYPE_DICTIONARY:
		state.herbarium = {}
	var collection: Dictionary = state.herbarium
	var lifetime := lifetime_catches(state)
	var level := gather_level(collection, lifetime)
	var pool: Array = GRADE_POOLS[grade].filter(func(specimen_id): return int(LEVEL_UNLOCK.get(specimen_id, 1)) <= level)
	if pool.is_empty():
		pool = [GRADE_POOLS[grade][0]]
	var start := posmod(roll, pool.size())
	var specimen_id := str(pool[start])
	for offset in range(pool.size()):
		var candidate := str(pool[(start + offset) % pool.size()])
		if int(collection.get(candidate, 0)) <= 0:
			specimen_id = candidate
			break
	var first_discovery := int(collection.get(specimen_id, 0)) <= 0
	collection[specimen_id] = int(collection.get(specimen_id, 0)) + 1
	state.herbarium = collection
	state.herbarium_catches = lifetime + 1
	var new_level := gather_level(collection, lifetime + 1)
	var spec: Dictionary = SPECIMENS[specimen_id]
	return {
		"id": specimen_id,
		"name": str(spec.name),
		"rarity": str(spec.rarity),
		"description": str(spec.description),
		"first_discovery": first_discovery,
		"count": int(collection[specimen_id]),
		"xp": 2 if first_discovery else 0,
		"gather_level": new_level,
		"leveled_up": new_level > level,
		"catches_to_next_level": catches_to_next_level(collection, lifetime + 1)
	}

static func discovered_count(collection: Variant) -> int:
	if typeof(collection) != TYPE_DICTIONARY:
		return 0
	var total := 0
	for specimen_id in SPECIMENS:
		if int((collection as Dictionary).get(specimen_id, 0)) > 0:
			total += 1
	return total

static func collection_text(collection: Variant) -> String:
	var entries: Array[String] = []
	var safe_collection: Dictionary = collection if typeof(collection) == TYPE_DICTIONARY else {}
	for specimen_id in SPECIMENS:
		var spec: Dictionary = SPECIMENS[specimen_id]
		var count := int(safe_collection.get(specimen_id, 0))
		entries.append("%s×%d" % [str(spec.name), count])
	return " · ".join(entries)
