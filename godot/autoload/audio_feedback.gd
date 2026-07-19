extends Node

const CUE_SYNTH := preload("res://scripts/audio/cue_synth.gd")
const PLAYER_COUNT := 6

var cue_cache: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var music_player: AudioStreamPlayer

func _ready() -> void:
	for index in range(PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "SFX%d" % index
		player.bus = &"SFX"
		add_child(player)
		players.append(player)
	music_player = AudioStreamPlayer.new()
	music_player.name = "AmbientMusic"
	music_player.bus = &"Music"
	music_player.volume_db = -8.0
	music_player.stream = CUE_SYNTH.make_ambience()
	add_child(music_player)
	if not _is_headless():
		music_player.play()
	get_tree().node_added.connect(_on_node_added)
	_wire_existing_buttons()

func play(cue: String, pitch_scale: float = 1.0) -> void:
	if players.is_empty() or _is_headless():
		return
	if not cue_cache.has(cue):
		cue_cache[cue] = CUE_SYNTH.make_cue(cue)
	var player := players[next_player]
	next_player = (next_player + 1) % players.size()
	player.stop()
	player.stream = cue_cache[cue]
	player.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
	player.play()

func _wire_existing_buttons() -> void:
	for node in get_tree().root.find_children("*", "BaseButton", true, false):
		_wire_button(node as BaseButton)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_wire_button.call_deferred(node as BaseButton)

func _wire_button(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button) or button.has_meta("audio_feedback_wired"):
		return
	button.set_meta("audio_feedback_wired", true)
	button.pressed.connect(play.bind("confirm", 1.0))

func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
