extends RefCounted
class_name LifeCards


func apply(rules, me: Dictionary, card: Dictionary) -> void:
	if bool(me.out) or me.purgatory != null:
		rules.discard_action(card)
		return
	var id := str(card.get("id", ""))
	rules.pending.card = card
	rules.pending.step = id
	match id:
		"mint_crypto":
			_color_pay(rules, me, 1000, 100)
		"crypto_scams":
			_color_pay(rules, me, 500, 500, true)
		"chatgpt":
			_chatgpt(rules, me)
		"lawsuit_tomatoes", "lawsuit_idea", "lawsuit_property":
			rules.ask_target(me, "Collect 100K from whom?")
		"lucky_moose":
			rules.open_wheel(me, 1000)
		"goat_ribbon":
			rules.grant(me, 120, "goat")
			rules.keep_card(me, card)
			rules.finish_card()
		"food_truck":
			_contest(rules, me, true)
		"spin_to_lose":
			_contest(rules, me, false)
		"dog_ransom":
			_dog(rules, me)
		"movie_star":
			_movie(rules, me)
		"mugged":
			_mugged(rules, me)
		"robbed_right":
			_rob(rules, me, 1, true)
		"steal_left":
			_rob(rules, me, -1, false)
		"identity_theft":
			rules.ask_target(me, "Swap lives with whom?")
		"five_loans":
			rules.take_loans(me, 5)
			rules.finish_card()
		"double_salary":
			me.salary_double = true
			rules.finish_card()
		"salary_flip":
			_flip(rules, me)
		"house_collector":
			_collector(rules, me)
		"love_or_list":
			_love(rules, me)
		"steal_job_or_house":
			rules.ask_target(me, "Steal a job or a house from whom?")
		"foreclosure":
			_foreclose(rules, me)
		"free_star":
			_free_star(rules, me)
		"life_toll":
			me.star_toll = true
			rules.finish_card()
		"nigel":
			rules.place(me, rules.find_tag("macaw"))
			rules.take_loans(me, 3)
			rules.finish_card(true)
		"win_car":
			if rules.gain_car(me):
				rules.note("status", me, "A new car")
			else:
				rules.grant(me, 60, "extra car")
			rules.finish_card()
		"car_flip":
			if rules.has_car(me):
				rules.lose_one_car(me)
			else:
				rules.gain_car(me)
			rules.finish_card()
		"insurance_flip":
			me.insurance = not bool(me.insurance)
			rules.finish_card()
		"unpaid_insurance":
			rules.lose_one_car(me)
			me.odd_half = true
			rules.finish_card()
		"flat_tire":
			me.flat_tire_turns = 3
			rules.finish_card()
		"giraffe":
			if rules.has_car(me):
				me.car_style = "giraffe"
			rules.finish_card()
		"ebike":
			if rules.has_car(me) and bool(me.insurance):
				me.insurance = false
			elif rules.has_car(me):
				rules.lose_one_car(me, true)
				me.ebike = true
			rules.finish_card()
		"ev":
			if not rules.has_car(me):
				rules.gain_car(me)
			me.car_style = "ev"
			rules.finish_card()
		"steal_all_cars":
			_steal_cars(rules, me)
		"move_10":
			me.move10_turns = 3
			rules.finish_card()
		"jet":
			if rules.has_car(me) and _job_id(me) != "race_car_driver" and int(me.jet_turns) <= 0:
				me.jet_turns = 2
			rules.finish_card()
		"fired_cat", "fired_snooze":
			_redraw_job(rules, me)
		"fired_forever":
			rules.clear_job(me, true)
			me.fired_forever = true
			rules.finish_card()
		"adoption":
			_adoption(rules, me)
		"twelve_children":
			_twelve(rules, me)
		"kidnapping":
			_kidnap(rules, me)
		"vows":
			_vows(rules, me)
		"divorce_fight":
			rules.clear_family(me)
			if _job_id(me) != "firefighter":
				me.jail_key = 4
				rules.note("jail", me, "Divorce jail, key 4")
			rules.finish_card()
		"lost_phone":
			rules.walk(me, 6, true)
			rules.finish_card(true)
		"night_school":
			rules.place(me, rules.find_tag("night_school"))
			rules.begin_night(me, false)
		"polar_bear":
			_polar(rules, me)
		"covid":
			_covid(rules, me)
		"broken_leg":
			me.broken_leg_turns = 5
			rules.finish_card()
		"left_hand":
			me.left_hand = true
			rules.finish_card()
		"groundhog":
			me.groundhog = true
			rules.finish_card()
		"meat":
			rules.phase = "yesno"
			rules.pending.step = "meat"
			rules.pending.ask = "Have you eaten meat in the last 24 hours?"
		"hogwarts":
			_hogwarts(rules, me)
		"draw_two":
			me.draw_two = true
			rules.finish_card()
		"wheel_card":
			rules.open_wheel(me, -1)
		"bacteria":
			var host = rules.neighbor(me, -1)
			if host != null:
				me.bacteria_host = int(host.i)
			rules.finish_card()
		"break_free":
			_break_free(rules, me)
		"star_immunity":
			me.star_immune = true
			rules.finish_card()
		"roadkill_blessing":
			me.roadkill_trail = 5
			rules.finish_card()
		"roadkill_expands":
			rules.roadkill_expands = true
			rules.finish_card()
		"snakebite":
			rules.queue_death(me, "snakebite")
			rules.finish_card()
		_:
			rules.finish_card()


