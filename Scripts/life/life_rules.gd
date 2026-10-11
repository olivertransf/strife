extends RefCounted
class_name LifeRules

const JobsScript = preload("res://Scripts/life/life_jobs.gd")
const CardsScript = preload("res://Scripts/life/life_cards.gd")

const START_CASH := 200
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
var order: Array = []
var phase := "seat_spin"
var pending: Dictionary = {}
var rng := RandomNumberGenerator.new()
var game_over := false
var fault := ""
var retire_bonuses: Array = []
var winners: Array = []
var pot := 100
var roadkill_expands := false
var investments: Dictionary = {}
var dying: Array = []
var jobs = null
var cards = null
var acts := 0
var _events: Array = []
var _prev: Dictionary = {}
var _follow := ""
var _stop_here := false
var _last_roll := 0


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
	}


static func _clean_cards(raw: Variant, deck_name: String) -> Array:
	var list: Array = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				var card: Dictionary = item.duplicate(true)
				card["deck"] = deck_name
				list.append(card)
	return list


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


static func sale_price(house: Dictionary, spin: int) -> int:
	if spin <= 5:
		return int(house.get("red", 0))
	return int(house.get("black", 0))


func setup(board_in: Dictionary, decks_in: Dictionary, count: int, seed: int, shuffle_decks := true, names: PackedStringArray = PackedStringArray()) -> void:
	board = board_in
	rng.seed = seed
	jobs = JobsScript.new()
	cards = CardsScript.new()
	decks = {}
	for deck_name in decks_in.keys():
		var fresh: Array = []
		for card in decks_in[deck_name]:
			fresh.append((card as Dictionary).duplicate(true))
		var draw: Array = fresh.duplicate(true)
		if shuffle_decks:
			_shuffle(draw)
		decks[deck_name] = {"fresh": fresh, "draw": draw, "discard": []}
	_prev.clear()
	for space_id in board.keys():
		for nxt in board[space_id].get("next", []):
			var key := str(nxt)
			if not _prev.has(key):
				_prev[key] = []
			(_prev[key] as Array).append(str(space_id))
	players = []
	order = []
	var total := clampi(count, 1, 4)
	for i in total:
		var person := "Player %d" % (i + 1)
		if i < names.size():
			person = names[i]
		players.append(_blank(i, person))
		order.append(i)
	turn = 0
	phase = "seat_spin"
	pending = {"spins": {}}
	game_over = false
	fault = ""
	retire_bonuses = []
	winners = []
	pot = 100
	roadkill_expands = false
	investments = {}
	dying = []


func act(action: Dictionary) -> Array:
	_events = []
	_follow = ""
	_stop_here = false
	acts += 1
	if game_over:
		_fault("acted after the game ended")
		return []
	if fault != "":
		return []
	var op := str(action.get("op", ""))
	if op == "start" and phase == "seat_spin":
		_silent_open()
		_do_start(bool(action.get("college", false)))
		return _events.duplicate(true)
	match phase:
		"seat_spin":
			_seat_spin(action)
		"rps":
			_rps(bool(action.get("go_last", false)))
		"invest":
			_invest(action)
		"choose_start":
			if op == "start":
				_do_start(bool(action.get("college", false)))
			else:
				_fault("choose a path")
		"choose_card":
			_keep(int(action.get("index", 0)))
		"spin":
			if op == "repay":
				_repay()
			elif op == "buy_car":
				_buy_car()
			elif op == "buy_insurance":
				_buy_insurance()
			else:
				_do_spin(action)
		"choose_fork":
			_do_fork(action)
		"choose_house":
			if str(pending.get("step", "")) == "love":
				cards.resume(self, players[turn], action)
			else:
				_buy_house(str(action.get("choice", "skip")))
		"wheel_pick":
			_wheel_pick(int(action.get("number", 1)), action)
		"choose_target":
			cards.resume(self, players[turn], action)
		"yesno":
			if str(pending.get("step", "")) == "spouse":
				_spouse_answer(bool(action.get("yes", false)))
			else:
				cards.resume(self, players[turn], action)
		"choose_key":
			_set_key(int(action.get("number", 4)))
		_:
			_fault("nothing to do")
	return _events.duplicate(true)


func prompt() -> Dictionary:
	var me: Dictionary = players[turn]
	match phase:
		"seat_spin":
			return {"phase": phase, "title": "Seat order", "detail": "%s spins for the first seat." % me.name, "options": [{"op": "spin", "label": "Spin"}]}
		"rps":
			return {
				"phase": phase,
				"title": "Rock, paper, scissors",
				"detail": "The winner may move to the last seat.",
				"options": [
					{"op": "rps", "go_last": false, "label": "Keep this seat"},
					{"op": "rps", "go_last": true, "label": "Go last"},
				],
			}
		"invest":
			return _invest_prompt()
		"choose_start":
			return {
				"phase": phase,
				"title": "Where do you start?",
				"detail": "College costs 100K and sends you through school. Career draws a job now.",
				"options": [
					{"op": "start", "college": false, "label": "Career"},
					{"op": "start", "college": true, "label": "College"},
				],
			}
		"choose_card":
			return _card_prompt()
		"spin":
			return _spin_prompt(me)
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
		"choose_target":
			return {
				"phase": phase,
				"title": str(pending.get("ask", "Choose a player")),
				"detail": me.name,
				"options": pending.get("options", []),
			}
		"yesno":
			return {
				"phase": phase,
				"title": str(pending.get("ask", "Yes or no")),
				"detail": me.name,
				"options": [
					{"op": "yesno", "yes": true, "label": "Yes"},
					{"op": "yesno", "yes": false, "label": "No"},
				],
			}
		"choose_key":
			return _key_prompt()
		"game_over":
			return {"phase": phase, "title": "Final tally", "detail": _winner_line(), "options": []}
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
			"salary": 0 if p.career == null else _salary_of(p),
			"actions": p.kept.size() if p.kept is Array else 0,
			"pets": 0,
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


func _wheel_picker() -> int:
	var line: Array = pending.get("order", [])
	var cursor := int(pending.get("cursor", 0))
	if cursor >= 0 and cursor < line.size():
		return int(line[cursor])
	return turn


func _branch(space_id: String, index: int) -> String:
	if not board.has(space_id):
		return ""
	var links: Array = board[space_id].get("next", [])
	if index < 0 or index >= links.size():
		return ""
	return str(links[index])


func player_by_index(index: int) -> Variant:
	if index < 0 or index >= players.size():
		return null
	return players[index]


func neighbor(me: Dictionary, delta: int) -> Variant:
	var count := players.size()
	if count == 0:
		return null
	return players[(int(me.i) + delta + count) % count]


func note(kind: String, me: Dictionary, text: String) -> void:
	_events.append({"kind": kind, "player": me.i, "title": text, "text": text, "death": kind})


func roll_event(me: Dictionary, movement: bool, forced := -1) -> int:
	if bool(me.out):
		return -1
	var raw := rng.randi_range(1, 10)
	if forced >= 1 and forced <= 10:
		raw = forced
	_last_roll = raw
	_events.append({"kind": "spin", "player": me.i, "value": raw, "red": raw <= 5})
	if not jobs.on_spin(self, me, raw, movement):
		return -1
	return raw


func grant(me: Dictionary, amount: int, reason: String) -> void:
	if amount == 0 or bool(me.out):
		return
	me.cash += amount
	_events.append({"kind": "cash", "player": me.i, "delta": amount, "cash": me.cash, "reason": reason})


