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
	print("Start Game pressed")
	$WeaponSelectPopup.visible = true
	$popupMenu.visible = false

func _on_open_settings():
	print("Settings pressed")
	emit_signal("open_settings")

func _on_quit_game():
	print("Quit pressed")
	emit_signal("quit_game")

func _on_weapon_selected(weapon_type):
	print("Weapon selected: ", weapon_type)
	emit_signal("weapon_selected", weapon_type)
	$WeaponSelectPopup.visible = false 