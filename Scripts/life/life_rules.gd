extends RefCounted
class_name LifeRules

const START_CASH := 200
const TUITION := 100
const PAYDAY_BONUS := 100
const LOAN_TAKE := 50
const LOAN_REPAY := 60
const WHEEL_PRIZE := 200
const BABY_VALUE := 50
const CARD_VALUE := 100
const NIGHT_COST := 100
const RETIRE_BONUS := [400, 300, 200, 100]

const TYPE_ENUM := {
	"payday": Spaces.SpaceType.PAYDAY,
	"action": Spaces.SpaceType.ACTION,
	"house": Spaces.SpaceType.HOUSE,
	"start": Spaces.SpaceType.START,
	"boy": Spaces.SpaceType.BOY,
	"girl": Spaces.SpaceType.GIRL,
	"wheel": Spaces.SpaceType.SPIN2WIN,
	"twins": Spaces.SpaceType.TWINS,
	"stop": Spaces.SpaceType.STOP,
	"end": Spaces.SpaceType.END,
	"park": Spaces.SpaceType.PARK,
	"pet": Spaces.SpaceType.PET,
}

var board: Dictionary = {}
var decks: Dictionary = {}
var players: Array = []
var turn := 0
var phase := "choose_start"
var pending: Dictionary = {}
var rng := RandomNumberGenerator.new()
var game_over := false
var fault := ""
var retire_bonuses: Array = []
var winners: Array = []
var _events: Array = []


static func load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


static func load_board() -> Dictionary:
	var raw = load_json("res://Data/board_spaces.json")
	return raw if raw is Dictionary else {}


static func load_decks() -> Dictionary:
	return {
		"career": _clean_cards(load_json("res://Data/careers.json"), "career"),
		"college": _clean_cards(load_json("res://Data/college_careers.json"), "college"),
		"action": _clean_cards(load_json("res://Data/actions.json"), "action"),
		"house": _clean_cards(load_json("res://Data/houses.json"), "house"),
		"pet": _clean_cards(load_json("res://Data/pets.json"), "pet"),
	}


static func _clean_cards(raw: Variant, deck_name: String) -> Array:
	var cards: Array = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				var card: Dictionary = item.duplicate(true)
				card["deck"] = deck_name
				if card.has("salary"):
					card["salary"] = int(card["salary"])
				if card.has("price"):
					card["price"] = int(card["price"])
				if card.has("red"):
					card["red"] = int(card["red"])
				if card.has("black"):
					card["black"] = int(card["black"])
				cards.append(card)
	return cards


static func apply_spaces(root: Node, table: Dictionary) -> void:
	for child in root.get_children():
		if not (child is Spaces):
			continue
		var row = table.get(child.name, {})
		if row.is_empty():
			continue
		var kind := str(row.get("type", "action"))
		child.space_type = TYPE_ENUM.get(kind, Spaces.SpaceType.ACTION)
		child.stop_kind = str(row.get("stop", ""))
		child.baby_count = int(row.get("babies", 0))


func setup(board_in: Dictionary, decks_in: Dictionary, count: int, seed: int, shuffle_decks := true, names: PackedStringArray = PackedStringArray()) -> void:
	board = board_in
	rng.seed = seed
	decks = {}
	for deck_name in decks_in.keys():
		var fresh: Array = []
		for card in decks_in[deck_name]:
			fresh.append((card as Dictionary).duplicate(true))
		var draw := fresh.duplicate(true)
		if shuffle_decks:
			_shuffle(draw)
		decks[deck_name] = {"fresh": fresh, "draw": draw}
	players = []
	var total := clampi(count, 1, 4)
	for i in total:
		var name := "Player %d" % (i + 1)
		if i < names.size():
			name = names[i]
		players.append({
			"i": i,
			"name": name,
			"cash": START_CASH,
			"loans": 0,
			"career": null,
			"spouse": false,
			"babies": 0,
			"actions": [],
			"pets": [],
			"houses": [],
			"space": "Space0",
			"at_gate": false,
			"forks": {},
			"retired": false,
			"retire_bonus": 0,
			"college": false,
			"score_parts": {},
		})
	turn = 0
	phase = "choose_start"
	pending = {}
	game_over = false
	fault = ""
	retire_bonuses = []
	winners = []


