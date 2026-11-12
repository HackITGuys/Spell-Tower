class_name WidthCap
extends Container
## Centres its children horizontally at most `max_width` wide (scaled with the
## player's text size), so layouts don't stretch across wide landscape screens.

var max_width := 760.0


func _init(p_max_width: float = 760.0) -> void:
	max_width = p_max_width


func cap() -> float:
	return minf(size.x, max_width * Term.scale)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var w := cap()
		for c in get_children():
			if c is Control and c.visible:
				fit_child_in_rect(c, Rect2((size.x - w) / 2.0, 0.0, w, size.y))


func _get_minimum_size() -> Vector2:
	var m := Vector2.ZERO
	for c in get_children():
		if c is Control and c.visible:
			m = m.max(c.get_combined_minimum_size())
	return Vector2(minf(m.x, max_width * Term.scale), m.y)
