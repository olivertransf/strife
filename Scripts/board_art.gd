extends Node2D

const CREAM := Color(0.95, 0.88, 0.70)
const COLLEGE := Color(0.58, 0.76, 0.90)
const CAREER := Color(0.95, 0.80, 0.42)
const FAMILY := Color(0.95, 0.68, 0.76)
const LIFE := Color(0.70, 0.86, 0.74)
const RISKY := Color(0.95, 0.60, 0.34)
const SAFE := Color(0.64, 0.84, 0.68)
const FORK := Color(0.90, 0.82, 0.62)

const WOOD := Color(0.34, 0.19, 0.10)
const WOOD_EDGE := Color(0.52, 0.32, 0.16)
const FELT := Color(0.10, 0.36, 0.27)
const FELT_NAP := Color(1, 1, 1, 0.035)
const GROOVE := Color(0.06, 0.16, 0.12, 0.95)
const INK_LIGHT := Color(0.98, 0.96, 0.91)
const INK_DARK := Color(0.22, 0.13, 0.08)

var spaces: Array[Spaces] = []
var lane: Dictionary = {}
var focus: Spaces
var motes: Array[Dictionary] = []
var _pulse := 0.0


func build(root: Node2D, college_name: String, career_name: String) -> void:
	spaces.clear()
	lane.clear()
	for child in root.get_children():
		if child is Spaces:
			spaces.append(child)
	var start := _named("Start")
	if start and start.next_spaces.size() >= 2:
		var college := _named(college_name)
		var career := _named(career_name)
		var shared := {}
		var from_college := _reach(college)
		var from_career := _reach(career)
		for key in from_college:
			if from_career.has(key):
				shared[key] = true
		for node in _until_shared(college, shared):
			lane[node.name] = COLLEGE
		for node in _until_shared(career, shared):
			lane[node.name] = CAREER
	_paint_forks()
	queue_redraw()


func burst(at: Vector2, tint: Color) -> void:
	for index in 6:
		var dir := Vector2.from_angle(float(index) / 6.0 * TAU + _pulse)
		motes.append({
			"at": to_local(at),
			"dir": dir,
			"tint": tint,
			"life": 0.42,
		})


func _process(delta: float) -> void:
	_pulse += delta
	var alive: Array[Dictionary] = []
	for mote in motes:
		var life := float(mote["life"]) - delta
		if life > 0.0:
			mote["life"] = life
			alive.append(mote)
	motes = alive
	queue_redraw()


func _draw() -> void:
	if spaces.is_empty():
		return
	var bounds := _bounds()
	_draw_table(bounds)
	_draw_tracks()
	_draw_tokens()
	_draw_motes()


func _bounds() -> Rect2:
	var min_p := Vector2(100000, 100000)
	var max_p := Vector2(-100000, -100000)
	for space in spaces:
		var at := to_local(space.global_position)
		min_p = min_p.min(at)
		max_p = max_p.max(at)
	var origin := min_p - Vector2(52, 52)
	return Rect2(origin, max_p - min_p + Vector2(104, 104))


func _draw_table(felt: Rect2) -> void:
	draw_colored_polygon(_round_poly(Rect2(Vector2(-1800, -1800), Vector2(3600, 3600)), 8), WOOD)
	for index in 18:
		var y := -1600.0 + float(index) * 180.0
		draw_line(Vector2(-1700, y), Vector2(1700, y + 30), Color(1, 1, 1, 0.025), 10, true)
	var lip := felt.grow(16)
	draw_colored_polygon(_round_poly(lip, 36), WOOD_EDGE)
	draw_colored_polygon(_round_poly(felt, 28), FELT)
	for index in 64:
		var px := felt.position.x + fmod(float(index) * 97.0, felt.size.x)
		var py := felt.position.y + fmod(float(index) * 57.0, felt.size.y)
		draw_circle(Vector2(px, py), 16, FELT_NAP)
	var stitch := felt.grow(-14)
	var a := stitch.position
	var b := Vector2(stitch.end.x, stitch.position.y)
	var c := stitch.end
	var d := Vector2(stitch.position.x, stitch.end.y)
	var thread := Color(0.93, 0.86, 0.68, 0.45)
	draw_dashed_line(a, b, thread, 1.4, 7, true, true)
	draw_dashed_line(b, c, thread, 1.4, 7, true, true)
	draw_dashed_line(c, d, thread, 1.4, 7, true, true)
	draw_dashed_line(d, a, thread, 1.4, 7, true, true)


