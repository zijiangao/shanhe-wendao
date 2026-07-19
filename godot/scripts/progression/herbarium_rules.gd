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

static func record(state: Dictionary, grade: String, roll: int = 0) -> Dictionary:
	if not GRADE_POOLS.has(grade):
		return {}
	if typeof(state.get("herbarium", {})) != TYPE_DICTIONARY:
		state.herbarium = {}
	var collection: Dictionary = state.herbarium
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
	state.herbarium = collection
	var spec: Dictionary = SPECIMENS[specimen_id]
	return {
		"id": specimen_id,
		"name": str(spec.name),
		"rarity": str(spec.rarity),
		"description": str(spec.description),
		"first_discovery": first_discovery,
		"count": int(collection[specimen_id]),
		"xp": 2 if first_discovery else 0
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
