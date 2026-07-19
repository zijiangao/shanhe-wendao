extends SceneTree

const SYNTH := preload("res://scripts/audio/cue_synth.gd")

func _initialize() -> void:
	for cue in SYNTH.CUES:
		var stream: AudioStreamWAV = SYNTH.make_cue(cue)
		assert(stream.format == AudioStreamWAV.FORMAT_16_BITS, "%s should use 16-bit PCM." % cue)
		assert(stream.mix_rate == SYNTH.MIX_RATE, "%s should use the shared sample rate." % cue)
		assert(stream.data.size() > 100, "%s should contain audible sample data." % cue)
		assert(_has_nonzero_sample(stream.data), "%s must not be silent." % cue)
	var first: AudioStreamWAV = SYNTH.make_cue("hit")
	var second: AudioStreamWAV = SYNTH.make_cue("hit")
	assert(first.data == second.data, "Procedural cues must be deterministic across runs.")
	var ambience: AudioStreamWAV = SYNTH.make_ambience(2.0)
	assert(ambience.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Ambient bed should loop seamlessly at runtime.")
	assert(ambience.loop_end > ambience.loop_begin, "Ambient loop needs a valid sample range.")

	print("CueSynth tests passed.")
	quit()

func _has_nonzero_sample(bytes: PackedByteArray) -> bool:
	for index in range(0, bytes.size() - 1, 2):
		if bytes.decode_s16(index) != 0:
			return true
	return false
