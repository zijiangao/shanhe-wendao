class_name CharacterPortraits
extends RefCounted

# Only exact character identities share a portrait. In particular, 厉无咎
# must never inherit 厉千秋's painting just because they share a surname.
const PORTRAIT_PATHS := {
	"沈羽": "res://assets/art/portrait-shen-yu.png",
	"顾长风": "res://assets/art/portrait-gu-changfeng.png",
	"林清霜": "res://assets/art/portrait-lin-qingshuang.png",
	"苏晚晴": "res://assets/art/portrait-su-wanqing.png",
	"厉千秋": "res://assets/art/portrait-li-qianqiu.png",
	"周慕白": "res://assets/art/portrait-zhou-mubai.png",
	"柳如烟": "res://assets/art/portrait-liu-ruyan.png",
}

static func for_speaker(speaker_name: String) -> Texture2D:
	var path: String = str(PORTRAIT_PATHS.get(speaker_name.strip_edges(), ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
