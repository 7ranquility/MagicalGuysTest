extends Control

signal start_game
signal open_settings
signal quit_game

func _ready():
	$popupMenu/VBoxContainer/baseMenuScreen/NinePatchRect/MarginContainer/VBoxContainer/"Start Game".pressed.connect(_on_start_game)
	$popupMenu/VBoxContainer/baseMenuScreen/NinePatchRect/MarginContainer/VBoxContainer/Settings.pressed.connect(_on_open_settings)
	$popupMenu/VBoxContainer/baseMenuScreen/NinePatchRect/MarginContainer/VBoxContainer/Quit.pressed.connect(_on_quit_game)

func _on_start_game():
	print("Start Game pressed")
	emit_signal("start_game")

func _on_open_settings():
	print("Settings pressed")
	emit_signal("open_settings")

func _on_quit_game():
	print("Quit pressed")
	emit_signal("quit_game") 