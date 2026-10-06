extends CanvasLayer
class_name StrifeUI

signal acted
signal presented

var last_action := ""
var last_index := -1
var setup_names: PackedStringArray = PackedStringArray()
var player_count := 3
var accepting := false

@onready var prompt_label: Label = $Root/Panel/Margin/VBox/Prompt
@onready var readout: Label = $Root/Panel/Margin/VBox/Readout
@onready var choices: VBoxContainer = $Root/Panel/Margin/VBox/Choices
@onready var spin_button: Button = $Root/Panel/Margin/VBox/Row/Spin
@onready var repay_button: Button = $Root/Panel/Margin/VBox/Row/Repay
@onready var players_box: VBoxContainer = $Root/Panel/Margin/VBox/Players
@onready var log_label: RichTextLabel = $Root/Panel/Margin/VBox/Log
@onready var setup: Control = $Root/Setup
@onready var name_edits: Array[LineEdit] = [
	$Root/Setup/Card/VBox/Names/Name1,
	$Root/Setup/Card/VBox/Names/Name2,
	$Root/Setup/Card/VBox/Names/Name3,
	$Root/Setup/Card/VBox/Names/Name4,
]
@onready var count_buttons: Array[Button] = [
	$Root/Setup/Card/VBox/Counts/Two,
	$Root/Setup/Card/VBox/Counts/Three,
	$Root/Setup/Card/VBox/Counts/Four,
]

var _cream := Color(0.965, 0.929, 0.847)
var _ink := Color(0.11, 0.09, 0.07, 0.96)
var _sage := Color(0.24, 0.46, 0.36)
var _gold := Color(0.72, 0.52, 0.22)
var spinner
var card_stage: HBoxContainer
const CardFace := preload("res://Scripts/life_card.gd")


func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Sans-Serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	$Root.theme = theme
	_style_tray($Root/Panel)
	_style_panel($Root/Setup, Color(0.05, 0.03, 0.02, 0.55))
	_style_card($Root/Setup/Card)
	var title := $Root/Panel/Margin/VBox/Title as Label
	title.add_theme_color_override("font_color", Color(0.96, 0.88, 0.66))
	title.add_theme_font_size_override("font_size", 34)
	for node in [prompt_label, readout, $Root/Setup/Card/VBox/Heading, $Root/Setup/Card/VBox/Blurb]:
		(node as Label).add_theme_color_override("font_color", _cream)
	prompt_label.add_theme_font_size_override("font_size", 18)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout.add_theme_font_size_override("font_size", 26)
	_style_button(spin_button, _gold)
	_style_button(repay_button, _sage)
	_style_button($Root/Setup/Card/VBox/Start, _gold)
	var rule := ColorRect.new()
	rule.color = Color(0.72, 0.52, 0.22, 0.85)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tray := $Root/Panel/Margin/VBox
	tray.add_child(rule)
	tray.move_child(rule, 1)
	_build_legend()
	for edit in name_edits:
		_style_field(edit)
	log_label.add_theme_color_override("default_color", Color(0.78, 0.74, 0.66))
	spin_button.pressed.connect(func() -> void: _emit("spin", -1))
	repay_button.pressed.connect(func() -> void: _emit("repay", -1))
	$Root/Setup/Card/VBox/Start.pressed.connect(_on_start)
	for index in count_buttons.size():
		var count := index + 2
		count_buttons[index].pressed.connect(func() -> void: _select_count(count))
		_style_button(count_buttons[index])
	for edit in name_edits:
		edit.add_theme_color_override("font_color", _cream)
	_select_count(3)
	spin_button.visible = false
	repay_button.visible = false
	spin_button.custom_minimum_size = Vector2(0, 44)
	repay_button.custom_minimum_size = Vector2(0, 44)
	spinner = preload("res://Scripts/spinner.gd").new()
	$Root/Panel/Margin/VBox.add_child(spinner)
	$Root/Panel/Margin/VBox.move_child(spinner, 3)
	card_stage = HBoxContainer.new()
	card_stage.name = "CardStage"
	card_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	card_stage.add_theme_constant_override("separation", 14)
	card_stage.alignment = BoxContainer.ALIGNMENT_CENTER
	card_stage.anchor_left = 0.0
	card_stage.anchor_top = 1.0
	card_stage.anchor_right = 0.74
	card_stage.anchor_bottom = 1.0
	card_stage.offset_left = 12
	card_stage.offset_top = -228
	card_stage.offset_right = -8
	card_stage.offset_bottom = -12
	card_stage.grow_horizontal = Control.GROW_DIRECTION_BOTH
	$Root.add_child(card_stage)


