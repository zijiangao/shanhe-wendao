class_name OnboardingSpec
extends RefCounted

const NEW_GAME_SCREEN := "location"
const OPENING_RETURN_SCREEN := "map"
const OPENING_DIALOGUE := [
	["顾长风", "黑苇渡商旅失踪。你先查清两条线索，再决定如何攻寨。"],
	["沈羽", "弟子领命。先察后动，绝不让无辜之人卷入。"]
]
const FIRST_CLUES := {
	"clue_fisher": [["老渔翁", "寨众夜里避开灯火，从北面芦荡的水道进出。暗道就在岸边。"]],
	"clue_tracks": [["沈羽", "脚印旁有箭羽刮痕。寨中藏有弓手，交战时应优先处理。"]]
}

static func dialogue_for(event_id: String) -> Array:
	return Array(FIRST_CLUES.get(event_id, [])).duplicate(true)