func pay(me: Dictionary, amount: int, reason: String, kind := "normal") -> bool:
	if amount <= 0 or bool(me.out):
		return true
	if kind == "normal" and _is_pirate(me):
		grant(me, amount, reason)
		return true
	if kind == "house" or kind == "tuition" or kind == "star":
		if int(me.cash) < amount:
			if kind == "star":
				queue_death(me, "death_return")
			return false
		me.cash -= amount
		_events.append({"kind": "cash", "player": me.i, "delta": -amount, "cash": me.cash, "reason": reason})
		return true
	var guard := 0
	while int(me.cash) < amount and guard < 40:
		guard += 1
		take_loans(me, 1)
		if fault != "":
			return false
	if int(me.cash) < amount:
		_fault("could not pay")
		return false
	me.cash -= amount
	_events.append({"kind": "cash", "player": me.i, "delta": -amount, "cash": me.cash, "reason": reason})
	return true


func pay_other(frm: Dictionary, to: Dictionary, amount: int, reason: String) -> void:
	if bool(frm.star_immune):
		return
	if not pay(frm, amount, reason, "player"):
		return
	grant(to, amount, reason)


func take_loans(me: Dictionary, count: int) -> void:
	for _i in count:
		if int(me.loans) > 400:
			_fault("loan spiral")
			return
		me.loans += 1
		me.cash += 50
		_events.append({"kind": "loan", "player": me.i, "cash": me.cash, "loans": me.loans})


func steal_all(frm: Dictionary, to: Dictionary) -> void:
	if bool(frm.star_immune):
		return
	var taken := int(frm.cash)
	var debts := int(frm.loans)
	frm.cash = 0
	frm.loans = 0
	to.cash += taken
	to.loans += debts
	_events.append({"kind": "cash", "player": frm.i, "delta": -taken, "cash": 0, "reason": "stolen"})
	if taken != 0:
		_events.append({"kind": "cash", "player": to.i, "delta": taken, "cash": to.cash, "reason": "stolen"})


func queue_death(me: Dictionary, kind: String) -> void:
	if bool(me.out) or me.purgatory != null:
		return
	if kind == "roadkill":
		me.out = true
		me.purgatory = null
		_events.append({"kind": "death", "player": me.i, "death": kind, "title": "Roadkill", "text": "Out of the game"})
		dying.append({"player": me.i, "kind": kind})
		_check_terminal()
		return
	me.purgatory = kind
	_events.append({"kind": "death", "player": me.i, "death": kind, "title": _death_name(kind), "text": "Purgatory until your turn"})
	dying.append({"player": me.i, "kind": kind})


func discard_action(card: Dictionary) -> void:
	if card.is_empty():
		return
	(decks["action"].discard as Array).append(card)


func keep_card(me: Dictionary, card: Dictionary) -> void:
	card["_kept"] = true
	me.kept.append(card)


func draw_action() -> Variant:
	return _draw("action")


func draw_house() -> Variant:
	return _draw("house")


func discard_house(house: Dictionary) -> void:
	if house.is_empty():
		return
	(decks["house"].discard as Array).append(house)


func finish_card(halt := false, quiet := false) -> void:
	var card = pending.get("card", {})
	if card is Dictionary and not card.is_empty() and not bool(card.get("_kept", false)):
		discard_action(card)
	pending.card = {}
	if quiet:
		return
	if phase != "spin":
		return
	if bool(pending.get("extra_spin", false)) and not halt:
		pending.extra_spin = false
		_follow = "again"
		_events.append({"kind": "spin_again", "player": turn})
		return
	var queue: Array = pending.get("queue", [])
	if not queue.is_empty():
		var next: Dictionary = queue.pop_front()
		pending.queue = queue
		resolve_action(players[turn], next)
		return
	_end_turn()


func resolve_action(me: Dictionary, card: Dictionary) -> void:
	_events.append({"kind": "card", "player": me.i, "title": card.get("title", ""), "text": card.get("text", ""), "deck": "action"})
	cards.apply(self, me, card)


func draw_one_action(me: Dictionary) -> void:
	if int(me.broken_leg_turns) > 0 or bool(me.out):
		return
	var count := 2 if bool(me.draw_two) else 1
	var drawn: Array = []
	for _i in count:
		var card = draw_action()
		if card == null:
			break
		drawn.append(card)
	if drawn.is_empty():
		return
	var first: Dictionary = drawn.pop_front()
	pending.queue = drawn
	resolve_action(me, first)


func find_tag(tag: String) -> String:
	for space_id in board.keys():
		if str(board[space_id].get("tag", "")) == tag:
			return str(space_id)
	return ""


func tag_of(space_id: String) -> String:
	if not board.has(space_id):
		return ""
	return str(board[space_id].get("tag", ""))


func prev_of(space_id: String) -> String:
	var list: Array = _prev.get(space_id, [])
	if list.is_empty():
		return ""
	var me: Dictionary = players[turn]
	if list.has(me.from):
		return str(me.from)
	return str(list[0])


func forward_of(space_id: String) -> String:
	if not board.has(space_id):
		return ""
	var links: Array = board[space_id].get("next", [])
	if links.is_empty():
		return ""
	return str(links[0])


func place(me: Dictionary, space_id: String) -> void:
	if space_id == "" or not board.has(space_id):
		return
	me.from = str(me.space)
	me.space = space_id
	me.at_gate = false
	_events.append({"kind": "enter", "player": me.i, "space": space_id, "landing": true})


func walk(me: Dictionary, steps: int, backward: bool) -> void:
	_walk(me, steps, backward, true)


func has_car(me: Dictionary) -> bool:
	return int(me.car_count) > 0


func car_cap(me: Dictionary) -> int:
	if _job(me) == "bus_driver":
		return 2
	return 1


func gain_car(me: Dictionary) -> bool:
	if int(me.car_count) >= car_cap(me):
		return false
	me.car_count += 1
	return true


func lose_one_car(me: Dictionary, force := false) -> bool:
	if not has_car(me):
		return false
	if not force and bool(me.insurance):
		me.insurance = false
		note("status", me, "Insurance keeps the car")
		return false
	me.car_count -= 1
	if int(me.car_count) <= 0:
		me.car_count = 0
		me.car_style = "car"
		clear_family(me)
	return true


func clear_job(me: Dictionary, forever: bool, drop := true) -> void:
	if drop and me.career != null:
		var deck := str(me.career.get("deck", "career"))
		if decks.has(deck):
			(decks[deck].discard as Array).append(me.career)
	me.career = null
	me.job_locked = false
	me.unemployed = true
	if forever:
		me.fired_forever = true
	_events.append({"kind": "career", "player": me.i, "title": "Unemployed", "salary": 20, "text": "20K on payday"})


func set_job(me: Dictionary, card: Dictionary, skip_viral := false) -> void:
	if bool(me.fired_forever) and str(card.get("id", "")) != "bee_keeper":
		return
	if me.career != null and me.career != card:
		var deck := str(me.career.get("deck", "career"))
		if decks.has(deck):
			(decks[deck].discard as Array).append(me.career)
	me.career = card
	me.unemployed = false
	me.fired_forever = false
	me.job_locked = str(card.get("id", "")) == "bee_keeper"
	if str(card.get("id", "")) == "carpenter" and int(me.star_ignore_used) == 0:
		me.star_ignore = 1
	_events.append({"kind": "career", "player": me.i, "title": card.get("title", ""), "salary": int(card.get("salary", 0)), "text": card.get("text", "")})
	if not skip_viral and str(card.get("id", "")) == "youtuber" and str(me.viral) != "yes":
		_viral(me)


