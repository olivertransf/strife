extends Button

var face: Dictionary = {}
var hot := false


func _ready() -> void:
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_stylebox_override("disabled", empty)
	var hidden := Color(0, 0, 0, 0)
	add_theme_color_override("font_color", hidden)
	add_theme_color_override("font_hover_color", hidden)
	add_theme_color_override("font_pressed_color", hidden)
	add_theme_color_override("font_focus_color", hidden)
	add_theme_color_override("font_disabled_color", hidden)
	custom_minimum_size = Vector2(152, 210)
	focus_mode = Control.FOCUS_NONE
	mouse_entered.connect(func() -> void:
		hot = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		hot = false
		queue_redraw()
	)


func show_face(card: Dictionary, caption: String) -> void:
	face = card
	text = caption
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2(4, 2), size - Vector2(8, 6))
	var kind := str(face.get("kind", "action"))
	var accent := _accent(kind)
	var paper := Color(0.98, 0.95, 0.89)
	var ink := Color(0.2, 0.13, 0.08)
	draw_colored_polygon(_round(rect.grow(3), 12), Color(0, 0, 0, 0.28))
	draw_colored_polygon(_round(rect, 12), accent if hot else accent.darkened(0.08))
	var inner := rect.grow(-5)
	draw_colored_polygon(_round(inner, 9), paper)
	var font := ThemeDB.fallback_font
	var banner := str(kind).to_upper()
	var banner_size := font.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	draw_string(font, Vector2(size.x * 0.5 - banner_size.x * 0.5, 28), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, accent.darkened(0.25))
	var title := str(face.get("name", ""))
	var title_px := 16
	if font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x > 128.0:
		title_px = 13
	var title_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px)
	draw_string(font, Vector2(size.x * 0.5 - title_size.x * 0.5, 50), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px, ink)
	var plate := Vector2(size.x * 0.5, 112)
	draw_circle(plate + Vector2(1, 2), 34, Color(0, 0, 0, 0.12))
	draw_circle(plate, 33, accent)
	draw_circle(plate + Vector2(-8, -10), 10, Color(1, 1, 1, 0.16))
	_glyph(title, plate, Color(0.98, 0.96, 0.92))
	var footer := _footer()
	var foot_size := font.get_string_size(footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	draw_string(font, Vector2(size.x * 0.5 - foot_size.x * 0.5, 168), footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
	var sub := _sub()
	if sub != "":
		var sub_size := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		draw_string(font, Vector2(size.x * 0.5 - sub_size.x * 0.5, 186), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, accent.darkened(0.2))
	if hot and not disabled:
		var rim := _round(rect, 12)
		if rim.size() > 1:
			rim.append(rim[0])
			draw_polyline(rim, Color(0.95, 0.82, 0.42), 2.5, true)


func _footer() -> String:
	var kind := str(face.get("kind", ""))
	if kind == "career" or kind == "college":
		return "%dK salary" % int(face.get("salary", 0))
	if kind == "house":
		return "Buy %dK" % int(face.get("cost", 0))
	var amount := int(face.get("amount", 0))
	match str(face.get("effect", "")):
		"bank":
			return "A new pet" if amount <= 0 else "Collect %dK" % amount
		"charge":
			return "Pay %dK" % amount
		"each":
			return "Others pay you %dK" % amount
		"pay":
			return "Pay others %dK" % amount
		_:
			return ""


func _sub() -> String:
	if str(face.get("kind", "")) != "house":
		return ""
	return "Red %dK · Black %dK" % [int(face.get("red", 0)), int(face.get("black", 0))]


func _accent(kind: String) -> Color:
	match kind:
		"career":
			return Color(0.84, 0.62, 0.24)
		"college":
			return Color(0.32, 0.5, 0.74)
		"house":
			return Color(0.75, 0.42, 0.26)
		"pet":
			return Color(0.78, 0.58, 0.22)
		_:
			return Color(0.22, 0.5, 0.42)


func _glyph(card_name: String, at: Vector2, ink: Color) -> void:
	match card_name:
		"Teacher":
			_book(at, ink)
		"Mechanic":
			draw_line(at + Vector2(-10, 8), at + Vector2(8, -10), ink, 3, true)
			draw_circle(at + Vector2(8, -8), 5, ink)
		"Athlete":
			_cup(at, ink)
		"Artist":
			draw_circle(at, 10, ink)
			draw_circle(at + Vector2(-4, -2), 2.2, Color(0.9, 0.3, 0.28))
			draw_circle(at + Vector2(3, 2), 2.2, Color(0.3, 0.55, 0.85))
			draw_circle(at + Vector2(4, -4), 2.2, Color(0.95, 0.82, 0.3))
		"Mail carrier":
			_envelope(at, ink)
		"Salesperson":
			draw_colored_polygon(PackedVector2Array([at + Vector2(-4, -12), at + Vector2(8, -6), at + Vector2(-4, 12), at + Vector2(-8, 0)]), ink)
			draw_circle(at + Vector2(-2, -6), 2, Color(0.98, 0.95, 0.89))
		"Chef":
			draw_rect(Rect2(at + Vector2(-8, -2), Vector2(16, 12)), ink, true)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-8, -2), at + Vector2(-4, -12), at + Vector2(4, -12), at + Vector2(8, -2)]), ink)
		"Ranger":
			_pine(at, ink)
		"Doctor":
			_cross(at, ink, 12)
		"Lawyer":
			draw_line(at + Vector2(0, -10), at + Vector2(0, 10), ink, 2, true)
			draw_line(at + Vector2(-10, -4), at + Vector2(10, -4), ink, 2, true)
			draw_circle(at + Vector2(-8, 4), 5, ink)
			draw_circle(at + Vector2(8, 4), 5, ink)
		"Accountant":
			draw_circle(at + Vector2(0, 6), 7, ink)
			draw_circle(at + Vector2(-6, -1), 6, ink)
			draw_circle(at + Vector2(6, -2), 6, ink)
		"Scientist":
			draw_colored_polygon(PackedVector2Array([at + Vector2(-8, 10), at + Vector2(8, 10), at + Vector2(4, -2), at + Vector2(-4, -2)]), ink)
			draw_rect(Rect2(at + Vector2(-2, -12), Vector2(4, 10)), ink, true)
		"Designer":
			draw_line(at + Vector2(-8, 8), at + Vector2(10, -10), ink, 3, true)
			draw_colored_polygon(PackedVector2Array([at + Vector2(6, -12), at + Vector2(12, -8), at + Vector2(8, -4)]), ink)
		"Architect":
			_building(at, 2, 4, false, ink)
		"Engineer":
			draw_circle(at, 6, ink)
			draw_arc(at, 11, 0, TAU, 16, ink, 3, true)
		"Journalist":
			draw_rect(Rect2(at + Vector2(-10, -8), Vector2(20, 16)), ink, false, 2)
			draw_line(at + Vector2(-6, -3), at + Vector2(6, -3), ink, 1.5, true)
			draw_line(at + Vector2(-6, 2), at + Vector2(6, 2), ink, 1.5, true)
		"Cabin":
			_building(at, 1, 0, true, ink)
		"Cottage":
			_building(at, 1, 3, true, ink)
		"Studio":
			_building(at, 1, 6, false, ink)
		"Flat":
			_building(at, 2, 2, false, ink)
		"Loft":
			_building(at, 2, 8, false, ink)
		"Bungalow":
			_building(at, 1, 8, true, ink)
		"Villa":
			_building(at, 2, 10, true, ink)
		"Manor":
			_building(at, 3, 8, true, ink)
		"Family picnic":
			draw_rect(Rect2(at + Vector2(-10, -2), Vector2(20, 10)), ink, true)
			draw_arc(at + Vector2(0, -2), 8, PI, TAU, 10, ink, 2, true)
		"Tax refund":
			draw_rect(Rect2(at + Vector2(-8, -10), Vector2(16, 20)), ink, false, 2)
			draw_line(at + Vector2(-4, 2), at + Vector2(0, 6), ink, 2, true)
			draw_line(at + Vector2(0, 6), at + Vector2(6, -2), ink, 2, true)
		"Side gig":
			draw_circle(at, 10, ink)
			draw_circle(at, 10, Color(0.98, 0.95, 0.89), false, 2.0)
		"Garage sale":
			draw_rect(Rect2(at + Vector2(-10, -4), Vector2(20, 12)), ink, true)
			draw_line(at + Vector2(-10, -4), at + Vector2(0, -12), ink, 2, true)
			draw_line(at + Vector2(10, -4), at + Vector2(0, -12), ink, 2, true)
		"Car repair":
			_car(at, ink)
		"Lost wallet":
			draw_rect(Rect2(at + Vector2(-11, -7), Vector2(22, 14)), ink, true)
			draw_rect(Rect2(at + Vector2(-4, -7), Vector2(8, 5)), Color(0.98, 0.95, 0.89), true)
		"Clinic bill":
			_cross(at, ink, 10)
		"Parking fines":
			draw_rect(Rect2(at + Vector2(-8, -10), Vector2(16, 20)), ink, true)
		"Birthday dinner":
			draw_rect(Rect2(at + Vector2(-10, 0), Vector2(20, 8)), ink, true)
			draw_line(at + Vector2(0, 0), at + Vector2(0, -8), ink, 2, true)
		"Housewarming":
			_building(at + Vector2(0, 4), 1, 2, true, ink)
		"You host":
			draw_circle(at + Vector2(0, 2), 9, ink)
			draw_circle(at + Vector2(0, 2), 4, Color(0.98, 0.95, 0.89))
		"Group gift":
			draw_rect(Rect2(at + Vector2(-9, -4), Vector2(18, 12)), ink, true)
			draw_line(at + Vector2(0, -4), at + Vector2(0, 8), Color(0.98, 0.95, 0.89), 2, true)
			draw_line(at + Vector2(-9, 2), at + Vector2(9, 2), Color(0.98, 0.95, 0.89), 2, true)
		"Bonus week":
			_star(at, 12, ink)
		"Appliance break":
			draw_rect(Rect2(at + Vector2(-8, -10), Vector2(16, 20)), ink, true)
			draw_line(at + Vector2(-2, -6), at + Vector2(3, 6), Color(0.98, 0.95, 0.89), 2, true)
		"Neighborhood fund":
			draw_rect(Rect2(at + Vector2(-7, -4), Vector2(14, 14)), ink, true)
			draw_arc(at + Vector2(0, -4), 7, PI, TAU, 10, ink, 2, true)
		"Shared ride":
			_car(at + Vector2(-6, 2), ink)
			draw_circle(at + Vector2(8, -4), 5, ink)
		"Loyal dog":
			draw_circle(at + Vector2(0, 2), 8, ink)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-8, -2), at + Vector2(-12, -12), at + Vector2(-2, -4)]), ink)
			draw_colored_polygon(PackedVector2Array([at + Vector2(8, -2), at + Vector2(12, -12), at + Vector2(2, -4)]), ink)
		"Lap cat":
			draw_circle(at + Vector2(0, 3), 8, ink)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-8, 0), at + Vector2(-10, -12), at + Vector2(-2, -2)]), ink)
			draw_colored_polygon(PackedVector2Array([at + Vector2(8, 0), at + Vector2(10, -12), at + Vector2(2, -2)]), ink)
		"Park parrot":
			draw_circle(at + Vector2(-2, 0), 8, ink)
			draw_colored_polygon(PackedVector2Array([at + Vector2(4, -2), at + Vector2(14, 0), at + Vector2(4, 4)]), Color(0.95, 0.7, 0.3))
		"Tank of fish":
			draw_rect(Rect2(at + Vector2(-12, -8), Vector2(24, 16)), ink, false, 2)
			draw_circle(at, 4, ink)
		"Barn rabbit":
			draw_circle(at + Vector2(0, 4), 7, ink)
			draw_rect(Rect2(at + Vector2(-6, -12), Vector2(3, 12)), ink, true)
			draw_rect(Rect2(at + Vector2(3, -12), Vector2(3, 12)), ink, true)
		"Pony club":
			draw_circle(at + Vector2(2, 2), 8, ink)
			draw_rect(Rect2(at + Vector2(-12, -2), Vector2(12, 5)), ink, true)
		"Vet visit":
			_cross(at, ink, 9)
		"Pet show":
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -12), at + Vector2(8, 8), at + Vector2(-8, 8)]), ink)
			draw_circle(at + Vector2(0, 2), 3, Color(0.98, 0.95, 0.89))
		_:
			_star(at, 10, ink)