func act(action: Dictionary) -> Array:
	_events = []
	if game_over:
		_fault("acted after the game ended")
		return []
	if fault != "":
		return []
	match str(action.get("op", "")):
		"start":
			_do_start(bool(action.get("college", false)))
		"keep":
			_do_keep(int(action.get("index", -1)))
		"spin":
			_do_spin(action)
		"fork":
			_do_fork(int(action.get("index", -1)))
		"house":
			_do_house(action)
		"wheel":
			_do_wheel(int(action.get("number", 0)))
		"repay":
			_do_repay()
		_:
			_fault("unknown action")
	return _events.duplicate(true)


func prompt() -> Dictionary:
	var me: Dictionary = players[turn]
	match phase:
		"choose_start":
			return {
				"phase": phase,
				"title": "Where do you start?",
				"detail": "College costs 100K now and pays more later. Career pays on the next payday.",
				"options": [
					{"op": "start", "college": false, "label": "Career"},
					{"op": "start", "college": true, "label": "College"},
				],
			}
		"choose_card":
			return _card_prompt()
		"spin":
			var options: Array = [{"op": "spin", "label": "Spin"}]
			if int(me.loans) > 0 and int(me.cash) >= LOAN_REPAY:
				options.append({"op": "repay", "label": "Repay a loan"})
			var detail := "Spin 1 to 10 and move."
			if me.career == null:
				detail = "No salary yet. Spin and move."
			return {"phase": phase, "title": "%s spins" % me.name, "detail": detail, "options": options}
		"choose_fork":
			return {
				"phase": phase,
				"title": str(pending.get("title", "Choose")),
				"detail": str(pending.get("detail", "")),
				"options": pending.get("options", []),
			}
		"choose_house":
			return _house_prompt(me)
		"wheel_pick":
			return _wheel_prompt()
		"game_over":
			return {"phase": phase, "title": "Life ledger", "detail": _winner_line(), "options": []}
		_:
			return {"phase": phase, "title": phase, "detail": "", "options": []}


func snapshot() -> Dictionary:
	var rows: Array = []
	for p in players:
		rows.append({
			"name": p.name,
			"cash": p.cash,
			"loans": p.loans,
			"babies": p.babies,
			"retired": p.retired,
			"retire_bonus": p.retire_bonus,
			"space": p.space,
			"job": "" if p.career == null else p.career.title,
			"salary": 0 if p.career == null else int(p.career.salary),
			"actions": p.actions.size(),
			"pets": p.pets.size(),
			"houses": p.houses.size(),
			"spouse": p.spouse,
			"score_parts": p.score_parts,
		})
	return {
		"phase": phase,
		"turn": turn,
		"game_over": game_over,
		"fault": fault,
		"winners": winners.duplicate(),
		"retire_bonuses": retire_bonuses.duplicate(),
		"players": rows,
	}


func _card_prompt() -> Dictionary:
	var kind := str(pending.get("kind", ""))
	var options: Array = []
	if kind == "night_keep":
		var offered: Dictionary = pending.cards[0]
		var current: Dictionary = pending.current if pending.current is Dictionary else {}
		options.append({
			"op": "keep",
			"index": 0,
			"label": "%s  %dK" % [offered.title, int(offered.salary)],
		})
		var current_title := "your job" if current.is_empty() else str(current.title)
		options.append({"op": "keep", "index": 1, "label": "Keep %s" % current_title})
		return {
			"phase": phase,
			"title": "Night school",
			"detail": offered.text,
			"options": options,
		}
	var title := "Choose a career"
	if kind == "graduation":
		title = "Graduation"
	elif kind == "house_pick":
		title = "Choose a house"
	for i in pending.cards.size():
		var card: Dictionary = pending.cards[i]
		var label := str(card.title)
		if card.has("salary"):
			label = "%s  %dK" % [card.title, int(card.salary)]
		elif card.has("price"):
			label = "%s  %dK" % [card.title, int(card.price)]
		options.append({"op": "keep", "index": i, "label": label, "text": card.get("text", "")})
	return {"phase": phase, "title": title, "detail": "Keep one. The other goes back.", "options": options}