func offer_jobs(me: Dictionary, deck_name: String, extra_spin: bool) -> void:
	if bool(me.job_locked) or bool(me.fired_forever):
		if extra_spin:
			pending.extra_spin = true
			phase = "spin"
			finish_card()
		else:
			phase = "spin"
			_after_ready(me) if not bool(me.ready) else _end_turn()
		return
	var first = _draw(deck_name)
	var second = _draw(deck_name)
	var dealt: Array = []
	if first != null:
		dealt.append(first)
	if second != null:
		dealt.append(second)
	if dealt.is_empty():
		phase = "spin"
		if bool(me.ready):
			_end_turn()
		else:
			_after_ready(me)
		return
	if dealt.size() == 1:
		set_job(me, dealt[0])
		phase = "spin"
		if extra_spin:
			pending.extra_spin = true
			finish_card()
		elif bool(me.ready):
			_end_turn()
		else:
			_after_ready(me)
		return
	pending.kind = "night" if bool(me.ready) else "job"
	pending.cards = dealt
	pending.extra_spin = extra_spin
	pending.deck = deck_name
	phase = "choose_card"
	_events.append({"kind": "deal", "player": me.i, "cards": _briefs(dealt)})


func begin_night(me: Dictionary, extra_spin: bool) -> void:
	var card = pending.get("card", {})
	if card is Dictionary and not card.is_empty() and not bool(card.get("_kept", false)):
		discard_action(card)
		pending.card = {}
	var fee := 0 if _job(me) == "janitor" else 100
	if fee > 0:
		pay(me, fee, "night school")
	if bool(me.job_locked) or bool(me.fired_forever):
		phase = "spin"
		if extra_spin:
			pending.extra_spin = true
			_events.append({"kind": "spin_again", "player": me.i})
		else:
			_end_turn()
		return
	var deck := "career"
	if bool(me.college) or (me.career != null and str(me.career.get("deck", "")) == "college"):
		deck = "college"
	offer_jobs(me, deck, extra_spin)


func can_take_child(me: Dictionary) -> bool:
	return has_car(me) and not bool(me.infertile)


func add_child(me: Dictionary, boy: bool, crowd: bool) -> void:
	if not can_take_child(me):
		return
	if boy:
		me.boys += 1
		if crowd:
			me.crowd_boys += 1
	else:
		me.girls += 1
		if crowd:
			me.crowd_girls += 1
	_sync(me)
	if _job(me) == "aaron":
		grant(me, 100, "child")
	_events.append({"kind": "babies", "player": me.i, "count": 1})


func clear_family(me: Dictionary) -> void:
	me.spouse = false
	clear_family_children(me)


func clear_family_children(me: Dictionary) -> void:
	me.girls = 0
	me.boys = 0
	me.crowd_girls = 0
	me.crowd_boys = 0
	_sync(me)


func foreign_houses(me: Dictionary) -> Array:
	var list: Array = []
	for other in players:
		if int(other.i) == int(me.i) or bool(other.star_immune):
			continue
		for h in other.houses.size():
			list.append({"index": other.i, "house": h, "title": other.houses[h].get("title", "House")})
	return list


func ask_target(me: Dictionary, ask: String) -> void:
	var options: Array = []
	for other in players:
		if int(other.i) == int(me.i) or bool(other.out):
			continue
		options.append({"op": "target", "index": other.i, "label": other.name, "house": false})
	if options.is_empty():
		finish_card()
		return
	phase = "choose_target"
	pending.ask = ask
	pending.options = options


func ask_houses(me: Dictionary, ask: String) -> void:
	var options: Array = []
	for row in foreign_houses(me):
		var owner = players[int(row.index)]
		options.append({
			"op": "target",
			"index": owner.i,
			"house": int(row.house),
			"label": "%s  %s" % [owner.name, row.title],
		})
	if options.is_empty():
		finish_card()
		return
	phase = "choose_target"
	pending.step = "house_collector"
	pending.ask = ask
	pending.options = options


func empty_stars(include_smiley: bool) -> Array:
	var list: Array = []
	for space_id in board.keys():
		var tag := tag_of(str(space_id))
		if tag == "black_dot":
			continue
		if tag == "smiley" and not include_smiley:
			continue
		if tag != "star" and tag != "smiley":
			continue
		var holders: Array = investments.get(str(space_id), [])
		if holders.is_empty():
			list.append(str(space_id))
	return list


func add_investment(me: Dictionary, space_id: String) -> void:
	if not investments.has(space_id):
		investments[space_id] = []
	(investments[space_id] as Array).append(int(me.i))


func gain_house(me: Dictionary, house: Dictionary) -> void:
	me.houses.append(house)
	_events.append({"kind": "house", "player": me.i, "title": house.get("title", ""), "text": house.get("title", ""), "price": 200, "bought": true})
	if str(house.get("buff", "")) == "windmill":
		_walk(me, 5, false, true)
	elif str(house.get("buff", "")) == "teepee":
		var raw := roll_event(me, false)
		if raw >= 6:
			grant(me, 50, "teepee")


func open_wheel(me: Dictionary, prize: int) -> void:
	var line: Array = []
	for p in players:
		if not bool(p.out):
			line.append(int(p.i))
	phase = "wheel_pick"
	pending.kind = "wheel"
	pending.lander = me.i
	pending.order = line
	pending.cursor = 0
	pending.picks = {}
	pending.prize = prize
	pending.extra_phase = false


func swap_lives(a: Dictionary, b: Dictionary) -> void:
	var keys: Array = [
		"cash", "loans", "career", "unemployed", "fired_forever", "job_locked", "assassin_hits", "silent",
		"salary_override", "salary_double", "flipped", "viral", "car_count", "car_style", "ebike", "insurance",
		"spouse", "girls", "boys", "crowd_girls", "crowd_boys", "infertile", "houses", "kept",
		"purgatory", "skip_turns", "jail_key", "groundhog", "broken_leg_turns", "draw_two",
		"odd_half", "flat_tire_turns", "jet_turns", "move10_turns", "star_toll", "star_ignore",
		"star_ignore_used", "star_immune", "bacteria_host", "roadkill_trail", "college",
	]
	for key in keys:
		var tmp = a.get(key, null)
		a[key] = b.get(key, null)
		b[key] = tmp
	_sync(a)
	_sync(b)
	note("status", a, "Lives swapped with %s" % b.name)


func _blank(index: int, person: String) -> Dictionary:
	return {
		"i": index,
		"name": person,
		"cash": START_CASH,
		"loans": 0,
		"career": null,
		"unemployed": false,
		"fired_forever": false,
		"job_locked": false,
		"assassin_hits": 0,
		"silent": false,
		"salary_override": null,
		"salary_double": false,
		"flipped": false,
		"viral": "no",
		"car_count": 1,
		"car_style": "car",
		"ebike": false,
		"insurance": false,
		"spouse": false,
		"girls": 0,
		"boys": 0,
		"crowd_girls": 0,
		"crowd_boys": 0,
		"infertile": false,
		"houses": [],
		"kept": [],
		"space": "Space0",
		"retired": false,
		"out": false,
		"purgatory": null,
		"skip_turns": 0,
		"jail_key": null,
		"groundhog": false,
		"broken_leg_turns": 0,
		"draw_two": false,
		"odd_half": false,
		"flat_tire_turns": 0,
		"jet_turns": 0,
		"move10_turns": 0,
		"star_toll": false,
		"star_ignore": 0,
		"star_ignore_used": 0,
		"star_immune": false,
		"bacteria_host": null,
		"roadkill_trail": 0,
		"trail": [],
		"forks": {},
		"at_gate": true,
		"college": false,
		"ready": false,
		"babies": 0,
		"pets": [],
		"left_hand": false,
		"from": "Space0",
		"retire_bonus": 0,
		"score_parts": {},
	}


