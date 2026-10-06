extends Node3D
class_name Player

var seat := 0
var ai := true
var display_name := ""
var built_people := -1
var built_pets := -1

func setup_view(index: int, car_color: Color, person_name: String) -> void:
	seat = index
	display_name = person_name
	var legacy := get_node_or_null("player_name")
	if legacy:
		legacy.hide()
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		mesh.scale = Vector3(0.07, 0.07, 0.07)
		var source := mesh.get_surface_override_material(0)
		var mat := StandardMaterial3D.new()
		if source is StandardMaterial3D and source.albedo_texture:
			mat.albedo_texture = source.albedo_texture
		mat.albedo_color = car_color
		mat.roughness = 0.35
		mesh.set_surface_override_material(0, mat)
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	var blob := CylinderMesh.new()
	blob.top_radius = 0.28
	blob.bottom_radius = 0.28
	blob.height = 0.012
	shadow.mesh = blob
	shadow.position = Vector3(0, 0.012, 0)
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(0, 0, 0, 0.35)
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = shade
	add_child(shadow)
	var pad := MeshInstance3D.new()
	pad.name = "Pad"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.2
	disc.bottom_radius = 0.2
	disc.height = 0.015
	pad.mesh = disc
	pad.position = Vector3(0, 0.02, 0)
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = car_color
	pad_mat.emission_enabled = true
	pad_mat.emission = car_color
	pad_mat.emission_energy_multiplier = 0.28
	pad.material_override = pad_mat
	add_child(pad)
	var name_label := Label3D.new()
	name_label.name = "NameLabel"
	name_label.text = person_name
	name_label.font_size = 48
	name_label.pixel_size = 0.0024
	name_label.position = Vector3(0, 0.5, 0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.outline_size = 10
	name_label.modulate = Color.WHITE
	name_label.no_depth_test = true
	add_child(name_label)
	var pegs := Node3D.new()
	pegs.name = "Pegs"
	add_child(pegs)


func set_active(on: bool) -> void:
	var label := get_node_or_null("NameLabel") as Label3D
	if label:
		label.modulate = Color(1, 0.86, 0.35) if on else Color.WHITE


func drive(moving: bool) -> void:
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh == null:
		return
	var pitch := -0.14 if moving else 0.0
	var tilt := create_tween()
	tilt.tween_property(mesh, "rotation:x", pitch, 0.12).set_trans(Tween.TRANS_SINE)


func set_pegs(people: int, pets: int) -> void:
	if people == built_people and pets == built_pets:
		return
	var grow_people := built_people >= 0 and people > built_people
	var grow_pets := built_pets >= 0 and pets > built_pets
	var people_from := built_people if built_people >= 0 else people
	var pets_from := built_pets if built_pets >= 0 else pets
	built_people = people
	built_pets = pets
	var root := get_node_or_null("Pegs")
	if root == null:
		return
	for child in root.get_children():
		child.free()
	var shown_people := mini(people, 6)
	for i in shown_people:
		var peg := _peg(CapsuleMesh.new(), Color(0.2, 0.48, 0.9) if i % 2 == 0 else Color(0.93, 0.4, 0.68))
		var capsule := peg.mesh as CapsuleMesh
		capsule.radius = 0.045
		capsule.height = 0.18
		peg.position = Vector3(-0.16 + (i % 3) * 0.14, 0.32, -0.04 + float(i / 3) * 0.12)
		root.add_child(peg)
		if grow_people and i >= people_from:
			_pop(peg)
	var shown_pets := mini(pets, 3)
	for i in shown_pets:
		var peg := _peg(SphereMesh.new(), Color(0.95, 0.58, 0.18))
		var sphere := peg.mesh as SphereMesh
		sphere.radius = 0.05
		sphere.height = 0.1
		peg.position = Vector3(0.22, 0.24, -0.06 + i * 0.1)
		root.add_child(peg)
		if grow_pets and i >= pets_from:
			_pop(peg)


func _peg(mesh: Mesh, color: Color) -> MeshInstance3D:
	var peg := MeshInstance3D.new()
	peg.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	peg.material_override = mat
	return peg


func _pop(peg: MeshInstance3D) -> void:
	peg.scale = Vector3(0.05, 0.05, 0.05)
	var pop := create_tween()
	pop.tween_property(peg, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
