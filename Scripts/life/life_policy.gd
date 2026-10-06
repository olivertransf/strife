extends RefCounted
class_name LifePolicy

static func choose(rules) -> Dictionary:
	var info: Dictionary = rules.prompt()
	var phase := str(info.get("phase", ""))
	match phase:
		"choose_start":
			var college := wants_college(rules)
			return {"op": "start", "college": college}
		"choose_card":
			return _keep(rules)
		"spin":
			return _spin(rules)
		"choose_fork":
			return _fork(rules)
		"choose_house":
			return _house(rules)
		"wheel_pick":
			return _wheel(rules, info)
		_:
			return {"op": "spin"}


static func wants_college(rules) -> bool:
	var avg_career := _avg(rules, "career")
	var avg_college := _avg(rules, "college")
	var career_steps := _steps(rules, rules._branch("Space0", 0), "Space13")
	var college_steps := _steps(rules, rules._branch("Space0", 1), "Space13")
	var sooner := float(career_steps - college_steps) / 8.0 * avg_career
	var edge := (avg_college - avg_career) * 4.0 - 100.0
	return edge > sooner


static func _keep(rules) -> Dictionary:
	var kind := str(rules.pending.get("kind", ""))
	if kind == "night_keep":
		var offered: Dictionary = rules.pending.cards[0]
		var current_salary := 0
		if rules.pending.current is Dictionary:
			current_salary = int(rules.pending.current.salary)
		if int(offered.salary) > current_salary:
			return {"op": "keep", "index": 0}
		return {"op": "keep", "index": 1}
	if kind == "house_pick":
		var best := 0
		var best_value := -100000.0
		for i in rules.pending.cards.size():
			var card: Dictionary = rules.pending.cards[i]
			var value := (float(card.red) + float(card.black)) * 0.5 - float(card.price)
			if value > best_value:
				best_value = value
				best = i
		return {"op": "keep", "index": best}
	var richest := 0
	var best_salary := -1
	for i in rules.pending.cards.size():
		var salary := int(rules.pending.cards[i].get("salary", 0))
		if salary > best_salary:
			best_salary = salary
			richest = i
	return {"op": "keep", "index": richest}


static func _spin(rules) -> Dictionary:
	var me: Dictionary = rules.players[rules.turn]
	if int(me.loans) > 0 and int(me.cash) >= 200:
		return {"op": "repay"}
	return {"op": "spin"}


static func _fork(rules) -> Dictionary:
	var kind := str(rules.pending.get("kind", ""))
	var options: Array = rules.pending.get("options", [])
	var me: Dictionary = rules.players[rules.turn]
	var cash := int(me.cash)
	if kind == "family":
		return options[1] if cash >= 80 else options[0]
	if kind == "risky":
		return options[0] if cash >= 150 else options[1]
	if kind == "retirement":
		var ahead := true
		for other in rules.players:
			if int(other.i) != int(me.i) and int(other.cash) > cash:
				ahead = false
		return options[1] if ahead else options[0]
	if kind == "night":
		var salary := 0
		if me.career is Dictionary:
			salary = int(me.career.salary)
		return options[0] if _avg(rules, "college") > salary else options[1]
	return options[0]


static func _house(rules) -> Dictionary:
	if str(rules.pending.get("kind", "")) == "house_pick":
		return _keep(rules)
	var me: Dictionary = rules.players[rules.turn]
	if me.houses.size() > 0 and int(me.cash) < 60:
		return {"op": "house", "choice": "sell"}
	if int(me.cash) >= 160:
		return {"op": "house", "choice": "buy"}
	return {"op": "house", "choice": "skip"}


static func _wheel(rules, info: Dictionary) -> Dictionary:
	var picker := int(info.get("picker", rules.turn))
	if bool(rules.pending.get("extra_phase", false)):
		var first := int(rules.pending.picks.get(picker, 1))
		var number := first + 5
		if number > 10:
			number -= 10
		return {"op": "wheel", "number": number}
	var pick := (picker * 3 + 2) % 10 + 1
	return {"op": "wheel", "number": pick}


static func _avg(rules, deck_name: String) -> float:
	var cards: Array = rules.decks[deck_name].fresh
	if cards.is_empty():
		return 0.0
	var total := 0
	for card in cards:
		total += int(card.get("salary", 0))
	return float(total) / float(cards.size())


static func _steps(rules, start: String, goal: String) -> int:
	var cur := start
	var count := 0
	var seen := {}
	while cur != "" and cur != goal and count < 200:
		if seen.has(cur) or not rules.board.has(cur):
			return 200
		seen[cur] = true
		var links: Array = rules.board[cur].get("next", [])
		if links.is_empty():
			return 200
		cur = str(links[0])
		count += 1
	return count