func _house_prompt(me: Dictionary) -> Dictionary:
	if str(pending.get("step", "")) == "pick":
		return _card_prompt()
	var options: Array = [{"op": "house", "choice": "skip", "label": "Do nothing"}]
	if me.houses.size() > 0:
		options.append({"op": "house", "choice": "sell", "label": "Sell a house"})
	options.append({"op": "house", "choice": "buy", "label": "Buy a house"})
	return {
		"phase": phase,
		"title": "House for sale",
		"detail": "Look at two, buy one, sell one you own, or walk on.",
		"options": options,
	}


func _wheel_prompt() -> Dictionary:
	var picker := _wheel_picker()
	var options: Array = []
	for n in range(1, 11):
		options.append({"op": "wheel", "number": n, "label": str(n)})
	var title := "Pick a number"
	var detail := "%s chooses." % players[picker].name
	if bool(pending.get("extra_phase", false)):
		title = "Second number"
		detail = "You landed here, so you get another number."
	return {"phase": phase, "title": title, "detail": detail, "options": options, "picker": picker}


func _do_start(college: bool) -> void:
	if phase != "choose_start":
		_fault("not choosing a start")
		return
	var me: Dictionary = players[turn]
	me.at_gate = true
	me.space = "Space0"
	if college:
		_pay(me, TUITION, "tuition")
		if fault != "":
			return
		me.college = true
		me.forks["Space0"] = _branch("Space0", 1)
		phase = "spin"
		_events.append({"kind": "path", "player": turn, "college": true})
	else:
		var first := _draw("career")
		var second := _draw("career")
		pending = {"kind": "career", "cards": [first, second]}
		phase = "choose_card"
		_events.append({"kind": "path", "player": turn, "college": false})
		_events.append({"kind": "deal", "player": turn, "cards": _card_briefs(pending.cards)})


func _do_keep(index: int) -> void:
	if phase != "choose_card":
		_fault("not choosing a card")
		return
	var kind := str(pending.get("kind", ""))
	var me: Dictionary = players[turn]
	if kind == "night_keep":
		var offered: Dictionary = pending.cards[0]
		if index == 0:
			if me.career is Dictionary:
				_return_card(me.career)
			me.career = offered
			_events.append({"kind": "career", "player": turn, "title": offered.title, "salary": offered.salary, "text": offered.text})
		else:
			_return_card(offered)
		phase = "spin"
		pending = {}
		_events.append({"kind": "spin_again", "player": turn})
		return
	if index < 0 or index >= pending.cards.size():
		_fault("bad card index")
		return
	var kept: Dictionary = pending.cards[index]
	for i in pending.cards.size():
		if i != index:
			_return_card(pending.cards[i])
	if kind == "house_pick":
		_pay(me, int(kept.price), "house")
		if fault != "":
			return
		me.houses.append(kept)
		_events.append({"kind": "house", "player": turn, "title": kept.title, "text": kept.text, "price": kept.price, "bought": true})
		pending = {}
		_end_turn()
		return
	me.career = kept
	if kind == "career":
		me.forks["Space0"] = _branch("Space0", 0)
		me.at_gate = true
		me.space = "Space0"
	_events.append({"kind": "career", "player": turn, "title": kept.title, "salary": kept.salary, "text": kept.text})
	phase = "spin"
	pending = {}
	if kind == "graduation":
		_events.append({"kind": "spin_again", "player": turn})


func _do_spin(action: Dictionary) -> void:
	if phase != "spin":
		_fault("not time to spin")
		return
	var value := int(action.get("value", 0))
	if value < 1 or value > 10:
		value = rng.randi_range(1, 10)
	_events.append({"kind": "spin", "player": turn, "value": value, "red": value <= 5})
	_move(players[turn], value)


func _do_fork(index: int) -> void:
	if phase != "choose_fork":
		_fault("not choosing a path")
		return
	var options: Array = pending.get("options", [])
	if index < 0 or index >= options.size():
		_fault("bad fork")
		return
	var me: Dictionary = players[turn]
	var kind := str(pending.get("kind", ""))
	if kind == "night":
		if index == 0:
			_pay(me, NIGHT_COST, "night school")
			if fault != "":
				return
			var card := _draw("college")
			var current = me.career
			pending = {"kind": "night_keep", "cards": [card], "current": current}
			phase = "choose_card"
			_events.append({"kind": "deal", "player": turn, "cards": _card_briefs(pending.cards)})
		else:
			pending = {}
			phase = "spin"
			_events.append({"kind": "spin_again", "player": turn})
		return
	var dest := str(options[index].get("dest", ""))
	if dest == "":
		_fault("missing path")
		return
	if kind == "retirement":
		_park(me, dest)
		pending = {}
		_end_turn()
		return
	me.forks[str(pending.get("space", ""))] = dest
	_events.append({"kind": "fork", "player": turn, "dest": dest, "label": options[index].get("label", "")})
	pending = {}
	phase = "spin"
	_events.append({"kind": "spin_again", "player": turn})