func resume(rules, me: Dictionary, action: Dictionary) -> void:
	rules.phase = "spin"
	var step := str(rules.pending.get("step", ""))
	match step:
		"lawsuit_tomatoes", "lawsuit_idea", "lawsuit_property":
			var other = rules.player_by_index(int(action.get("index", -1)))
			if other != null and not bool(other.star_immune):
				rules.pay_other(other, me, 100, "lawsuit")
				rules.keep_card(me, rules.pending.card)
			rules.finish_card()
		"identity_theft":
			var other = rules.player_by_index(int(action.get("index", -1)))
			if other != null and not bool(other.star_immune) and not bool(other.out):
				rules.swap_lives(me, other)
			rules.finish_card()
		"steal_job_or_house":
			_steal_from(rules, me, action)
		"house_collector":
			_take_named_house(rules, me, action)
		"love":
			_love_answer(rules, me, action)
		"free_star":
			var dest := str(action.get("dest", ""))
			if dest != "":
				rules.add_investment(me, dest)
			rules.finish_card()
		"meat":
			if bool(action.get("yes", false)):
				me.cash = 0
				rules.note("cash", me, "The snake and the ram take the cash")
			rules.finish_card()
		"hogwarts":
			var cards: Array = rules.pending.get("cards", [])
			var index := int(action.get("index", 0))
			if index < 0 or index >= cards.size():
				index = 0
			var kept: Dictionary = cards[index]
			for i in cards.size():
				if i != index:
					rules.discard_action(cards[i])
			rules.pending.card = {}
			rules.phase = "spin"
			rules.resolve_action(me, kept)
		_:
			rules.finish_card()


func _color_pay(rules, me: Dictionary, black_gain: int, red_pay: int, red_is_pay := true) -> void:
	var raw: int = rules.roll_event(me, false)
	if raw < 0:
		rules.finish_card()
		return
	if raw >= 6:
		rules.grant(me, black_gain, "black")
	elif red_is_pay:
		rules.pay(me, red_pay, "red")
	rules.finish_card()


func _chatgpt(rules, me: Dictionary) -> void:
	var raw: int = rules.roll_event(me, false)
	if raw < 0:
		rules.finish_card()
		return
	if raw >= 6:
		rules.clear_job(me, false)
	else:
		rules.grant(me, 500, "grant")
	rules.finish_card()


func _contest(rules, me: Dictionary, pay_winners: bool) -> void:
	var best := -1
	var scored: Array = []
	for other in rules.players:
		if bool(other.out):
			continue
		var raw: int = rules.roll_event(other, false)
		if raw < 0:
			continue
		scored.append({"i": other.i, "raw": raw})
		if raw > best:
			best = raw
	for row in scored:
		if int(row.raw) != best:
			continue
		var who = rules.player_by_index(int(row.i))
		if who == null:
			continue
		if pay_winners:
			rules.grant(who, 500, "race")
		else:
			rules.pay(who, 500, "spin to lose")
	rules.finish_card()


func _dog(rules, me: Dictionary) -> void:
	var raw: int = rules.roll_event(me, false)
	if raw < 0:
		rules.finish_card()
		return
	var amount := 100
	if raw <= 3:
		amount = 10
	elif raw <= 6:
		amount = 20
	elif raw <= 9:
		amount = 50
	rules.pay(me, amount, "ransom")
	rules.finish_card()


