class_name Targeting
extends RefCounted
## Auto-lock targeting. Works on any object with:
##   text: String, typed: int, y: float (larger = closer to base), and
##   optionally `alive: bool`.

enum Result { NO_MATCH, LOCKED, ADVANCED, COMPLETED, WRONG }

var current: Object = null


func has_target() -> bool:
	return current != null and _is_alive(current)


func release() -> void:
	if current != null and _is_alive(current):
		current.typed = 0
	current = null


## ch must already be normalised. candidates: Array of word objects.
func handle(ch: String, candidates: Array) -> Result:
	if not has_target():
		current = null
		var best: Object = null
		for c: Object in candidates:
			if not _is_alive(c) or c.typed != 0 or c.text.is_empty():
				continue
			if c.text[0] == ch and (best == null or c.y > best.y):
				best = c
		if best == null:
			return Result.NO_MATCH
		current = best
		current.typed = 1
		if current.typed >= current.text.length():
			return Result.COMPLETED
		return Result.LOCKED

	var expected: String = current.text[current.typed]
	if ch != expected:
		return Result.WRONG
	current.typed += 1
	if current.typed >= current.text.length():
		return Result.COMPLETED
	return Result.ADVANCED


## Call after handling COMPLETED to clear the lock.
func finish() -> Object:
	var done := current
	current = null
	return done


static func nearest(candidates: Array) -> Object:
	var best: Object = null
	for c: Object in candidates:
		if _is_alive(c) and (best == null or c.y > best.y):
			best = c
	return best


static func _is_alive(o: Object) -> bool:
	if not is_instance_valid(o):
		return false
	if "alive" in o:
		return o.alive
	return true