func present(text: String, options: PackedStringArray, show_spin: bool, show_repay: bool) -> void:
	prompt_label.text = text
	_clear_choices()
	for index in options.size():
		var choice := index
		var button := Button.new()
		button.text = options[index]
		button.custom_minimum_size = Vector2(0, 36)
		_style_button(button)
		button.pressed.connect(func() -> void: _emit("choice", choice))
		choices.add_child(button)
	spin_button.visible = show_spin
	repay_button.visible = show_repay
	accepting = true
	presented.emit()


func present_cards(text: String, cards: Array, labels: PackedStringArray, extra: PackedStringArray) -> void:
	prompt_label.text = text
	_clear_choices()
	var count := 0
	for index in cards.size():
		var data: Dictionary = cards[index]
		var face = CardFace.new()
		face.show_face(data, labels[index] if index < labels.size() else str(data.get("name", "")))
		var choice := count
		face.pressed.connect(func() -> void: _emit("choice", choice))
		card_stage.add_child(face)
		count += 1
	for caption in extra:
		var choice := count
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size = Vector2(0, 36)
		_style_button(button)
		button.pressed.connect(func() -> void: _emit("choice", choice))
		choices.add_child(button)
		count += 1
	spin_button.visible = false
	repay_button.visible = false
	accepting = true
	presented.emit()


func show_drawn(card: Dictionary) -> void:
	_clear_stage()
	var face = CardFace.new()
	face.show_face(card, "")
	face.disabled = true
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_stage.add_child(face)


func choice_texts() -> PackedStringArray:
	var labels := PackedStringArray()
	if card_stage:
		_gather(card_stage, labels)
	_gather(choices, labels)
	return labels


func _gather(node: Node, labels: PackedStringArray) -> void:
	for child in node.get_children():
		if child is Button:
			var caption := str((child as Button).text)
			if caption != "" and child.visible:
				labels.append(caption)
		_gather(child, labels)


func set_readout(text: String, color: Color) -> void:
	readout.text = text
	readout.add_theme_color_override("font_color", color)


func show_spin(value: int, animate: bool) -> void:
	var red := value % 2 == 1
	var word := "red" if red else "black"
	set_readout("%d   %s" % [value, word], Color(0.92, 0.42, 0.36) if red else Color(0.86, 0.88, 0.92))
	if spinner:
		spinner.show_value(value, animate)