func _do_house(action: Dictionary) -> void:
	if phase != "choose_house":
		_fault("not a house")
		return
	var me: Dictionary = players[turn]
	var choice := str(action.get("choice", "skip"))
	if choice == "buy":
		var first := _draw("house")
		var second := _draw("house")
		pending = {"kind": "house_pick", "step": "pick", "cards": [first, second]}
		phase = "choose_card"
		_events.append({"kind": "deal", "player": turn, "cards": _card_briefs(pending.cards)})
		return
	if choice == "sell":
		if me.houses.is_empty():
			choice = "skip"
		else:
			var house: Dictionary = me.houses.pop_back()
			var spin := int(action.get("spin", 0))
			if spin < 1 or spin > 10:
				spin = rng.randi_range(1, 10)
			var red := spin <= 5
			var gain := int(house.red) if red else int(house.black)
			_return_card(house)
			_gain(me, gain, "sold a house")
			_events.append({
				"kind": "house",
				"player": turn,
				"title": house.title,
				"text": house.text,
				"bought": false,
				"spin": spin,
				"red": red,
				"gain": gain,
			})
			pending = {}
			_end_turn()
			return
	pending = {}
	_events.append({"kind": "pass", "player": turn, "reason": "house"})
	_end_turn()


func _do_wheel(number: int) -> void:
	if phase != "wheel_pick":
		_fault("not the wheel")
		return
	if number < 1 or number > 10:
		_fault("bad wheel number")
		return
	var picker := _wheel_picker()
	if bool(pending.get("extra_phase", false)):
		pending.extra = number
		_events.append({"kind": "wheel_pick", "player": picker, "number": number, "extra": true})
		_resolve_wheel()
		return
	pending.picks[picker] = number
	_events.append({"kind": "wheel_pick", "player": picker, "number": number, "extra": false})
	pending.cursor = int(pending.cursor) + 1
	if int(pending.cursor) >= pending.order.size():
		pending.extra_phase = true


func _do_repay() -> void:
	if phase != "spin":
		_fault("cannot repay now")
		return
	var me: Dictionary = players[turn]
	if int(me.loans) <= 0 or int(me.cash) < LOAN_REPAY:
		_fault("cannot repay")
		return
	me.cash -= LOAN_REPAY
	me.loans -= 1
	_events.append({"kind": "repay", "player": turn, "cash": me.cash, "loans": me.loans})


func _move(me: Dictionary, steps: int) -> void:
	var left := steps
	while left > 0:
		var nxt := _peek_next(me)
		if nxt == "":
			_open_branch(me, left)
			return
		if nxt == "<end>":
			_fault("moved off the board")
			return
		var stop := str(board[nxt].get("stop", ""))
		var landing := left == 1 or (stop != "" and stop != "start")
		_enter(me, nxt, landing)
		if fault != "":
			return
		left -= 1
		if stop != "" and stop != "start":
			return
		if phase != "spin":
			return
	if phase == "spin" and not me.retired:
		_end_turn()


func _enter(me: Dictionary, space_id: String, landing: bool) -> void:
	if not board.has(space_id):
		_fault("missing space %s" % space_id)
		return
	me.at_gate = false
	me.space = space_id
	var space: Dictionary = board[space_id]
	_events.append({"kind": "enter", "player": me.i, "space": space_id, "landing": landing})
	var stop := str(space.get("stop", ""))
	if stop != "" and stop != "start":
		_resolve_stop(me, space)
		return
	if not landing:
		if str(space.get("type", "")) == "payday":
			_payday(me, false)
		return
	match str(space.get("type", "")):
		"payday":
			_payday(me, true)
		"action":
			_draw_keep(me, "action")
		"pet":
			_draw_keep(me, "pet")
		"house":
			pending = {"step": "mode"}
			phase = "choose_house"
		"boy", "girl", "twins":
			_add_babies(me, _baby_count(space))
		"wheel":
			_open_wheel(me)
		"end":
			_park(me, space_id)
		_:
			pass


