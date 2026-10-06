extends Node2D

var marks: Array[Vector2] = []


func follow(at: Vector2) -> void:
	global_position = at
	queue_redraw()


func set_marks(points: Array[Vector2]) -> void:
	marks = points
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var wobble := sin(float(Time.get_ticks_msec()) / 180.0) * 1.6
	var gold := Color(0.98, 0.84, 0.38, 0.95)
	draw_arc(Vector2.ZERO, 36.0 + wobble, 0, TAU, 48, gold, 3.0, true)
	draw_arc(Vector2.ZERO, 28.0, 0, TAU, 32, Color(0.98, 0.84, 0.38, 0.35), 1.6, true)
	for point in marks:
		var at := to_local(point)
		draw_arc(at, 18.0 + wobble * 0.4, 0, TAU, 28, gold, 3.0, true)
		draw_circle(at, 3.0, gold)
