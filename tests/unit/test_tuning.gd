extends SpellTestSuite
## Grades, stages, speed and spawn tuning.


func test_tuning() -> void:
	var stages := Tuning.STAGES_PER_GRADE
	check(Tuning.grade_for_level(1) == 0 and Tuning.stage_for_level(1) == 1, "level 1 = pre-school, stage 1")
	check(Tuning.grade_for_level(6) == 1 and Tuning.stage_for_level(6) == 1, "level 6 = grade 1, stage 1")
	check(
		(
			Tuning.grade_for_level(Tuning.MAX_LEVEL) == Tuning.MAX_GRADE
			and Tuning.stage_for_level(Tuning.MAX_LEVEL) == stages
		),
		"last level = grade 10, last stage"
	)
	for g in range(Tuning.MIN_GRADE, Tuning.MAX_GRADE + 1):
		var first := Tuning.first_level_of_grade(g)
		check(
			Tuning.grade_for_level(first) == g and Tuning.stage_for_level(first) == 1,
			"grade %d starts at its first stage" % g
		)
	check(Tuning.grade_name(0) != Tuning.grade_name(1) and Tuning.grade_name(3).contains("3"), "grade names")
	check(
		Tuning.level_label(Tuning.first_level_of_grade(3) + 1) == "%s · 2/%d" % [Tuning.grade_name(3), stages],
		"level label shows grade and stage"
	)
	check(Tuning.fall_time(1, 4) > Tuning.fall_time(Tuning.first_level_of_grade(1), 4), "pre-school falls slowest")
	check(
		absf(Tuning.fall_time(Tuning.first_level_of_grade(1), 4) - 14.0 / 0.9) < 0.001,
		"grade 1 speed is 0.9x of v0.1 (14 s)"
	)
	check(Tuning.fall_time(5, 10) > Tuning.fall_time(5, 4), "long words fall slower")
	for g in range(Tuning.MIN_GRADE, Tuning.MAX_GRADE + 1):
		var first := Tuning.first_level_of_grade(g)
		for s in range(1, stages):
			check(
				Tuning.fall_time(first + s, 4) < Tuning.fall_time(first + s - 1, 4),
				"grade %d: stage %d faster than %d" % [g, s + 1, s]
			)
		if g < Tuning.MAX_GRADE:
			var last := first + stages - 1
			# Dropping from the next grade's first stage back into this grade speeds up.
			check(
				Tuning.fall_time(last, 4) < Tuning.fall_time(last + 1, 4),
				"dropping from grade %d to %d speeds up" % [g + 1, g]
			)
			check(
				Tuning.fall_time(last + 1, 4) < Tuning.fall_time(first, 4),
				"grade %d starts faster than grade %d" % [g + 1, g]
			)
	check(Tuning.spawn_interval(20) >= Tuning.SPAWN_INTERVAL_MIN, "spawn interval floor")
	var g1 := Tuning.first_level_of_grade(1)
	check(Tuning.spawn_interval(g1) == Tuning.spawn_interval(g1 + stages - 1), "spawn rate follows the grade")
	check(
		Tuning.max_words(1) == Tuning.MAX_WORDS_BASE and Tuning.max_words(Tuning.MAX_LEVEL) <= Tuning.MAX_WORDS_CAP,
		"max words range"
	)
	var sum := Tuning.WEIGHT_CURRENT_GRADE + Tuning.WEIGHT_GRADE_BELOW + Tuning.WEIGHT_LOWER_GRADES
	check(absf(sum - 1.0) < 0.001, "grade weights sum to 1")
	check(Tuning.word_value(0, 1) > 0.0, "pre-school words are worth points")