func _silent_open() -> void:
	order = []
	for p in players:
		order.append(int(p.i))
	phase = "choose_start"
	turn = 0
	pending = {}


func _seat_spin(action: Dictionary) -> void:
	var raw := _raw(action)
	pending.spins[turn] = raw
	_events.append({"kind": "spin", "player": turn, "value": raw, "red": raw <= 5})
	if pending.spins.size() < players.size():
		turn = (turn + 1) % players.size()
		return
	var best := -1
	var tied: Array = []
	for i in players.size():
		var score := int(pending.spins[i])
		if score > best:
			best = score
			tied = [i]
		elif score == best:
			tied.append(i)
	if tied.size() > 1:
		var kept := {}
		for i in players.size():
			if not tied.has(i):
				kept[i] = pending.spins[i]
		pending.spins = kept
		turn = int(tied[0])
		return
	order.sort_custom(func(a, b):
		var sa := int(pending.spins[a])
		var sb := int(pending.spins[b])
		if sa == sb:
			return int(a) < int(b)
		return sa > sb
	)
	turn = int(order[0])
	phase = "rps"
	pending = {}


func _rps(go_last: bool) -> void:
	if go_last:
		var seat := int(turn)
		order.erase(seat)
		order.append(seat)
	phase = "invest"
	pending = {"cursor": 0}
	turn = int(order[0])


func _invest(action: Dictionary) -> void:
	var me: Dictionary = players[turn]
	if bool(action.get("yes", false)):
		var dest := str(action.get("dest", ""))
		if dest != "" and int(me.cash) >= 100:
			pay(me, 100, "star bet", "star")
			if fault == "":
				add_investment(me, dest)
	var cursor := int(pending.get("cursor", 0)) + 1
	if cursor >= order.size():
		phase = "choose_start"
		pending = {}
		turn = int(order[0])
		return
	pending.cursor = cursor
	turn = int(order[cursor])


func _do_start(college: bool) -> void:
	var me: Dictionary = players[turn]
	if college and int(me.cash) >= 100:
		pay(me, 100, "tuition", "tuition")
		me.college = true
		me.forks["Space0"] = _branch("Space0", 1)
		me.at_gate = true
		_events.append({"kind": "path", "player": me.i, "college": true})
		_after_ready(me)
		return
	me.college = false
	me.forks["Space0"] = _branch("Space0", 0)
	me.at_gate = true
	_events.append({"kind": "path", "player": me.i, "college": false})
	offer_jobs(me, "career", false)


func _keep(index: int) -> void:
	if str(pending.get("step", "")) == "hogwarts":
		cards.resume(self, players[turn], {"index": index})
		return
	var dealt: Array = pending.get("cards", [])
	if dealt.is_empty():
		_fault("no cards")
		return
	if index < 0 or index >= dealt.size():
		index = 0
	var me: Dictionary = players[turn]
	var extra := bool(pending.get("extra_spin", false))
	var night := str(pending.get("kind", "")) == "night"
	for i in dealt.size():
		if i != index:
			var deck := str(dealt[i].get("deck", "career"))
			if decks.has(deck):
				(decks[deck].discard as Array).append(dealt[i])
	set_job(me, dealt[index])
	pending = {}
	phase = "spin"
	if night:
		if extra:
			_events.append({"kind": "spin_again", "player": me.i})
		else:
			_end_turn()
		return
	_after_ready(me)


func _after_ready(me: Dictionary) -> void:
	me.ready = true
	for seat in order:
		if not bool(players[int(seat)].ready):
			turn = int(seat)
			phase = "choose_start"
			pending = {}
			return
	turn = int(order[0])
	phase = "spin"
	pending = {}
	_events.append({"kind": "turn", "player": turn, "phase": phase})


func _do_spin(action: Dictionary) -> void:
	var me: Dictionary = players[turn]
	if bool(me.out) or bool(me.retired):
		_end_turn()
		return
	_resolve_purgatory(me)
	if fault != "" or game_over or bool(me.out):
		return
	if int(me.skip_turns) > 0:
		me.skip_turns -= 1
		note("skip", me, "Turn skipped")
		_end_turn()
		return
	if me.jail_key != null:
		var key_spin := _raw(action)
		_events.append({"kind": "spin", "player": me.i, "value": key_spin, "red": key_spin <= 5})
		jobs.on_spin(self, me, key_spin, false)
		if me.purgatory == null and not bool(me.out) and key_spin == int(me.jail_key):
			me.jail_key = null
			note("jail", me, "The key fits")
		_end_turn()
		return
	if bool(me.groundhog):
		var hog := _raw(action)
		_events.append({"kind": "spin", "player": me.i, "value": hog, "red": hog <= 5})
		jobs.on_spin(self, me, hog, false)
		if me.purgatory == null and not bool(me.out) and hog >= 6:
			me.groundhog = false
			note("status", me, "The day moves on")
		_end_turn()
		return
	if int(me.move10_turns) > 0:
		me.move10_turns -= 1
		_walk(me, 10, false, false)
		return
	if me.bacteria_host != null:
		var host = player_by_index(int(me.bacteria_host))
		var host_gone := host == null or bool(host.out) or bool(host.retired) or host.bacteria_host != null
		if host_gone:
			me.bacteria_host = null
			if tag_of(str(me.space)) == "roadkill" or _expanded_kill(str(me.space)) or _trail_kill(me, str(me.space)):
				queue_death(me, "roadkill")
				if not game_over:
					_end_turn()
				return
		else:
			_end_turn()
			return
	var raw := _raw(action)
	_events.append({"kind": "spin", "player": me.i, "value": raw, "red": raw <= 5})
	var moving: bool = jobs.on_spin(self, me, raw, true)
	if not moving or me.purgatory != null or bool(me.out) or game_over:
		if not game_over and not bool(me.out):
			_end_turn()
		return
	var length := _length(me, raw)
	if length <= 0:
		_end_turn()
		return
	_walk(me, length, false, false)


func _length(me: Dictionary, raw: int) -> int:
	var mult := 1.0
	if _job(me) == "race_car_driver":
		mult = 2.0
	if int(me.jet_turns) > 0 and mult == 1.0 and has_car(me):
		mult = 2.0
	if not has_car(me):
		mult = 0.5
	if bool(me.odd_half) and raw % 2 == 1:
		mult = 0.5
	var length := float(raw) * mult
	if _job(me) == "aaron":
		length += float(int(me.girls) + int(me.boys))
	length -= float(int(me.boys) - int(me.crowd_boys))
	if bool(me.ebike):
		length += 2.0
	if has_car(me) and str(me.car_style) == "ev":
		length += 1.0
	if int(me.flat_tire_turns) > 0:
		length -= 2.0
	if int(me.crowd_girls) + int(me.crowd_boys) > 0:
		length -= 4.0
	if int(me.flat_tire_turns) > 0 and length < 0.0:
		if bool(me.insurance):
			me.insurance = false
		else:
			pay(me, 250, "crash")
		length = 0.0
	if length < 0.0:
		length = 0.0
	return int(length)


