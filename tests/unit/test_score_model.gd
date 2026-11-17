extends SpellTestSuite
## Bar, score, stages and power-ups.


func test_score_model() -> void:
	var m := ScoreModel.new(5)
	check(m.level == 5 and m.bar == Tuning.BAR_START, "start state")
	check(m.floor_level == 3, "floor = start - allowance")
	var pts := m.on_word_completed(5, 6, false)
	check(pts > 0 and m.score == pts, "points awarded")
	check(m.streak == 1 and m.bar > Tuning.BAR_START, "streak + bar up")
	m.on_word_completed(5, 6, true)
	check(m.streak == 1, "mistakes don't extend streak")

	# Penalty grows with accuracy and streak.
	var good := ScoreModel.new(5)
	for i in 10:
		good.on_word_completed(5, 5, false)
	var bad := ScoreModel.new(5)
	for i in 10:
		bad.on_word_completed(5, 5, true)
	check(
		good.miss_penalty() > bad.miss_penalty(),
		"doing well -> bigger miss penalty (%.1f vs %.1f)" % [good.miss_penalty(), bad.miss_penalty()]
	)
	var hi := ScoreModel.new(Tuning.first_level_of_grade(5))
	var lo := ScoreModel.new(1)
	check(hi.miss_penalty() > lo.miss_penalty(), "higher tier -> bigger penalty")
	check(m.wrong_letter_penalty() < m.miss_penalty(), "wrong letter < miss")

	# Level up.
	var up := ScoreModel.new(2)
	var events: Array = []
	up.level_changed.connect(func(l, dlt): events.append([l, dlt]))
	var guard := 0
	while up.level == 2 and guard < 100:
		up.on_word_completed(2, 4, false)
		guard += 1
	check(up.level == 3 and events == [[3, 1]], "levels up when bar full")
	check(up.bar == Tuning.BAR_RESET, "bar reset after level up")
	check(guard <= 12, "level up takes a reasonable number of words (%d)" % guard)

	# Level down then game over.
	var down := ScoreModel.new(4)
	var over := [false]
	down.game_over.connect(func(): over[0] = true)
	guard = 0
	while not over[0] and guard < 200:
		down.on_word_missed()
		guard += 1
	check(over[0] and down.is_over, "game over eventually")
	check(down.level == down.floor_level, "game over at floor level (%d)" % down.level)
	check(down.on_word_completed(4, 4, false) == 0, "no points after game over")
	var l1 := ScoreModel.new(1)
	check(l1.floor_level == 1, "floor never below 1")
	# Five stages per grade: beating pre-school stage 5 -> grade 1, stage 1.
	var grade_up := ScoreModel.new(Tuning.STAGES_PER_GRADE)
	guard = 0
	while grade_up.level == Tuning.STAGES_PER_GRADE and guard < 100:
		grade_up.on_word_completed(0, 3, false)
		guard += 1
	check(
		Tuning.grade_for_level(grade_up.level) == 1 and Tuning.stage_for_level(grade_up.level) == 1,
		"beating pre-school 5/5 goes to grade 1, 1/5 (got %s)" % Tuning.level_label(grade_up.level)
	)
	check(grade_up.score > 0, "pre-school words score points")
	# Top level: the bar fills but there's nowhere higher to go.
	var top := ScoreModel.new(Tuning.MAX_LEVEL)
	for i in 50:
		top.on_word_completed(10, 8, false)
	check(
		top.level == Tuning.MAX_LEVEL and top.bar <= Tuning.BAR_MAX,
		"level capped at %s" % Tuning.level_label(Tuning.MAX_LEVEL)
	)


func test_power_ups() -> void:
	var p := PowerUps.new()
	check(p.count(PowerUps.AUTOSPELL) == 1, "starts with one autospell")
	check(p.use(PowerUps.AUTOSPELL) and p.count(PowerUps.AUTOSPELL) == 0, "use consumes")
	check(not p.use(PowerUps.AUTOSPELL), "can't use empty")
	var shake0 := p.count(PowerUps.SHAKE)

	# AUTOSPELL every N correct words; every SHAKE_EVERY_NTH reward is a SHAKE.
	var n := Tuning.AUTOSPELL_EVERY
	for i in n - 1:
		p.on_correct_word()
	check(p.count(PowerUps.AUTOSPELL) == 0, "nothing before %d correct words" % n)
	p.on_correct_word()
	check(p.count(PowerUps.AUTOSPELL) == 1, "autospell at %d correct words" % n)
	for i in n:
		p.on_correct_word()
	check(p.count(PowerUps.AUTOSPELL) == 2, "autospell at %d correct words" % (2 * n))
	check(p.count(PowerUps.SHAKE) == shake0, "no shake yet")
	for i in n:
		p.on_correct_word()
	check(p.count(PowerUps.AUTOSPELL) == 2, "3rd reward is not an autospell")
	check(p.count(PowerUps.SHAKE) == shake0 + 1, "3rd reward is a shake")
	check(p.count(PowerUps.CLEAR) == 0, "correct words never grant clear")

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
	check(
		(
			seq
			== [
				PowerUps.AUTOSPELL,
				PowerUps.AUTOSPELL,
				PowerUps.SHAKE,
				PowerUps.AUTOSPELL,
				PowerUps.AUTOSPELL,
				PowerUps.SHAKE
			]
		),
		"reward order A A S A A S (got %s)" % [seq]
	)

	# CLEAR: one per level cleared.
	var c := PowerUps.new()
	c.on_level_up()
	check(c.count(PowerUps.CLEAR) == 1, "level up grants clear")
	check(c.count(PowerUps.AUTOSPELL) == 1, "level up doesn't grant autospell")
	for i in 10:
		c.on_level_up()
	check(c.count(PowerUps.CLEAR) == Tuning.POWERUP_MAX, "charges capped")
