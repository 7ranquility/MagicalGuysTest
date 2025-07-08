extends Control

signal upgrade_chosen(upgrade_id)

var upgrades = []  # List of all possible upgrades (populated externally)
var available_upgrades = []  # Upgrades to show this time
var weapon_groups = {}  # {group_name: [upgrade_id, ...]}

const MAX_CHOICES = 3


func _ready():
	visible = false
	set_process_input(false)


func show_menu(upgrade_pool: Array, group_filter: Array):
	print("show_menu called with upgrades:", upgrade_pool, " groups:", group_filter)
	# upgrade_pool: all upgrades player could get
	# group_filter: allowed weapon groups (e.g. ["Aura"])
	# Filter and pick up to MAX_CHOICES upgrades
	available_upgrades.clear()
	var filtered = []
	for upg in upgrade_pool:
		if upg.group in group_filter:
			filtered.append(upg)
	filtered.shuffle()
	for i in range(min(MAX_CHOICES, filtered.size())):
		available_upgrades.append(filtered[i])
	print("available_upgrades:", available_upgrades)
	_update_ui()
	visible = true
	get_tree().paused = true
	set_process_input(true)
	grab_focus()


func _update_ui():
	print("_update_ui called, available_upgrades:", available_upgrades)
	var buttons_container = get_node("Panel/VBoxContainer/UpgradeButtons")
	print("buttons_container:", buttons_container)
	# Remove all children from the container
	for child in buttons_container.get_children():
		buttons_container.remove_child(child)
		child.queue_free()
	var first_btn = null
	for i in range(available_upgrades.size()):
		var upg = available_upgrades[i]
		var btn = Button.new()
		btn.text = upg.name + " (" + upg.group + ")\n" + upg.description
		btn.focus_mode = Control.FOCUS_ALL
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.disabled = false
		btn.process_mode = Node.PROCESS_MODE_ALWAYS
		print("Connecting button ", i, ": ", btn.text)
		btn.pressed.connect(func(): _on_upgrade_selected(i))
		buttons_container.add_child(btn)
		if i == 0:
			first_btn = btn
	# Focus the first button and the menu
	if first_btn:
		first_btn.grab_focus()
	grab_focus()
	buttons_container.queue_redraw()


func _on_upgrade_selected(idx):
	var chosen = available_upgrades[idx]
	emit_signal("upgrade_chosen", chosen.id)
	visible = false
	get_tree().paused = false
	set_process_input(false)


# Gamepad/keyboard navigation
func _unhandled_input(event):
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		var buttons = get_node("Panel/VBoxContainer/UpgradeButtons").get_children()
		var focused = null
		for i in range(buttons.size()):
			if buttons[i].has_focus():
				focused = i
				break
		if event.keycode == KEY_UP:
			if focused != null and focused > 0:
				buttons[focused - 1].grab_focus()
				accept_event()
		elif event.keycode == KEY_DOWN:
			if focused != null and focused < buttons.size() - 1:
				buttons[focused + 1].grab_focus()
				accept_event()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			if focused != null:
				buttons[focused].emit_signal("pressed")
				accept_event()
	elif event is InputEventJoypadButton and event.pressed:
		var buttons = get_node("Panel/VBoxContainer/UpgradeButtons").get_children()
		var focused = null
		for i in range(buttons.size()):
			if buttons[i].has_focus():
				focused = i
				break
		if event.button_index == JOY_BUTTON_DPAD_UP:
			if focused != null and focused > 0:
				buttons[focused - 1].grab_focus()
				accept_event()
		elif event.button_index == JOY_BUTTON_DPAD_DOWN:
			if focused != null and focused < buttons.size() - 1:
				buttons[focused + 1].grab_focus()
				accept_event()
		elif event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]:
			if focused != null:
				buttons[focused].emit_signal("pressed")
				accept_event()


# Utility for registering upgrades (to be called externally)
func register_upgrade(upgrade):
	upgrades.append(upgrade)
	if not weapon_groups.has(upgrade.group):
		weapon_groups[upgrade.group] = []
	weapon_groups[upgrade.group].append(upgrade.id)
