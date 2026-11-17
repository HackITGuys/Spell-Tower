class_name SpellTestSuite
extends GdUnitTestSuite
## Base for the unit suites in tests/unit/ (GdUnit4).
## Kept outside tests/unit/ so the runner doesn't treat it as a suite.
##
## check() is a light condition + message assertion, used by the checks that
## loop over every word or every palette: only failures create a report entry,
## so thousands of passing checks stay fast. Prefer the normal GdUnit4
## assert_* calls for new single-value tests.


func check(cond: bool, msg: String) -> void:
	if not cond:
		fail(msg)
