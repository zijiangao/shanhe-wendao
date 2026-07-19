class_name CueSynth
extends RefCounted

const MIX_RATE := 22050

const CUES := {
	"confirm": {"frequency": 660.0, "duration": 0.075, "volume": 0.18, "wave": "sine"},
	"error": {"frequency": 150.0, "duration": 0.16, "volume": 0.22, "wave": "square"},
	"move": {"frequency": 310.0, "duration": 0.11, "volume": 0.17, "wave": "noise"},
	"hit": {"frequency": 105.0, "duration": 0.18, "volume": 0.32, "wave": "noise"},
	"skill": {"frequency": 880.0, "duration": 0.32, "volume": 0.24, "wave": "sine", "sweep": 0.65},
	"enemy_hit": {"frequency": 82.0, "duration": 0.24, "volume": 0.34, "wave": "square"},
	"heavy_hit": {"frequency": 64.0, "duration": 0.31, "volume": 0.38, "wave": "noise", "sweep": -0.28},
	"turn": {"frequency": 440.0, "duration": 0.12, "volume": 0.16, "wave": "triangle"},
	"victory": {"frequency": 523.25, "duration": 0.55, "volume": 0.23, "wave": "sine", "sweep": 0.5},
	"defeat": {"frequency": 196.0, "duration": 0.55, "volume": 0.22, "wave": "triangle", "sweep": -0.55},
	"training_perfect": {"frequency": 784.0, "duration": 0.22, "volume": 0.22, "wave": "sine", "sweep": 0.45},
	"training_good": {"frequency": 587.33, "duration": 0.16, "volume": 0.19, "wave": "triangle", "sweep": 0.2},
	"training_ok": {"frequency": 392.0, "duration": 0.12, "volume": 0.16, "wave": "triangle"},
	"training_miss": {"frequency": 130.81, "duration": 0.2, "volume": 0.2, "wave": "square", "sweep": -0.25},
	"training_result": {"frequency": 523.25, "duration": 0.48, "volume": 0.22, "wave": "sine", "sweep": 0.6}
}

static func make_cue(cue: String) -> AudioStreamWAV:
	var spec: Dictionary = CUES.get(cue, CUES.confirm)
	return make_tone(float(spec.frequency), float(spec.duration), float(spec.volume), str(spec.wave), float(spec.get("sweep", 0.0)))

static func make_tone(frequency: float, duration: float, volume: float, wave: String = "sine", sweep: float = 0.0) -> AudioStreamWAV:
	var safe_duration := clampf(duration, 0.02, 2.0)
	var sample_count := maxi(1, int(MIX_RATE * safe_duration))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5348414E
	var phase := 0.0
	for index in range(sample_count):
		var progress := float(index) / float(sample_count)
		var current_frequency := maxf(30.0, frequency * (1.0 + sweep * progress))
		phase += TAU * current_frequency / float(MIX_RATE)
		var oscillator := _wave_sample(wave, phase, rng)
		var attack := minf(1.0, progress / 0.06)
		var decay := pow(1.0 - progress, 2.2)
		var sample := clampi(int(oscillator * attack * decay * clampf(volume, 0.0, 1.0) * 32767.0), -32768, 32767)
		bytes.encode_s16(index * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream

static func make_ambience(duration: float = 12.0) -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * clampf(duration, 2.0, 30.0))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var notes := [110.0, 146.83, 164.81, 220.0]
	for index in range(sample_count):
		var time := float(index) / float(MIX_RATE)
		var segment := int(time / 3.0) % notes.size()
		var blend := 0.5 - 0.5 * cos(TAU * fmod(time, 3.0) / 3.0)
		var first: float = notes[segment]
		var second: float = notes[(segment + 1) % notes.size()]
		var value := sin(TAU * first * time) * (1.0 - blend) + sin(TAU * second * time) * blend
		value += sin(TAU * 55.0 * time) * 0.45
		var sample := clampi(int(value * 0.055 * 32767.0), -32768, 32767)
		bytes.encode_s16(index * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream

static func _wave_sample(wave: String, phase: float, rng: RandomNumberGenerator) -> float:
	match wave:
		"square": return 1.0 if sin(phase) >= 0.0 else -1.0
		"triangle": return asin(sin(phase)) * 2.0 / PI
		"noise": return rng.randf_range(-1.0, 1.0)
		_: return sin(phase)
