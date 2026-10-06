extends Node3D

const LifeTests = preload("res://Scripts/life/life_tests.gd")
const RulesScript = preload("res://Scripts/life/life_rules.gd")
const Policy = preload("res://Scripts/life/life_policy.gd")

const CAR_COLORS := [
	Color(0.86, 0.28, 0.28),
	Color(0.25, 0.48, 0.9),
	Color(0.28, 0.7, 0.42),
	Color(0.92, 0.72, 0.28),
]
const NAMES := ["Alex", "Blair", "Casey", "Drew"]

@export var game_spaces: Array[Node]

var rules = RulesScript.new()
var seats: Array[Player] = []
var board
var hud
var camera
var busy := false
var pace := 0.22
var capture := false
var audio
var _route: Array = []
var _trailed := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--rules" in args or "--sim" in args:
		_run_headless(args)
		return
	_boot(args)


func _run_headless(args: PackedStringArray) -> void:
	var err := ""
	if "--rules" in args:
		err = LifeTests.run($Spaces)
	else:
		err = LifeTests.run_sim(_arg_int(args, "--games", 30), _arg_int(args, "--seed", 1))
	if err == "":
		print("RESULT ok")
	else:
		print("RESULT fail %s" % err)
	await get_tree().process_frame
	get_tree().quit(0 if err == "" else 1)


func _boot(args: PackedStringArray) -> void:
	capture = "--capture" in args
	var all_ai := capture or "--ai" in args
	_hide_legacy()
	_felt()
	var table: Dictionary = RulesScript.load_board()
	RulesScript.apply_spaces($Spaces, table)
	board = preload("res://Scripts/board_view.gd").new()
	board.name = "BoardView"
	add_child(board)
	board.build($Spaces, table)
	hud = preload("res://Scripts/hud.gd").new()
	add_child(hud)
	hud.instant = capture
	hud.acted.connect(_on_acted)
	_stage()
	if not capture:
		audio = preload("res://Scripts/life/life_audio.gd").new()
		add_child(audio)
		audio.setup()
	camera = $Camera3D
	_spawn_players(all_ai)
	rules.setup(table, RulesScript.load_decks(), 4, 1 if capture else randi(), true, PackedStringArray(NAMES))
	hud.you_rules_name = "" if all_ai else NAMES[0]
	_place_all(false)
	_refresh()
	camera.shot("overview", board.center, board.span)
	camera.snap()
	if capture:
		_capture()
		return
	_pump()


func _hide_legacy() -> void:
	for node_name in ["Control", "spin_number", "Timer"]:
		var node := get_node_or_null(node_name)
		if node is CanvasItem:
			node.hide()
	var photo := get_node_or_null("Board")
	if photo:
		photo.hide()


func _felt() -> void:
	var table := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if table == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.07, 0.32, 0.18)
	mat.roughness = 0.92
	table.set_surface_override_material(0, mat)


func _stage() -> void:
	var key := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if key:
		key.light_color = Color(1.0, 0.93, 0.8)
		key.light_energy = 1.2
		key.shadow_enabled = true
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.62, 0.72, 0.9)
	fill.light_energy = 0.38
	fill.rotation_degrees = Vector3(-28, 40, 0)
	add_child(fill)
	var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world and world.environment:
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color(0.12, 0.09, 0.07)
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color(0.42, 0.36, 0.28)
		world.environment.ambient_light_energy = 0.45
	var wood := MeshInstance3D.new()
	wood.name = "WoodRim"
	var slab := BoxMesh.new()
	slab.size = Vector3(46, 0.35, 42)
	wood.mesh = slab
	wood.position = Vector3(0, -0.62, 0)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.28, 0.16, 0.08)
	bark.roughness = 0.72
	wood.material_override = bark
	add_child(wood)


