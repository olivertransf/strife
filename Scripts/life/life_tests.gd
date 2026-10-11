extends RefCounted
class_name LifeTests

const Rules = preload("res://Scripts/life/life_rules.gd")
const Policy = preload("res://Scripts/life/life_policy.gd")

static func run(spaces_root: Node) -> String:
	var cases := [
		"_unemployed_and_salary",
		"_half_speed",
		"_bee_keeper_spin",
		"_singer_voice",
		"_college_yeet",
		"_house_colors",
		"_wheel_pot",
		"_retirement_order",
	]
	for case_name in cases:
		var rules := Rules.new()
		var err := ""
		match case_name:
			"_unemployed_and_salary":
				err = _unemployed_and_salary(rules)
			"_half_speed":
				err = _half_speed(rules)
			"_bee_keeper_spin":
				err = _bee_keeper_spin(rules)
			"_singer_voice":
				err = _singer_voice(rules)
			"_college_yeet":
				err = _college_yeet(rules)
			"_house_colors":
				err = _house_colors(rules)
			"_wheel_pot":
				err = _wheel_pot(rules)
			"_retirement_order":
				err = _retirement_order(rules)
		if err != "":
			return err
	var graph_err := graph(spaces_root)
	if graph_err != "":
		return graph_err
	return ""


