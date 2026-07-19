extends Control

const MAP_TEXTURE := preload("res://assets/art/jianghu-world-map.png")
const BATTLE_TEXTURE := preload("res://assets/art/luoyang-battle-rain.png")
const QINGYUN_TEXTURE := preload("res://assets/art/locations/qingyun-courtyard.png")
const LUOYANG_TEXTURE := preload("res://assets/art/locations/luoyang-market.png")
const HUASHAN_TEXTURE := preload("res://assets/art/locations/huashan-terrace.png")
const EMEI_TEXTURE := preload("res://assets/art/locations/emei-summit.png")
const HERO_TEXTURE := preload("res://assets/art/portrait-shen-yu.png")
const TOKEN_ATLAS := preload("res://assets/art/battle-tokens.png")
const DIALOGUE_VIEW := preload("res://scenes/ui/dialogue_view.tscn")
const CHOICE_VIEW := preload("res://scenes/ui/choice_view.tscn")
const WORLD_MAP_VIEW := preload("res://scenes/world/world_map_view.tscn")
const LOCATION_VIEW := preload("res://scenes/world/location_view.tscn")
const TACTICAL_BATTLE_VIEW := preload("res://scenes/battle/tactical_battle_view.tscn")
const BATTLE_RULES := preload("res://scripts/battle/battle_rules.gd")
const BATTLE_ENGINE := preload("res://scripts/battle/battle_engine.gd")
const NAVIGATION_RULES := preload("res://scripts/ui/navigation_rules.gd")
const TUTORIAL_RULES := preload("res://scripts/ui/tutorial_rules.gd")
const DEMO_POLICY := preload("res://scripts/release/demo_policy.gd")
const DIFFICULTY_RULES := preload("res://scripts/battle/difficulty_rules.gd")
const STORE_CAPTURE_SPEC := preload("res://scripts/release/store_capture_spec.gd")
const CREDITS_PATH := "res://data/credits.json"

var screen: String = "menu"
var previous_screen: String = "menu"
var content: Control
var status_label: Label
var toast_label: Label
var battle_mode: String = "move"
var last_rewards: Dictionary = {}
var dialogue_event: String = ""
var dialogue_index: int = 0
var dialogue_entries: Array = []
var dialogue_return_screen: String = "location"
var choice_event: String = ""
var choice_prompt: String = ""
var choice_options: Array = []
var active_tutorial_step: String = ""
var last_defeat_battle: String = ""
var store_capture_active: bool = false

func _ready() -> void:
	if _handle_release_mode_verification():
		return
	GameState.state_changed.connect(_on_state_changed)
	GameState.battle_started.connect(func(): screen = "battle"; _rebuild())
	SteamService.achievement_unlocked.connect(_on_achievement_unlocked)
	_build_shell()
	_show_menu()
	if "--capture-store-screenshots" in OS.get_cmdline_user_args():
		call_deferred("_capture_store_screenshots")

func _handle_release_mode_verification() -> bool:
	var arguments := OS.get_cmdline_user_args()
	var expected_demo := "--verify-demo-build" in arguments
	var expected_full := "--verify-full-build" in arguments
	var verify_credits := "--verify-release-credits" in arguments
	if verify_credits:
		var credits_valid := FileAccess.file_exists(CREDITS_PATH) and FileAccess.file_exists("res://ASSET_PROVENANCE.md") and FileAccess.file_exists("res://THIRD_PARTY_NOTICES.md")
		if not credits_valid:
			push_error("Release credits or legal notices are missing from the package.")
		get_tree().quit(0 if credits_valid else 3)
		return true
	if not expected_demo and not expected_full:
		return false
	var valid := DEMO_POLICY.is_demo_build() if expected_demo else not DEMO_POLICY.is_demo_build()
	if not valid:
		push_error("Release mode verification failed.")
	get_tree().quit(0 if valid else 2)
	return true

func _capture_store_screenshots() -> void:
	store_capture_active = true
	get_window().size = STORE_CAPTURE_SPEC.OUTPUT_SIZE
	var output_path := ProjectSettings.globalize_path(STORE_CAPTURE_SPEC.OUTPUT_DIRECTORY)
	DirAccess.make_dir_recursive_absolute(output_path)

	GameState.new_game()
	GameState.data.quest_stage = "emei_trial"
	GameState.data.location = "qingyun"
	GameState.data.companions = ["lin_qingshuang"]
	GameState.data.faction_relations.huashan = 3
	GameState.data.faction_relations.emei = 3
	screen = "map"
	_rebuild()
	await _save_store_capture("world_map")

	GameState.new_game()
	GameState.data.quest_stage = "investigate"
	GameState.data.location = "blackreed"
	GameState.data.investigations = ["secret_route", "archer"]
	screen = "location"
	_rebuild()
	await _save_store_capture("blackreed_investigation")

	GameState.data.energy = 3
	GameState.start_blackreed_battle()
	battle_mode = "move"
	screen = "battle"
	_rebuild()
	await _save_store_capture("blackreed_tactics")

	var battle: Dictionary = GameState.data.battle
	battle.enemies[0].x = 1
	battle.enemies[0].y = 1
	BATTLE_ENGINE.player_action(battle, GameState.data, "skill", Vector2i(1, 1), RandomNumberGenerator.new())
	battle_mode = "inspect"
	_rebuild()
	await _save_store_capture("skill_impact")

	GameState.new_game()
	GameState.data.energy = 3
	GameState.data.location = "huashan"
	GameState.data.quest_stage = "huashan_trial"
	GameState.data.companions = ["lin_qingshuang"]
	GameState.start_huashan_trial_battle()
	battle_mode = "move"
	screen = "battle"
	_rebuild()
	await _save_store_capture("huashan_companion")

	GameState.new_game()
	GameState.data.location = "luoyang"
	GameState.data.quest_stage = "chapter_complete"
	choice_event = "baima_route"
	choice_prompt = "太守府夜宴，你准备如何取得武库名录？"
	choice_options = [
		["侠义 · 公开赴宴", "以青云门弟子身份登门，保护席间无辜之人。", "heroism"],
		["谋略 · 易容潜入", "伪装成账房，避开正面冲突寻找密库。", "strategy"],
		["威势 · 持令问罪", "以玄铁令震慑守卫，迫使太守当面对质。", "authority"]
	]
	screen = "choice"
	_rebuild()
	await _save_store_capture("luoyang_choice")

	print("Store screenshots saved to: %s" % output_path)
	get_tree().quit(0)

func _save_store_capture(id: String) -> void:
	toast_label.text = ""
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != STORE_CAPTURE_SPEC.OUTPUT_SIZE:
		image.resize(STORE_CAPTURE_SPEC.OUTPUT_SIZE.x, STORE_CAPTURE_SPEC.OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var filename := STORE_CAPTURE_SPEC.filename_for(id)
	var result := image.save_png("%s/%s" % [STORE_CAPTURE_SPEC.OUTPUT_DIRECTORY, filename])
	if result != OK:
		push_error("Failed to save store screenshot: %s" % filename)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	var action: Dictionary = NAVIGATION_RULES.back_action(screen, previous_screen)
	if bool(action.allowed):
		screen = str(action.target)
		_rebuild()
	elif str(action.message) != "":
		AudioFeedback.play("error")
		_toast(str(action.message))
	get_viewport().set_input_as_handled()

func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = Color("#ddd5c3")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var header_panel := PanelContainer.new()
	header_panel.custom_minimum_size.y = 70
	header_panel.add_theme_stylebox_override("panel", _box(Color("#14271f")))
	root.add_child(header_panel)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header_panel.add_child(header)

	var brand := Label.new()
	brand.text = "  山河问道  ·  两年江湖录"
	if DEMO_POLICY.is_demo_build():
		brand.text += "  ·  试玩版"
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_theme_font_size_override("font_size", 20)
	brand.add_theme_color_override("font_color", Color("#eadfc7"))
	header.add_child(brand)

	for pair in [["天下舆图", "map"], ["任务", "quests"], ["人物", "character"], ["成就", "achievements"], ["存档", "save"], ["设置", "settings"]]:
		var button := Button.new()
		button.text = pair[0]
		button.flat = true
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", Color("#d8d0bd"))
		button.add_theme_color_override("font_hover_color", Color("#ffffff"))
		button.add_theme_color_override("font_pressed_color", Color("#dfbf74"))
		button.pressed.connect(_switch_screen.bind(pair[1]))
		header.add_child(button)
	if OS.is_debug_build():
		var dev_button := Button.new()
		dev_button.text = "开发"
		dev_button.flat = true
		dev_button.add_theme_font_size_override("font_size", 16)
		dev_button.add_theme_color_override("font_color", Color("#dfbf74"))
		dev_button.pressed.connect(_switch_screen.bind("dev"))
		header.add_child(dev_button)

	status_label = Label.new()
	status_label.custom_minimum_size.x = 180
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("#dfbf74"))
	header.add_child(status_label)

	content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	toast_label = Label.new()
	toast_label.custom_minimum_size.y = 34
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_color", Color("#eee5d3"))
	toast_label.add_theme_stylebox_override("normal", _box(Color("#263a31")))
	root.add_child(toast_label)

func _show_menu() -> void:
	screen = "menu"
	_clear_content()
	var art := TextureRect.new()
	art.texture = MAP_TEXTURE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(art)

	var shade := ColorRect.new()
	shade.color = Color("#09130dbb")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(shade)

	var panel := VBoxContainer.new()
	panel.position = Vector2(95, 100)
	panel.size = Vector2(410, 430)
	panel.add_theme_constant_override("separation", 14)
	content.add_child(panel)

	var title := Label.new()
	title.text = "山河问道"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#f2e5c8"))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "两年之约 · 一纸玄铁令\n拜入青云，行走江湖，在厉千秋出关前阻止大劫。"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#c9c7bc"))
	panel.add_child(subtitle)

	var new_button := _action_button("开启新的江湖", Color("#9f4032"))
	new_button.pressed.connect(func(): GameState.new_game(); SaveManager.save_auto(); _switch_screen("map"))
	panel.add_child(new_button)

	var continue_button := _action_button("继续自动存档", Color("#315746"))
	continue_button.disabled = not FileAccess.file_exists(SaveManager.AUTO_PATH)
	continue_button.pressed.connect(_continue_auto_save)
	panel.add_child(continue_button)

	var hint := Label.new()
	hint.text = "试玩章：青云门 → 黑苇渡 → 黑苇寨之战" if DEMO_POLICY.is_demo_build() else "江湖路：青云 → 洛阳 → 华山 → 峨眉"
	hint.add_theme_color_override("font_color", Color("#aeb8b0"))
	panel.add_child(hint)
	var credits_button := _action_button("制作名单与版权", Color("#485e54"))
	credits_button.pressed.connect(_switch_screen.bind("credits"))
	panel.add_child(credits_button)
	var quit_button := _action_button("退出游戏", Color("#68433d"))
	quit_button.pressed.connect(func(): get_tree().quit())
	panel.add_child(quit_button)
	_update_status()
	call_deferred("_focus_first_content_control")

