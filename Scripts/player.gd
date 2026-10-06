extends Sprite2D
class_name Player

const CAR_CAPACITY := 6

var color: Color = Color(0.86, 0.27, 0.22)
var _back
var _badge
var money: int = 200
var job: Job
var title: String
var age: int
var speed: int = 1

var salary: int = 0
var job_name: String = ""
var took_college: bool = false
var people: int = 1
var babies: int = 0
var married: bool = false
var loans: int = 0
var retired: bool = false
var estate: String = ""
var houses: Array[Dictionary] = []
var actions: Array[Dictionary] = []
var pets: Array[Dictionary] = []
var pet_name: String = ""
var display_name: String = ""
var forced_index: int = -1
var space: Spaces


func _ready() -> void:
	display_name = name
	frame = 0
	scale = Vector2(0.55, 0.55)
	z_index = 8
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var label := $player_name as RichTextLabel
	label.text = ""
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.offset_top = -72
	label.offset_bottom = -44
	label.add_theme_color_override("default_color", Color(0.98, 0.96, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_font_size_override("normal_font_size", 22)
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.z_index = 3
	var decal := preload("res://Scripts/peg_decal.gd")
	_back = decal.new()
	_back.behind = true
	_back.show_behind_parent = true
	_back.z_index = -1
	add_child(_back)
	_badge = decal.new()
	_badge.z_index = 2
	add_child(_badge)


func set_peg_name(peg_name: String) -> void:
	display_name = peg_name
	var label := $player_name as RichTextLabel
	label.clear()
	label.add_text(peg_name)


func restyle() -> void:
	if _back:
		_back.queue_redraw()
	if _badge:
		_badge.queue_redraw()


func hop() -> void:
	var rest := Vector2(0.55, 0.55)
	scale = Vector2(0.68, 0.4)
	var tween := create_tween()
	tween.tween_property(self, "scale", rest, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func add_people(count: int) -> int:
	var room := CAR_CAPACITY - people
	var added := mini(count, maxi(room, 0))
	people += added
	babies += added
	restyle()
	return added


func summary() -> String:
	var lines: PackedStringArray = []
	if job_name == "":
		lines.append("No job yet")
	else:
		lines.append("%s, %dK" % [job_name, salary])
	var life := "%d in the car · %d %s" % [people, babies, "baby" if babies == 1 else "babies"]
	if married:
		life += " · married"
	if loans > 0:
		life += " · %d %s" % [loans, "loan" if loans == 1 else "loans"]
	if retired:
		life += " · retired"
	if estate != "":
		life += " · " + estate
	lines.append(life)
	if pet_name != "":
		lines.append("Pet " + pet_name)
	if houses.size() > 0:
		var house_names: PackedStringArray = []
		for house in houses:
			house_names.append(str(house["name"]))
		lines.append(", ".join(house_names))
	if actions.size() > 0:
		lines.append("%d action %s" % [actions.size(), "card" if actions.size() == 1 else "cards"])
	if pets.size() > 0:
		lines.append("%d pet %s" % [pets.size(), "card" if pets.size() == 1 else "cards"])
	return "\n".join(lines)
