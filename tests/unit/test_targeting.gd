extends SpellTestSuite
## Locking onto and typing falling words.


class Item:
	var text := ""
	var typed := 0
	var y := 0.0
	var alive := true

	func _init(t: String, p_y: float) -> void:
		text = t
		y = p_y


func test_targeting() -> void:
	var t := Targeting.new()
	var cat := Item.new("cat", 100.0)
	var cow := Item.new("cow", 300.0)  # closer to base
	var dog := Item.new("dog", 200.0)
	var list := [cat, cow, dog]
	check(t.handle("x", list) == Targeting.Result.NO_MATCH, "no match")
	check(not t.has_target(), "no target after no match")
	check(t.handle("c", list) == Targeting.Result.LOCKED, "locks")
	check(t.current == cow, "locks nearest to base")
	check(t.handle("a", list) == Targeting.Result.WRONG, "wrong letter")
	check(cow.typed == 1, "wrong letter doesn't advance")
	check(t.handle("o", list) == Targeting.Result.ADVANCED, "advances")
	check(t.handle("w", list) == Targeting.Result.COMPLETED, "completes")
	check(t.finish() == cow and not t.has_target(), "finish clears lock")
	cow.alive = false
	check(t.handle("c", list) == Targeting.Result.LOCKED and t.current == cat, "dead words skipped")
	t.release()
	check(not t.has_target() and cat.typed == 0, "release resets typed")
	check(Targeting.nearest(list) == dog, "nearest alive")
	var one := Item.new("a", 0.0)
	check(t.handle("a", [one]) == Targeting.Result.COMPLETED, "one-letter word completes on lock")
