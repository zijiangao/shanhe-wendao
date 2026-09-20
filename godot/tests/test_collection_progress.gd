extends SceneTree

const HERBS := preload("res://scripts/progression/herbarium_rules.gd")
const MINERALS := preload("res://scripts/progression/mineralogy_rules.gd")
const CRAFT := preload("res://scripts/progression/crafting_rules.gd")

func _initialize() -> void:
	var game := root.get_node("GameState")
	game.new_game()
	game.data.materials = {"herbs": 100, "ore": 100}
	game.data.herbarium = {"dewgrass": 8, "cloudleaf": 1}
	game.data.mineralogy = {"ironstone": 8, "silver_sand": 1}
	assert(CRAFT.apply(game.data, "insight_pill"))
	assert(CRAFT.apply(game.data, "twin_edge_saber"))
	assert(int(game.data.herbarium.cloudleaf) == 0 and int(game.data.mineralogy.silver_sand) == 0)
	var saved: Dictionary = game.data.duplicate(true)
	assert(game.import_data(saved))
	assert(HERBS.gather_level(game.data.herbarium, HERBS.lifetime_catches(game.data)) == 4)
	assert(MINERALS.gather_level(game.data.mineralogy, MINERALS.lifetime_catches(game.data)) == 4)
	assert(HERBS.record(game.data, "S", 1).id == "cloudleaf", "Used ingredients must not relock rare herbs.")
	assert(MINERALS.record(game.data, "S", 1).id == "silver_sand", "Used ingredients must not relock rare minerals.")
	assert(int(game.data.herbarium_catches) == 10 and int(game.data.mineralogy_catches) == 10)
	print("Collection progress tests passed.")
	quit()
