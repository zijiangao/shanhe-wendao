class_name OnboardingSpec
extends RefCounted

const NEW_GAME_SCREEN := "location"
const OPENING_RETURN_SCREEN := "map"
const OPENING_DIALOGUE := [
	["顾长风", "黑苇渡商旅失踪。若你愿意，可查访此事；何时动身、先游历何处，都由你决定。"],
	["沈羽", "弟子愿接下这桩委托，也会自行走访各地，先察后动。"]
]
const FIRST_CLUES := {
	"clue_fisher": [["老渔翁", "寨众夜里避开灯火，从北面芦荡的水道进出。暗道就在岸边。"]],
	"clue_tracks": [["沈羽", "脚印旁有箭羽刮痕。寨中藏有弓手，交战时应优先处理。"]]
}

static func dialogue_for(event_id: String) -> Array:
	return Array(FIRST_CLUES.get(event_id, [])).duplicate(true)