func _draw_tracks() -> void:
	for space in spaces:
		if space.space_type == Spaces.SpaceType.END:
			continue
		var origin := to_local(space.global_position)
		for path in space.next_spaces:
			var dest := space.get_node(path) as Spaces
			if dest == null:
				continue
			var tip := to_local(dest.global_position)
			draw_line(origin, tip, GROOVE, 16, true)
	for space in spaces:
		if space.space_type == Spaces.SpaceType.END:
			continue
		var origin := to_local(space.global_position)
		for path in space.next_spaces:
			var dest := space.get_node(path) as Spaces
			if dest == null:
				continue
			var tip := to_local(dest.global_position)
			var paint := CREAM
			if lane.has(dest.name):
				paint = lane[dest.name] as Color
			draw_line(origin, tip, paint, 8, true)
			_chevron(origin, tip, paint.darkened(0.45))


func _chevron(origin: Vector2, tip: Vector2, ink: Color) -> void:
	var span := tip - origin
	if span.length() < 32.0:
		return
	var dir := span.normalized()
	var side := dir.orthogonal()
	var mid := origin.lerp(tip, 0.5)
	draw_colored_polygon(PackedVector2Array([
		mid + dir * 5.0,
		mid - dir * 3.0 + side * 3.2,
		mid - dir * 3.0 - side * 3.2,
	]), ink)


func _draw_tokens() -> void:
	for space in spaces:
		var at := to_local(space.global_position)
		var special := space.space_type == Spaces.SpaceType.STOP or space.space_type == Spaces.SpaceType.START or space.space_type == Spaces.SpaceType.END
		var radius := 14.0 if special else 11.5
		var fill := _fill(space.space_type)
		draw_circle(at + Vector2(1.4, 2.2), radius, Color(0, 0, 0, 0.28))
		if space.space_type == Spaces.SpaceType.STOP:
			draw_colored_polygon(_regular(at, radius + 1.0, 8, PI / 8.0), fill.darkened(0.4))
			draw_colored_polygon(_regular(at, radius - 1.2, 8, PI / 8.0), fill)
		else:
			draw_circle(at, radius, fill.darkened(0.38))
			draw_circle(at + Vector2(-0.6, -0.8), radius - 2.2, fill)
		draw_circle(at + Vector2(-2.4, -2.6), radius * 0.38, Color(1, 1, 1, 0.22))
		var ink := INK_DARK if fill.get_luminance() > 0.55 else INK_LIGHT
		_icon(space.space_type, at, ink)
		if space == focus:
			var ring := radius + 5.0 + sin(_pulse * 5.0) * 1.2
			draw_arc(at, ring, 0, TAU, 36, Color(0.98, 0.86, 0.42, 0.95), 2.4, true)
		if space.space_type == Spaces.SpaceType.START:
			_pill(at + Vector2(42, 16), "START")
		elif space.space_type == Spaces.SpaceType.END:
			_pill(at + Vector2(0, 28), "RETIRE")


func _draw_motes() -> void:
	for mote in motes:
		var life := float(mote["life"])
		var dir: Vector2 = mote["dir"]
		var origin: Vector2 = mote["at"]
		var tint: Color = mote["tint"]
		var at := origin + dir * (1.0 - life / 0.42) * 18.0
		tint.a = clampf(life / 0.42, 0.0, 1.0)
		draw_circle(at, 2.6, tint)


func _pill(at: Vector2, text: String) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var origin := at + Vector2(-width * 0.5 - 5, -24)
	draw_colored_polygon(_round_poly(Rect2(origin, Vector2(width + 10, 15)), 4), Color(0.08, 0.06, 0.04, 0.82))
	draw_string(font, origin + Vector2(5, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.98, 0.94, 0.86))