func _spawn_players(all_ai: bool) -> void:
	var folder := $players
	var packed := load("res://Scenes/player.tscn")
	while folder.get_child_count() < 4:
		var extra = packed.instantiate()
		extra.name = "player%d" % (folder.get_child_count() + 1)
		folder.add_child(extra)
	seats.clear()
	for i in folder.get_child_count():
		var car := folder.get_child(i) as Player
		if car == null:
			continue
		if seats.size() >= 4:
			car.hide()
			continue
		car.setup_view(seats.size(), CAR_COLORS[seats.size()], NAMES[seats.size()])
		car.ai = all_ai or seats.size() > 0
		if not car.ai:
			car.display_name = "You"
			car.get_node("NameLabel").text = "You"
		seats.append(car)


func _pump() -> void:
	while not rules.game_over:
		var actor := _actor_index()
		if not seats[actor].ai:
			_refresh()
			hud.show_prompt(rules.prompt())
			return
		busy = true
		var events: Array = rules.act(Policy.choose(rules))
		await _play(events)
		busy = false
	hud.show_scores(rules.snapshot())
	camera.shot("score", board.center, board.span)


func _on_acted(action: Dictionary) -> void:
	if busy or rules.game_over:
		return
	var actor := _actor_index()
	if seats[actor].ai:
		return
	busy = true
	var events: Array = rules.act(action)
	await _play(events)
	busy = false
	_pump()


func _play(events: Array) -> void:
	hud.hide_card()
	hud.hide_choices()
	_route.clear()
	_trailed = false
	for ev in events:
		var kind := str(ev.get("kind", ""))
		if kind == "enter" or kind == "park":
			_route.append(str(ev.get("space", "")))
	for ev in events:
		await _present(ev)
		_sync()
	board.clear_preview()
	_refresh()
	await _aim_for_phase()


func _show_event_card(ev: Dictionary) -> void:
	var title := str(ev.get("title", ""))
	var body := str(ev.get("text", ""))
	var value := ""
	if ev.get("cards") is Array and not ev.cards.is_empty():
		var dealt: Dictionary = ev.cards[0]
		title = str(dealt.get("title", title))
		body = str(dealt.get("text", body))
		if int(dealt.get("salary", 0)) > 0:
			value = "%dK" % int(dealt.salary)
		elif int(dealt.get("price", 0)) > 0:
			value = "%dK" % int(dealt.price)
	elif int(ev.get("salary", 0)) > 0:
		value = "%dK" % int(ev.salary)
	elif int(ev.get("price", 0)) > 0:
		value = "%dK" % int(ev.price)
	var tint := Color(0.93, 0.76, 0.32)
	if ev.get("cards") is Array and ev.cards.size() >= 2:
		hud.show_deal(ev.cards, tint)
		return
	hud.show_card(title, body, value, tint)


