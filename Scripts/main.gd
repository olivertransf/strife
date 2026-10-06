extends Node2D

const RETIRE_BONUS: Array[int] = [400, 300, 200, 100]
const PET_NAMES: Array[String] = ["Miso", "Dot", "Pip", "Nib"]

@export var game_spaces: Array[Node]
@export var players: Dictionary[int, Sprite2D] = {}

@onready var camera: Camera2D = $Camera2D
@onready var ui = $Control
@onready var start_space: Spaces = $Spaces/Start

const DeckScript := preload("res://Scripts/life_decks.gd")
var decks
var seated: Array[Player] = []
var turn := 0
var current_player: Player
var retire_count := 0
var college_entry := ""
var career_entry := ""
var playing := false
var autoplay := false
var prompts := 0
var did_repay: Dictionary = {}
var sold_once := false
var last_money: Dictionary = {}
var ring
var board
var hold_camera := false
var snapshot := false

const PLAY_ZOOM := 1.5
const PEG_COLORS: Array[Color] = [
	Color(0.86, 0.27, 0.22),
	Color(0.24, 0.46, 0.82),
	Color(0.28, 0.62, 0.38),
	Color(0.58, 0.36, 0.74),
]

const KIND_NAME: Dictionary = {
	Spaces.SpaceType.PAYDAY: "Payday",
	Spaces.SpaceType.ACTION: "Action",
	Spaces.SpaceType.HOUSE: "House",
	Spaces.SpaceType.START: "Start",
	Spaces.SpaceType.BOY: "Boy",
	Spaces.SpaceType.GIRL: "Girl",
	Spaces.SpaceType.SPIN2WIN: "Spin to Win",
	Spaces.SpaceType.TWINS: "Twins",
	Spaces.SpaceType.STAR: "Pet",
	Spaces.SpaceType.STOP: "Stop",
	Spaces.SpaceType.BONUS: "Bonus",
	Spaces.SpaceType.DEBT: "Debt",
	Spaces.SpaceType.END: "Retirement",
}


func _ready() -> void:
	autoplay = OS.get_cmdline_user_args().has("--autoplay")
	snapshot = OS.get_cmdline_user_args().has("--snapshot")
	if autoplay:
		seed(4304)
	else:
		randomize()
	decks = DeckScript.new()
	$spin_number.visible = false
	if has_node("Board"):
		$Board.visible = false
	if has_node("Img3466"):
		$Img3466.visible = false
	_ensure_fourth_player()
	_prepare_paths()
	board = preload("res://Scripts/board_art.gd").new()
	board.z_index = 1
	add_child(board)
	board.build($Spaces, college_entry, career_entry)
	for player in _scene_players():
		_seat_on(player, start_space)
	camera.make_current()
	camera.zoom = Vector2(PLAY_ZOOM, PLAY_ZOOM)
	camera.position = _camera_goal()
	ring = preload("res://Scripts/peg_ring.gd").new()
	ring.z_index = 6
	add_child(ring)
	if OS.get_cmdline_user_args().has("--self-test"):
		_self_test()
		get_tree().quit()
		return
	if snapshot:
		_take_snapshot()
		return
	if autoplay:
		ui.presented.connect(_auto_answer)
		print("AUTOPLAY seed 4304")
	_boot()
	if autoplay:
		ui._on_start.call_deferred()


func _self_test() -> void:
	print("PATHS college=", college_entry, " career=", career_entry)
	var sample := Player.new()
	sample.took_college = true
	sample.job_name = ""
	sample.married = false
	print("GRAD ", _stop_role(sample, $Spaces/Space132))
	sample.job_name = "Teacher"
	print("MARRIED ", _stop_role(sample, $Spaces/Space14))
	sample.married = true
	print("BABY ", _stop_role(sample, $Spaces/Space65))
	print("FAMILY ", _branch_labels($Spaces/Space55))
	print("RISKY ", _branch_labels($Spaces/Space92))
	print("FORK ", _branch_labels($Spaces/Space26))
	print("END ", _stop_role(sample, $Spaces/Space121))
	sample.free()


func _process(_delta: float) -> void:
	if camera == null:
		return
	var focus := start_space.global_position
	if current_player:
		focus = current_player.global_position
	if ring:
		ring.follow(focus)
	if board and current_player:
		board.focus = current_player.space
	if hold_camera:
		return
	var weight := 1.0 if autoplay else 0.07
	camera.position = camera.position.lerp(_camera_goal(), weight)


