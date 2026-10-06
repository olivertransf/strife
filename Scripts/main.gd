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
	hud.acted.connect(_on_acted)
	camera = $Camera3D
	_spawn_players(all_ai)
	rules.setup(table, RulesScript.load_decks(), 4, 1 if capture else randi(), true, PackedStringArray(NAMES))
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
	mat.albedo_color = Color(0.05, 0.22, 0.14)
	mat.roughness = 0.9
	table.set_surface_override_material(0, mat)


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
	for ev in events:
		match str(ev.get("kind", "")):
			"spin":
				board.set_spin(int(ev.value))
				hud.set_spin_text(int(ev.value), bool(ev.red))
				await get_tree().create_timer(pace).timeout
			"enter", "park":
				await _move_car(int(ev.player), str(ev.space))
				camera.shot("follow", seats[int(ev.player)].global_position, board.span)
			"card", "deal", "career":
				_show_event_card(ev)
				camera.shot("card", seats[int(ev.player)].global_position, board.span)
				await get_tree().create_timer(pace * 2.0).timeout
			"house":
				_show_event_card(ev)
				await get_tree().create_timer(pace).timeout
			"winners":
				hud.show_scores(rules.snapshot())
				camera.shot("score", board.center, board.span)
		_refresh_pegs()
	_refresh()
	_aim_for_phase()


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
	hud.show_card(title, body, value, tint)


func _aim_for_phase() -> void:
	if rules.phase == "choose_fork":
		camera.shot("fork", seats[rules.turn].global_position, board.span)
	elif rules.phase == "wheel_pick":
		camera.shot("wheel", board.wheel_position, board.span)
	elif rules.phase == "game_over":
		hud.show_scores(rules.snapshot())
		camera.shot("score", board.center, board.span)


func _move_car(index: int, space_name: String) -> void:
	var car: Player = seats[index]
	var target = board.marker_position(space_name) + _slot(index)
	target.y = 0.08
	var delta = target - car.global_position
	delta.y = 0
	if delta.length() > 0.05:
		var turn := create_tween()
		turn.tween_property(car, "rotation:y", atan2(delta.x, delta.z), pace * 0.6)
		await turn.finished
	var slide := create_tween()
	slide.tween_property(car, "global_position", target, pace).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await slide.finished


func _place_all(animate: bool) -> void:
	for i in seats.size():
		var space_name := str(rules.players[i].space)
		var target = board.marker_position(space_name) + _slot(i)
		target.y = 0.08
		if animate:
			seats[i].global_position = seats[i].global_position
		seats[i].global_position = target
	_refresh_pegs()


func _refresh() -> void:
	var snap: Dictionary = rules.snapshot()
	var info: Dictionary = rules.prompt()
	var turn_name := str(snap.players[rules.turn].name)
	if rules.phase == "wheel_pick":
		turn_name = str(snap.players[int(info.get("picker", rules.turn))].name)
	hud.show_status(snap.players, turn_name, str(info.get("title", "")))
	if not busy:
		hud.show_prompt(info)
	_refresh_pegs()


func _refresh_pegs() -> void:
	for i in seats.size():
		var row: Dictionary = rules.players[i]
		var people := 1 + int(row.babies) + (1 if bool(row.spouse) else 0)
		var pets := 1 + int(row.pets.size())
		seats[i].set_pegs(people, pets)


func _slot(index: int) -> Vector3:
	return Vector3(-1.15 + (index % 2) * 2.3, 0, -0.85 + float(index / 2) * 1.7)


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
