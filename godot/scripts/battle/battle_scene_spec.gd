class_name BattleSceneSpec
extends RefCounted

const FALLBACK_ID := "blackreed"
const SCENES := {
	"blackreed": {"texture": "res://assets/art/luoyang-battle-rain.png", "title": "黑苇渡 · 暴雨夜", "shade": "#07110d55", "accent": "#27604b"},
	"huashan_trial": {"texture": "res://assets/art/locations/huashan-terrace.png", "title": "华山剑坪 · 云海日光", "shade": "#10203348", "accent": "#496b8a"},
	"wuku_finale": {"texture": "res://assets/art/locations/emei-summit.png", "title": "武库天门 · 金色封印", "shade": "#24150870", "accent": "#8a5b31"}
}

static func scene_for(battle_id: String) -> Dictionary:
	return Dictionary(SCENES.get(battle_id, SCENES[FALLBACK_ID])).duplicate(true)

