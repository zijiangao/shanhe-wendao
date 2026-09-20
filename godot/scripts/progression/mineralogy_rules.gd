class_name MineralogyRules
extends RefCounted

const SPECIMENS := {
	"ironstone": {
		"name": "青铁石",
		"rarity": "寻常",
		"description": "质地坚韧，是淬炼寻常兵刃的根基。"
	},
	"silver_sand": {
		"name": "流银砂",
		"rarity": "少见",
		"description": "细砂映光如水，可令刃口更轻更利。"
	},
	"fire_copper": {
		"name": "赤火铜",
		"rarity": "珍稀",
		"description": "矿心余温不散，适合锻造承受真气的器胚。"
	},
	"star_marrow": {
		"name": "星陨髓",
		"rarity": "奇珍",
		"description": "陨铁深处凝成的银蓝结晶，落锤时声如清钟。"
	}
}

const GRADE_POOLS := {
	"C": ["ironstone"],
	"B": ["ironstone", "silver_sand"],
	"A": ["ironstone", "silver_sand", "fire_copper"],
	"S": ["ironstone", "silver_sand", "fire_copper", "star_marrow"]
}

## 挖矿等级 (0.117.0) -- 与 herbarium_rules.gd 的采药等级同构，独立于挖矿人
## 本身0-100级熟练度之外，矿物本身的1-10级"图鉴"进度，见该文件的注释。
const MAX_GATHER_LEVEL := 10
const CATCHES_PER_LEVEL := 3
const LEVEL_UNLOCK := {
	"ironstone": 1,
	"silver_sand": 4,
	"fire_copper": 7,
	"star_marrow": 10,
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
	return maxi(total_catches(state.get("mineralogy", {})), int(state.get("mineralogy_catches", 0)))

static func record(state: Dictionary, grade: String, roll: int = 0) -> Dictionary:
	if not GRADE_POOLS.has(grade):
		return {}
	if typeof(state.get("mineralogy", {})) != TYPE_DICTIONARY:
		state.mineralogy = {}
	var collection: Dictionary = state.mineralogy
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
	state.mineralogy = collection
	state.mineralogy_catches = lifetime + 1
	var new_level := gather_level(collection, lifetime + 1)
	var spec: Dictionary = SPECIMENS[specimen_id]
	return {
		"id": specimen_id,
		"name": str(spec.name),
		"rarity": str(spec.rarity),
		"description": str(spec.description),
		"first_discovery": first_discovery,
		"count": int(collection[specimen_id]),
		"silver": 2 if first_discovery else 0,
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
