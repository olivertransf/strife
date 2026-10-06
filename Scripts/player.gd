extends Node3D
class_name Player

var seat := 0
var ai := true
var display_name := ""

func setup_view(index: int, car_color: Color, person_name: String) -> void:
	seat = index
	display_name = person_name
	var legacy := get_node_or_null("player_name")
	if legacy:
		legacy.hide()
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var source := mesh.get_surface_override_material(0)
		var mat := StandardMaterial3D.new()
		if source is StandardMaterial3D and source.albedo_texture:
			mat.albedo_texture = source.albedo_texture
		mat.albedo_color = car_color
		mat.roughness = 0.35
		mesh.set_surface_override_material(0, mat)
	var name_label := Label3D.new()
	name_label.name = "NameLabel"
	name_label.text = person_name
	name_label.font_size = 64
	name_label.pixel_size = 0.003
	name_label.position = Vector3(0, 0.55, 0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.outline_size = 10
	name_label.modulate = Color.WHITE
	add_child(name_label)
	var pegs := Node3D.new()
	pegs.name = "Pegs"
	add_child(pegs)


func set_pegs(people: int, pets: int) -> void:
	var root := get_node_or_null("Pegs")
	if root == null:
		return
	for child in root.get_children():
		child.free()
	var shown_people := mini(people, 6)
	for i in shown_people:
		var peg := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.045
		capsule.height = 0.18
		peg.mesh = capsule
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.48, 0.9) if i % 2 == 0 else Color(0.93, 0.4, 0.68)
		peg.material_override = mat
		peg.position = Vector3(-0.16 + (i % 3) * 0.14, 0.32, -0.04 + float(i / 3) * 0.12)
		root.add_child(peg)
	var shown_pets := mini(pets, 3)
	for i in shown_pets:
		var peg := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.05
		sphere.height = 0.1
		peg.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.58, 0.18)
		peg.material_override = mat
		peg.position = Vector3(0.22, 0.24, -0.06 + i * 0.1)
		root.add_child(peg)
