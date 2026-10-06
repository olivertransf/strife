extends CanvasLayer

signal acted(action: Dictionary)

var status_label: Label
var detail_label: Label
var card_panel: PanelContainer
var card_title: Label
var card_body: Label
var card_value: Label
var choice_box: GridContainer
var score_panel: PanelContainer
var score_label: Label
var spin_label: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_status(root)
	_card(root)
	_choices(root)
	_score(root)


func show_status(rows: Array, turn_name: String, phase_title: String) -> void:
	var lines: PackedStringArray = []
	lines.append(phase_title)
	for row in rows:
		var mark := ">" if str(row.name) == turn_name else " "
		var job := str(row.job) if str(row.job) != "" else "no job"
		var family := "babies %d" % int(row.babies)
		if bool(row.spouse):
			family = "married, " + family
		lines.append("%s%s   %dK   %s" % [mark, row.name, int(row.cash), job])
		lines.append("    loans %d   %s" % [int(row.loans), family])
	status_label.text = "\n".join(lines)


func show_prompt(info: Dictionary) -> void:
	detail_label.text = str(info.get("detail", ""))
	for child in choice_box.get_children():
		child.queue_free()
	var options: Array = info.get("options", [])
	if str(info.get("phase", "")) == "wheel_pick":
		detail_label.text = "%s. %s" % [info.get("title", ""), info.get("detail", "")]
	choice_box.columns = 5 if options.size() > 4 else maxi(options.size(), 1)
	for option in options:
		var button := Button.new()
		button.text = str(option.get("label", "Choose"))
		button.custom_minimum_size = Vector2(150, 46) if options.size() > 4 else Vector2(220, 52)
		button.pressed.connect(_emit.bind(option))
		choice_box.add_child(button)
	choice_box.visible = not options.is_empty()


func show_card(title: String, body: String, value: String, tint: Color) -> void:
	card_title.text = title
	card_body.text = body
	card_value.text = value
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.13, 0.18, 0.96)
	style.border_color = tint
	style.set_border_width_all(6)
	style.set_corner_radius_all(18)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	card_panel.add_theme_stylebox_override("panel", style)
	card_panel.visible = true


func hide_card() -> void:
	card_panel.visible = false


func show_scores(snap: Dictionary) -> void:
	var lines: PackedStringArray = []
	var winner_line := ""
	for winner_name in snap.get("winners", []):
		if winner_line != "":
			winner_line += ", "
		winner_line += str(winner_name)
	lines.append("Richest: " + winner_line)
	for row in snap.players:
		var parts: Dictionary = row.score_parts
		lines.append("%s  %dK" % [row.name, int(row.cash)])
		if not parts.is_empty():
			lines.append("   cash %s   houses %s   cards %s   babies %s   loans %s" % [
				parts.get("cash", 0), parts.get("houses", 0),
				int(parts.get("actions", 0)) + int(parts.get("pets", 0)),
				parts.get("babies", 0), parts.get("loans", 0),
			])
	score_label.text = "\n".join(lines)
	score_panel.visible = true
	choice_box.visible = false
	detail_label.text = ""
	spin_label.text = ""


func set_spin_text(value: int, red: bool) -> void:
	spin_label.text = "%d  %s" % [value, "red" if red else "black"]


func _emit(option: Dictionary) -> void:
	var action := option.duplicate(true)
	action.erase("label")
	action.erase("text")
	action.erase("dest")
	acted.emit(action)


func _status(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 12)
	panel.custom_minimum_size = Vector2(460, 300)
	panel.add_theme_stylebox_override("panel", _paper(Color(0.08, 0.1, 0.14, 0.88), Color(0.93, 0.76, 0.32)))
	root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	box.add_child(status_label)
	spin_label = Label.new()
	spin_label.add_theme_font_size_override("font_size", 28)
	spin_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.4))
	box.add_child(spin_label)
	detail_label = Label.new()
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.custom_minimum_size = Vector2(480, 48)
	detail_label.add_theme_font_size_override("font_size", 16)
	detail_label.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	box.add_child(detail_label)


func _card(root: Control) -> void:
	card_panel = PanelContainer.new()
	card_panel.position = Vector2(470, 150)
	card_panel.custom_minimum_size = Vector2(500, 280)
	card_panel.visible = false
	root.add_child(card_panel)
	var box := VBoxContainer.new()
	card_panel.add_child(box)
	card_value = Label.new()
	card_value.add_theme_font_size_override("font_size", 64)
	card_value.add_theme_color_override("font_color", Color(0.98, 0.86, 0.4))
	box.add_child(card_value)
	card_title = Label.new()
	card_title.add_theme_font_size_override("font_size", 36)
	card_title.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	box.add_child(card_title)
	card_body = Label.new()
	card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_body.custom_minimum_size = Vector2(440, 80)
	card_body.add_theme_font_size_override("font_size", 20)
	card_body.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
	box.add_child(card_body)


func _choices(root: Control) -> void:
	choice_box = GridContainer.new()
	choice_box.position = Vector2(500, 600)
	choice_box.columns = 5
	choice_box.add_theme_constant_override("h_separation", 8)
	choice_box.add_theme_constant_override("v_separation", 8)
	root.add_child(choice_box)


func _score(root: Control) -> void:
	score_panel = PanelContainer.new()
	score_panel.position = Vector2(430, 150)
	score_panel.custom_minimum_size = Vector2(520, 420)
	score_panel.visible = false
	score_panel.add_theme_stylebox_override("panel", _paper(Color(0.1, 0.12, 0.16, 0.94), Color(0.95, 0.9, 0.6)))
	root.add_child(score_panel)
	score_label = Label.new()
	score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	score_label.custom_minimum_size = Vector2(480, 360)
	score_label.add_theme_font_size_override("font_size", 20)
	score_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	score_panel.add_child(score_label)


func _paper(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
