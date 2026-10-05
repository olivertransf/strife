extends Sprite2D
class_name Player

const CAR_CAPACITY := 6

var color: Color
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
	scale = Vector2(0.62, 0.62)
	z_index = 5
	var label := $player_name as RichTextLabel
	label.add_theme_color_override("default_color", Color(0.98, 0.96, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05))
	label.add_theme_constant_override("outline_size", 6)
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF


func set_peg_name(peg_name: String) -> void:
	display_name = peg_name
	var label := $player_name as RichTextLabel
	label.clear()
	label.add_text(peg_name)


func add_people(count: int) -> int:
	var room := CAR_CAPACITY - people
	var added := mini(count, maxi(room, 0))
	people += added
	babies += added
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
