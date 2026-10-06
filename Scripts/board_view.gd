extends Node3D

const COLORS := {
	"payday": Color(0.18, 0.72, 0.34),
	"action": Color(0.95, 0.78, 0.22),
	"house": Color(0.62, 0.4, 0.24),
	"start": Color(0.95, 0.95, 0.92),
	"boy": Color(0.25, 0.55, 0.95),
	"girl": Color(0.95, 0.45, 0.72),
	"wheel": Color(0.58, 0.28, 0.86),
	"twins": Color(0.55, 0.78, 0.95),
	"stop": Color(0.86, 0.22, 0.22),
	"end": Color(0.98, 0.9, 0.55),
	"park": Color(0.55, 0.52, 0.45),
	"pet": Color(0.95, 0.52, 0.18),
}

const SPIN_TIME := 0.85

var markers := {}
var tile_mats := {}
var slice_mats: Array[StandardMaterial3D] = []
var wheel_needle: Node3D
var wheel_position := Vector3.ZERO
var center := Vector3.ZERO
var span := 20.0
var focus_ring: MeshInstance3D
var _previewed: Array[String] = []
var _breathe := 0.0
var _focus_tween: Tween


func build(spaces_root: Node, table: Dictionary) -> void:
	markers.clear()
	tile_mats.clear()
	var roads := Node3D.new()
	roads.name = "Roads"
	add_child(roads)
	var min_x := 10000.0
	var max_x := -10000.0
	var min_z := 10000.0
	var max_z := -10000.0
	for child in spaces_root.get_children():
		if not (child is Spaces):
			continue
		var space := child as Spaces
		markers[space.name] = space
		var point := space.global_position
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.z)
		max_z = maxf(max_z, point.z)
		var row: Dictionary = table.get(space.name, {})
		var kind := str(row.get("type", "action"))
		_paint(space, kind, str(row.get("label", "")))
	center = Vector3((min_x + max_x) * 0.5, 0, (min_z + max_z) * 0.5)
	span = maxf(max_x - min_x, max_z - min_z)
	for child in spaces_root.get_children():
		if not (child is Spaces):
			continue
		var space := child as Spaces
		for link in space.next_spaces:
			var nxt := space.get_node_or_null(link) as Node3D
			if nxt:
				_road(roads, space.global_position, nxt.global_position)
	_wheel(Vector3(min_x - 3.2, 0.35, center.z))
	_focus_ring()


func marker_position(space_name: String) -> Vector3:
	if not markers.has(space_name):
		return center
	var space := markers[space_name] as Spaces
	return space.global_position


