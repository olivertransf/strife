extends RefCounted
class_name LifeTests

const Rules = preload("res://Scripts/life/life_rules.gd")
const Policy = preload("res://Scripts/life/life_policy.gd")

static func run(spaces_root: Node) -> String:
	var cases := [
		"_payday_pass_and_land",
		"_stop_cuts_move",
		"_college_and_career",
		"_loans_and_repay",
		"_wheel_prize",
		"_baby_and_card_score",
		"_retirement_order",
		"_house_sale_colors",
	]
	for case_name in cases:
		var rules := Rules.new()
		var err := ""
		match case_name:
			"_payday_pass_and_land":
				err = _payday_pass_and_land(rules)
			"_stop_cuts_move":
				err = _stop_cuts_move(rules)
			"_college_and_career":
				err = _college_and_career(rules)
			"_loans_and_repay":
				err = _loans_and_repay(rules)
			"_wheel_prize":
				err = _wheel_prize(rules)
			"_baby_and_card_score":
				err = _baby_and_card_score(rules)
			"_retirement_order":
				err = _retirement_order(rules)
			"_house_sale_colors":
				err = _house_sale_colors(rules)
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
		var seen := {}
		while not rules.game_over and guard < 900:
			guard += 1
			var me: Dictionary = rules.players[rules.turn]
			var key := "%s|%s|%s|%s|%s|%s|%s" % [
				rules.phase,
				rules.turn,
				me.space,
				me.cash,
				rules.pending.get("kind", ""),
				rules.pending.get("cursor", ""),
				rules.pending.get("extra_phase", false),
			]
			seen[key] = int(seen.get(key, 0)) + 1
			if int(seen[key]) > 6:
				return "stalled game %d at %s" % [n, key]
			rules.act(Policy.choose(rules))
			if rules.fault != "":
				return "game %d %s" % [n, rules.fault]
			if not rules.game_over:
				for p in rules.players:
					if int(p.cash) < 0:
						return "game %d negative cash" % n
		if not rules.game_over:
			return "game %d did not finish" % n
		if rules.retire_bonuses != [400, 300, 200, 100]:
			return "game %d retirement order %s" % [n, str(rules.retire_bonuses)]
		for p in rules.players:
			if not bool(p.retired):
				return "game %d %s never retired" % [n, p.name]
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


static func _payday_pass_and_land(rules: Rules) -> String:
	var board := _line(["payday", "payday"])
	rules.setup(board, _salary_deck(50), 1, 1, false)
	rules.act({"op": "start", "college": false})
	rules.act({"op": "keep", "index": 0})
	rules.act({"op": "spin", "value": 2})
	if rules.fault != "":
		return "payday %s" % rules.fault
	if int(rules.players[0].cash) != 400:
		return "pass then land payday cash %s" % str(rules.players[0].cash)
	if rules.players[0].space != "S2":
		return "payday landed on %s" % rules.players[0].space
	var land := Rules.new()
	land.setup(board, _salary_deck(50), 1, 1, false)
	land.act({"op": "start", "college": false})
	land.act({"op": "keep", "index": 0})
	land.act({"op": "spin", "value": 1})
	if int(land.players[0].cash) != 350:
		return "land payday cash %s" % str(land.players[0].cash)
	return ""


static func _stop_cuts_move(rules: Rules) -> String:
	var board := _line(["stop", "payday"])
	board["S1"]["stop"] = "married"
	rules.setup(board, _salary_deck(0), 1, 2, false)
	rules.act({"op": "start", "college": false})
	rules.act({"op": "keep", "index": 0})
	rules.act({"op": "spin", "value": 5})
	if rules.players[0].space != "S1":
		return "stop did not halt on %s" % rules.players[0].space
	if rules.phase != "spin":
		return "stop should spin again"
	var gift := int(rules.players[0].cash) - 200
	if gift != 50 and gift != 100:
		return "wedding gift %s" % gift
	return ""