func _switch_screen(next: String) -> void:
	if next != "menu" and screen == "menu" and GameState.data.is_empty():
		GameState.new_game()
	if next in NAVIGATION_RULES.OVERLAY_SCREENS:
		previous_screen = screen
	screen = next
	_rebuild()

func _rebuild() -> void:
	SteamService.evaluate_state(GameState.data)
	if DEMO_POLICY.should_redirect_screen(screen, GameState.data):
		screen = "demo_complete"
	match screen:
		"menu": _show_menu()
		"map": _show_map()
		"location": _show_location()
		"quests": _show_quests()
		"dialogue": _show_dialogue()
		"choice": _show_choice()
		"palace": _show_palace()
		"dev": _show_dev_menu()
		"character": _show_character()
		"save": _show_saves()
		"settings": _show_settings()
		"achievements": _show_achievements()
		"credits": _show_credits()
		"battle": _show_battle()
		"victory": _show_victory()
		"defeat": _show_defeat()
		"final_choice": _show_final_choice()
		"ending": _show_ending()
		"demo_complete": _show_demo_complete()
	_update_status()
	_show_contextual_tutorial()
	call_deferred("_focus_first_content_control")

func _focus_first_content_control() -> void:
	if content == null:
		return
	var controls := content.find_children("*", "Control", true, false)
	for node in controls:
		var control := node as Control
		if control == null or control.is_queued_for_deletion() or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
			continue
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		control.grab_focus()
		return

func _show_map() -> void:
	_clear_content()
	var places: Array[String] = ["qingyun", "blackreed"]
	if _luoyang_unlocked():
		places.append("luoyang")
	if _huashan_unlocked():
		places.append("huashan")
	if _emei_unlocked():
		places.append("emei")
	var view: WorldMapView = WORLD_MAP_VIEW.instantiate()
	content.add_child(view)
	view.setup(MAP_TEXTURE, GameState.data, _quest_objective(), places)
	view.destination_requested.connect(_map_destination_requested)
	view.enter_requested.connect(func(): screen = "location"; _rebuild())
	view.rest_requested.connect(_rest_requested)

func _continue_auto_save() -> void:
	if SaveManager.load_auto():
		_switch_screen(_screen_after_load())
	else:
		_toast("自动存档读取失败，请检查存档文件。")

func _rest_requested() -> void:
	if not GameState.rest():
		_toast(_time_action_failure_message())
		return
	if not SaveManager.save_auto():
		_toast("调息完成，但自动存档失败。")
	_rebuild()

func _map_destination_requested(destination: String) -> void:
	if destination == GameState.data.location:
		screen = "location"
		_rebuild()
	elif GameState.travel(destination):
		SaveManager.save_auto()
		screen = "location"
		_rebuild()
	else:
		_toast(_time_action_failure_message())

func _show_location() -> void:
	_clear_content()
	var location_id: String = str(GameState.data.location)
	var headings := {"qingyun": "青云门 · 山门内", "blackreed": "黑苇渡 · 芦荡深处", "luoyang": "洛阳城 · 神都烟火", "huashan": "华山 · 云台剑会", "emei": "峨眉山 · 云深清音"}
	var view: LocationView = LOCATION_VIEW.instantiate()
	content.add_child(view)
	view.setup(_location_texture(location_id), headings.get(location_id, "江湖"), _quest_objective(), _location_actions(location_id))
	view.action_requested.connect(_location_action_requested)

func _location_actions(location_id: String) -> Array:
	if location_id == "qingyun":
		return [
			{"id": "master", "text": "正殿 · 拜见师父", "x": 90, "y": 155},
			{"id": "train", "text": "演武场 · 修炼", "x": 420, "y": 205},
			{"id": "library", "text": "藏经阁 · 查阅典籍", "x": 725, "y": 145},
			{"id": "map", "text": "山门 · 返回舆图", "x": 910, "y": 420}
		]
	if location_id == "blackreed":
		var ready: bool = GameState.data.investigations.size() >= 2
		return [
			{"id": "fisher", "text": "渡口 · 已询问" if "secret_route" in GameState.data.investigations else "渡口 · 询问渔民", "x": 70, "y": 170, "disabled": "secret_route" in GameState.data.investigations},
			{"id": "tracks", "text": "芦荡 · 已调查" if "archer" in GameState.data.investigations else "芦荡 · 搜寻脚印", "x": 365, "y": 245, "disabled": "archer" in GameState.data.investigations},
			{"id": "herbs", "text": "破船 · 已搜寻" if "herbs" in GameState.data.investigations else "破船 · 搜寻物资", "x": 685, "y": 330, "disabled": "herbs" in GameState.data.investigations},
			{"id": "fight", "text": "寨门 · 发起战斗" if ready else "寨门 · 尚需两条线索", "x": 930, "y": 150, "disabled": not ready},
			{"id": "map", "text": "渡口 · 返回舆图", "x": 930, "y": 430}
		]
	if location_id == "huashan":
		var trial_ready: bool = "lin_qingshuang" in GameState.data.companions
		return [
			{"id": "huashan_gate", "text": "山门 · 递上名帖", "x": 80, "y": 175, "disabled": str(GameState.data.quest_stage) != "chapter2_complete"},
			{"id": "meet_lin", "text": "迎客峰 · 林清霜", "x": 370, "y": 260, "disabled": str(GameState.data.quest_stage) == "chapter2_complete" or trial_ready},
			{"id": "huashan_trial", "text": "论剑台 · 双人试炼" if trial_ready else "论剑台 · 需要同伴", "x": 690, "y": 335, "disabled": not trial_ready or str(GameState.data.quest_stage) == "huashan_trial_complete"},
			{"id": "huashan_cliff", "text": "思过崖 · 残图剑痕", "x": 930, "y": 160, "disabled": str(GameState.data.quest_stage) != "huashan_trial_complete"},
			{"id": "map", "text": "山道 · 返回舆图", "x": 930, "y": 440}
		]
	if location_id == "emei":
		var entered: bool = str(GameState.data.emei_entry) != ""
		return [
			{"id": "emei_gate", "text": "清音桥 · 选择入山方式" if not entered else "清音桥 · 已获准入山", "x": 75, "y": 175, "disabled": entered},
			{"id": "meet_su", "text": "清音阁 · 苏晚晴", "x": 370, "y": 255, "disabled": not entered or str(GameState.data.quest_stage) != "emei_meet_su"},
			{"id": "elephant_pool", "text": "洗象池 · 门派试问", "x": 680, "y": 345, "disabled": str(GameState.data.quest_stage) != "emei_investigate"},
			{"id": "emei_peak", "text": "金顶 · 追入后山密道" if str(GameState.data.quest_stage) == "emei_trial" else ("金顶 · 武库天门决战" if str(GameState.data.quest_stage) == "final_assault" else "金顶 · 尘埃落定"), "x": 930, "y": 155, "disabled": str(GameState.data.quest_stage) not in ["emei_trial", "final_assault"]},
			{"id": "map", "text": "山道 · 返回舆图", "x": 930, "y": 440}
		]
	return [
		{"id": "gate", "text": "城门 · 打听消息", "x": 75, "y": 175},
		{"id": "inn", "text": "悦来客栈 · 江湖传闻", "x": 360, "y": 285},
		{"id": "market", "text": "西市 · 商旅云集", "x": 675, "y": 350},
		{"id": "temple", "text": "白马寺 · 玄铁令之约" if str(GameState.data.quest_stage) == "chapter_complete" else "白马寺 · 夜探古刹", "x": 925, "y": 155},
		{"id": "palace", "text": "太守府 · 夜宴", "x": 925, "y": 300, "disabled": str(GameState.data.quest_stage) != "luoyang_investigate"},
		{"id": "map", "text": "城门 · 返回舆图", "x": 930, "y": 445}
	]

func _location_action_requested(action_id: String) -> void:
	match action_id:
		"map": screen = "map"; _rebuild()
		"master": _qingyun_master_event()
		"train":
			if GameState.train():
				_toast("苦修一周，臂力与修为提升。")
				if not SaveManager.save_auto():
					_toast("修炼完成，但自动存档失败。")
			else:
				_toast(_time_action_failure_message())
			_rebuild()
		"library": _start_dialogue("library", [["守阁弟子", "玄铁令本是前朝武库信物，近年却频频出现在厉千秋党羽手中。"], ["沈羽", "看来黑苇渡之事并非普通匪患。"]])
		"fisher": _start_dialogue("clue_fisher", [["老渔翁", "夜里总有船避开灯火，往北面的芦荡去。"], ["沈羽", "暗道入口应当就在水边。"]])
		"tracks": _start_dialogue("clue_tracks", [["沈羽", "脚印一深一浅，还有箭羽留下的刮痕。"], ["沈羽", "寨中藏有弓手，交战时需先行提防。"]])
		"herbs": _start_dialogue("clue_herbs", [["沈羽", "船舱里还有未受潮的金疮药，可以先处理伤势。"]])
		"fight": _begin_blackreed_battle()
		"gate": _start_dialogue("luoyang_gate", [["守城军士", "近日太守府戒备森严，夜里还有禁军出入。"], ["沈羽", "玄铁令的消息恐怕已经传进官府。"]])
		"inn": _start_dialogue("luoyang_inn", [["说书人", "厉千秋尚未出关，他的义子却已在洛阳搜寻前朝武库。"], ["沈羽", "看来必须赶在他们之前找到下一枚钥匙。"]])
		"market": _start_dialogue("luoyang_market", [["药铺掌柜", "少侠初到洛阳，这包金疮药便宜卖你。真正值钱的消息，要去白马寺问。"]])
		"temple": _baima_event()
		"palace": _enter_palace()
		"huashan_gate": _start_dialogue("huashan_arrival", [["华山执事", "青云门沈羽，持武库名录而来？剑会只认剑，也认胆识。"], ["沈羽", "晚辈愿依华山规矩，查清残图下落。"]])
		"meet_lin": _start_dialogue("meet_lin", [["林清霜", "论剑台今年改为双人试炼。你若不嫌我剑路太快，我可以与你同上。"], ["沈羽", "求之不得。厉无咎既盯上残图，我们更该彼此照应。"]])
		"huashan_trial": _begin_huashan_trial()
		"huashan_cliff": _start_dialogue("huashan_cliff", [["林清霜", "石壁剑痕并非华山剑法，倒像有人故意留下的引路符号。"], ["沈羽", "符号指向峨眉。厉无咎已经先行一步。"]])
		"emei_gate": _start_story_dialogue("emei_gate")
		"meet_su": _start_story_dialogue("meet_su")
		"elephant_pool": _start_dialogue("elephant_pool", [["苏晚晴", "洗象池旁有两条路：一边是受伤同门，一边是厉无咎留下的脚印。你先救谁？"], ["沈羽", "线索可以再追，人命不能重来。先救人。"], ["苏晚晴", "这个回答，至少不像厉无咎。"]])
		"emei_peak":
			if str(GameState.data.quest_stage) == "emei_trial":
				_start_dialogue("emei_peak", [["苏晚晴", "金顶佛光下有一道逆行剑痕，正通往封闭百年的后山密道。"], ["林清霜", "厉无咎在等我们。他想用武库天门作最后一道局。"], ["沈羽", "那便让这场追逐在这里结束。武库属于谁，等打赢之后再问。"]])
			else:
				_begin_final_battle()