func _fill(kind: Spaces.SpaceType) -> Color:
	match kind:
		Spaces.SpaceType.PAYDAY:
			return Color(0.93, 0.74, 0.28)
		Spaces.SpaceType.ACTION:
			return Color(0.20, 0.52, 0.44)
		Spaces.SpaceType.HOUSE:
			return Color(0.80, 0.44, 0.26)
		Spaces.SpaceType.START:
			return Color(0.96, 0.93, 0.84)
		Spaces.SpaceType.BOY:
			return Color(0.34, 0.60, 0.86)
		Spaces.SpaceType.GIRL:
			return Color(0.88, 0.44, 0.60)
		Spaces.SpaceType.SPIN2WIN:
			return Color(0.90, 0.48, 0.20)
		Spaces.SpaceType.TWINS:
			return Color(0.60, 0.44, 0.80)
		Spaces.SpaceType.STAR:
			return Color(0.95, 0.82, 0.30)
		Spaces.SpaceType.STOP:
			return Color(0.78, 0.22, 0.18)
		Spaces.SpaceType.BONUS:
			return Color(0.34, 0.68, 0.40)
		Spaces.SpaceType.DEBT:
			return Color(0.42, 0.30, 0.22)
		Spaces.SpaceType.END:
			return Color(0.14, 0.36, 0.28)
	return Color(0.5, 0.5, 0.5)


func _icon(kind: Spaces.SpaceType, at: Vector2, ink: Color) -> void:
	match kind:
		Spaces.SpaceType.PAYDAY:
			draw_arc(at, 4.2, 0, TAU, 14, ink, 1.5, true)
			draw_line(at + Vector2(0, -5.2), at + Vector2(0, 5.2), ink, 1.4, true)
		Spaces.SpaceType.ACTION:
			draw_rect(Rect2(at + Vector2(-3.6, -4.6), Vector2(7.2, 9.2)), ink, false, 1.3)
			draw_line(at + Vector2(-2, -1), at + Vector2(2.2, -1), ink, 1.1, true)
			draw_line(at + Vector2(-2, 1.6), at + Vector2(2.2, 1.6), ink, 1.1, true)
		Spaces.SpaceType.HOUSE:
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(0, -5.5),
				at + Vector2(5.5, -1),
				at + Vector2(-5.5, -1),
			]), ink)
			draw_rect(Rect2(at + Vector2(-3.4, -1), Vector2(6.8, 5.4)), ink, true)
		Spaces.SpaceType.START:
			draw_line(at + Vector2(-1, 5), at + Vector2(-1, -5), ink, 1.4, true)
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(-1, -5),
				at + Vector2(5, -2.5),
				at + Vector2(-1, 0),
			]), ink)
		Spaces.SpaceType.BOY:
			draw_circle(at + Vector2(0, -2.4), 2.4, ink)
			draw_line(at + Vector2(0, 0.4), at + Vector2(0, 4.6), ink, 1.5, true)
		Spaces.SpaceType.GIRL:
			draw_circle(at + Vector2(0, -2.6), 2.3, ink)
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(0, 0),
				at + Vector2(4, 5),
				at + Vector2(-4, 5),
			]), ink)
		Spaces.SpaceType.TWINS:
			draw_circle(at + Vector2(-2.6, -1), 2.2, ink)
			draw_circle(at + Vector2(2.6, -1), 2.2, ink)
		Spaces.SpaceType.SPIN2WIN:
			draw_arc(at, 4.4, 0.4, 5.4, 12, ink, 1.6, true)
			draw_circle(at, 1.3, ink)
		Spaces.SpaceType.STAR:
			_star(at, 5.2, ink)
		Spaces.SpaceType.STOP:
			draw_rect(Rect2(at + Vector2(-3.2, -3.2), Vector2(6.4, 6.4)), ink, true)
		Spaces.SpaceType.BONUS:
			draw_line(at + Vector2(0, -4.5), at + Vector2(0, 4.5), ink, 1.8, true)
			draw_line(at + Vector2(-4.5, 0), at + Vector2(4.5, 0), ink, 1.8, true)
		Spaces.SpaceType.DEBT:
			draw_line(at + Vector2(-4.2, 0), at + Vector2(4.2, 0), ink, 1.8, true)
		Spaces.SpaceType.END:
			_star(at, 5.4, Color(0.95, 0.82, 0.38))


