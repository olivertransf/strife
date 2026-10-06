extends CanvasLayer

signal acted(action: Dictionary)

var you_rules_name := ""
var instant := false
var lit_numbers: Array = []
var display_font: Font
var banner_tween: Tween
var deal_root: Control
var banner_panel: PanelContainer
var banner_title: Label
var banner_sub: Label
var card_panel: PanelContainer
var card_title: Label
var card_body: Label
var card_value: Label
var choice_box: GridContainer
var score_panel: PanelContainer
var score_label: Label
var chips: Array = []

const GOLD := Color(0.98, 0.84, 0.38)
const INK := Color(0.97, 0.95, 0.9)
const MUTED := Color(0.78, 0.76, 0.7)
const GREEN := Color(0.45, 0.9, 0.5)
const RED := Color(0.95, 0.42, 0.38)


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	if FileAccess.file_exists("res://Assets/fonts/Nunito-Bold.ttf"):
		var font := FontFile.new()
		font.data = FileAccess.get_file_as_bytes("res://Assets/fonts/Nunito-Bold.ttf")
		display_font = font
	_banner(root)
	_strip(root)
	_card(root)
	_deal(root)
	_choices(root)
	_score(root)


func show_status(rows: Array, turn_name: String, _phase_title: String) -> void:
	for i in mini(rows.size(), chips.size()):
		var row: Dictionary = rows[i]
		var chip: Dictionary = chips[i]
		var shown := str(row.name)
		if you_rules_name != "" and shown == you_rules_name:
			shown = "You"
		var job := str(row.job) if str(row.job) != "" else "no job"
		var family := ""
		if bool(row.spouse):
			family = "  married"
		if int(row.babies) > 0:
			family += "  babies %d" % int(row.babies)
		if int(row.loans) > 0:
			family += "  loans %d" % int(row.loans)
		var active := str(row.name) == turn_name
		var cash_now := int(row.cash)
		var had_cash: bool = chip.has("cash")
		var previous := int(chip.get("cash", cash_now))
		chip.cash = cash_now
		chip.title.text = "%s   %dK" % [shown, cash_now]
		if had_cash and cash_now != previous:
			chip.title.add_theme_color_override("font_color", GREEN if cash_now > previous else RED)
		else:
			chip.title.add_theme_color_override("font_color", INK)
		chip.detail.text = job + family
		chip.panel.add_theme_stylebox_override("panel", _chip_style(chip.color, active))
		chip.panel.visible = true


func show_prompt(info: Dictionary) -> void:
	banner(str(info.get("title", "")), str(info.get("detail", "")), GOLD)
	for child in choice_box.get_children():
		child.queue_free()
	var options: Array = info.get("options", [])
	choice_box.columns = 5 if options.size() > 4 else maxi(options.size(), 1)
	for option in options:
		var button := Button.new()
		var label := str(option.get("label", "Choose"))
		if label == "College":
			label = "College\n100K tuition"
		button.text = label
		var picked: bool = option.has("number") and int(option.number) in lit_numbers
		button.custom_minimum_size = Vector2(112, 48) if options.size() > 4 else Vector2(240, 64)
		button.add_theme_font_size_override("font_size", 18)
		_use_font(button)
		button.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02) if picked else INK)
		button.add_theme_color_override("font_hover_color", Color(0.15, 0.1, 0.02))
		var fill := GOLD if picked else Color(0.16, 0.14, 0.1)
		button.add_theme_stylebox_override("normal", _button_style(fill, GOLD))
		button.add_theme_stylebox_override("hover", _button_style(GOLD, Color(1, 0.95, 0.7)))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.72, 0.58, 0.2), GOLD))
		button.pressed.connect(_emit.bind(option))
		choice_box.add_child(button)
	choice_box.visible = not options.is_empty()