func _resolve_stop(me: Dictionary, space: Dictionary) -> void:
	match str(space.get("stop", "")):
		"graduation":
			pending = {"kind": "graduation", "cards": [_draw("college"), _draw("college")]}
			phase = "choose_card"
			_events.append({"kind": "deal", "player": me.i, "cards": _card_briefs(pending.cards)})
		"married":
			me.spouse = true
			var spin := rng.randi_range(1, 10)
			var gift := 50 if spin <= 5 else 100
			_gain(me, gift, "wedding gifts")
			_events.append({"kind": "married", "player": me.i, "spin": spin, "red": spin <= 5, "gift": gift})
			phase = "spin"
			_events.append({"kind": "spin_again", "player": me.i})
		"babies":
			var spin := rng.randi_range(1, 10)
			var count := 0
			if spin >= 9:
				count = 3
			elif spin >= 7:
				count = 2
			elif spin >= 4:
				count = 1
			_add_babies(me, count)
			_events.append({"kind": "baby_spin", "player": me.i, "spin": spin, "count": count})
			phase = "spin"
			_events.append({"kind": "spin_again", "player": me.i})
		"night":
			phase = "choose_fork"
			pending = {
				"kind": "night",
				"title": "Night school",
				"detail": "Pay 100K to draw a college career, or keep the job you have.",
				"options": [
					{"op": "fork", "index": 0, "label": "Night school"},
					{"op": "fork", "index": 1, "label": "Keep your job"},
				],
			}
		"family", "risky", "retirement":
			_open_stop_fork(me, space)
		_:
			phase = "spin"
			_events.append({"kind": "spin_again", "player": me.i})


func _open_stop_fork(me: Dictionary, space: Dictionary) -> void:
	var kind := str(space.get("stop", ""))
	var labels: Array = pending_labels(kind)
	var nexts: Array = space.get("next", [])
	var options: Array = []
	for i in nexts.size():
		var label := "Path %d" % (i + 1)
		if i < labels.size():
			label = str(labels[i])
		options.append({"op": "fork", "index": i, "label": label, "dest": str(nexts[i])})
	phase = "choose_fork"
	pending = {
		"kind": kind,
		"space": me.space,
		"title": labels[0] if kind == "retirement" else str(space.get("label", kind)),
		"detail": _fork_detail(kind),
		"options": options,
	}
	if kind == "retirement":
		pending.title = "Retirement"


func pending_labels(kind: String) -> Array:
	match kind:
		"family":
			return ["Life path", "Family path"]
		"risky":
			return ["Risky road", "Safe route"]
		"retirement":
			return ["Countryside Acres", "Millionaire Mansion"]
		_:
			return []


func _fork_detail(kind: String) -> String:
	match kind:
		"family":
			return "Family path is where the babies are. Life path keeps moving."
		"risky":
			return "Risky road pays and costs more. Safe route is quieter."
		"retirement":
			return "Park the car. First to retire collects 400K, then 300K, 200K, and 100K."
		_:
			return ""


func _open_branch(me: Dictionary, _left: int) -> void:
	var space: Dictionary = board[me.space]
	_open_stop_fork(me, space)


func _open_wheel(me: Dictionary) -> void:
	var order: Array = []
	for p in players:
		order.append(int(p.i))
	phase = "wheel_pick"
	pending = {
		"kind": "wheel",
		"lander": me.i,
		"order": order,
		"cursor": 0,
		"picks": {},
		"extra_phase": false,
		"extra": -1,
	}


func _resolve_wheel() -> void:
	var owned := {}
	for key in pending.picks.keys():
		var number := int(pending.picks[key])
		if not owned.has(number):
			owned[number] = []
		owned[number].append(int(key))
	var extra := int(pending.extra)
	if not owned.has(extra):
		owned[extra] = []
	var lander := int(pending.lander)
	if not owned[extra].has(lander):
		owned[extra].append(lander)
	var spin := 1
	for _try in 80:
		spin = rng.randi_range(1, 10)
		if owned.has(spin) and owned[spin].size() > 0:
			break
	var winners: Array = owned.get(spin, [])
	for idx in winners:
		_gain(players[int(idx)], WHEEL_PRIZE, "wheel")
	_events.append({"kind": "wheel", "spin": spin, "winners": winners.duplicate()})
	pending = {}
	_end_turn()