func _walk(me: Dictionary, steps: int, backward: bool, nested: bool) -> void:
	var left := steps
	var guard := 0
	while left > 0 and guard < 80:
		guard += 1
		if game_over or fault != "" or _follow != "" or bool(me.out) or me.purgatory != null:
			return
		if phase != "spin":
			return
		var nxt := ""
		if backward:
			nxt = prev_of(str(me.space))
		else:
			nxt = _peek_next(me)
		if nxt == "":
			if not backward:
				_open_fork(me)
			return
		if nxt == "<end>":
			_retire(me, str(me.space))
			return
		var landing := left == 1 or _hard_stop(nxt, me)
		if not _enter(me, nxt, landing, backward):
			if game_over or _follow != "":
				return
			if phase == "choose_key":
				pending.left = left - 1
				pending.backward = backward
				pending.nested = nested
			elif not nested and phase == "spin" and (bool(me.out) or me.purgatory != null):
				_end_turn()
			return
		left -= 1
		if _stop_here:
			_stop_here = false
			if not nested and _follow == "" and phase == "spin" and not game_over:
				_end_turn()
			return
		if phase != "spin" or _follow != "":
			return
		if landing:
			if bool(pending.get("extra_spin", false)) and not nested:
				pending.extra_spin = false
				_follow = "again"
				_events.append({"kind": "spin_again", "player": me.i})
			elif not nested and _follow == "" and not game_over:
				_end_turn()
			return
	if not nested and _follow == "" and phase == "spin" and not game_over:
		_end_turn()


func _enter(me: Dictionary, space_id: String, landing: bool, backward: bool) -> bool:
	var previous := str(me.space)
	me.from = previous
	me.space = space_id
	me.at_gate = false
	if not backward and previous != "":
		me.trail.append(previous)
		while me.trail.size() > 5:
			me.trail.pop_front()
	_events.append({"kind": "enter", "player": me.i, "space": space_id, "landing": landing})
	_copy_bacteria(me)
	var tag := tag_of(space_id)
	if tag == "roadkill" or _expanded_kill(space_id) or _trail_kill(me, space_id):
		queue_death(me, "roadkill")
		return false
	if tag == "car_stack":
		queue_death(me, "soft_return")
		return false
	var kind := str(board[space_id].get("type", ""))
	if not landing and not backward and kind == "payday" and not (has_car(me) and str(me.car_style) == "giraffe"):
		_payday(me)
	if not _pass_triggers(me, space_id):
		return false
	if phase != "spin":
		return false
	if not landing and has_car(me) and str(me.car_style) == "giraffe" and kind == "payday":
		_land(me, space_id, backward)
		_stop_here = true
		return _follow == "" and phase == "spin" and me.purgatory == null and not bool(me.out)
	if not landing:
		return true
	_land(me, space_id, backward)
	if _follow != "" or phase != "spin" or me.purgatory != null or bool(me.out) or game_over:
		return false
	return true


func _land(me: Dictionary, space_id: String, backward: bool) -> void:
	var tag := tag_of(space_id)
	if tag == "ram":
		if _job(me) == "zoo_keeper":
			_instant_win(me)
			return
		queue_death(me, "soft_return")
		return
	if tag == "school":
		place(me, find_tag("night_school"))
		begin_night(me, false)
		return
	var kind := str(board[space_id].get("type", ""))
	var stop := str(board[space_id].get("stop", ""))
	var override := tag in ["star", "smiley", "black_dot", "macaw", "polar"]
	if tag in ["star", "smiley", "black_dot"]:
		_land_star(me, space_id, tag)
		if phase != "spin" or me.purgatory != null:
			return
	if override:
		kind = ""
	if kind == "payday":
		_payday(me)
	elif kind == "action":
		draw_one_action(me)
	elif kind == "house":
		_offer_board_house(me)
	elif kind == "boy":
		add_child(me, true, false)
	elif kind == "girl":
		add_child(me, false, false)
	elif kind == "twins":
		add_child(me, true, false)
		add_child(me, false, false)
	elif kind == "wheel":
		open_wheel(me, -1)
	elif kind == "end":
		_retire(me, space_id)
		return
	elif kind == "pet":
		pass
	if stop == "married":
		if has_car(me) and not bool(me.spouse):
			me.spouse = true
			_events.append({"kind": "married", "player": me.i, "gift": 0, "spin": 0, "red": false})
		if not backward:
			pending.extra_spin = true
	elif stop == "babies":
		add_child(me, false, false)
		if not backward:
			pending.extra_spin = true
	elif stop == "night" and tag == "night_school":
		begin_night(me, not backward)
	elif stop in ["family", "risky", "retirement"]:
		_open_fork(me)
	elif stop != "" and stop != "start" and not backward:
		pending.extra_spin = true


func _pass_triggers(me: Dictionary, space_id: String) -> bool:
	for other in players:
		if int(other.i) == int(me.i) or bool(other.out) or other.purgatory != null:
			continue
		if str(other.space) != space_id:
			continue
		var mine := int(me.girls) + int(me.boys)
		var theirs := int(other.girls) + int(other.boys)
		if mine >= 5 and theirs >= 5:
			_duel(me, other)
		if _job(me) == "police_officer" and has_car(other) and _job(other) != "firefighter" and other.jail_key == null and not bool(other.star_immune):
			_ask_key(me, other)
			return false
		if _job(me) == "janitor" and bool(other.spouse) and not bool(other.star_immune):
			other.spouse = false
			note("status", other, "The Janitor takes the spouse")
		if _job(me) == "baby_sitter" and theirs > 0 and not bool(other.star_immune):
			pay_other(other, me, 80 * theirs, "sitting")
		if has_car(me) and not has_car(other):
			pay(other, 200, "hit and run")
	return true


func _duel(a: Dictionary, b: Dictionary) -> void:
	var left := 0
	var right := 0
	var guard := 0
	while left == right and guard < 10:
		guard += 1
		left = rng.randi_range(1, 6)
		right = rng.randi_range(1, 6)
	var loser: Dictionary = a if left < right else b
	_remove_children(loser, 3)
	loser.infertile = true
	_events.append({"kind": "duel", "player": loser.i, "title": "Child duel", "text": "%s loses 3 children" % loser.name})


func _ask_key(officer: Dictionary, target: Dictionary) -> void:
	pending.suspend = {"jail": target.i}
	pending.ask = "%s names the jail key" % officer.name
	phase = "choose_key"


func _set_key(number: int) -> void:
	var target_i := int(pending.get("suspend", {}).get("jail", -1))
	var left := int(pending.get("left", 0))
	var backward := bool(pending.get("backward", false))
	var nested := bool(pending.get("nested", false))
	var target = player_by_index(target_i)
	if target != null:
		target.jail_key = clampi(number, 1, 10)
		note("jail", target, "Key %d" % int(target.jail_key))
	pending = {}
	phase = "spin"
	var me: Dictionary = players[turn]
	if game_over or bool(me.out) or me.purgatory != null:
		if not game_over:
			_end_turn()
		return
	if left > 0:
		_walk(me, left, backward, nested)
		return
	_land(me, str(me.space), backward)
	if _follow != "" or phase != "spin" or game_over or bool(me.out) or me.purgatory != null:
		if me.purgatory != null and not game_over and _follow == "":
			_end_turn()
		return
	if bool(pending.get("extra_spin", false)):
		pending.extra_spin = false
		_follow = "again"
		_events.append({"kind": "spin_again", "player": me.i})
		return
	_end_turn()


