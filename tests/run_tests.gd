extends SceneTree
## Headless logic tests:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits 0 when everything passes, 1 otherwise.

var _checks := 0
var _failures := 0
var _section := ""


func _initialize() -> void:
	_test_manifest_and_word_files()
	_test_text_norm()
	_test_word_picker()
	_test_targeting()
	_test_score_model()
	_test_power_ups()
	_test_shuffle_bag()
	_test_review_queue()
	_test_palettes()
	_test_profiles()
	_test_sfx()
	_test_translations()
	_test_tuning()
	print("")
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("  FAIL [%s] %s" % [_section, msg])


func _begin(name: String) -> void:
	_section = name
	print("- " + name)


class Item:
	var text := ""
	var typed := 0
	var y := 0.0
	var alive := true

	func _init(t: String, p_y: float) -> void:
		text = t
		y = p_y


# ---------------------------------------------------------------------------

func _new_bank() -> Node:
	var wb: Node = load("res://scripts/autoload/word_bank.gd").new()
	wb.load_manifest()
	return wb


func _test_manifest_and_word_files() -> void:
	_begin("manifest + word files")
	var wb := _new_bank()
	_check(wb.languages.size() >= 1, "manifest has languages")
	_check(wb.has_language("en"), "english present")
	for def: Dictionary in wb.languages:
		var code: String = def["code"]
		var alpha: String = def["alphabet"]
		for row: String in def["keyboard"]:
			for i in row.length():
				_check(alpha.contains(row[i]), "%s keyboard key '%s' in alphabet" % [code, row[i]])
		for i in alpha.length():
			var on_kb := false
			for row: String in def["keyboard"]:
				on_kb = on_kb or row.contains(alpha[i])
			_check(on_kb, "%s alphabet letter '%s' reachable on keyboard" % [code, alpha[i]])
		_check(wb.load_language(code), "%s loads" % code)
		_check(wb.entries.size() > 0, "%s has words" % code)
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(def["word_file"]))
		var seen := {}
		var total := 0
		for t in raw["tiers"]:
			for w: String in raw["tiers"][t]:
				total += 1
				_check(not seen.has(w), "%s duplicate word '%s'" % [code, w])
				seen[w] = true
				_check(w == w.to_lower(), "%s '%s' is lowercase" % [code, w])
				for i in w.length():
					var cp := w.unicode_at(i)
					_check(cp < 0x300 or cp > 0x36F, "%s '%s' has no combining marks (NFC)" % [code, w])
		_check(wb.entries.size() == total, "%s every word accepted by alphabet" % code)
		for c in raw.get("concepts", {}):
			_check(seen.has(c), "%s concept word '%s' exists" % [code, c])
	wb.load_language("en")
	var tiers: Dictionary = wb.build_tiers()
	for t in range(Tuning.MIN_TIER, Tuning.MAX_TIER + 1):
		_check(tiers.has(t) and tiers[t].size() >= 120, "en tier %d has >= 120 words" % t)
	_check(wb.entries["cat"]["id"] == "en:cat", "ids are lang-prefixed")
	_check(wb.concept_of("cat") == "animal.cat", "concept lookup")
	wb.free()


func _test_text_norm() -> void:
	_begin("text normalisation")
	var nb := TextNorm.new({"alphabet": "abcdefghijklmnopqrstuvwxyzæøå", "equivalents": {"ä": "æ", "ö": "ø"}})
	_check(nb.normalize_char("Å") == "å", "uppercase Å -> å")
	_check(nb.normalize_char("Ø") == "ø", "uppercase Ø -> ø")
	_check(nb.normalize_char("ä") == "æ", "equivalent ä -> æ")
	_check(nb.normalize_char("Ö") == "ø", "equivalent Ö -> ø")
	_check(nb.normalize_char("1") == "", "digits ignored")
	_check(nb.normalize_char(" ") == "", "space ignored")
	_check(nb.is_valid_word("blåbær"), "blåbær valid")
	var en := TextNorm.new({"alphabet": "abcdefghijklmnopqrstuvwxyz"})
	_check(en.normalize_char("å") == "", "å not in english alphabet")
	_check(en.normalize_char("Q") == "q", "Q -> q")
	var tr_ := TextNorm.new({"alphabet": "abcçdefgğhıijklmnoöprsştuüvyz", "casefold": {"I": "ı", "İ": "i"}})
	_check(tr_.normalize_char("I") == "ı", "turkish casefold I -> ı")
	_check(tr_.normalize_char("İ") == "i", "turkish casefold İ -> i")