func _movie(rules, me: Dictionary) -> void:
	var raw: int = rules.roll_event(me, false)
	if raw < 0:
		rules.finish_card()
		return
	if raw <= 5:
		rules.pay(me, 50, "movie")
	elif raw <= 8:
		rules.grant(me, 50, "movie")
	else:
		rules.grant(me, 5000, "movie")
	rules.finish_card()


func _mugged(rules, me: Dictionary) -> void:
	var raw: int = rules.roll_event(me, false)
	if raw < 0:
		rules.finish_card()
		return
	if raw <= 5:
		me.cash = 0
	rules.finish_card()


func _rob(rules, me: Dictionary, delta: int, skip_next: bool) -> void:
	var other = rules.neighbor(me, delta)
	if other != null and not bool(other.star_immune):
		if skip_next:
			rules.steal_all(me, other)
		else:
			rules.steal_all(other, me)
	if skip_next:
		me.skip_turns += 1
	rules.finish_card()


func _flip(rules, me: Dictionary) -> void:
	var raw: int = rules.roll_event(me, false)
	if raw < 0:
		rules.finish_card()
		return
	me.salary_double = false
	me.flipped = true
	me.salary_override = 0 if raw <= 5 else 1000
	rules.finish_card()


func _collector(rules, me: Dictionary) -> void:
	var raw: int = rules.roll_event(me, false)
	if raw < 0:
		rules.finish_card()
		return
	var need := 0
	if raw >= 9:
		need = 2
	elif raw >= 6:
		need = 1
	var homes: Array = rules.foreign_houses(me)
	if need <= 0 or homes.is_empty():
		rules.finish_card()
		return
	rules.pending.need = mini(need, homes.size())
	rules.pending.step = "house_collector"
	rules.ask_houses(me, "Which house do you take?")


func _love(rules, me: Dictionary) -> void:
	var offers: Array = []
	for _i in 2:
		var house = rules.draw_house()
		if house == null:
			break
		offers.append(house)
	if offers.is_empty():
		rules.finish_card()
		return
	rules.pending.offers = offers
	rules.pending.offer_i = 0
	rules.pending.step = "love"
	rules.phase = "choose_house"
	rules.pending.price = 200


func _foreclose(rules, me: Dictionary) -> void:
	if me.houses.size() > 0:
		while me.houses.size() > 0:
			rules.discard_house(me.houses.pop_back())
	else:
		rules.clear_family_children(me)
	rules.finish_card()


func _free_star(rules, me: Dictionary) -> void:
	var open: Array = rules.empty_stars(false)
	if open.is_empty():
		rules.finish_card()
		return
	var options: Array = []
	for space_id in open:
		options.append({"op": "fork", "index": options.size(), "dest": space_id, "label": "Star %s" % space_id})
	rules.phase = "choose_fork"
	rules.pending.step = "free_star"
	rules.pending.kind = "free_star"
	rules.pending.title = "Free investment"
	rules.pending.detail = "Place a marker on an empty star."
	rules.pending.options = options


func _steal_cars(rules, me: Dictionary) -> void:
	for other in rules.players:
		if int(other.i) == int(me.i) or not rules.has_car(other):
			continue
		if rules.lose_one_car(other):
			rules.gain_car(me)
	rules.finish_card()


func _redraw_job(rules, me: Dictionary) -> void:
	if bool(me.job_locked):
		rules.finish_card()
		return
	var deck := "career"
	if me.career != null:
		deck = str(me.career.get("deck", "career"))
	rules.clear_job(me, false)
	rules.offer_jobs(me, deck, false)


func _adoption(rules, me: Dictionary) -> void:
	if not rules.can_take_child(me):
		rules.finish_card()
		return
	rules.add_child(me, false, false)
	rules.walk(me, 10, true)
	rules.finish_card(true)


func _twelve(rules, me: Dictionary) -> void:
	if not rules.can_take_child(me):
		rules.finish_card()
		return
	for _i in 8:
		rules.add_child(me, false, true)
	for _j in 4:
		rules.add_child(me, true, true)
	rules.finish_card()


func _kidnap(rules, me: Dictionary) -> void:
	var kids := int(me.girls) + int(me.boys)
	if kids <= 0:
		rules.finish_card()
		return
	rules.pay(me, 10 * kids, "ransom")
	var raw: int = rules.roll_event(me, false)
	if raw > 0 and raw <= 5:
		rules.clear_family_children(me)
	rules.finish_card()