func _land_star(me: Dictionary, space_id: String, tag: String) -> void:
	if tag == "black_dot":
		grant(me, 1000, "black dot")
		return
	if bool(me.star_toll):
		_pay_star(me, 600)
		return
	if tag == "smiley":
		return
	pending.star = space_id
	phase = "choose_fork"
	pending.kind = "star_bet"
	pending.title = "Star"
	pending.detail = "Invest 100K, cash only."
	pending.options = [
		{"op": "fork", "index": 0, "label": "Invest 100K"},
		{"op": "fork", "index": 1, "label": "Walk on"},
	]


func _pay_star(me: Dictionary, amount: int) -> void:
	if bool(me.star_immune):
		return
	if int(me.star_ignore) > 0:
		me.star_ignore = 0
		me.star_ignore_used = 1
		note("status", me, "The Carpenter ignores the star")
		return
	if int(me.cash) < amount:
		queue_death(me, "death_return")
		return
	pay(me, amount, "star", "star")


func _payday(me: Dictionary) -> void:
	var amount := _payday_amount(me)
	if amount != 0:
		grant(me, amount, "payday")
	if me.career != null and _job(me) == "happy_loan_collector":
		take_loans(me, 4)
	_events.append({"kind": "payday", "player": me.i, "salary": amount, "bonus": 0, "landed": true})


func _payday_amount(me: Dictionary) -> int:
	if me.career == null and not bool(me.unemployed):
		return 0
	if bool(me.unemployed) and me.career == null:
		return 20
	var base := int(me.career.get("salary", 0))
	if bool(me.flipped):
		base = int(me.salary_override)
	if bool(me.salary_double):
		base *= 2
	if _job(me) == "pirate":
		base += 150
	for house in me.houses:
		if str(house.get("buff", "")) == "eco":
			base += 10
	return base


func _salary_of(me: Dictionary) -> int:
	if me.career == null:
		return 0
	var base := int(me.career.get("salary", 0))
	if bool(me.flipped):
		base = int(me.salary_override)
	if bool(me.salary_double):
		base *= 2
	return base


func _offer_board_house(me: Dictionary) -> void:
	var house = draw_house()
	if house == null:
		return
	pending.house = house
	pending.step = ""
	phase = "choose_house"


func _buy_house(choice: String) -> void:
	var me: Dictionary = players[turn]
	var house = pending.get("house", null)
	pending.house = null
	phase = "spin"
	if choice == "buy" and house is Dictionary and int(me.cash) >= int(house.get("price", 0)):
		if pay(me, int(house.price), "house", "house"):
			gain_house(me, house)
			if _follow != "" or phase != "spin" or game_over:
				return
			_end_turn()
			return
	if house is Dictionary:
		discard_house(house)
	if _follow != "" or game_over:
		return
	phase = "spin"
	_end_turn()


func _do_fork(action: Dictionary) -> void:
	var kind := str(pending.get("kind", ""))
	if kind == "free_star" or str(pending.get("step", "")) == "free_star":
		cards.resume(self, players[turn], action)
		return
	if kind == "star_bet":
		var me: Dictionary = players[turn]
		if int(action.get("index", 1)) == 0 and int(me.cash) >= 100:
			pay(me, 100, "star", "star")
			if fault == "":
				add_investment(me, str(pending.get("star", "")))
		phase = "spin"
		pending = {}
		_end_turn()
		return
	var options: Array = pending.get("options", [])
	var index := int(action.get("index", 0))
	if index < 0 or index >= options.size():
		_fault("bad fork")
		return
	var me: Dictionary = players[turn]
	if kind == "retirement":
		_retire(me, str(options[index].get("dest", me.space)))
		return
	if kind == "risky" and index == 0:
		var raw := roll_event(me, false)
		if raw > 0 and raw <= 5 and me.purgatory == null and not bool(me.out):
			me.cash = 0
			note("status", me, "Risky road takes the cash")
		if me.purgatory != null or bool(me.out) or game_over:
			if not game_over:
				_end_turn()
			return
	var dest := str(options[index].get("dest", ""))
	me.forks[str(me.space)] = dest
	_events.append({"kind": "fork", "player": me.i, "dest": dest, "label": options[index].get("label", "")})
	pending = {}
	phase = "spin"
	_events.append({"kind": "spin_again", "player": me.i})


func _open_fork(me: Dictionary) -> void:
	var space: Dictionary = board[me.space]
	var kind := str(space.get("stop", "fork"))
	var labels: Array = []
	match kind:
		"family":
			labels = ["Life path", "Family path"]
		"risky":
			labels = ["Risky road", "Safe route"]
		"retirement":
			labels = ["Countryside Acres", "Millionaire Mansion"]
		_:
			labels = ["This way", "That way"]
	var nexts: Array = space.get("next", [])
	if nexts.size() <= 1:
		return
	var options: Array = []
	for i in nexts.size():
		var label := "Path %d" % (i + 1)
		if i < labels.size():
			label = str(labels[i])
		options.append({"op": "fork", "index": i, "label": label, "dest": str(nexts[i])})
	phase = "choose_fork"
	pending = {
		"kind": kind,
		"title": str(space.get("label", kind)),
		"detail": "Choose the next road.",
		"options": options,
	}


func _wheel_pick(number: int, action: Dictionary) -> void:
	var picker := _wheel_picker()
	number = clampi(number, 1, 10)
	pending.picks[picker] = number
	_events.append({"kind": "wheel_pick", "player": picker, "number": number, "extra": false})
	pending.cursor = int(pending.get("cursor", 0)) + 1
	var line: Array = pending.get("order", [])
	if int(pending.cursor) < line.size():
		return
	var lander: Dictionary = players[int(pending.get("lander", turn))]
	var forced := int(action.get("spin", -1))
	var raw := roll_event(lander, false, forced)
	if raw < 0:
		raw = _last_roll
	var prize := int(pending.get("prize", -1))
	if prize < 0:
		prize = pot
	var won: Array = []
	for key in pending.picks.keys():
		if int(pending.picks[key]) == raw:
			won.append(int(key))
			grant(players[int(key)], prize, "wheel")
	_events.append({"kind": "wheel", "player": lander.i, "spin": raw, "winners": won, "prize": prize})
	pot += 100
	pending = {}
	phase = "spin"
	if not game_over:
		_end_turn()


func _retire(me: Dictionary, first: String) -> void:
	var cur := first
	var guard := 0
	while board.has(cur) and board[cur].get("next", []).size() > 0 and str(board[cur].get("type", "")) != "end" and guard < 80:
		cur = str(board[cur].next[0])
		guard += 1
	me.space = cur
	me.retired = true
	me.at_gate = false
	var place_i := retire_bonuses.size()
	var bonus := 0
	if place_i < RETIRE_BONUS.size():
		bonus = int(RETIRE_BONUS[place_i])
	retire_bonuses.append(bonus)
	me.retire_bonus = bonus
	grant(me, bonus, "retirement")
	var park_name := "Retirement"
	if cur == "Space99" or str(board[cur].get("label", "")) == "Countryside":
		park_name = "Countryside Acres"
	elif cur == "Space121" or str(board[cur].get("label", "")) == "Mansion":
		park_name = "Millionaire Mansion"
	_events.append({"kind": "park", "player": me.i, "space": cur, "bonus": bonus, "place": place_i + 1, "park": park_name})
	pending = {}
	phase = "spin"
	_end_turn()


