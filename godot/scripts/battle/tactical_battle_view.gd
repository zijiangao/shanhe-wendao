class_name TacticalBattleView
extends Control

const BATTLE_ENGINE := preload("res://scripts/battle/battle_engine.gd")

signal cell_selected(x: int, y: int)
signal mode_selected(mode: String)
signal end_turn_requested

const TOKEN_ATLAS := preload("res://assets/art/battle-tokens.png")
const LIN_TOKEN := preload("res://assets/art/portrait-lin-qingshuang.png")

func setup(background: Texture2D, battle: Dictionary, player: Dictionary, mode: String, cells: Array, enemy_preview: String) -> void:
	var art := TextureRect.new()
	art.texture = background
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var shade := ColorRect.new()
	shade.color = Color("#07110d55")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var title := Label.new()
	title.position = Vector2(30, 14)
	title.text = "%s  ·  第 %d 回合" % [battle.name, battle.turn]
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#f1e3c6"))
	add_child(title)
	var turn_banner := Label.new()
	turn_banner.position = Vector2(660, 14)
	turn_banner.size = Vector2(160, 36)
	turn_banner.text = "我 方 回 合"
	turn_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_banner.add_theme_font_size_override("font_size", 18)
	turn_banner.add_theme_color_override("font_color", Color("#d9f2e5"))
	turn_banner.add_theme_stylebox_override("normal", _box(Color("#27604b")))
	add_child(turn_banner)
	_animate_turn_banner(turn_banner)

	var board := GridContainer.new()
	board.columns = 8
	board.position = Vector2(30, 60)
	board.size = Vector2(790, 450)
	board.add_theme_constant_override("h_separation", 5)
	board.add_theme_constant_override("v_separation", 5)
	add_child(board)
	for data in cells:
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(94, 66)
		cell.text = str(data.text)
		cell.disabled = bool(data.disabled)
		cell.add_theme_font_size_override("font_size", 15)
		cell.add_theme_color_override("font_color", Color("#fff4dc"))
		cell.add_theme_stylebox_override("normal", _box(Color(data.color)))
		cell.add_theme_stylebox_override("focus", _box(Color(data.color).lightened(0.28)))
		cell.add_theme_stylebox_override("disabled", _box(Color(data.color)))
		var token_index: int = int(data.token)
		if token_index >= 0:
			cell.icon = _battle_token(token_index)
			cell.expand_icon = true
		cell.pressed.connect(_emit_cell.bind(int(data.x), int(data.y)))
		board.add_child(cell)

	if battle.has("effect") and not battle.effect.is_empty():
		var effect: Dictionary = battle.effect
		var effect_label := Label.new()
		effect_label.position = Vector2(30 + int(effect.x) * 99, 60 + int(effect.y) * 71)
		effect_label.size = Vector2(94, 66)
		effect_label.z_index = 5
		effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect_label.text = str(effect.text)
		effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		effect_label.add_theme_font_size_override("font_size", 22)
		effect_label.add_theme_color_override("font_color", Color("#fff0a8"))
		effect_label.add_theme_stylebox_override("normal", _box(Color("#a33127cc") if effect.type == "damage" else Color("#d4b34aaa")))
		add_child(effect_label)
		_animate_impact(effect_label, str(effect.get("type", "damage")) == "damage")
	if battle.has("skill_flash") and bool(battle.skill_flash):
		var skill_name := Label.new()
		skill_name.position = Vector2(250, 260)
		skill_name.size = Vector2(360, 64)
		skill_name.z_index = 6
		skill_name.text = "流 云 剑 法"
		skill_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		skill_name.add_theme_font_size_override("font_size", 30)
		skill_name.add_theme_color_override("font_color", Color("#fff2bd"))
		skill_name.add_theme_stylebox_override("normal", _box(Color("#315f4be8")))
		add_child(skill_name)
		_animate_skill_name(skill_name)

	var side := PanelContainer.new()
	side.position = Vector2(840, 60)
	side.size = Vector2(400, 478)
	side.add_theme_stylebox_override("panel", _box(Color("#14271ff2")))
	add_child(side)
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 10)
	side.add_child(side_box)
	var status := Label.new()
	var active_name: String = "林清霜" if str(battle.get("active_unit", "hero")) == "ally" else "沈羽"
	var active_hp: int = int(battle.ally.hp) if active_name == "林清霜" else int(player.hp)
	var active_max_hp: int = int(battle.ally.max_hp) if active_name == "林清霜" else int(player.max_hp)
	var qi_text: String = "真气 %d/%d · 护卫 %d" % [battle.ally.qi, battle.ally.max_qi, battle.ally.guard] if active_name == "林清霜" else "真气 %d/20" % player.qi
	status.text = "当前角色：%s    气血 %d/%d    %s\n共享行动点 %d/2    当前：%s\n目标：%s" % [active_name, active_hp, active_max_hp, qi_text, battle.ap, _mode_name(mode), BATTLE_ENGINE.objective_text(battle)]
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color("#f2dfb3"))
	side_box.add_child(status)
	var result := Label.new()
	result.text = "战况\n%s" % battle.result
	result.custom_minimum_size.y = 95
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", 16)
	result.add_theme_color_override("font_color", Color("#f4eee2"))
	result.add_theme_stylebox_override("normal", _box(Color("#21382f")))
	side_box.add_child(result)
	var preview := Label.new()
	preview.text = "敌方预判\n" + enemy_preview
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_theme_font_size_override("font_size", 14)
	preview.add_theme_color_override("font_color", Color("#e5c8b6"))
	side_box.add_child(preview)
	var action_grid := GridContainer.new()
	action_grid.columns = 2
	action_grid.add_theme_constant_override("h_separation", 8)
	action_grid.add_theme_constant_override("v_separation", 8)
	side_box.add_child(action_grid)
	var actions: Array = [["移动", "move"], ["普通攻击", "attack"]]
	if active_name == "林清霜":
		actions.append(["霜华刺 · 6真气", "frost_dash"])
		actions.append(["寒锋守势", "frost_guard"])
	else:
		actions.append(["流云剑法 · 8真气", "skill"])
		actions.append(["取消选择", "inspect"])
	for action in actions:
		var button := _action_button(action[0], Color("#8b493b") if mode == action[1] else Color("#315f4b"))
		button.custom_minimum_size.x = 174
		button.disabled = int(battle.ap) <= 0 and action[1] != "inspect" or (action[1] == "skill" and int(player.qi) < 8) or (action[1] == "frost_dash" and int(battle.ally.qi) < 6)
		button.pressed.connect(_emit_mode.bind(str(action[1])))
		action_grid.add_child(button)
	var end_button := _action_button("结束回合", Color("#806c4f"))
	end_button.custom_minimum_size.x = 174
	end_button.pressed.connect(func(): end_turn_requested.emit())
	action_grid.add_child(end_button)
	var help := Label.new()
	help.text = "移动：两格内，消耗1行动点\n普攻：相邻敌人，消耗1行动点\n流云剑法：同一直线三格，消耗1行动点"
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color("#cfc8b8"))
	side_box.add_child(help)

