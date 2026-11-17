extends SpellTestSuite
## Colour palettes and synthesised sounds.


func test_palettes() -> void:
	var term: Node = load("res://scripts/autoload/term.gd").new()
	for pal: Dictionary in term.PALETTES:
		var c: Dictionary = term.derive(pal["base"])
		var id: String = pal["id"]
		check(c["bg"].get_luminance() < 0.08, "%s background is dark" % id)
		check(c["fg"].get_luminance() - c["bg"].get_luminance() > 0.4, "%s text contrasts with background" % id)
		check(c["dim"].get_luminance() < c["fg"].get_luminance(), "%s dim is dimmer than text" % id)
		var grey: bool = pal["base"].s < 0.15
		if not grey:
			check(term.hue_gap(c["fg"].h, c["accent"].h) >= term.MIN_HUE_GAP, "%s accent differs from text" % id)
			check(term.hue_gap(c["fg"].h, c["error"].h) >= term.MIN_HUE_GAP, "%s error differs from text" % id)
		check(term.hue_gap(c["accent"].h, c["error"].h) >= term.MIN_HUE_GAP, "%s error differs from accent" % id)
	for t: Dictionary in term.TEXT_SIZES:
		check(t["scale"] >= 0.8 and t["scale"] <= 1.6, "text size %s sane" % t["id"])
	term.free()


func test_sfx() -> void:
	var sfx_script: Script = load("res://scripts/autoload/sfx.gd")
	for name in sfx_script.SOUNDS:
		var spec: Array = sfx_script.SOUNDS[name]
		var w: AudioStreamWAV = sfx_script.synth(spec[0], spec[1], spec[2])
		var samples := 0
		for part in spec[2]:
			samples += int(part[2] * sfx_script.RATE)
		check(w.data.size() == samples * 2, "%s has the expected length" % name)
		var peak := 0
		for i in range(0, w.data.size(), 2):
			peak = maxi(peak, absi(w.data.decode_s16(i)))
		check(peak > 1000 and peak < 32767, "%s is audible and not clipped (peak %d)" % [name, peak])