func _test_word_picker() -> void:
	_begin("word picker")
	var tiers := {}
	for t in range(1, 11):
		var ws: Array = []
		for c in "abcdefghij":
			ws.append(c + "word" + str(t))
		tiers[t] = ws
	var p := WordPicker.new(tiers, 1234)
	var counts := {}
	var n := 4000
	for i in n:
		var t := p.pick_tier(5)
		counts[t] = counts.get(t, 0) + 1
	_check(absf(counts.get(5, 0) / float(n) - 0.60) < 0.04, "tier L ~60%% (got %.2f)" % (counts.get(5, 0) / float(n)))
	_check(absf(counts.get(4, 0) / float(n) - 0.25) < 0.04, "tier L-1 ~25 percent")
	_check(absf(counts.get(6, 0) / float(n) - 0.15) < 0.04, "tier L+1 ~15 percent")
	_check(counts.size() == 3, "only three tiers used")
	for i in 200:
		_check(p.pick_tier(1) >= 1 and p.pick_tier(10) <= 10, "tier clamped")
	var blocked := {"a": true, "b": true, "c": true}
	for i in 100:
		var w := p.pick(3, blocked)
		_check(w != "" and not blocked.has(w[0]), "blocked initials respected")
	var all_blocked := {}
	for c in "abcdefghij":
		all_blocked[c] = true
	_check(p.pick(3, all_blocked) == "", "returns empty when all initials blocked")
	# Recent words are not repeated while alternatives exist.
	var p2 := WordPicker.new({1: ["aa", "bb", "cc", "dd", "ee", "ff", "gg", "hh", "ii", "jj", "kk", "ll", "mm", "nn", "oo", "pp", "qq", "rr", "ss", "tt"]}, 7)
	var seen := {}
	for i in Tuning.RECENT_MEMORY:
		var w := p2.pick(1)
		_check(not seen.has(w), "no repeat within recent memory (%s)" % w)
		seen[w] = true
	# Sparse language: only tier 1 exists, level 8 must still find words.
	var p3 := WordPicker.new({1: ["xa", "xb"]}, 1)
	_check(p3.pick(8) != "", "falls back to nearest populated tier")


func _test_targeting() -> void:
	_begin("targeting")
	var t := Targeting.new()
	var cat := Item.new("cat", 100.0)
	var cow := Item.new("cow", 300.0)  # closer to base
	var dog := Item.new("dog", 200.0)
	var list := [cat, cow, dog]
	_check(t.handle("x", list) == Targeting.Result.NO_MATCH, "no match")
	_check(not t.has_target(), "no target after no match")
	_check(t.handle("c", list) == Targeting.Result.LOCKED, "locks")
	_check(t.current == cow, "locks nearest to base")
	_check(t.handle("a", list) == Targeting.Result.WRONG, "wrong letter")
	_check(cow.typed == 1, "wrong letter doesn't advance")
	_check(t.handle("o", list) == Targeting.Result.ADVANCED, "advances")
	_check(t.handle("w", list) == Targeting.Result.COMPLETED, "completes")
	_check(t.finish() == cow and not t.has_target(), "finish clears lock")
	cow.alive = false
	_check(t.handle("c", list) == Targeting.Result.LOCKED and t.current == cat, "dead words skipped")
	t.release()
	_check(not t.has_target() and cat.typed == 0, "release resets typed")
	_check(Targeting.nearest(list) == dog, "nearest alive")
	var one := Item.new("a", 0.0)
	_check(t.handle("a", [one]) == Targeting.Result.COMPLETED, "one-letter word completes on lock")