func _present(ev: Dictionary) -> void:
	var kind := str(ev.get("kind", ""))
	var who := _who(ev)
	match kind:
		"spin":
			var red := bool(ev.red)
			board.set_spin(int(ev.value))
			_sfx("spin")
			hud.banner("%s spins" % who, "%d    %s" % [int(ev.value), "Red" if red else "Black"], Color(0.92, 0.34, 0.32) if red else Color(0.82, 0.82, 0.88))
			await board.preview(_route)
		"enter":
			await _travel(int(ev.player), str(ev.space), false)
		"park":
			await _travel(int(ev.player), str(ev.space), true)
			_float_at(int(ev.player), "+%dK" % int(ev.get("bonus", 0)), Color(0.98, 0.84, 0.38))
			hud.banner(str(ev.get("park", "Retirement")), "Bonus  +%dK" % int(ev.get("bonus", 0)), Color(0.98, 0.84, 0.38))
			_sfx("cheer")
			await get_tree().create_timer(0.95).timeout
		"payday":
			var salary := int(ev.get("salary", 0))
			var bonus := int(ev.get("bonus", 0))
			var landed := bool(ev.get("landed", false))
			if salary > 0:
				_float_at(int(ev.player), "+%dK" % salary, Color(0.45, 0.9, 0.5))
			if bonus > 0:
				_float_at(int(ev.player), "+%dK" % bonus, Color(0.98, 0.84, 0.38))
			_sfx("coin")
			if landed:
				var line := "+%dK salary" % salary
				if bonus > 0:
					line += "    +%dK for landing" % bonus
				if salary == 0 and bonus == 0:
					line = "No salary yet"
				hud.banner("Payday", line, Color(0.42, 0.86, 0.48))
				await get_tree().create_timer(0.55).timeout
			else:
				await get_tree().create_timer(0.12).timeout
		"cash":
			if str(ev.get("reason", "")) in ["payday", "payday bonus", "wedding gifts", "wheel", "retirement", "sold a house"]:
				return
			var delta := int(ev.get("delta", 0))
			var sign := "+" if delta > 0 else ""
			_float_at(int(ev.player), "%s%dK" % [sign, delta], Color(0.45, 0.9, 0.5) if delta > 0 else Color(0.95, 0.42, 0.38))
			_sfx("coin" if delta > 0 else "loan")
			hud.banner(str(ev.get("reason", "Cash")).capitalize(), "%s%dK" % [sign, delta], Color(0.42, 0.86, 0.48) if delta > 0 else Color(0.92, 0.38, 0.34))
			await get_tree().create_timer(0.38).timeout
		"loan":
			_float_at(int(ev.player), "+50K", Color(0.95, 0.42, 0.38))
			hud.banner("Bank loan", "%s borrows 50K" % who, Color(0.92, 0.38, 0.34))
			_sfx("loan")
			await get_tree().create_timer(0.5).timeout
		"repay":
			_float_at(int(ev.player), "-60K", Color(0.45, 0.9, 0.5))
			hud.banner("Loan repaid", "%s pays 60K" % who, Color(0.42, 0.86, 0.48))
			_sfx("coin")
			await get_tree().create_timer(0.5).timeout
		"card", "deal", "career", "house":
			_show_event_card(ev)
			_banner_for_card(kind, ev, who)
			if kind == "house" and not bool(ev.get("bought", true)):
				_float_at(int(ev.player), "+%dK" % int(ev.get("gain", 0)), Color(0.45, 0.9, 0.5))
			_sfx("card")
			camera.shot("card", seats[int(ev.get("player", rules.turn))].global_position, board.span)
			await get_tree().create_timer(1.05).timeout
		"married":
			_float_at(int(ev.player), "+%dK" % int(ev.get("gift", 0)), Color(0.95, 0.55, 0.72))
			hud.banner("Just married", "Wedding gifts  +%dK" % int(ev.get("gift", 0)), Color(0.95, 0.55, 0.72))
			_sfx("cheer")
			await get_tree().create_timer(0.8).timeout
		"baby_spin":
			hud.banner(_baby_word(int(ev.get("count", 0))), "Spin %d" % int(ev.get("spin", 0)), Color(0.95, 0.55, 0.72))
			_sfx("stop")
			await get_tree().create_timer(0.75).timeout
		"babies":
			hud.banner(_baby_word(int(ev.get("count", 0))), who, Color(0.62, 0.78, 0.98))
			await get_tree().create_timer(0.45).timeout
		"spin_again":
			hud.banner("Stop", "%s spins again" % who, Color(0.92, 0.38, 0.34))
			_sfx("stop")
			await get_tree().create_timer(0.45).timeout
		"path":
			hud.banner("College" if bool(ev.get("college", false)) else "Career", who, Color(0.98, 0.84, 0.38))
			await get_tree().create_timer(0.4).timeout
		"fork":
			hud.banner(str(ev.get("label", "New road")), "%s takes that road" % who, Color(0.98, 0.84, 0.38))
			await get_tree().create_timer(0.45).timeout
		"wheel_pick":
			board.light_number(int(ev.get("number", 1)))
			_sfx("spin")
			await get_tree().create_timer(0.18).timeout
		"wheel":
			board.set_spin(int(ev.get("spin", 1)))
			hud.banner("Wheel hits %d" % int(ev.get("spin", 0)), _wheel_line(ev), Color(0.72, 0.55, 0.95))
			for winner in ev.get("winners", []):
				_float_at(int(winner), "+200K", Color(0.72, 0.55, 0.95))
			_sfx("cheer")
			camera.shot("wheel", board.wheel_position, board.span)
			await get_tree().create_timer(0.95).timeout
		"turn":
			var line := "Your turn" if who == "You" else "%s's turn" % who
			hud.banner(line, "Spin and move", Color(0.98, 0.84, 0.38))
			await get_tree().create_timer(0.28).timeout
		"score":
			hud.banner("%s  %dK" % [who, int(ev.get("total", 0))], "Houses, cards, babies, and loans", Color(0.98, 0.84, 0.38))
			_sfx("coin")
			await get_tree().create_timer(0.42).timeout
		"winners":
			hud.show_scores(rules.snapshot())
			camera.shot("score", board.center, board.span)
			_sfx("cheer")
			await get_tree().create_timer(0.7).timeout
		"pass":
			hud.banner("Walk on", who, Color(0.78, 0.76, 0.7))
			await get_tree().create_timer(0.28).timeout