func _camera_goal() -> Vector2:
	var focus := start_space.global_position
	if current_player:
		focus = current_player.global_position
	var zoom := camera.zoom.x if camera else PLAY_ZOOM
	var view := get_viewport_rect().size
	return focus + Vector2(0.13 * view.x / zoom, -8)


func _take_snapshot() -> void:
	await _grab("/tmp/strife-setup.png")
	ui.hide_setup()
	var roster := _scene_players()
	var names: PackedStringArray = ["Ada", "Bea", "Cal"]
	for index in 3:
		var player := roster[index]
		player.visible = true
		player.set_peg_name(names[index])
		player.color = PEG_COLORS[index]
		player.restyle()
		seated.append(player)
	roster[3].visible = false
	_seat_on(seated[0], start_space)
	_seat_on(seated[1], $Spaces/Space55)
	_seat_on(seated[2], $Spaces/Space26)
	seated[0].money = 100
	seated[0].took_college = true
	seated[1].money = 240
	seated[1].job_name = "Artist"
	seated[1].salary = 30
	seated[1].married = true
	seated[1].people = 2
	seated[1].restyle()
	seated[2].money = 380
	seated[2].job_name = "Teacher"
	seated[2].salary = 40
	current_player = seated[1]
	playing = true
	board.focus = current_player.space
	ui.present("Bea, spin.", PackedStringArray(), true, false)
	ui.refresh(seated, current_player)
	hold_camera = true
	camera.zoom = Vector2(PLAY_ZOOM, PLAY_ZOOM)
	camera.position = _camera_goal()
	if ring:
		ring.follow(current_player.global_position)
	await _grab("/tmp/strife-play.png")
	var sample: Array[Dictionary] = [
		{"name": "Artist", "salary": 30, "kind": "career"},
		{"name": "Doctor", "salary": 100, "kind": "college"},
		{"name": "Villa", "cost": 160, "red": 200, "black": 120, "kind": "house"},
	]
	ui.present_cards(
		"Ada, choose a card.",
		sample,
		PackedStringArray(["Artist, 30K", "Doctor, 100K", "Villa for 160K"]),
		PackedStringArray(["Pass"])
	)
	await _grab("/tmp/strife-cards.png")
	ui.present("Bea, spin.", PackedStringArray(), true, false)
	_fit_table()
	await _grab("/tmp/strife-table.png")
	get_tree().quit(0)


func _fit_table() -> void:
	var min_p := Vector2(100000, 100000)
	var max_p := Vector2(-100000, -100000)
	for child in $Spaces.get_children():
		if child is Spaces:
			var at: Vector2 = (child as Spaces).global_position
			min_p = min_p.min(at)
			max_p = max_p.max(at)
	var center := (min_p + max_p) * 0.5
	var span := (max_p - min_p) + Vector2(140, 120)
	var view := get_viewport_rect().size
	var zx := (view.x * 0.72) / span.x
	var zy := (view.y * 0.88) / span.y
	var fitted := minf(zx, zy)
	camera.zoom = Vector2(fitted, fitted)
	camera.position = center + Vector2(view.x * 0.13 / fitted, 0)


func _grab(path: String) -> void:
	for _step in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	print("SNAPSHOT ", path, " ", image.get_width(), " ", image.get_height())


func _boot() -> void:
	await ui.acted
	if ui.last_action != "setup":
		return
	var count: int = ui.last_index
	var roster := _scene_players()
	for index in roster.size():
		var player := roster[index]
		player.visible = index < count
		if index < count:
			player.set_peg_name(ui.setup_names[index])
			player.color = PEG_COLORS[index % PEG_COLORS.size()]
			player.restyle()
			player.pet_name = PET_NAMES[index]
			seated.append(player)
	ui.hide_setup()
	playing = true
	_log("Everyone starts with 200K, one peg, and a pet.")
	await _opening()
	var turns_taken := 0
	while not _all_retired():
		turns_taken += 1
		if turns_taken > 400:
			_fail("the table did not retire")
			return
		current_player = seated[turn]
		if current_player.retired:
			_advance()
			continue
		await _take_turn(current_player)
		if _all_retired():
			break
		_advance()
	await _finale()


func _opening() -> void:
	for player in seated:
		current_player = player
		_refresh()
		var path := await _choose(
			"%s, college or career?" % player.display_name,
			PackedStringArray(["College, pay 100K", "Career now"])
		)
		if path == 0:
			player.took_college = true
			_charge(player, 100)
			player.forced_index = _index_named(start_space, college_entry)
			_log("%s pays 100K and starts college." % player.display_name)
		else:
			player.forced_index = _index_named(start_space, career_entry)
			await _pick_job(player, "careers", "choose one of these two careers")
		_refresh()


