extends Reference

const RATE = 16000
const FRAMES = 320
const BYTES = 163
const STEPS = [7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767]
const SHIFTS = [-1,-1,-1,-1,2,4,6,8]

static func encode(samples):
	var data = PoolByteArray()
	if samples.size() != FRAMES:
		return data
	data.resize(BYTES)
	var predictor = int(clamp(samples[0], -1.0, 1.0) * 32767.0)
	var index = 40
	data[0] = predictor & 255
	data[1] = (predictor >> 8) & 255
	data[2] = index
	for i in range(1, FRAMES):
		var diff = int(clamp(samples[i], -1.0, 1.0) * 32767.0) - predictor
		var code = 8 if diff < 0 else 0
		diff = abs(diff)
		var step = STEPS[index]
		var change = step >> 3
		if diff >= step:
			code |= 4
			diff -= step
			change += step
		step >>= 1
		if diff >= step:
			code |= 2
			diff -= step
			change += step
		step >>= 1
		if diff >= step:
			code |= 1
			change += step
		predictor = int(clamp(predictor + (-change if code & 8 else change), -32768, 32767))
		index = int(clamp(index + SHIFTS[code & 7], 0, 88))
		var offset = 3 + ((i - 1) >> 1)
		if (i - 1) & 1:
			data[offset] |= code << 4
		else:
			data[offset] = code
	return data

static func decode(data):
	var frames = PoolVector2Array()
	if typeof(data) != TYPE_RAW_ARRAY or data.size() != BYTES or data[2] > 88:
		return frames
	var predictor = int(data[0]) | (int(data[1]) << 8)
	if predictor >= 32768:
		predictor -= 65536
	var index = int(data[2])
	frames.resize(FRAMES)
	frames[0] = Vector2.ONE * (predictor / 32768.0)
	for i in range(1, FRAMES):
		var code = (int(data[3 + ((i - 1) >> 1)]) >> (4 if (i - 1) & 1 else 0)) & 15
		var step = STEPS[index]
		var change = (step >> 3) + (step if code & 4 else 0) + ((step >> 1) if code & 2 else 0) + ((step >> 2) if code & 1 else 0)
		predictor = int(clamp(predictor + (-change if code & 8 else change), -32768, 32767))
		index = int(clamp(index + SHIFTS[code & 7], 0, 88))
		frames[i] = Vector2.ONE * (predictor / 32768.0)
	return frames