func _park(me: Dictionary, first: String) -> void:
	var cur := first
	var guard := 0
	while board[cur].get("next", []).size() > 0 and guard < 80:
		cur = str(board[cur].next[0])
		guard += 1
	me.space = cur
	me.retired = true
	var place := retire_bonuses.size()
	var bonus: int = int(RETIRE_BONUS[mini(place, RETIRE_BONUS.size() - 1)])
	retire_bonuses.append(bonus)
	me.retire_bonus = bonus
	_gain(me, bonus, "retirement")
	var park_name := "Millionaire Mansion"
	if cur == "Space99" or str(board[cur].get("label", "")) == "Countryside":
		park_name = "Countryside Acres"
	_events.append({"kind": "park", "player": me.i, "space": cur, "bonus": bonus, "place": place + 1, "park": park_name})


func _payday(me: Dictionary, landed: bool) -> void:
	var salary := 0
	if me.career is Dictionary:
		salary = int(me.career.salary)
	_gain(me, salary, "payday")
	var bonus := 0
	if landed:
		bonus = PAYDAY_BONUS
		_gain(me, bonus, "payday bonus")
	_events.append({"kind": "payday", "player": me.i, "salary": salary, "bonus": bonus, "landed": landed})


func _draw_keep(me: Dictionary, deck_name: String) -> void:
	var card := _draw(deck_name)
	if deck_name == "pet":
		me.pets.append(card)
	else:
		me.actions.append(card)
	_events.append({
		"kind": "card",
		"player": me.i,
		"deck": deck_name,
		"title": card.get("title", ""),
		"text": card.get("text", ""),
		"salary": int(card.get("salary", 0)),
		"price": int(card.get("price", 0)),
	})
	if card.has("effect"):
		_apply_effect(me, card.effect)


func _apply_effect(me: Dictionary, effect: Dictionary) -> void:
	match str(effect.get("op", "")):
		"pay":
			_pay(me, int(effect.get("amount", 0)), "card")
		"collect":
			_gain(me, int(effect.get("amount", 0)), "card")
		"pay_each":
			for other in players:
				if int(other.i) == int(me.i):
					continue
				_pay(me, int(effect.get("amount", 0)), "card")
				_gain(other, int(effect.get("amount", 0)), "gift")
		"collect_each":
			for other in players:
				if int(other.i) == int(me.i):
					continue
				_pay(other, int(effect.get("amount", 0)), "card")
				_gain(me, int(effect.get("amount", 0)), "gift")
		"babies":
			_add_babies(me, int(effect.get("count", 1)))
		"swap_career":
			var card := _draw("college")
			if me.career is Dictionary:
				_return_card(me.career)
			me.career = card
			_events.append({"kind": "career", "player": me.i, "title": card.title, "salary": card.salary, "text": card.text})
		"loan":
			me.cash += LOAN_TAKE
			me.loans += 1
			_events.append({"kind": "loan", "player": me.i, "cash": me.cash, "loans": me.loans})
		_:
			_fault("bad card effect")


func _add_babies(me: Dictionary, count: int) -> void:
	if count <= 0:
		_events.append({"kind": "babies", "player": me.i, "count": 0})
		return
	me.babies += count
	_events.append({"kind": "babies", "player": me.i, "count": count, "total": me.babies})


func _pay(me: Dictionary, amount: int, reason: String) -> void:
	if amount <= 0:
		return
	while int(me.cash) < amount:
		me.cash += LOAN_TAKE
		me.loans += 1
		_events.append({"kind": "loan", "player": me.i, "cash": me.cash, "loans": me.loans})
		if int(me.loans) > 40:
			_fault("loan spiral")
			return
	me.cash -= amount
	_events.append({"kind": "cash", "player": me.i, "delta": -amount, "cash": me.cash, "reason": reason})
	if int(me.cash) < 0:
		_fault("negative cash")


func _gain(me: Dictionary, amount: int, reason: String) -> void:
	if amount == 0:
		return
	me.cash += amount
	_events.append({"kind": "cash", "player": me.i, "delta": amount, "cash": me.cash, "reason": reason})