func _add_scene_action(text_value: String, at: Vector2, callback: Callable) -> Button:
	var button := _action_button(text_value, Color("#263f34ee"))
	button.position = at
	button.size = Vector2(260, 58)
	button.pressed.connect(callback)
	content.add_child(button)
	return button

func _qingyun_master_event() -> void:
	match str(GameState.data.quest_stage):
		"meet_master": _start_dialogue("accept_mission", [["顾长风", "黑苇渡商旅失踪，官府却闭口不谈。你入门虽短，心性尚可，便下山查一查。"], ["沈羽", "弟子领命。若此事牵涉江湖势力，定会留下线索。"], ["顾长风", "记住，先察后动。剑快不如眼明。"]])
		"return_master": _start_dialogue("finish_chapter", [["沈羽", "弟子在寨主身上取得玄铁令，背后似与厉千秋有关。"], ["顾长风", "此令牵涉洛阳旧案。你先养伤，随后持令前往洛阳白马寺。"], ["沈羽", "弟子明白。"]])
		_: _start_dialogue("master_chat", [["顾长风", "江湖路远，莫忘入门时的本心。"]])

func _start_dialogue(event_id: String, entries: Array, return_to: String = "location") -> void:
	dialogue_event = event_id
	dialogue_entries = entries
	dialogue_index = 0
	dialogue_return_screen = return_to
	screen = "dialogue"
	_rebuild()

func _start_story_dialogue(event_id: String, return_to: String = "location") -> void:
	var entries: Array = ContentDB.dialogue(event_id)
	if entries.is_empty():
		_toast("剧情数据缺失：%s" % event_id)
		return
	_start_dialogue(event_id, entries, return_to)

func _baima_event() -> void:
	if str(GameState.data.quest_stage) == "chapter_complete":
		_start_story_dialogue("baima_intro")
	else:
		_start_dialogue("baima_repeat", [["无尘僧", "你选择的道路已经落子。太守府夜宴，切记随机应变。"]])

func _show_dialogue() -> void:
	_clear_content()
	var entry: Array = dialogue_entries[dialogue_index]
	var view: DialogueView = DIALOGUE_VIEW.instantiate()
	content.add_child(view)
	view.setup(_location_texture(str(GameState.data.location)), str(entry[0]), str(entry[1]), dialogue_index, dialogue_entries.size())
	view.continue_requested.connect(_advance_dialogue)

func _advance_dialogue() -> void:
	dialogue_index += 1
	if dialogue_index < dialogue_entries.size():
		_rebuild()
		return
	_finish_dialogue_event(dialogue_event)
	if screen == "dialogue":
		screen = dialogue_return_screen
	SaveManager.save_auto()
	_rebuild()

func _finish_dialogue_event(event_id: String) -> void:
	match event_id:
		"accept_mission":
			GameState.data.quest_stage = "investigate"
			GameState.add_log("师父命你调查黑苇渡商旅失踪一案。")
		"clue_fisher": GameState.add_investigation("secret_route", "渔民指出了寨众夜间行船的暗道。")
		"clue_tracks": GameState.add_investigation("archer", "你从脚印与箭痕判断寨中藏有弓手。")
		"clue_herbs":
			if GameState.add_investigation("herbs", "你在破船中找到药材，恢复了气血。"):
				GameState.data.hp = GameState.data.max_hp
		"finish_chapter":
			GameState.data.quest_stage = "chapter_complete"
			GameState.data.master_relation += 1
			GameState.add_log("顾长风命你携玄铁令前往洛阳白马寺。")
		"baima_intro":
			choice_event = "baima_route"
			choice_prompt = "太守府夜宴，你准备如何取得武库名录？"
			choice_options = [
				["侠义 · 公开赴宴", "以青云门弟子身份登门，保护席间无辜之人。", "heroism"],
				["谋略 · 易容潜入", "伪装成账房，避开正面冲突寻找密库。", "strategy"],
				["威势 · 持令问罪", "以玄铁令震慑守卫，迫使太守当面对质。", "authority"]
			]
			screen = "choice"
		"luoyang_market":
			if "洛阳金疮药" not in GameState.data.items:
				GameState.data.items.append("洛阳金疮药")
		"palace_witness": _add_palace_evidence("witness", "heroism")
		"palace_ledger": _add_palace_evidence("ledger", "strategy")
		"palace_seal": _add_palace_evidence("seal", "authority")
		"li_wujiu":
			choice_event = "chapter2_end"
			choice_prompt = "武库名录已经到手，你准备如何处置这份足以震动江湖的证据？"
			choice_options = [
				["公之于众", "揭露太守罪行，迅速提升江湖声望。", "public"],
				["交还师门", "让青云门处置名录，增加顾长风的信任。", "master"],
				["暗留残页", "独自追查厉无咎，获得特殊物品与悟性。", "keep"]
			]
			screen = "choice"
		"huashan_arrival":
			GameState.data.quest_stage = "huashan_meet_companion"
			GameState.data.faction_relations.huashan += 1
			GameState.add_log("你持名帖进入华山剑会，华山关系提升。")
		"meet_lin":
			if "lin_qingshuang" not in GameState.data.companions:
				GameState.data.companions.append("lin_qingshuang")
			GameState.data.quest_stage = "huashan_trial"
			GameState.add_log("华山弟子林清霜暂时加入队伍。")
		"huashan_cliff":
			GameState.data.quest_stage = "chapter3_complete"
			GameState.data.faction_relations.huashan += 2
			GameState.add_log("你在思过崖发现指向峨眉的残图剑痕。")
		"emei_gate":
			choice_event = "emei_entry"
			choice_prompt = "峨眉已经封山，你准备用什么方式取得入山许可？"
			choice_options = []
			if int(GameState.data.faction_relations.huashan) >= 2:
				choice_options.append(["华山引荐", "出示华山剑会名帖，获得较高的峨眉初始信任。", "recommend"])
			if int(GameState.data.renown) >= 8:
				choice_options.append(["凭声望拜山", "报上江湖名号，以过往事迹证明来意。", "renown"])
			choice_options.append(["帮助山民", "先协助山下受灾村民，耗费一周换取入山机会。", "aid"])
			screen = "choice"
		"meet_su":
			GameState.data.quest_stage = "emei_investigate"
			GameState.add_log("峨眉弟子苏晚晴带你前往洗象池接受试问。")
		"elephant_pool":
			GameState.data.quest_stage = "emei_trial"
			GameState.data.faction_relations.emei += 1
			if "su_trust" not in GameState.data.flags:
				GameState.data.flags.append("su_trust")
			GameState.add_log("你选择先救峨眉弟子，获得苏晚晴的初步信任。")
		"emei_peak":
			GameState.data.quest_stage = "final_assault"
			GameState.add_log("你在峨眉金顶找到武库天门，厉无咎正在密道尽头等候。")

func _add_palace_evidence(kind: String, favored_route: String) -> void:
	if kind in GameState.data.palace_evidence:
		return
	GameState.data.palace_evidence.append(kind)
	if str(GameState.data.luoyang_route) != favored_route:
		GameState.data.palace_alert = mini(5, int(GameState.data.palace_alert) + 1)
	GameState.add_log("你在太守府取得证据：%s。" % {"witness": "账房船契", "ledger": "私兵账册", "seal": "伪造官印"}.get(kind, kind))

func _show_choice() -> void:
	_clear_content()
	var view: ChoiceView = CHOICE_VIEW.instantiate()
	content.add_child(view)
	view.setup(_location_texture(str(GameState.data.location)), choice_prompt, choice_options)
	view.option_selected.connect(_resolve_choice)

func _resolve_choice(route: String) -> void:
	if choice_event == "baima_route":
		GameState.data.alignment[route] = int(GameState.data.alignment.get(route, 0)) + 1
		GameState.data.luoyang_route = route
		GameState.data.quest_stage = "luoyang_investigate"
		match route:
			"heroism":
				GameState.data.renown += 2
				GameState.add_log("你决定以青云弟子身份公开赴宴，保护无辜。")
			"strategy":
				GameState.data.insight += 1
				GameState.add_log("你决定易容潜入太守府，悟性提升。")
			"authority":
				GameState.data.strength += 1
				GameState.add_log("你决定持玄铁令登门问罪，臂力提升。")
	elif choice_event == "chapter2_end":
		match route:
			"public":
				GameState.data.renown += 5
				GameState.add_log("你在洛阳公开武库名录，太守罪行大白于天下。")
			"master":
				GameState.data.master_relation += 2
				GameState.add_log("你将武库名录交回青云门，获得师门信任。")
			"keep":
				GameState.data.insight += 1
				if "武库名录残页" not in GameState.data.items:
					GameState.data.items.append("武库名录残页")
				GameState.add_log("你暗中留下名录残页，准备独自追查厉无咎。")
		GameState.data.quest_stage = "chapter2_complete"
	elif choice_event == "emei_entry":
		if route == "aid" and not GameState.spend_week():
			_toast(_time_action_failure_message())
			return
		GameState.data.emei_entry = route
		GameState.data.quest_stage = "emei_meet_su"
		match route:
			"recommend":
				GameState.data.faction_relations.emei += 2
				GameState.add_log("你凭华山引荐进入峨眉，获得峨眉弟子的信任。")
			"renown":
				GameState.data.faction_relations.emei += 1
				GameState.add_log("你凭江湖声望获准进入峨眉。")
			"aid":
				GameState.data.renown += 2
				GameState.data.faction_relations.emei += 1
				GameState.add_log("你耗费一周帮助山民，峨眉为你打开山门。")
	elif choice_event == "final_legacy":
		GameState.complete_game(route)
	choice_event = ""
	screen = "ending" if str(GameState.data.quest_stage) == "game_complete" else ("map" if str(GameState.data.quest_stage) == "chapter2_complete" else "location")
	SaveManager.save_auto()
	_rebuild()

func _enter_palace() -> void:
	if str(GameState.data.quest_stage) != "luoyang_investigate":
		_toast("先前往白马寺，决定进入夜宴的方法。")
		return
	screen = "palace"
	_rebuild()

