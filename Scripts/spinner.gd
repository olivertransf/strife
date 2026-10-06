extends Control

var angle := 0.0:
	set(value):
		angle = value
		queue_redraw()

var landed := 0:
	set(value):
		landed = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(0, 176)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_value(value: int, animate: bool) -> void:
	landed = value
	var target := -float(value - 1) * 36.0
	if not animate:
		angle = target
		return
	var dest := target
	while dest > angle - 300.0:
		dest -= 360.0
	dest -= 720.0
	var tween := create_tween()
	tween.tween_property(self, "angle", dest, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var center := Vector2(size.x * 0.5, 88)
	var radius := 62.0
	var inner := 24.0
	draw_circle(center, radius + 16, Color(0.22, 0.12, 0.07))
	draw_circle(center, radius + 12, Color(0.62, 0.40, 0.20))
	draw_circle(center, radius + 8, Color(0.28, 0.16, 0.09))
	draw_circle(center, radius + 2, Color(0.08, 0.06, 0.05))
	var font := ThemeDB.fallback_font
	for index in 10:
		var gap := deg_to_rad(1.8)
		var start := deg_to_rad(angle - 90.0 + float(index) * 36.0 - 18.0) + gap
		var finish := start + deg_to_rad(36.0) - gap * 2.0
		var odd := index % 2 == 0
		var color := Color(0.78, 0.24, 0.20) if odd else Color(0.16, 0.14, 0.13)
		var pts := PackedVector2Array()
		pts.append(center + Vector2(cos(start), sin(start)) * inner)
		for step in 4:
			var sweep := start + (finish - start) * float(step) / 3.0
			pts.append(center + Vector2(cos(sweep), sin(sweep)) * radius)
		pts.append(center + Vector2(cos(finish), sin(finish)) * inner)
		draw_colored_polygon(pts, color)
		var mid := (start + finish) * 0.5
		var pos := center + Vector2(cos(mid), sin(mid)) * 43.0
		var text := str(index + 1)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string(font, pos + Vector2(-text_size.x * 0.5, text_size.y * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.98, 0.95, 0.88))
	draw_circle(center, 22, Color(0.72, 0.54, 0.24))
	draw_circle(center, 18, Color(0.12, 0.09, 0.07))
	var hub := str(landed) if landed > 0 else "·"
	var hub_size := font.get_string_size(hub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string(font, center + Vector2(-hub_size.x * 0.5, hub_size.y * 0.32), hub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.98, 0.94, 0.84))
	var tip := center + Vector2(0, -radius - 14)
	draw_colored_polygon(PackedVector2Array([
		tip,
		center + Vector2(-7, -radius + 2),
		center + Vector2(7, -radius + 2),
	]), Color(0.98, 0.86, 0.42))
	draw_circle(center + Vector2(0, -radius + 2), 3.5, Color(0.98, 0.86, 0.42))