func _resolve_purgatory(me: Dictionary) -> void:
	if me.purgatory == null:
		return
	var kind := str(me.purgatory)
	me.purgatory = null
	match kind:
		"soft_return":
			if not lose_one_car(me):
				pass
			elif int(me.car_count) > 0:
				pass
			place(me, "Space0")
		"death_return":
			_wipe(me)
			me.car_count = 1
			me.car_style = "car"
			me.unemployed = true
			place(me, "Space0")
		"snake_return":
			_wipe(me)
			me.car_count = 1
			me.car_style = "car"
			me.unemployed = true
			take_loans(me, 5)
			place(me, "Space0")
		"snakebite":
			_become_bee(me)
			place(me, "Space0")
		_:
			place(me, "Space0")
	note("status", me, _death_name(kind))


func _wipe(me: Dictionary) -> void:
	me.cash = 0
	me.loans = 0
	me.career = null
	me.job_locked = false
	me.fired_forever = false
	me.unemployed = true
	me.assassin_hits = 0
	me.silent = false
	me.salary_double = false
	me.flipped = false
	me.salary_override = 0
	me.viral = "no"
	me.ebike = false
	me.insurance = false
	me.houses = []
	me.kept = []
	me.skip_turns = 0
	me.jail_key = null
	me.groundhog = false
	me.broken_leg_turns = 0
	me.draw_two = false
	me.odd_half = false
	me.flat_tire_turns = 0
	me.jet_turns = 0
	me.move10_turns = 0
	me.star_toll = false
	me.star_ignore = 0
	me.star_ignore_used = 0
	me.star_immune = false
	me.bacteria_host = null
	me.roadkill_trail = 0
	me.trail = []
	clear_family(me)


func _become_bee(me: Dictionary) -> void:
	for other in players:
		if int(other.i) == int(me.i):
			continue
		if _job(other) == "bee_keeper":
			clear_job(other, true)
	var card := _job_card("bee_keeper")
	if card.is_empty():
		card = {"id": "bee_keeper", "title": "Bee Keeper", "salary": 0, "bonus": 3, "gift": 0, "special": "bee", "deck": "career"}
	me.fired_forever = false
	set_job(me, card, true)
	me.job_locked = true


func _instant_win(me: Dictionary) -> void:
	game_over = true
	phase = "game_over"
	winners = [me.i]
	_events.append({"kind": "winners", "player": me.i, "title": me.name})


func _end_turn() -> void:
	_follow = "ended"
	if game_over or fault != "":
		return
	_tick(players[turn])
	if _check_terminal():
		return
	var me: Dictionary = players[turn]
	if not bool(me.out) and not bool(me.retired) and _lone_mover(me) and _distance(me) > 50 and not _any_purgatory():
		place(me, find_tag("family_stop"))
		me.retired = true
		_events.append({"kind": "park", "player": me.i, "space": me.space, "bonus": 0, "place": 0, "park": "Family stop"})
		_tally()
		return
	var guard := 0
	var nxt := int(turn)
	while guard < players.size():
		guard += 1
		nxt = _next_seat(nxt)
		var cand: Dictionary = players[nxt]
		if bool(cand.out) or bool(cand.retired):
			continue
		turn = nxt
		phase = "spin"
		pending = {}
		_events.append({"kind": "turn", "player": turn, "phase": phase})
		return
	_tally()


func _tick(me: Dictionary) -> void:
	if int(me.flat_tire_turns) > 0:
		me.flat_tire_turns -= 1
	if int(me.jet_turns) > 0:
		me.jet_turns -= 1
	if int(me.broken_leg_turns) > 0:
		me.broken_leg_turns -= 1


func _check_terminal() -> bool:
	if game_over:
		return true
	for p in players:
		if not bool(p.out) and not bool(p.retired):
			return false
	_tally()
	return true


func _tally() -> void:
	pending.tally_i = 0
	_tally_step()


func _tally_step() -> void:
	var i := int(pending.get("tally_i", 0))
	while i < players.size():
		var me: Dictionary = players[i]
		i += 1
		pending.tally_i = i
		if bool(me.out):
			continue
		if bool(me.spouse):
			phase = "yesno"
			pending.step = "spouse"
			pending.ask = "Sell your spouse?"
			pending.spouse = me.i
			turn = me.i
			return
	_score_all()


func _spouse_answer(yes: bool) -> void:
	var me: Dictionary = players[int(pending.get("spouse", turn))]
	if yes and bool(me.spouse):
		var raw := rng.randi_range(1, 10)
		if raw >= 6:
			grant(me, 200, "spouse")
		else:
			pay(me, 500, "spouse")
		me.spouse = false
	_tally_step()


func _score_all() -> void:
	var best := -1000000000
	winners = []
	for me in players:
		var total := 0
		if not bool(me.out):
			total = int(me.cash)
			for house in me.houses:
				var spin := rng.randi_range(1, 10)
				var gain := sale_price(house, spin)
				total += gain
				_events.append({"kind": "house", "player": me.i, "title": house.get("title", ""), "bought": false, "red": spin <= 5, "gain": gain})
			total += 100 * (int(me.girls) + int(me.boys))
			total += 100 * me.kept.size()
			total -= 50 * int(me.loans)
		me.cash = total
		me.score_parts = {"total": total}
		_events.append({"kind": "score", "player": me.i, "total": total})
		if total > best:
			best = total
			winners = [me.i]
		elif total == best:
			winners.append(me.i)
	game_over = true
	phase = "game_over"
	_events.append({"kind": "winners", "winners": winners.duplicate()})


func _repay() -> void:
	var me: Dictionary = players[turn]
	if int(me.loans) <= 0 or int(me.cash) < 60:
		return
	me.cash -= 60
	me.loans -= 1
	_events.append({"kind": "repay", "player": me.i, "cash": me.cash, "loans": me.loans})


func _buy_car() -> void:
	var me: Dictionary = players[turn]
	if int(me.cash) < 500 or int(me.car_count) >= car_cap(me):
		return
	pay(me, 500, "car", "house")
	if fault == "":
		gain_car(me)


func _buy_insurance() -> void:
	var me: Dictionary = players[turn]
	if bool(me.insurance) or int(me.cash) < 200:
		return
	pay(me, 200, "insurance", "house")
	if fault == "":
		me.insurance = true


func _viral(me: Dictionary) -> void:
	var raw := roll_event(me, false)
	if raw < 0:
		return
	if raw >= 6:
		me.viral = "yes"
		grant(me, 500, "viral")
	else:
		me.viral = "failed"


func _copy_bacteria(host: Dictionary) -> void:
	for other in players:
		if other.bacteria_host == null:
			continue
		if int(other.bacteria_host) != int(host.i):
			continue
		other.space = host.space
		other.from = host.from
		_events.append({"kind": "enter", "player": other.i, "space": host.space, "landing": true})


func _hard_stop(space_id: String, _me: Dictionary) -> bool:
	if not board.has(space_id):
		return false
	var stop := str(board[space_id].get("stop", ""))
	if stop != "" and stop != "start":
		return true
	if tag_of(space_id) in ["school", "roadkill", "car_stack"]:
		return true
	return false


func _peek_next(me: Dictionary) -> String:
	if bool(me.at_gate):
		return str(me.forks.get("Space0", ""))
	if not board.has(me.space):
		return ""
	var links: Array = board[me.space].get("next", [])
	if links.is_empty():
		return "<end>"
	if links.size() == 1:
		return str(links[0])
	var chosen := str(me.forks.get(me.space, ""))
	return chosen


func _expanded_kill(space_id: String) -> bool:
	if not roadkill_expands:
		return false
	var road := find_tag("roadkill")
	if road == "":
		return false
	var list: Array = _prev.get(road, [])
	return list.has(space_id)