func _show_palace() -> void:
	_clear_content()
	var art := TextureRect.new()
	art.texture = BATTLE_TEXTURE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color("#120b08a8")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(shade)
	var heading := Label.new()
	heading.position = Vector2(42, 22)
	heading.text = "太守府 · 夜宴"
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color("#f3d7a2"))
	content.add_child(heading)
	var route_label := Label.new()
	route_label.position = Vector2(45, 70)
	route_label.text = "入府方式：%s     证据：%d/3     警戒：%d/5" % [_route_name(str(GameState.data.luoyang_route)), GameState.data.palace_evidence.size(), GameState.data.palace_alert]
	route_label.add_theme_font_size_override("font_size", 18)
	route_label.add_theme_color_override("font_color", Color("#f7eee0"))
	content.add_child(route_label)
	var route_hint := Label.new()
	route_hint.position = Vector2(850, 22)
	route_hint.size = Vector2(370, 80)
	route_hint.text = _route_hint(str(GameState.data.luoyang_route))
	route_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_hint.add_theme_color_override("font_color", Color("#dfbf74"))
	content.add_child(route_hint)

	var witness := _add_scene_action("宴席 · 保护证人", Vector2(95, 175), func(): _palace_event("witness"))
	witness.disabled = "witness" in GameState.data.palace_evidence
	var ledger := _add_scene_action("书房 · 搜查账册", Vector2(420, 265), func(): _palace_event("ledger"))
	ledger.disabled = "ledger" in GameState.data.palace_evidence
	var seal := _add_scene_action("密库 · 夺取官印", Vector2(740, 350), func(): _palace_event("seal"))
	seal.disabled = "seal" in GameState.data.palace_evidence
	var confront := _add_scene_action("正厅 · 与厉无咎对质", Vector2(940, 170), func(): _confront_li_wujiu())
	confront.disabled = GameState.data.palace_evidence.size() < 2
	_add_scene_action("侧门 · 暂离太守府", Vector2(940, 445), func(): screen = "location"; _rebuild())
	var evidence := Label.new()
	evidence.position = Vector2(45, 445)
	evidence.size = Vector2(760, 105)
	evidence.text = "已取得证据\n%s" % _evidence_list()
	evidence.add_theme_font_size_override("font_size", 17)
	evidence.add_theme_color_override("font_color", Color("#f5ecda"))
	evidence.add_theme_stylebox_override("normal", _box(Color("#172820e8")))
	content.add_child(evidence)

func _palace_event(kind: String) -> void:
	match kind:
		"witness": _start_story_dialogue("palace_witness", "palace")
		"ledger": _start_story_dialogue("palace_ledger", "palace")
		"seal": _start_story_dialogue("palace_seal", "palace")

func _confront_li_wujiu() -> void:
	if int(GameState.data.palace_alert) >= 3:
		GameState.data.hp = maxi(1, int(GameState.data.hp) - 6)
		GameState.add_log("太守府警戒过高，你突破守卫时损失了6点气血。")
	_start_story_dialogue("li_wujiu", "palace")

func _route_name(route: String) -> String:
	return {"heroism": "侠义 · 公开赴宴", "strategy": "谋略 · 易容潜入", "authority": "威势 · 持令问罪"}.get(route, "尚未决定")

func _route_hint(route: String) -> String:
	return {"heroism": "保护证人不会提高警戒。", "strategy": "搜查书房不会提高警戒。", "authority": "夺取官印不会提高警戒。"}.get(route, "选择路线后获得专属优势。")

func _evidence_list() -> String:
	var names: PackedStringArray = []
	for item in GameState.data.palace_evidence:
		names.append({"witness": "账房船契与证词", "ledger": "私兵转运账册", "seal": "伪造调令的官印"}.get(item, item))
	return "尚未取得证据" if names.is_empty() else " · ".join(names)

func _begin_blackreed_battle() -> void:
	if GameState.data.investigations.size() < 2:
		_toast("至少调查两处地点，摸清寨中情况。")
		return
	if GameState.start_blackreed_battle():
		if "archer" in GameState.data.investigations:
			GameState.data.battle.result = "你提前发现了弓手位置。先处理远程威胁！"
		if "secret_route" in GameState.data.investigations:
			GameState.data.battle.player_x = 2
		GameState.capture_battle_checkpoint()
		battle_mode = "move"
		SaveManager.save_auto()

func _begin_huashan_trial() -> void:
	if "lin_qingshuang" not in GameState.data.companions:
		_toast("需要先在迎客峰邀请林清霜。")
		return
	if not GameState.start_huashan_trial_battle():
		_toast("行动点不足，请先调息。")
		return
	battle_mode = "move"
	GameState.capture_battle_checkpoint()
	SaveManager.save_auto()

func _show_quests() -> void:
	_clear_content()
	var panel := PanelContainer.new()
	panel.position = Vector2(105, 45)
	panel.size = Vector2(1070, 500)
	panel.add_theme_stylebox_override("panel", _box(Color("#172820")))
	content.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := Label.new()
	title.text = "行走江湖 · 任务日志"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#f2dfb3"))
	box.add_child(title)
	var main_task := Label.new()
	if _emei_unlocked():
		main_task.text = "主线 · 峨眉迷踪\n%s\n\n峨眉关系：%d\n入山方式：%s" % [_quest_objective(), GameState.data.faction_relations.emei, _emei_entry_name(str(GameState.data.emei_entry))]
	elif _huashan_unlocked():
		main_task.text = "主线 · 华山剑会\n%s\n\n队伍：%s\n华山关系：%d" % [_quest_objective(), "沈羽、林清霜" if "lin_qingshuang" in GameState.data.companions else "沈羽", GameState.data.faction_relations.huashan]
	elif _luoyang_unlocked():
		main_task.text = "主线 · 洛阳风云\n%s\n\n行事倾向\n侠义 %d    谋略 %d    威势 %d" % [_quest_objective(), GameState.data.alignment.heroism, GameState.data.alignment.strategy, GameState.data.alignment.authority]
	else:
		main_task.text = "主线 · 黑苇疑云\n%s\n\n调查线索  %d/3\n%s" % [_quest_objective(), GameState.data.investigations.size(), _clue_list()]
	main_task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_task.add_theme_font_size_override("font_size", 19)
	main_task.add_theme_color_override("font_color", Color("#f4eee2"))
	main_task.add_theme_stylebox_override("normal", _box(Color("#294438")))
	box.add_child(main_task)
	var hint := Label.new()
	hint.text = "提示：在天下舆图点击当前地点即可进入场景。场景中的人物与地点会推进任务。"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("#cfc8b8"))
	box.add_child(hint)

func _show_achievements() -> void:
	_clear_content()
	var backdrop := ColorRect.new()
	backdrop.color = Color("#d8cfbd")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(backdrop)
	var panel := VBoxContainer.new()
	panel.position = Vector2(185, 28)
	panel.size = Vector2(910, 520)
	panel.add_theme_constant_override("separation", 10)
	content.add_child(panel)
	var title := Label.new()
	title.text = "江 湖 成 就    %d/%d" % [SteamService.unlocked_count(), SteamService.definitions.size()]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#193128"))
	panel.add_child(title)
	var backend_label := Label.new()
	backend_label.text = "Steam 服务：%s%s" % [SteamService.backend_name(), " · 已连接" if SteamService.is_live() else " · 本地模拟（等待 App ID/SDK）"]
	backend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	backend_label.add_theme_color_override("font_color", Color("#526159"))
	panel.add_child(backend_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for value in SteamService.definitions:
		var definition: Dictionary = value
		var unlocked: bool = SteamService.is_unlocked(str(definition.api_name))
		var entry := Label.new()
		entry.text = "%s  %s\n%s" % ["已解锁" if unlocked else "未解锁", str(definition.title), str(definition.description)]
		entry.custom_minimum_size.y = 62
		entry.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		entry.add_theme_font_size_override("font_size", 17)
		entry.add_theme_color_override("font_color", Color("#f2dfb3") if unlocked else Color("#b9b4aa"))
		entry.add_theme_stylebox_override("normal", _box(Color("#294438") if unlocked else Color("#4b514d")))
		list.add_child(entry)

func _show_credits() -> void:
	_clear_content()
	var art := TextureRect.new()
	art.texture = QINGYUN_TEXTURE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color("#08130de8")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(shade)
	var panel := VBoxContainer.new()
	panel.position = Vector2(210, 24)
	panel.size = Vector2(860, 525)
	panel.add_theme_constant_override("separation", 10)
	content.add_child(panel)
	var title := Label.new()
	title.text = "制 作 名 单 与 版 权"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f2dfb3"))
	panel.add_child(title)
	var version := Label.new()
	version.text = "《山河问道》 · Windows 0.11.0 · Godot 4.7.1"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_color_override("font_color", Color("#c9c7bc"))
	panel.add_child(version)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for section in _credit_sections():
		var heading := Label.new()
		heading.text = str(section.get("title", ""))
		heading.add_theme_font_size_override("font_size", 21)
		heading.add_theme_color_override("font_color", Color("#dfbf74"))
		list.add_child(heading)
		var body := Label.new()
		body.text = "\n".join(PackedStringArray(section.get("lines", [])))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 16)
		body.add_theme_color_override("font_color", Color("#eee5d3"))
		body.add_theme_stylebox_override("normal", _box(Color("#17382ecc")))
		list.add_child(body)
	var back := _action_button("返回", Color("#806c4f"))
	back.pressed.connect(func(): screen = previous_screen if previous_screen != "credits" else "menu"; _rebuild())
	panel.add_child(back)

