class_name WordPicker
extends RefCounted
## Picks words for a level. Word tiers are grades (0 = pre-school, 1..10).
## - grade mix: 75% the current grade, 15% the grade below, 10% any grade below
##   that (Tuning.WEIGHT_*)
## - growing word pool for the current grade: each grade is shuffled once per
##   game, and a stage uses the first Tuning.pool_size(stage) words of that
##   order. Stage 1 is a random set; later stages keep those words and add new
##   ones. Lower grades use all their words; higher grades (only reached as a
##   fallback in sparse languages) their stage-1 pool.
## - per-grade shuffle bag: every pool word is used before any repeats
## - never two words on screen with the same first letter
## - no repeats of the last RECENT_MEMORY words
## - failed words due for review (ReviewQueue) take priority

## tier/grade (int) -> Array[String]
var tiers: Dictionary = {}
var rng := RandomNumberGenerator.new()
var recent: Array[String] = []
var review: ReviewQueue = null
var _bags := {}   ## grade -> Array[String], remaining words in shuffled order
var _bag_n := {}  ## grade -> pool size the bag was filled for
var _order := {}  ## grade -> Array[String], this game's fixed shuffle of the grade


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


## Which grade the next word comes from (see the class comment).
func pick_tier(level: int) -> int:
	var grade := Tuning.grade_for_level(level)
	var roll := rng.randf()
	if roll < Tuning.WEIGHT_GRADE_BELOW:
		return grade - 1 if grade - 1 >= Tuning.MIN_GRADE else grade
	roll -= Tuning.WEIGHT_GRADE_BELOW
	if roll < Tuning.WEIGHT_LOWER_GRADES:
		return rng.randi_range(Tuning.MIN_GRADE, grade - 2) if grade - 2 >= Tuning.MIN_GRADE else grade
	return grade


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
	var current := Tuning.grade_for_level(level)
	# Try the wanted grade first, then spread outwards (handles sparse languages).
	for dist in range(0, Tuning.MAX_GRADE - Tuning.MIN_GRADE + 1):
		for t in _tiers_at_distance(wanted, dist):
			var w := _pick_from(t, _pool_size_for(t, level, current), blocked_initials)
			if w != "":
				_remember(w)
				return w
	return ""


func _tiers_at_distance(center: int, dist: int) -> Array[int]:
	var out: Array[int] = []
	if dist == 0:
		out.append(center)
	else:
		# Prefer easier grades first when falling back.
		for t in [center - dist, center + dist]:
			if t >= Tuning.MIN_GRADE and t <= Tuning.MAX_GRADE:
				out.append(t)
	return out


## The words of a grade in play at this level (see the class comment).
func pool(tier: int, level: int) -> Array:
	var n := _pool_size_for(tier, level, Tuning.grade_for_level(level))
	return _ordered(tier).slice(0, n)


func _pool_size_for(tier: int, level: int, current: int) -> int:
	if tier < current:
		return _ordered(tier).size()
	if tier > current:
		return Tuning.pool_size(1)
	return Tuning.pool_size(Tuning.stage_for_level(level))


func _ordered(tier: int) -> Array:
	if not _order.has(tier):
		_order[tier] = _shuffled(tiers.get(tier, []))
	return _order[tier]


func _pick_from(tier: int, pool_size: int, blocked: Dictionary) -> String:
	var order := _ordered(tier)
	if order.is_empty():
		return ""
	var n := mini(pool_size, order.size())
	var words := order.slice(0, n)
	var bag: Array = _bags.get(tier, [])
	var had := int(_bag_n.get(tier, 0))
	if n > had and had > 0:
		# The pool grew: mix the new words into the current round.
		bag.append_array(order.slice(had, n))
		bag = _shuffled(bag)
	elif n < had:
		# The pool shrank (level down): drop words that left it.
		bag = bag.filter(func(w): return words.has(w))
	_bag_n[tier] = n
	if bag.is_empty():
		bag = _shuffled(words)
	_bags[tier] = bag
	for i in bag.size():
		var w: String = bag[i]
		if not blocked.has(w[0]) and not recent.has(w):
			bag.remove_at(i)
			return w
	# Nothing usable left in this round of the bag: allow the rest of the pool.
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
