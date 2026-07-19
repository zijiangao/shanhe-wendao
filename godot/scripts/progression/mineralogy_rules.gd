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

static func record(state: Dictionary, grade: String, roll: int = 0) -> Dictionary:
	if not GRADE_POOLS.has(grade):
		return {}
	if typeof(state.get("mineralogy", {})) != TYPE_DICTIONARY:
		state.mineralogy = {}
	var collection: Dictionary = state.mineralogy
	var pool: Array = GRADE_POOLS[grade]
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
	var spec: Dictionary = SPECIMENS[specimen_id]
	return {
		"id": specimen_id,
		"name": str(spec.name),
		"rarity": str(spec.rarity),
		"description": str(spec.description),
		"first_discovery": first_discovery,
		"count": int(collection[specimen_id]),
		"silver": 2 if first_discovery else 0
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
		entries.append("%s×%d" % [str(spec.name), count] if count > 0 else "？？？")
	return " · ".join(entries)