func _test_score_model() -> void:
	_begin("score model")
	var m := ScoreModel.new(5)
	_check(m.level == 5 and m.bar == Tuning.BAR_START, "start state")
	_check(m.floor_level == 3, "floor = start - allowance")
	var pts := m.on_word_completed(5, 6, false)
	_check(pts > 0 and m.score == pts, "points awarded")
	_check(m.streak == 1 and m.bar > Tuning.BAR_START, "streak + bar up")
	m.on_word_completed(5, 6, true)
	_check(m.streak == 1, "mistakes don't extend streak")

	# Penalty grows with accuracy and streak.
	var good := ScoreModel.new(5)
	for i in 10:
		good.on_word_completed(5, 5, false)
	var bad := ScoreModel.new(5)
	for i in 10:
		bad.on_word_completed(5, 5, true)
	_check(good.miss_penalty() > bad.miss_penalty(), "doing well -> bigger miss penalty (%.1f vs %.1f)" % [good.miss_penalty(), bad.miss_penalty()])
	var hi := ScoreModel.new(9)
	var lo := ScoreModel.new(1)
	_check(hi.miss_penalty() > lo.miss_penalty(), "higher level -> bigger penalty")
	_check(m.wrong_letter_penalty() < m.miss_penalty(), "wrong letter < miss")

	# Level up.
	var up := ScoreModel.new(2)
	var events: Array = []
	up.level_changed.connect(func(l, dlt): events.append([l, dlt]))
	var guard := 0
	while up.level == 2 and guard < 100:
		up.on_word_completed(2, 4, false)
		guard += 1
	_check(up.level == 3 and events == [[3, 1]], "levels up when bar full")
	_check(up.bar == Tuning.BAR_RESET, "bar reset after level up")
	_check(guard <= 12, "level up takes a reasonable number of words (%d)" % guard)

	# Level down then game over.
	var down := ScoreModel.new(4)
	var over := [false]
	down.game_over.connect(func(): over[0] = true)
	guard = 0
	while not over[0] and guard < 200:
		down.on_word_missed()
		guard += 1
	_check(over[0] and down.is_over, "game over eventually")
	_check(down.level == down.floor_level, "game over at floor level (%d)" % down.level)
	_check(down.on_word_completed(4, 4, false) == 0, "no points after game over")
	var l1 := ScoreModel.new(1)
	_check(l1.floor_level == 1, "floor never below 1")
	var res := ScoreModel.new(3)
	res.resume(7, 1, 1234)
	_check(res.level == 7 and res.floor_level == 1 and res.score == 1234, "resume restores level/floor/score")
	_check(res.bar == Tuning.BAR_START and res.max_level_reached == 7, "resume starts the level fresh")


func _test_power_ups() -> void:
	_begin("power-ups")
	var p := PowerUps.new()
	_check(p.count(PowerUps.AUTOSPELL) == 1, "starts with one autospell")
	_check(p.use(PowerUps.AUTOSPELL) and p.count(PowerUps.AUTOSPELL) == 0, "use consumes")
	_check(not p.use(PowerUps.AUTOSPELL), "can't use empty")
	var shake0 := p.count(PowerUps.SHAKE)

	# AUTOSPELL every N correct words; every SHAKE_EVERY_NTH reward is a SHAKE.
	var n := Tuning.AUTOSPELL_EVERY
	for i in n - 1:
		p.on_correct_word()
	_check(p.count(PowerUps.AUTOSPELL) == 0, "nothing before %d correct words" % n)
	p.on_correct_word()
	_check(p.count(PowerUps.AUTOSPELL) == 1, "autospell at %d correct words" % n)
	for i in n:
		p.on_correct_word()
	_check(p.count(PowerUps.AUTOSPELL) == 2, "autospell at %d correct words" % (2 * n))
	_check(p.count(PowerUps.SHAKE) == shake0, "no shake yet")
	for i in n:
		p.on_correct_word()
	_check(p.count(PowerUps.AUTOSPELL) == 2, "3rd reward is not an autospell")
	_check(p.count(PowerUps.SHAKE) == shake0 + 1, "3rd reward is a shake")
	_check(p.count(PowerUps.CLEAR) == 0, "correct words never grant clear")

	# Exact sequence over 6 milestones: A A S A A S.
	var q := PowerUps.new()
	q.charges = {PowerUps.AUTOSPELL: 0, PowerUps.CLEAR: 0, PowerUps.SHAKE: 0}
	var seq: Array[String] = []
	q.earned.connect(func(kind): seq.append(kind))
	for m in 6:
		for i in n:
			q.on_correct_word()
		while q.use(PowerUps.AUTOSPELL):  # spend so the cap doesn't hide rewards
			pass
	_check(seq == [PowerUps.AUTOSPELL, PowerUps.AUTOSPELL, PowerUps.SHAKE,
			PowerUps.AUTOSPELL, PowerUps.AUTOSPELL, PowerUps.SHAKE], "reward order A A S A A S (got %s)" % [seq])

	# CLEAR: one per level cleared.
	var c := PowerUps.new()
	c.on_level_up()
	_check(c.count(PowerUps.CLEAR) == 1, "level up grants clear")
	_check(c.count(PowerUps.AUTOSPELL) == 1, "level up doesn't grant autospell")
	for i in 10:
		c.on_level_up()
	_check(c.count(PowerUps.CLEAR) == Tuning.POWERUP_MAX, "charges capped")