func set_spin(value: int) -> void:
	if wheel_needle == null:
		return
	var angle := _slice_angle(value)
	light_number(value)
	var spin := create_tween()
	spin.tween_property(wheel_needle, "rotation:y", angle + TAU * 2.0 + 0.45, SPIN_TIME * 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	spin.tween_property(wheel_needle, "rotation:y", angle + TAU * 2.0, SPIN_TIME * 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func light_number(value: int) -> void:
	for i in slice_mats.size():
		var mat := slice_mats[i]
		var on := i + 1 == value
		mat.emission_enabled = on
		mat.emission_energy_multiplier = 0.85 if on else 0.0


func preview(names: Array) -> void:
	clear_preview()
	for space_name in names:
		_glow(str(space_name), 0.7)
		_previewed.append(str(space_name))
		await get_tree().create_timer(0.07).timeout
	var left := SPIN_TIME - float(names.size()) * 0.07
	if left > 0.05:
		await get_tree().create_timer(left).timeout


func clear_preview() -> void:
	for space_name in _previewed:
		_glow(space_name, 0.0)
	_previewed.clear()


func dim(space_name: String) -> void:
	_glow(space_name, 0.0)


func focus(space_name: String) -> void:
	if focus_ring == null or not markers.has(space_name):
		return
	var at := marker_position(space_name)
	at.y = 0.09
	focus_ring.visible = true
	if _focus_tween:
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.tween_property(focus_ring, "global_position", at, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func float_money(at: Vector3, text: String, tint: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 72
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 12
	label.modulate = tint
	label.position = at + Vector3(0, 0.72, 0)
	label.no_depth_test = true
	add_child(label)
	var rise := create_tween()
	rise.set_parallel(true)
	rise.tween_property(label, "position:y", label.position.y + 0.85, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.tween_property(label, "modulate:a", 0.0, 0.45).set_delay(0.28)
	rise.chain().tween_callback(label.queue_free)


func next_direction(space_name: String) -> Vector3:
	if not markers.has(space_name):
		return Vector3.ZERO
	var space := markers[space_name] as Spaces
	var origin := space.global_position
	var sum := Vector3.ZERO
	var count := 0
	for link in space.next_spaces:
		var nxt := space.get_node_or_null(link) as Node3D
		if nxt == null:
			continue
		var step := nxt.global_position - origin
		step.y = 0
		if step.length() < 0.05:
			continue
		sum += step.normalized()
		count += 1
	if count == 0:
		return Vector3.ZERO
	return sum / float(count)


func _process(delta: float) -> void:
	if focus_ring == null or not focus_ring.visible:
		return
	_breathe += delta
	var scale := 1.0 + sin(_breathe * 3.2) * 0.035
	focus_ring.scale = Vector3(scale, 1.0, scale)


func _paint(space: Spaces, kind: String, custom: String) -> void:
	var mesh_node := space.get_node_or_null("CylinderMesh") as MeshInstance3D
	var color := Color(0.5, 0.5, 0.5)
	if COLORS.has(kind):
		color = COLORS[kind]
	_rim(space)
	if mesh_node:
		mesh_node.position.y = 0.03
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.42
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.0
		mesh_node.material_override = mat
		tile_mats[space.name] = mat
	_icon(space, kind, color)
	if not _named(kind) and custom == "":
		return
	var text := custom
	if text == "":
		text = _fallback_label(kind)
	if text == "":
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.004
	label.position = Vector3(0, 0.62, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.modulate = Color(0.98, 0.97, 0.94)
	label.no_depth_test = true
	space.add_child(label)


func _named(kind: String) -> bool:
	return kind in ["start", "stop", "end", "boy", "girl", "twins", "wheel"]


func _rim(space: Spaces) -> void:
	var rim := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.7
	cyl.bottom_radius = 0.74
	cyl.height = 0.1
	rim.mesh = cyl
	rim.position = Vector3(0, -0.01, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.12, 0.09)
	mat.roughness = 0.75
	rim.material_override = mat
	space.add_child(rim)


func _icon(space: Spaces, kind: String, color: Color) -> void:
	var icon := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.lightened(0.25)
	mat.roughness = 0.35
	match kind:
		"payday":
			var coin := CylinderMesh.new()
			coin.top_radius = 0.16
			coin.bottom_radius = 0.16
			coin.height = 0.04
			icon.mesh = coin
			mat.albedo_color = Color(0.95, 0.82, 0.28)
		"action":
			var star := BoxMesh.new()
			star.size = Vector3(0.22, 0.05, 0.22)
			icon.mesh = star
		"house":
			var body := BoxMesh.new()
			body.size = Vector3(0.28, 0.12, 0.22)
			icon.mesh = body
		"pet":
			var ball := SphereMesh.new()
			ball.radius = 0.1
			ball.height = 0.2
			icon.mesh = ball
		"wheel":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.08
			ring.outer_radius = 0.16
			icon.mesh = ring
		"boy", "girl", "twins":
			var peg := CapsuleMesh.new()
			peg.radius = 0.06
			peg.height = 0.2
			icon.mesh = peg
		_:
			return
	icon.material_override = mat
	icon.position = Vector3(0, 0.14, 0)
	space.add_child(icon)


func _fallback_label(kind: String) -> String:
	match kind:
		"boy":
			return "Boy"
		"girl":
			return "Girl"
		"twins":
			return "Twins"
		"wheel":
			return "Wheel"
		"start":
			return "Start"
		"end":
			return "Retire"
		"stop":
			return "Stop"
		_:
			return ""


func _glow(space_name: String, energy: float) -> void:
	if not tile_mats.has(space_name):
		return
	var mat: StandardMaterial3D = tile_mats[space_name]
	mat.emission_energy_multiplier = energy


func _road(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var delta := b - a
	delta.y = 0
	var length := delta.length()
	if length < 0.2:
		return
	var yaw := atan2(delta.x, delta.z)
	var road := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.028, length)
	road.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.22, 0.2)
	mat.roughness = 0.8
	road.material_override = mat
	road.position = (a + b) * 0.5
	road.position.y = 0.01
	road.rotation.y = yaw
	parent.add_child(road)
	var dash := MeshInstance3D.new()
	var dash_box := BoxMesh.new()
	dash_box.size = Vector3(0.06, 0.02, minf(0.55, length * 0.28))
	dash.mesh = dash_box
	var dash_mat := StandardMaterial3D.new()
	dash_mat.albedo_color = Color(0.93, 0.84, 0.45)
	dash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dash.material_override = dash_mat
	dash.position = a.lerp(b, 0.5)
	dash.position.y = 0.03
	dash.rotation.y = yaw
	parent.add_child(dash)
	var arrow := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.07
	cone.height = 0.16
	arrow.mesh = cone
	arrow.material_override = dash_mat
	arrow.position = a.lerp(b, 0.72)
	arrow.position.y = 0.045
	arrow.rotation = Vector3(PI * 0.5, yaw, 0)
	parent.add_child(arrow)


func _focus_ring() -> void:
	focus_ring = MeshInstance3D.new()
	focus_ring.name = "FocusRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.78
	focus_ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.86, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.82, 0.3)
	mat.emission_energy_multiplier = 0.7
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	focus_ring.material_override = mat
	focus_ring.visible = false
	add_child(focus_ring)


func _wheel(at: Vector3) -> void:
	wheel_position = at
	var root := Node3D.new()
	root.name = "LifeWheel"
	root.position = at
	add_child(root)
	var base := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.28
	disc.bottom_radius = 1.28
	disc.height = 0.08
	base.mesh = disc
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.1, 0.09, 0.08)
	base_mat.roughness = 0.55
	base.material_override = base_mat
	root.add_child(base)
	slice_mats.clear()
	for i in 10:
		var start := TAU * float(i) / 10.0 + 0.03
		var end := TAU * float(i + 1) / 10.0 - 0.03
		var wedge := MeshInstance3D.new()
		wedge.mesh = _wedge(start, end, 1.12, 0.07)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.78, 0.18, 0.16) if i < 5 else Color(0.22, 0.22, 0.26)
		mat.roughness = 0.4
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.emission_enabled = true
		mat.emission = Color(1, 0.86, 0.4)
		mat.emission_energy_multiplier = 0.0
		wedge.material_override = mat
		slice_mats.append(mat)
		root.add_child(wedge)
		var mid := (start + end) * 0.5
		var number := Label3D.new()
		number.text = str(i + 1)
		number.font_size = 48
		number.pixel_size = 0.004
		number.position = Vector3(sin(mid) * 0.72, 0.16, cos(mid) * 0.72)
		number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		number.outline_size = 8
		number.modulate = Color(0.98, 0.96, 0.9)
		root.add_child(number)
	wheel_needle = Node3D.new()
	root.add_child(wheel_needle)
	var needle := MeshInstance3D.new()
	var pointer := BoxMesh.new()
	pointer.size = Vector3(0.07, 0.04, 0.85)
	needle.mesh = pointer
	needle.position = Vector3(0, 0.12, 0.38)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.98, 0.88, 0.42)
	gold.emission_enabled = true
	gold.emission = Color(0.98, 0.86, 0.35)
	gold.emission_energy_multiplier = 0.4
	needle.material_override = gold
	wheel_needle.add_child(needle)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.12
	hub_mesh.bottom_radius = 0.12
	hub_mesh.height = 0.1
	hub.mesh = hub_mesh
	hub.position = Vector3(0, 0.12, 0)
	hub.material_override = gold
	root.add_child(hub)


func _wedge(start: float, end: float, radius: float, y: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 4
	for step in steps:
		var a0 := lerpf(start, end, float(step) / float(steps))
		var a1 := lerpf(start, end, float(step + 1) / float(steps))
		tool.set_normal(Vector3.UP)
		tool.add_vertex(Vector3(0, y, 0))
		tool.set_normal(Vector3.UP)
		tool.add_vertex(Vector3(sin(a1) * radius, y, cos(a1) * radius))
		tool.set_normal(Vector3.UP)
		tool.add_vertex(Vector3(sin(a0) * radius, y, cos(a0) * radius))
	return tool.commit()


func _slice_angle(value: int) -> float:
	return TAU * (float(value) - 0.5) / 10.0