static func _college_and_career(rules: Rules) -> String:
	var board := {
		"Space0": {"type": "start", "stop": "start", "next": ["Job", "Grad"], "babies": 0},
		"Job": {"type": "action", "stop": "", "next": ["Grad"], "babies": 0},
		"Grad": {"type": "stop", "stop": "graduation", "next": ["Tail"], "babies": 0},
		"Tail": {"type": "action", "stop": "", "next": [], "babies": 0},
	}
	var decks := _salary_deck(40)
	decks.college = [{"id": "g", "deck": "college", "title": "Pilot", "text": "Wings.", "salary": 130}, {"id": "g2", "deck": "college", "title": "Vet", "text": "Paws.", "salary": 90}]
	rules.setup(board, decks, 1, 3, false)
	rules.act({"op": "start", "college": true})
	if int(rules.players[0].cash) != 100:
		return "tuition cash %s" % str(rules.players[0].cash)
	if rules.players[0].career != null:
		return "college started with a job"
	rules.act({"op": "spin", "value": 1})
	if rules.phase != "choose_card":
		return "graduation did not deal, phase %s fault %s" % [rules.phase, rules.fault]
	if rules.pending.cards.size() != 2:
		return "graduation draw"
	rules.act({"op": "keep", "index": 0})
	if rules.players[0].career.title != "Pilot":
		return "kept college card"
	var career := Rules.new()
	career.setup(board, decks, 1, 3, false)
	career.act({"op": "start", "college": false})
	if career.phase != "choose_card" or career.pending.cards.size() != 2:
		return "career did not draw two"
	career.act({"op": "keep", "index": 1})
	if career.players[0].career.title != "Clerk":
		return "kept the wrong career"
	return ""


static func _loans_and_repay(rules: Rules) -> String:
	var board := _line(["action", "action"])
	var decks := _salary_deck(0)
	decks.action = [
		{"id": "pay", "deck": "action", "title": "Bill", "text": "Ouch.", "effect": {"op": "pay", "amount": 250}},
		{"id": "found", "deck": "action", "title": "Found", "text": "Nice.", "effect": {"op": "collect", "amount": 200}},
	]
	rules.setup(board, decks, 1, 4, false)
	rules.act({"op": "start", "college": false})
	rules.act({"op": "keep", "index": 0})
	rules.act({"op": "spin", "value": 1})
	if int(rules.players[0].loans) != 1 or int(rules.players[0].cash) != 0:
		return "loan take cash %s loans %s" % [str(rules.players[0].cash), str(rules.players[0].loans)]
	if int(rules.players[0].cash) < 0:
		return "negative without covering loan"
	rules.act({"op": "spin", "value": 1})
	if int(rules.players[0].cash) != 200:
		return "collect after loan %s" % str(rules.players[0].cash)
	rules.act({"op": "repay"})
	if rules.fault != "":
		return "repay %s" % rules.fault
	if int(rules.players[0].loans) != 0 or int(rules.players[0].cash) != 140:
		return "repay result cash %s loans %s" % [str(rules.players[0].cash), str(rules.players[0].loans)]
	return ""


static func _wheel_prize(rules: Rules) -> String:
	var board := _line(["wheel"])
	rules.setup(board, _salary_deck(0), 2, 5, false, PackedStringArray(["Alex", "Blair"]))
	rules.act({"op": "start", "college": false})
	rules.act({"op": "keep", "index": 0})
	rules.act({"op": "spin", "value": 1})
	if rules.phase != "wheel_pick":
		return "wheel phase %s %s" % [rules.phase, rules.fault]
	rules.act({"op": "wheel", "number": 4})
	rules.act({"op": "wheel", "number": 4})
	rules.act({"op": "wheel", "number": 4})
	if rules.fault != "":
		return "wheel %s" % rules.fault
	for p in rules.players:
		if int(p.cash) != 400:
			return "wheel cash %s" % str(p.cash)
	return ""


static func _baby_and_card_score(rules: Rules) -> String:
	var board := {
		"Space0": {"type": "start", "stop": "start", "next": ["A", "Z"], "babies": 0},
		"A": {"type": "action", "stop": "", "next": ["R"], "babies": 0},
		"R": {"type": "stop", "stop": "retirement", "next": ["P", "Q"], "babies": 0},
		"P": {"type": "end", "stop": "", "next": [], "babies": 0, "label": "Countryside"},
		"Q": {"type": "end", "stop": "", "next": [], "babies": 0, "label": "Mansion"},
		"Z": {"type": "action", "stop": "", "next": ["A"], "babies": 0},
	}
	var decks := _salary_deck(0)
	decks.action = [{"id": "baby", "deck": "action", "title": "Twins", "text": "Two.", "effect": {"op": "babies", "count": 2}}]
	rules.setup(board, decks, 1, 6, false)
	rules.act({"op": "start", "college": false})
	rules.act({"op": "keep", "index": 0})
	rules.act({"op": "spin", "value": 1})
	rules.act({"op": "spin", "value": 1})
	rules.act({"op": "fork", "index": 0})
	if not rules.game_over:
		return "score game did not end %s" % rules.fault
	if int(rules.players[0].babies) != 2:
		return "babies %s" % str(rules.players[0].babies)
	if int(rules.players[0].cash) != 800:
		return "end value cash %s" % str(rules.players[0].cash)
	return ""


