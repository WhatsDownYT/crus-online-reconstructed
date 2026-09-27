extends Reference

const HELMET = 1
const BIOSUIT = 2
const GLAND = 4
const CLUSTER = 8
const ORGAN = 16
const GOLEM = 32
const BOUNCY = 64
const ABOMINATOR = 128
const GOO = 256
const SCALEDOWN = 512
const HAZMAT = 1024
const HOLY = 2048
const STEALTH = 4096
const ALL = 8191
const IMPLANTS = {
	"Composite Helmet": HELMET,
	"CSIJ Level V Biosuit": BIOSUIT,
	"Speed Enhancer Gland": GLAND,
	"Speed Enhancer Node Cluster": CLUSTER,
	"Speed Enhancer Total Organ Package": ORGAN,
	"CSIJ Level VI Golem Exosystem": GOLEM,
	"Bouncy Suit": BOUNCY,
	"Abominator": ABOMINATOR,
	"Goo Overdrive": GOO,
	"Cortical Scaledown+": SCALEDOWN,
	"Hazmat Suit": HAZMAT,
	"Holy Scope": HOLY,
	"Stealth Suit+": STEALTH
}
const BLOCK = 8000
var reverse_input = []
var reverse_output = []
var reverse_cursor = 0
var reverse_count = 0
var sample_time = 0
var reverse_active = false

static func mask_for(implants, upside_down, helmet_broken = false):
	var mask = 0
	for implant in implants:
		if implant.jammed: continue
		mask |= IMPLANTS.get(implant.i_name, 0)
	if not upside_down: mask &= ~ABOMINATOR
	if helmet_broken: mask &= ~HELMET
	return mask

static func pitch(mask, seconds):
	var scale = 1.0
	if mask & GLAND: scale *= 1.06
	if mask & CLUSTER: scale *= 1.16
	if mask & ORGAN: scale *= 1.32
	if mask & SCALEDOWN: scale *= 1.4
	if mask & BOUNCY: scale *= 0.9
	if mask & GOO: scale *= 1.0 + 0.1 * sin(seconds * TAU * 3.0)
	return scale

static func cutoff(mask):
	if mask & BIOSUIT: return 650.0
	if mask & HAZMAT: return 4200.0
	if mask & HELMET: return 6200.0
	return 16000.0

func reset():
	reverse_input.resize(0)
	reverse_output.resize(0)
	reverse_cursor = 0
	reverse_count = 0
	sample_time = 0
	reverse_active = false

func process(frames, mask):
	var reverse = (mask & ABOMINATOR) != 0
	if reverse != reverse_active:
		reset()
		reverse_active = reverse
		if reverse: reverse_input.resize(BLOCK)
	if reverse:
		var output = PoolVector2Array()
		output.resize(frames.size())
		for i in range(frames.size()):
			output[i] = reverse_output[reverse_cursor] if reverse_cursor < reverse_output.size() else Vector2.ZERO
			reverse_cursor += 1
			reverse_input[reverse_count] = frames[i]
			reverse_count += 1
			if reverse_count == BLOCK:
				reverse_output = reverse_input
				reverse_output.invert()
				reverse_input = []
				reverse_input.resize(BLOCK)
				reverse_count = 0
				reverse_cursor = 0
		frames = output
	if mask & HOLY:
		for i in range(frames.size()):
			var carrier = 0.2 + 0.8 * sin(TAU * 110.0 * float(sample_time) / 16000.0)
			frames[i] *= carrier
			sample_time += 1
	return frames
