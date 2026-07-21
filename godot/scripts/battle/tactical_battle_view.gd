class_name TacticalBattleView
extends Control

const BATTLE_ENGINE := preload("res://scripts/battle/battle_engine.gd")
const DIFFICULTY_RULES := preload("res://scripts/battle/difficulty_rules.gd")
const COMBAT_FEEDBACK := preload("res://scripts/battle/combat_feedback.gd")
const TRAINING_RULES := preload("res://scripts/progression/training_minigame_rules.gd")
const SPARRING_RULES := preload("res://scripts/progression/sparring_rules.gd")
const WUXUE_RULES := preload("res://scripts/progression/wuxue_rules.gd")
const UI_THEME := preload("res://scripts/ui/ui_theme.gd")

signal cell_selected(x: int, y: int)
signal mode_selected(mode: String)
signal end_turn_requested
signal presentation_finished

const TOKEN_ATLAS := preload("res://assets/art/battle-tokens.png")
const LIN_TOKEN := preload("res://assets/art/portrait-lin-qingshuang.png")

var presentation_active: bool = false

func setup(background: Texture2D, battle: Dictionary, player: Dictionary, mode: String, cells: Array, enemy_preview: String, scene_style: Dictionary = {}) -> void:
	var art := TextureRect.new()
	art.texture = background
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(str(scene_style.get("shade", "#07110d55")))
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var title := Label.new()
	title.position = Vector2(30, 14)
	title.text = "%s  ·  %s难度  ·  第 %d 回合" % [scene_style.get("title", battle.name), DIFFICULTY_RULES.display_name(str(battle.get("difficulty", "standard"))), battle.turn]
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
	turn_banner.add_theme_stylebox_override("normal", _box(Color(str(scene_style.get("accent", "#27604b")))))
	add_child(turn_banner)
	var static_capture := bool(scene_style.get("static_capture", false))
	if not static_capture:
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

	var effects: Array = battle.get("effects", [])
	if effects.is_empty() and battle.has("effect") and not battle.effect.is_empty():
		effects = [battle.effect]
	for effect: Dictionary in effects:
		var effect_label := Label.new()
		effect_label.position = Vector2(34 + int(effect.x) * 99, 48 + int(effect.y) * 71)
		effect_label.size = Vector2(86, 34)
		effect_label.z_index = 5
		effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect_label.text = str(effect.text)
		effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		effect_label.add_theme_font_size_override("font_size", 18)
		effect_label.add_theme_color_override("font_color", Color("#fff0a8"))
		effect_label.add_theme_stylebox_override("normal", _box(Color("#a33127e8") if effect.type == "damage" else Color("#315f4be8")))
		add_child(effect_label)
		if not static_capture:
			_play_impact_feedback(effect_label, COMBAT_FEEDBACK.for_player_effect(effect))
	if battle.has("skill_flash") and bool(battle.skill_flash):
		var skill_name := Label.new()
		skill_name.position = Vector2(250, 260)
		skill_name.size = Vector2(360, 64)
		skill_name.z_index = 6
		skill_name.text = str(battle.get("skill_name", "流 云 剑 法"))
		skill_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		skill_name.add_theme_font_size_override("font_size", 30)
		skill_name.add_theme_color_override("font_color", Color("#fff2bd"))
		skill_name.add_theme_stylebox_override("normal", _box(Color("#315f4be8")))
		add_child(skill_name)
		if not static_capture:
			_animate_skill_name(skill_name)

	var side := PanelContainer.new()
	side.position = Vector2(840, 60)
	side.size = Vector2(400, 540)
	side.add_theme_stylebox_override("panel", _box(Color("#14271ff2")))
	add_child(side)
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 4)
	side.add_child(side_box)
	var status := Label.new()
	var active_name: String = "林清霜" if str(battle.get("active_unit", "hero")) == "ally" else "沈羽"
	var active_hp: int = int(battle.ally.hp) if active_name == "林清霜" else int(player.hp)
	var active_max_hp: int = int(battle.ally.max_hp) if active_name == "林清霜" else int(player.max_hp)
	var qi_text: String = "真气 %d/%d · 护卫 %d" % [battle.ally.qi, battle.ally.max_qi, battle.ally.guard] if active_name == "林清霜" else "真气 %d/20 · 护体 %d" % [player.qi, int(battle.get("hero_guard", 0))]
	status.text = "当前角色：%s    气血 %d/%d    %s\n共享行动点 %d/2    当前：%s\n目标：%s" % [active_name, active_hp, active_max_hp, qi_text, battle.ap, _mode_name(mode), BATTLE_ENGINE.objective_text(battle)]
	if str(battle.get("battle_id", "")) == "qingyun_spar":
		status.text += "\n演武课题：%s · 兵器方向：%s" % [battle.get("name", "青云切磋"), SPARRING_RULES.discipline_name(str(battle.get("discipline", "swordsmanship")))]
	status.add_theme_font_size_override("font_size", 17)
	status.add_theme_color_override("font_color", Color("#f2dfb3"))
	side_box.add_child(status)
	var result := Label.new()
	result.text = "战况\n%s" % battle.result
	result.custom_minimum_size.y = 70
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", 16)
	result.add_theme_color_override("font_color", Color("#f4eee2"))
	result.add_theme_stylebox_override("normal", _box(Color("#21382f")))
	side_box.add_child(result)
	var preview := Label.new()
	preview.text = "敌方预判\n" + enemy_preview
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_theme_font_size_override("font_size", 13)
	preview.add_theme_color_override("font_color", Color("#e5c8b6"))
	side_box.add_child(preview)
	var action_grid := GridContainer.new()
	action_grid.columns = 2
	action_grid.add_theme_constant_override("h_separation", 8)
	action_grid.add_theme_constant_override("v_separation", 6)
	side_box.add_child(action_grid)
	var actions: Array = [["移动", "move"], ["普通攻击", "attack"]]
	if active_name == "林清霜":
		actions.append(["霜华刺 · 6真气", "frost_dash"])
		actions.append(["寒锋守势", "frost_guard"])
	else:
		var qi_cost := TRAINING_RULES.cloud_qi_cost(int(player.get("swordsmanship", 0)))
		actions.append(["流云剑法 · %d真气" % qi_cost, "skill"])
		actions.append(["断岳刀法 · %d真气" % BATTLE_ENGINE.BLADE_QI_COST, "blade_skill"])
		var equipped_moves: Array = player.get("equipped_moves", [])
		if "stone_splitting_fist" in equipped_moves:
			actions.append(["裂石拳 · %d真气" % BATTLE_ENGINE.STONE_FIST_QI_COST, "stone_splitting_fist"])
		if "night_triple_blade" in equipped_moves:
			actions.append(["暗夜三刀 · %d真气" % BATTLE_ENGINE.NIGHT_BLADE_QI_COST, "night_triple_blade"])
		actions.append(["运气护体 · 回3气", "brace"])
		actions.append(["回春散 · 回%d" % BATTLE_ENGINE.healing_amount(player), "heal"])
		actions.append(["霹雳石 ×%d" % int(player.get("consumables", {}).get("thunder_stone", 0)), "thunder_stone"])
		actions.append(["取消选择", "inspect"])
	for action in actions:
		var button := _action_button(action[0], Color("#8b493b") if mode == action[1] else Color("#315f4b"))
		button.custom_minimum_size.x = 174
		button.disabled = int(battle.ap) <= 0 and action[1] != "inspect" or (action[1] == "skill" and int(player.qi) < TRAINING_RULES.cloud_qi_cost(int(player.get("swordsmanship", 0)))) or (action[1] == "blade_skill" and int(player.qi) < BATTLE_ENGINE.BLADE_QI_COST) or (action[1] == "frost_dash" and int(battle.ally.qi) < 6) or (action[1] == "heal" and (int(player.get("consumables", {}).get("healing_powder", 0)) <= 0 or int(player.hp) >= int(player.max_hp))) or (action[1] == "thunder_stone" and int(player.get("consumables", {}).get("thunder_stone", 0)) <= 0) or (action[1] == "stone_splitting_fist" and int(player.qi) < BATTLE_ENGINE.STONE_FIST_QI_COST) or (action[1] == "night_triple_blade" and int(player.qi) < BATTLE_ENGINE.NIGHT_BLADE_QI_COST)
		button.pressed.connect(_emit_mode.bind(str(action[1])))
		action_grid.add_child(button)
	var end_button := _action_button("结束回合", Color("#806c4f"))
	end_button.custom_minimum_size.x = 174
	end_button.pressed.connect(func(): end_turn_requested.emit())
	action_grid.add_child(end_button)
	var help := Label.new()
	help.text = BATTLE_ENGINE.hero_action_help(player) if active_name == "沈羽" else "霜华刺：突进两格并攻击 · 消耗6真气\n寒锋守势：获得护卫并恢复3真气 · 均消耗1行动点"
	help.add_theme_font_size_override("font_size", 10)
	help.add_theme_color_override("font_color", Color("#cfc8b8"))
	side_box.add_child(help)