func banner(title: String, detail: String, accent: Color) -> void:
	banner_title.text = title
	banner_sub.text = detail
	banner_panel.add_theme_stylebox_override("panel", _ribbon(accent))
	banner_panel.visible = title != "" or detail != ""
	if banner_tween:
		banner_tween.kill()
	if instant:
		banner_panel.offset_top = 14
		banner_panel.offset_bottom = 96
		return
	banner_panel.offset_top = -88
	banner_panel.offset_bottom = -6
	banner_tween = create_tween()
	banner_tween.set_parallel(true)
	banner_tween.tween_property(banner_panel, "offset_top", 14.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.tween_property(banner_panel, "offset_bottom", 96.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_card(title: String, body: String, value: String, tint: Color) -> void:
	_clear_deal()
	card_title.text = title
	card_body.text = body
	card_value.text = value
	card_panel.add_theme_stylebox_override("panel", _ribbon(tint))
	card_panel.visible = true


func show_deal(cards: Array, tint: Color) -> void:
	card_panel.visible = false
	_clear_deal()
	deal_root.visible = true
	var count := cards.size()
	for i in count:
		var card: Dictionary = cards[i]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(250, 210)
		panel.add_theme_stylebox_override("panel", _ribbon(tint))
		var shift := (float(i) - float(count - 1) * 0.5) * 270.0
		panel.position = Vector2(shift - 125.0, -105.0)
		panel.rotation = deg_to_rad((float(i) - float(count - 1) * 0.5) * 7.0)
		deal_root.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		var value := ""
		if int(card.get("salary", 0)) > 0:
			value = "%dK" % int(card.salary)
		elif int(card.get("price", 0)) > 0:
			value = "%dK" % int(card.price)
		box.add_child(_line(value, 40, GOLD))
		box.add_child(_line(str(card.get("title", "")), 24, INK))
		var body := _line(str(card.get("text", "")), 15, MUTED)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(220, 64)
		box.add_child(body)


func hide_card() -> void:
	card_panel.visible = false
	_clear_deal()


func hide_choices() -> void:
	choice_box.visible = false


func show_scores(snap: Dictionary) -> void:
	var lines: PackedStringArray = []
	var winner_line := ""
	for winner_name in snap.get("winners", []):
		if winner_line != "":
			winner_line += ", "
		var shown := str(winner_name)
		if you_rules_name != "" and shown == you_rules_name:
			shown = "You"
		winner_line += shown
	lines.append("Richest: " + winner_line)
	for row in snap.players:
		var parts: Dictionary = row.score_parts
		var shown := str(row.name)
		if you_rules_name != "" and shown == you_rules_name:
			shown = "You"
		lines.append("%s  %dK" % [shown, int(row.cash)])
		if not parts.is_empty():
			lines.append("   cash %s   houses %s   cards %s   babies %s   loans %s" % [
				parts.get("cash", 0), parts.get("houses", 0),
				int(parts.get("actions", 0)) + int(parts.get("pets", 0)),
				parts.get("babies", 0), parts.get("loans", 0),
			])
	score_label.text = "\n".join(lines)
	score_panel.visible = true
	choice_box.visible = false
	banner("Final tally", "Richest: " + winner_line, GOLD)


func set_spin_text(value: int, red: bool) -> void:
	var tint := Color(0.92, 0.34, 0.32) if red else Color(0.82, 0.82, 0.86)
	banner(str(value), "Red" if red else "Black", tint)


func _emit(option: Dictionary) -> void:
	var action := option.duplicate(true)
	action.erase("label")
	action.erase("text")
	action.erase("dest")
	acted.emit(action)


func _banner(root: Control) -> void:
	banner_panel = PanelContainer.new()
	banner_panel.anchor_left = 0.5
	banner_panel.anchor_right = 0.5
	banner_panel.offset_left = -390
	banner_panel.offset_right = 390
	banner_panel.offset_top = 14
	banner_panel.offset_bottom = 96
	banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_panel.add_child(box)
	banner_title = Label.new()
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.add_theme_font_size_override("font_size", 32)
	banner_title.add_theme_color_override("font_color", INK)
	_use_font(banner_title)
	box.add_child(banner_title)
	banner_sub = Label.new()
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_sub.custom_minimum_size = Vector2(720, 0)
	banner_sub.add_theme_font_size_override("font_size", 18)
	banner_sub.add_theme_color_override("font_color", MUTED)
	_use_font(banner_sub)
	box.add_child(banner_sub)


func _strip(root: Control) -> void:
	var strip := HBoxContainer.new()
	strip.anchor_right = 1
	strip.offset_left = 16
	strip.offset_right = -16
	strip.offset_top = 108
	strip.offset_bottom = 176
	strip.add_theme_constant_override("separation", 10)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(strip)
	var colors := [
		Color(0.86, 0.28, 0.28),
		Color(0.25, 0.48, 0.9),
		Color(0.28, 0.7, 0.42),
		Color(0.92, 0.72, 0.28),
	]
	for color in colors:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", _chip_style(color, false))
		strip.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		var title := Label.new()
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", INK)
		_use_font(title)
		box.add_child(title)
		var detail := Label.new()
		detail.add_theme_font_size_override("font_size", 13)
		detail.add_theme_color_override("font_color", MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(detail)
		chips.append({"panel": panel, "title": title, "detail": detail, "color": color})


func _card(root: Control) -> void:
	card_panel = PanelContainer.new()
	card_panel.anchor_left = 0.5
	card_panel.anchor_top = 0.5
	card_panel.anchor_right = 0.5
	card_panel.anchor_bottom = 0.5
	card_panel.offset_left = -270
	card_panel.offset_top = -150
	card_panel.offset_right = 270
	card_panel.offset_bottom = 130
	card_panel.visible = false
	root.add_child(card_panel)
	var box := VBoxContainer.new()
	card_panel.add_child(box)
	card_value = Label.new()
	card_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_value.add_theme_font_size_override("font_size", 58)
	card_value.add_theme_color_override("font_color", GOLD)
	_use_font(card_value)
	box.add_child(card_value)
	card_title = Label.new()
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_title.add_theme_font_size_override("font_size", 32)
	card_title.add_theme_color_override("font_color", INK)
	_use_font(card_title)
	box.add_child(card_title)
	card_body = Label.new()
	card_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_body.custom_minimum_size = Vector2(480, 72)
	card_body.add_theme_font_size_override("font_size", 18)
	card_body.add_theme_color_override("font_color", MUTED)
	box.add_child(card_body)


func _choices(root: Control) -> void:
	var anchor := CenterContainer.new()
	anchor.anchor_top = 1
	anchor.anchor_right = 1
	anchor.anchor_bottom = 1
	anchor.offset_top = -150
	anchor.offset_bottom = -28
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(anchor)
	choice_box = GridContainer.new()
	choice_box.columns = 5
	choice_box.add_theme_constant_override("h_separation", 10)
	choice_box.add_theme_constant_override("v_separation", 10)
	anchor.add_child(choice_box)


func _score(root: Control) -> void:
	score_panel = PanelContainer.new()
	score_panel.anchor_left = 0.5
	score_panel.anchor_top = 0.5
	score_panel.anchor_right = 0.5
	score_panel.anchor_bottom = 0.5
	score_panel.offset_left = -280
	score_panel.offset_top = -190
	score_panel.offset_right = 280
	score_panel.offset_bottom = 210
	score_panel.visible = false
	score_panel.add_theme_stylebox_override("panel", _ribbon(GOLD))
	root.add_child(score_panel)
	score_label = Label.new()
	score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	score_label.custom_minimum_size = Vector2(500, 340)
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", INK)
	_use_font(score_label)
	score_panel.add_child(score_label)


func _deal(root: Control) -> void:
	deal_root = Control.new()
	deal_root.anchor_left = 0.5
	deal_root.anchor_top = 0.5
	deal_root.anchor_right = 0.5
	deal_root.anchor_bottom = 0.5
	deal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deal_root.visible = false
	root.add_child(deal_root)


func _clear_deal() -> void:
	if deal_root == null:
		return
	for child in deal_root.get_children():
		child.queue_free()
	deal_root.visible = false


func _line(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	_use_font(label)
	return label


func _use_font(control: Control) -> void:
	if display_font == null:
		return
	control.add_theme_font_override("font", display_font)


func _ribbon(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.94)
	style.border_color = accent
	style.border_width_bottom = 6
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.set_corner_radius_all(16)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	return style


func _chip_style(color: Color, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.9)
	style.border_color = GOLD if active else color
	style.border_width_left = 8
	style.border_width_top = 3 if active else 1
	style.border_width_right = 3 if active else 1
	style.border_width_bottom = 3 if active else 1
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _button_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
