class_name WordPicker
extends RefCounted
## Picks words for a level:
## - weighted around the level's tier (TIER_WEIGHTS)
## - per-tier shuffle bag: every word of a tier is used before any repeats
## - never two words on screen with the same first letter
## - no repeats of the last RECENT_MEMORY words
## - failed words due for review (ReviewQueue) take priority

## tier (int) -> Array[String]
var tiers: Dictionary = {}
var rng := RandomNumberGenerator.new()
var recent: Array[String] = []
var review: ReviewQueue = null
var _bags := {}   ## tier -> Array[String], remaining words in shuffled order


func _init(p_tiers: Dictionary, seed_value: int = -1) -> void:
	tiers = p_tiers
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func has_words() -> bool:
	for t in tiers:
		if not tiers[t].is_empty():
			return true
	return false


## Weighted tier choice around the level (TIER_WEIGHTS), clamped to MIN..MAX.
func pick_tier(level: int) -> int:
	var base := Tuning.tier_for_level(level)
	var roll := rng.randf()
	var acc := 0.0
	for offset in Tuning.TIER_WEIGHTS:
		acc += Tuning.TIER_WEIGHTS[offset]
		if roll <= acc:
			return clampi(base + offset, Tuning.MIN_TIER, Tuning.MAX_TIER)
	return base


## blocked_initials: Dictionary of first letters already on screen.
## Returns "" if nothing fits.
func pick(level: int, blocked_initials: Dictionary = {}) -> String:
	if review != null:
		review.tick()
		var r := review.take_due(blocked_initials)
		if r != "":
			_remember(r)
			return r
	var wanted := pick_tier(level)
	# Try the wanted tier first, then spread outwards (handles sparse languages).
	for dist in range(0, Tuning.MAX_TIER):
		for t in _tiers_at_distance(wanted, dist):
			var w := _pick_from(t, blocked_initials)
			if w != "":
				_remember(w)
				return w
	return ""


func _tiers_at_distance(center: int, dist: int) -> Array[int]:
	var out: Array[int] = []
	if dist == 0:
		out.append(center)
	else:
		# Prefer easier tiers first when falling back.
		for t in [center - dist, center + dist]:
			if t >= Tuning.MIN_TIER and t <= Tuning.MAX_TIER:
				out.append(t)
	return out


func _pick_from(tier: int, blocked: Dictionary) -> String:
	var words: Array = tiers.get(tier, [])
	if words.is_empty():
		return ""
	var bag: Array = _bags.get(tier, [])
	if bag.is_empty():
		bag = _shuffled(words)
		_bags[tier] = bag
	for i in bag.size():
		var w: String = bag[i]
		if not blocked.has(w[0]) and not recent.has(w):
			bag.remove_at(i)
			return w
	# Nothing usable left in this round of the bag: allow the rest of the tier.
	for w: String in _shuffled(words):
		if not blocked.has(w[0]) and not recent.has(w):
			return w
	for w: String in _shuffled(words):
		if not blocked.has(w[0]):
			return w
	return ""


func _shuffled(words: Array) -> Array:
	var a := words.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a


func _remember(w: String) -> void:
	recent.append(w)
	while recent.size() > Tuning.RECENT_MEMORY:
		recent.pop_front()
