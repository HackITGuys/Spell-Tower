extends SpellTestSuite
## Failed words coming back (Leitner boxes).


func test_review_queue() -> void:
	var q := ReviewQueue.new()
	var changes: Array = []
	q.box_changed.connect(func(w, b): changes.append([w, b]))
	q.failed("because")
	check(q.box_of("because") == 0 and changes[-1] == ["because", 0], "failed -> box 0")
	for i in Tuning.REVIEW_GAPS[0] - 1:
		q.tick()
	check(q.take_due() == "", "not due before gap")
	q.tick()
	check(q.take_due() == "because", "due after gap")
	check(q.take_due() == "", "rescheduled after being taken")
	q.succeeded("because")
	check(q.box_of("because") == 1, "success -> next box")
	check(q.due_at("because") == q.spawn_index + Tuning.REVIEW_GAPS[1], "longer gap in next box")
	for b in range(2, Tuning.REVIEW_GAPS.size()):
		q.succeeded("because")
	q.succeeded("because")
	check(not q.has("because") and changes[-1] == ["because", Tuning.REVIEW_GAPS.size()], "graduates after last box")
	q.succeeded("never_failed")
	check(not q.has("never_failed"), "success on unknown word is ignored")
	# Failing again resets.
	q.failed("rhythm")
	q.succeeded("rhythm")
	q.failed("rhythm")
	check(q.box_of("rhythm") == 0, "failing resets to box 0")
	# Blocked initials.
	var q2 := ReviewQueue.new()
	q2.failed("apple")
	q2.failed("bread")
	for i in 10:
		q2.tick()
	check(q2.take_due({"a": true}) == "bread", "skips words with blocked initials")
	# Seeding staggers carried-over words.
	var q3 := ReviewQueue.new()
	q3.seed_words(["one", "two", "three"])
	check(q3.size() == 3, "seeded")
	check(q3.due_at("one") < q3.due_at("two") and q3.due_at("two") < q3.due_at("three"), "seeds are staggered")
	# Picker serves due review words first.
	var p := WordPicker.new({1: ["xa", "xb", "yc", "zd"]}, 3)
	p.review = ReviewQueue.new()
	p.review.seed_words(["because"])
	var got := false
	for i in Tuning.REVIEW_SEED_START + 2:
		if p.pick(1) == "because":
			got = true
	check(got, "picker returns a due review word")