func _test_translations() -> void:
	_begin("translations")
	var paths: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	_check(paths.size() >= 2, "at least two UI locales registered")
	var tables: Array[Translation] = []
	for path in paths:
		var t := load(path) as Translation
		_check(t != null, "loads %s" % path)
		if t != null:
			tables.append(t)
	if tables.is_empty():
		return
	var reference := tables[0]
	var keys := reference.get_message_list()
	_check(keys.size() > 10, "reference has keys")
	for t in tables:
		_check(t.get_message_list().size() == keys.size(), "%s has same key count" % t.locale)
		for k in keys:
			_check(String(t.get_message(k)) != "", "%s has %s" % [t.locale, k])
		_check(String(t.get_message("LOCALE_NAME")) != "", "%s has native name" % t.locale)


func _test_tuning() -> void:
	_begin("tuning")
	_check(Tuning.start_level_for_age(4) == 1, "age 4 -> level 1")
	_check(Tuning.start_level_for_age(8) == 4, "age 8 -> level 4")
	_check(Tuning.start_level_for_age(30) == 10, "age clamps to 10")
	_check(Tuning.fall_time(1, 4) > Tuning.fall_time(10, 4), "falls faster at higher level")
	_check(Tuning.fall_time(5, 10) > Tuning.fall_time(5, 4), "long words fall slower")
	_check(Tuning.spawn_interval(20) >= Tuning.SPAWN_INTERVAL_MIN, "spawn interval floor")
	_check(Tuning.max_words(1) == Tuning.MAX_WORDS_BASE and Tuning.max_words(99) == Tuning.MAX_WORDS_CAP, "max words range")
	var sum := 0.0
	for k in Tuning.TIER_WEIGHTS:
		sum += Tuning.TIER_WEIGHTS[k]
	_check(absf(sum - 1.0) < 0.001, "tier weights sum to 1")


func _test_shuffle_bag() -> void:
	_begin("shuffle bag")
	var words: Array = []
	for i in 60:
		words.append("w%02d" % i)
	# Only one tier, so every pick comes from it.
	var p := WordPicker.new({1: words}, 99)
	var seen := {}
	var repeats := 0
	for i in words.size():
		var w := p.pick(1)
		if seen.has(w):
			repeats += 1
		seen[w] = true
	_check(repeats == 0, "no repeats until the whole tier was used (%d repeats)" % repeats)
	_check(seen.size() == words.size(), "every word of the tier used once")
	var w2 := p.pick(1)
	_check(w2 != "", "bag refills")


func _test_review_queue() -> void:
	_begin("review queue")
	var q := ReviewQueue.new()
	var changes: Array = []
	q.box_changed.connect(func(w, b): changes.append([w, b]))
	q.failed("because")
	_check(q.box_of("because") == 0 and changes[-1] == ["because", 0], "failed -> box 0")
	for i in Tuning.REVIEW_GAPS[0] - 1:
		q.tick()
	_check(q.take_due() == "", "not due before gap")
	q.tick()
	_check(q.take_due() == "because", "due after gap")
	_check(q.take_due() == "", "rescheduled after being taken")
	q.succeeded("because")
	_check(q.box_of("because") == 1, "success -> next box")
	_check(q.due_at("because") == q.spawn_index + Tuning.REVIEW_GAPS[1], "longer gap in next box")
	for b in range(2, Tuning.REVIEW_GAPS.size()):
		q.succeeded("because")
	q.succeeded("because")
	_check(not q.has("because") and changes[-1] == ["because", Tuning.REVIEW_GAPS.size()], "graduates after last box")
	q.succeeded("never_failed")
	_check(not q.has("never_failed"), "success on unknown word is ignored")
	# Failing again resets.
	q.failed("rhythm")
	q.succeeded("rhythm")
	q.failed("rhythm")
	_check(q.box_of("rhythm") == 0, "failing resets to box 0")
	# Blocked initials.
	var q2 := ReviewQueue.new()
	q2.failed("apple")
	q2.failed("bread")
	for i in 10:
		q2.tick()
	_check(q2.take_due({"a": true}) == "bread", "skips words with blocked initials")
	# Seeding staggers carried-over words.
	var q3 := ReviewQueue.new()
	q3.seed_words(["one", "two", "three"])
	_check(q3.size() == 3, "seeded")
	_check(q3.due_at("one") < q3.due_at("two") and q3.due_at("two") < q3.due_at("three"), "seeds are staggered")
	# Picker serves due review words first.
	var p := WordPicker.new({1: ["xa", "xb", "yc", "zd"]}, 3)
	p.review = ReviewQueue.new()
	p.review.seed_words(["because"])
	var got := false
	for i in Tuning.REVIEW_SEED_START + 2:
		if p.pick(1) == "because":
			got = true
	_check(got, "picker returns a due review word")