func _end_turn() -> void:
	if _everyone_retired():
		_final_score()
		return
	for _step in players.size():
		turn = (turn + 1) % players.size()
		if not bool(players[turn].retired):
			break
	var me: Dictionary = players[turn]
	var started := bool(me.forks.has("Space0")) or me.career != null or bool(me.college)
	phase = "spin" if bool(started) else "choose_start"
	pending = {}
	_events.append({"kind": "turn", "player": turn, "phase": phase})


func _final_score() -> void:
	if game_over:
		return
	var best := -1000000000
	for me in players:
		var house_sum := 0
		var house_notes: Array = []
		for house in me.houses:
			var spin := rng.randi_range(1, 10)
			var red := spin <= 5
			var gain := int(house.red) if red else int(house.black)
			house_sum += gain
			house_notes.append({"title": house.title, "gain": gain, "red": red})
		var action_value := CARD_VALUE * int(me.actions.size())
		var pet_value := CARD_VALUE * int(me.pets.size())
		var baby_value := BABY_VALUE * int(me.babies)
		var loan_cost := LOAN_REPAY * int(me.loans)
		var parts := {
			"cash": int(me.cash),
			"houses": house_sum,
			"actions": action_value,
			"pets": pet_value,
			"babies": baby_value,
			"loans": loan_cost,
		}
		me.score_parts = parts
		me.cash = int(me.cash) + house_sum + action_value + pet_value + baby_value - loan_cost
		me.loans = 0
		me.houses = []
		_events.append({"kind": "score", "player": me.i, "total": me.cash, "parts": parts, "houses": house_notes})
		if int(me.cash) > best:
			best = int(me.cash)
			winners = [me.name]
		elif int(me.cash) == best:
			winners.append(me.name)
	game_over = true
	phase = "game_over"
	pending = {}
	_events.append({"kind": "winners", "names": winners.duplicate(), "detail": _winner_line()})


func _everyone_retired() -> bool:
	for me in players:
		if not bool(me.retired):
			return false
	return true


func _peek_next(me: Dictionary) -> String:
	if bool(me.at_gate):
		return str(me.forks.get("Space0", ""))
	var links: Array = board[me.space].get("next", [])
	if links.is_empty():
		return "<end>"
	if links.size() == 1:
		return str(links[0])
	return str(me.forks.get(me.space, ""))


func _branch(space_id: String, index: int) -> String:
	if not board.has(space_id):
		return ""
	var links: Array = board[space_id].get("next", [])
	if index < 0 or index >= links.size():
		return ""
	return str(links[index])


func _baby_count(space: Dictionary) -> int:
	var written := int(space.get("babies", 0))
	if written > 0:
		return written
	match str(space.get("type", "")):
		"boy", "girl":
			return 1
		"twins":
			return 2
		_:
			return 0


func _draw(deck_name: String) -> Dictionary:
	var pile: Dictionary = decks[deck_name]
	if pile.draw.is_empty():
		pile.draw = (pile.fresh as Array).duplicate(true)
		_shuffle(pile.draw)
	if pile.draw.is_empty():
		_fault("empty deck %s" % deck_name)
		return {}
	return pile.draw.pop_front()


func _return_card(card: Dictionary) -> void:
	var deck_name := str(card.get("deck", ""))
	if not decks.has(deck_name):
		return
	decks[deck_name].draw.append(card)


func _shuffle(cards: Array) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp


func _card_briefs(cards: Array) -> Array:
	var briefs: Array = []
	for card in cards:
		briefs.append({
			"title": card.get("title", ""),
			"text": card.get("text", ""),
			"salary": int(card.get("salary", 0)),
			"price": int(card.get("price", 0)),
			"deck": card.get("deck", ""),
		})
	return briefs


func _wheel_picker() -> int:
	if bool(pending.get("extra_phase", false)):
		return int(pending.lander)
	var order: Array = pending.order
	return int(order[int(pending.cursor)])


func _winner_line() -> String:
	if winners.size() == 1:
		return "%s retires richest." % winners[0]
	if winners.is_empty():
		return ""
	return "%s tie." % ", ".join(winners)


func _fault(message: String) -> void:
	if fault == "":
		fault = message
		_events.append({"kind": "fault", "message": message})
