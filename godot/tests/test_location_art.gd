extends SceneTree

const LOCATION_ART := [
	"res://assets/art/locations/qingyun-courtyard.png",
	"res://assets/art/locations/luoyang-market.png",
	"res://assets/art/locations/huashan-terrace.png",
	"res://assets/art/locations/emei-summit.png"
]

func _initialize() -> void:
	for path in LOCATION_ART:
		assert(ResourceLoader.exists(path, "Texture2D"), "Every commercial location background must be imported: %s" % path)
		var texture := load(path) as Texture2D
		assert(texture != null, "Location art must load as a Godot texture: %s" % path)
		assert(texture.get_width() >= 1280 and texture.get_height() >= 720, "Location art must support the shipping viewport without upscaling: %s" % path)
		var ratio := float(texture.get_width()) / float(texture.get_height())
		assert(absf(ratio - (16.0 / 9.0)) < 0.03, "Location art should stay close to 16:9 to avoid destructive cropping: %s" % path)
	print("Location art tests passed.")
	quit()