func _book(at: Vector2, ink: Color) -> void:
	draw_line(at + Vector2(0, -8), at + Vector2(0, 8), ink, 2, true)
	draw_arc(at + Vector2(-6, 0), 8, -1.2, 1.2, 8, ink, 2, true)
	draw_arc(at + Vector2(6, 0), 8, PI - 1.2, PI + 1.2, 8, ink, 2, true)


func _cup(at: Vector2, ink: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-8, -8),
		at + Vector2(8, -8),
		at + Vector2(5, 4),
		at + Vector2(-5, 4),
	]), ink)
	draw_rect(Rect2(at + Vector2(-8, 6), Vector2(16, 3)), ink, true)
	draw_line(at + Vector2(0, -8), at + Vector2(0, -13), ink, 2, true)


func _envelope(at: Vector2, ink: Color) -> void:
	draw_rect(Rect2(at + Vector2(-12, -8), Vector2(24, 16)), ink, false, 2)
	draw_line(at + Vector2(-12, -8), at + Vector2(0, 2), ink, 2, true)
	draw_line(at + Vector2(12, -8), at + Vector2(0, 2), ink, 2, true)


func _pine(at: Vector2, ink: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -14), at + Vector2(10, 2), at + Vector2(-10, 2)]), ink)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -6), at + Vector2(12, 10), at + Vector2(-12, 10)]), ink)
	draw_rect(Rect2(at + Vector2(-2, 10), Vector2(4, 5)), ink, true)