func _credit_sections() -> Array:
	if not FileAccess.file_exists(CREDITS_PATH):
		return [{"title": "版权信息不可用", "lines": ["credits.json 未被正确打包。"]}]
	var file := FileAccess.open(CREDITS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed.get("sections", []) if typeof(parsed) == TYPE_DICTIONARY else []

func _quest_objective() -> String:
	return {
		"meet_master": "前往青云门正殿，拜见师父顾长风。",
		"investigate": "前往黑苇渡调查，取得两条线索后攻入山寨。",
		"return_master": "携玄铁令返回青云门，向顾长风复命。",
		"chapter_complete": "前往洛阳白马寺，将玄铁令交给无尘僧。",
		"luoyang_investigate": "潜入太守府夜宴，取得至少两件证据并与厉无咎对质。",
		"chapter2_complete": "第二章完成：厉无咎逃离洛阳，武库名录指向华山。",
		"huashan_meet_companion": "前往迎客峰寻找搭档，准备双人论剑试炼。",
		"huashan_trial": "与林清霜登上论剑台，通过华山双人试炼。",
		"huashan_trial_complete": "前往思过崖查看武库残图留下的剑痕。",
		"chapter3_complete": "第三章完成：残图线索指向峨眉。",
		"emei_meet_su": "在清音阁拜访苏晚晴，查明后山闯阵者。",
		"emei_investigate": "前往洗象池接受峨眉试问，争取继续追查厉无咎。",
		"emei_trial": "峨眉试问已通过：下一步前往金顶追查后山密道。"
		,"final_assault": "武库天门已经开启：在金顶密道与厉无咎展开最终决战。"
		,"final_choice": "厉无咎已败：决定武库与江湖的未来。"
		,"game_complete": "山河已定。可在结局页回顾这段江湖旅程。"
	}.get(str(GameState.data.get("quest_stage", "meet_master")), "继续调查江湖异动。")

func _luoyang_unlocked() -> bool:
	return str(GameState.data.get("quest_stage", "meet_master")) in ["chapter_complete", "luoyang_investigate", "chapter2_complete", "huashan_meet_companion", "huashan_trial", "huashan_trial_complete", "chapter3_complete", "emei_meet_su", "emei_investigate", "emei_trial", "final_assault", "final_choice", "game_complete"]

func _huashan_unlocked() -> bool:
	return str(GameState.data.get("quest_stage", "meet_master")) in ["chapter2_complete", "huashan_meet_companion", "huashan_trial", "huashan_trial_complete", "chapter3_complete", "emei_meet_su", "emei_investigate", "emei_trial", "final_assault", "final_choice", "game_complete"]

func _emei_unlocked() -> bool:
	return str(GameState.data.get("quest_stage", "meet_master")) in ["chapter3_complete", "emei_meet_su", "emei_investigate", "emei_trial", "final_assault", "final_choice", "game_complete"]

func _emei_entry_name(route: String) -> String:
	return {"recommend": "华山引荐", "renown": "江湖声望", "aid": "帮助山民"}.get(route, "尚未入山")

func _location_texture(location_id: String) -> Texture2D:
	return {
		"qingyun": QINGYUN_TEXTURE,
		"blackreed": BATTLE_TEXTURE,
		"luoyang": LUOYANG_TEXTURE,
		"huashan": HUASHAN_TEXTURE,
		"emei": EMEI_TEXTURE
	}.get(location_id, MAP_TEXTURE)

func _clue_list() -> String:
	var lines: PackedStringArray = []
	for clue in GameState.data.investigations:
		lines.append("· " + {"secret_route": "芦荡暗道", "archer": "寨中弓手", "herbs": "破船药材"}.get(clue, clue))
	return "尚未取得线索" if lines.is_empty() else "\n".join(lines)

func _show_dev_menu() -> void:
	_clear_content()
	var panel := PanelContainer.new()
	panel.position = Vector2(150, 42)
	panel.size = Vector2(980, 510)
	panel.add_theme_stylebox_override("panel", _box(Color("#172820")))
	content.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "开发测试菜单"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#dfbf74"))
	box.add_child(title)
	var warning := Label.new()
	warning.text = "仅在 DEBUG 构建中出现。章节跳转会重置当前进度，请先手动存档。"
	warning.add_theme_color_override("font_color", Color("#efc0b2"))
	box.add_child(warning)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for entry in [["新游戏 · 青云门", "new"], ["第一章 · 黑苇调查", "blackreed"], ["战棋 · 黑苇遭遇战", "battle"], ["第二章 · 初到洛阳", "luoyang"], ["太守府 · 谋略路线", "palace"], ["第二章 · 已完成", "chapter2"], ["第三章 · 华山试炼", "huashan"], ["第四章 · 初到峨眉", "emei"], ["终章 · 武库天门", "finale"]]:
		var button := _action_button(entry[0], Color("#315f4b"))
		button.custom_minimum_size.x = 440
		button.pressed.connect(_dev_jump.bind(str(entry[1])))
		grid.add_child(button)
	var reload_button := _action_button("重新读取剧情 JSON", Color("#806c4f"))
	reload_button.pressed.connect(func(): _toast("剧情数据已重新读取。" if ContentDB.reload_content() else "剧情数据读取失败。"))
	box.add_child(reload_button)

func _dev_jump(target: String) -> void:
	GameState.new_game()
	match target:
		"new":
			GameState.data.location = "qingyun"
			screen = "map"
		"blackreed":
			GameState.data.quest_stage = "investigate"
			GameState.data.location = "blackreed"
			GameState.data.investigations = ["secret_route"]
			screen = "location"
		"battle":
			GameState.data.quest_stage = "investigate"
			GameState.data.location = "blackreed"
			GameState.data.investigations = ["secret_route", "archer"]
			GameState.data.energy = 3
			GameState.start_blackreed_battle()
			return
		"luoyang":
			GameState.data.quest_stage = "chapter_complete"
			GameState.data.location = "luoyang"
			GameState.data.items.append("玄铁令")
			screen = "location"
		"palace":
			GameState.data.quest_stage = "luoyang_investigate"
			GameState.data.location = "luoyang"
			GameState.data.luoyang_route = "strategy"
			GameState.data.alignment.strategy = 1
			screen = "palace"
		"chapter2":
			GameState.data.quest_stage = "chapter2_complete"
			GameState.data.location = "luoyang"
			screen = "map"
		"huashan":
			GameState.data.quest_stage = "huashan_trial"
			GameState.data.location = "huashan"
			GameState.data.companions.append("lin_qingshuang")
			GameState.data.faction_relations.huashan = 2
			screen = "location"
		"emei":
			GameState.data.quest_stage = "chapter3_complete"
			GameState.data.location = "emei"
			GameState.data.companions.append("lin_qingshuang")
			GameState.data.faction_relations.huashan = 3
			screen = "location"
		"finale":
			GameState.data.quest_stage = "final_assault"
			GameState.data.location = "emei"
			GameState.data.companions.append("lin_qingshuang")
			GameState.data.flags.append("su_trust")
			GameState.data.faction_relations.huashan = 3
			GameState.data.faction_relations.emei = 3
			screen = "location"
	SaveManager.save_auto()
	_rebuild()

func _show_character() -> void:
	_clear_content()
	var page := HBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 48
	page.offset_top = 28
	page.offset_right = -48
	page.offset_bottom = -28
	page.add_theme_constant_override("separation", 22)
	content.add_child(page)

	# 左侧只负责人物形象与身份，裁切由父容器控制，绝不侵入信息区。
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size.x = 355
	portrait_frame.clip_contents = true
	portrait_frame.add_theme_stylebox_override("panel", _box(Color("#25382f")))
	page.add_child(portrait_frame)
	var portrait_stack := Control.new()
	portrait_stack.clip_contents = true
	portrait_frame.add_child(portrait_stack)
	var portrait := TextureRect.new()
	portrait.texture = HERO_TEXTURE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_stack.add_child(portrait)
	var identity_shade := ColorRect.new()
	identity_shade.color = Color("#0d1812dd")
	identity_shade.anchor_top = 1.0
	identity_shade.anchor_right = 1.0
	identity_shade.anchor_bottom = 1.0
	identity_shade.offset_top = -112
	portrait_stack.add_child(identity_shade)
	var identity := Label.new()
	identity.text = "沈 羽\n青云门 · 入门弟子"
	identity.position = Vector2(22, 18)
	identity.add_theme_font_size_override("font_size", 22)
	identity.add_theme_color_override("font_color", Color("#f2dfb3"))
	identity_shade.add_child(identity)

	# 右侧采用可扫描的信息卡布局。
	var info_panel := PanelContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.add_theme_stylebox_override("panel", _box(Color("#172820")))
	page.add_child(info_panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 12)
	info_panel.add_child(info)
	var heading := Label.new()
	heading.text = "人物总览"
	heading.add_theme_font_size_override("font_size", 27)
	heading.add_theme_color_override("font_color", Color("#f2dfb3"))
	info.add_child(heading)

	var summary := Label.new()
	summary.text = "综合战力  %d     气血  %d/%d     真气  %d     声望  %d" % [GameState.power(), GameState.data.hp, GameState.data.max_hp, GameState.data.qi, GameState.data.renown]
	summary.add_theme_font_size_override("font_size", 18)
	summary.add_theme_color_override("font_color", Color("#e9e1cf"))
	info.add_child(summary)

	var stat_grid := GridContainer.new()
	stat_grid.columns = 4
	stat_grid.add_theme_constant_override("h_separation", 10)
	info.add_child(stat_grid)
	for entry in [["臂力", GameState.data.strength], ["身法", GameState.data.agility], ["悟性", GameState.data.insight], ["根骨", GameState.data.constitution]]:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _box(Color("#294438")))
		var value := Label.new()
		value.text = "%s\n%d" % [entry[0], entry[1]]
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 20)
		value.add_theme_color_override("font_color", Color("#fff4dc"))
		card.add_child(value)
		stat_grid.add_child(card)

	var skill_title := Label.new()
	skill_title.text = "武 学"
	skill_title.add_theme_font_size_override("font_size", 20)
	skill_title.add_theme_color_override("font_color", Color("#dfbf74"))
	info.add_child(skill_title)
	var skill_card := Label.new()
	skill_card.text = "流云剑法   ·   近身剑招   ·   消耗 8 真气\n当前效果：相邻目标造成较高伤害；修炼属性会直接提高招式威力。"
	skill_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_card.add_theme_font_size_override("font_size", 17)
	skill_card.add_theme_color_override("font_color", Color("#f4eee2"))
	skill_card.add_theme_stylebox_override("normal", _box(Color("#223a30")))
	info.add_child(skill_card)

	var item_title := Label.new()
	item_title.text = "行 囊"
	item_title.add_theme_font_size_override("font_size", 20)
	item_title.add_theme_color_override("font_color", Color("#dfbf74"))
	info.add_child(item_title)
	var items := Label.new()
	items.text = "已装备：青锋剑\n携带物品：%s" % "、".join(PackedStringArray(GameState.data.items))
	items.add_theme_font_size_override("font_size", 17)
	items.add_theme_color_override("font_color", Color("#f4eee2"))
	info.add_child(items)
	var party := Label.new()
	party.text = "同行侠客：%s\n门派关系：青云 %d · 华山 %d" % ["林清霜" if "lin_qingshuang" in GameState.data.companions else "暂无", GameState.data.faction_relations.qingyun, GameState.data.faction_relations.huashan]
	party.add_theme_font_size_override("font_size", 17)
	party.add_theme_color_override("font_color", Color("#dfbf74"))
	info.add_child(party)
	var mastery := Label.new()
	mastery.text = "武学熟练度：流云剑法 %d · 霜华刺 %d · 寒锋守势 %d\n每使用3次，对应武学伤害或护卫值 +1。" % [GameState.data.skill_mastery.cloud, GameState.data.skill_mastery.frost, GameState.data.skill_mastery.frost_guard]
	mastery.add_theme_font_size_override("font_size", 15)
	mastery.add_theme_color_override("font_color", Color("#cfc8b8"))
	info.add_child(mastery)

