class_name BattleRules
extends RefCounted

static func enemy_at(battle: Dictionary, cell: Vector2i) -> int:
	for index in range(battle.enemies.size()):
		var enemy: Dictionary = battle.enemies[index]
		if int(enemy.hp) > 0 and Vector2i(int(enemy.x), int(enemy.y)) == cell:
			return index
	return -1

static func is_ally_at(battle: Dictionary, cell: Vector2i) -> bool:
	return battle.has("ally") and not battle.ally.is_empty() and int(battle.ally.hp) > 0 and Vector2i(int(battle.ally.x), int(battle.ally.y)) == cell

static func active_position(battle: Dictionary) -> Vector2i:
	if str(battle.get("active_unit", "hero")) == "ally" and battle.has("ally") and int(battle.ally.hp) > 0:
		return Vector2i(int(battle.ally.x), int(battle.ally.y))
	return Vector2i(int(battle.player_x), int(battle.player_y))

static func set_active_position(battle: Dictionary, cell: Vector2i) -> void:
	if str(battle.get("active_unit", "hero")) == "ally" and battle.has("ally"):
		battle.ally.x = cell.x
		battle.ally.y = cell.y
	else:
		battle.player_x = cell.x
		battle.player_y = cell.y

static func is_blocked(battle: Dictionary, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= int(battle.width) or cell.y >= int(battle.height):
		return true
	for point in battle.blocked:
		if Vector2i(int(point[0]), int(point[1])) == cell:
			return true
	return false

static func is_occupied(battle: Dictionary, cell: Vector2i) -> bool:
	return enemy_at(battle, cell) >= 0 or is_ally_at(battle, cell) or Vector2i(int(battle.player_x), int(battle.player_y)) == cell

static func can_move_to(battle: Dictionary, cell: Vector2i) -> bool:
	if is_blocked(battle, cell) or is_occupied(battle, cell):
		return false
	var path := find_path(battle, active_position(battle), cell, false)
	return path.size() >= 2 and path.size() <= 3

static func can_attack_cell(battle: Dictionary, cell: Vector2i, skill: bool, hero_qi: int) -> bool:
	if enemy_at(battle, cell) < 0:
		return false
	var delta := cell - active_position(battle)
	var distance := absi(delta.x) + absi(delta.y)
	if skill:
		return str(battle.get("active_unit", "hero")) != "ally" and distance <= 3 and hero_qi >= 8 and has_clear_line(battle, active_position(battle), cell)
	return distance == 1

static func can_enemy_attack(battle: Dictionary, enemy: Dictionary, target: Vector2i) -> bool:
	var origin := Vector2i(int(enemy.x), int(enemy.y))
	var distance := absi(target.x - origin.x) + absi(target.y - origin.y)
	var attack_range := maxi(1, int(enemy.get("range", 1)))
	if distance > attack_range:
		return false
	return distance == 1 or has_clear_line(battle, origin, target)

static func enemy_target(battle: Dictionary, enemy: Dictionary) -> Dictionary:
	var enemy_position := Vector2i(int(enemy.x), int(enemy.y))
	var hero_target := Vector2i(int(battle.player_x), int(battle.player_y))
	var best := {"position": hero_target, "is_ally": false, "name": "沈羽"}
	if not battle.has("ally") or int(battle.ally.hp) <= 0:
		return best
	var ally_target := Vector2i(int(battle.ally.x), int(battle.ally.y))
	var hero_attackable := can_enemy_attack(battle, enemy, hero_target)
	var ally_attackable := can_enemy_attack(battle, enemy, ally_target)
	if ally_attackable and not hero_attackable:
		return {"position": ally_target, "is_ally": true, "name": str(battle.ally.name)}
	if hero_attackable and not ally_attackable:
		return best
	if absi(ally_target.x - enemy_position.x) + absi(ally_target.y - enemy_position.y) < absi(hero_target.x - enemy_position.x) + absi(hero_target.y - enemy_position.y):
		return {"position": ally_target, "is_ally": true, "name": str(battle.ally.name)}
	return best

static func has_clear_line(battle: Dictionary, from: Vector2i, to: Vector2i) -> bool:
	var delta := to - from
	if delta.x != 0 and delta.y != 0:
		return false
	var direction := Vector2i(signi(delta.x), signi(delta.y))
	var steps := absi(delta.x) + absi(delta.y)
	for step in range(1, steps):
		var cursor := from + direction * step
		if is_blocked(battle, cursor) or is_occupied(battle, cursor):
			return false
	return true

static func can_frost_dash(battle: Dictionary, cell: Vector2i) -> bool:
	if str(battle.get("active_unit", "hero")) != "ally" or enemy_at(battle, cell) < 0 or int(battle.ally.qi) < 6:
		return false
	var start := Vector2i(int(battle.ally.x), int(battle.ally.y))
	if absi(cell.x - start.x) + absi(cell.y - start.y) > 2:
		return false
	var path := find_path(battle, start, cell, true)
	return path.size() >= 2 and path.size() <= 3

static func find_path(battle: Dictionary, start: Vector2i, goal: Vector2i, allow_goal_occupied: bool) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == goal:
			break
		for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next: Vector2i = current + direction
			if came_from.has(next) or is_blocked(battle, next):
				continue
			if is_occupied(battle, next) and not (allow_goal_occupied and next == goal):
				continue
			came_from[next] = current
			frontier.append(next)
	if not came_from.has(goal):
		return []
	var path: Array[Vector2i] = [goal]
	var cursor := goal
	while cursor != start:
		cursor = came_from[cursor]
		path.push_front(cursor)
	return path

static func enemy_preview(battle: Dictionary) -> String:
	var lines: PackedStringArray = []
	for enemy in battle.enemies:
		if int(enemy.hp) <= 0:
			continue
		var target_data := enemy_target(battle, enemy)
		var target: Vector2i = target_data.position
		var target_name: String = target_data.name
		var can_attack := can_enemy_attack(battle, enemy, target)
		lines.append("· %s：%s%s" % [enemy.name, "准备远程攻击" if can_attack and int(enemy.get("range", 1)) > 1 else ("准备攻击" if can_attack else "向"), target_name if can_attack else target_name + "接近"])
	return "\n".join(lines)
