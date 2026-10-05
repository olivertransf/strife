extends CanvasLayer
class_name StrifeUI

signal acted

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
var _ink := Color(0.09, 0.085, 0.078, 0.94)
var _sage := Color(0.227, 0.42, 0.345)


func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Sans-Serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	$Root.theme = theme
	_style_panel($Root/Panel, _ink)
	_style_panel($Root/Setup, Color(0.05, 0.05, 0.05, 0.45))
	_style_panel($Root/Setup/Card, Color(0.14, 0.13, 0.11, 1))
	for node in [$Root/Panel/Margin/VBox/Title, prompt_label, readout, $Root/Setup/Card/VBox/Heading, $Root/Setup/Card/VBox/Blurb]:
		(node as Label).add_theme_color_override("font_color", _cream)
	_style_button(spin_button)
	_style_button(repay_button)
	_style_button($Root/Setup/Card/VBox/Start)
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


func set_readout(text: String, color: Color) -> void:
	readout.text = text
	readout.add_theme_color_override("font_color", color)


func refresh(players: Array, current: Player) -> void:
	for child in players_box.get_children():
		child.free()
	for player in players:
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
		var tint := _cream
		if player == current and not player.retired:
			tint = Color(0.62, 0.8, 0.7)
		title.add_theme_color_override("font_color", tint)
		cash.add_theme_color_override("font_color", tint)
		body.add_theme_color_override("font_color", Color(0.82, 0.78, 0.7))
		players_box.add_child(block)


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
		child.queue_free()


func _style_panel(panel: Panel, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	panel.add_theme_stylebox_override("panel", box)


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = _sage
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.30, 0.52, 0.43)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", _cream)
	button.add_theme_color_override("font_hover_color", _cream)