func _take_turn(player: Player) -> void:
	var again := true
	var first := true
	while again:
		var prompt := "%s, spin." % player.display_name
		if not first:
			prompt = "%s, spin again." % player.display_name
		await _wait_spin(player, prompt)
		var spin := _roll()
		_show_spin(spin)
		_log("%s spins %d (%s)." % [player.display_name, spin, _color_name(spin)])
		await _flick(spin)
		await _move(player, spin)
		again = await _resolve(player)
		first = false
		_refresh()


func _move(player: Player, steps: int) -> void:
	ui.present("%s is moving." % player.display_name, PackedStringArray(), false, false)
	var space := player.space
	for step in steps:
		if space == null or space.space_type == Spaces.SpaceType.END:
			break
		var dest := await _step_target(space, player)
		if dest == null:
			break
		var dest_pos := _peg_position(player, dest)
		if autoplay:
			player.global_position = dest_pos
		else:
			player.hop()
			var tween := create_tween()
			tween.tween_property(player, "global_position", dest_pos, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await tween.finished
			if board:
				board.burst(dest_pos, Color(0.98, 0.94, 0.82))
		space = dest
		player.space = space
		ui.prompt_label.text = "%s  ·  %s" % [player.display_name, KIND_NAME.get(space.space_type, "")]
		var more := step < steps - 1
		if space.space_type == Spaces.SpaceType.PAYDAY and more:
			player.money += player.salary
			if player.salary > 0:
				_log("%s collects %dK for passing payday." % [player.display_name, player.salary])
			_refresh()
		if space.space_type == Spaces.SpaceType.STOP or space.space_type == Spaces.SpaceType.END:
			break


func _step_target(space: Spaces, player: Player) -> Spaces:
	var paths := space.next_spaces
	if paths.is_empty():
		return null
	var index := 0
	if player.forced_index >= 0 and player.forced_index < paths.size():
		index = player.forced_index
		player.forced_index = -1
	elif paths.size() > 1:
		var labels := _branch_labels(space)
		_show_fork(space)
		index = await _choose("%s, which path?" % player.display_name, labels)
		_clear_fork()
	return space.get_node(paths[index]) as Spaces


func _resolve(player: Player) -> bool:
	var space := player.space
	if space == null:
		return false
	match space.space_type:
		Spaces.SpaceType.PAYDAY:
			var payout := player.salary + 100
			player.money += payout
			_log("%s lands on payday and collects %dK." % [player.display_name, payout])
			return false
		Spaces.SpaceType.ACTION:
			await _draw_kept(player, "actions")
			return false
		Spaces.SpaceType.STAR:
			await _draw_kept(player, "pets")
			return false
		Spaces.SpaceType.HOUSE:
			await _house_stop(player)
			return false
		Spaces.SpaceType.SPIN2WIN:
			await _spin_to_win(player)
			return false
		Spaces.SpaceType.BOY:
			_add_babies(player, 1, "a boy")
			return false
		Spaces.SpaceType.GIRL:
			_add_babies(player, 1, "a girl")
			return false
		Spaces.SpaceType.TWINS:
			_add_babies(player, 2, "twins")
			return false
		Spaces.SpaceType.BONUS:
			player.money += 100
			_log("%s collects a 100K bonus." % player.display_name)
			return false
		Spaces.SpaceType.DEBT:
			_charge(player, 50)
			_log("%s pays 50K on a debt space." % player.display_name)
			return false
		Spaces.SpaceType.STOP, Spaces.SpaceType.END:
			return await _resolve_stop(player, space)
		_:
			return false


func _resolve_stop(player: Player, space: Spaces) -> bool:
	var role := _stop_role(player, space)
	match role:
		"graduation":
			_log("%s graduates." % player.display_name)
			await _pick_job(player, "college", "choose one of these two careers")
			return true
		"married":
			if not player.married and player.people < Player.CAR_CAPACITY:
				player.married = true
				player.people += 1
				_log("%s gets married. A spouse peg gets in the car." % player.display_name)
			await _wait_spin(player, "%s, spin for wedding gifts. Red is 50K from each player. Black is 100K." % player.display_name)
			var spin := _roll()
			_show_spin(spin)
			var gift := 50 if spin % 2 == 1 else 100
			_collect_from_others(player, gift)
			_log("%s spins %s and collects %dK from each player." % [player.display_name, _color_name(spin), gift])
			return true
		"baby":
			await _wait_spin(player, "%s, spin for babies. 1–3 none, 4–6 one, 7–8 twins, 9–10 triplets." % player.display_name)
			var spin := _roll()
			_show_spin(spin)
			var count := _babies_from_spin(spin)
			_add_babies(player, count, "%d from the spin" % count)
			return true
		"family", "risky", "fork":
			var labels := _branch_labels(space)
			_show_fork(space)
			var index := await _choose("%s, choose a path. Then spin again." % player.display_name, labels)
			_clear_fork()
			player.forced_index = index
			_log("%s takes the %s." % [player.display_name, labels[index]])
			return true
		"night":
			_charge(player, 100)
			_log("%s pays 100K for night school." % player.display_name)
			var offer: Dictionary = decks.draw("college")
			if offer.is_empty():
				return true
			var keep := await _choose_cards(
				"%s, night school offers a new career." % player.display_name,
				[offer],
				PackedStringArray(["Take %s" % offer["name"]]),
				PackedStringArray(["Keep %s" % (player.job_name if player.job_name != "" else "your job")])
			)
			if keep == 0:
				if player.job_name != "":
					decks.to_bottom("college" if player.took_college else "careers", {"name": player.job_name, "salary": player.salary})
				player.job_name = offer["name"]
				player.salary = int(offer["salary"])
				_log("%s is now a %s." % [player.display_name, player.job_name])
			else:
				decks.to_bottom("college", offer)
				_log("%s keeps %s." % [player.display_name, player.job_name])
			return true
		"retire":
			await _retire(player)
			return false
		_:
			return false


func _house_stop(player: Player) -> void:
	var options: PackedStringArray = PackedStringArray(["Buy"])
	if player.houses.size() > 0:
		options.append("Sell")
	options.append("Pass")
	var choice := await _choose("%s, buy a house, sell one, or pass." % player.display_name, options)
	var picked := options[choice]
	if picked == "Pass":
		_log("%s passes on housing." % player.display_name)
		return
	if picked == "Sell":
		var names: PackedStringArray = []
		var owned: Array[Dictionary] = []
		for house in player.houses:
			owned.append(house)
			names.append("%s (red %dK, black %dK)" % [house["name"], house["red"], house["black"]])
		var which := await _choose_cards("%s, choose a house to sell." % player.display_name, owned, names, PackedStringArray())
		var house: Dictionary = player.houses[which]
		player.houses.remove_at(which)
		await _wait_spin(player, "Spin to sell %s. Red %dK, black %dK." % [house["name"], house["red"], house["black"]])
		var spin := _roll()
		_show_spin(spin)
		var price := int(house["red"] if spin % 2 == 1 else house["black"])
		player.money += price
		decks.to_bottom("houses", house)
		_log("%s sells %s for %dK." % [player.display_name, house["name"], price])
		return
	var first: Dictionary = decks.draw("houses")
	var second: Dictionary = decks.draw("houses")
	var offer: PackedStringArray = []
	var cards: Array[Dictionary] = []
	if not first.is_empty():
		cards.append(first)
		offer.append("%s for %dK" % [first["name"], first["cost"]])
	if not second.is_empty():
		cards.append(second)
		offer.append("%s for %dK" % [second["name"], second["cost"]])
	if cards.is_empty():
		_log("No houses are left.")
		return
	var which := await _choose_cards("%s, choose a house to buy." % player.display_name, cards, offer, PackedStringArray(["Pass"]))
	if which >= cards.size():
		for card in cards:
			decks.to_bottom("houses", card)
		_log("%s passes on housing." % player.display_name)
		return
	var bought: Dictionary = cards[which]
	_charge(player, int(bought["cost"]))
	player.houses.append(bought)
	for index in cards.size():
		if index != which:
			decks.to_bottom("houses", cards[index])
	_log("%s buys %s for %dK." % [player.display_name, bought["name"], bought["cost"]])


func _spin_to_win(player: Player) -> void:
	var picks: Dictionary = {}
	var participants: Array[Player] = []
	for entry in seated:
		if not entry.retired:
			participants.append(entry)
	for entry in participants:
		var numbers := _number_choices()
		var first := await _choose("%s, place a Spin to Win token." % entry.display_name, numbers)
		picks[entry] = [first + 1]
	var second := await _choose("%s, place a second token." % player.display_name, _number_choices())
	var mine: Array = picks[player]
	mine.append(second + 1)
	picks[player] = mine
	var covered := {}
	for entry in participants:
		for number in picks[entry]:
			covered[number] = true
	var hit := 1
	for _attempt in 40:
		hit = _roll()
		if covered.has(hit):
			break
	_show_spin(hit)
	_log("Spin to Win hits %d." % hit)
	for entry in participants:
		if (picks[entry] as Array).has(hit):
			entry.money += 200
			_log("%s collects 200K." % entry.display_name)


func _retire(player: Player) -> void:
	var choice := await _choose(
		"%s, retire to Millionaire Mansion or Countryside Acres." % player.display_name,
		PackedStringArray(["Millionaire Mansion", "Countryside Acres"])
	)
	player.estate = "Millionaire Mansion" if choice == 0 else "Countryside Acres"
	player.retired = true
	var bonus: int = RETIRE_BONUS[mini(retire_count, RETIRE_BONUS.size() - 1)]
	retire_count += 1
	player.money += bonus
	_log("%s retires to %s and collects %dK." % [player.display_name, player.estate, bonus])


func _finale() -> void:
	for player in seated:
		current_player = player
		var pending: Array[Dictionary] = []
		pending.assign(player.houses)
		player.houses.clear()
		for house in pending:
			await _wait_spin(player, "Spin to sell %s. Red %dK, black %dK." % [house["name"], house["red"], house["black"]])
			var spin := _roll()
			_show_spin(spin)
			var price := int(house["red"] if spin % 2 == 1 else house["black"])
			player.money += price
			_log("%s sells %s for %dK." % [player.display_name, house["name"], price])
			_refresh()
	var lines: PackedStringArray = []
	var best := -1000000000
	var winners: PackedStringArray = []
	for player in seated:
		var action_bonus := player.actions.size() * 100
		var pet_bonus := player.pets.size() * 100
		var baby_bonus := player.babies * 50
		var loan_cost := player.loans * 60
		var total := player.money + action_bonus + pet_bonus + baby_bonus - loan_cost
		lines.append("%s  %dK" % [player.display_name, total])
		lines.append("%dK on hand + %dK actions + %dK pets + %dK babies - %dK loans" % [player.money, action_bonus, pet_bonus, baby_bonus, loan_cost])
		if total > best:
			best = total
			winners = PackedStringArray([player.display_name])
		elif total == best:
			winners.append(player.display_name)
	var headline := "%s wins with %dK." % [winners[0], best]
	if winners.size() > 1:
		headline = "%s tie with %dK." % [", ".join(winners), best]
	_log(headline)
	_refresh()
	await _choose(headline + "\n" + "\n".join(lines), PackedStringArray(["New game"]))
	get_tree().reload_current_scene()


func _pick_job(player: Player, pile: String, prompt: String) -> void:
	var first: Dictionary = decks.draw(pile)
	var second: Dictionary = decks.draw(pile)
	var cards: Array[Dictionary] = []
	var labels: PackedStringArray = []
	for card in [first, second]:
		if card.is_empty():
			continue
		cards.append(card)
		labels.append("%s, %dK" % [card["name"], card["salary"]])
	if cards.is_empty():
		return
	var index := await _choose_cards("%s, %s." % [player.display_name, prompt], cards, labels, PackedStringArray())
	var chosen: Dictionary = cards[index]
	player.job_name = chosen["name"]
	player.salary = int(chosen["salary"])
	for card_index in cards.size():
		if card_index != index:
			decks.to_bottom(pile, cards[card_index])
	_log("%s becomes %s for %dK." % [player.display_name, _job_title(player.job_name), player.salary])


func _draw_kept(player: Player, pile: String) -> void:
	var card: Dictionary = decks.draw(pile)
	if card.is_empty():
		_log("The deck is empty.")
		return
	_apply_card(player, card)
	if str(card["kind"]) == "pet":
		player.pets.append(card)
	else:
		player.actions.append(card)
	_log("%s keeps %s." % [player.display_name, card["name"]])
	ui.show_drawn(card)


func _apply_card(player: Player, card: Dictionary) -> void:
	var amount := int(card["amount"])
	if amount <= 0:
		return
	match str(card["effect"]):
		"bank":
			player.money += amount
			_log("%s collects %dK." % [player.display_name, amount])
		"charge":
			_charge(player, amount)
			_log("%s pays %dK." % [player.display_name, amount])
		"each":
			_collect_from_others(player, amount)
			_log("Each other player pays %s %dK." % [player.display_name, amount])
		"pay":
			_pay_each(player, amount)
			_log("%s pays each other player %dK." % [player.display_name, amount])


func _add_babies(player: Player, count: int, label: String) -> void:
	if count <= 0:
		_log("%s has no new babies." % player.display_name)
		return
	var added := player.add_people(count)
	if added < count:
		_log("The car is full. %s adds %d of %d (%s)." % [player.display_name, added, count, label])
	else:
		_log("%s adds %d (%s)." % [player.display_name, added, label])


func _charge(player: Player, amount: int) -> void:
	if amount <= 0:
		return
	if player.money < amount:
		var need := amount - player.money
		var count := int(ceil(float(need) / 50.0))
		player.loans += count
		player.money += count * 50
		_log("%s borrows %dK." % [player.display_name, count * 50])
	player.money -= amount


func _collect_from_others(receiver: Player, amount: int) -> void:
	for player in seated:
		if player == receiver:
			continue
		_charge(player, amount)
		receiver.money += amount


func _pay_each(payer: Player, amount: int) -> void:
	for player in seated:
		if player == payer:
			continue
		_charge(payer, amount)
		player.money += amount


func _wait_spin(player: Player, prompt: String) -> void:
	while true:
		var can_repay := player.loans > 0 and player.money >= 60
		ui.present(prompt, PackedStringArray(), true, can_repay)
		_refresh()
		await ui.acted
		if ui.last_action == "repay":
			player.money -= 60
			player.loans -= 1
			_log("%s repays a loan for 60K." % player.display_name)
			continue
		return


func _choose(prompt: String, options: PackedStringArray) -> int:
	ui.present(prompt, options, false, false)
	_refresh()
	await ui.acted
	return ui.last_index


func _choose_cards(prompt: String, cards: Array, labels: PackedStringArray, extra: PackedStringArray) -> int:
	ui.present_cards(prompt, cards, labels, extra)
	_refresh()
	await ui.acted
	return ui.last_index


func _roll() -> int:
	return randi_range(1, 10)


func _flick(final_value: int) -> void:
	ui.show_spin(final_value, not autoplay)
	if autoplay:
		return
	await get_tree().create_timer(0.72).timeout


func _show_spin(value: int) -> void:
	ui.show_spin(value, false)


func _job_title(job_name: String) -> String:
	if job_name.is_empty():
		return "a worker"
	var first := job_name.substr(0, 1).to_lower()
	var article := "an" if "aeiou".contains(first) else "a"
	return "%s %s" % [article, job_name]


func _color_name(value: int) -> String:
	return "red" if value % 2 == 1 else "black"


func _number_choices() -> PackedStringArray:
	var numbers := PackedStringArray()
	for number in range(1, 11):
		numbers.append(str(number))
	return numbers


func _approached_through_babies(space: Spaces) -> bool:
	var incoming := _incoming()
	var node := space
	var guard := 0
	while node and guard < 14:
		if node.space_type == Spaces.SpaceType.BOY or node.space_type == Spaces.SpaceType.GIRL or node.space_type == Spaces.SpaceType.TWINS:
			return true
		var prevs: Array = incoming.get(node.name, [])
		if prevs.size() != 1:
			return false
		node = prevs[0] as Spaces
		guard += 1
	return false


func _incoming() -> Dictionary:
	var links := {}
	for node in $Spaces.get_children():
		if not node is Spaces:
			continue
		var space := node as Spaces
		for path in space.next_spaces:
			var nxt := space.get_node(path) as Spaces
			if nxt == null:
				continue
			var prevs: Array = links.get(nxt.name, [])
			prevs.append(space)
			links[nxt.name] = prevs
	return links


func _babies_from_spin(value: int) -> int:
	if value <= 3:
		return 0
	if value <= 6:
		return 1
	if value <= 8:
		return 2
	return 3


func _stop_role(player: Player, space: Spaces) -> String:
	if space.space_type == Spaces.SpaceType.END:
		return "retire"
	if space.next_spaces.size() > 1:
		var labels := _branch_labels(space)
		if labels.has("Family path"):
			return "family"
		if labels.has("Risky road"):
			return "risky"
		return "fork"
	if _approached_through_babies(space):
		return "baby"
	if player.took_college and player.job_name == "":
		return "graduation"
	if not player.married:
		return "married"
	return "night"


func _branch_labels(space: Spaces) -> PackedStringArray:
	var kinds: PackedStringArray = []
	for index in space.next_spaces.size():
		kinds.append(_branch_kind(space, index))
	var labels: PackedStringArray = []
	for index in kinds.size():
		if kinds[index] != "":
			labels.append(kinds[index])
		elif kinds.has("Family path"):
			labels.append("Life path")
		elif kinds.has("Risky road"):
			labels.append("Safe route")
		else:
			var node := space.get_node(space.next_spaces[index]) as Spaces
			labels.append("Upper path" if node.global_position.y < space.global_position.y else "Lower path")
	var tally := {}
	for label in labels:
		tally[label] = int(tally.get(label, 0)) + 1
	for index in labels.size():
		if int(tally.get(labels[index], 0)) > 1:
			labels[index] = "%s %d" % [labels[index], index + 1]
	return labels


func _branch_kind(space: Spaces, index: int) -> String:
	var babies := false
	var wild := false
	for node in _exclusive_nodes(space, index):
		match node.space_type:
			Spaces.SpaceType.BOY, Spaces.SpaceType.GIRL, Spaces.SpaceType.TWINS:
				babies = true
			Spaces.SpaceType.DEBT, Spaces.SpaceType.BONUS:
				wild = true
	if babies:
		return "Family path"
	if wild:
		return "Risky road"
	return ""


func _exclusive_nodes(space: Spaces, index: int) -> Array[Spaces]:
	var other_reach := {}
	for other in space.next_spaces.size():
		if other == index:
			continue
		for key in _reach(space.get_node(space.next_spaces[other]) as Spaces):
			other_reach[key] = true
	var nodes: Array[Spaces] = []
	var node := space.get_node(space.next_spaces[index]) as Spaces
	var guard := 0
	while node and guard < 24:
		if other_reach.has(node.name):
			break
		nodes.append(node)
		if node.space_type == Spaces.SpaceType.END or node.next_spaces.size() != 1:
			break
		node = node.get_node(node.next_spaces[0]) as Spaces
		guard += 1
	return nodes


func _prepare_paths() -> void:
	var first := start_space.get_node(start_space.next_spaces[0]) as Spaces
	var second := start_space.get_node(start_space.next_spaces[1]) as Spaces
	var shared := {}
	var reach_first := _reach(first)
	var reach_second := _reach(second)
	for key in reach_first:
		if reach_second.has(key):
			shared[key] = true
	if _stop_before_shared(first, shared):
		college_entry = first.name
		career_entry = second.name
	else:
		college_entry = second.name
		career_entry = first.name


func _stop_before_shared(entry: Spaces, shared: Dictionary) -> bool:
	var node := entry
	var guard := 0
	while node and guard < 80:
		if shared.has(node.name):
			return false
		if node.space_type == Spaces.SpaceType.STOP:
			return true
		if node.space_type == Spaces.SpaceType.END or node.next_spaces.size() != 1:
			return false
		node = node.get_node(node.next_spaces[0]) as Spaces
		guard += 1
	return false


func _reach(start: Spaces) -> Dictionary:
	var seen := {}
	if start == null:
		return seen
	var stack: Array[Spaces] = [start]
	var guard := 0
	while stack.size() > 0 and guard < 500:
		guard += 1
		var node: Spaces = stack.pop_back()
		if seen.has(node.name):
			continue
		seen[node.name] = true
		if node.space_type == Spaces.SpaceType.END:
			continue
		for path in node.next_spaces:
			var nxt := node.get_node(path) as Spaces
			if nxt:
				stack.append(nxt)
	return seen


func _index_named(space: Spaces, entry_name: String) -> int:
	for index in space.next_spaces.size():
		if space.get_node(space.next_spaces[index]).name == entry_name:
			return index
	return 0


func _scene_players() -> Array[Player]:
	var found: Array[Player] = []
	for node in get_tree().get_nodes_in_group("players"):
		if node is Player:
			found.append(node)
	found.sort_custom(func(a: Player, b: Player) -> bool: return a.get_index() < b.get_index())
	return found


func _ensure_fourth_player() -> void:
	if _scene_players().size() >= 4:
		return
	var peg := preload("res://Scenes/player.tscn").instantiate() as Player
	peg.texture = preload("res://Assets/kenney_boardgame-pack/Spritesheets/piecesPurple.png")
	peg.name = "player4"
	add_child(peg)
	peg.add_to_group("players")


func _seat_on(player: Player, space: Spaces) -> void:
	player.space = space
	player.global_position = _peg_position(player, space)


func _peg_position(player: Player, space: Spaces) -> Vector2:
	var offsets: Array[Vector2] = [Vector2(-14, -8), Vector2(14, -8), Vector2(-14, 12), Vector2(14, 12)]
	var index := seated.find(player)
	if index < 0:
		index = _scene_players().find(player)
	if index < 0:
		index = 0
	return space.global_position + offsets[index % offsets.size()]


func _advance() -> void:
	if seated.is_empty():
		return
	turn = (turn + 1) % seated.size()


func _all_retired() -> bool:
	if seated.is_empty():
		return false
	for player in seated:
		if not player.retired:
			return false
	return true


func _refresh() -> void:
	for player in seated:
		var previous: int = int(last_money.get(player, player.money))
		var delta := player.money - previous
		player.modulate = Color(0.75, 0.75, 0.75) if player.retired else Color.WHITE
		if playing and delta != 0 and not autoplay:
			_popup(player, delta)
			if board:
				var spark := Color(0.95, 0.78, 0.32) if delta > 0 else Color(0.90, 0.36, 0.30)
				board.burst(player.global_position, spark)
		last_money[player] = player.money
	ui.refresh(seated, current_player)


func _popup(player: Player, delta: int) -> void:
	var screen: Vector2 = get_viewport().get_canvas_transform() * player.global_position
	var text := "+%dK" % delta if delta > 0 else "%dK" % delta
	var color := Color(0.55, 0.84, 0.62) if delta > 0 else Color(0.92, 0.46, 0.4)
	ui.popup(screen, text, color)


func _show_fork(space: Spaces) -> void:
	if ring == null:
		return
	var points: Array[Vector2] = []
	for path in space.next_spaces:
		var node := space.get_node(path) as Spaces
		if node:
			points.append(node.global_position)
	ring.set_marks(points)


func _clear_fork() -> void:
	if ring:
		var empty: Array[Vector2] = []
		ring.set_marks(empty)


func _log(line: String) -> void:
	ui.add_log(line)
	if autoplay:
		print(line)


func _auto_answer() -> void:
	prompts += 1
	if prompts > 2500:
		_fail("too many decisions")
		return
	if prompts % 200 == 0 and current_player:
		var where: String = current_player.space.name if current_player.space else "?"
		print("PROGRESS ", prompts, " ", current_player.display_name, " ", where)
	var buttons: Array[String] = []
	for caption in ui.choice_texts():
		buttons.append(caption)
	if buttons.is_empty() and not ui.spin_button.visible:
		return
	var prompt := str(ui.prompt_label.text)
	if "wins with" in prompt or "tie with" in prompt:
		print("RESULT")
		for line in prompt.split("\n"):
			print(line)
		get_tree().quit(0)
		return
	if buttons.is_empty() and ui.repay_button.visible and current_player and not did_repay.has(current_player):
		did_repay[current_player] = true
		ui._emit("repay", -1)
		return
	if buttons.is_empty():
		ui._emit("spin", -1)
		return
	ui._emit("choice", _policy(prompt, buttons))


func _policy(prompt: String, buttons: Array[String]) -> int:
	var lower := prompt.to_lower()
	if "college or career" in lower:
		return 0 if seated.is_empty() or current_player == seated[0] else 1
	if _has_button(buttons, "Family path"):
		return _button_index(buttons, "Family path") if current_player == seated[0] else _button_index(buttons, "Life path")
	if _has_button(buttons, "Risky road"):
		return _button_index(buttons, "Risky road") if current_player == seated[0] else _button_index(buttons, "Safe route")
	if _has_button(buttons, "Upper path") or _has_button(buttons, "Lower path"):
		return 0
	if "buy a house" in lower:
		if current_player and current_player.houses.size() > 0 and not sold_once:
			sold_once = true
			return _button_index(buttons, "Sell")
		if current_player and current_player.houses.is_empty():
			return _button_index(buttons, "Buy")
		return _button_index(buttons, "Pass")
	if "night school" in lower:
		return 0
	if "millionaire" in lower or "countryside" in lower:
		return 0
	if "second token" in lower:
		return mini(4, buttons.size() - 1)
	if "token" in lower:
		return mini(2, buttons.size() - 1)
	return 0


func _has_button(buttons: Array[String], needle: String) -> bool:
	for label in buttons:
		if needle.to_lower() in label.to_lower():
			return true
	return false


func _button_index(buttons: Array[String], needle: String) -> int:
	for index in buttons.size():
		if needle.to_lower() in buttons[index].to_lower():
			return index
	return 0


func _fail(reason: String) -> void:
	var who := current_player.display_name if current_player else "?"
	var where: String = current_player.space.name if current_player and current_player.space else "?"
	print("AUTOPLAY_FAIL ", reason, " ", who, " ", where)
	get_tree().quit(1)
