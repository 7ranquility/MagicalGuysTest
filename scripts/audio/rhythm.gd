class_name Rhythm
extends RefCounted
## Converts weapon cooldowns into rhythms on the 16th-note grid.
##
## A cooldown in seconds becomes "k hits per cycle" (cycle = 64 steps = 4 bars) for the
## current tempo, laid out as a Euclidean rhythm. Faster cooldowns mean more hits per
## cycle, so balance is tempo independent while every hit lands on a grid step.

const CYCLE: int = 64
const ROUND_HITS: PackedInt32Array = [1, 2, 4, 8, 16, 32, 64]


## Number of hits per 64-step cycle for a cooldown at the given step duration.
static func hits_for_cooldown(cooldown: float, step_dur: float) -> int:
	var exact: float = float(CYCLE) * step_dur / maxf(cooldown, 0.01)
	for p: int in ROUND_HITS:
		if absf(exact - float(p)) / float(p) < 0.1:
			return p
	return clampi(roundi(exact), 1, CYCLE)


## Euclidean rhythm: k hits spread as evenly as possible over n steps, first hit on step 0.
static func euclid(k: int, n: int = CYCLE) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(n)
	k = clampi(k, 0, n)
	for i: int in n:
		out[i] = 1 if (i * k) % n < k else 0
	return out


## Effective seconds between hits of a rhythm with k hits per cycle.
static func period(k: int, step_dur: float) -> float:
	return float(CYCLE) * step_dur / float(maxi(k, 1))
