extends RefCounted

var careers: Array[Dictionary] = []
var college: Array[Dictionary] = []
var houses: Array[Dictionary] = []
var actions: Array[Dictionary] = []
var pets: Array[Dictionary] = []

var _source: Dictionary = {}


func _init() -> void:
	_source = {
		"careers": _career_source(false),
		"college": _career_source(true),
		"houses": _house_source(),
		"actions": _action_source(),
		"pets": _pet_source(),
	}
	refill("careers")
	refill("college")
	refill("houses")
	refill("actions")
	refill("pets")


func draw(pile: String) -> Dictionary:
	var deck := _pile(pile)
	if deck.is_empty():
		refill(pile)
	if deck.is_empty():
		return {}
	return (deck.pop_front() as Dictionary).duplicate(true)


func to_bottom(pile: String, card: Dictionary) -> void:
	if card.is_empty():
		return
	_pile(pile).append(card.duplicate(true))


func refill(pile: String) -> void:
	var deck := _pile(pile)
	deck.clear()
	for card in _source[pile]:
		deck.append((card as Dictionary).duplicate(true))
	deck.shuffle()


func _pile(pile: String) -> Array[Dictionary]:
	match pile:
		"careers":
			return careers
		"college":
			return college
		"houses":
			return houses
		"actions":
			return actions
		"pets":
			return pets
		_:
			return actions


func _career_source(is_college: bool) -> Array[Dictionary]:
	if is_college:
		return [
			_job("Doctor", 100),
			_job("Lawyer", 90),
			_job("Accountant", 80),
			_job("Scientist", 80),
			_job("Designer", 70),
			_job("Architect", 70),
			_job("Engineer", 60),
			_job("Journalist", 60),
		]
	return [
		_job("Teacher", 40),
		_job("Mechanic", 40),
		_job("Athlete", 50),
		_job("Artist", 30),
		_job("Mail carrier", 20),
		_job("Salesperson", 30),
		_job("Chef", 30),
		_job("Ranger", 40),
	]


func _house_source() -> Array[Dictionary]:
	return [
		_house("Cabin", 40, 70, 30),
		_house("Cottage", 50, 80, 40),
		_house("Studio", 60, 50, 90),
		_house("Flat", 80, 110, 60),
		_house("Loft", 100, 80, 140),
		_house("Bungalow", 120, 160, 90),
		_house("Villa", 160, 200, 120),
		_house("Manor", 200, 240, 160),
	]


func _action_source() -> Array[Dictionary]:
	return [
		_card("Family picnic", "action", "bank", 20),
		_card("Tax refund", "action", "bank", 50),
		_card("Side gig", "action", "bank", 30),
		_card("Garage sale", "action", "bank", 10),
		_card("Car repair", "action", "charge", 20),
		_card("Lost wallet", "action", "charge", 30),
		_card("Clinic bill", "action", "charge", 40),
		_card("Parking fines", "action", "charge", 10),
		_card("Birthday dinner", "action", "each", 10),
		_card("Housewarming", "action", "each", 20),
		_card("You host", "action", "pay", 10),
		_card("Group gift", "action", "pay", 20),
		_card("Bonus week", "action", "bank", 40),
		_card("Appliance break", "action", "charge", 20),
		_card("Neighborhood fund", "action", "each", 10),
		_card("Shared ride", "action", "pay", 10),
	]


func _pet_source() -> Array[Dictionary]:
	return [
		_card("Loyal dog", "pet", "bank", 0),
		_card("Lap cat", "pet", "bank", 0),
		_card("Park parrot", "pet", "bank", 0),
		_card("Tank of fish", "pet", "bank", 0),
		_card("Barn rabbit", "pet", "bank", 0),
		_card("Pony club", "pet", "charge", 10),
		_card("Vet visit", "pet", "charge", 20),
		_card("Pet show", "pet", "bank", 20),
	]


func _job(job_name: String, salary: int) -> Dictionary:
	return {"name": job_name, "salary": salary}


func _house(house_name: String, cost: int, red_sale: int, black_sale: int) -> Dictionary:
	return {"name": house_name, "cost": cost, "red": red_sale, "black": black_sale}


func _card(card_name: String, kind: String, effect: String, amount: int) -> Dictionary:
	return {"name": card_name, "kind": kind, "effect": effect, "amount": amount}
