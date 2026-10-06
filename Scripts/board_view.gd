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

var markers := {}
var wheel_needle: Node3D
var wheel_position := Vector3.ZERO
var center := Vector3.ZERO
var span := 20.0


func build(spaces_root: Node, table: Dictionary) -> void:
	markers.clear()
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


func marker_position(space_name: String) -> Vector3:
	if not markers.has(space_name):
		return center
	var space := markers[space_name] as Spaces
	return space.global_position


func set_spin(value: int) -> void:
	if wheel_needle == null:
		return
	var angle := float(value) / 10.0 * TAU
	var tween := create_tween()
	tween.tween_property(wheel_needle, "rotation:y", angle + TAU * 2.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _paint(space: Spaces, kind: String, custom: String) -> void:
	var mesh_node := space.get_node_or_null("CylinderMesh") as MeshInstance3D
	var color := Color(0.5, 0.5, 0.5)
	if COLORS.has(kind):
		color = COLORS[kind]
	if mesh_node:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.4
		mesh_node.material_override = mat
	var text := custom
	if text == "":
		text = _fallback_label(kind)
	if text == "":
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.004
	label.position = Vector3(0, 0.42, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.modulate = Color(0.98, 0.97, 0.94)
	space.add_child(label)


func _fallback_label(kind: String) -> String:
	match kind:
		"payday":
			return "Pay"
		"action":
			return "Action"
		"house":
			return "House"
		"boy":
			return "Boy"
		"girl":
			return "Girl"
		"twins":
			return "Twins"
		"wheel":
			return "Wheel"
		"pet":
			return "Pet"
		"start":
			return "Start"
		"end":
			return "Retire"
		"stop":
			return "Stop"
		_:
			return ""


func _road(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var delta := b - a
	delta.y = 0
	var length := delta.length()
	if length < 0.2:
		return
	var road := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.46, 0.035, length)
	road.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.2, 0.18)
	mat.roughness = 0.85
	road.material_override = mat
	road.position = (a + b) * 0.5
	road.position.y = 0.015
	road.rotation.y = atan2(delta.x, delta.z)
	parent.add_child(road)


func _wheel(at: Vector3) -> void:
	wheel_position = at
	var root := Node3D.new()
	root.name = "LifeWheel"
	root.position = at
	add_child(root)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.15
	cyl.bottom_radius = 1.15
	cyl.height = 0.08
	disc.mesh = cyl
	var base := StandardMaterial3D.new()
	base.albedo_color = Color(0.12, 0.12, 0.14)
	disc.material_override = base
	root.add_child(disc)
	_half(root, Color(0.75, 0.16, 0.18), -0.28)
	_half(root, Color(0.12, 0.12, 0.14), 0.28)
	wheel_needle = Node3D.new()
	root.add_child(wheel_needle)
	var needle := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.06, 0.95)
	needle.mesh = box
	needle.position = Vector3(0, 0.08, -0.35)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.9, 0.55)
	needle.material_override = mat
	wheel_needle.add_child(needle)
	var title := Label3D.new()
	title.text = "1-10"
	title.font_size = 72
	title.pixel_size = 0.005
	title.position = Vector3(0, 0.45, 0)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(title)


func _half(root: Node3D, color: Color, x: float) -> void:
	var half := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.95, 0.09, 1.7)
	half.mesh = box
	half.position = Vector3(x, 0.03, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	half.material_override = mat
	root.add_child(half)