static func run_sim(games: int, seed: int) -> String:
	var results: Array = []
	for n in games:
		var rules := Rules.new()
		rules.setup(Rules.load_board(), Rules.load_decks(), 4, seed + n, true, PackedStringArray(["Alex", "Blair", "Casey", "Drew"]))
		var guard := 0
		while not rules.game_over and guard < 12000:
			guard += 1
			var before := rules.acts
			rules.act(Policy.choose(rules))
			if rules.fault != "":
				return "game %d %s" % [n, rules.fault]
			if rules.acts == before and not rules.game_over:
				return "game %d stalled at %s" % [n, rules.phase]
			if not rules.game_over:
				for p in rules.players:
					if int(p.cash) < 0:
						return "game %d negative cash" % n
		if not rules.game_over:
			var me: Dictionary = rules.players[rules.turn]
			return "game %d phase %s p%s %s cash %s loans %s car %s boys %s girls %s crowd %s/%s flat %s odd %s bike %s jet %s m10 %s host %s unemp %s" % [
				n, rules.phase, str(rules.turn), str(me.space), str(me.cash), str(me.loans),
				str(me.car_count), str(me.boys), str(me.girls), str(me.crowd_boys), str(me.crowd_girls),
				str(me.flat_tire_turns), str(me.odd_half), str(me.ebike), str(me.jet_turns), str(me.move10_turns),
				str(me.bacteria_host), str(me.unemployed),
			]
		results.append({"winner": rules.winners, "cash": _cash_row(rules)})
	var path := ProjectSettings.globalize_path("res://artifacts/sim.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not write sim.json"
	file.store_string(JSON.stringify({"seed": seed, "games": games, "ok": true, "results": results}, "\t"))
	return ""


static func graph(spaces_root: Node) -> String:
	var table = Rules.load_json("res://Data/board_spaces.json")
	if not (table is Dictionary):
		return "board table missing"
	Rules.apply_spaces(spaces_root, table)
	var by_name := {}
	for child in spaces_root.get_children():
		if child is Spaces:
			by_name[child.name] = child
	if by_name.size() != table.size():
		return "space count %d != %d" % [by_name.size(), table.size()]
	for name in table.keys():
		if not by_name.has(name):
			return "missing node %s" % name
		var node: Spaces = by_name[name]
		var expect: Array = table[name].get("next", [])
		if node.next_spaces.size() != expect.size():
			return "%s link count" % name
		for i in expect.size():
			var linked := node.get_node(node.next_spaces[i])
			if linked == null or linked.name != str(expect[i]):
				return "%s link %d" % [name, i]
		if node.stop_kind != str(table[name].get("stop", "")):
			return "%s stop kind" % name
		if node.next_spaces.size() > 1 and node.stop_kind == "":
			return "fork without stop %s" % name
	if by_name["Space0"].stop_kind != "start":
		return "start is not a fork stop"
	if by_name["Space36"].stop_kind != "family":
		return "family fork"
	if by_name["Space56"].stop_kind != "risky":
		return "risky fork"
	if by_name["Space94"].stop_kind != "retirement":
		return "retirement fork"
	if by_name["Space123"].stop_kind != "graduation":
		return "graduation missing"
	if by_name["Space99"].next_spaces.size() != 0 or by_name["Space121"].next_spaces.size() != 0:
		return "retirement is not a dead end"
	var seen := {}
	var stack: Array = ["Space0"]
	while not stack.is_empty():
		var name: String = stack.pop_back()
		if seen.has(name):
			continue
		seen[name] = true
		var node: Spaces = by_name[name]
		for path in node.next_spaces:
			var nxt := node.get_node(path)
			if nxt == null:
				return "broken link at %s" % name
			stack.append(nxt.name)
	if seen.size() != by_name.size():
		return "unreachable spaces"
	return ""


static func _unemployed_and_salary(rules: Rules) -> String:
	var paid := Rules.new()
	paid.setup(_line(["payday", "payday"]), _salary_deck(50, 2), 1, 1, false)
	_ready(paid)
	paid.act({"op": "spin", "value": 2})
	if paid.fault != "":
		return "salary %s" % paid.fault
	if int(paid.players[0].cash) != 300:
		return "salary cash %s" % str(paid.players[0].cash)
	rules.setup(_line(["payday", "payday"]), _salary_deck(50, 2), 1, 1, false)
	_ready(rules)
	rules.players[0].career = null
	rules.players[0].unemployed = true
	rules.act({"op": "spin", "value": 2})
	if int(rules.players[0].cash) != 240:
		return "unemployed cash %s" % str(rules.players[0].cash)
	return ""


static func _half_speed(rules: Rules) -> String:
	rules.setup(_line(["pet", "pet", "pet", "pet"]), _salary_deck(0, 2), 1, 2, false)
	_ready(rules)
	rules.players[0].car_count = 0
	rules.act({"op": "spin", "value": 7})
	if rules.fault != "":
		return "half %s" % rules.fault
	if rules.players[0].space != "S3":
		return "half landed on %s" % rules.players[0].space
	return ""


static func _bee_keeper_spin(rules: Rules) -> String:
	var bee := {
		"id": "bee_keeper", "deck": "career", "title": "Bee Keeper", "text": "Hive.",
		"salary": 0, "bonus": 3, "gift": 0, "special": "bee",
	}
	var decks := _salary_deck(0, 1)
	decks.career = [bee]
	rules.setup(_line(["pet", "pet", "pet"]), decks, 1, 3, false)
	rules.act({"op": "start", "college": false})
	if rules.phase != "spin":
		return "bee did not start, phase %s" % rules.phase
	rules.act({"op": "spin", "value": 3})
	if str(rules.players[0].purgatory) != "snake_return":
		return "bee purgatory %s" % str(rules.players[0].purgatory)
	if int(rules.players[0].cash) != 1200:
		return "bee cash %s" % str(rules.players[0].cash)
	rules.act({"op": "spin", "value": 1})
	if rules.fault != "":
		return "bee return %s" % rules.fault
	if int(rules.players[0].cash) != 250 or int(rules.players[0].loans) != 5:
		return "snake cash %s loans %s" % [str(rules.players[0].cash), str(rules.players[0].loans)]
	if rules.players[0].career != null:
		return "snake kept the job"
	return ""


static func _singer_voice(rules: Rules) -> String:
	var singer := {"id": "singer", "deck": "career", "title": "Singer", "text": "Voice.", "salary": 70, "bonus": 4, "gift": 20}
	var assassin := {"id": "assassin", "deck": "career", "title": "Assassin", "text": "Quiet.", "salary": 80, "bonus": 2, "gift": 0, "special": "assassin"}
	var filler := {"id": "filler", "deck": "career", "title": "Filler", "text": "Wait.", "salary": 1, "bonus": 8, "gift": 0}
	var decks := _salary_deck(0, 1)
	decks.career = [singer, filler.duplicate(true), assassin, filler.duplicate(true)]
	rules.setup(_line(_pets(12)), decks, 2, 4, false, PackedStringArray(["Ada", "Bea"]))
	rules.act({"op": "start", "college": false})
	rules.act({"op": "keep", "index": 0})
	rules.act({"op": "start", "college": false})
	rules.act({"op": "keep", "index": 0})
	rules.act({"op": "spin", "value": 2})
	if rules.fault != "":
		return "singer %s" % rules.fault
	if int(rules.players[0].assassin_hits) != 1 or not bool(rules.players[0].silent):
		return "first hit silent %s" % str(rules.players[0].silent)
	if rules.players[0].purgatory != null:
		return "singer died early"
	rules.act({"op": "spin", "value": 1})
	rules.act({"op": "spin", "value": 2})
	if int(rules.players[0].assassin_hits) != 2 or bool(rules.players[0].silent):
		return "voice did not return"
	if rules.players[0].purgatory != null:
		return "second hit killed the singer"
	return ""


static func _college_yeet(rules: Rules) -> String:
	rules.setup(Rules.load_board(), Rules.load_decks(), 1, 5, false)
	rules.act({"op": "start", "college": true})
	var moved: Array = rules.act({"op": "spin", "value": 2})
	if rules.fault != "":
		return "college %s" % rules.fault
	if rules.players[0].space != "Space82":
		return "college space %s" % rules.players[0].space
	if rules.phase != "choose_card":
		return "college phase %s" % rules.phase
	if int(rules.players[0].cash) != 0:
		return "college cash %s" % str(rules.players[0].cash)
	for ev in moved:
		if str(ev.get("kind", "")) == "payday":
			return "college collected a payday"
	return ""


static func _house_colors(_rules: Rules) -> String:
	var house := {"id": "h", "title": "Cabin", "red": 60, "black": 180}
	if Rules.sale_price(house, 3) != 60:
		return "red sale %s" % str(Rules.sale_price(house, 3))
	if Rules.sale_price(house, 8) != 180:
		return "black sale %s" % str(Rules.sale_price(house, 8))
	return ""


static func _wheel_pot(rules: Rules) -> String:
	rules.setup(_line(["wheel"]), _salary_deck(0, 4), 2, 6, false, PackedStringArray(["Ada", "Bea"]))
	_ready(rules)
	rules.act({"op": "spin", "value": 1})
	if rules.phase != "wheel_pick":
		return "wheel phase %s %s" % [rules.phase, rules.fault]
	rules.act({"op": "wheel", "number": 4})
	rules.act({"op": "wheel", "number": 4, "spin": 4})
	if rules.fault != "":
		return "wheel %s" % rules.fault
	if rules.pot != 200:
		return "pot %s" % str(rules.pot)
	for p in rules.players:
		if int(p.cash) != 300:
			return "wheel cash %s" % str(p.cash)
	return ""


static func _retirement_order(rules: Rules) -> String:
	var board := {
		"Space0": {"type": "start", "stop": "start", "next": ["S1", "Z"], "babies": 0},
		"S1": {"type": "end", "stop": "", "next": [], "babies": 0},
		"Z": {"type": "pet", "stop": "", "next": ["S1"], "babies": 0},
	}
	rules.setup(board, _salary_deck(0, 8), 4, 7, false, PackedStringArray(["A", "B", "C", "D"]))
	for _i in 4:
		rules.act({"op": "start", "college": false})
		rules.act({"op": "keep", "index": 0})
	for _j in 4:
		rules.act({"op": "spin", "value": 1})
	if rules.fault != "":
		return "retire %s" % rules.fault
	if rules.retire_bonuses != [400, 300, 200, 100]:
		return "order %s" % str(rules.retire_bonuses)
	if not rules.game_over:
		return "retirement did not finish"
	return ""


static func _ready(rules: Rules) -> void:
	var count := rules.players.size()
	for _i in count:
		rules.act({"op": "start", "college": false})
		if rules.phase == "choose_card":
			rules.act({"op": "keep", "index": 0})


static func _line(types: Array) -> Dictionary:
	var board := {
		"Space0": {"type": "start", "stop": "start", "next": ["S1", "Z"], "babies": 0},
		"Z": {"type": "pet", "stop": "", "next": ["S1"], "babies": 0},
	}
	for i in types.size():
		var name := "S%d" % (i + 1)
		var nxt := "S%d" % (i + 2) if i + 1 < types.size() else ""
		var nexts: Array = []
		if nxt != "":
			nexts.append(nxt)
		board[name] = {"type": types[i], "stop": "", "next": nexts, "babies": 0}
	return board


static func _pets(count: int) -> Array:
	var types: Array = []
	for _i in count:
		types.append("pet")
	return types


static func _salary_deck(salary: int, copies: int) -> Dictionary:
	var careers: Array = []
	for i in copies:
		careers.append({
			"id": "job%d" % i,
			"deck": "career",
			"title": "Clerk" if i % 2 == 1 else "Cook",
			"text": "Work.",
			"salary": salary,
			"bonus": 0,
			"gift": 0,
		})
	return {
		"career": careers,
		"college": [
			{"id": "g", "deck": "college", "title": "Pilot", "text": "Wings.", "salary": 100, "bonus": 1, "gift": 0},
			{"id": "g2", "deck": "college", "title": "Vet", "text": "Paws.", "salary": 90, "bonus": 2, "gift": 0},
		],
		"action": [
			{"id": "left_hand", "deck": "action", "title": "Left hand", "text": "Table only.", "keep": false},
		],
		"house": [],
	}


static func _cash_row(rules: Rules) -> Array:
	var row: Array = []
	for p in rules.players:
		row.append(int(p.cash))
	return row
