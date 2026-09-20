extends TacticalBattleView

signal release_animation
var waiting := false

func play_enemy_events(_events: Array) -> void:
	waiting = true
	await release_animation
