extends Camera3D

var want := Vector3(0, 18, 14)
var look := Vector3.ZERO


func shot(mode: String, target: Vector3, span: float) -> void:
	look = target
	match mode:
		"overview", "score":
			want = target + Vector3(0, span * 0.72, span * 0.42)
		"follow":
			want = target + Vector3(-1.6, 4.2, 6.2)
		"card":
			want = target + Vector3(1.2, 3.4, 4.6)
		"wheel":
			want = target + Vector3(2.2, 2.6, 3.4)
		"fork":
			want = target + Vector3(-1.2, 4.6, 5.2)
		_:
			want = target + Vector3(0, 8, 8)


func snap() -> void:
	global_position = want
	if global_position.distance_to(look) > 0.05:
		look_at(look, Vector3.UP)


func _process(delta: float) -> void:
	global_position = global_position.lerp(want, 1.0 - exp(-6.0 * delta))
	if global_position.distance_to(look) > 0.05:
		look_at(look, Vector3.UP)