func _emit_cell(x: int, y: int) -> void:
	cell_selected.emit(x, y)

func _emit_mode(mode: String) -> void:
	mode_selected.emit(mode)

func play_enemy_events(events: Array) -> void:
	if presentation_active:
		return
	presentation_active = true
	var blocker := ColorRect.new()
	blocker.color = Color("#100b09aa")
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.z_index = 20
	add_child(blocker)
	var turn_label := _presentation_label("敌 方 回 合", Vector2(480, 16), Vector2(300, 48), Color("#8b493bee"), 24)
	turn_label.z_index = 21
	add_child(turn_label)
	var instant := DisplayServer.get_name() == "headless"
	if not instant:
		await get_tree().create_timer(0.28).timeout
	for event: Dictionary in events:
		await _play_enemy_event(event, instant)
	if not instant:
		await get_tree().create_timer(0.12).timeout
	blocker.queue_free()
	turn_label.queue_free()
	presentation_active = false
	presentation_finished.emit()

func _play_enemy_event(event: Dictionary, instant: bool = false) -> void:
	match str(event.get("type", "")):
		"move":
			var from_cell: Vector2i = event.get("from", Vector2i.ZERO)
			var to_cell: Vector2i = event.get("to", from_cell)
			var marker := _presentation_label(str(event.get("actor", "敌人")), _cell_overlay_position(from_cell), Vector2(94, 44), Color("#71322dee"), 16)
			marker.z_index = 22
			add_child(marker)
			AudioFeedback.play("move")
			if instant:
				marker.position = _cell_overlay_position(to_cell)
			else:
				var movement := create_tween()
				movement.tween_property(marker, "position", _cell_overlay_position(to_cell), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
				await movement.finished
			marker.queue_free()
		"attack":
			var position: Vector2i = event.get("position", Vector2i.ZERO)
			var attack_label := _presentation_label("%s · %s" % [event.get("actor", "敌人"), event.get("text", "发动攻击")], _cell_overlay_position(position) + Vector2(-18, -38), Vector2(130, 36), Color("#8b493bee"), 15)
			attack_label.z_index = 22
			add_child(attack_label)
			AudioFeedback.play("turn")
			if not instant:
				await get_tree().create_timer(0.24).timeout
			attack_label.queue_free()
		"hit":
			var target: Vector2i = event.get("target", Vector2i.ZERO)
			var damage := int(event.get("damage", 0))
			var blocked := int(event.get("blocked", 0))
			var hit_text := "格挡" if damage <= 0 and blocked > 0 else "-%d" % damage
			if damage > 0 and blocked > 0:
				hit_text += "  挡%d" % blocked
			var hit_label := _presentation_label(hit_text, _cell_overlay_position(target) + Vector2(4, -8), Vector2(86, 38), Color("#315f4bee") if damage <= 0 else Color("#a33127ee"), 19)
			hit_label.z_index = 23
			add_child(hit_label)
			var feedback := COMBAT_FEEDBACK.for_enemy_hit(event)
			AudioFeedback.play(str(feedback.cue), float(feedback.pitch))
			if not instant:
				_play_impact_feedback(hit_label, feedback)
				await get_tree().create_timer(0.28).timeout
			hit_label.queue_free()
		"technique":
			var technique := _presentation_label(str(event.get("text", "敌方绝技")), Vector2(370, 245), Vector2(520, 68), Color("#7d3029f2"), 28)
			technique.z_index = 23
			add_child(technique)
			AudioFeedback.play("skill")
			if not instant:
				_animate_skill_name(technique)
				await get_tree().create_timer(0.38).timeout
			technique.queue_free()

func _cell_overlay_position(cell: Vector2i) -> Vector2:
	return Vector2(30 + cell.x * 99, 71 + cell.y * 71)

func _presentation_label(text_value: String, at: Vector2, dimensions: Vector2, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#fff0c6"))
	label.add_theme_stylebox_override("normal", _box(color))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _animate_turn_banner(banner: Control) -> void:
	banner.modulate.a = 0.0
	banner.position.y -= 8.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(banner, "modulate:a", 1.0, 0.16)
	tween.tween_property(banner, "position:y", banner.position.y + 8.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _play_impact_feedback(label: Control, feedback: Dictionary) -> void:
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.45, 0.45)
	var impact := create_tween()
	impact.tween_interval(0.035)
	impact.tween_property(label, "scale", Vector2(1.18, 1.18), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact.tween_property(label, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _combat_flashes_enabled() and float(feedback.get("flash_alpha", 0.0)) > 0.0:
		var flash := ColorRect.new()
		flash.color = Color(str(feedback.get("flash", "#ffffff")), float(feedback.flash_alpha))
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.z_index = 22
		add_child(flash)
		var flash_tween := create_tween()
		flash_tween.tween_property(flash, "modulate:a", 0.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flash_tween.tween_callback(flash.queue_free)
	var shake_amount := float(feedback.get("shake", 0.0))
	if _screen_shake_enabled() and shake_amount > 0.0:
		var origin := position
		var camera_shake := create_tween()
		camera_shake.tween_property(self, "position", origin + Vector2(shake_amount, -shake_amount * 0.42), 0.035)
		camera_shake.tween_property(self, "position", origin + Vector2(-shake_amount * 0.72, shake_amount * 0.38), 0.045)
		camera_shake.tween_property(self, "position", origin + Vector2(shake_amount * 0.38, -shake_amount * 0.16), 0.04)
		camera_shake.tween_property(self, "position", origin, 0.05)

func _screen_shake_enabled() -> bool:
	var settings := get_tree().root.get_node_or_null("SettingsManager")
	return settings == null or bool(settings.data.get("screen_shake", true))

func _combat_flashes_enabled() -> bool:
	var settings := get_tree().root.get_node_or_null("SettingsManager")
	return settings == null or bool(settings.data.get("combat_flashes", true))

func _animate_skill_name(label: Control) -> void:
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.8, 0.8)
	label.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.12)

func _mode_name(mode: String) -> String:
	return {"move": "移动", "attack": "普通攻击", "skill": "流云剑法", "blade_skill": "断岳刀法", "thunder_stone": "霹雳石", "brace": "运气护体", "frost_dash": "霜华刺", "frost_guard": "寒锋守势", "stone_splitting_fist": "裂石拳", "night_triple_blade": "暗夜三刀", "inspect": "查看战场"}.get(mode, mode)

func _battle_token(index: int) -> Texture2D:
	if index == 4:
		return LIN_TOKEN
	var token := AtlasTexture.new()
	token.atlas = TOKEN_ATLAS
	var half: int = int(TOKEN_ATLAS.get_width() / 2.0)
	token.region = Rect2((index % 2) * half, int(index / 2.0) * half, half, half)
	return token

func _action_button(text_value: String, color: Color) -> Button:
	var button := UI_THEME.action_button(text_value, color)
	button.custom_minimum_size.y = 42
	return button

func _box(color: Color) -> StyleBoxFlat:
	return UI_THEME.box(color)