func _star(at: Vector2, radius: float, ink: Color) -> void:
	var pts := PackedVector2Array()
	for index in 10:
		var reach := radius if index % 2 == 0 else radius * 0.42
		var angle := -PI * 0.5 + float(index) * TAU / 10.0
		pts.append(at + Vector2(cos(angle), sin(angle)) * reach)
	draw_colored_polygon(pts, ink)


func _regular(at: Vector2, radius: float, sides: int, turn: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for index in sides:
		var angle := turn + TAU * float(index) / float(sides)
		pts.append(at + Vector2(cos(angle), sin(angle)) * radius)
	return pts


func _round_poly(rect: Rect2, radius: float) -> PackedVector2Array:
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
		for step in 7:
			var angle := starts[corner] + float(step) / 7.0 * (PI * 0.5)
			pts.append(centers[corner] + Vector2(cos(angle), sin(angle)) * reach)
	return pts


func _paint_forks() -> void:
	for space in spaces:
		if space.next_spaces.size() < 2 or space.space_type == Spaces.SpaceType.END:
			continue
		var found_family := false
		var found_risky := false
		var groups: Array[Dictionary] = []
		for index in space.next_spaces.size():
			var nodes := _exclusive(space, index)
			var kind := _kind_of(nodes)
			if kind == "family":
				found_family = true
			elif kind == "risky":
				found_risky = true
			groups.append({"nodes": nodes, "kind": kind})
		for group in groups:
			var kind := str(group["kind"])
			var paint := FORK
			if kind == "family":
				paint = FAMILY
			elif kind == "risky":
				paint = RISKY
			elif found_family:
				paint = LIFE
			elif found_risky:
				paint = SAFE
			var nodes: Array = group["nodes"]
			for node in nodes:
				var spot := node as Spaces
				if spot and not lane.has(spot.name):
					lane[spot.name] = paint


func _kind_of(nodes: Array[Spaces]) -> String:
	for node in nodes:
		match node.space_type:
			Spaces.SpaceType.BOY, Spaces.SpaceType.GIRL, Spaces.SpaceType.TWINS:
				return "family"
			Spaces.SpaceType.DEBT, Spaces.SpaceType.BONUS:
				return "risky"
			_:
				pass
	return ""


func _until_shared(entry: Spaces, shared: Dictionary) -> Array[Spaces]:
	var marked: Array[Spaces] = []
	var node := entry
	var guard := 0
	while node and guard < 80:
		if shared.has(node.name):
			break
		marked.append(node)
		if node.space_type == Spaces.SpaceType.END or node.next_spaces.size() != 1:
			break
		node = node.get_node(node.next_spaces[0]) as Spaces
		guard += 1
	return marked


func _exclusive(space: Spaces, index: int) -> Array[Spaces]:
	var other := {}
	for side in space.next_spaces.size():
		if side == index:
			continue
		for key in _reach(space.get_node(space.next_spaces[side]) as Spaces):
			other[key] = true
	var nodes: Array[Spaces] = []
	var node := space.get_node(space.next_spaces[index]) as Spaces
	var guard := 0
	while node and guard < 24:
		if other.has(node.name):
			break
		nodes.append(node)
		if node.space_type == Spaces.SpaceType.END or node.next_spaces.size() != 1:
			break
		node = node.get_node(node.next_spaces[0]) as Spaces
		guard += 1
	return nodes


func _reach(start: Spaces) -> Dictionary:
	var seen := {}
	if start == null:
		return seen
	var stack: Array[Spaces] = [start]
	var guard := 0
	while stack.size() > 0 and guard < 500:
		guard += 1
		var node: Spaces = stack.pop_back()
		if seen.has(node.name):
			continue
		seen[node.name] = true
		if node.space_type == Spaces.SpaceType.END:
			continue
		for path in node.next_spaces:
			var nxt := node.get_node(path) as Spaces
			if nxt:
				stack.append(nxt)
	return seen


func _named(entry_name: String) -> Spaces:
	for space in spaces:
		if space.name == entry_name:
			return space
	return null