func _show_settings() -> void:
	_clear_content()
	var backdrop := ColorRect.new()
	backdrop.color = Color("#d8cfbd")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(backdrop)
	var panel := VBoxContainer.new()
	panel.position = Vector2(300, 28)
	panel.size = Vector2(680, 520)
	panel.add_theme_constant_override("separation", 12)
	content.add_child(panel)
	var title := Label.new()
	title.text = "设 置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#193128"))
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "设置会立即生效，并独立于游戏存档保存。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("#526159"))
	panel.add_child(subtitle)
	_add_volume_setting(panel, "主音量", "master_volume")
	_add_volume_setting(panel, "音乐音量", "music_volume")
	_add_volume_setting(panel, "音效音量", "sfx_volume")

	var difficulty_row := HBoxContainer.new()
	difficulty_row.add_theme_constant_override("separation", 18)
	panel.add_child(difficulty_row)
	var difficulty_label := Label.new()
	difficulty_label.text = "战斗难度"
	difficulty_label.custom_minimum_size.x = 120
	difficulty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	difficulty_label.add_theme_font_size_override("font_size", 18)
	difficulty_row.add_child(difficulty_label)
	var difficulty_options := OptionButton.new()
	difficulty_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for level in SettingsManager.DIFFICULTIES:
		difficulty_options.add_item(DIFFICULTY_RULES.display_name(level))
		if str(level) == str(SettingsManager.data.difficulty):
			difficulty_options.selected = difficulty_options.item_count - 1
	difficulty_row.add_child(difficulty_options)
	var difficulty_detail := Label.new()
	difficulty_detail.text = DIFFICULTY_RULES.description(str(SettingsManager.data.difficulty))
	difficulty_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	difficulty_detail.add_theme_color_override("font_color", Color("#526159"))
	panel.add_child(difficulty_detail)
	difficulty_options.item_selected.connect(func(index: int):
		var level: String = str(SettingsManager.DIFFICULTIES[index])
		SettingsManager.update_setting("difficulty", level)
		difficulty_detail.text = DIFFICULTY_RULES.description(level)
	)

	var display_row := HBoxContainer.new()
	display_row.add_theme_constant_override("separation", 18)
	panel.add_child(display_row)
	var fullscreen := CheckButton.new()
	fullscreen.text = "全屏显示"
	fullscreen.button_pressed = bool(SettingsManager.data.fullscreen)
	fullscreen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fullscreen.add_theme_font_size_override("font_size", 18)
	fullscreen.toggled.connect(func(enabled: bool): SettingsManager.update_setting("fullscreen", enabled))
	display_row.add_child(fullscreen)
	var scale_label := Label.new()
	scale_label.text = "界面缩放"
	scale_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scale_label.add_theme_font_size_override("font_size", 18)
	display_row.add_child(scale_label)
	var scale_options := OptionButton.new()
	for scale in SettingsManager.UI_SCALES:
		scale_options.add_item("%d%%" % int(float(scale) * 100.0))
		if is_equal_approx(float(scale), float(SettingsManager.data.ui_scale)):
			scale_options.selected = scale_options.item_count - 1
	scale_options.item_selected.connect(func(index: int): SettingsManager.update_setting("ui_scale", SettingsManager.UI_SCALES[index]))
	display_row.add_child(scale_options)

	var hint := Label.new()
	hint.text = "推荐 Steam Deck 使用 115% 或 130% 界面缩放。难度会从下一场新开始的战斗生效，当前战斗与重试保持原数值。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("#526159"))
	hint.add_theme_stylebox_override("normal", _box(Color("#ede5d5")))
	panel.add_child(hint)
	var reset := _action_button("恢复默认设置", Color("#806c4f"))
	reset.pressed.connect(func(): SettingsManager.data = SettingsManager.defaults(); SettingsManager.apply_settings(); SettingsManager.save_settings(); _rebuild())
	panel.add_child(reset)
	var reset_tutorial := _action_button("重新显示新手引导", Color("#315746"))
	reset_tutorial.pressed.connect(_reset_tutorial)
	panel.add_child(reset_tutorial)

func _add_volume_setting(parent: VBoxContainer, label_text: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("#193128"))
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = float(SettingsManager.data.get(key, 0.8)) * 100.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float): SettingsManager.update_setting(key, value / 100.0))
	row.add_child(slider)
	var value_label := Label.new()
	value_label.text = "%d%%" % int(slider.value)
	value_label.custom_minimum_size.x = 60
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(value: float): value_label.text = "%d%%" % int(value))
	row.add_child(value_label)

func _show_saves() -> void:
	_clear_content()
	var backdrop := ColorRect.new()
	backdrop.color = Color("#d8cfbd")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(backdrop)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 75
	panel.offset_top = 30
	panel.offset_right = -75
	panel.offset_bottom = -30
	panel.add_theme_constant_override("separation", 12)
	content.add_child(panel)
	var title := Label.new()
	title.text = "江湖行卷"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#193128"))
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "保存当前旅程，或从过去的节点继续。游戏也会在关键行动后自动存档。"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#526159"))
	panel.add_child(subtitle)
	for slot in range(1, 4):
		var saved: Dictionary = SaveManager.slot_summary(slot)
		var card := PanelContainer.new()
		card.custom_minimum_size.y = 118
		card.add_theme_stylebox_override("panel", _box(Color("#172820" if not saved.is_empty() else "#35463e")))
		panel.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		var slot_badge := Label.new()
		slot_badge.text = "%02d" % slot
		slot_badge.custom_minimum_size.x = 72
		slot_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_badge.add_theme_font_size_override("font_size", 28)
		slot_badge.add_theme_color_override("font_color", Color("#dfbf74"))
		row.add_child(slot_badge)
		var details := Label.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		details.add_theme_font_size_override("font_size", 17)
		details.add_theme_color_override("font_color", Color("#f4eee2"))
		if saved.is_empty():
			details.text = "空白行卷\n尚未写下任何江湖经历"
		else:
			details.text = "%s  ·  第 %d 周\n战力 %d    气血 %d/%d    声望 %d" % [GameState.place_name(str(saved.get("location", "qingyun"))), int(saved.get("week", 1)), int(saved.get("strength", 4)) + int(saved.get("agility", 5)) + int(saved.get("insight", 4)) + int(saved.get("constitution", 4)) + Array(saved.get("skills", [])).size() * 5, int(saved.get("hp", 45)), int(saved.get("max_hp", 45)), int(saved.get("renown", 0))]
		row.add_child(details)
		var save_button := _action_button("覆盖存档" if not saved.is_empty() else "写入存档", Color("#315f4b"))
		save_button.custom_minimum_size.x = 120
		save_button.pressed.connect(_save_slot_requested.bind(slot))
		row.add_child(save_button)
		var load_button := _action_button("继续游历", Color("#8b493b"))
		load_button.custom_minimum_size.x = 120
		load_button.disabled = saved.is_empty()
		load_button.pressed.connect(_load_slot_requested.bind(slot))
		row.add_child(load_button)

func _save_slot_requested(slot: int) -> void:
	if SaveManager.save_slot(slot):
		_rebuild()
		_toast("已保存到存档 %d。" % slot)
	else:
		_toast("存档 %d 写入失败，请检查磁盘权限。" % slot)

func _load_slot_requested(slot: int) -> void:
	if not SaveManager.load_slot(slot):
		_toast("存档 %d 读取失败或内容损坏。" % slot)
		return
	screen = _screen_after_load()
	_rebuild()

func _screen_after_load() -> String:
	if not GameState.data.battle.is_empty():
		return "battle"
	if typeof(GameState.data.get("battle_retry", {})) == TYPE_DICTIONARY and not GameState.data.battle_retry.is_empty():
		return "defeat"
	if DEMO_POLICY.is_demo_complete(GameState.data):
		return "demo_complete"
	return "map"

func _show_battle() -> void:
	_clear_content()
	if GameState.data.battle.is_empty():
		screen = "map"
		_show_map()
		return
	var battle: Dictionary = GameState.data.battle
	var view: TacticalBattleView = TACTICAL_BATTLE_VIEW.instantiate()
	content.add_child(view)
	view.setup(BATTLE_TEXTURE, battle, GameState.data, battle_mode, _battle_cell_data(battle), BATTLE_RULES.enemy_preview(battle))
	view.cell_selected.connect(_tactical_cell)
	view.mode_selected.connect(_battle_mode_selected)
	view.end_turn_requested.connect(_enemy_turn)

func _battle_mode_selected(next_mode: String) -> void:
	if next_mode == "frost_guard":
		_execute_player_action("frost_guard")
		return
	battle_mode = next_mode
	_rebuild()

func _battle_cell_data(battle: Dictionary) -> Array:
	var cells: Array = []
	for y in range(int(battle.height)):
		for x in range(int(battle.width)):
			var data := {"x": x, "y": y, "text": "·", "disabled": false, "token": -1, "color": "#1d2b25bb" if battle_mode != "inspect" else "#294438dd"}
			var cell := Vector2i(x, y)
			var boss_danger: bool = BATTLE_RULES.is_boss_sweep_cell(battle, cell)
			var move_valid: bool = battle_mode == "move" and BATTLE_RULES.can_move_to(battle, cell)
			var attack_valid: bool = battle_mode == "attack" and BATTLE_RULES.can_attack_cell(battle, cell, false, int(GameState.data.qi))
			var skill_valid: bool = battle_mode == "skill" and BATTLE_RULES.can_attack_cell(battle, cell, true, int(GameState.data.qi))
			var frost_valid: bool = battle_mode == "frost_dash" and BATTLE_RULES.can_frost_dash(battle, cell)
			if move_valid:
				data.color = "#28678aee"
			elif attack_valid:
				data.color = "#c94b3fee"
			elif skill_valid:
				data.color = "#c18b2fee"
			elif frost_valid:
				data.color = "#668fbbee"
			elif boss_danger:
				data.color = "#8f2f24ee"
			if BATTLE_RULES.is_blocked(battle, cell):
				data.text = "岩石"
				data.disabled = true
				data.color = "#4b4b45ee"
			elif x == int(battle.player_x) and y == int(battle.player_y):
				data.text = "%s%s沈羽\nAP %d" % ["⚠ " if boss_danger else "", "▶ " if str(battle.get("active_unit", "hero")) == "hero" else "", battle.ap]
				data.token = 0
				data.color = "#3d916fee" if str(battle.get("active_unit", "hero")) == "hero" else "#2f7359"
			elif BATTLE_RULES.is_ally_at(battle, cell):
				data.text = "%s%s%s\n护卫 %d" % ["⚠ " if boss_danger else "", "▶ " if str(battle.get("active_unit", "hero")) == "ally" else "", battle.ally.name, battle.ally.guard]
				data.token = 4
				data.color = "#8068a9ee" if str(battle.get("active_unit", "hero")) == "ally" else "#594a78ee"
			else:
				var enemy_index: int = BATTLE_RULES.enemy_at(battle, cell)
				if enemy_index >= 0:
					var enemy: Dictionary = battle.enemies[enemy_index]
					data.text = "%s\n%d/%d" % [enemy.name, enemy.hp, enemy.max_hp]
					data.token = 1 if enemy.name == "黑苇寨主" else (3 if "弓手" in enemy.name else 2)
					if not attack_valid and not skill_valid and not frost_valid:
						data.color = "#71322dee"
			cells.append(data)
	return cells

