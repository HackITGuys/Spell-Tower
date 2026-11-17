extends SpellTestSuite
## Grade mix, word pools and the shuffle bag.


func test_word_picker() -> void:
	var tiers := {}
	for t in range(Tuning.MIN_GRADE, Tuning.MAX_GRADE + 1):
		var ws: Array = []
		for c in "abcdefghij":
			ws.append(c + "word" + str(t))
		tiers[t] = ws
	var p := WordPicker.new(tiers, 1234)
	var counts := {}
	var n := 4000
	var lvl5 := Tuning.first_level_of_grade(5)
	for i in n:
		var t := p.pick_tier(lvl5)
		counts[t] = counts.get(t, 0) + 1
	var share := func(grades: Array) -> float:
		var c := 0
		for g in grades:
			c += counts.get(g, 0)
		return c / float(n)
	check(absf(share.call([5]) - 0.75) < 0.03, "current grade ~75%% (got %.2f)" % share.call([5]))
	check(absf(share.call([4]) - 0.15) < 0.03, "grade below ~15%% (got %.2f)" % share.call([4]))
	check(absf(share.call([0, 1, 2, 3]) - 0.10) < 0.03, "all lower grades ~10%% (got %.2f)" % share.call([0, 1, 2, 3]))
	for g in [0, 1, 2, 3]:
		check(counts.get(g, 0) > 0, "grade %d is reachable from grade 5" % g)
	check(share.call([6, 7, 8, 9, 10]) == 0.0, "never a harder grade")
	# Near the bottom the missing shares go to the current grade.
	var g1 := {}
	for i in n:
		var t := p.pick_tier(Tuning.first_level_of_grade(1))
		g1[t] = g1.get(t, 0) + 1
	check(absf(g1.get(0, 0) / float(n) - 0.15) < 0.03, "grade 1: pre-school ~15%%")
	check(absf(g1.get(1, 0) / float(n) - 0.85) < 0.03, "grade 1: own grade gets the rest")
	for i in 200:
		check(p.pick_tier(1) == 0, "pre-school only uses pre-school")
		check(p.pick_tier(Tuning.MAX_LEVEL) <= Tuning.MAX_GRADE, "grade clamped")
	var blocked := {"a": true, "b": true, "c": true}
	for i in 100:
		var w := p.pick(3, blocked)
		check(w != "" and not blocked.has(w[0]), "blocked initials respected")
	var all_blocked := {}
	for c in "abcdefghij":
		all_blocked[c] = true
	check(p.pick(3, all_blocked) == "", "returns empty when all initials blocked")
	# Recent words are not repeated while alternatives exist.
	var p2 := WordPicker.new({1: ["aa", "bb", "cc", "dd", "ee", "ff", "gg", "hh", "ii", "jj", "kk", "ll", "mm", "nn", "oo", "pp", "qq", "rr", "ss", "tt"]}, 7)
	var seen := {}
	for i in Tuning.RECENT_MEMORY:
		var w := p2.pick(1)
		check(not seen.has(w), "no repeat within recent memory (%s)" % w)
		seen[w] = true
	# Sparse language: only tier 1 exists, level 8 must still find words.
	var p3 := WordPicker.new({1: ["xa", "xb"]}, 1)
	check(p3.pick(8) != "", "falls back to nearest populated tier")


func test_word_pools() -> void:
	var words: Array = []
	for i in 200:
		words.append("%c%03d" % [97 + i % 26, i])
	# Grade 0 holds the test words, so levels 1..5 are its stages 1..5.
	var p := WordPicker.new({0: words, 1: words.map(func(w): return "z" + w)}, 5)
	var prev: Array = []
	for stage in range(1, Tuning.STAGES_PER_GRADE + 1):
		var pool := p.pool(0, stage)
		check(pool.size() == Tuning.pool_size(stage), "stage %d pool size %d" % [stage, pool.size()])
		check(pool.slice(0, prev.size()) == prev, "stage %d keeps the earlier words" % stage)
		prev = pool
	check(Tuning.pool_size(1) < Tuning.pool_size(Tuning.STAGES_PER_GRADE), "pool grows over the stages")
	check(p.pool(0, Tuning.first_level_of_grade(1)).size() == words.size(), "a lower grade uses all its words")
	check(p.pool(1, 1).size() == Tuning.pool_size(1), "a higher grade uses its first pool")
	# Picks stay inside the stage's pool.
	var p1 := {}
	for w in p.pool(0, 1):
		p1[w] = true
	var outside := 0
	for i in 100:
		var w := p.pick(1)
		if not p1.has(w):
			outside += 1
	check(outside == 0, "stage 1 picks only from its pool (%d outside)" % outside)
	# Moving to stage 2 introduces the new words.
	var p2 := {}
	for w in p.pool(0, 2):
		if not p1.has(w):
			p2[w] = true
	var fresh := 0
	for i in Tuning.POOL_GROWTH:
		if p2.has(p.pick(2)):
			fresh += 1
	check(fresh > 0, "new stage brings new words (%d)" % fresh)
	# Small grades: the pool is the whole grade.
	var small := WordPicker.new({0: ["ab", "cd", "ef"]}, 1)
	check(small.pool(0, 1).size() == 3, "pool capped at grade size")
	check(small.pick(1) != "", "small grade still picks")
	# Different games get different random sets.
	var a := WordPicker.new({0: words}, 1).pool(0, 1)
	var b := WordPicker.new({0: words}, 2).pool(0, 1)
	check(a != b, "random starting set per game")


func test_shuffle_bag() -> void:
	var words: Array = []
	for i in 60:
		words.append("w%02d" % i)
	# Only one tier, so every pick comes from it. Stage 5 = pool of 60 words.
	var lvl := Tuning.STAGES_PER_GRADE
	check(Tuning.pool_size(lvl) >= words.size(), "stage 5 pool covers the test grade")
	var p := WordPicker.new({0: words}, 99)
	var seen := {}
	var repeats := 0
	for i in words.size():
		var w := p.pick(lvl)
		if seen.has(w):
			repeats += 1
		seen[w] = true
	check(repeats == 0, "no repeats until the whole tier was used (%d repeats)" % repeats)
	check(seen.size() == words.size(), "every word of the tier used once")
	var w2 := p.pick(lvl)
	check(w2 != "", "bag refills")
