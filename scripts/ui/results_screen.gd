extends Control
## End of run: stats and damage per instrument.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root: Control = UiKit.screen_root()
	add_child(root)
	var r: Dictionary = Game.last_result
	var panel: PanelContainer = UiKit.panel()
	var v: VBoxContainer = UiKit.vbox(10)
	panel.add_child(v)
	var won: bool = r.get("won", false)
	var title: Label = UiKit.label("STAGE CLEAR!" if won else "GAME OVER", UiKit.SIZE_HEAD, UiKit.C_GOOD if won else UiKit.C_BAD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var g: GridContainer = UiKit.grid(2, 40)
	for row: Array in [
		["Time survived", UiKit.format_time(float(r.get("time", 0.0)))],
		["Level reached", str(int(r.get("level", 1)))],
		["Enemies defeated", str(int(r.get("kills", 0)))],
		["Gold earned", str(int(r.get("gold", 0)))],
	]:
		g.add_child(UiKit.label(row[0], UiKit.SIZE_BODY, UiKit.C_DIM))
		g.add_child(UiKit.label(row[1], UiKit.SIZE_BODY))
	v.add_child(g)
	v.add_child(UiKit.label("DAMAGE BY INSTRUMENT", UiKit.SIZE_BODY, UiKit.C_ACCENT, true))
	var dmg: Dictionary = r.get("damage", {})
	var ids: Array = dmg.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return float(dmg[a]) > float(dmg[b]))
	for id: String in ids:
		var def: Dictionary = Content.instruments.get(id, {})
		var row2: HBoxContainer = UiKit.hbox(12)
		row2.custom_minimum_size.x = 520
		row2.add_child(UiKit.icon(def.get("icon", "ui_unknown"), 40))
		row2.add_child(UiKit.label(def.get("name", id), 22))
		row2.add_child(UiKit.spacer())
		row2.add_child(UiKit.label(UiKit.format_number(float(dmg[id])), 22, UiKit.C_DIM))
		v.add_child(row2)
	var buttons: HBoxContainer = UiKit.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var again: Button = UiKit.button("Play again", func() -> void: Game.go("run"))
	buttons.add_child(again)
	buttons.add_child(UiKit.button("Title", func() -> void: Game.go("title")))
	v.add_child(buttons)
	root.add_child(UiKit.center(panel))
	again.grab_focus.call_deferred()