func popup(screen_pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = screen_pos + Vector2(-18, -28)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", 22)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 32, 0.55)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	tween.finished.connect(label.queue_free)


func refresh(players: Array, current: Player) -> void:
	for child in players_box.get_children():
		child.free()
	for index in players.size():
		var player: Player = players[index]
		var card := PanelContainer.new()
		var box := StyleBoxFlat.new()
		var active := player == current and not player.retired
		box.bg_color = Color(0.20, 0.16, 0.12, 0.98) if active else Color(0.13, 0.11, 0.09, 0.82)
		box.corner_radius_top_left = 8
		box.corner_radius_top_right = 8
		box.corner_radius_bottom_left = 8
		box.corner_radius_bottom_right = 8
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		box.border_width_left = 4
		box.border_color = _peg_color(index)
		card.add_theme_stylebox_override("panel", box)
		var block := VBoxContainer.new()
		var header := HBoxContainer.new()
		var title := Label.new()
		title.text = player.display_name
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cash := Label.new()
		cash.text = "%dK" % player.money
		cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(title)
		header.add_child(cash)
		var body := Label.new()
		body.text = player.summary()
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		block.add_child(header)
		block.add_child(body)
		card.add_child(block)
		var tint := Color(0.96, 0.88, 0.66) if active else _cream
		title.add_theme_color_override("font_color", tint)
		title.add_theme_font_size_override("font_size", 18)
		cash.add_theme_color_override("font_color", Color(0.95, 0.78, 0.38))
		cash.add_theme_font_size_override("font_size", 18)
		body.add_theme_color_override("font_color", Color(0.84, 0.78, 0.68))
		if player.retired:
			card.modulate = Color(1, 1, 1, 0.55)
		players_box.add_child(card)


func _peg_color(index: int) -> Color:
	var colors: Array[Color] = [
		Color(0.86, 0.27, 0.22),
		Color(0.24, 0.46, 0.82),
		Color(0.28, 0.62, 0.38),
		Color(0.58, 0.36, 0.74),
	]
	return colors[index % colors.size()]


func add_log(line: String) -> void:
	log_label.append_text(line + "\n")


func hide_setup() -> void:
	setup.visible = false
	setup.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_start() -> void:
	($Root/Setup/Card/VBox/Start as Button).disabled = true
	setup_names = PackedStringArray()
	for index in player_count:
		var raw := name_edits[index].text.strip_edges()
		setup_names.append(raw if raw != "" else "Player %d" % [index + 1])
	_emit("setup", player_count)


func _select_count(count: int) -> void:
	player_count = count
	for index in name_edits.size():
		name_edits[index].visible = index < count
	for index in count_buttons.size():
		var selected := index + 2 == count
		count_buttons[index].modulate = Color(1, 1, 1, 1) if selected else Color(1, 1, 1, 0.45)


func _emit(action: String, index: int) -> void:
	if not accepting and action != "setup":
		return
	accepting = false
	last_action = action
	last_index = index
	acted.emit.call_deferred()


func _clear_choices() -> void:
	for child in choices.get_children():
		child.visible = false
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.queue_free()
	_clear_stage()


func _clear_stage() -> void:
	if card_stage == null:
		return
	for child in card_stage.get_children():
		child.visible = false
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.queue_free()


func _style_panel(panel: Panel, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	panel.add_theme_stylebox_override("panel", box)


func _style_tray(panel: Panel) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = _ink
	box.border_color = Color(0.48, 0.30, 0.16)
	box.set_border_width_all(8)
	box.corner_radius_top_left = 18
	box.corner_radius_bottom_left = 18
	box.shadow_color = Color(0, 0, 0, 0.4)
	box.shadow_size = 18
	box.shadow_offset = Vector2(-6, 0)
	panel.add_theme_stylebox_override("panel", box)


func _style_card(panel: Panel) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.14, 0.11, 0.08, 1)
	box.border_color = Color(0.55, 0.36, 0.18)
	box.set_border_width_all(6)
	box.set_corner_radius_all(16)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 22
	panel.add_theme_stylebox_override("panel", box)


func _style_field(edit: LineEdit) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.06, 0.05)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(8)
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", box)


func _build_legend() -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	var items: Array[Dictionary] = [
		{"name": "Payday", "color": Color(0.93, 0.74, 0.28)},
		{"name": "Action", "color": Color(0.20, 0.52, 0.44)},
		{"name": "House", "color": Color(0.80, 0.44, 0.26)},
		{"name": "Stop", "color": Color(0.78, 0.22, 0.18)},
		{"name": "Baby", "color": Color(0.34, 0.60, 0.86)},
		{"name": "Pet", "color": Color(0.95, 0.82, 0.30)},
		{"name": "Spin", "color": Color(0.90, 0.48, 0.20)},
		{"name": "Retire", "color": Color(0.14, 0.36, 0.28)},
	]
	for item in items:
		var bit := HBoxContainer.new()
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bit.add_theme_constant_override("separation", 4)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.color = item["color"] as Color
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var caption := Label.new()
		caption.text = str(item["name"])
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_font_size_override("font_size", 12)
		caption.add_theme_color_override("font_color", Color(0.82, 0.76, 0.66))
		bit.add_child(swatch)
		bit.add_child(caption)
		grid.add_child(bit)
	$Root/Panel/Margin/VBox.add_child(grid)
	$Root/Panel/Margin/VBox.move_child(grid, $Root/Panel/Margin/VBox.get_child_count() - 2)


func _style_button(button: Button, fill: Color = _sage) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", _cream)
	button.add_theme_color_override("font_hover_color", _cream)
