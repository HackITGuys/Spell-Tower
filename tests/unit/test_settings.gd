extends SpellTestSuite
## Player profiles and their settings.


func test_profiles() -> void:
	var s: Node = load("res://scripts/autoload/settings.gd").new()
	s.persist = false
	check(not s.has_profiles(), "starts empty")
	check(s.sanitize_name("  anna   <b>marie  ") == "Anna bmarie", "sanitises names (got '%s')" % s.sanitize_name("  anna   <b>marie  "))
	check(s.sanitize_name("   ") == "", "blank name rejected")
	check(s.sanitize_name("abcdefghijklmnopqrstuvwxyz").length() == s.NAME_MAX, "name length capped")
	check(s.sanitize_name("øyvind") == "Øyvind", "non-ASCII names capitalised")
	var a: String = s.create_profile("ola", 2)
	check(a != "" and s.current_name() == "Ola" and s.grade == 2, "create + select")
	check(s.effective_start_level() == Tuning.first_level_of_grade(2), "starts at the first stage of the start grade")
	s.grade = 0
	check(s.effective_start_level() == 1, "pre-school starts at level 1")
	s.grade = 99
	check(s.grade == Tuning.MAX_GRADE, "grade clamped")
	s.grade = 2
	# Older profiles: age / start level -> start grade; removed keys dropped.
	var old := {"age": 4, "start_level": 0, "mode": "listen", "resume": {"level": 3}}
	s._migrate(old)
	check(old.get("grade") == 0 and not old.has("age") and not old.has("mode") and not old.has("resume"), "age 4 -> pre-school (got %s)" % [old])
	var old8 := {"age": 8, "start_level": 0}
	s._migrate(old8)
	check(old8.get("grade") == 3 and not old8.has("start_level"), "age 8 -> grade 3")
	var chosen := {"age": 8, "start_level": 5}
	s._migrate(chosen)
	check(chosen.get("grade") == 5, "chosen start level wins over age")
	var adult := {"age": 99, "start_level": 0}
	s._migrate(adult)
	check(adult.get("grade") == Tuning.MAX_GRADE, "adult -> top grade")
	check(s.create_profile("OLA", 9) == "", "duplicate name (any case) rejected")
	check(s.create_profile("", 9) == "", "empty name rejected")
	s.palette = "pink"
	s.text_size = "xl"
	var b: String = s.create_profile("Kari", 10)
	check(s.current_id() == b and s.palette == "pink" and s.text_size == "xl", "new profile inherits look")
	s.palette = "cyan"
	s.select_profile(a)
	check(s.palette == "pink", "profiles keep their own preferences")
	s.select_profile(b)
	check(s.palette == "cyan", "switching back restores them")
	check(s.profiles().size() == 2 and s.profiles()[0]["name"] == "Kari", "profiles listed by name")
	check(s.record_score("en", 500) and s.best_for("en") == 500 and s.high_score() == 500, "best + high score")
	check(not s.record_score("en", 300) and s.best_for("en") == 500, "lower score is not a best")
	s.record_score("nb", 800)
	check(s.high_score() == 800 and s.best_for("en") == 500, "high score spans languages")
	s.delete_profile(b)
	check(s.profiles().size() == 1 and s.current_id() == a, "delete falls back to another profile")
	s.delete_profile(a)
	check(not s.has_profiles() and s.current_id() == "", "delete last profile")
	s.free()
