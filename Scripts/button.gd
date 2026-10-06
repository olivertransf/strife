extends Button

signal pressed_to_main

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	emit_signal("pressed_to_main")