func _emit_cell(x: int, y: int) -> void:
	cell_selected.emit(x, y)

func _emit_mode(mode: String) -> void:
	mode_selected.emit(mode)

func _animate_turn_banner(banner: Control) -> void:
	banner.modulate.a = 0.0
	banner.position.y -= 8.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(banner, "modulate:a", 1.0, 0.16)
	tween.tween_property(banner, "position:y", banner.position.y + 8.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _animate_impact(label: Control, shake: bool) -> void:
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.45, 0.45)
	var impact := create_tween()
	impact.tween_interval(0.035)
	impact.tween_property(label, "scale", Vector2(1.18, 1.18), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact.tween_property(label, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if shake:
		var origin := position
		var camera_shake := create_tween()
		camera_shake.tween_property(self, "position", origin + Vector2(7, -3), 0.035)
		camera_shake.tween_property(self, "position", origin + Vector2(-5, 3), 0.045)
		camera_shake.tween_property(self, "position", origin + Vector2(3, -1), 0.04)
		camera_shake.tween_property(self, "position", origin, 0.05)

func _animate_skill_name(label: Control) -> void:
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.8, 0.8)
	label.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.12)

func _mode_name(mode: String) -> String:
	return {"move": "移动", "attack": "普通攻击", "skill": "流云剑法", "frost_dash": "霜华刺", "frost_guard": "寒锋守势", "inspect": "查看战场"}.get(mode, mode)

func _battle_token(index: int) -> Texture2D:
	if index == 4:
		return LIN_TOKEN
	var token := AtlasTexture.new()
	token.atlas = TOKEN_ATLAS
	var half: int = int(TOKEN_ATLAS.get_width() / 2.0)
	token.region = Rect2((index % 2) * half, int(index / 2.0) * half, half, half)
	return token

func _action_button(text_value: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("#f5ecd9"))
	button.add_theme_stylebox_override("normal", _box(color))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.12)))
	button.add_theme_stylebox_override("focus", _box(color.lightened(0.24)))
	return button

func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = color.lightened(0.18)
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
