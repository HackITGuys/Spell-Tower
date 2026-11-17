extends SpellTestSuite
## Word files, manifest and text normalisation.


func _new_bank() -> Node:
	var wb: Node = load("res://scripts/autoload/word_bank.gd").new()
	wb.load_manifest()
	return wb


func test_manifest_and_word_files() -> void:
	var wb := _new_bank()
	check(wb.languages.size() >= 1, "manifest has languages")
	check(wb.has_language("en"), "english present")
	for def: Dictionary in wb.languages:
		var code: String = def["code"]
		var alpha: String = def["alphabet"]
		for row: String in def["keyboard"]:
			for i in row.length():
				check(alpha.contains(row[i]), "%s keyboard key '%s' in alphabet" % [code, row[i]])
		for i in alpha.length():
			var on_kb := false
			for row: String in def["keyboard"]:
				on_kb = on_kb or row.contains(alpha[i])
			check(on_kb, "%s alphabet letter '%s' reachable on keyboard" % [code, alpha[i]])
		check(wb.load_language(code), "%s loads" % code)
		check(wb.entries.size() > 0, "%s has words" % code)
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(def["word_file"]))
		var seen := {}
		var total := 0
		for t in raw["tiers"]:
			for w: String in raw["tiers"][t]:
				total += 1
				check(not seen.has(w), "%s duplicate word '%s'" % [code, w])
				seen[w] = true
				check(w == w.to_lower(), "%s '%s' is lowercase" % [code, w])
				for i in w.length():
					var cp := w.unicode_at(i)
					check(cp < 0x300 or cp > 0x36F, "%s '%s' has no combining marks (NFC)" % [code, w])
		check(wb.entries.size() == total, "%s every word accepted by alphabet" % code)
		check(raw["tiers"].has("0") and (raw["tiers"]["0"] as Array).size() >= 20, "%s has pre-school words" % code)
		for c in raw.get("concepts", {}):
			check(seen.has(c), "%s concept word '%s' exists" % [code, c])
	wb.load_language("en")
	var tiers: Dictionary = wb.build_tiers()
	for t in range(1, Tuning.MAX_GRADE + 1):
		check(tiers.has(t) and tiers[t].size() >= 120, "en grade %d has >= 120 words" % t)
	check(tiers.has(0) and tiers[0].size() >= 40, "en pre-school has >= 40 words")
	check(wb.base_difficulty("a") == 0 and wb.base_difficulty("cat") == 0, "letters and first words are pre-school")
	check(wb.entries["cat"]["id"] == "en:cat", "ids are lang-prefixed")
	check(wb.concept_of("cat") == "animal.cat", "concept lookup")
	wb.free()


func test_text_norm() -> void:
	var nb := TextNorm.new({"alphabet": "abcdefghijklmnopqrstuvwxyzæøå", "equivalents": {"ä": "æ", "ö": "ø"}})
	check(nb.normalize_char("Å") == "å", "uppercase Å -> å")
	check(nb.normalize_char("Ø") == "ø", "uppercase Ø -> ø")
	check(nb.normalize_char("ä") == "æ", "equivalent ä -> æ")
	check(nb.normalize_char("Ö") == "ø", "equivalent Ö -> ø")
	check(nb.normalize_char("1") == "", "digits ignored")
	check(nb.normalize_char(" ") == "", "space ignored")
	check(nb.is_valid_word("blåbær"), "blåbær valid")
	var en := TextNorm.new({"alphabet": "abcdefghijklmnopqrstuvwxyz"})
	check(en.normalize_char("å") == "", "å not in english alphabet")
	check(en.normalize_char("Q") == "q", "Q -> q")
	var tr_ := TextNorm.new({"alphabet": "abcçdefgğhıijklmnoöprsştuüvyz", "casefold": {"I": "ı", "İ": "i"}})
	check(tr_.normalize_char("I") == "ı", "turkish casefold I -> ı")
	check(tr_.normalize_char("İ") == "i", "turkish casefold İ -> i")