func _cross(at: Vector2, ink: Color, reach: float) -> void:
	draw_rect(Rect2(at + Vector2(-reach * 0.28, -reach), Vector2(reach * 0.56, reach * 2.0)), ink, true)
	draw_rect(Rect2(at + Vector2(-reach, -reach * 0.28), Vector2(reach * 2.0, reach * 0.56)), ink, true)


func _car(at: Vector2, ink: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-12, 2),
		at + Vector2(-8, -6),
		at + Vector2(4, -6),
		at + Vector2(12, 2),
		at + Vector2(12, 6),
		at + Vector2(-12, 6),
	]), ink)
	draw_circle(at + Vector2(-6, 7), 3, Color(0.98, 0.95, 0.89))
	draw_circle(at + Vector2(6, 7), 3, Color(0.98, 0.95, 0.89))


func _building(at: Vector2, floors: int, extra: float, chimney: bool, ink: Color) -> void:
	var wide := 12.0 + extra
	var body := 8.0 + float(floors) * 5.0
	var base := at + Vector2(0, 10)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-wide, -body * 0.2),
		base + Vector2(0, -body * 0.85),
		base + Vector2(wide, -body * 0.2),
	]), ink)
	draw_rect(Rect2(base + Vector2(-wide * 0.7, -body * 0.2), Vector2(wide * 1.4, body * 0.75)), ink, true)
	if chimney:
		draw_rect(Rect2(base + Vector2(wide * 0.28, -body * 0.7), Vector2(3.5, 8)), ink, true)


func _star(at: Vector2, radius: float, ink: Color) -> void:
	var pts := PackedVector2Array()
	for index in 10:
		var reach := radius if index % 2 == 0 else radius * 0.42
		var angle := -PI * 0.5 + float(index) * TAU / 10.0
		pts.append(at + Vector2(cos(angle), sin(angle)) * reach)
	draw_colored_polygon(pts, ink)


func _round(rect: Rect2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var reach := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var centers: Array[Vector2] = [
		rect.position + Vector2(reach, reach),
		Vector2(rect.end.x - reach, rect.position.y + reach),
		rect.end - Vector2(reach, reach),
		Vector2(rect.position.x + reach, rect.end.y - reach),
	]
	var starts: Array[float] = [PI, PI * 1.5, 0.0, PI * 0.5]
	for corner in 4:
		for step in 6:
			var angle := starts[corner] + float(step) / 6.0 * (PI * 0.5)
			pts.append(centers[corner] + Vector2(cos(angle), sin(angle)) * reach)
	return pts
