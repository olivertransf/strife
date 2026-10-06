extends Node2D

var behind := false


func _draw() -> void:
	var player := get_parent() as Player
	if player == null:
		return
	if behind:
		_car(player)
	else:
		_badge(player)


func _car(player: Player) -> void:
	var tint := player.color
	draw_set_transform(Vector2(0, 28), 0, Vector2(1.45, 0.4))
	draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.38))
	draw_set_transform(Vector2(0, 20), 0, Vector2(1.25, 0.48))
	draw_circle(Vector2.ZERO, 17.0, tint.darkened(0.28))
	draw_set_transform(Vector2(0, 17), 0, Vector2(1.08, 0.4))
	draw_circle(Vector2.ZERO, 15.0, tint)
	draw_set_transform(Vector2(-7, 13), 0, Vector2(0.42, 0.24))
	draw_circle(Vector2.ZERO, 9.0, Color(1, 1, 1, 0.28))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _badge(player: Player) -> void:
	if player.people <= 1:
		return
	var at := Vector2(24, -4)
	draw_circle(at, 13, Color(0.08, 0.06, 0.05))
	draw_circle(at + Vector2(-1, -1), 11, player.color.lightened(0.12))
	var digits := str(player.people)
	var origin := at + Vector2(-5 if player.people < 10 else -8, 6)
	draw_string(ThemeDB.fallback_font, origin, digits, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.98, 0.96, 0.9))