func _banner_for_card(kind: String, ev: Dictionary, who: String) -> void:
	var title := str(ev.get("title", ""))
	if kind == "house":
		var bought := bool(ev.get("bought", false))
		var line := title
		if not bought:
			var color_name := "Red" if bool(ev.get("red", false)) else "Black"
			line = "%s    %s  +%dK" % [title, color_name, int(ev.get("gain", 0))]
		hud.banner("Bought a house" if bought else "Sold a house", line, Color(0.86, 0.7, 0.45))
		return
	if kind == "career":
		hud.banner("New job", "%s    %s" % [title, who], Color(0.98, 0.84, 0.38))
		return
	if kind == "deal":
		hud.banner("Draw", "Keep one. The other goes back.", Color(0.98, 0.84, 0.38))
		return
	var deck := "Pet" if str(ev.get("deck", "")) == "pet" else "Action"
	hud.banner(deck, title, Color(0.95, 0.62, 0.28) if deck == "Pet" else Color(0.95, 0.82, 0.28))


func _baby_word(count: int) -> String:
	match count:
		0:
			return "No baby"
		1:
			return "One baby"
		2:
			return "Twins"
		_:
			return "Triplets"


func _wheel_line(ev: Dictionary) -> String:
	var names: PackedStringArray = []
	for winner in ev.get("winners", []):
		var index := int(winner)
		if index >= 0 and index < seats.size():
			names.append(seats[index].display_name)
	if names.is_empty():
		return "Nobody collected"
	return "200K for " + ", ".join(names)


func _who(ev: Dictionary) -> String:
	if not ev.has("player"):
		return ""
	var index := int(ev.player)
	if index < 0 or index >= seats.size():
		return ""
	return seats[index].display_name


func _aim_for_phase() -> void:
	var info: Dictionary = rules.prompt()
	if rules.phase == "choose_fork":
		hud.banner(str(info.get("title", "Choose")), str(info.get("detail", "")), Color(0.98, 0.84, 0.38))
		camera.shot("fork", seats[rules.turn].global_position, board.span)
		await get_tree().create_timer(0.25).timeout
	elif rules.phase == "wheel_pick":
		hud.lit_numbers = _picked_numbers()
		hud.banner(str(info.get("title", "Pick a number")), str(info.get("detail", "")), Color(0.72, 0.55, 0.95))
		camera.shot("wheel", board.wheel_position, board.span)
	elif rules.phase == "choose_house" or rules.phase == "choose_card":
		hud.banner(str(info.get("title", "")), str(info.get("detail", "")), Color(0.98, 0.84, 0.38))
		camera.shot("card", seats[rules.turn].global_position, board.span)
	elif rules.phase == "game_over":
		hud.show_scores(rules.snapshot())
		camera.shot("score", board.center, board.span)


