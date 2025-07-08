extends Control

signal start_game
signal open_settings
signal quit_game
signal weapon_selected(weapon_type)

func _ready():
	$popupMenu/VBoxContainer/baseMenuScreen/NinePatchRect/MarginContainer/VBoxContainer/"Start Game".pressed.connect(_on_start_game)
	$popupMenu/VBoxContainer/baseMenuScreen/NinePatchRect/MarginContainer/VBoxContainer/Settings.pressed.connect(_on_open_settings)
	$popupMenu/VBoxContainer/baseMenuScreen/NinePatchRect/MarginContainer/VBoxContainer/Quit.pressed.connect(_on_quit_game)
	$WeaponSelectPopup/VBoxContainer/AuraButton.pressed.connect(func(): _on_weapon_selected("Aura"))
	$WeaponSelectPopup/VBoxContainer/ProjectileButton.pressed.connect(func(): _on_weapon_selected("Projectile"))

func _on_start_game():
	"""Handles Start Game button press: shows weapon select popup and hides main menu."""
	print("Start Game pressed")
	$WeaponSelectPopup.visible = true
	$popupMenu.visible = false

func _on_open_settings():
	"""Handles Settings button press and emits open_settings signal."""
	print("Settings pressed")
	emit_signal("open_settings")

func _on_quit_game():
	"""Handles Quit button press and emits quit_game signal."""
	print("Quit pressed")
	emit_signal("quit_game")

func _on_weapon_selected(weapon_type):
	"""Handles weapon selection and emits weapon_selected signal."""
	print("Weapon selected: ", weapon_type)
	emit_signal("weapon_selected", weapon_type)
	$WeaponSelectPopup.visible = false 