func _vows(rules, me: Dictionary) -> void:
	if not bool(me.spouse):
		rules.finish_card()
		return
	var raw: int = rules.roll_event(me, false)
	if raw < 0:
		rules.finish_card()
		return
	if raw >= 6:
		me.spouse = false
	else:
		rules.pay(me, 100, "vows")
	rules.finish_card()


func _polar(rules, me: Dictionary) -> void:
	rules.place(me, rules.find_tag("polar"))
	var guard := 0
	while guard < 80:
		guard += 1
		var prev: String = rules.prev_of(str(me.space))
		if prev == "":
			break
		if rules.tag_of(prev) in ["star", "smiley", "black_dot"]:
			break
		rules.place(me, prev)
	rules.finish_card(true)


func _covid(rules, me: Dictionary) -> void:
	var raw: int = rules.roll_event(me, false)
	if raw < 0:
		rules.finish_card()
		return
	me.skip_turns += 3 if raw <= 5 else 1
	rules.finish_card()


func _hogwarts(rules, me: Dictionary) -> void:
	var drawn: Array = []
	for _i in 2:
		var card = rules.draw_action()
		if card == null:
			break
		drawn.append(card)
	if drawn.is_empty():
		rules.finish_card()
		return
	if drawn.size() == 1:
		rules.finish_card()
		rules.resolve_action(me, drawn[0])
		return
	rules.pending.cards = drawn
	rules.pending.step = "hogwarts"
	rules.pending.kind = "hogwarts"
	rules.phase = "choose_card"


func _break_free(rules, me: Dictionary) -> void:
	var bacteria: Dictionary = {}
	var host: Dictionary = {}
	if me.bacteria_host != null:
		bacteria = me
		var found = rules.player_by_index(int(me.bacteria_host))
		if found != null:
			host = found
	else:
		for other in rules.players:
			if other.bacteria_host != null and int(other.bacteria_host) == int(me.i):
				bacteria = other
				host = me
				break
	if bacteria.is_empty():
		rules.finish_card()
		return
	bacteria.bacteria_host = null
	var nxt: String = rules.forward_of(str(host.space))
	if nxt != "":
		rules.place(bacteria, nxt)
	rules.finish_card()
	rules.draw_one_action(bacteria)


func _steal_from(rules, me: Dictionary, action: Dictionary) -> void:
	var other = rules.player_by_index(int(action.get("index", -1)))
	if other == null or bool(other.star_immune):
		rules.finish_card()
		return
	var take_house := bool(action.get("house", false))
	if take_house and other.houses.size() > 0:
		var house = other.houses.pop_front()
		me.houses.append(house)
	elif other.career != null and not bool(other.job_locked) and not bool(me.fired_forever) and not bool(me.job_locked):
		var stolen = other.career
		rules.clear_job(other, false, false)
		rules.set_job(me, stolen, true)
	rules.finish_card()


func _take_named_house(rules, me: Dictionary, action: Dictionary) -> void:
	var owner = rules.player_by_index(int(action.get("index", -1)))
	var which := int(action.get("house", 0))
	if owner != null and which >= 0 and which < owner.houses.size() and not bool(owner.star_immune):
		var house = owner.houses[which]
		owner.houses.remove_at(which)
		me.houses.append(house)
	rules.pending.need = int(rules.pending.get("need", 1)) - 1
	if int(rules.pending.need) > 0 and not rules.foreign_houses(me).is_empty():
		rules.ask_houses(me, "Take another house")
		return
	rules.finish_card()


func _love_answer(rules, me: Dictionary, action: Dictionary) -> void:
	var offers: Array = rules.pending.get("offers", [])
	var index := int(rules.pending.get("offer_i", 0))
	if index < offers.size() and str(action.get("choice", "")) == "buy" and int(me.cash) >= 200:
		rules.pay(me, 200, "house", "house")
		if rules.fault == "":
			rules.gain_house(me, offers[index])
			offers[index] = null
	elif index < offers.size() and offers[index] != null:
		rules.discard_house(offers[index])
	index += 1
	rules.pending.offer_i = index
	if index < offers.size():
		rules.phase = "choose_house"
		return
	rules.finish_card()


func _job_id(me: Dictionary) -> String:
	if me.career == null:
		return ""
	return str(me.career.get("id", ""))