func _travel(index: int, space_name: String, lift: bool) -> void:
	board.focus(space_name)
	var car: Player = seats[index]
	if not _trailed:
		camera.shot("follow", car.global_position, board.span)
		_trailed = true
	if lift:
		await _lift_car(car, space_name)
	else:
		await _move_car(index, space_name)
	board.dim(space_name)
	camera.follow(car.global_position)


func _lift_car(car: Player, space_name: String) -> void:
	var up := car.global_position
	up.y += 1.5
	var rise := create_tween()
	rise.tween_property(car, "global_position", up, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await rise.finished
	var target = _stand(seats.find(car), space_name)
	camera.shot("follow", target, board.span)
	await get_tree().create_timer(0.2).timeout
	car.global_position = target + Vector3(0, 1.3, 0)
	var ahead: Vector3 = board.next_direction(space_name)
	if ahead.length() > 0.05:
		car.rotation.y = atan2(ahead.x, ahead.z)
	var drop := create_tween()
	drop.tween_property(car, "global_position", target, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await drop.finished


func _move_car(index: int, space_name: String) -> void:
	var car: Player = seats[index]
	var target = _stand(index, space_name)
	var delta = target - car.global_position
	delta.y = 0
	var duration := clampf(delta.length() / 7.5, 0.28, 0.48)
	car.drive(true)
	_sfx("hop")
	if delta.length() > 0.08:
		var face := create_tween()
		face.tween_property(car, "rotation:y", _yaw_near(car.rotation.y, atan2(delta.x, delta.z)), minf(0.16, duration))
	var mid = car.global_position.lerp(target, 0.5)
	mid.y = target.y + 0.16
	var motion := create_tween()
	motion.tween_property(car, "global_position", mid, duration * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	motion.tween_property(car, "global_position", target, duration * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await motion.finished
	car.drive(false)


func _place_all(_animate: bool) -> void:
	for i in seats.size():
		var space_name := str(rules.players[i].space)
		seats[i].global_position = _stand(i, space_name)
		var ahead: Vector3 = board.next_direction(space_name)
		if ahead.length() > 0.05:
			seats[i].rotation.y = atan2(ahead.x, ahead.z)
	_refresh_pegs()


func _stand(index: int, space_name: String) -> Vector3:
	var target = board.marker_position(space_name) + _share_offset(index, space_name)
	target.y = 0.045
	return target


func _share_offset(index: int, space_name: String) -> Vector3:
	var mates: Array[int] = []
	for i in seats.size():
		if str(rules.players[i].space) == space_name:
			mates.append(i)
	if mates.size() <= 1:
		return Vector3.ZERO
	var rank := mates.find(index)
	var angle := TAU * float(rank) / float(mates.size())
	return Vector3(cos(angle), 0, sin(angle)) * 0.26


func _yaw_near(current: float, aim: float) -> float:
	return current + wrapf(aim - current, -PI, PI)


func _sync() -> void:
	var snap: Dictionary = rules.snapshot()
	var actor := _actor_index()
	hud.show_status(snap.players, str(snap.players[actor].name), "")
	_mark_actor(actor)
	_refresh_pegs()
	board.focus(str(rules.players[actor].space))


func _refresh() -> void:
	var snap: Dictionary = rules.snapshot()
	var info: Dictionary = rules.prompt()
	var turn_name := str(snap.players[rules.turn].name)
	if rules.phase == "wheel_pick":
		turn_name = str(snap.players[int(info.get("picker", rules.turn))].name)
		hud.lit_numbers = _picked_numbers()
	else:
		hud.lit_numbers = []
	hud.show_status(snap.players, turn_name, str(info.get("title", "")))
	_mark_actor(int(info.get("picker", rules.turn)) if rules.phase == "wheel_pick" else int(rules.turn))
	if not busy:
		hud.show_prompt(info)
	_refresh_pegs()


func _refresh_pegs() -> void:
	for i in seats.size():
		var row: Dictionary = rules.players[i]
		var people := 1 + int(row.babies) + (1 if bool(row.spouse) else 0)
		var pets := 1 + int(row.pets.size())
		seats[i].set_pegs(people, pets)


func _mark_actor(index: int) -> void:
	for i in seats.size():
		seats[i].set_active(i == index)


func _picked_numbers() -> Array:
	var taken: Array = []
	var picks = rules.pending.get("picks", {})
	if picks is Dictionary:
		for key in picks.keys():
			taken.append(int(picks[key]))
	return taken


func _float_at(index: int, text: String, tint: Color) -> void:
	if index < 0 or index >= seats.size():
		return
	board.float_money(seats[index].global_position, text, tint)


func _sfx(clip_name: String) -> void:
	if audio:
		audio.play(clip_name)


func _actor_index() -> int:
	if rules.phase == "wheel_pick":
		return int(rules._wheel_picker())
	return int(rules.turn)


func _capture() -> void:
	pace = 0.05
	await _frame_shot("opening")
	var got := {"card": false, "move": false, "wheel": false, "fork": false}
	var steps := 0
	while steps < 500 and not rules.game_over and not (got.card and got.move and got.wheel and got.fork):
		steps += 1
		if rules.phase == "choose_fork" and not bool(got.fork):
			hud.hide_card()
			hud.show_prompt(rules.prompt())
			camera.shot("fork", seats[rules.turn].global_position, board.span)
			camera.snap()
			await _frame_shot("fork")
			got.fork = true
		if rules.phase == "wheel_pick" and not bool(got.wheel):
			hud.hide_card()
			hud.show_prompt(rules.prompt())
			camera.set_process(false)
			camera.shot("wheel", board.wheel_position, board.span)
			camera.snap()
			await _frame_shot("wheel")
			camera.set_process(true)
			got.wheel = true
		var events: Array = rules.act(Policy.choose(rules))
		_place_all(false)
		_refresh()
		for ev in events:
			var kind := str(ev.get("kind", ""))
			if kind == "spin":
				board.set_spin(int(ev.value))
				hud.set_spin_text(int(ev.value), bool(ev.red))
			if (kind == "card" or kind == "career" or kind == "deal") and not bool(got.card):
				_show_event_card(ev)
				_banner_for_card(kind, ev, _who(ev))
				camera.shot("card", seats[int(ev.get("player", 0))].global_position, board.span)
				camera.snap()
				await _frame_shot("card")
				got.card = true
			if kind == "enter" and not bool(got.move):
				hud.hide_card()
				camera.shot("follow", seats[int(ev.player)].global_position, board.span)
				camera.snap()
				await _frame_shot("move")
				got.move = true
	while not rules.game_over and steps < 900:
		steps += 1
		rules.act(Policy.choose(rules))
	_place_all(false)
	var final_snap: Dictionary = rules.snapshot()
	hud.hide_card()
	var leader := ""
	if final_snap.winners.size() > 0:
		leader = str(final_snap.winners[0])
	hud.show_status(final_snap.players, leader, "Final tally")
	hud.show_scores(final_snap)
	camera.set_process(false)
	camera.shot("score", board.center, board.span)
	camera.snap()
	await _frame_shot("scoreboard")
	camera.set_process(true)
	var missing: PackedStringArray = []
	for shot_name in ["opening", "move", "card", "wheel", "fork", "scoreboard"]:
		var path := ProjectSettings.globalize_path("res://artifacts/captures/%s.png" % shot_name)
		if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).size() < 1000:
			missing.append(shot_name)
	if missing.is_empty() and rules.game_over:
		print("RESULT ok")
		get_tree().quit(0)
	else:
		print("RESULT fail capture %s over=%s" % [",".join(missing), str(rules.game_over)])
		get_tree().quit(1)


func _frame_shot(shot_name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://artifacts/captures/%s.png" % shot_name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)


func _arg_int(args: PackedStringArray, flag: String, fallback: int) -> int:
	var index := args.find(flag)
	if index >= 0 and index + 1 < args.size():
		return int(args[index + 1])
	return fallback