static func _retirement_order(rules: Rules) -> String:
	var board := {
		"Space0": {"type": "start", "stop": "start", "next": ["R", "Z"], "babies": 0},
		"R": {"type": "stop", "stop": "retirement", "next": ["P", "Q"], "babies": 0},
		"P": {"type": "end", "stop": "", "next": [], "babies": 0},
		"Q": {"type": "end", "stop": "", "next": [], "babies": 0},
		"Z": {"type": "action", "stop": "", "next": ["R"], "babies": 0},
	}
	rules.setup(board, _salary_deck(0), 2, 7, false, PackedStringArray(["Alex", "Blair"]))
	for _i in 2:
		rules.act({"op": "start", "college": false})
		rules.act({"op": "keep", "index": 0})
		rules.act({"op": "spin", "value": 1})
		rules.act({"op": "fork", "index": 0})
	if rules.retire_bonuses != [400, 300]:
		return "order %s" % str(rules.retire_bonuses)
	if not rules.game_over:
		return "retirement did not finish"
	return ""


static func _house_sale_colors(rules: Rules) -> String:
	var board := _line(["house", "house"])
	var decks := _salary_deck(0)
	var house := {"id": "h", "deck": "house", "title": "Cabin", "text": "Dock.", "price": 100, "red": 60, "black": 180}
	decks.house = [house, house.duplicate(true), house.duplicate(true)]
	rules.setup(board, decks, 1, 8, false)
	rules.act({"op": "start", "college": false})
	rules.act({"op": "keep", "index": 0})
	rules.act({"op": "spin", "value": 1})
	rules.act({"op": "house", "choice": "buy"})
	rules.act({"op": "keep", "index": 0})
	if int(rules.players[0].cash) != 100:
		return "buy cash %s %s" % [str(rules.players[0].cash), rules.fault]
	rules.act({"op": "spin", "value": 1})
	rules.act({"op": "house", "choice": "sell", "spin": 2})
	if int(rules.players[0].cash) != 160:
		return "red sale %s" % str(rules.players[0].cash)
	var black := Rules.new()
	black.setup(board, decks, 1, 8, false)
	black.act({"op": "start", "college": false})
	black.act({"op": "keep", "index": 0})
	black.act({"op": "spin", "value": 1})
	black.act({"op": "house", "choice": "buy"})
	black.act({"op": "keep", "index": 0})
	black.act({"op": "spin", "value": 1})
	black.act({"op": "house", "choice": "sell", "spin": 8})
	if int(black.players[0].cash) != 280:
		return "black sale %s %s" % [str(black.players[0].cash), black.fault]
	return ""


static func _line(types: Array) -> Dictionary:
	var board := {
		"Space0": {"type": "start", "stop": "start", "next": ["S1", "Z"], "babies": 0},
		"Z": {"type": "action", "stop": "", "next": ["S1"], "babies": 0},
	}
	for i in types.size():
		var name := "S%d" % (i + 1)
		var nxt := "S%d" % (i + 2) if i + 1 < types.size() else ""
		var nexts: Array = []
		if nxt != "":
			nexts.append(nxt)
		board[name] = {"type": types[i], "stop": "", "next": nexts, "babies": 0}
	return board


static func _salary_deck(salary: int) -> Dictionary:
	return {
		"career": [
			{"id": "a", "deck": "career", "title": "Cook", "text": "Rush.", "salary": salary},
			{"id": "b", "deck": "career", "title": "Clerk", "text": "Files.", "salary": salary},
		],
		"college": [
			{"id": "g", "deck": "college", "title": "Pilot", "text": "Wings.", "salary": 100},
			{"id": "g2", "deck": "college", "title": "Vet", "text": "Paws.", "salary": 90},
		],
		"action": [
			{"id": "act", "deck": "action", "title": "Quiet", "text": "Nothing much.", "effect": {"op": "collect", "amount": 0}},
		],
		"house": [],
		"pet": [],
	}


static func _cash_row(rules: Rules) -> Array:
	var row: Array = []
	for p in rules.players:
		row.append(int(p.cash))
	return row