func _show_battle_legacy() -> void:
	_clear_content()
	if GameState.data.battle.is_empty():
		screen = "map"
		_show_map()
		return
	var art := TextureRect.new()
	art.texture = BATTLE_TEXTURE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color("#07110d55")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(shade)

	var battle: Dictionary = GameState.data.battle
	var title := Label.new()
	title.position = Vector2(30, 14)
	title.text = "%s  ·  第 %d 回合" % [battle.name, battle.turn]
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#f1e3c6"))
	content.add_child(title)
	var turn_banner := Label.new()
	turn_banner.position = Vector2(660, 14)
	turn_banner.size = Vector2(160, 36)
	turn_banner.text = "我 方 回 合"
	turn_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_banner.add_theme_font_size_override("font_size", 18)
	turn_banner.add_theme_color_override("font_color", Color("#d9f2e5"))
	turn_banner.add_theme_stylebox_override("normal", _box(Color("#27604b")))
	content.add_child(turn_banner)

	var board := GridContainer.new()
	board.columns = 8
	board.position = Vector2(30, 60)
	board.size = Vector2(790, 450)
	board.add_theme_constant_override("h_separation", 5)
	board.add_theme_constant_override("v_separation", 5)
	content.add_child(board)
	for y in range(6):
		for x in range(8):
			var position := Vector2i(x, y)
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(94, 66)
			cell.add_theme_font_size_override("font_size", 15)
			cell.add_theme_color_override("font_color", Color("#fff4dc"))
			var move_valid: bool = battle_mode == "move" and BATTLE_RULES.can_move_to(battle, position)
			var attack_valid: bool = battle_mode == "attack" and BATTLE_RULES.can_attack_cell(battle, position, false, int(GameState.data.qi))
			var skill_valid: bool = battle_mode == "skill" and BATTLE_RULES.can_attack_cell(battle, position, true, int(GameState.data.qi))
			var cell_color := Color("#1d2b25bb") if battle_mode != "inspect" else Color("#294438dd")
			if move_valid:
				cell_color = Color("#28678aee")
			elif attack_valid:
				cell_color = Color("#a33b32ee")
			elif skill_valid:
				cell_color = Color("#9a732bee")
			cell.add_theme_stylebox_override("normal", _box(cell_color))
			if BATTLE_RULES.is_blocked(battle, position):
				cell.text = "岩石"
				cell.disabled = true
				cell.add_theme_stylebox_override("disabled", _box(Color("#4b4b45ee")))
			elif x == int(battle.player_x) and y == int(battle.player_y):
				cell.text = "沈羽\nAP %d" % battle.ap
				cell.icon = _battle_token(0)
				cell.expand_icon = true
				cell.add_theme_stylebox_override("normal", _box(Color("#2f7359")))
			else:
				var enemy_index: int = BATTLE_RULES.enemy_at(battle, position)
				if enemy_index >= 0:
					var enemy: Dictionary = battle.enemies[enemy_index]
					cell.text = "%s\n%d/%d" % [enemy.name, enemy.hp, enemy.max_hp]
					cell.icon = _battle_token(1 if enemy.name == "黑苇寨主" else (3 if "弓手" in enemy.name else 2))
					cell.expand_icon = true
					if attack_valid:
						cell.add_theme_stylebox_override("normal", _box(Color("#c94b3fee")))
					elif skill_valid:
						cell.add_theme_stylebox_override("normal", _box(Color("#c18b2fee")))
					else:
						cell.add_theme_stylebox_override("normal", _box(Color("#71322dee")))
				else:
					cell.text = "·"
			cell.pressed.connect(_tactical_cell.bind(x, y))
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
		content.add_child(effect_label)
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
		content.add_child(skill_name)

	var side := PanelContainer.new()
	side.position = Vector2(840, 60)
	side.size = Vector2(400, 478)
	side.add_theme_stylebox_override("panel", _box(Color("#14271ff2")))
	content.add_child(side)
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 10)
	side.add_child(side_box)
	var status := Label.new()
	status.text = "沈羽    气血 %d/%d    真气 %d/20\n行动点 %d/2    当前：%s" % [GameState.data.hp, GameState.data.max_hp, GameState.data.qi, battle.ap, _mode_name(battle_mode)]
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
	preview.text = "敌方预判\n" + BATTLE_RULES.enemy_preview(battle)
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_theme_font_size_override("font_size", 14)
	preview.add_theme_color_override("font_color", Color("#e5c8b6"))
	side_box.add_child(preview)
	var action_grid := GridContainer.new()
	action_grid.columns = 2
	action_grid.add_theme_constant_override("h_separation", 8)
	action_grid.add_theme_constant_override("v_separation", 8)
	side_box.add_child(action_grid)
	for action in [["移动", "move"], ["普通攻击", "attack"], ["流云剑法 · 8真气", "skill"]]:
		var action_button := _action_button(action[0], Color("#8b493b") if battle_mode == action[1] else Color("#315f4b"))
		action_button.custom_minimum_size.x = 174
		action_button.disabled = int(battle.ap) <= 0 or (action[1] == "skill" and int(GameState.data.qi) < 8)
		action_button.pressed.connect(func(): battle_mode = action[1]; _rebuild())
		action_grid.add_child(action_button)
	var cancel_button := _action_button("取消选择 / 查看战场", Color("#4d5550"))
	cancel_button.custom_minimum_size.x = 174
	cancel_button.pressed.connect(func(): battle_mode = "inspect"; _rebuild())
	action_grid.add_child(cancel_button)
	var end_button := _action_button("结束回合", Color("#806c4f"))
	end_button.custom_minimum_size.x = 174
	end_button.pressed.connect(_enemy_turn)
	action_grid.add_child(end_button)
	var help := Label.new()
	help.text = "移动：两格内，消耗1行动点\n普攻：相邻敌人，消耗1行动点\n流云剑法：同一直线三格，消耗1行动点"
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color("#cfc8b8"))
	side_box.add_child(help)

func _tactical_cell(x: int, y: int) -> void:
	var battle: Dictionary = GameState.data.battle
	if x == int(battle.player_x) and y == int(battle.player_y):
		battle.active_unit = "hero"
		battle.result = "当前由沈羽行动。"
		GameState.data.battle = battle
		_rebuild()
		return
	if BATTLE_RULES.is_ally_at(battle, Vector2i(x, y)):
		battle.active_unit = "ally"
		battle.result = "当前由林清霜行动。"
		GameState.data.battle = battle
		_rebuild()
		return
	if int(battle.ap) <= 0:
		_toast("行动点已用尽，请结束回合。")
		return
	_execute_player_action(battle_mode, Vector2i(x, y))

func _execute_player_action(action: String, target: Vector2i = Vector2i.ZERO) -> void:
	var outcome: Dictionary = BATTLE_ENGINE.player_action(GameState.data.battle, GameState.data, action, target)
	if not bool(outcome.ok):
		AudioFeedback.play("error")
		_toast(str(outcome.error))
		return
	AudioFeedback.play({"move": "move", "attack": "hit", "skill": "skill", "frost_dash": "skill", "frost_guard": "turn"}.get(action, "confirm"))
	var battle: Dictionary = outcome.battle
	if _check_tactical_victory(battle):
		SaveManager.save_auto()
		_rebuild()
		return
	GameState.data.battle = battle
	SaveManager.save_auto()
	_rebuild()

func _enemy_turn() -> void:
	var battle: Dictionary = GameState.data.battle
	var outcome: Dictionary = BATTLE_ENGINE.enemy_turn(battle, int(GameState.data.hp))
	GameState.data.hp = int(outcome.hero_hp)
	if bool(outcome.hero_defeated):
		AudioFeedback.play("defeat")
		last_defeat_battle = str(battle.get("battle_id", "blackreed"))
		GameState.finish_battle(false)
		screen = "defeat"
	else:
		AudioFeedback.play("skill" if bool(outcome.get("boss_transition", false)) else ("enemy_hit" if int(outcome.total_hurt) > 0 else "turn"))
		GameState.data.battle = outcome.battle
		if _check_tactical_victory(outcome.battle):
			SaveManager.save_auto()
			_rebuild()
			return
	SaveManager.save_auto()
	_rebuild()

func _show_defeat() -> void:
	_clear_content()
	var art := TextureRect.new()
	art.texture = BATTLE_TEXTURE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color("#120b09dd")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(shade)
	var panel := VBoxContainer.new()
	panel.position = Vector2(365, 75)
	panel.size = Vector2(550, 430)
	panel.add_theme_constant_override("separation", 18)
	content.add_child(panel)
	var title := Label.new()
	title.text = "胜 负 未 定"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color("#e7c7b5"))
	panel.add_child(title)
	var summary := Label.new()
	summary.text = "沈羽力竭退出战场。\n\n你可以回到本场战斗开始时的状态，重新调整走位与目标优先级；也可以接受战败结果，回到舆图继续江湖行程。"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 19)
	summary.add_theme_color_override("font_color", Color("#f1e8dc"))
	summary.add_theme_stylebox_override("normal", _box(Color("#251a16dd")))
	panel.add_child(summary)
	var retry := _action_button("重试本场战斗 · 不额外消耗周数", Color("#8b493b"))
	retry.disabled = GameState.data.get("battle_retry", {}).is_empty()
	retry.pressed.connect(_retry_last_battle)
	panel.add_child(retry)
	var retreat := _action_button("接受战败 · 返回天下舆图", Color("#4d5550"))
	retreat.pressed.connect(_accept_battle_defeat)
	panel.add_child(retreat)

func _retry_last_battle() -> void:
	if not GameState.retry_last_battle():
		_toast("无法找到本场战斗的重试记录。")
		return
	battle_mode = "move"
	screen = "battle"
	SaveManager.save_auto()
	_rebuild()

func _accept_battle_defeat() -> void:
	GameState.abandon_battle_retry()
	last_defeat_battle = ""
	screen = "map"
	SaveManager.save_auto()
	_rebuild()

