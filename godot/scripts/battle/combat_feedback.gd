class_name CombatFeedback
extends RefCounted

const PROFILES := {
	"guard": {"shake": 0.0, "flash_alpha": 0.0, "flash": "#9bc7b2", "cue": "turn", "pitch": 1.1},
	"light": {"shake": 4.0, "flash_alpha": 0.09, "flash": "#fff2cf", "cue": "enemy_hit", "pitch": 1.05},
	"normal": {"shake": 6.0, "flash_alpha": 0.14, "flash": "#ffd9bd", "cue": "enemy_hit", "pitch": 0.95},
	"heavy": {"shake": 10.0, "flash_alpha": 0.22, "flash": "#ffb29a", "cue": "heavy_hit", "pitch": 0.82},
	"skill": {"shake": 9.0, "flash_alpha": 0.20, "flash": "#d8fff0", "cue": "skill", "pitch": 1.0}
}

static func profile(level: String) -> Dictionary:
	return Dictionary(PROFILES.get(level, PROFILES.normal)).duplicate(true)

static func for_player_effect(effect: Dictionary) -> Dictionary:
	var effect_type := str(effect.get("type", "damage"))
	if effect_type == "guard":
		return profile("guard")
	if effect_type == "skill":
		return profile("skill")
	return profile("light")

static func for_enemy_hit(event: Dictionary) -> Dictionary:
	if int(event.get("damage", 0)) <= 0 and int(event.get("blocked", 0)) > 0:
		return profile("guard")
	return profile(str(event.get("impact", "normal")))