func _test_palettes() -> void:
	_begin("palettes")
	var term: Node = load("res://scripts/autoload/term.gd").new()
	for pal: Dictionary in term.PALETTES:
		var c: Dictionary = term.derive(pal["base"])
		var id: String = pal["id"]
		_check(c["bg"].get_luminance() < 0.08, "%s background is dark" % id)
		_check(c["fg"].get_luminance() - c["bg"].get_luminance() > 0.4, "%s text contrasts with background" % id)
		_check(c["dim"].get_luminance() < c["fg"].get_luminance(), "%s dim is dimmer than text" % id)
		var grey: bool = pal["base"].s < 0.15
		if not grey:
			_check(term.hue_gap(c["fg"].h, c["accent"].h) >= term.MIN_HUE_GAP, "%s accent differs from text" % id)
			_check(term.hue_gap(c["fg"].h, c["error"].h) >= term.MIN_HUE_GAP, "%s error differs from text" % id)
		_check(term.hue_gap(c["accent"].h, c["error"].h) >= term.MIN_HUE_GAP, "%s error differs from accent" % id)
	for t: Dictionary in term.TEXT_SIZES:
		_check(t["scale"] >= 0.8 and t["scale"] <= 1.6, "text size %s sane" % t["id"])
	term.free()


func _test_profiles() -> void:
	_begin("profiles")
	var s: Node = load("res://scripts/autoload/settings.gd").new()
	s.persist = false
	_check(not s.has_profiles(), "starts empty")
	_check(s.sanitize_name("  anna   <b>marie  ") == "Anna bmarie", "sanitises names (got '%s')" % s.sanitize_name("  anna   <b>marie  "))
	_check(s.sanitize_name("   ") == "", "blank name rejected")
	_check(s.sanitize_name("abcdefghijklmnopqrstuvwxyz").length() == s.NAME_MAX, "name length capped")
	_check(s.sanitize_name("øyvind") == "Øyvind", "non-ASCII names capitalised")
	var a: String = s.create_profile("ola", 7)
	_check(a != "" and s.current_name() == "Ola" and s.age == 7, "create + select")
	_check(s.create_profile("OLA", 9) == "", "duplicate name (any case) rejected")
	_check(s.create_profile("", 9) == "", "empty name rejected")
	s.palette = "pink"
	s.text_size = "xl"
	var b: String = s.create_profile("Kari", 10)
	_check(s.current_id() == b and s.palette == "pink" and s.text_size == "xl", "new profile inherits look")
	s.palette = "cyan"
	s.select_profile(a)
	_check(s.palette == "pink", "profiles keep their own preferences")
	s.select_profile(b)
	_check(s.palette == "cyan", "switching back restores them")
	_check(s.profiles().size() == 2 and s.profiles()[0]["name"] == "Kari", "profiles listed by name")
	_check(s.record_score("en", 500) and s.best_for("en") == 500 and s.high_score() == 500, "best + high score")
	_check(not s.record_score("en", 300) and s.best_for("en") == 500, "lower score is not a best")
	s.record_score("nb", 800)
	_check(s.high_score() == 800 and s.best_for("en") == 500, "high score spans languages")
	_check(not s.has_resume(), "no resume yet")
	s.set_resume({"lang": "en", "mode": "show", "level": 6, "floor": 2, "score": 900})
	_check(s.has_resume() and s.resume_state["level"] == 6, "resume saved")
	s.clear_resume()
	_check(not s.has_resume(), "resume cleared")
	s.delete_profile(b)
	_check(s.profiles().size() == 1 and s.current_id() == a, "delete falls back to another profile")
	s.delete_profile(a)
	_check(not s.has_profiles() and s.current_id() == "", "delete last profile")
	s.free()


func _test_sfx() -> void:
	_begin("sfx synthesis")
	var sfx_script: Script = load("res://scripts/autoload/sfx.gd")
	for name in sfx_script.SOUNDS:
		var spec: Array = sfx_script.SOUNDS[name]
		var w: AudioStreamWAV = sfx_script.synth(spec[0], spec[1], spec[2])
		var samples := 0
		for part in spec[2]:
			samples += int(part[2] * sfx_script.RATE)
		_check(w.data.size() == samples * 2, "%s has the expected length" % name)
		var peak := 0
		for i in range(0, w.data.size(), 2):
			peak = maxi(peak, absi(w.data.decode_s16(i)))
		_check(peak > 1000 and peak < 32767, "%s is audible and not clipped (peak %d)" % [name, peak])