func _trail_kill(me: Dictionary, space_id: String) -> bool:
	for other in players:
		if int(other.i) == int(me.i) or int(other.roadkill_trail) <= 0:
			continue
		if other.trail.has(space_id):
			return true
	return false


func _remove_children(me: Dictionary, count: int) -> void:
	var left := count
	while left > 0 and int(me.crowd_boys) > 0:
		me.crowd_boys -= 1
		me.boys -= 1
		left -= 1
	while left > 0 and int(me.crowd_girls) > 0:
		me.crowd_girls -= 1
		me.girls -= 1
		left -= 1
	while left > 0 and int(me.boys) > 0:
		me.boys -= 1
		left -= 1
	while left > 0 and int(me.girls) > 0:
		me.girls -= 1
		left -= 1
	_sync(me)


func _lone_mover(me: Dictionary) -> bool:
	for other in players:
		if int(other.i) == int(me.i):
			continue
		if not bool(other.retired):
			return false
	return true


func _any_purgatory() -> bool:
	for p in players:
		if p.purgatory != null:
			return true
	return false


func _distance(me: Dictionary) -> int:
	var seen := {}
	var queue: Array = [[str(me.space), 0]]
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var here: String = item[0]
		var dist: int = item[1]
		if seen.has(here) or not board.has(here):
			continue
		seen[here] = true
		if str(board[here].get("type", "")) == "end" or str(board[here].get("stop", "")) == "retirement":
			return dist
		for nxt in board[here].get("next", []):
			queue.append([str(nxt), dist + 1])
	return 0


func _next_seat(current: int) -> int:
	var at := order.find(current)
	if at < 0:
		return (current + 1) % players.size()
	return int(order[(at + 1) % order.size()])


func _job(me: Dictionary) -> String:
	if me.career == null:
		return ""
	return str(me.career.get("id", ""))


func _is_pirate(me: Dictionary) -> bool:
	return _job(me) == "pirate"


func _job_card(id: String) -> Dictionary:
	for deck_name in ["career", "college"]:
		if not decks.has(deck_name):
			continue
		for pile_name in ["fresh", "draw", "discard"]:
			for card in decks[deck_name][pile_name]:
				if str(card.get("id", "")) == id:
					return card
	return {}


func _death_name(kind: String) -> String:
	match kind:
		"soft_return":
			return "Car stack"
		"death_return":
			return "Death"
		"snake_return":
			return "Snake"
		"snakebite":
			return "Snakebite"
		"roadkill":
			return "Roadkill"
		_:
			return "Death"


func _draw(deck_name: String) -> Variant:
	if not decks.has(deck_name):
		return null
	var pile: Dictionary = decks[deck_name]
	if (pile.draw as Array).is_empty():
		pile.draw = pile.discard
		pile.discard = []
		_shuffle(pile.draw)
	if (pile.draw as Array).is_empty():
		return null
	return (pile.draw as Array).pop_front()


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp


func _raw(action: Dictionary) -> int:
	if action.has("value"):
		return clampi(int(action.value), 1, 10)
	return rng.randi_range(1, 10)


func _sync(me: Dictionary) -> void:
	me.babies = int(me.girls) + int(me.boys)


func _fault(message: String) -> void:
	fault = message
	_events.append({"kind": "fault", "text": message})


func _winner_line() -> String:
	if winners.is_empty():
		return "No winner"
	var names: PackedStringArray = []
	for i in winners:
		names.append(str(players[int(i)].name))
	return ", ".join(names)


func _invest_prompt() -> Dictionary:
	var options: Array = [{"op": "invest", "yes": false, "label": "Skip"}]
	for space_id in empty_stars(false):
		options.append({"op": "invest", "yes": true, "dest": space_id, "label": "Bet 100K"})
		break
	return {"phase": phase, "title": "Star bet", "detail": "Optional 100K. The smiley star is closed.", "options": options}


func _card_prompt() -> Dictionary:
	var dealt: Array = pending.get("cards", [])
	var options: Array = []
	for i in dealt.size():
		var card: Dictionary = dealt[i]
		options.append({"op": "keep", "index": i, "label": "%s  %dK" % [card.get("title", "Card"), int(card.get("salary", 0))]})
	return {"phase": phase, "title": "Keep one", "detail": "The other goes back.", "options": options}


func _spin_prompt(me: Dictionary) -> Dictionary:
	var options: Array = [{"op": "spin", "label": "Spin"}]
	if me.jail_key != null or bool(me.groundhog) or int(me.skip_turns) > 0 or int(me.move10_turns) > 0:
		return {"phase": phase, "title": "%s" % me.name, "detail": _spin_detail(me), "options": [{"op": "spin", "label": "Continue"}]}
	if int(me.loans) > 0 and int(me.cash) >= 60:
		options.append({"op": "repay", "label": "Repay a loan"})
	if int(me.cash) >= 500 and int(me.car_count) < car_cap(me):
		options.append({"op": "buy_car", "label": "Buy a car"})
	if not bool(me.insurance) and int(me.cash) >= 200:
		options.append({"op": "buy_insurance", "label": "Buy insurance"})
	return {"phase": phase, "title": "%s spins" % me.name, "detail": _spin_detail(me), "options": options}


func _spin_detail(me: Dictionary) -> String:
	if me.jail_key != null:
		return "Spin the jail key."
	if bool(me.groundhog):
		return "Spin black to leave this space."
	if int(me.skip_turns) > 0:
		return "This turn is skipped."
	if int(me.move10_turns) > 0:
		return "Move 10."
	if me.career == null:
		return "No salary yet."
	return "Spin 1 to 10."


func _house_prompt(me: Dictionary) -> Dictionary:
	if str(pending.get("step", "")) == "love":
		var offers: Array = pending.get("offers", [])
		var index := int(pending.get("offer_i", 0))
		var title := "House"
		if index < offers.size() and offers[index] != null:
			title = str(offers[index].get("title", "House"))
		return {
			"phase": phase,
			"title": title,
			"detail": "200K cash.",
			"options": [
				{"op": "house", "choice": "buy", "label": "Buy"},
				{"op": "house", "choice": "skip", "label": "Skip"},
			],
		}
	var house = pending.get("house", {})
	var price := int(house.get("price", 0)) if house is Dictionary else 0
	var name := str(house.get("title", "House")) if house is Dictionary else "House"
	return {
		"phase": phase,
		"title": name,
		"detail": "%dK cash" % price,
		"options": [
			{"op": "house", "choice": "buy", "label": "Buy"},
			{"op": "house", "choice": "skip", "label": "Skip"},
		],
	}


func _wheel_prompt() -> Dictionary:
	var options: Array = []
	for number in range(1, 11):
		options.append({"op": "wheel", "number": number, "label": str(number)})
	var picker := _wheel_picker()
	var shown := pot
	if int(pending.get("prize", -1)) >= 0:
		shown = int(pending.prize)
	return {"phase": phase, "title": "%s picks" % players[picker].name, "detail": "The pot is %dK." % shown, "picker": picker, "options": options}


func _key_prompt() -> Dictionary:
	var options: Array = []
	for number in range(1, 11):
		options.append({"op": "key", "number": number, "label": str(number)})
	return {"phase": phase, "title": "Jail key", "detail": str(pending.get("ask", "")), "options": options}


func _briefs(dealt: Array) -> Array:
	var rows: Array = []
	for card in dealt:
		rows.append({"title": card.get("title", ""), "text": card.get("text", ""), "salary": int(card.get("salary", 0))})
	return rows
