extends GdUnitTestSuite
## UI locale resolution (the Locale autoload).


func test_registered_locales_resolve_to_themselves() -> void:
	for code in ["en", "nb", "nn"]:
		assert_bool(Locale.has_locale(code)).override_failure_message("%s registered" % code).is_true()
		assert_str(Locale.resolve(code)).is_equal(code)


func test_nynorsk_is_not_aliased_to_bokmal() -> void:
	# An OS set to Nynorsk must get the Nynorsk UI now that it exists.
	assert_bool(Locale.ALIASES.has("nn")).is_false()
	assert_str(Locale.ALIASES.get("no", "")).is_equal("nb")


func test_every_alias_points_at_a_registered_locale() -> void:
	for alias in Locale.ALIASES:
		assert_bool(Locale.has_locale(Locale.ALIASES[alias])).is_true()


func test_unknown_code_falls_back_to_a_registered_locale() -> void:
	assert_bool(Locale.has_locale(Locale.resolve("xx"))).is_true()