func _check_tactical_victory(battle: Dictionary) -> bool:
	if not BATTLE_ENGINE.is_victory(battle):
		return false
	AudioFeedback.play("victory")
	var battle_id: String = str(battle.get("battle_id", "blackreed"))
	if battle_id == "wuku_finale":
		last_rewards = {"title": "天 门 已 定", "story": "厉无咎的刀落在石阶上。武库机关仍在轰鸣，而决定它命运的人已经变成了你。", "xp": 60, "silver": 30, "renown": 8, "item": "武库钥印", "turns": battle.turn, "next_screen": "final_choice"}
	elif battle_id == "huashan_trial":
		last_rewards = {"title": "剑 会 胜 出", "story": "你与林清霜剑路相合，通过华山双人试炼。守台长老准许你们前往思过崖查看残图。", "xp": 30, "silver": 10, "renown": 3, "item": "思过崖通行令", "turns": battle.turn}
	else:
		last_rewards = {"title": "大 捷", "story": "黑苇寨众溃散，渡口重归平静。你从寨主身上搜出一枚玄铁令，厉千秋的阴谋终于露出端倪。", "xp": 22, "silver": 15, "renown": 4, "item": "玄铁令", "turns": battle.turn}
	GameState.finish_battle(true)
	GameState.data.quest_stage = "final_choice" if battle_id == "wuku_finale" else ("huashan_trial_complete" if battle_id == "huashan_trial" else "return_master")
	screen = "demo_complete" if DEMO_POLICY.should_end_after_victory(battle_id) else "victory"
	return true

func _show_demo_complete() -> void:
	_clear_content()
	var art := TextureRect.new()
	art.texture = MAP_TEXTURE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color("#08130de8")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(shade)
	var panel := VBoxContainer.new()
	panel.position = Vector2(310, 42)
	panel.size = Vector2(660, 500)
	panel.add_theme_constant_override("separation", 14)
	content.add_child(panel)
	var title := Label.new()
	title.text = "试 玩 章 结 束"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#f2dfb3"))
	panel.add_child(title)
	var summary := Label.new()
	summary.text = "你已完成《山河问道》试玩版纵向切片。\n\n黑苇寨主败退，玄铁令却将线索指向洛阳官府。完整版中，沈羽将走访洛阳、华山与峨眉，结识同伴，选择侠义、谋略或威势之路。"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 18)
	summary.add_theme_color_override("font_color", Color("#eee5d3"))
	summary.add_theme_stylebox_override("normal", _box(Color("#17382eee")))
	panel.add_child(summary)
	var stats := Label.new()
	stats.text = "试玩记录\n江湖周数  %d    声望  %d    调查线索  %d/3\n已解锁成就  %d/%d" % [GameState.data.week, GameState.data.renown, GameState.data.investigations.size(), SteamService.unlocked_count(), SteamService.definitions.size()]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 18)
	stats.add_theme_color_override("font_color", Color("#dfbf74"))
	panel.add_child(stats)
	var note := Label.new()
	note.text = "感谢试玩。Steam 商店页上线后，可将完整版加入愿望单。试玩存档可在完整版中继续。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color("#c9c7bc"))
	panel.add_child(note)
	var achievements := _action_button("查看已解锁成就", Color("#315746"))
	achievements.pressed.connect(func(): screen = "achievements"; _rebuild())
	panel.add_child(achievements)
	var menu := _action_button("返回主菜单", Color("#806c4f"))
	menu.pressed.connect(_show_menu)
	panel.add_child(menu)

func _mode_name(mode: String) -> String:
	return {"move": "移动", "attack": "普通攻击", "skill": "流云剑法", "inspect": "查看战场"}.get(mode, mode)

func _battle_token(index: int) -> AtlasTexture:
	var token := AtlasTexture.new()
	token.atlas = TOKEN_ATLAS
	var half: int = int(TOKEN_ATLAS.get_width() / 2.0)
	token.region = Rect2((index % 2) * half, int(index / 2.0) * half, half, half)
	return token

func _show_victory() -> void:
	_clear_content()
	var art := TextureRect.new()
	art.texture = BATTLE_TEXTURE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color("#08130ddd")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(shade)
	var panel := VBoxContainer.new()
	panel.position = Vector2(390, 65)
	panel.size = Vector2(500, 465)
	panel.add_theme_constant_override("separation", 16)
	content.add_child(panel)
	var title := Label.new()
	title.text = str(last_rewards.get("title", "大 捷"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#f2dfb3"))
	panel.add_child(title)
	var story := Label.new()
	story.text = str(last_rewards.get("story", "战斗已经结束。"))
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.add_theme_font_size_override("font_size", 18)
	story.add_theme_color_override("font_color", Color("#eee5d3"))
	panel.add_child(story)
	var rewards := Label.new()
	rewards.text = "战斗回合    %d\n修为获得    +%d\n银两获得    +%d\n声望提升    +%d\n重要物品    %s" % [last_rewards.get("turns", 0), last_rewards.get("xp", 22), last_rewards.get("silver", 15), last_rewards.get("renown", 4), last_rewards.get("item", "玄铁令")]
	rewards.add_theme_font_size_override("font_size", 20)
	rewards.add_theme_color_override("font_color", Color("#fff0d2"))
	rewards.add_theme_stylebox_override("normal", _box(Color("#17382eee")))
	panel.add_child(rewards)
	var next_screen := str(last_rewards.get("next_screen", "map"))
	var continue_button := _action_button("进入武库 · 作出最终抉择" if next_screen == "final_choice" else "收剑归鞘 · 返回天下舆图", Color("#8b493b"))
	continue_button.pressed.connect(func(): screen = next_screen; _rebuild())
	panel.add_child(continue_button)

func _begin_final_battle() -> void:
	if not GameState.start_final_battle():
		_toast(_time_action_failure_message())
		return
	battle_mode = "move"
	screen = "battle"
	SaveManager.save_auto()
	_rebuild()

func _show_final_choice() -> void:
	choice_event = "final_legacy"
	choice_prompt = "厉无咎已败。面对足以改写天下的武库，你准备留下怎样的江湖？"
	choice_options = [
		["侠义 · 毁去兵库", "击碎杀伐机关，公开证据，让各派共同见证。", "destroy"],
		["威势 · 共守盟约", "以玄铁令重立秩序，由三派共同监管武库。", "seal"],
		["谋略 · 藏锋济世", "封存兵法，只保留医理与机关术造福百姓。", "preserve"]
	]
	_show_choice()

func _show_ending() -> void:
	_clear_content()
	var ending: Dictionary = GameState.data.get("ending", {})
	var panel := VBoxContainer.new()
	panel.position = Vector2(270, 45)
	panel.size = Vector2(740, 500)
	panel.add_theme_constant_override("separation", 16)
	content.add_child(panel)
	var title := Label.new()
	title.text = "终 章 · %s" % str(ending.get("title", "山河问道"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#dfbf74"))
	panel.add_child(title)
	var rank := Label.new()
	rank.text = "结局评价：%s    完成周数：%d / 104" % [ending.get("rank", "江湖未定"), ending.get("week", GameState.data.week)]
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank.add_theme_font_size_override("font_size", 20)
	panel.add_child(rank)
	var story := Label.new()
	story.text = str(ending.get("story", "你的江湖仍在路上。"))
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.custom_minimum_size.y = 210
	story.add_theme_font_size_override("font_size", 19)
	story.add_theme_color_override("font_color", Color("#eee5d3"))
	story.add_theme_stylebox_override("normal", _box(Color("#17382eee")))
	panel.add_child(story)
	var credits := Label.new()
	credits.text = "《山河问道》主线完结\n感谢行走这段江湖。你的结局与存档已经保存。"
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_theme_color_override("font_color", Color("#c9c7bc"))
	panel.add_child(credits)
	var achievements := _action_button("查看通关成就", Color("#315746"))
	achievements.pressed.connect(func(): screen = "achievements"; _rebuild())
	panel.add_child(achievements)
	var menu := _action_button("返回主菜单", Color("#806c4f"))
	menu.pressed.connect(func(): screen = "menu"; _rebuild())
	panel.add_child(menu)

func _intent_name(intent: String) -> String:
	return {"strike": "迅猛攻势", "heavy": "两格重击", "guard": "护住要害"}.get(intent, intent)

func _intent_description(intent: String) -> String:
	return {
		"strike": "攻击相邻一格，后撤即可避开",
		"heavy": "攻击两格范围，红色区域均会受击",
		"guard": "稳守反击，适合趁机调息或积累破绽"
	}.get(intent, "观察敌人的下一步动作")

func _on_state_changed() -> void:
	_update_status()

func _on_achievement_unlocked(_api_name: String, title: String) -> void:
	if store_capture_active:
		return
	AudioFeedback.play("victory", 1.2)
	_toast("成就解锁 · %s" % title)

func _update_status() -> void:
	if status_label == null:
		return
	status_label.text = "第 %d 周 · %s\n战力 %d" % [GameState.data.week, "期限已至" if GameState.deadline_reached() else "剩余 %d 周" % GameState.weeks_left(), GameState.power()]

func _time_action_failure_message() -> String:
	return "两年之期已至，无法再进行耗时行动。" if GameState.deadline_reached() else "行动点不足，请先调息。"

func _show_contextual_tutorial() -> void:
	if store_capture_active:
		return
	active_tutorial_step = TUTORIAL_RULES.step_for(screen, GameState.data)
	if active_tutorial_step.is_empty():
		return
	var tutorial: Dictionary = TUTORIAL_RULES.content(active_tutorial_step, _quest_objective())
	if tutorial.is_empty():
		return
	var blocker := ColorRect.new()
	blocker.color = Color("#07100bbb")
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.z_index = 80
	content.add_child(blocker)
	var card := VBoxContainer.new()
	card.position = Vector2(345, 105)
	card.size = Vector2(590, 355)
	card.add_theme_constant_override("separation", 16)
	card.z_index = 81
	content.add_child(card)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color("#172820f5")))
	card.add_child(panel)
	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 14)
	panel.add_child(text_box)
	var title := Label.new()
	title.text = str(tutorial.title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#f2dfb3"))
	text_box.add_child(title)
	var body := Label.new()
	body.text = str(tutorial.body)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color("#f4eee2"))
	text_box.add_child(body)
	var continue_button := _action_button("我知道了 · 继续", Color("#8b493b"))
	continue_button.pressed.connect(_dismiss_tutorial)
	card.add_child(continue_button)
	var skip_button := Button.new()
	skip_button.text = "跳过全部新手引导"
	skip_button.flat = true
	skip_button.add_theme_color_override("font_color", Color("#c8c3b7"))
	skip_button.pressed.connect(_skip_all_tutorials)
	card.add_child(skip_button)

func _dismiss_tutorial() -> void:
	TUTORIAL_RULES.mark_seen(GameState.data, active_tutorial_step)
	active_tutorial_step = ""
	SaveManager.save_auto()
	_rebuild()

func _skip_all_tutorials() -> void:
	for step in TUTORIAL_RULES.STEPS:
		TUTORIAL_RULES.mark_seen(GameState.data, step)
	active_tutorial_step = ""
	SaveManager.save_auto()
	_rebuild()

func _reset_tutorial() -> void:
	TUTORIAL_RULES.reset(GameState.data)
	SaveManager.save_auto()
	_toast("新手引导已重置，进入舆图、青云门和战斗时将再次显示。")
	_rebuild()

func _clear_content() -> void:
	for child in content.get_children():
		child.queue_free()

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

func _toast(message: String) -> void:
	toast_label.text = message
